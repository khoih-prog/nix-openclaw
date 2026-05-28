#!/usr/bin/env node
import childProcess from "node:child_process";
import fs from "node:fs";
import https from "node:https";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, "../..");
const sourceInfoPath = path.join(repoRoot, "nix/sources/openclaw-source.nix");
const outputDir = path.join(repoRoot, "nix/generated/openclaw-runtime-plugins");
const defaultOutputPath = path.join(outputDir, "default.nix");

const curatedPlugins = [
  {
    id: "slack",
    attrName: "slack",
    packageName: "@openclaw/slack",
    v1aClass: "bundled-dependencies",
  },
  {
    id: "discord",
    attrName: "discord",
    packageName: "@openclaw/discord",
    v1aClass: "bundled-dependencies",
  },
  {
    id: "brave",
    attrName: "brave",
    packageName: "@openclaw/brave-plugin",
    v1aClass: "no-runtime-dependencies",
  },
  {
    id: "diagnostics-prometheus",
    attrName: "diagnosticsPrometheus",
    packageName: "@openclaw/diagnostics-prometheus",
    v1aClass: "no-runtime-dependencies",
  },
];

function run(command, args, options = {}) {
  const result = childProcess.spawnSync(command, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    ...options,
  });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed:\n${result.stderr || result.stdout}`);
  }
  return result.stdout;
}

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, { headers: { Accept: "application/json" } }, (response) => {
        if (
          response.statusCode >= 300
          && response.statusCode < 400
          && response.headers.location
        ) {
          response.resume();
          fetchJson(response.headers.location).then(resolve, reject);
          return;
        }
        if (response.statusCode !== 200) {
          reject(new Error(`GET ${url} failed with HTTP ${response.statusCode}`));
          response.resume();
          return;
        }
        let body = "";
        response.setEncoding("utf8");
        response.on("data", (chunk) => {
          body += chunk;
        });
        response.on("end", () => {
          try {
            resolve(JSON.parse(body));
          } catch (error) {
            reject(error);
          }
        });
      })
      .on("error", reject);
  });
}

function readReleaseVersion() {
  const sourceInfo = fs.readFileSync(sourceInfoPath, "utf8");
  const match = sourceInfo.match(/releaseVersion = "([^"]+)";/);
  if (!match) {
    throw new Error(`Could not read releaseVersion from ${sourceInfoPath}`);
  }
  return match[1];
}

function npmRegistryUrl(packageName) {
  return `https://registry.npmjs.org/${encodeURIComponent(packageName).replace("%2F", "%2f")}`;
}

function pickDefined(object) {
  return Object.fromEntries(Object.entries(object).filter(([, value]) => value !== undefined));
}

function sortedObject(object = {}) {
  return Object.fromEntries(Object.entries(object).sort(([a], [b]) => a.localeCompare(b)));
}

function shrinkwrapSummary(shrinkwrap) {
  const packages = shrinkwrap?.packages ?? {};
  return Object.fromEntries(
    Object.entries(packages)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([packagePath, entry]) => [
        packagePath,
        pickDefined({
          name: entry.name,
          version: entry.version,
          resolved: entry.resolved,
          integrity: entry.integrity,
          optional: entry.optional === true ? true : undefined,
          dev: entry.dev === true ? true : undefined,
          hasInstallScript: entry.hasInstallScript === true ? true : undefined,
          bin: entry.bin,
          os: entry.os,
          cpu: entry.cpu,
        }),
      ]),
  );
}

function collectPackageRoots(nodeModulesDir, baseRel = "node_modules") {
  if (!fs.existsSync(nodeModulesDir)) {
    return [];
  }

  const roots = [];
  for (const entry of fs.readdirSync(nodeModulesDir).sort()) {
    if (entry === ".bin") {
      continue;
    }

    const entryPath = path.join(nodeModulesDir, entry);
    const entryRel = `${baseRel}/${entry}`;
    if (!fs.statSync(entryPath).isDirectory()) {
      continue;
    }

    if (entry.startsWith("@")) {
      for (const scopedName of fs.readdirSync(entryPath).sort()) {
        const scopedPath = path.join(entryPath, scopedName);
        const scopedRel = `${entryRel}/${scopedName}`;
        if (fs.statSync(scopedPath).isDirectory()) {
          roots.push(scopedRel);
          roots.push(...collectPackageRoots(path.join(scopedPath, "node_modules"), `${scopedRel}/node_modules`));
        }
      }
    } else {
      roots.push(entryRel);
      roots.push(...collectPackageRoots(path.join(entryPath, "node_modules"), `${entryRel}/node_modules`));
    }
  }

  return roots;
}

function validateTarMembers(tarball) {
  const memberList = run("tar", [
    "-tzf",
    tarball,
  ]);
  for (const member of memberList.split(/\r?\n/).filter(Boolean)) {
    if (path.isAbsolute(member) || member.split("/").includes("..")) {
      throw new Error(`unsafe tar member path in ${tarball}: ${member}`);
    }
    if (!member.startsWith("package/")) {
      throw new Error(`unexpected tar member outside package/ in ${tarball}: ${member}`);
    }
  }
}

function nixString(value) {
  return JSON.stringify(value);
}

function nixAttrName(name) {
  return /^[A-Za-z_][A-Za-z0-9_'-]*$/.test(name) ? name : nixString(name);
}

function toNix(value, indent = "") {
  const nextIndent = `${indent}  `;
  if (value === null) {
    return "null";
  }
  if (typeof value === "string") {
    return nixString(value);
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  if (Array.isArray(value)) {
    if (value.length === 0) {
      return "[ ]";
    }
    return `[\n${value.map((item) => `${nextIndent}${toNix(item, nextIndent)}`).join("\n")}\n${indent}]`;
  }
  if (typeof value === "object") {
    const entries = Object.entries(value);
    if (entries.length === 0) {
      return "{ }";
    }
    return `{\n${entries
      .map(([key, item]) => `${nextIndent}${nixAttrName(key)} = ${toNix(item, nextIndent)};`)
      .join("\n")}\n${indent}}`;
  }
  throw new Error(`Unsupported Nix value: ${value}`);
}

function renderLock(lock) {
  return `# Generated by nix/scripts/update-openclaw-runtime-plugin-locks.mjs. Do not edit manually.\n${toNix(lock)}\n`;
}

function renderDefault(locks) {
  const entries = locks
    .map((lock) => `  ${nixAttrName(lock.id)} = import ./${lock.attrName}.nix;`)
    .join("\n");
  return `# Generated by nix/scripts/update-openclaw-runtime-plugin-locks.mjs. Do not edit manually.\n{\n${entries}\n}\n`;
}

async function buildLock(plugin, releaseVersion) {
  const packageMetadata = await fetchJson(npmRegistryUrl(plugin.packageName));
  const versionMetadata = packageMetadata.versions?.[releaseVersion];
  if (!versionMetadata) {
    throw new Error(`${plugin.packageName}@${releaseVersion} is not published`);
  }

  const prefetch = JSON.parse(
    run("nix", [
      "store",
      "prefetch-file",
      "--json",
      versionMetadata.dist.tarball,
    ]),
  );

  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "openclaw-runtime-plugin-lock-"));
  try {
    validateTarMembers(prefetch.storePath);
    run("tar", [
      "-xzf",
      prefetch.storePath,
      "-C",
      tmpDir,
    ]);

    const packageRoot = path.join(tmpDir, "package");
    const packageJson = JSON.parse(fs.readFileSync(path.join(packageRoot, "package.json"), "utf8"));
    const manifest = JSON.parse(fs.readFileSync(path.join(packageRoot, "openclaw.plugin.json"), "utf8"));
    const shrinkwrapPath = path.join(packageRoot, "npm-shrinkwrap.json");
    const shrinkwrap = fs.existsSync(shrinkwrapPath)
      ? JSON.parse(fs.readFileSync(shrinkwrapPath, "utf8"))
      : null;
    const shrinkwrapPackages = shrinkwrapSummary(shrinkwrap);
    const bundledPackageRoots = collectPackageRoots(path.join(packageRoot, "node_modules"));

    if (packageJson.name !== plugin.packageName) {
      throw new Error(`${plugin.packageName}: package.json name mismatch`);
    }
    if (packageJson.version !== releaseVersion) {
      throw new Error(`${plugin.packageName}: package.json version mismatch`);
    }
    if (manifest.id !== plugin.id) {
      throw new Error(`${plugin.packageName}: openclaw.plugin.json id mismatch`);
    }

    for (const bundledRoot of bundledPackageRoots) {
      if (!shrinkwrapPackages[bundledRoot]) {
        throw new Error(`${plugin.packageName}: bundled dependency ${bundledRoot} missing from shrinkwrap`);
      }
    }

    return {
      id: plugin.id,
      attrName: plugin.attrName,
      packageName: plugin.packageName,
      version: releaseVersion,
      tarballUrl: versionMetadata.dist.tarball,
      npmIntegrity: versionMetadata.dist.integrity,
      npmShasum: versionMetadata.dist.shasum,
      nixHash: prefetch.hash,
      v1aClass: plugin.v1aClass,
      manifestId: manifest.id,
      openclawCompat: packageJson.openclaw?.compat?.pluginApi ?? "",
      peerOpenClaw: packageJson.peerDependencies?.openclaw ?? "",
      runtimeExtensions: packageJson.openclaw?.runtimeExtensions ?? [],
      runtimeSetupEntry: packageJson.openclaw?.runtimeSetupEntry ?? null,
      channels: manifest.channels ?? [],
      contracts: manifest.contracts ?? {},
      dependencies: sortedObject(packageJson.dependencies ?? versionMetadata.dependencies ?? {}),
      optionalDependencies: sortedObject(
        packageJson.optionalDependencies ?? versionMetadata.optionalDependencies ?? {},
      ),
      bundleDependencies: [
        ...(versionMetadata.bundleDependencies ?? versionMetadata.bundledDependencies ?? []),
      ].sort(),
      bundledPackageRoots,
    };
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

const releaseVersion = readReleaseVersion();
const locks = [];
for (const plugin of curatedPlugins) {
  locks.push(await buildLock(plugin, releaseVersion));
}

fs.mkdirSync(outputDir, { recursive: true });
for (const lock of locks) {
  fs.writeFileSync(path.join(outputDir, `${lock.attrName}.nix`), renderLock(lock));
}
fs.writeFileSync(defaultOutputPath, renderDefault(locks));
console.log(`wrote ${path.relative(repoRoot, outputDir)} for OpenClaw ${releaseVersion}`);
