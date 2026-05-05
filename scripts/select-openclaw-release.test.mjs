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
assert.equal(selection.latestStableSource.tagName, "v2026.5.3-1");
assert.equal(selection.latestStableSource.releaseVersion, "2026.5.3-1");
assert.equal(selection.latestMacAppStable.tagName, "v2026.5.2");
assert.equal(selection.latestMacAppStable.releaseVersion, "2026.5.2");
assert.equal(
  selection.latestMacAppStable.appUrl,
  "https://github.com/openclaw/openclaw/releases/download/v2026.5.2/OpenClaw-2026.5.2.zip",
);
assert.deepEqual(
  selection.appLagStableReleases.map((release) => release.tagName),
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
assert.equal(none.latestStableSource.tagName, "v2026.5.3");
assert.equal(none.latestStableSource.releaseVersion, "2026.5.3");
assert.equal(none.latestMacAppStable, null);
assert.deepEqual(none.appLagStableReleases, [
  { tagName: "v2026.5.3", reason: "missing-macos-zip" },
]);

console.log("release selection: ok");
