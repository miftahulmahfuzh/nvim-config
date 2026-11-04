# Code Analysis: Neovim 0.12.6 config: zero warnings, deprecations and errors

**Type:** Bug Investigation (plus a sweep)
**Date:** 2026-11-04 12:14 (Asia/Jakarta)
**Session ID:** 20261104-121422-N12C
**Plan:** `.workflows/plan/NVIM_0_12_CLEAN_PLAN.md` (4 phases + post-land Deploy)
**Worktree:** `/home/miftah/.worktrees/nvim/nvim-0-12-clean`, branch `feature/nvim-0-12-clean` (base `origin/main` @ `8bcb55c`)

---

## User Input

### Original User Request

```
Make the freshly deployed Neovim 0.12.6 config fully clean: no warnings, deprecations or errors left. Unattended: decide everything yourself, record decisions, commit and push to main. No human in the loop.

CONTEXT: ~/.config/nvim is the owner's LIVE config (clone of github.com/miftahulmahfuzh/nvim-config), now at origin/main 8bcb55c, running /opt/nvim-linux-x86_64 = v0.12.6 since the fix-bugs-nvim-0-12 set landed today (merge edb8b0c; plan docs/plans/FIX_BUGS_NVIM_0_12_PLAN.md and evidence .workflows/plan/fix-bugs-nvim-0-12/ on main). ~/nvim-config no longer exists. Work in a worktree off origin/main, never edit ~/.config/nvim directly; at the end fast-forward it with: git -C ~/.config/nvim fetch origin && git -C ~/.config/nvim merge --ff-only origin/main (clean tree after). Any live plugin/Mason change goes the way fix-bugs-nvim-0-12's Deploy runbook D4 did (backup first under ~/.local/opt/, plain git to the seed lock's {branch,commit,url}, lazy-lock.json updated), only after land.

PROOF: .claude/skills/verify-nvim-config (read SKILL.md and features/*.md). Every fix gets before/after on verify.sh up --live and verify.sh up (nvim 0.12.6 is now the default binary), failure shown first; update the matching features/*.md end states.

KNOWN LEFTOVERS (from that set's reports):
1. verify.sh sync respawns nvim with the caller's PATH instead of run_path (repro run ~/.local/state/nvim-config-verify/1104-112534-2226714).
2. ':messages' shows a plugin's 'client.request is deprecated' warning on 0.12.6. Find the plugin, fix (bump/replace/config).
3. A CursorHold diagnostic open_float 'Invalid width' error was seen once (phase 9's key sweep, not reproduced by a clean journey). Reproduce or prove it gone.
4. git-conflict.nvim's vim.highlight / vim.validate{} deprecation warnings on 0.12.
5. v:errmsg holds 'E216: No such group or event: FileExplorer *' after startup.
6. Sweep for anything else: :checkhealth (esp. vim.deprecated, lazy, mason, nvim-treesitter, lsp), :messages after every features/*.md journey, every plugin loads, deprecation notices in nvim-notify history. Fix what is real; record what is upstream-only and why.
Finish with one verify.sh up --live + doctor from ~/.config/nvim after the fast-forward showing :messages and checkhealth clean, and report each item's before/after evidence paths.
```

### User-Provided Context
- Live config `~/.config/nvim` @ `8bcb55c` (= `origin/main`), binary `/opt/nvim-linux-x86_64` = v0.12.6.
- Prior set: `docs/plans/FIX_BUGS_NVIM_0_12_PLAN.md`, `.workflows/plan/fix-bugs-nvim-0-12/` (Deploy runbook D0-D8 in `phase-9.md:1150-1330`).

### User-Provided Files
None marked with `@`. Named: `.claude/skills/verify-nvim-config/SKILL.md`, `features/*.md`, the prior plan.

### Requirement IDs

| ID | What the user asked for |
|---|---|
| R1 | `verify.sh sync` respawns nvim with `run_path`, not the caller's PATH |
| R2 | No `client.request is deprecated` in `:messages`: find the plugin, fix it |
| R3 | CursorHold diagnostic `open_float` "Invalid 'width'": reproduce or prove gone |
| R4 | No git-conflict.nvim `vim.highlight` / `vim.validate{}` deprecations on 0.12 |
| R5 | `v:errmsg` empty after startup (no `E216: ... FileExplorer *`) |
| R6 | Sweep: checkhealth, `:messages` after every journey, every plugin loads, nvim-notify history; fix what is real, record what is upstream-only and why |
| R7 | Unattended: decisions recorded, land on `main`, push, live plugin changes D4-style after land, fast-forward `~/.config/nvim` clean, final `up --live` + doctor from it showing `:messages` and checkhealth clean, every item's before/after evidence paths reported |

---

## Detailed Requirements Understanding

**Problem statement.** The landed 0.12.6 config is functionally correct but noisy: one harness bug (R1), two
plugins calling APIs 0.12 deprecated (R2 blink.cmp, R4 git-conflict.nvim), one config autocmd that crashes in a
narrow window (R3), one plugin option that leaves a stale `v:errmsg` (R5), plus checkhealth findings of
mixed origin (R6). Each needs a measured before (failure first) and after, in both run modes.

**Success criteria.**
- `:messages` empty after startup and after every `features/*.md` journey, live and seeded.
- `vim.v.errmsg == ""` after startup.
- `:checkhealth vim.deprecated` has zero warnings; `lazy`, `mason-lspconfig`, `nvim-treesitter`, `vim.treesitter`,
  `hop`, `lspconfig` stay ✅; `go` has no ❌; `vim.health` has no true-colour warning; `fidget` no warning.
  Every remaining WARNING/ERROR in the full `:checkhealth` is in a recorded allow-list with its reason
  (environment-only: optional tools not installed, the run's network fence; or upstream-only).
- `verify.sh sync` keeps `vim.env.PATH == run_path`, and `doctor` FAILs when it does not.
- Owner's live environment matches after Deploy; `~/.config/nvim` == `origin/main`, clean.

**Key considerations / assumptions.**
- "Clean" checkhealth cannot mean zero warnings overall: snacks/fzf-lua/mason/which-key/diffview report optional
  tools the owner never installed (kitty, lazygit, fd, viu, hg, cargo, php, julia...). Inference: clean = no
  finding caused by this config or fixable from it; the rest are listed with their reason (R6 "record what is
  upstream-only and why").
- The harness's run PATH deliberately excludes per-user dirs; but the owner's nvim sees the Go tools in
  `~/.gvm/pkgsets/go1.25.7/global/bin`. Without them the run cannot judge go.nvim's health honestly.

---

## Analysis Scope

### Discovered Related Files
- `.claude/skills/verify-nvim-config/scripts/verify.sh` (775 lines): `run_path` `:94`, `run_env` `:110`,
  `start_nvim_cmd` `:228`, `cmd_up` tmux start `:406`, `cmd_doctor` `:455`, `cmd_sync` `:642` (`respawn-pane` `:656`).
- `lua/plugin_specs.lua`: blink.cmp `:50-62` (`version = "v0.*"`, `build = "cargo build --release"`),
  git-conflict.nvim `:383-390` (`version = "*"`), nvim-tree `:495-501`, fidget `:503-508`, snacks `:474-490`.
- `lua/config/blink-cmp.lua` (v0 option shape, incl. `cmdline.sources = { default, providers }`).
- `lua/config/git-conflict.lua` (setup + `User GitConflictResolved` → `GitConflictListQf`).
- `lua/config/nvim-tree.lua:51-52` (`disable_netrw = false`, `hijack_netrw = true`), `:79` `hijack_directories`.
- `lua/globals.lua:47-48` (`vim.g.loaded_netrw = 1`, `vim.g.loaded_netrwPlugin = 1`).
- `lua/diagnostic-conf.lua:47-64` (CursorHold → `diagnostic.open_float({ width = 100 })`).
- `lua/config/fidget-nvim.lua` (`require("fidget").setup {}`).
- `.tmux.conf.local:18` (`tmux_conf_24b_colour=auto`); `.tmux.conf:887-912` (oh-my-tmux `_apply_24b`).
- Runtime: `/opt/nvim-linux-x86_64/share/nvim/runtime/lua/vim/lsp/util.lua:1537-1600,1760`,
  `.../vim/health/health.lua:356-366`.
- Plugins (live `~/.local/share/nvim/lazy`): blink.cmp `485c034` (v0.14.x), git-conflict.nvim `v2.1.0`
  (`4bbfdd9`), nvim-tree.lua `3fb91e1`, go.nvim `4755def`.
- Upstream clones (scratch, read-only reference):
  `/tmp/claude-1000/-home-miftah--config-nvim/bcfe6938-f07b-47fb-8dea-f4d06c1251b6/scratchpad/up/{blink.cmp,git-conflict.nvim,nvim-tree.lua,gc-stryukovsky,gc-seblyng,gc-konradmalik}`.

---

## Current Dataflow (per finding)

### R1: `sync` PATH leak
`cmd_up` starts the tmux server under `setsid unshare -n $(run_env)` (`:406`), so the first pane's nvim gets
`run_path`. `cmd_sync` (`:656`) runs `tmx "$dir" respawn-pane -k ... "$(start_nvim_cmd)"` from the **caller's**
shell. tmux (3.x `spawn.c`) takes `PATH` from the issuing client's environment when that client has no session,
so the respawned nvim gets the caller's PATH. `start_nvim_cmd` is `$NVIM_BIN --listen <sock>`: no env.
`cmd_doctor` has no PATH check (phase 4 of the prior set removed the opencode line that used to expose it).

Measured (live run `1104-121901-2809686`): `evidence/16-lua-vim.env.PATH.txt` (before sync: mason/bin,
`/opt/nvim-linux-x86_64/bin`, miniconda, node, `~/.gvm/gos/go1.25.7/bin`, `~/.fzf/bin`, system dirs) vs
`evidence/17-lua-vim.env.PATH.txt` (after: `~/.opencode/bin`, `~/.gvm/pkgsets/...` ...: the caller's).
Doctor after the sync: all ok (no line catches it). Original repro: `1104-112534-2226714`.

Also measured: `run_path` includes the dirs of `$PY $NODE $GO fzf rg jq ctags` only; go.nvim's tools
(`golangci-lint`, `gomodifytags`, `impl`, `dlv`, `goimports`, ... 19 of them) live in
`~/.gvm/pkgsets/go1.25.7/global/bin` (= the caller's `go env GOPATH`/bin), which the owner's nvim sees and the
run does not. Result in the run: `:checkhealth go` ❌ `Failed to run healthcheck for "go" plugin. Exception:
vim/_core/system:324: ENOENT ... 'golangci-lint'` + 19 "Missing tool" warnings (go.nvim `health.lua:58` calls
`vim.system` without an executable check: an upstream crash, triggered only by the fence).

### R2: `client.request is deprecated`
blink.cmp spec `version = "v0.*"` → live `485c034` (v0.14.x, 2025-03-24).
`blink/cmp/sources/lsp/completion.lua:17` and `sources/lsp/init.lua:90` call `client.request(...)` (dot form,
deprecated in 0.12 in favour of `client:request`). Trigger: any LSP completion in insert mode.
Measured (live run `1104-121455-2789754`): `:messages` empty after LSP attach on go/lua/py
(`evidence/09-lua-...messages`), then `G o` + typing `vim.` in `sample.lua` → screen
`evidence/15-screen-screen.txt` last line `client.request is deprecated. Run ":checkhealth vim.deprecated"...`.
Upstream v1.10.2 (`78336bc89ee5365633bcf754d93df01678b5c08f`) uses `client:request` (`completion.lua:37`,
`init.lua:99`). Other dot-callers found (`nvim-ufo`, `fzf-lua`, `snacks`, `nvim-colorizer`, `lazydev`) are
version-guarded or only reached on paths the phase 4 sweep exercises.

blink v1 differences that touch `lua/config/blink-cmp.lua`: `cmdline.sources` is a list/function in v1 (the
config passes `{ default = ..., providers = ... }`), providers live under `sources.providers`; the prebuilt fuzzy
library is downloaded for a release tag (`fuzzy.prebuilt_binaries`), `cargo` is not on the run's PATH.

### R3: CursorHold `open_float` "Invalid 'width'"
`diagnostic-conf.lua:47-64`: on CursorHold, if the buffer has diagnostics and the cursor moved, call
`diagnostic.open_float({ width = 100 })`. 0.12.6 `lsp/util.lua:_make_floating_popup_size` computes
`width = min(width, nvim_win_get_width(0) - border_width)`; the float border is `single` (2 cols), so in a window
≤2 columns wide width ≤ 0 and `nvim_open_win` (`util.lua:1760`) throws. Not upstream-fixable from here; the
config must not call it in a window that narrow.
**Reproduced deterministically** (live run `1104-121901-2809686`): `sample.lua`, paste `x = undefined_thing`
(lua_ls diagnostic), `:2vsplit`, `k j`, `h` → `evidence/14-screen-screen.txt` (traceback through
`diagnostic-conf.lua:61`, "Press ENTER"). Earlier sighting: `1104-114633-2535931/evidence/messages-at-down.txt:6-12`.

### R4: git-conflict.nvim deprecations
Spec `akinsho/git-conflict.nvim`, `version = "*"` → tag `v2.1.0`. Upstream's last commit is `a1badcd`
(2024-12-27); master still has `vim.highlight.priorities.user` (`git-conflict.lua:111`) and
`vim.validate({ rgb_24bit = {...} })` (`colors.lua:12`). `:checkhealth vim.deprecated` (live run
`1104-121901-2809686`, `evidence/03-lua-...`) lists exactly these two, both from git-conflict
(`git-conflict.lua:109`, `colors.lua:12`), reached from `lua/config/git-conflict.lua:3` at VeryLazy.
They do not show in `:messages` (first-use deprecations from a `VeryLazy` load are only in the health report).
Forks inspected: `stryukovsky/git-conflict.nvim` commit `63c5b427038d85b20c32a25c7f3bd502241ce869`
("chore: resolve deprecation stuff") = upstream `a1badcd` + exactly `vim.hl`, positional `vim.validate`, and
`vim.diagnostic.enable(false, {bufnr})` (the last also on the Resolved path, a bug only when
`disable_diagnostics = true`, which this config does not set). Every caller of `shade_color` passes a non-nil
number (defaults applied first), so the now-required validate cannot fire. Later fork commits add notify
messages and nested-repo logic (behaviour changes). `seblyng/...` (41d5297) and `konradmalik/...` are rewrites
that drop `GitConflictListQf` and the `User GitConflictResolved` event this config's autocmd uses.
Because forks carry upstream's tags, `version = "*"` on any fork resolves to the old `v2.1.0`.

### R5: `E216: No such group or event: FileExplorer *`
nvim-tree is loaded by startup (`package.loaded["nvim-tree"]` true right after `up`, despite `keys`).
`config/nvim-tree.lua` sets `hijack_netrw = true` → nvim-tree's `manage_netrw` runs
`silent! autocmd! FileExplorer *` and a `VimEnter ++once` copy. `silent!` hides the message but still sets
`v:errmsg`, and the group never exists because `globals.lua:47-48` disables netrw before any plugin loads.
Upstream nvim-tree `69eb0c3` (2026-11-03) does the same (`lua/nvim-tree/config.lua:535-536`): config-side fix.
`hijack_directories` stays enabled when `disable_netrw = true` (nvim-tree: disabled only if both are false).
Measured: live run `1104-121455-2789754` `evidence/01-lua-vim.v.errmsg.txt`.

### R6: checkhealth sweep (live run `1104-121901-2809686`, `evidence/03-lua-...` 3589 lines)

| Section | Finding | Origin | Disposition |
|---|---|---|---|
| vim.deprecated | `vim.highlight`, `vim.validate{}` | git-conflict.nvim | R4 |
| go | ❌ exception (golangci-lint ENOENT) + 19 missing tools | run fence (tools in `~/.gvm/pkgsets/.../global/bin`) + go.nvim health crash | R1 phase adds the Go tool dir to `run_path`; crash recorded upstream |
| fidget | `nvim-tree.lua integration is implicitly enabled` (removal planned) | config | set it explicitly |
| vim.health | True colour not detected in tmux | `.tmux.conf.local:18` `tmux_conf_24b_colour=auto` + owner has no `COLORTERM` (owner's tmux: `client_termfeatures` lacks RGB, `terminal-overrides` empty) | `tmux_conf_24b_colour=true` (adds `*256col*:Tc`) |
| vim.lsp | 6 "Unknown filetype" (gotmpl, javascript.jsx, typescript.tsx, yaml.docker-compose, yaml.gitlab, yaml.helm-values) | nvim-lspconfig default `filetypes` | upstream-only, record |
| vim.provider | PyPI unreachable | run's network fence | environment-only, record |
| snacks | lazygit, kitty/wezterm/ghostty, magick, gs, mmdc, fd, notifier not ready, `regex`/`latex` parsers | optional tools / disabled modules (config enables only input + picker) | environment-only, record |
| mason | cargo, luarocks, composer, php, javac, julia | optional toolchains | environment-only, record |
| fzf_lua | viu, chafa, ueberzugpp | optional previewers | environment-only, record |
| diffview | `hg` not executable | optional | environment-only, record |
| targets | `iB`, `ab`, `ib` conflicts with text_obj#Buffer / vim-sandwich | owner's deliberate mappings | intentional, record (no behaviour change) |
| which-key | 14 overlap notices | informational by design (its own text says so) | record |
| blink.cmp | "Some providers may show up as disabled" | informational, always printed | record (re-check on v1) |
| lazy, lspconfig, mason-lspconfig, nvim-treesitter, vim.treesitter, hop, vim.pack | ✅ | | keep |

`:messages` after startup: empty (live, `00-up-messages.txt`). nvim-notify history after startup: `{}`.
The journeys of `features/*.md` and "every plugin loads" are not yet swept: the phase 4 sweep does them.

### R7: deploy path
Prior Deploy runbook D4 (`.workflows/plan/fix-bugs-nvim-0-12/phase-9.md:1248-1290`): per plugin, `remote set-url
origin <seed lock url>`, fetch the lock branch, `checkout <commit>`, assert HEAD and raw `remote.origin.url`,
merge the seed lock entries into `~/.config/nvim/lazy-lock.json` (gitignored), assert a clean tree; backups
under `~/.local/opt/deploy-backup-<date>/`; report under `~/.local/state/nvim-config-verify/deploy-<date>.md`.
`verify.sh up --live` replaces a plugin whose spec moved (url/branch change, or a seed-lock commit unknown to the
live clone) from the seed: git-conflict (url change) and blink.cmp (seed-lock bump) will both be
`replaced_from_seed` until Deploy. `~/.tmux.conf.local` is a separate regular file, currently byte-identical to
the repo's `.tmux.conf.local`; the owner's tmux server must never be contacted (SKILL.md).

---

## Reference List

| Symbol / key | File:line | Kind |
|---|---|---|
| `run_path` | verify.sh:94 | def |
| `run_env` | verify.sh:110 | def (callers :146 :384 :406 :419 :612 :634) |
| `start_nvim_cmd` | verify.sh:228 | def (callers :408 :656) |
| `respawn-pane` | verify.sh:656 | call (the leak) |
| `cmd_doctor` | verify.sh:455 | def |
| `saghen/blink.cmp` spec | lua/plugin_specs.lua:50-62 | config |
| blink setup | lua/config/blink-cmp.lua | config |
| `akinsho/git-conflict.nvim` spec | lua/plugin_specs.lua:383-390 | config |
| git-conflict setup / autocmd | lua/config/git-conflict.lua | config |
| `hijack_netrw` / `disable_netrw` | lua/config/nvim-tree.lua:51-52 | config |
| `loaded_netrw*` | lua/globals.lua:47-48 | config |
| CursorHold float | lua/diagnostic-conf.lua:47-64 | config |
| fidget setup | lua/config/fidget-nvim.lua | config |
| `tmux_conf_24b_colour` | .tmux.conf.local:18 | config |
| feature docs | .claude/skills/verify-nvim-config/features/{startup,lsp,git,live-environment,tmux-bindings,README}.md | doc |
| SKILL.md run PATH / sync / doctor text | .claude/skills/verify-nvim-config/SKILL.md | doc |

## Impact Points (files that WILL need changes)
1. `verify.sh` (`cmd_sync`, `run_path`, `cmd_doctor`), `SKILL.md`, `features/startup.md` — phase 1.
2. `lua/config/nvim-tree.lua`, `lua/diagnostic-conf.lua`, `lua/config/fidget-nvim.lua`, `features/lsp.md`,
   `features/startup.md` (after phase 1) — phase 2.
3. `lua/plugin_specs.lua`, `lua/config/blink-cmp.lua`, `lua/config/git-conflict.lua`, seed lock + re-seed,
   `features/git.md`, `features/lsp.md` (after phase 2) — phase 3.
4. `.tmux.conf.local`, new `features/health.md`, `features/README.md`, `features/live-environment.md`,
   `features/tmux-bindings.md`, the set's evidence index and the Deploy runbook — phase 4.

**This document describes. The plan files prescribe.**
