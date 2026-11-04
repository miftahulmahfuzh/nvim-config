# Plan: Neovim 0.12.6 config: zero warnings, deprecations and errors

**Slug:** nvim-0-12-clean
**Date:** 2026-11-04 12:14 (Asia/Jakarta)
**Analysis:** `.workflows/analyze/20261104-121422-N12C_code_analyzer.md`
**Worktree:** `/home/miftah/.worktrees/nvim/nvim-0-12-clean`
**Branch:** `feature/nvim-0-12-clean` (base: `origin/main` @ `9cea538`; cut at `8bcb55c`, rebased onto `9cea538` fix(startup) ensure_cwd, which touches `lua/custom-autocmd.lua` and `features/startup.md` "Deleted working directory")
**Phases:** 4 (+ the post-land **Deploy** section, run by the coordinator after it lands the set)
**Status:** planned
**Coordinator:** —

---

## Why

Verbatim from the owner:

> Make the freshly deployed Neovim 0.12.6 config fully clean: no warnings, deprecations or errors left. Unattended: decide everything yourself, record decisions, commit and push to main. No human in the loop.
>
> CONTEXT: ~/.config/nvim is the owner's LIVE config (clone of github.com/miftahulmahfuzh/nvim-config), now at origin/main 8bcb55c, running /opt/nvim-linux-x86_64 = v0.12.6 since the fix-bugs-nvim-0-12 set landed today (merge edb8b0c; plan docs/plans/FIX_BUGS_NVIM_0_12_PLAN.md and evidence .workflows/plan/fix-bugs-nvim-0-12/ on main). ~/nvim-config no longer exists. Work in a worktree off origin/main, never edit ~/.config/nvim directly; at the end fast-forward it with: git -C ~/.config/nvim fetch origin && git -C ~/.config/nvim merge --ff-only origin/main (clean tree after). Any live plugin/Mason change goes the way fix-bugs-nvim-0-12's Deploy runbook D4 did (backup first under ~/.local/opt/, plain git to the seed lock's {branch,commit,url}, lazy-lock.json updated), only after land.
>
> PROOF: .claude/skills/verify-nvim-config (read SKILL.md and features/*.md). Every fix gets before/after on verify.sh up --live and verify.sh up (nvim 0.12.6 is now the default binary), failure shown first; update the matching features/*.md end states.
>
> KNOWN LEFTOVERS (from that set's reports):
> 1. verify.sh sync respawns nvim with the caller's PATH instead of run_path (repro run ~/.local/state/nvim-config-verify/1104-112534-2226714).
> 2. ':messages' shows a plugin's 'client.request is deprecated' warning on 0.12.6. Find the plugin, fix (bump/replace/config).
> 3. A CursorHold diagnostic open_float 'Invalid width' error was seen once (phase 9's key sweep, not reproduced by a clean journey). Reproduce or prove it gone.
> 4. git-conflict.nvim's vim.highlight / vim.validate{} deprecation warnings on 0.12.
> 5. v:errmsg holds 'E216: No such group or event: FileExplorer *' after startup.
> 6. Sweep for anything else: :checkhealth (esp. vim.deprecated, lazy, mason, nvim-treesitter, lsp), :messages after every features/*.md journey, every plugin loads, deprecation notices in nvim-notify history. Fix what is real; record what is upstream-only and why.
> Finish with one verify.sh up --live + doctor from ~/.config/nvim after the fast-forward showing :messages and checkhealth clean, and report each item's before/after evidence paths.

## Requirements

| ID | What the user asked for | Phases |
|---|---|---|
| R1 | `verify.sh sync` respawns nvim with `run_path`, not the caller's PATH | 1 |
| R2 | No `client.request is deprecated` (blink.cmp v0.14 → v1) | 3 (live dirs moved by Deploy D3, under R7) |
| R3 | CursorHold diagnostic `open_float` "Invalid 'width'": reproduce and fix | 2 |
| R4 | No git-conflict.nvim `vim.highlight` / `vim.validate{}` deprecations | 3 (live dirs moved by Deploy D3, under R7) |
| R5 | `v:errmsg` empty after startup (no E216 FileExplorer) | 2 |
| R6 | Sweep: checkhealth, `:messages` after every journey, every plugin loads, notify history; fix real, record upstream-only | 1 (Go tools on run PATH), 2 (fidget), 4 (tmux true colour, render-markdown latex/yaml, sweep, allow-list) |
| R7 | Unattended land + push, D4-style live changes after land, fast-forward `~/.config/nvim`, final `up --live` + doctor clean, evidence paths per item | 4 (evidence index + Deploy runbook; run by the coordinator after land) |

## Scope

**In scope:** the five known leftovers; config-side checkhealth findings (fidget implicit integration, tmux true colour,
render-markdown latex/yaml enabled without parsers);
the run PATH gaps that make the harness misjudge go.nvim's health; a recorded allow-list for every remaining
environment-only / upstream-only checkhealth line; Deploy of the two plugin moves and `~/.tmux.conf.local`.

**Out of scope:** installing optional tools the owner never installed (lazygit, fd, kitty, viu, hg, cargo, php,
julia, mmdc, gs, magick); changing the owner's deliberate mappings (`targets` / vim-sandwich `ib`/`ab`, `iB`,
which-key overlaps); a blanket `:Lazy update`; plugins other than blink.cmp and git-conflict.nvim; contacting the
owner's tmux server.

## Invariants

1. **Every phase leaves the config working**: startup `:messages` has no new error, every journey in
   `features/*.md` that passed at `8bcb55c` still passes, live and seeded.
2. **Failure first**: every fix records a before (on the base, the failure) and an after, on `verify.sh up --live`
   **and** `verify.sh up`, with evidence paths in the phase's `.workflows/plan/nvim-0-12-clean/evidence-phase-N.md`.
3. **Nothing outside the worktree is written by phases 1-4**, except: `~/.local/state/nvim-config-verify/` (runs,
   evidence) and, by **phase 3 only**, the shared verify seed (`verify.sh seed`, its lock). `~/.config/nvim`,
   `~/.local/share/nvim`, `~/.tmux.conf.local` and `/opt/nvim-linux-x86_64` are written only by the Deploy
   section, after the set has landed on `origin/main`. The owner's tmux server is never contacted.
4. **Feature docs move with the code**: each phase rewrites the end states of the `features/*.md` files it owns
   (see each phase's Owns). `features/README.md`, `features/live-environment.md` and the new `features/health.md`
   are phase 4's.
5. **No user-visible behaviour change beyond the fixes**: completion keymaps (`<Tab>`, `<S-Tab>`, `<Enter>`,
   `<C-U>`, `<C-D>`, `<C-E>`, `<Esc>`, cmdline completion), git-conflict mappings (`co`, `ct`, `cb`, `c0`, `]x`,
   `[x`), `GitConflictListQf` + the `User GitConflictResolved` qf refresh, nvim-tree's directory hijack
   (`nvim <dir>`), and the diagnostic float in normal-width windows all behave as before.
6. **Never `git push` to `main` from a phase.** Landing is the coordinator's; the Deploy section follows it.
7. The colorscheme is random per start: never assert its name.

## Phases

| # | Title | Satisfies | Package | Files | Depends on | Difficulty | Plan | TaskID | Card |
|---|-------|-----------|---------|-------|-----------|------------|------|--------|------|
| 1 | verify.sh: sync keeps run_path, doctor checks PATH, Go tools on run PATH | R1, R6 | verify skill | 4 | — | NORMAL | `.workflows/plan/nvim-0-12-clean/phase-1.md` | — | — |
| 2 | Config-side fixes: E216, CursorHold width, fidget integration | R5, R3, R6 | `lua/` | 6 | 1 | EASY | `.workflows/plan/nvim-0-12-clean/phase-2.md` | — | — |
| 3 | Plugin moves: blink.cmp v1, git-conflict deprecation-free fork | R2, R4 | `lua/` + verify skill + seed | 9 (+ seed lock, outside the repo) | 2 (and 1) | HARD | `.workflows/plan/nvim-0-12-clean/phase-3.md` | — | — |
| 4 | Sweep, tmux true colour, health allow-list, evidence index, Deploy runbook | R6, R7 | verify skill + tmux + `lua/plugin_specs.lua` (render-markdown `opts`) | 12 | 3 | NORMAL | `.workflows/plan/nvim-0-12-clean/phase-4.md` | — | — |

Phases run strictly sequentially 1 → 2 → 3 → 4. Edges are true dependencies: 2 needs 1's `sync` (its stash/sync
before-after recipe would otherwise run nvim on the caller's PATH) and edits `features/startup.md` after 1; 3 edits
`verify.sh` and `SKILL.md` on top of 1's hunks, edits `features/lsp.md` after 2, and takes its before runs on 1+2
(`cmd_seed` builds its own PATH, so the seed itself does not need 1's `run_path`); 4 edits `lua/plugin_specs.lua`
after 3 (another spec) and sweeps the result of all three.

Shared files and their order (one owner per region): `verify.sh` 1 (`run_path`, `run_path_of`, `start_nvim_cmd`,
meta, doctor, sync comment) → 3 (`seed_commit_unknown_to_live` → `live_lacks_seed_commit`, `cmd_up` live comment +
caller); `SKILL.md` 1 (run-PATH paragraph, sync paragraph, doctor `path` bullet) → 3 (Launch **live** bullet,
Gotchas nvim-treesitter bullet); `features/startup.md` `9cea538` "Deleted working directory" → 1 (PATH subsection)
→ 2 (`v:errmsg` subsection), each directly before `## Gotchas`; `features/lsp.md` 2 (CursorHold, fidget) → 3
(completion), each directly before `## Gotchas`; `lua/plugin_specs.lua` 3 (blink.cmp, git-conflict specs) → 4
(render-markdown `opts`). `features/README.md`, `live-environment.md`, `tmux-bindings.md`, `health.md`: 4 only.

### Phase 1 — verify.sh: sync keeps run_path, doctor checks PATH, Go tools on run PATH
**Satisfies:** R1, R6 (go health judged on the owner's tool set)
**Owns:** `verify.sh`: `start_nvim_cmd` prints `env PATH=<run_path_of DIR> <nvim> --listen <sock>` (one command
for `up` and `sync`; `respawn-pane -e PATH=` does not work, see Decisions); new `run_path_of DIR` (meta
`run_path=`, else `run_path`); `cmd_up` writes `run_path=` into meta; a new doctor `path` line (FAIL when nvim's
`vim.env.PATH`, minus Mason's prepended `<data>/mason/bin` and go.nvim's appended `$HOME/go/bin`, differs from the
run's `run_path=`); `run_path`'s tool list gains `golangci-lint` (go.nvim's tool dir, the "each tool by its own
directory" rule); the `cmd_sync` comment. `SKILL.md`: a run-PATH paragraph (Launch), the sync paragraph, the doctor
`path` bullet. `features/startup.md`: new `### The run's PATH (up, sync, doctor)` after `9cea538`'s "Deleted working
directory", before `## Gotchas`. `evidence-phase-1.md`.
**Does not touch:** `lua/`, the seed, `seed.lua`, `seed_commit_unknown_to_live` and `cmd_up`'s live block, the SKILL.md
**live** bullet and nvim-treesitter Gotcha (phase 3), any other `features/*.md`; `run_env` stays on `run_path`.
**Exit criteria:** before (base script from `9cea538`, both modes): `vim.env.PATH` after `sync` = caller's PATH,
doctor exit 0 with no `path` line, `:checkhealth go` ERROR + `Missing tool`; after: identical PATH before/after
`sync` equal to Mason's bin + meta `run_path`, doctor `path ok`; a fault-injected PATH gives doctor `path FAIL`,
exit 1; `:checkhealth go` has no ERROR and no "Missing tool" in either mode; `gofumpt`/`gopls` resolve to Mason's;
Go format-on-save diff unchanged; `--bare` doctor exit 0 with `path ok`; every journey still passes.

### Phase 2 — Config-side fixes: E216, CursorHold width, fidget integration
**Satisfies:** R5, R3, R6 (fidget)
**Owns:** `lua/config/nvim-tree.lua` (`disable_netrw = true`, `hijack_netrw = false`; netrw is already off in
`globals.lua`), `lua/diagnostic-conf.lua` CursorHold callback (skip `open_float` when the window has fewer than 3
columns; `width = 100` unchanged, no config-side cap: the runtime already caps to window − border),
`lua/config/fidget-nvim.lua` (`setup { notification = { window = { avoid = { "NvimTree" } } } }`, then
`package.loaded["fidget.integration.nvim-tree"].options.enable = false`, guarded), `features/lsp.md` (new
`### CursorHold diagnostic float` incl. the `:2vsplit` repro, `### fidget health`, both before `## Gotchas`),
`features/startup.md` (`### v:errmsg after startup and the directory hijack`, after phase 1's subsection, before
`## Gotchas`), `evidence-phase-2.md`.
**Does not touch:** `verify.sh`, `SKILL.md`, `plugin_specs.lua`, the seed, `lua/globals.lua`, `lua/custom-autocmd.lua`,
phase 1's startup.md subsection.
**Exit criteria:** before/after both modes (stash/`sync` recipe): `v:errmsg` `E216...` → `""`; `:2vsplit` repro →
traceback "Invalid 'width'" → no error, `floats = 0`, `diagnostics_pos` updated in the 2-col window, and a width-100
float in the full-width window; `:checkhealth fidget` WARNING → none, avoid list `{ "NvimTree" }` before and after;
`:e .` → single `NvimTree` window before and after; `:messages` empty, doctor exit 0.

### Phase 3 — Plugin moves: blink.cmp v1, git-conflict deprecation-free fork
**Satisfies:** R2, R4
**Owns:** `lua/plugin_specs.lua` blink.cmp (`version = "1.*"`, drop `build = "cargo build --release"`: v1 on a
release tag downloads its prebuilt fuzzy lib, and the run has no cargo) and git-conflict
(`"stryukovsky/git-conflict.nvim"`, `commit = "63c5b427038d85b20c32a25c7f3bd502241ce869"`, no `version`; the lock
key stays `git-conflict.nvim`); `lua/config/blink-cmp.lua` on v1.10.2's schema (every key checked; identical keymaps;
`cmdline.sources = {}`, which is what the v0 table shape meant; the obsolete commented `fuzzy` block removed);
`verify.sh` `seed_commit_unknown_to_live` → `live_lacks_seed_commit` ("the live checkout does not contain the seed
commit": `merge-base --is-ancestor`), its comment in `cmd_up`'s live block and its one caller; the two SKILL.md
sentences that state the old rule; `seed.lua` step `blink.cmp fuzzy library` (fetches the prebuilt lib for the
checked-out tag with the checked-out code); new `features/lua/deprecations.lua` probe; seed lock bump for blink.cmp
(`commit` → `78336bc89ee5365633bcf754d93df01678b5c08f`, keep `branch`/`url`) and `verify.sh seed`;
`features/git.md` (rewrite: git-conflict sub-feature + conflict journey), `features/lsp.md` `### Completion (blink.cmp
v1)` (after phase 2's subsections), `evidence-phase-3.md`. `lua/config/git-conflict.lua` and `PLUGIN_EXTRA_DATA`
unchanged.
**Does not touch:** other plugin specs (the render-markdown spec is phase 4's), phase 1's `verify.sh`/`SKILL.md`
hunks, phase 2's lsp.md subsections, `features/README.md`, `features/live-environment.md` (its old-rule sentence is
rewritten by phase 4), `features/startup.md`.
**Exit criteria:** before (both modes): completion in insert mode prints `client.request is deprecated`;
`:checkhealth vim.deprecated` shows the two git-conflict warnings. After: no deprecation line in `:messages` after
completion in lua/go/python; `:checkhealth vim.deprecated` 0 warnings; `:checkhealth blink.cmp` reports the rust
fuzzy lib (no Lua-fallback warning); completion keymaps and cmdline completion unchanged; git-conflict mappings,
`GitConflictListQf` and the Resolved qf refresh work; `--live` lists exactly `blink.cmp git-conflict.nvim` in
`replaced_from_seed`.

### Phase 4 — Sweep, tmux true colour, health allow-list, evidence index, Deploy runbook
**Satisfies:** R6, R7
**Owns:** `.tmux.conf.local` (`tmux_conf_24b_colour=true`) and `features/tmux-bindings.md`; the render-markdown
spec's `opts` in `lua/plugin_specs.lua` (`{ latex = { enabled = false }, yaml = { enabled = false } }`, a sweep
finding measured while planning; no plugin moves); the probes `features/lua/{health_diff,noise,load_all}.lua` and
the lever `.workflows/plan/nvim-0-12-clean/phase-4-health.sh`; the full sweep on both modes (every `features/*.md`
journey with `noise.lua` + phase 3's `deprecations.lua` after each; every lazy plugin loaded; full `:checkhealth`),
fixing any new config-side finding (no plugin moves); new `features/health.md` (allow-list + known noise; its go.nvim
entries are provisional and corrected to the measured report once phase 1 has landed: a correction, not a fix);
`features/README.md`, `features/live-environment.md` (incl. the new `live_lacks_seed_commit` rule); the set's index
`evidence.md` and `evidence-phase-4.md`; the Deploy runbook (D0-D6) in phase-4.md.
**Does not touch:** `verify.sh` (phases 1, 3), `seed.lua` (3), `SKILL.md` (1, 3) beyond what a sweep finding requires;
plugin moves (url/branch/version/commit/build); `lua/config/*`; `features/startup.md`, `lsp.md`, `git.md` (only a
config-side sweep fix may touch their end states); `features/editing-mappings.md`; the seed.
**Exit criteria:** `phase-4-health.sh seeded` and `live` exit 0: `:checkhealth vim.health` true-colour warning gone
(`tc-override`, `tc-rgb` PASS), `render-markdown` warnings gone, `:checkhealth` minus `features/health.md`'s allow-list
empty with gopls attached and with every plugin loaded, `load_all` `failed=0 unloaded=0`, `v:errmsg` empty; every
sweep row matches its "End state seen" with `noise=0` or only its listed expected noise, and `deprecations.lua` = `0`;
`evidence.md` has a path in every cell (R7's point to the Deploy report); the Deploy runbook parses (`bash -n`).

## Deploy (after land) — run by the coordinator after it pushes `main`

Not optional (R7). Exact commands, assertions and rollbacks: phase-4.md § "Deploy runbook". Summary:
0. Preconditions: `origin/main` carries the set; `~/.config/nvim` clean; seed lock entries present.
1. Backup to `~/.local/opt/deploy-backup-<date>/`: live `lazy-lock.json`, `lazy/blink.cmp`, `lazy/git-conflict.nvim`,
   `~/.tmux.conf.local`, `~/.config/nvim` HEAD.
2. `git -C ~/.config/nvim fetch origin && git -C ~/.config/nvim merge --ff-only origin/main`; assert clean.
3. D4-style plugin moves (plain git, seed lock `{branch, commit, url}`; `remote set-url` from the lock's raw url,
   `fetch -q --tags origin <branch>`, `checkout <commit>`, assert HEAD and raw `remote.origin.url`): git-conflict.nvim
   (re-pointed to the fork) and blink.cmp. blink.cmp also: assert `git describe --tags --exact-match` = `v1.10.2` (the
   live clone has object `78336bc` but not the tag, hence `--tags`); `rm -rf target` (v0's cargo tree); `install -D -m
   0644` the seed's three files `target/release/{libblink_cmp_fuzzy.so, libblink_cmp_fuzzy.so.sha256, version}`
   (without `.sha256` blink re-downloads; `0644` because seed files are read-only); assert `version` = `v1.10.2` and
   the checksum. Merge both seed lock entries into the live lock. v0's `~/.local/share/nvim/blink/cmp/fuzzy.db/` is
   left in place and named in the report.
4. `~/.tmux.conf.local` ← repo's, only if it was byte-identical to `8bcb55c`'s before (else stop and report);
   takes effect on the owner's next tmux server start (never `source`d into the running server).
5. Final proof from `~/.config/nvim`: `verify.sh up --live` (empty `replaced_from_seed`), doctor exit 0 (incl.
   `path ok`), `:messages` empty, `v:errmsg` empty, `noise.lua` `noise=0`, lsp.md's completion (lua) and CursorHold
   journeys as assertions (rust fuzzy lib v1.10.2, no deprecation, `2 0` in the 2-column window), full `:checkhealth`
   minus the allow-list empty (gopls attached; all loaded), `deprecations.lua` = `0`; `down`.
6. Report to `~/.local/state/nvim-config-verify/deploy-<date>.md` (never inside `~/.config/nvim`).

## Reconciliation Log

Round 1. Every quote was checked against `9cea538` with the earlier phases' edits applied to scratch copies
(`verify.sh` and `SKILL.md` with phase 1's; `plugin_specs.lua` with phase 3's); `bash -n` passes on phase 4's
Deploy runbook after the edits.

| # | Conflict | Phases | Resolution |
|---|---|---|---|
| 1 | File collision: phase 3 edits `verify.sh` (rule rename, `cmd_up` live comment, caller) and two `SKILL.md` sentences, phase 1's files, with pre-phase-1 line numbers | 1, 3 | Simulated phase 1 on `9cea538`: none of phase 3's quoted lines is in a phase-1 hunk, so the quoted text stands. Line refs rewritten to post-phase-1 (`verify.sh:270-281`, `:345-348`, `:366`; `SKILL.md:63-64`, `:198`). Phase 1's Leaves alone / Handoffs and phase 3's "Shares files with phase 1" name each other's regions. |
| 2 | Contract drift (index vs phase 3): index Owns lacked the `verify.sh` rule change, the SKILL.md sentences, the `seed.lua` step and `features/lua/deprecations.lua`, and said "`PLUGIN_EXTRA_DATA` only" | 3 | Index phase 3 Owns / Does not touch rewritten to the plan; `PLUGIN_EXTRA_DATA` unchanged; file count 6 → 9. |
| 3 | Unmet assumption: analysis said `--live` replaces blink.cmp because its seed commit is "unknown to the live clone"; measured false (live clone has `78336bc`, HEAD `485c034`) | 3, 4 | Phase 3 Step 1 changes the rule to `live_lacks_seed_commit` (not HEAD or an ancestor); phase 4 Step 9 rewrites `live-environment.md`'s old-rule sentence (phase 3's handoff marked taken). No later phase references the old name (grep: only `SKILL.md`, `verify.sh`, `live-environment.md`, all edited). |
| 4 | File collision: phase 4 Step 4 edits `lua/plugin_specs.lua` (phase 3's file) with only a "spec becomes" block and base line `:134` | 3, 4 | Kept in phase 4 (Decisions). Explicit Old block added, quoting post-phase-3 `:129-136` (identical to base `:128-135`); outside phase 3's hunks (`:49-56`, `:384-395` post-phase-3). Index phase 4 "Does not touch: plugin specs" → "plugin moves"; phase 3 Leaves alone names it. |
| 5 | Anchor error: phase 1 cited `startup.md:107` as the last line of "Deleted working directory"; it is `:108` on `9cea538` | 1 | Phase 1 Files table and Step 8 corrected (`:88-108`, insert after `:108`, before `## Gotchas` `:110`). Phase 2's anchor (`## Gotchas` + first bullet) is unchanged by phase 1 and lands after phase 1's subsection. |
| 6 | Anchor: phase 3's lsp.md insertion had no explicit trailing blank line before `## Gotchas` | 3 | Step 8 now states the block is followed by one blank line, and names phase 2's last line above it. |
| 7 | Contract drift (index vs phase 2, fidget): index said "nvim-tree integration set explicitly"; measured that this re-warns as a deprecated option | 2, 4 | Index Owns/exit criteria → avoid list in `setup` + module option off after setup; phase 4 health.md "Fixed by this set" row reworded to match. Decisions. |
| 8 | Contract drift (index vs phase 2, CursorHold): index said "cap the width to what fits" | 2 | Guard only (`< 3` columns skips); runtime already caps (measured). Index Owns/exit criteria updated. Decisions. |
| 9 | Contract drift (index vs phase 1): index left `-e` vs `env` open and doctor stripping only Mason's bin | 1 | Index Owns states `env PATH=` in `start_nvim_cmd`, `run_path_of`, meta `run_path=`, doctor strips `mason/bin` and go.nvim's `$HOME/go/bin`. Decisions. File count 3 → 4. |
| 10 | Gap: index Deploy D3 summary omitted `fetch --tags`, `rm -rf target`, the `.sha256` file and `0644` | 4 | Phase 4's runbook already had them; index Deploy step 3 rewritten to match. |
| 11 | Contract drift: phase 4 Deploy D5's R2/R3 checks did not match lsp.md's journeys (other keys, waits, lnum, no float-width / floats probe, no fuzzy-lib check) | 2, 3, 4 | D5 R2/R3 rewritten to lsp.md's `### Completion (blink.cmp v1)` (lua part) and `### CursorHold diagnostic float` with the same keys, waits and probes as assertions; lsp.md's recorded value wins on a difference. Runbook `bash -n` ok. |
| 12 | Unverified data: phase 4's ten go.nvim allow-list entries were written from `health.lua`, not measured (the base crashed first) | 1, 4 | Phase 4 note after the health.md block and in Step 2: after phase 1 lands, correct the entries' text to the measured report in both modes; a correction is not a fix and not a finding; other go lines or any go ERROR are findings. |
| 13 | Gap: phase 4's sweep table did not list `9cea538`'s deleted-cwd journey (asserted notify WARN) or phase 1's PATH fault injection (asserted doctor FAIL) as expected noise; git-conflict journey order | 1, 4 | Added to the `startup.md` row's expected noise; the `git.md` row runs the conflict journey last or in its own run. |
| 14 | Ownership drift: phase 4 attributed `verify.sh`, `seed.lua`, `SKILL.md` wholly to phase 1 | 4 | Corrected: `verify.sh` 1+3, `seed.lua` 3, `SKILL.md` 1+3. |
| 15 | Unowned handoff: phase 1 offered phase 4 an optional edit of `features/editing-mappings.md:67` | 1, 4 | Not edited (Decisions); both plans say so. |
| 16 | Wrong edge rationale: index said phase 3's `seed` snapshot needs phase 1's `run_path`; `cmd_seed` builds its own PATH | 1, 3 | Index edge text and phase 3 Depends/Requires restated (3 edits phase 1's files and needs its `sync`/doctor; before runs on 1+2). Order 1 → 2 → 3 → 4 unchanged. |

Checked, no conflict: deleted-then-used (the only deletion/rename, `seed_commit_unknown_to_live`, has one caller,
edited in the same step); duplicate work (no two phases edit the same region); broken-build phase (every phase's
edits are self-contained: phase 3's spec, config, seed and rule land together; phase 4's probes only read); ordering
(every dependency points backward); gaps vs the analysis impact points 1-4 and its Reference List (`run_env` left on
`run_path` by decision; `lua/config/git-conflict.lua` and `lua/globals.lua` deliberately unchanged); R1-R7 each served;
no requirement creep (phase 3's rule change and probe serve R2/R4's `--live` proof; phase 4's render-markdown fix
serves R6).

## Decisions

| Fork | Chosen | Rung |
|---|---|---|
| git-conflict.nvim: keep (deprecations stay), shim in config, rewrite forks (seblyng, konradmalik), or the minimal fork | `stryukovsky/git-conflict.nvim` pinned `commit = 63c5b42` (upstream `a1badcd` + only the deprecation swaps); full API kept (`GitConflictListQf`, `User GitConflictResolved`, mappings) | 5: user raw input ("fix (bump/replace/config)") + invariant 5 (no behaviour change rules out the rewrites); 6: precedent of hop → `smoka7` fork with the same lock key |
| git-conflict fork: `version = "*"` vs `commit` | `commit`: forks carry upstream's tags, so `*` resolves to the deprecated `v2.1.0` | 3: measured (analysis R4) |
| blink.cmp: config workaround vs bump | `version = "1.*"` (v1.10.2), config migrated to v1's schema | 5: user raw input ("bump/replace/config"); v1 is upstream's fix |
| blink.cmp `build = "cargo build --release"` | dropped; v1 tag downloads its prebuilt lib; Deploy copies the seed's lib | 6: convention (run PATH has no cargo; upstream's recommended install) |
| E216: clear `v:errmsg` after startup vs nvim-tree options | `disable_netrw = true`, `hijack_netrw = false` (netrw is already disabled in `globals.lua`; directory hijack keeps working with `disable_netrw`) | 6: convention (fix the cause, not the symptom) |
| R3: "prove gone" vs fix | fix: reproduced deterministically with `:2vsplit` | 2: phase exit criteria (R3 reproduce) |
| go.nvim health ❌ in runs: record as fence-only vs give runs the owner's Go tools | add go.nvim's tool dir to `run_path` by the existing "each tool by its own directory" rule | 6: convention (`run_path`'s own comment: "external tools the config shells out to") |
| True-colour health warning: record vs fix | fix (`tmux_conf_24b_colour=true`): the owner's tmux really lacks RGB (no `COLORTERM`), so `termguicolors` colours are downsampled | 5: user raw input ("Fix what is real") |
| Owner's running tmux server and `~/.tmux.conf.local` | file copied in Deploy only if unchanged since base; server never contacted, change applies on its next start | 1: invariant 3 + SKILL.md ("never the owner's tmux server") |
| "checkhealth clean" with optional tools absent | clean = full output minus a recorded allow-list (`features/health.md`) is empty | 5: user raw input ("record what is upstream-only and why") |
| R1 fix: `respawn-pane -e PATH=` vs an `env PATH=` prefix in `start_nvim_cmd` | `env PATH=<run_path_of DIR>` in `start_nvim_cmd`, shared by `up` and `sync`; `run_path` recorded in meta (`run_path=`) and read back by `run_path_of` | 2: phase 1 exit criteria (identical PATH before/after `sync`): measured, tmux 3.4 overwrites `-e PATH` with the session-less client's PATH |
| Doctor `path` comparison | nvim's PATH minus exactly Mason's prepended `<data>/mason/bin` and go.nvim's appended `$HOME/go/bin` must equal meta `run_path=` | 2: phase 1 exit criteria (`path ok` on good runs in both modes, `FAIL` on a foreign entry): both entries measured inside nvim |
| `run_env` on `run_path` vs `run_path_of` | stays on `run_path` (`cli`/`headless` are not nvim's pane; equal inside `up`) | 4: Requirements R1 (only nvim's respawn is asked for) |
| fidget: integration option in `setup()` vs avoid list + module option | `setup { notification.window.avoid = { "NvimTree" } }`, then `fidget.integration.nvim-tree` `options.enable = false` (guarded) | 2: phase 2 exit criteria (`:checkhealth fidget` without WARNING, avoid list unchanged): measured, the setup option re-warns as `Deprecated setup option` |
| CursorHold: width guard + config width cap vs guard only | guard only (skip in windows < 3 columns); `width = 100` kept | 2: phase 2 exit criteria (no error in 2 columns; width-100 float in a full window): measured, the runtime already caps to window − 2 (3 → 1, 150 → 100) |
| blink v1 `cmdline.sources`: `{}` vs `{ "cmdline", "path" }` | `{}` | 1: invariant 5 (no behaviour change): measured, v0's `{ default, providers }` table yielded no sources (ipairs), and enabling them would make cmdline `<Enter>` accept a menu item |
| `--live` replacement rule: keep "commit never fetched" vs "live checkout does not contain the seed commit" | `live_lacks_seed_commit` (`merge-base --is-ancestor`), renamed from `seed_commit_unknown_to_live` | 1: invariant 2 (after on `up --live` must drive the fixed plugin): measured, the live clone already has `78336bc`, so the old rule kept v0.14.2; every other seed entry equals live HEAD, so nothing else moves |
| Stale blink fuzzy lib in the seed: seed step vs "run `seed` twice" note | `seed.lua` step `blink.cmp fuzzy library` (download with the checked-out code; asserts `rust`, version, `.so`, `.sha256`) | 2: phase 3 exit criteria (`:checkhealth blink.cmp` reports the rust lib, no Lua fallback) + invariant 3 (runs are offline) |
| Deploy D3 for blink.cmp | `fetch --tags`, checkout `78336bc`, assert tag `v1.10.2`, `rm -rf target`, `install -D -m 0644` the seed's `.so`, `.so.sha256`, `version`, assert version + checksum | 3: phase 3's measured facts 1 and 4 (live clone lacks the tag; blink needs all three files and the tag), serving D5's assertions (no fallback notice) |
| render-markdown latex/yaml warnings: record in the allow-list vs disable in phase 4 (phase 3's file) | disable (`opts = { latex = { enabled = false }, yaml = { enabled = false } }`) in phase 4, after phase 3's hunks | 4: Why ("Fix what is real") + index phase 4 Owns ("fixing any new config-side finding it surfaces, no plugin moves"): neither feature can render (no parser, no converter) |
| go.nvim allow-list entries written from code, not measured | provisional: corrected to the measured report after phase 1 lands; a wording correction is not a fix or a finding | 2: phase 4 exit criteria (scripted checkhealth minus allow-list empty, both modes) |
| Deploy D5 checks for R2/R3 | lsp.md's completion (lua) and CursorHold journeys verbatim, as assertions; lsp.md's recorded value wins | 1: invariant 4 (feature docs move with the code; the final proof re-drives what the docs record) |
| `features/editing-mappings.md:67` run-PATH sentence | left as is | 6: convention (the sentence is still true; SKILL.md's new paragraph is the canonical list; smallest change) |
| `lua/config/git-conflict.lua` | unchanged | 3: phase 3's code blocks (the fork at `63c5b42` keeps `setup`, `GitConflictListQf`, `User GitConflictResolved`) |

## Open Questions

(none)

## Rollback

- Per phase before land: drop the phase's commits on `feature/nvim-0-12-clean`. Phase 3 also: restore the seed lock
  from `~/.local/state/nvim-config-verify/seed-lock.before-nvim-0-12-clean-phase-3.json` (blink.cmp `485c034`) and
  `seed`; keep phase 3's `seed.lua` step (version-agnostic, it refetches v0.14.2's library), or, if reverting it too,
  first remove the seed's `lazy/blink.cmp/target` (phase-3.md § Rollback).
- After land, before Deploy: `git revert -m 1 <merge>` on `main`, push.
- After Deploy: restore `~/.config/nvim/lazy-lock.json`, `~/.local/share/nvim/lazy/{blink.cmp,git-conflict.nvim}`
  and `~/.tmux.conf.local` from `~/.local/opt/deploy-backup-<date>/`; `git -C ~/.config/nvim reset --keep <saved HEAD>`
  (or merge the revert). Exact commands: phase-4.md § Deploy runbook, "Full rollback".

## Next

Run the whole set as a swarm (sequential here: each phase depends on the previous one); after it lands, run the
Deploy section above:

    /analyze-orchestrator -f .workflows/plan/NVIM_0_12_CLEAN_PLAN.md

Or one phase at a time:

    /implement -f .workflows/plan/NVIM_0_12_CLEAN_PLAN.md --phase 1
