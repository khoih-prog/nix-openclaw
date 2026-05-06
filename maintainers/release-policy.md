# Release Policy

`nix-openclaw` publishes one user-facing package, `openclaw`, with component outputs for maintainers and modules.

## Desired State

- `openclaw-gateway` tracks the newest stable upstream OpenClaw source release that satisfies the Nix package contract.
- `openclaw-app` tracks the newest stable upstream release that has a published public `OpenClaw-*.zip` app artifact.
- These tracks are independent. Source and app versions may differ.

## Non-Negotiables

- Do not hold back the source-built gateway because a newer source release lacks public macOS app assets.
- Do not treat source/app version mismatch as a failure.
- Do not make upstream's full Vitest suite a promotion gate; upstream owns source test health.
- Do verify the Nix-owned package contract: source build, generated config options, package contents, gateway smoke startup, module activation, and newest available public macOS app artifact.
- Do prefer the upstream `.zip` app artifact for `openclaw-app`, but verify the unpacked contents contain an `.app`.

## Freshness Check

The package is fresh only when both are true:

- `nix/sources/openclaw-source.nix` matches GitHub's newest stable OpenClaw source tag.
- `nix/packages/openclaw-app.nix` matches the newest stable public `OpenClaw-*.zip` app artifact.

If newer stable source releases lack public app assets, report that as an upstream app publishing miss and keep the app pin on the newest public zip.
