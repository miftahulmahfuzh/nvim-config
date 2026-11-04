# Plan: Fix the verify-nvim-config findings, purge opencode, upgrade Neovim to 0.12.6

**Slug:** fix-bugs-nvim-0-12
**Date:** 2026-11-04 10:34 (+07)
**Analysis:** `docs/analyzer/20261104-102452-MRDD_code_analyzer.md` (gitignored by `*_code_analyzer.md`; lives in the worktree)
**Worktree:** `/home/miftah/.worktrees/nvim/fix-bugs-nvim-0-12`
**Branch:** `feature/fix-bugs-nvim-0-12` (base: `origin/main` @ `a14aef9`)
**Phases:** 9 (+ the post-land **Deploy** section, run by the coordinator after Step 5 lands the set)
**Status:** planned (reconciled rounds 1-2, 2026-11-04)
**Coordinator:** —

---

## Why

Verbatim from the user:

> Fix every bug the verify-nvim-config pass found, purge opencode, and upgrade Neovim. Unattended: decide everything yourself, record decisions, commit and push to main. No human in the loop.
>
> ANCHOR: ~/.config/nvim is the owner's LIVE config (the nvim they use daily) and a clone of https://github.com/miftahulmahfuzh/nvim-config. It was fast-forwarded to origin/main a14aef9 just before this session. Plan, prove and land from here. ~/nvim-config is another clone of the same repo; leave it alone. When the work lands, ~/.config/nvim's main must equal origin/main again with a clean tree (`git -C ~/.config/nvim fetch origin && git -C ~/.config/nvim merge --ff-only origin/main`; plain `git pull --ff-only` fails in this checkout with "Cannot fast-forward to multiple branches").
>
> PROOF: the repo's skill .claude/skills/verify-nvim-config (read SKILL.md and features/*.md first). Every fix gets a before/after on `verify.sh up --live` (the change on a copy of the live plugins/Mason/lock) AND on `verify.sh up` (seeded), with the failure shown first on the base. Update the matching features/*.md end states in the same change.
>
> BUGS (root causes already found, see the feature files):
> 1. Data loss: lua/custom-autocmd.lua (~line 254) runs `silent %!stylua -` on BufWritePre without checking the exit status; on a Lua syntax error stylua's error text replaces the buffer, and the file on disk when the cursor restore does not throw (repro in features/format-on-save.md: 11-line file -> 3 lines of error text). Format via vim.system with stdin, replace lines only on exit 0, keep the cursor safe, never lose content.
> 2. pyright never starts: after/lsp/pyright.lua sets cmd = { "delance-langserver", "--stdio" }; Mason installs pyright. Make Python buffers get a working server (features/lsp.md).
> 3. lua/plugin_specs.lua: nvim-treesitter has no branch pin, so lazy follows GitHub's default `main` (incompatible with require("nvim-treesitter.configs")); the live lock says master. Pin what the config actually supports (or migrate deliberately) so `:Lazy update`/a fresh install cannot break it.
> 4. phaazon/hop.nvim was deleted from GitHub; switch to the maintained fork smoka7/hop.nvim (same API).
> 5. plugin_specs.lua mason config calls get_package("gofumpt"):install() unconditionally on every start (a reinstall + go install per launch); mason-tool-installer already ensures gofumpt. Remove the per-start reinstall.
> 6. Dashboard: on the start screen ,bg / ,bv save the new art but do not redraw (create_dashboard() never sets ascii_art_win). Make the visible art follow the selection.
> 7. The lazy bootstrap git clone result is unchecked; offline first start dies with E5113 in require("lazy"). Fail gracefully (clear message, rest of init.lua still loads).
>
> ALSO:
> 8. Purge opencode entirely: lua/custom/opencode.lua, its require in lua/config/fzf-lua.lua, any mapping/doc mention; then remove the fake-opencode machinery from the verify skill (verify.sh write_fake_opencode, doctor's opencode line, SKILL.md/features mentions) since nothing will call it.
> 9. Upgrade Neovim to the latest stable release (from github.com/neovim/neovim/releases, nvim-linux-x86_64.tar.gz, verify its sha256). It lives at /opt/nvim-linux-x86_64 (dir owned by miftah, /opt itself root-owned and sudo needs a password: replace the directory's CONTENTS in place, keep a backup of 0.11.5 under ~/.local/opt/). Bump init.lua's expected_version to match, check every plugin still loads on the new version (verify.sh up --live, doctor, the feature journeys), and fix what breaks.
> 10. Fix the verify skill's deploy hint (cmd_live prints `pull --ff-only`, which fails here) to the fetch + merge --ff-only form above.
>
> LANDING: commit with conventional messages, push to main of https://github.com/miftahulmahfuzh/nvim-config, then fast-forward ~/.config/nvim to it and finish with one `verify.sh up --live` + doctor + the format-on-save and lsp journeys from ~/.config/nvim itself. Report each bug's before/after evidence paths.

## Requirements

| ID | What the user asked for | Phases |
|---|---|---|
| R1 | Stylua format-on-save never loses content (`vim.system` + stdin, replace only on exit 0, cursor safe) | 1 |
| R2 | Python buffers get a working pyright server | 2 |
| R3 | nvim-treesitter pinned/migrated so `:Lazy update` or a fresh install cannot break it | 9 |
| R4 | hop.nvim from `smoka7/hop.nvim` | 8 |
| R5 | No per-start `get_package("gofumpt"):install()` | 7 |
| R6 | Dashboard start screen redraws on `,bg` / `,bv` | 3 |
| R7 | Offline first start fails gracefully (clear message, rest of init.lua loads) | 6 |
| R8 | Purge opencode from the config and from the verify skill | 4 |
| R9 | Neovim → latest stable v0.12.6 (sha256-verified, contents replaced in place, 0.11.5 backed up in `~/.local/opt/`), `expected_version` bumped, all plugins load, breaks fixed | 9 (+ Deploy) |
| R10 | verify deploy hint = `fetch` + `merge --ff-only origin/main` | 5 |
| R11 | Land on `main`, fast-forward `~/.config/nvim` clean, final live verify from `~/.config/nvim`, report evidence paths | 9 (evidence index) + Deploy |

Coupling stated: **phase 9 serves R3 and R9 together** because they cannot be split (analysis, Key Considerations 2-4): nvim-treesitter `master` is archived and its textobjects path is broken on 0.12 (`vaf` → `tsrange.lua:27: attempt to call method 'start'`), while nvim-treesitter `main` requires Neovim ≥ 0.12.0. Pinning `master` keeps 0.12 broken; migrating to `main` needs 0.12.

## Scope

**In scope:** the 10 numbered items, the verify-skill changes needed to *prove* them (moved-plugin handling for R3/R4, the opencode fake removal, the hint), feature docs, the Neovim binary swap, and updating the owner's live plugin/Mason/parser state so the landed config works in the nvim the owner actually runs.

**Out of scope:** updating any plugin other than nvim-treesitter, nvim-treesitter-textobjects, hop.nvim and go.nvim (no blanket `:Lazy update`/`sync`); plugin-side deprecation warnings on 0.12 that are not errors (git-conflict.nvim's `vim.highlight`/`vim.validate{}`); `~/nvim-config` (never touched); colorscheme randomness; the owner's tmux server.

## Invariants

1. **The tree loads at the end of every phase**: `verify.sh up` (seeded) prints no startup errors and `doctor` exits 0 (except a WARN the phase documents as the intended end state).
2. **Proof shape for every fix**: failure shown first on the base, then the fix, on **both** `verify.sh up --live` and `verify.sh up`. Procedure: drive the base (before the edit, or with the base file swapped in per execution rule 2; SKILL.md's `git stash` recipe is not used in this set) → `sync` → drive → copy the fix back → `sync` → drive (or `up` twice when a re-seed sits between). Every phase writes its evidence paths into its phase report and into its **own** file `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-N.md`, written after all of its runs are down and committed with the phase; phase 9 builds the set's index `evidence.md` (per-requirement before/after table) from all of them (see § Execution rules).
3. **Nothing outside the worktree is written by phases 1-8.** Phase 9 may write only: the shared verify seed (`verify.sh seed`), `~/.local/opt/` (staging + 0.11.5 backup), and its scratch dirs. **`/opt/nvim-linux-x86_64`, `~/.config/nvim` and `~/.local/share/nvim` are written only by the Deploy section, after the set has landed on `origin/main`.**
4. **Phases 1-8 prove on the installed 0.11.5** (default `NVIM_BIN`). **Phase 9 proves on the staged 0.12.6** via `VERIFY_NVIM=$HOME/.local/opt/nvim-0.12.6/nvim-linux-x86_64/bin/nvim` (exported for every `verify.sh` call, since each invocation reads it).
5. **Re-seeding is serialized**: only phases 8 and 9 run `verify.sh seed`, and the dependency chain puts them in different waves. Phases 1-3 are not ordered against phase 8, so every `seed` is preceded by the **seed guard**: wait until `verify.sh ls` lists no `up` run (a seed rewrites the shared seed under a live seeded run, and that run's `doctor` would FAIL its `seed` line).
6. **The feature docs move with the code**: each phase rewrites the end states of its own `features/*.md` file(s). `features/README.md` ("Known on the base" column and the dated header) and `features/live-environment.md` (its doctor line, `live` end state, journey summary and copy gotchas) are owned by phase 9 only; no other phase edits them except phase 5's two deploy-command mentions in `live-environment.md` (`:13-14` "The owner deploys with ..." and `:43` "Deploying ..."). Every earlier phase's handoff for these files is collected in phase-9.md Step 11.
7. **Conventional commit messages**, one or more commits per phase, scope = area (`fix(format)`, `fix(lsp)`, `fix(dashboard)`, `refactor(opencode)`, `fix(verify)`, `fix(bootstrap)`, `perf(mason)`, `fix(hop)`, `feat(nvim)`/`fix(treesitter)`).
8. **Never `git push` to `main` from a phase.** Landing is the coordinator's Step 5; the Deploy section follows it.

## Execution rules (every phase plan repeats them at its top; they override any command that disagrees)

1. **Own worktree.** Wave 1 (phases 1-4) runs concurrently in separate worktrees/branches merged by
   the integrator. Every command runs from the phase's own worktree root `$WT`
   (`WT=$(git rev-parse --show-toplevel)`); no plan hard-codes a worktree path.
2. **No `git stash`** (its stack is shared by every worktree of the repo). Base/fix swaps copy the fix
   to `SW=$(mktemp -d)`, write the base with `git show "$PHASE_BASE:<path>" ><path>` (`PHASE_BASE` =
   HEAD before the phase's first edit) and copy the fix back.
3. **Pathspec commits**: `git add -- <new files>`, then `git commit -m ... -- <every path>`.
4. **Evidence**: `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-N.md`, one file per phase (no shared
   file, so concurrent phases and the integrator never conflict on it), written only after every run
   of the phase is down (the file is inside the snapshotted tree; a mid-run write makes `doctor`
   print `code WARN`), committed as the phase's last commit `docs(evidence): phase N ...`. Phase 9
   writes `evidence.md` (the index) from all nine. `.workflows/` is tracked: the orchestrator commits
   the plan set before phases start; phases commit only their evidence file (phase 4 also its proof
   script `phase-4-proof.sh`).
5. **Seed guard** before any `verify.sh seed` (phases 8, 9): `until [ -z "$($V ls | awk '$2 == "up"')" ]; do sleep 30; done` via the Monitor tool.

## Phases

| # | Title | Satisfies | Package | Files | Depends on | Difficulty | Plan | TaskID | Card |
|---|-------|-----------|---------|-------|-----------|------------|------|--------|------|
| 1 | Stylua format-on-save without data loss | R1 | `lua/` + verify features | 2 (+ evidence) | — | NORMAL | `.workflows/plan/fix-bugs-nvim-0-12/phase-1.md` | — | — |
| 2 | pyright starts on Python buffers | R2 | `after/lsp` + verify features | 2 (+ evidence) | — | EASY | `.workflows/plan/fix-bugs-nvim-0-12/phase-2.md` | — | — |
| 3 | Dashboard redraw follows the selection | R6 | `lua/config` + verify features | 2 (+ evidence) | — | NORMAL | `.workflows/plan/fix-bugs-nvim-0-12/phase-3.md` | — | — |
| 4 | Purge opencode (config + verify fake) | R8 | `lua/` + verify skill | 5 (+ evidence, proof script) | — | NORMAL | `.workflows/plan/fix-bugs-nvim-0-12/phase-4.md` | — | — |
| 5 | Deploy hint: fetch + merge --ff-only | R10 | verify skill | 3 (+ evidence) | 4 | EASY | `.workflows/plan/fix-bugs-nvim-0-12/phase-5.md` | — | — |
| 6 | Graceful offline lazy bootstrap | R7 | `lua/` + verify skill | 4 (+ evidence) | 5 | NORMAL | `.workflows/plan/fix-bugs-nvim-0-12/phase-6.md` | — | — |
| 7 | Drop the per-start gofumpt reinstall | R5 | `lua/` + verify skill | 4 (+ evidence) | 6 | EASY | `.workflows/plan/fix-bugs-nvim-0-12/phase-7.md` | — | — |
| 8 | hop.nvim → smoka7 fork, verify learns moved plugins | R4 | `lua/` + verify skill | 5 (+ evidence) | 7 | HARD | `.workflows/plan/fix-bugs-nvim-0-12/phase-8.md` | — | — |
| 9 | Neovim 0.12.6 + nvim-treesitter `main` migration | R3, R9, R11 | `lua/`, `init.lua`, `README.md`, verify skill | 12 (+ evidence, `evidence.md` index) | 1, 2, 3, 8 | HARD | `.workflows/plan/fix-bugs-nvim-0-12/phase-9.md` | — | — |

Edges, and why each is true: 5→4 (both edit `verify.sh` near the PATH/sink code and the same SKILL.md "Never driven" bullet); 6→5 (SKILL.md Gotchas and `features/startup.md` neighbourhood; `plugin_specs.lua` chain start); 7→6 (`plugin_specs.lua`, `features/startup.md`, SKILL.md); 8→7 (`plugin_specs.lua`, `seed.lua`, SKILL.md, `verify.sh` cmd_up); 9→8 (uses phase 8's moved-plugin machinery, `plugin_specs.lua`, `seed.lua`) and 9→1,2,3 (phase 9 re-drives every journey on 0.12.6 and rewrites `features/README.md`/`live-environment.md` from the final end states). Phases 1-4 share no file (each writes its own `evidence-phase-N.md`) and run as wave 1. Waves: {1,2,3,4} → 5 → 6 → 7 → 8 → 9 (phases 1-3 may still be running while 5-8 run; invariant 5's seed guard covers the only shared state, the verify seed).

### Phase 1 — Stylua format-on-save without data loss
**Satisfies:** R1
**Owns:** `lua/custom-autocmd.lua` (the `auto_format_lua_on_save` autocmd only), `features/format-on-save.md`, `evidence-phase-1.md`.
**Does not touch:** the Python syntax-check autocmd, go.nvim's formatter, `features/README.md`, `features/live-environment.md`.
**Exit criteria:** on base the syntax-error journey reproduces the 3-line data loss (live + seeded); after the fix the file and buffer keep all 11+1 lines, a warning names the stylua error, the cursor stays put; valid code still formats exactly as before (same end state as the existing "valid code" journey); the "cursor below line 3" variant also keeps content.

### Phase 2 — pyright starts on Python buffers
**Satisfies:** R2
**Owns:** `after/lsp/pyright.lua`, `features/lsp.md`, `evidence-phase-2.md`.
**Does not touch:** `lua/config/lsp.lua`, mason-lspconfig's `ensure_installed`.
**Exit criteria:** base shows pyright `0` clients + the `delance-langserver is not executable` log line; after, `wait` reports `pyright` attached on `app.py` (live + seeded) and `lsp.log` has no `delance` line; settings/capabilities in the file unchanged.

### Phase 3 — Dashboard redraw follows the selection
**Satisfies:** R6
**Owns:** `lua/config/dashboard-nvim.lua`, `features/dashboard.md`, `evidence-phase-3.md`.
**Does not touch:** `ascii_art/*`, `features/lua/dashboard_art.lua` (reuse as is).
**Exit criteria:** base: `,bg` on the start screen → probe `shown=<old> saved=<new>`; after: `shown=<new> saved=<new>` on start screen, split view still works, `,bv` and `,bh` also redraw; a window the user has moved off the dashboard (`e` then `,bg`) is never hijacked.

### Phase 4 — Purge opencode (config + verify fake)
**Satisfies:** R8
**Owns:** delete `lua/custom/opencode.lua`; `lua/config/fzf-lua.lua:4`; `verify.sh` (`write_fake_opencode`, its call, the `sink` dir + `VERIFY_SINK`, doctor's `opencode` line, the opencode words in the PATH comments, `down`'s sink copy/cleanup); `SKILL.md` (doctor list, Evidence paragraph, the opencode sentence(s) in the "Never driven" bullet); `features/fzf-lua.md:29`; `evidence-phase-4.md` + `phase-4-proof.sh`. Also drops the per-run `bin/` dir from PATH and `run_path`'s argument (it only held the fake); no later phase references `bin/`, `sink` or `VERIFY_SINK`.
**Does not touch:** the deploy hint (phase 5), anything tmux.
**Exit criteria:** `git grep -i opencode` in the worktree prints nothing outside `docs/` plan/analysis files and `.workflows/`; base doctor shows the `opencode ok` line, after doctor has no opencode line and exits 0; fzf-lua journey (`,ff` → guide.txt) passes live + seeded.

### Phase 5 — Deploy hint: fetch + merge --ff-only
**Satisfies:** R10
**Owns:** `verify.sh` `cmd_live` deploy line; SKILL.md's "deploying is the owner's ..." sentence (in phase 4's final "Never driven" bullet); `features/live-environment.md`'s two deploy mentions (`:13-14` "The owner deploys with ..." and `:43` "Deploying ..."), nothing else in that file; `evidence-phase-5.md`.
**Exit criteria:** base `verify.sh live` prints `pull --ff-only`; after it prints `git -C ~/.config/nvim fetch origin && git -C ~/.config/nvim merge --ff-only origin/main` (with `$LIVE_CONFIG` expanded); `git grep -n "pull --ff-only"` prints nothing in the skill.

### Phase 6 — Graceful offline lazy bootstrap
**Satisfies:** R7
**Owns:** `lua/plugin_specs.lua` lines 1-18 (grows by 22 lines; later phases anchor on text) and the final `require("lazy").setup` → `lazy.setup` guard; `lua/colorschemes.lua` (`rand_colorscheme` fallback); `features/startup.md` (bare section + gotchas); SKILL.md's `--bare` Gotcha; `evidence-phase-6.md`.
**Exit criteria:** base `up --bare` prints `E5113 ... module 'lazy' not found`; after: no E5113/traceback, one clear message naming the failed clone and how to retry, `diagnostic-conf` loaded (`vim.diagnostic.config()` reflects it), a builtin colorscheme active, `doctor` on the bare run passes its nvim/messages lines as the feature doc states; seeded and `--live` startups unchanged (no new messages).

### Phase 7 — Drop the per-start gofumpt reinstall
**Satisfies:** R5
**Owns:** `lua/plugin_specs.lua` mason spec `config` (base ~521-529, found by text); `seed.lua`'s "installed by the config's own startup install" special case and comment; `features/startup.md` Mason paragraphs/gotcha; SKILL.md "Downloads are the seed's job" bullet; `evidence-phase-7.md`.
**Exit criteria:** base: `mason.log` shows `Executing installer for Package(name=gofumpt)` after a plain start (live + seeded); after: no gofumpt installer line on start, `mason/bin/gofumpt` still present, go format-on-save journey still turns `var x = a+b` into `x := a + b`.

### Phase 8 — hop.nvim → smoka7 fork, verify learns moved plugins
**Satisfies:** R4
**Owns:** `lua/plugin_specs.lua` hop spec; `seed.lua` pin loop (MOVED = spec branch differs from the lock entry's, or spec url differs from the entry's `url`; a moved plugin follows the spec) and the new `seed lock` step (writes `{branch, commit, url}` per plugin to `SEED_LOCK_OUT`); `verify.sh` `origin_url`, the `PLUGIN_EXTRA_DATA` hook, `cmd_seed` lock handling and `cmd_up` live branch (replace a *moved* plugin from the seed; `replaced_from_seed`, `evidence/00-up-replaced.txt`); SKILL.md seed/live bullets and the hop + "lazy never re-targets" Gotchas; the hop `f`/`F` journey as a section of `features/editing-mappings.md` (no `hop.md`); re-seed (behind the seed guard); `evidence-phase-8.md`.
**Exit criteria:** base: `git ls-remote https://github.com/phaazon/hop.nvim` fails and the seed log carries `WARN plugin hop.nvim: clone failed ... copied from the live dir`; after: re-seed logs exactly one `MOVED plugin hop.nvim` and no hop WARN, seed lock `hop.nvim` = smoka7 commit with the smoka7 `url`, a second seed pins it without MOVED, `up --live` lists `replaced_from_seed=hop.nvim` (only), and pressing `f` shows hop hints and jumps (live + seeded).

### Phase 9 — Neovim 0.12.6 + nvim-treesitter `main` migration
**Satisfies:** R3, R9, R11 (evidence index)
**Owns:** staging 0.12.6 in `~/.local/opt/nvim-0.12.6/` (download, sha256 `474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87`), backup of 0.11.5 to `~/.local/opt/nvim-0.11.5/`; `init.lua` expected_version; `README.md` badge; `lua/plugin_specs.lua` treesitter/textobjects specs + `tree-sitter-cli` in mason-tool-installer; `lua/config/treesitter.lua`, `lua/config/treesitter-textobjects.lua`; go.nvim bump to `4755def` (seed lock `commit` only); `seed.lua` treesitter step (after Mason, tree-sitter-cli first, stale `master` parser cleanup); `verify.sh` on top of phase 8's machinery (`PLUGIN_EXTRA_DATA[nvim-treesitter]="site/parser site/parser-info site/queries"`, `seed_commit_unknown_to_live` as one more clause in phase 8's replacement test, live copy of `site/`, repoint after a replacement); re-seed (behind the seed guard); all journeys on 0.12.6; `features/README.md`, `features/live-environment.md` (all but phase 5's two deploy mentions), `features/startup.md` version line + Mason bullet, SKILL.md treesitter/`VERIFY_NVIM` text on top of phase 8's bullets, new `features/treesitter.md`; `evidence-phase-9.md` and the set's index `evidence.md`; the Deploy runbook (phase-9.md § Deploy runbook).
**Does not touch:** `/opt/nvim-linux-x86_64`, `~/.config/nvim`, `~/.local/share/nvim` (Deploy owns them).
**Exit criteria:** base on staged 0.12.6: `vaf` → `tsrange.lua:27` E5108 (live + seeded), and a fresh install following GitHub's default branch breaks `require("nvim-treesitter.configs")`; after: specs pin `branch = "main"` for both, highlight active on lua/go/python/markdown, `vaf`/`vif`/`vac`/`vic` select, `gnn`/`grn`/`grm` selection works through 0.12's built-ins, `=` indents, go.nvim loads, no errors in `:messages`, every journey in features/*.md passes on 0.12.6 live + seeded (hop's in `editing-mappings.md`), no version warning; `--live` before Deploy lists exactly `nvim-treesitter nvim-treesitter-textobjects hop.nvim go.nvim` in `replaced_from_seed` with the three `site/` paths in `00-up-replaced.txt`; `evidence.md` has a path in every R1-R10 cell.

## Deploy (after land) — run by the coordinator after Step 5 pushes `main`

This is part of R9/R11 and is **not optional**: the landed config requires 0.12.6 and nvim-treesitter `main`, so `~/.config/nvim` is only correct once all of these are done, in this order, from a bash shell (not the deleted worktree). The exact commands, each with its assertion and rollback, are phase-9.md § "Deploy runbook" (D0-D8); this is the summary and the two must agree:

0. **Preconditions (D0)**: staged 0.12.6 and backup 0.11.5 present; `/opt` still 0.11.5; `~/.config/nvim` clean and fast-forwardable; **`origin/main` carries the landed set** (its `init.lua` expects 0.12.6, its specs name `smoka7/hop.nvim` and `branch = "main"`, its `.workflows/.../evidence.md` exists); the seed lock (phase 8's `{branch, commit, url}` format) holds the 4 targets and the seed dirs are at those commits.
1. **Backup (D1)** to `~/.local/opt/deploy-backup-<date>/`: `lazy-lock.json`, the 4 plugin dirs, `site/` if any, the config HEAD.
2. **Swap the binary in place (D2)**: `find /opt/nvim-linux-x86_64 -mindepth 1 -delete` then `cp -a <staged>/. /opt/nvim-linux-x86_64/`; assert `--version` = v0.12.6.
3. **Fast-forward the config (D3)**: `git -C ~/.config/nvim fetch origin && git -C ~/.config/nvim merge --ff-only origin/main`; assert HEAD == origin/main and `git status --porcelain` empty. **Everything below runs after this merge**, on the landed config.
4. **Live plugins (D4)**: for each of the 4 plugins, `remote set-url origin <seed lock url>` (hop: phaazon → smoka7), fetch the lock branch, check out the lock commit (plain git, not `Lazy! restore`, so no `build` hook runs half-way); write the 4 seed lock entries into `~/.config/nvim/lazy-lock.json` (gitignored); assert HEAD and raw origin url per dir; remove the stale `lazy/nvim-treesitter/{parser,parser-info}` left from `master`.
5. **Mason + parsers (D5, D6)**: install `tree-sitter-cli` into the live Mason (headless, synchronous), then the 13 parsers synchronously into `~/.local/share/nvim/site`; assert every `.so` and a single `parser/python.so` on the runtimepath.
6. **Final proof from `~/.config/nvim` (D7)**: `verify.sh live` (0 commits behind, fetch + merge deploy line), `up --live` (no startup errors, `replaced_from_seed` empty), `doctor`, the format-on-save journeys (valid; syntax error keeps 11 lines + stylua WARN in nvim-notify), the lsp journey (lua_ls, gopls, pyright) and `vaf`; `~/.config/nvim` still clean afterwards.
7. **Report (D8)**: assertions re-checked; the run report `~/.local/state/nvim-config-verify/deploy-<date>.md` (outside the repo, so the checkout stays clean) plus the per-bug before/after paths from `.workflows/plan/fix-bugs-nvim-0-12/evidence.md` on `origin/main`.

If any assertion in D2-D7 fails: the full rollback (D6 → D2: parsers/site from backup, Mason tool optional, plugin dirs + lock from backup, `git -C ~/.config/nvim reset --keep <pre-deploy HEAD>`, binary from `~/.local/opt/nvim-0.11.5`), then report.

## Reconciliation Log

| # | Conflict (class) | Phases | Resolution |
|---|---|---|---|
| 1 | File collision: all nine phases appended to one `.workflows/.../evidence.md`, while wave 1 runs concurrently in separate worktrees (merge conflicts at integration) | 1-9 | Each phase writes its own `evidence-phase-N.md` after its runs are down and commits it as its last commit; phase 9 builds `evidence.md` (the index) from all nine. Execution rule 4, invariant 2, every phase's Files/Steps/Proof edited. |
| 2 | Contract drift: plans disagreed on whether `.workflows/` is committed (phases 1/9 "coordinator state, not committed", 2/7 committed it, 3/6 "check") | 1-9 | `.workflows/` is tracked (the orchestrator commits the plan set); every phase commits its evidence file; phase 4 also commits its proof script. |
| 3 | Unmet assumption: plans hard-coded the set worktree path for `cd`, evidence and phase 4's proof script, but wave 1 runs in separate worktrees | 1-9 | Replaced with `$WT` (the phase's own `git rev-parse --show-toplevel`); phase 4's script resolves its root from `$0`. Execution rule 1. |
| 4 | Collision: phases 1, 2, 3, 5, 6, 7 swapped base/fix with `git stash`/`stash pop`; the stash stack is shared across worktrees, so concurrent phases could pop each other's stash | 1-3, 5-7 | Base/fix swap through a per-phase `mktemp` copy and `git show "$PHASE_BASE:<path>"`. Execution rule 2; each proof rewritten. |
| 5 | Collision (shared index race): `git add` + bare `git commit` | 1-9 | Pathspec commits (`git commit -m ... -- <paths>`), execution rule 3; phase 2's commit (its `--` stood before `-m`) fixed. |
| 6 | Unmet assumption + duplicate work: phase 9 Step 7d/7e was written against an *assumed* phase 8 loop and added a second `site/` fill loop + meta key `site_filled_from_seed` beside phase 8's `PLUGIN_EXTRA_DATA` hook | 8, 9 | Phase 9 Step 7 rewritten on phase 8's final code (quoted): `PLUGIN_EXTRA_DATA[nvim-treesitter]="site/parser site/parser-info site/queries"`, `seed_commit_unknown_to_live` as one extra clause in phase 8's test line, live `site/` copy, `repoint_data "$dir" "$SEED/data"` after a replacement. The fill loop and `site_filled_from_seed` are gone from Step 7, SKILL.md/live-environment.md/treesitter.md text, J1 and D7. |
| 7 | Contract drift: phase 9 Step 8 rewrote go.nvim's seed lock entry as `{branch, commit}`, dropping phase 8's `url` | 8, 9 | `jq '."go.nvim".commit = "4755def…"'` keeps `branch` and `url`; stage-1 expectations name phase 8's `MOVED plugin nvim-treesitter` / `-textobjects` lines and no hop MOVED. |
| 8 | Later phase quotes pre-change state: phase 9 Step 12 targeted base SKILL.md bullets ("lazy ignores a lock entry ...", seed `:41`) that phase 8 replaced | 8, 9 | Step 12 rewritten as exact old/new blocks of phase 8's final text (seed bullet, live bullet, "lazy never re-targets" clause), anchored on text. |
| 9 | Contract drift: Deploy D4 took the url from `git remote get-url` (applies the owner's `insteadOf`, so hop's live origin would become `git@github.com:...` and look "moved" forever); D0/D8 checked urls the same way | 9 | D4 uses the seed lock's `url` field (phase 8's format) for `set-url`; every url check uses raw `git config --get remote.origin.url`. |
| 10 | Contract drift: Deploy D7 expected `12` lines and a stylua warning in `:messages`; phase 1's end state is `11` lines with the WARN in nvim-notify, not `:messages` | 1, 9 | D7 asserts `11` / `local x = = 1` and reads `require("notify").history()`; gopls/pyright waits use phase 2's 90 s. |
| 11 | Gap: Deploy D7 "append every evidence path to `evidence.md` row R11" would write a tracked file inside `~/.config/nvim` after the fast-forward, breaking R11's clean tree | 9, Deploy | The Deploy report goes to `~/.local/state/nvim-config-verify/deploy-<date>.md`; `evidence.md`'s R11 row points there; D7/D8 assert the checkout is still clean. |
| 12 | Gap: runbook D7/D8 had no rollback line; D7's `! grep` assertion is ignored by `set -e`; D0 did not check the set had landed | 9, Deploy | D7/D8 rollbacks stated (a failed D7 assertion triggers the full rollback); `! grep` replaced by `if ...; then exit 1; fi`; D0 asserts `origin/main` carries the set. |
| 13 | Ordering hazard on shared state: phase 8 re-seeds while wave-1 phases 1-3 may still have seeded runs up (their `doctor` would FAIL `seed`) | 1-3, 8, 9 | Seed guard before every `seed` (wait until `verify.sh ls` lists no `up` run): invariant 5, execution rule 5, phase 8 J2/J3, phase 9 Step 8. No new DAG edge. |
| 14 | Contract drift: the index let phase 8 write `features/hop.md` "or" an `editing-mappings.md` section; phase 9 kept a conditional `hop.md` README row and listed `hop.md` in Leaves alone / J11 | 8, 9 | Phase 8 chose `editing-mappings.md`. Phase 9's README has no hop row; the Editing mappings row covers hop `f`/`F`; J11 and Leaves alone point at `editing-mappings.md`. |
| 15 | Gap: phase 9 rewrote only `live-environment.md:28-31`, leaving phase 5's handoff (the `live` end state and doctor line still quote `d7bf9fe`/`24ff768`) unowned; invariant 6 named one phase-5 line while phase 5 edits two | 5, 9 | Phase 9 Step 11 owns `:21`, `:24-26`, `:28-31`, `:39-40`; phase 5 owns `:13-14` and `:43`; invariant 6 updated. |
| 16 | Unowned handoffs into phase 9's docs (from phases 1-8) | 1-9 | Collected as a checklist in phase-9.md Step 11: README cells (format, LSP, dashboard, fzf-lua, startup, editing mappings/hop, treesitter), live-environment (stylua/pyright clauses, `live` end state, `replaced_from_seed`, `site/`), startup.md Mason bullet names `tree-sitter-cli` (phase 7's handoff). |
| 17 | Later phase quotes pre-change state: phase 5's SKILL.md step hedged "phase 4 may wrap its tail differently" | 4, 5 | Phase 5 uses phase 4's quoted final bullet as its `old_string`. |
| 18 | Contract drift: phase 9 Step 1 "proved" a fresh install lacks `configs.lua` with `ls` on a scratch clone that may not exist; its durable logs lived in a session scratchpad under `/tmp` | 9 | Step 1 clones upstream's default branch into `$P9/upstream` first and asserts it is `main`; phase 9 evidence lives in `~/.local/state/nvim-config-verify/phase9-evidence/`. |
| 19 | Deleted-then-used check: phase 4 removes `$dir/bin`, `sink/`, `VERIFY_SINK`, `write_fake_opencode` and `run_path`'s argument | 4-9 | Verified: no later phase references them (phase 8 anchors on text and notes the removal; phase 9 states it). No change. |
| 20 | Sequential edits of `plugin_specs.lua`, `seed.lua`, `verify.sh`, `SKILL.md`, `startup.md` (4→5→6→7→8→9) | 4-9 | Checked: phases 7, 8, 9 anchor every hunk on text (phase 6's +22 lines noted); phase 8's `cmd_up`/`cmd_seed` hunks avoid phase 4's lines; phase 9's seed.lua Change B anchors after phase 8's `seed lock` step and before phase 7's Mason step text. |
| 21 | Coverage check | all | Every R1-R11 has an owning phase; no step serves an `R` outside its phase's Satisfies line; every analysis Impact Point (1-15) and Reference List row is owned (`utils.is_compatible_version` and go.nvim's dependency line need no change). |
| 22 | Round 2, hard-coded path: phase 9 Step 0 wrote its download into the planning session's scratchpad (`/tmp/claude-1000/.../scratchpad/dl`), a dir the phase session does not own | 9 | `DL=$P9/dl`; the planning session's verified tarball is only read (copied if readable), else downloaded; sha256 checked either way. |
| 23 | Round 2, contract drift (comment vs code): phase 9 Step 7c adds the `site/` copy but phase 8's `live)` header comment still says "Only lazy/, mason/ and rplugin.vim" | 8, 9 | Step 7c also updates that comment to name `site/`. |
| 24 | Round 2 check: phase 9 Step 7 quotes vs phase 8's final `verify.sh` (`declare -A PLUGIN_EXTRA_DATA=()`, `origin_url`, the `cp -a lazy mason` / `rplugin.vim` pair, the test line `[ "$sb" != "${lb:-$sb}" ] \|\| [ "$su" != "$lu" ] \|\| continue`, the `done` / `flock -u 9` / `fi` tail); Step 11/12 old text vs phases 5, 7, 8 and the base `live-environment.md`/`startup.md`; Deploy D0-D8 vs the index Deploy section and phase 8's `{branch, commit, url}` lock; forbidden references (`git stash`, shared `evidence.md` writes, `$dir/bin`, `sink`, worktree paths); R1-R11 ownership | 1-9, Deploy | Verified, no change: every quoted block matches verbatim (Step 12 (c)/(d) old blocks are line-prefix substrings of phase 8's text, so an exact-substring edit applies); every D step asserts and has a rollback; after D3 only the gitignored `lazy-lock.json` (D4) is written inside `~/.config/nvim` and D4/D7/D8 assert a clean tree; remaining `sink`/`$dir/bin`/`git stash` mentions are phase 4's removal steps or prohibitions; every R maps to its phase as in the Requirements table. |

## Decisions

| Fork | Chosen | Rung |
|---|---|---|
| R3: pin nvim-treesitter `master` vs migrate to `main` | migrate both nvim-treesitter and textobjects to `main` in phase 9 | 5: user's raw input (R3 allows "migrate deliberately"; R9 says "fix what breaks") + measured: `master` textobjects break on 0.12 and `master` is archived |
| R3 incremental selection (`gnn`/`grn`/`grc`/`grm`) on `main` (plugin dropped it) | keep `gnn` (n) / `grn` (x, grow) / `grm` (x, shrink) mapped onto 0.12's built-in `an`/`in` treesitter selection; drop `grc` (scope_incremental, no built-in equivalent) | 6: surrounding convention (keep the owner's keys working where the platform offers it) |
| R3 parser installs need `tree-sitter` CLI | add `tree-sitter-cli` to mason-tool-installer's `ensure_installed` (Mason v0.27.1 satisfies `main`'s ≥0.26.1) | 6: convention (Mason already supplies every other tool) |
| go.nvim's unguarded `nvim-treesitter.*` requires: upstream master `5622d97` vs `4755def` | bump go.nvim to `4755deffda8eeb0ceed53b535cce29f0e29a640a` (the newest main-aware commit that runs on the live guihua.lua `ef44ba4`) through the seed lock's `commit` only; not master, which needs `guihua.ts_utils` and would make guihua.lua a fifth moved plugin | 1: stated scope invariant "only nvim-treesitter, -textobjects, hop.nvim and go.nvim move" (Scope; measured in phase-9.md Facts) |
| R1 stylua argv | keep `{ "stylua", "-" }` run in nvim's cwd (same config resolution as today); only error handling changes | 1: invariant "no behaviour change beyond the bug" (keeps the valid-code end state byte for byte) |
| R1 on stylua failure | keep the buffer untouched, write proceeds with the user's text, `vim.notify` WARN with stylua's first stderr line | 5: user's raw input "never lose content" |
| R6 which windows redraw | every window showing a dashboard buffer (start screen and split); a window no longer showing the dashboard buffer is never touched | 5: user's raw input "make the visible art follow the selection" |
| R7 colorscheme with no plugins | `rand_colorscheme` falls back to a builtin scheme when the picked one errors | 5: user's raw input "rest of init.lua still loads" |
| R4 hop pin | plain `"smoka7/hop.nvim"` (lock pins the commit), no `version` | 6: convention (other specs are unpinned) |
| Proving R3/R4 on `--live` when live has the old plugin | verify.sh replaces a plugin from the seed when the seed lock's branch or origin url differs from live's, and says so (`replaced_from_seed`) | 2: exit criteria require `--live` proofs |
| When the binary and live plugins change | only in the Deploy section, after land; phase 9 proves on a staged binary via `VERIFY_NVIM` | 1: invariant 3 (the owner's nvim never runs a half-landed state) |
| Owner's already-running nvim processes during the swap | accepted: they keep the old binary inode; lazily-sourced runtime files may come from 0.12.6 until restarted | 5: user's raw input (replace contents in place; no sudo) |
| Live plugin update breadth | only the 4 plugins the set moves/bumps, never `sync`/`update` all | 6: convention (out of scope: other plugins) |
| How Deploy moves the 4 live plugins (incl. hop's url change): `Lazy! restore` vs plain git | plain git: `remote set-url origin <seed lock url>`, fetch the lock branch, check out the lock commit, then write the seed lock entries into the live lock; no `build` hook runs (`:TSUpdate` needs the CLI D5 installs; `:GoUpdateBinaries` would be cut off by `+qa`) | 3: plan code blocks (phase-9.md D4 and its measured reasons) |
| Which url Deploy and verify compare | the raw `remote.origin.url` (`git config --get`), taken from the seed lock's `url` field; never `git remote get-url` (applies the owner's `insteadOf`) | 3: plan code blocks (phase 8's `origin_url`/`norm` boundary rule) |
| Parsers/queries on `--live`: phase 9's own fill loop + `site_filled_from_seed` vs phase 8's `PLUGIN_EXTRA_DATA` hook | the hook: `PLUGIN_EXTRA_DATA[nvim-treesitter]="site/parser site/parser-info site/queries"`, copied when nvim-treesitter is replaced, then `repoint_data "$dir" "$SEED/data"`; no fill loop, no new meta key | 3: plan code blocks (phase 8's contract names it "the hook phase 9 uses") |
| go.nvim's commit-only bump on `--live` (not a branch/url move) | one extra clause `seed_commit_unknown_to_live` in phase 8's replacement test | 2: phase 9 exit criteria (go.nvim before/after shown on `--live`) |
| Where evidence lives | one `evidence-phase-N.md` per phase, committed with the phase; `evidence.md` index written by phase 9; `.workflows/` tracked | 4: index Phases (wave 1 concurrent in separate worktrees) + 6: convention (the orchestrator commits the plan set) |
| Where the Deploy run's evidence lives | `~/.local/state/nvim-config-verify/deploy-<date>.md`, never inside `~/.config/nvim` | 5: user's raw input ("`~/.config/nvim`'s main must equal origin/main again with a clean tree") |
| Base/fix swap in proofs | per-phase `mktemp` copy + `git show "$PHASE_BASE:<path>"`; never `git stash` | 6: convention (swarm rules: the stash stack is shared across worktrees) |
| Re-seed while wave-1 runs may be up | seed guard (wait until no run is up) instead of new DAG edges 8→{1,2,3} | 1: invariants 1 and 5 (`doctor` exits 0 for every phase; seeding serialized) |
| Deploy order: binary swap before or after the config fast-forward | D2 swap, then D3 `fetch` + `merge --ff-only origin/main`, then every config-dependent step (plugins, Mason, parsers, proof) after D3; D0 asserts `origin/main` already carries the set | 4: index Deploy section order; the intermediate "0.12.6 + old config" is the measured base (loads, only `vaf` broken), while "0.11.5 + new config" would break treesitter |
| Version warning between land and Deploy | accepted: `init.lua` expects 0.12.6 from land on, but the owner's checkout only receives it at D3, after D2 swapped the binary, so the warning shows only if the owner pulls by hand before Deploy; Deploy runs immediately after land | 1: invariant 3 (binary and live state change only in Deploy, after land) |

## Open Questions

None.

## Rollback

- **Per phase (before land):** `git revert` the phase's commits on the feature branch (its `evidence-phase-N.md` commit may stay as history). Phases 8/9 also re-seed; `verify.sh seed` again after the revert restores the seed's plugins (the seed is verify state, not the owner's).
- **After land, before Deploy:** `git revert -m 1 <merge>` on `main` and push.
- **After Deploy:** restore `/opt/nvim-linux-x86_64` contents from `~/.local/opt/nvim-0.11.5/nvim-linux-x86_64/` (`find ... -mindepth 1 -delete; cp -a`), restore `~/.config/nvim/lazy-lock.json`, the 4 plugin dirs and `~/.local/share/nvim/site` (removed if the backup has none) from `~/.local/opt/deploy-backup-<date>/`, `git -C ~/.config/nvim reset --keep "$(cat ~/.local/opt/deploy-backup-<date>/config-head.txt)"` (= `a14aef9` today; or merge the revert). Exact commands: phase-9.md § Deploy runbook, "Full rollback".

## Next

Run the whole set as a swarm — a session per phase, concurrent wherever `Depends on` allows; after Step 5 lands it, run the Deploy section above:

    /analyze-orchestrator -f docs/plans/FIX_BUGS_NVIM_0_12_PLAN.md

Or execute the phases one at a time, starting at phase 1:

    /implement -f docs/plans/FIX_BUGS_NVIM_0_12_PLAN.md --phase 1
