# Todos

## Active Tasks

- [ ] **P1-NVIM-THTB** Phase 3: Plugin moves: blink.cmp v1, git-conflict deprecation-free fork
  - **Difficulty**: HARD
  - **Type**: Update
  - **Context**: Owns plugin moves: blink.cmp to `version = "1.*"` (drop cargo build) with `lua/config/blink-cmp.lua` on the v1 schema, git-conflict to the `stryukovsky/git-conflict.nvim` fork pinned at a commit, `verify.sh` `live_lacks_seed_commit` rename, seed.lua fuzzy-lib step, new `features/lua/deprecations.lua` probe, seed lock bump, features/git.md and lsp.md docs, evidence-phase-3.md. Exit: no `client.request is deprecated` after completion, `:checkhealth vim.deprecated` 0 warnings, `:checkhealth blink.cmp` shows rust fuzzy lib, keymaps and git-conflict features unchanged, `--live` lists exactly `blink.cmp git-conflict.nvim` in `replaced_from_seed`.
  - **Status**: open
  - **Plan Set**: `.workflows/orchestration/nvim-0-12-clean/PLAN.md` (phase 3 of 4)
  - **Satisfies**: R2 — No `client.request is deprecated` (blink.cmp v0.14 -> v1); R4 — No git-conflict.nvim `vim.highlight` / `vim.validate{}` deprecations
  - **Depends on**: P1-NVIM-4SP0, P1-NVIM-ZN89
  - **Plan**: `.workflows/plan/P1-NVIM-THTB.md`

- [ ] **P1-NVIM-IS7R** Phase 4: Sweep, tmux true colour, health allow-list, evidence index, Deploy runbook
  - **Difficulty**: NORMAL
  - **Type**: Update
  - **Context**: Owns the final sweep: `.tmux.conf.local` true colour, render-markdown `opts` (latex/yaml off) in `lua/plugin_specs.lua`, probes `health_diff/noise/load_all`, `phase-4-health.sh`, features/health.md allow-list, README/live-environment docs, the `evidence.md` index and the Deploy runbook (D0-D6). Exit: `phase-4-health.sh seeded` and `live` exit 0 (true-colour and render-markdown warnings gone, `:checkhealth` empty minus allow-list, `load_all` failed=0 unloaded=0, `v:errmsg` empty), every sweep row matches its end state with `deprecations.lua` = 0, evidence.md has a path in every cell, the Deploy runbook passes `bash -n`.
  - **Status**: blocked
  - **Plan Set**: `.workflows/orchestration/nvim-0-12-clean/PLAN.md` (phase 4 of 4)
  - **Satisfies**: R6 — Sweep: checkhealth, `:messages` after every journey, every plugin loads, notify history; fix real, record upstream-only; R7 — Unattended land + push, D4-style live changes after land, fast-forward `~/.config/nvim`, final `up --live` + doctor clean, evidence paths per item
  - **Depends on**: P1-NVIM-THTB
  - **Plan**: `.workflows/plan/P1-NVIM-IS7R.md`

## Completed Tasks

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

