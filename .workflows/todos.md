# Todos

## Active Tasks

- [ ] **P2-NVIM-F6PG** Bump go.nvim + glance.nvim D4-style, re-seed
  - **Difficulty**: NORMAL
  - **Type**: Update
  - **Context**: Follow-up from nvim-0-12-clean phase 4 (coordinator decision). go.nvim `4755def` calls `vim.lsp.codelens.refresh({ bufnr = bufnr })` (`go/codelens.lua:59`, fixed upstream in `5622d97` with `codelens.enable`), and glance.nvim calls `vim.validate{<table>}` in setup (`glance/init.lua:333`, `:367`, gone upstream in `5a8eab1`). Both are allowed in `features/health.md` under "Fixed upstream, not moved here". Bump both in the seed lock, `verify.sh seed`, prove on `up` and `up --live` (`:checkhealth vim.deprecated` empty, `deprecations.lua` = 0), deploy D4-style (backup under `~/.local/opt/`, plain git to the seed lock's {branch,commit,url}, live `lazy-lock.json`), then remove both entries from health.md's allow-list and noise list and the two exclusions in `phase-4-health.sh`'s `deprecations` check.
  - **Status**: open
  - **Depends on**: P1-NVIM-IS7R

- [ ] **P2-NVIM-6CQH** Cmdline `<Tab>` completes again (`:e sam<Tab>` inserts a literal `^I`)
  - **Difficulty**: EASY
  - **Type**: Bug
  - **Context**: Found by nvim-0-12-clean phase 4's sweep and kept there (invariant 5: no behaviour change in that set). `lua/config/blink-cmp.lua` maps cmdline `<Tab>` to `{ "select_next", "fallback" }` with `cmdline.sources = {}`, so blink's fallback returns `<Tab>` from an expr mapping, and `'wildchar'` ignores mapped keys (`'wildcharm'` = 0). Same on blink v0.14.2 and v1.10.2, and in a real terminal. Evidence and full analysis: `features/health.md` § "Findings kept as they are"; runs `1104-135505-3642755`, `1104-135833-3831128`. Fix candidates: `vim.o.wildcharm = 9` (keeps blink's map), or drop the cmdline `<Tab>`/`<S-Tab>` keys. Also correct the comment at `blink-cmp.lua:94-95`. Prove with lsp.md's cmdline step (`:e sample.lua`) on `up` and `up --live`.
  - **Status**: open
  - **Depends on**: P1-NVIM-IS7R

- [ ] **P2-NVIM-R4JW** git-conflict Resolved refresh leaves `E565` in `v:errmsg`
  - **Difficulty**: EASY
  - **Type**: Bug
  - **Context**: Found by nvim-0-12-clean phase 4's sweep (git.md conflict journey, both modes: runs `1104-135627-3767397`, `1104-135856-3841678`, trace `1104-135941-3872925`). git-conflict.nvim fires `User GitConflictResolved` twice per resolution, the second time from its redraw hook under textlock (`git-conflict.lua:673` → `process:481` → `parse_buffer:408`). `lua/config/git-conflict.lua`'s callback then runs `silent! GitConflictListQf`, whose `copen` fails with `E565: Not allowed to change text or change window: copen`. `silent!` hides it, and the list is already right from the first firing. Fix: wrap the callback body in `vim.schedule`. Then remove the `E565` entry from `features/health.md`'s noise list and the git.md Gotcha, and prove with git.md's conflict journey + `noise.lua` (`noise=0`) on `up` and `up --live`.
  - **Status**: open
  - **Depends on**: P1-NVIM-IS7R

## Completed Tasks

- [x] **P1-NVIM-IS7R** Phase 4: Sweep, tmux true colour, health allow-list, evidence index, Deploy runbook
  - **Difficulty**: NORMAL
  - **Type**: Update
  - **Context**: Owns the final sweep: `.tmux.conf.local` true colour, render-markdown `opts` (latex/yaml off) in `lua/plugin_specs.lua`, probes `health_diff/noise/load_all`, `phase-4-health.sh`, features/health.md allow-list, README/live-environment docs, the `evidence.md` index and the Deploy runbook (D0-D6). Exit: `phase-4-health.sh seeded` and `live` exit 0 (true-colour and render-markdown warnings gone, `:checkhealth` empty minus allow-list, `load_all` failed=0 unloaded=0, `v:errmsg` empty), every sweep row matches its end state with `deprecations.lua` = 0, evidence.md has a path in every cell, the Deploy runbook passes `bash -n`. Handoffs from phase 3: go.nvim `codelens.refresh` and glance.nvim `vim.validate{}` deprecations in `:checkhealth vim.deprecated` (were hidden on the base behind blink/git-conflict); cmdline `:e sam<Tab>` leaves a literal `^I` (blink cmdline <Tab> fallback, same on v0.14.2 and v1) as a finding; `features/live-environment.md` old-rule sentence (now `live_lacks_seed_commit`); README Git/LSP rows; `:checkhealth blink.cmp` 'providers disabled' WARNING to the allow-list.
  - **Status**: completed
  - **Plan Set**: `.workflows/orchestration/nvim-0-12-clean/PLAN.md` (phase 4 of 4)
  - **Satisfies**: R6 — Sweep: checkhealth, `:messages` after every journey, every plugin loads, notify history; fix real, record upstream-only; R7 — Unattended land + push, D4-style live changes after land, fast-forward `~/.config/nvim`, final `up --live` + doctor clean, evidence paths per item
  - **Depends on**: P1-NVIM-THTB
  - **Plan**: `.workflows/plan/P1-NVIM-IS7R.md`
  - **Completed**: 2026-11-04 14:06
  - **Method**: /do
  - **Files**: .claude/skills/verify-nvim-config/features/health.md, .claude/skills/verify-nvim-config/features/lua/health_diff.lua, .claude/skills/verify-nvim-config/features/lua/noise.lua, .claude/skills/verify-nvim-config/features/lua/load_all.lua, .workflows/plan/nvim-0-12-clean/phase-4-health.sh, .tmux.conf.local, .claude/skills/verify-nvim-config/features/tmux-bindings.md, lua/plugin_specs.lua, .claude/skills/verify-nvim-config/features/README.md, .claude/skills/verify-nvim-config/features/live-environment.md, .claude/skills/verify-nvim-config/features/format-on-save.md, .claude/skills/verify-nvim-config/features/lsp.md, .claude/skills/verify-nvim-config/features/git.md, .workflows/plan/nvim-0-12-clean/evidence-phase-4.md, .workflows/plan/nvim-0-12-clean/evidence.md, .workflows/plan/nvim-0-12-clean/phase-4.md, .workflows/orchestration/nvim-0-12-clean/phase-4.md, .workflows/plan/P1-NVIM-IS7R.md, .workflows/todos.md
  - **Drift**:
    - Measured go.nvim health had 4 lines the plan's provisional allow-list lacked (nvim-dap, nvim-dap-ui, nvim-dap-virtual-text not installed/loaded; Not all plugin installed): added as class (b), the config declares no dap plugin.
    - health_diff.lua: a vim.deprecated key now carries the plugin of its first stack frame as subsection, so the glance.nvim / go.nvim allow entries cannot mask a git-conflict regression.
    - Deploy D5 asserted deprecations.lua = 0 strictly; go.nvim's codelens line (allowed by coordinator decision) would have failed it once D5 opens main.go and rolled back a good deploy. D5 now uses deps_other (excludes exactly the two upstream lines). D5's CursorHold step now sends k and j separately (racy otherwise, 3/4 failures measured). bash -n passes.
    - format-on-save.md recorded a 'written' line in :messages; Neovim 0.12.6 keeps write messages out of :messages (nvim --clean alike). End-state text corrected.
    - lsp.md CursorHold recipe made deterministic (k, wait diagnostics_pos, j); 6/6 passes on both modes.
    - git.md: Gotchas for E565 after ct, ,gp Press-ENTER prompt, commit journey early in a run.
  - **Decided**:
    - go.nvim codelens.refresh + glance.nvim vim.validate{} -> recorded in health.md 'Fixed upstream, not moved here', follow-up P2-NVIM-F6PG (coordinator decision, rung 1: invariant 3)
    - cmdline :e sam<Tab> literal ^I -> config behaviour (blink cmdline <Tab> fallback from an expr map; wildchar ignores mapped keys), kept and recorded in health.md + P2-NVIM-6CQH (coordinator decision, rung 1: invariant 5)
    - E565 after git-conflict ct -> known noise + P2-NVIM-R4JW, lua/config/git-conflict.lua unchanged (rung 1: index Decision 'git-conflict.lua unchanged' + phase 4 does not touch lua/config/*; never widen scope)
    - format-on-save.md stale :messages end state -> doc corrected to measured 0.12.6 behaviour (rung 1: invariant 4)


- [x] **P1-NVIM-THTB** Phase 3: Plugin moves: blink.cmp v1, git-conflict deprecation-free fork
  - **Difficulty**: HARD
  - **Type**: Update
  - **Context**: Owns plugin moves: blink.cmp to `version = "1.*"` (drop cargo build) with `lua/config/blink-cmp.lua` on the v1 schema, git-conflict to the `stryukovsky/git-conflict.nvim` fork pinned at a commit, `verify.sh` `live_lacks_seed_commit` rename, seed.lua fuzzy-lib step, new `features/lua/deprecations.lua` probe, seed lock bump, features/git.md and lsp.md docs, evidence-phase-3.md. Exit: no `client.request is deprecated` after completion, `:checkhealth vim.deprecated` 0 warnings, `:checkhealth blink.cmp` shows rust fuzzy lib, keymaps and git-conflict features unchanged, `--live` lists exactly `blink.cmp git-conflict.nvim` in `replaced_from_seed`.
  - **Status**: completed
  - **Plan Set**: `.workflows/orchestration/nvim-0-12-clean/PLAN.md` (phase 3 of 4)
  - **Satisfies**: R2 — No `client.request is deprecated` (blink.cmp v0.14 -> v1); R4 — No git-conflict.nvim `vim.highlight` / `vim.validate{}` deprecations
  - **Depends on**: P1-NVIM-4SP0, P1-NVIM-ZN89
  - **Plan**: `.workflows/plan/P1-NVIM-THTB.md`
  - **Completed**: 2026-11-04 13:40
  - **Method**: /do
  - **Files**: .claude/skills/verify-nvim-config/SKILL.md, .claude/skills/verify-nvim-config/scripts/verify.sh, .claude/skills/verify-nvim-config/scripts/seed.lua, .claude/skills/verify-nvim-config/features/lsp.md, .claude/skills/verify-nvim-config/features/git.md, .claude/skills/verify-nvim-config/features/lua/deprecations.lua, lua/plugin_specs.lua, lua/config/blink-cmp.lua, .workflows/plan/nvim-0-12-clean/evidence-phase-3.md
  - **Drift**:
    - Plan's lsp.md completion recipe was unmeasured and derailed on v0.14.2 and v1 alike: lua_ls in WORK has no vim library so `vim.` opens no menu, and `Escape Escape` in one keys call leaves insert mode on. Recipe now types `vim.p` and sends each Escape separately + waits for mode n; assertions unchanged.
    - Plan's expected `:e sam<Tab>` -> `:e sample.lua` was never true: both v0.14.2 and v1 leave `:e sam^I` (blink cmdline <Tab> fallback feeds a non-wildchar Tab). Recorded unchanged.
    - External state written (invariant 3, phase 3 only): seed lock blink.cmp -> 78336bc, `verify.sh seed` re-run (git-conflict MOVED to stryukovsky@63c5b42, blink fuzzy lib v1.10.2 downloaded); backup at ~/.local/state/nvim-config-verify/seed-lock.before-nvim-0-12-clean-phase-3.json.
  - **Decided**:
    - A2 `:checkhealth vim.deprecated` = 'No deprecated functions detected' -> satisfied as 'no blink.cmp / git-conflict.nvim entry'; go.nvim codelens.refresh and glance.nvim vim.validate{} (hidden on the base behind the first-reported names) handed to phase 4 (rung 4: R2/R4 + index Scope 'plugins other than blink.cmp and git-conflict.nvim' out of scope; never widen scope)
    - Cmdline <Tab> literal ^I kept as is -> no change (rung 1: invariant 5, cmdline completion behaves as before); handed to phase 4 as a finding
    - Completion journey mechanics rewritten (vim.p, separate Escapes) -> journey fixed, not assertions (rung 2: phase exit criteria need a drivable recipe; same before/after end states measured on live via a d90b730 checkout, run 1104-133804-3361630)


- [x] **P1-NVIM-4SP0** Phase 2: Config-side fixes: E216, CursorHold width, fidget integration
  - **Difficulty**: EASY
  - **Type**: Bug
  - **Context**: Owns config-side fixes: nvim-tree `disable_netrw = true`/`hijack_netrw = false` (E216), a CursorHold callback guard in `lua/diagnostic-conf.lua` skipping `open_float` in windows under 3 columns, fidget nvim-tree integration/avoid config, plus features/lsp.md, features/startup.md docs and evidence-phase-2.md. Exit: `v:errmsg` empty, `:2vsplit` repro gives no 'Invalid width' error, `:checkhealth fidget` warning gone, `:e .` yields a single NvimTree window, `:messages` empty, doctor exit 0 (both modes).
  - **Status**: completed
  - **Plan Set**: `.workflows/orchestration/nvim-0-12-clean/PLAN.md` (phase 2 of 4)
  - **Satisfies**: R5 — `v:errmsg` empty after startup (no E216 FileExplorer); R3 — CursorHold diagnostic `open_float` "Invalid 'width'": reproduce and fix; R6 — Sweep: checkhealth, `:messages` after every journey, every plugin loads, notify history; fix real, record upstream-only
  - **Depends on**: P1-NVIM-ZN89
  - **Plan**: `.workflows/plan/P1-NVIM-4SP0.md`
  - **Completed**: 2026-11-04 13:19
  - **Method**: /do
  - **Files**: lua/config/nvim-tree.lua, lua/diagnostic-conf.lua, lua/config/fidget-nvim.lua, .claude/skills/verify-nvim-config/features/startup.md, .claude/skills/verify-nvim-config/features/lsp.md, .workflows/plan/nvim-0-12-clean/evidence-phase-2.md
  - **Drift**:
    - No code drift; every plan quote matched the tree.
    - Pre-existing, not a regression: after J2 (`:e .`) only an NvimTree window remains and the next BufEnter fires custom-autocmd.lua auto_close_win (qall), killing the pane. Base and fix identical (run 1104-131824-3104731). Recorded in features/startup.md; J2 must run last in a drive.
  - **Decided**:
    - Plan recipe uses `git stash push` → copied the fixed files aside and used `git checkout -- <3 paths>` for the before drive (environment rule: stash stack is shared across worktrees/sessions; tie-break: reversible, narrower blast radius)
    - Exit criterion ':messages empty' vs blink.cmp's 'client.request is deprecated' still present → accepted, it is R2 which the Requirements table assigns to phase 3; no error lines, doctor 'messages ok' (rung 4: Requirements; never widen scope)
    - Build check `nvim --headless ... loadfile` refused by the harness hook → `luac -p` on the three files (equivalent syntax check)

- [x] **P1-NVIM-ZN89** Phase 1: verify.sh: sync keeps run_path, doctor checks PATH, Go tools on run PATH
  - **Difficulty**: NORMAL
  - **Type**: Bug
  - **Context**: Owns verify.sh run-PATH handling: `start_nvim_cmd` uses `env PATH=<run_path_of DIR>` for both `up` and `sync`, `cmd_up` records `run_path=` in meta, a new doctor `path` check, and `golangci-lint` added to `run_path`; plus SKILL.md and features/startup.md docs and evidence-phase-1.md. Exit: PATH identical before/after `sync` and equal to Mason's bin + meta run_path, doctor `path ok` (FAIL on fault-injected PATH), `:checkhealth go` has no ERROR/Missing tool in either mode, Go format-on-save unchanged, every journey passes.
  - **Status**: completed
  - **Plan Set**: `.workflows/orchestration/nvim-0-12-clean/PLAN.md` (phase 1 of 4)
  - **Satisfies**: R1 — `verify.sh sync` respawns nvim with `run_path`, not the caller's PATH; R6 — Sweep: checkhealth, `:messages` after every journey, every plugin loads, notify history; fix real, record upstream-only
  - **Depends on**: —
  - **Plan**: `.workflows/plan/P1-NVIM-ZN89.md`
  - **Completed**: 2026-11-04 13:07
  - **Method**: /do
  - **Files**: .claude/skills/verify-nvim-config/scripts/verify.sh, .claude/skills/verify-nvim-config/SKILL.md, .claude/skills/verify-nvim-config/features/startup.md, .workflows/plan/nvim-0-12-clean/evidence-phase-1.md, .workflows/todos.md, .workflows/plan/P1-NVIM-ZN89.md, .workflows/plan/P1-NVIM-4SP0.md, .workflows/plan/P1-NVIM-THTB.md, .workflows/plan/P1-NVIM-IS7R.md, .workflows/orchestration/nvim-0-12-clean/PLAN.md, .workflows/orchestration/nvim-0-12-clean/ledger.json, .workflows/plan/NVIM_0_12_CLEAN_PLAN.md
  - **Drift**:
    - Plan J1 ran :checkhealth go after sync; on the base the leaked caller PATH contains the Go bin, so it showed 0 ERROR. Added J1b/J2 that run it before sync: ERROR + 19 Missing tool in both modes.
    - Remaining go-health warnings measured (13, both modes) include nvim-dap/nvim-dap-ui/nvim-dap-virtual-text 'not installed/loaded' and 'Not all plugin installed', not in the plan's handoff list; recorded in startup.md and evidence for phase 4's allow-list.
    - shellcheck not installed; bash -n passes.
  - **Decided**:
    - J1's go-health 'before' masked by the leak → run checkhealth before sync for the before evidence (rung 2: exit criteria require go health ERROR on the base)

