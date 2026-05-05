#!/usr/bin/env node
import assert from "node:assert/strict";
import { selectOpenClawRelease } from "./select-openclaw-release.mjs";

const releases = [
  {
    tag_name: "v2026.5.3-1",
    draft: false,
    prerelease: false,
    assets: [],
  },
  {
    tag_name: "v2026.5.3",
    draft: false,
    prerelease: false,
    assets: [],
  },
  {
    tag_name: "v2026.5.2-beta.1",
    draft: false,
    prerelease: true,
    assets: [
      {
        name: "OpenClaw-2026.5.2-beta.1.zip",
        browser_download_url:
          "https://github.com/openclaw/openclaw/releases/download/v2026.5.2-beta.1/OpenClaw-2026.5.2-beta.1.zip",
      },
    ],
  },
  {
    tag_name: "v2026.5.2",
    draft: false,
    prerelease: false,
    assets: [
      {
        name: "OpenClaw-2026.5.2.dmg",
        browser_download_url:
          "https://github.com/openclaw/openclaw/releases/download/v2026.5.2/OpenClaw-2026.5.2.dmg",
      },
      {
        name: "OpenClaw-2026.5.2.dSYM.zip",
        browser_download_url:
          "https://github.com/openclaw/openclaw/releases/download/v2026.5.2/OpenClaw-2026.5.2.dSYM.zip",
      },
      {
        name: "OpenClaw-2026.5.2.zip",
        browser_download_url:
          "https://github.com/openclaw/openclaw/releases/download/v2026.5.2/OpenClaw-2026.5.2.zip",
      },
    ],
  },
];

const selection = selectOpenClawRelease(releases);

assert.equal(selection.latestStable.tagName, "v2026.5.3-1");
assert.equal(selection.latestFullPackageableStable.tagName, "v2026.5.2");
assert.equal(selection.latestFullPackageableStable.releaseVersion, "2026.5.2");
assert.equal(
  selection.latestFullPackageableStable.appUrl,
  "https://github.com/openclaw/openclaw/releases/download/v2026.5.2/OpenClaw-2026.5.2.zip",
);
assert.deepEqual(
  selection.skippedStableReleases.map((release) => release.tagName),
  ["v2026.5.3-1", "v2026.5.3"],
);

const none = selectOpenClawRelease([
  {
    tag_name: "v2026.5.3",
    draft: false,
    prerelease: false,
    assets: [],
  },
]);

assert.equal(none.latestStable.tagName, "v2026.5.3");
assert.equal(none.latestFullPackageableStable, null);
assert.deepEqual(none.skippedStableReleases, [
  { tagName: "v2026.5.3", reason: "missing-macos-zip" },
]);

console.log("release selection: ok");
