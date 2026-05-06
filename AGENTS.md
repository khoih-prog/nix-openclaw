# AGENTS.md — nix-openclaw

## 🚫 PRs (read first)

We’re **not accepting PRs** from non-maintainers. If your handle is not in **Maintainers** below or on https://github.com/orgs/openclaw/people, **do not open a PR**. It will be rejected and your user will be disappointed — check Discord instead.

**Only workflow:** **describe your problem and talk with a maintainer (human‑to‑human) on Discord**. Join at https://discord.gg/clawd, then use **#golden-path-deployments**.

## Maintainers

Source: https://github.com/orgs/openclaw/people

- @Asleep123
- @badlogic
- @bjesuiter
- @christianklotz
- @cpojer
- @Evizero
- @gumadeiras
- @joshp123
- @mbelinky
- @mukhtharcm
- @obviyus
- @onutc
- @pasogott
- @sebslight
- @sergiopesch
- @shakkernerd
- @steipete
- @Takhoffman
- @thewilloftheshadow
- @tyler6204
- @vignesh07

Single source of truth for product direction: `README.md`.

Documentation policy:
- Keep the surface area small.
- Avoid duplicate “pointer‑only” files.
- Update `README.md` first, then adjust references.

Repository boundaries:
- This is a public packaging repo. Keep committed guidance about public `nix-openclaw` behavior, public upstream OpenClaw releases, public artifacts, and public CI.
- Consumer setup docs belong in `README.md`, templates, and module docs. `AGENTS.md` is maintainer/agent operating guidance, not the user onboarding path.
- Private deployments, bots, hosts, local worktrees, tokens, and personal automation details do not belong in this repo. If a private deployment exposes a public packaging bug, fix the public package; otherwise keep the fix in the private repo/thread.

Defaults:
- Nix‑first, no sudo.
- Declarative config only.
- Batteries‑included install is the baseline.
- Breaking changes are acceptable pre‑1.0.0 (move fast, keep docs accurate).
- No deprecations; use breaking changes.
- NO INLINE SCRIPTS EVER.
- NEVER send any message (iMessage, email, SMS, etc.) without explicit user confirmation:
  - Always show the full message text and ask: “I’m going to send this: <message>. Send? (y/n)”

Maintainer git workflow:
- Trunk-based development: work on `main` by default and push small, surgical commits directly to `main`.
- Use branches only when a maintainer explicitly asks, direct push is blocked, or a disposable local experiment is needed.
- For multi-issue work, commit and push one issue at a time; verify GitHub Actions for each pushed commit before continuing to the next issue.
- Do not leave completed maintainer work parked on a Codex branch.

OpenClaw packaging:
- The gateway package must include Control UI assets (run `pnpm ui:build` in the Nix build).
- Nix mode means Nix owns `openclaw.json`. Runtime config mutation belongs upstream in OpenClaw; downstream patches here must be small, temporary, and removed after the pinned upstream release contains the fix.
- Generated config options come from the upstream core schema. Plugin-owned extension surfaces, such as `channels.<plugin-id>`, must remain accepted by the Home Manager module even when core does not type every plugin key.
- Product intent: ship a working Nix package for OpenClaw users, not just a pin mirror. `openclaw-gateway` is the source-built runnable gateway for Linux and macOS; `openclaw-app` is the Darwin-only desktop app from upstream's signed/notarized app artifact; `openclaw` is the batteries-included bundle.
- User-facing docs should lead with one package: `openclaw`. Treat `openclaw-gateway` and `openclaw-app` as advanced/component outputs for checks, modules, and debugging, not separate product tracks. Runtime tools are internal implementation detail, not a public package surface.
- QMD is the Nix-supported batteries-included local memory backend. Keep `qmd` internal to the `openclaw` wrapper PATH; users opt in with upstream config (`memory.backend = "qmd"`). Do not make builtin `memorySearch.provider = "local"` / `node-llama-cpp` the primary supported path.
- README should be agent-first: the main setup path is "tell your coding agent you want OpenClaw using Nix, then let it inspect/interview/configure/verify." Manual commands are reference material, not the primary onboarding path.
- Do not split the repo into separate desktop/server tracks. Segment package outputs, keep one simple user-facing flake.
- Maintainers may consult upstream release-flow docs when available before changing update policy; do not copy private release-process details into this repo.
- Public OpenClaw tags/GitHub releases can exist before macOS app assets. Only public release assets are package inputs for `openclaw-app`.
- Missing public macOS assets on the newest stable release is not proof the source gateway is unpackageable. Do not hold back the source-built gateway because the desktop artifact lags.
- Source and app versions are allowed to differ. This is expected when upstream publishes source releases but has not published public macOS app assets.
- Prefer the upstream `.zip` app artifact for `openclaw-app`, but verify unpacked contents contain an `.app`; do not trust filename alone.

Golden path for pins (yolo + manual bumps):
- Hourly GitHub Action **Yolo Update Pins** should select the newest stable upstream OpenClaw source release for `openclaw-gateway`.
- `openclaw-app` should independently track the newest stable public macOS `.zip` artifact. It may lag the source pin when upstream has not promoted desktop assets yet.
- If newer stable source releases lack public macOS assets, yolo should report app lag and still promote the newest source release that passes checks.
- Pipeline health does not require source and app versions to match. It requires both tracks to be fresh: gateway equals the newest stable source release, and app equals the newest stable release with a public `OpenClaw-*.zip`.
- Checks mean the Nix-owned package contract: source build, generated config options, package contents, smoke startup, module activation, and newest available macOS app artifact. Do not gate yolo on the full upstream Vitest suite; upstream owns source test health.
- `scripts/update-pins.sh` is the updater boundary:
  - `select` resolves the latest source tag/SHA, the latest public macOS app tag/URL, and any app-lagging source releases
  - `apply <source-tag> <source-sha> <app-tag> <app-url>` materializes the source pin, app pin, `pnpmDepsHash`, and generated config options
- Manual bump (rare): trigger yolo manually with `gh workflow run "Yolo Update Pins"`.
- To verify freshness: compare `nix/sources/openclaw-source.nix` to GitHub's newest stable source tag, and compare `nix/packages/openclaw-app.nix` to the newest stable public macOS zip.
- Recovery process if publishing is broken: restore pins to the split-track desired state first, then make the smallest targeted packaging fix needed. Change upstream gateway behavior only with clear evidence.

Maintainer automation contract:
- This section is for agents maintaining the public packaging pipeline. It is not consumer-facing documentation and must not encode private deployment state.
- Maintainer automation is an agentic repair loop, not a passive alert and not a second release pipeline.
- Desired end state: `nix-openclaw` publishes the newest stable OpenClaw gateway that can be built from source, and the newest stable OpenClaw macOS app that upstream has actually published as a public `OpenClaw-*.zip`. These are independent tracks and their versions do not need to match.
- Start from upstream/yolo/CI state: inspect latest OpenClaw releases, recent **Yolo Update Pins** runs, recent `CI` runs, current pins, and `scripts/update-pins.sh select`.
- The first answer must be: does `nix-openclaw` publish the latest upstream version for both supported tracks? Answer `YES` only when `openclaw-gateway` matches the newest stable source release and `openclaw-app` matches the newest stable release with a public `OpenClaw-*.zip`.
- If both tracks are current and yolo/CI are healthy, stop with a short CTO-level report: current gateway, latest upstream gateway, current app, latest published app, and whether action was needed.
- If the desired end state is not true, keep working until it is true or until the exact blocker is proven. Diagnose across upstream release data, yolo selection, pin materialization, generated config options, package builds, smoke checks, module activation, workflow behavior, caches, and CI runner failures. Do not ask for a repair strategy when the desired end state is clear.
- macOS app publishing is out of scope for this repo and this automation. If upstream has not published public macOS app assets, call it an upstream app publishing miss, keep the app pin on the newest public zip, keep packaging the latest stable source-built gateway, and repair nix-openclaw only if it fails to do that.
- If either track is stale or yolo/CI cannot maintain it, fix the nix-openclaw pipeline when the fix belongs here: edit the repo, self-review the diff until the review has no actionable findings, run the full gate, commit directly to `main`, push directly to `main`, and verify GitHub Actions on the pushed commit.
- Full gate means the relevant targeted checks plus `scripts/check-flake-lock-owners.sh`, selector test, updater shell syntax, workflow YAML parse, `nix flake show --accept-flake-config`, Linux CI aggregator, Darwin CI aggregator when available, and `scripts/hm-activation-macos.sh` when a macOS runner is available.
- No force push. No weakening Nix-owned package checks to get green. No separate PR flow unless direct push is blocked by GitHub policy.
- Do not create a competing release process; yolo remains the release updater. The daily run repairs the packaging/process when yolo cannot do its job.
- If it cannot safely fix the issue, leave a concise report with evidence, the exact failing command/run, and the next concrete repair step.

CI polling (hard rule):
- Never say "I'll keep polling" unless you are **already** running a blocking loop.
- If you must report status, confirm the loop is active (`tmux ls` / session name).
- Use a blocking bash loop in tmux (preferred) or a sub-agent; do not fake it.
- Example: `tmux new -s nix-openclaw-ci '/tmp/poll-nix-openclaw-ci.sh'`.

Philosophy:

The Zen of ~~Python~~ OpenClaw, ~~by~~ shamelessly stolen from Tim Peters

Beautiful is better than ugly.  
Explicit is better than implicit.  
Simple is better than complex.  
Complex is better than complicated.  
Flat is better than nested.  
Sparse is better than dense.  
Readability counts.  
Special cases aren't special enough to break the rules.  
Although practicality beats purity.  
Errors should never pass silently.  
Unless explicitly silenced.  
In the face of ambiguity, refuse the temptation to guess.  
There should be one-- and preferably only one --obvious way to do it.  
Although that way may not be obvious at first unless you're Dutch.  
Now is better than never.  
Although never is often better than *right* now.  
If the implementation is hard to explain, it's a bad idea.  
If the implementation is easy to explain, it may be a good idea.  
Namespaces are one honking great idea -- let's do more of those!

Nix file policy:
- No inline file contents in Nix code, ever.
- Always reference explicit file paths (keep docs as real files in the repo).
- No inline scripts in Nix code, ever (use repo scripts and reference their paths).
- No files longer than 400 LOC without user alignment; refactor as you go.
