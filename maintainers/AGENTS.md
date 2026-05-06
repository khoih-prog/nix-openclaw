# Maintainer Agent Guide

This directory is public maintainer guidance for agents working on `nix-openclaw`.
It is not consumer setup documentation and must not contain private deployment state.

## Boundaries

- Keep consumer onboarding in `README.md`, templates, and module docs.
- Keep private deployments, bots, hosts, local worktrees, tokens, and personal automation details out of this repo.
- If a private deployment exposes a public packaging bug, fix the public package here and keep deployment-specific repair elsewhere.
- Treat `README.md` as the product direction source of truth.

## Read Order

1. `packaging.md` for Nix-owned package invariants.
2. `release-policy.md` for the split-track publishing invariant.
3. `automation.md` for the maintainer repair loop.
4. `gates.md` for verification and CI expectations.
5. Root `AGENTS.md` for repo-wide rules.

## Maintainer Workflow

- Work on `main` by default and push small, surgical commits directly to `main` when maintainer policy allows it.
- Use branches only when a maintainer asks, direct push is blocked, or a disposable local experiment is needed.
- For multi-issue work, commit and push one issue at a time, then verify GitHub Actions for that pushed commit before continuing.
- Do not leave completed maintainer work parked on an agent branch.
- No force push. No weakening package checks just to get green.
