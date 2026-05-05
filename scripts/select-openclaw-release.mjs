#!/usr/bin/env node
import { pathToFileURL } from "node:url";

export function selectOpenClawRelease(releases) {
  if (!Array.isArray(releases)) {
    throw new Error("Expected a GitHub releases JSON array");
  }

  const stableReleases = releases.filter((release) => {
    return release && release.draft !== true && release.prerelease !== true;
  });
  const latestStable = stableReleases[0] ?? null;
  const skippedStableReleases = [];

  for (const release of stableReleases) {
    const tagName = release.tag_name ?? release.tagName;
    if (!tagName) {
      skippedStableReleases.push({
        tagName: null,
        reason: "missing-tag",
      });
      continue;
    }

    const appAsset = (release.assets ?? []).find((asset) => {
      const name = asset?.name;
      return (
        typeof name === "string" &&
        /^OpenClaw-.*\.zip$/.test(name) &&
        !/dSYM/i.test(name) &&
        Boolean(asset?.browser_download_url)
      );
    });

    if (!appAsset) {
      skippedStableReleases.push({
        tagName,
        reason: "missing-macos-zip",
      });
      continue;
    }

    return {
      latestStable: latestStable
        ? {
            tagName: latestStable.tag_name ?? latestStable.tagName,
          }
        : null,
      latestFullPackageableStable: {
        tagName,
        releaseVersion: tagName.replace(/^v/, ""),
        appAssetName: appAsset.name,
        appUrl: appAsset.browser_download_url,
      },
      skippedStableReleases,
    };
  }

  return {
    latestStable: latestStable
      ? {
          tagName: latestStable.tag_name ?? latestStable.tagName,
        }
      : null,
    latestFullPackageableStable: null,
    skippedStableReleases,
  };
}

function readStdin() {
  return new Promise((resolve, reject) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      data += chunk;
    });
    process.stdin.on("end", () => resolve(data));
    process.stdin.on("error", reject);
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const input = await readStdin();
  const releases = JSON.parse(input);
  const selection = selectOpenClawRelease(releases);
  process.stdout.write(`${JSON.stringify(selection, null, 2)}\n`);
}
