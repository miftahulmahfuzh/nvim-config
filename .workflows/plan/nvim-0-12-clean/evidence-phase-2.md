# Phase 2 evidence: E216, CursorHold width, fidget integration

Base for "before": the worktree with phase 2's three Lua edits reverted (`9cea538` + phase 1, HEAD `cbb88cf`).
"After": the same run after the edits were restored + `verify.sh sync` (nvim restarted on `run_path`, doctor
`path ok`). Instead of `git stash` (the stash stack is shared with other worktrees/sessions), the fixed files
were copied aside, the three paths reverted with `git checkout -- <path>` for the before drive, then copied back.

Evidence root: `~/.local/state/nvim-config-verify/<run>/evidence/`. Both runs use the same drive script, so
file numbers are identical: before `01`-`19`, after `20`-`39`; `wait` results are in `LOG.md`.

Runs: live `1104-131054-3055370` (`up --live`, `replaced_from_seed=` empty), seeded `1104-131214-3068043` (`up`).

| Journey | Mode | Run | Before (failure) | After |
|---|---|---|---|---|
| J1 `v:errmsg` after startup (R5) | live | `1104-131054-3055370` | `01-lua-vim.v.errmsg.txt` `E216: No such group or event: FileExplorer *` | `20-lua-vim.v.errmsg.txt` `""` |
| J1 `v:errmsg` after startup (R5) | seeded | `1104-131214-3068043` | `01-lua-vim.v.errmsg.txt` `E216: ...` | `20-lua-vim.v.errmsg.txt` `""` |
| J2 `:e .` opens nvim-tree | live | `1104-131054-3055370` | `19-lua-vim.inspect___cwd___...txt` `wins = { "NvimTree" }`, cwd WORK | `38-lua-vim.inspect___cwd___...txt` same |
| J2 `:e .` opens nvim-tree | seeded | `1104-131214-3068043` | `19-lua-...txt` same | `38-lua-...txt` same |
| J3 CursorHold `:2vsplit` (R3) | live | `1104-131054-3055370` | `15-screen-narrow.txt` `Invalid 'width': expected positive Integer`, `Press ENTER` | `34-screen-narrow.txt` no `Invalid`; `LOG.md` `wait ok ... diagnostics_pos`; `35-lua-__width___...txt` `width = 2, floats = 0` |
| J3 CursorHold `:2vsplit` (R3) | seeded | `1104-131214-3068043` | `15-screen-narrow.txt` traceback | `34-screen-narrow.txt` + `35-lua-...txt` same |
| J3 full-width float width 100 | live | `1104-131054-3055370` | `LOG.md` 13:11:09 `wait ok ... == 100` | `LOG.md` 13:11:56 `wait ok ... == 100` |
| J3 full-width float width 100 | seeded | `1104-131214-3068043` | `LOG.md` 13:12:27 `wait ok ... == 100` | `LOG.md` 13:12:35 `wait ok ... == 100` |
| J4 `:checkhealth fidget` (R6) | live | `1104-131054-3055370` | `04-lua-table.concat_vim.tbl_filter_...txt` `WARNING nvim-tree.lua integration is implicitly enabled` | `23-lua-...txt` empty |
| J4 `:checkhealth fidget` (R6) | seeded | `1104-131214-3068043` | `04-lua-...txt` WARNING | `23-lua-...txt` empty |
| J4 fidget avoid list | live | `1104-131054-3055370` | `06-lua-require__fidget...txt` `{ "NvimTree" }` | `25-lua-...txt` `{ "NvimTree" }` |
| J4 fidget avoid list | seeded | `1104-131214-3068043` | `06-lua-...txt` `{ "NvimTree" }` | `25-lua-...txt` `{ "NvimTree" }` |
| `:messages` + doctor after | live | `1104-131054-3055370` | — | `39-lua-vim.fn.execute__messages__.txt` (only blink's `client.request is deprecated`, R2/phase 3); doctor exit 0, `messages ok`, `path ok`; `messages-at-down.txt` 0 `E\d+:`/`Invalid` |
| `:messages` + doctor after | seeded | `1104-131214-3068043` | — | `39-lua-...txt` same; doctor exit 0, `messages ok`, `path ok`, `seed ok` |
| Neighbor: lsp.md lua_ls/gopls/pyright attach | seeded | `1104-131840-3108024` | — | `LOG.md` `wait ok` lua_ls, gopls, pyright, `reportAssignmentType`; `01-lua-vim.v.errmsg.txt` `""`; doctor exit 0; `messages-at-down.txt` only blink's deprecation |

Pre-existing, not a regression: after J2 the only window is `NvimTree`, and the next `BufEnter` fires
`custom-autocmd.lua`'s `auto_close_win` (`qall`): the seeded run's pane died when the neighbor check was
started on it (`40-keys-...txt` `Pane is dead (status 0)`, so it has no `messages-at-down.txt`). Run
`1104-131824-3104731` shows the base and the fix behave identically (`05-screen-after-base.txt`,
`10-screen-after-fixed.txt`, both `Pane is dead (status 0)`); recorded in `features/startup.md`.

Planning measurements: live `1104-121455-2789754/evidence/01-lua-vim.v.errmsg.txt` (E216),
live `1104-121901-2809686/evidence/14-screen-screen.txt` (Invalid 'width'), seeded
`1104-123239-2888928/evidence/03`-`06` (hijack on base; errmsg empty + hijack with Step 1 in the run snapshot).
