#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const configPath = process.env.OPENCLAW_CONFIG_PATH;
const gatewayPackage = process.env.OPENCLAW_GATEWAY;
const expectedWorkspace = process.env.OPENCLAW_EXPECTED_WORKSPACE;

if (!configPath) {
  console.error("OPENCLAW_CONFIG_PATH is not set");
  process.exit(1);
}

if (!gatewayPackage) {
  console.error("OPENCLAW_GATEWAY is not set");
  process.exit(1);
}

if (!expectedWorkspace) {
  console.error("OPENCLAW_EXPECTED_WORKSPACE is not set");
  process.exit(1);
}

const openclaw = path.join(gatewayPackage, "bin", "openclaw");
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "openclaw-config-validity-"));

try {
  const env = {
    ...process.env,
    HOME: path.join(tmpDir, "home"),
    XDG_CONFIG_HOME: path.join(tmpDir, "config"),
    XDG_CACHE_HOME: path.join(tmpDir, "cache"),
    XDG_DATA_HOME: path.join(tmpDir, "data"),
    OPENCLAW_CONFIG_PATH: configPath,
    OPENCLAW_STATE_DIR: path.join(tmpDir, "state"),
    OPENCLAW_LOG_DIR: path.join(tmpDir, "logs"),
    OPENCLAW_NIX_MODE: "1",
    NO_COLOR: "1",
  };

  for (const key of [
    "HOME",
    "XDG_CONFIG_HOME",
    "XDG_CACHE_HOME",
    "XDG_DATA_HOME",
    "OPENCLAW_STATE_DIR",
    "OPENCLAW_LOG_DIR",
  ]) {
    fs.mkdirSync(env[key], { recursive: true });
  }

  const validate = spawnSync(openclaw, ["config", "validate", "--json"], {
    env,
    encoding: "utf8",
  });

  if (validate.status !== 0) {
    if (validate.stdout) {
      process.stdout.write(validate.stdout);
    }
    if (validate.stderr) {
      process.stderr.write(validate.stderr);
    }
    console.error(`openclaw config validation failed with exit code ${validate.status ?? "unknown"}`);
    process.exit(validate.status ?? 1);
  }

  const validation = JSON.parse(validate.stdout);
  if (!validation || validation.valid !== true) {
    console.error("openclaw config validation did not report valid=true");
    process.exit(1);
  }

  const workspace = spawnSync(openclaw, ["config", "get", "agents.defaults.workspace", "--json"], {
    env,
    encoding: "utf8",
  });

  if (workspace.status !== 0) {
    if (workspace.stdout) {
      process.stdout.write(workspace.stdout);
    }
    if (workspace.stderr) {
      process.stderr.write(workspace.stderr);
    }
    console.error(`openclaw config get failed with exit code ${workspace.status ?? "unknown"}`);
    process.exit(workspace.status ?? 1);
  }

  const actualWorkspace = JSON.parse(workspace.stdout);
  if (actualWorkspace !== expectedWorkspace) {
    console.error(
      `openclaw config returned unexpected workspace: ${JSON.stringify(actualWorkspace)} != ${JSON.stringify(expectedWorkspace)}`,
    );
    process.exit(1);
  }

  console.log("openclaw config validation: ok");
} finally {
  fs.rmSync(tmpDir, { recursive: true, force: true });
}
