> Adopted from `.workflows/orchestration/nvim-0-12-clean/PLAN.md` phase 2. Source: `.workflows/plan/nvim-0-12-clean/phase-2.md`.
> Written and reconciled by /analyze — edit the source, not this copy.

# Phase 2: Config-side fixes: E216, CursorHold width, fidget integration

**Plan set:** `NVIM_0_12_CLEAN_PLAN.md`
**Analysis:** `.workflows/analyze/20261104-121422-N12C_code_analyzer.md`
**Satisfies:** R5 (`v:errmsg` empty after startup), R3 (CursorHold `open_float` "Invalid 'width'"), R6 (the fidget checkhealth finding only)
**Depends on:** Phase 1 (`verify.sh sync` keeps `run_path`; this phase's before/after recipe restarts nvim with `sync`)
**Difficulty:** EASY
**Package:** `lua/`

**Base:** the worktree as rebased onto `origin/main` `9cea538` (fix(startup) ensure_cwd), plus phase 1.
`9cea538` touched only `lua/custom-autocmd.lua` and `features/startup.md` (new `### Deleted working
directory` subsection, kept intact here). None of the three Lua files this phase edits changed in it;
the line numbers below were re-read after the rebase.

---

## Goal

After this phase a fresh start leaves `vim.v.errmsg` empty (nvim-tree no longer runs
`silent! autocmd! FileExplorer *` against a group that `globals.lua` already prevented), a CursorHold in a
window too narrow for a bordered float no longer throws "Invalid 'width'" (the float is skipped there and
still opens at width 100 in normal windows), and `:checkhealth fidget` has no warning while fidget still
keeps its notification window clear of nvim-tree. `nvim <dir>` / `:e <dir>` still opens nvim-tree.

## Interface Contract

**Deletes:** none.
**Renames:** none.
**Creates:**
- `features/startup.md` subsection `### v:errmsg after startup and the directory hijack`
- `features/lsp.md` subsections `### CursorHold diagnostic float` and `### fidget health`
- `.workflows/plan/nvim-0-12-clean/evidence-phase-2.md`
**Signature changes:** none.
**Config value changes:**
- `lua/config/nvim-tree.lua`: `disable_netrw` `false` → `true`; `hijack_netrw` `true` → `false`.
- `lua/diagnostic-conf.lua`: the CursorHold callback skips `open_float` when the current window has fewer
  than 3 columns (`nvim_win_get_width(0) - 2 < 1`). `width = 100` is unchanged; `vim.b.diagnostics_pos`
  bookkeeping unchanged (still updated on a skipped hold).
- `lua/config/fidget-nvim.lua`: `setup { notification = { window = { avoid = { "NvimTree" } } } }`, then
  `package.loaded["fidget.integration.nvim-tree"].options.enable = false` (guarded on the module existing).
  **Deviation from the index wording** ("nvim-tree integration set explicitly"): on fidget `e32b672` (live and
  seed), passing `integration = { ["nvim-tree"] = { enable = ... } }` to `setup()` replaces the warning with
  another one (`Deprecated setup option: 'integration.nvim-tree.enable'`, measured headless, see Step 3).
  Only setting the module's option after `setup()` makes `explicitly_configured()` true without logging a
  deprecated option. The avoid list carries the behaviour.
**Requires (from earlier phases):** Phase 1: `verify.sh sync` respawns nvim with `run_path` (so the `--live`
before/after recipe below compares like with like); phase 1's new `features/startup.md` subsection sits
after "Deleted working directory" and before `## Gotchas`.
**Leaves alone (owned by others):** `verify.sh`, `SKILL.md`, phase 1's startup.md subsection (Phase 1);
`lua/plugin_specs.lua`, the seed, `lua/config/blink-cmp.lua`, `lua/config/git-conflict.lua`,
`features/git.md`, the `features/lsp.md` completion journey (Phase 3, which edits lsp.md after this phase);
`.tmux.conf.local`, `features/health.md`, `features/README.md`, `features/live-environment.md`,
`features/tmux-bindings.md`, the set's evidence index (Phase 4); `lua/globals.lua` (already right:
`:47-48` set `loaded_netrw`/`loaded_netrwPlugin`); `lua/custom-autocmd.lua` (`9cea538`'s `ensure_cwd`).

## Files

| File | Action | What changes |
|---|---|---|
| `lua/config/nvim-tree.lua:51-52` | modify | `disable_netrw = true`, `hijack_netrw = false` |
| `lua/diagnostic-conf.lua:59-61` | modify | CursorHold callback: skip `open_float` in a window with < 3 columns |
| `lua/config/fidget-nvim.lua:1` | modify | avoid list `{ "NvimTree" }` in setup; implicit nvim-tree integration switched off after setup |
| `.claude/skills/verify-nvim-config/features/startup.md` (before `## Gotchas`, after phase 1's subsection) | modify | new subsection: `v:errmsg` end state + directory hijack journey |
| `.claude/skills/verify-nvim-config/features/lsp.md:38-40` | modify | two new subsections before `## Gotchas`: CursorHold float (incl. the `:2vsplit` repro) and fidget health |
| `.workflows/plan/nvim-0-12-clean/evidence-phase-2.md` | create | run ids + evidence paths, before/after, both modes |

## Implementation Steps

Do Steps 1-3 and leave them **uncommitted** until the Proof journeys ran: the before half of every
journey is driven on the stashed tree (see Verification).

### Step 1: nvim-tree stops touching the FileExplorer group (R5)
**File:** `lua/config/nvim-tree.lua:51-52`
**Cause (traced):** nvim-tree `3fb91e1` `lua/nvim-tree.lua:123-131` `manage_netrw`: with `hijack_netrw = true`
it runs `vim.cmd("silent! autocmd! FileExplorer *")` and registers
`autocmd VimEnter * ++once silent! autocmd! FileExplorer *`. `silent!` hides the message but still sets
`v:errmsg`, and the `FileExplorer` group never exists because `lua/globals.lua:47-48` disable netrw before
any plugin loads. Measured before: live run `1104-121455-2789754` `evidence/01-lua-vim.v.errmsg.txt` =
`E216: No such group or event: FileExplorer *`.
**Why the hijack keeps working:** `lua/nvim-tree.lua:726` `netrw_disabled = opts.disable_netrw or opts.hijack_netrw`,
`:732` `hijack_directories.enable = hijack_directories.enable and netrw_disabled`, `:192` registers the
`BufEnter`/`BufNewFile` → `open_on_directory` autocmd when enabled. With `disable_netrw = true`,
`netrw_disabled` stays true; `manage_netrw` then only sets `vim.g.loaded_netrw{,Plugin} = 1` (already set by
globals.lua: a no-op). The plugin doc agrees: `hijack_netrw` is "overridden if disable_netrw is true".
Measured during planning on seeded run `1104-123239-2888928` (run snapshot edited, not the repo):
base `:e .` → one window, `ft = "NvimTree"`, cwd WORK (`evidence/03-lua-...`, `04-screen-hijack.txt`);
with this change, headless `+'e .'` → `errmsg=[] ft=NvimTree wins=1 tree=true` (`evidence/05`, `06-headless-...`).
**Code:** exact replacement (2-space indent, inside the `nvim_tree.setup {` table):

old:
```lua
  auto_reload_on_write = true,
  disable_netrw = false,
  hijack_netrw = true,
  hijack_cursor = false,
```
new:
```lua
  auto_reload_on_write = true,
  -- netrw is already off (globals.lua sets loaded_netrw before any plugin loads). hijack_netrw would
  -- run `silent! autocmd! FileExplorer *` against a group that never exists, leaving E216 in
  -- v:errmsg. disable_netrw keeps hijack_directories (`nvim <dir>`, `:e <dir>`) enabled.
  disable_netrw = true,
  hijack_netrw = false,
  hijack_cursor = false,
```
**Impact:** no `FileExplorer` autocmd commands at startup; `v:errmsg` is `""` after startup. Directory
hijack unchanged (Journey J2).

### Step 2: CursorHold float skips windows too narrow for a bordered float (R3)
**File:** `lua/diagnostic-conf.lua:59-61` (inside the `CursorHold` autocmd at `:47-66`; the file is
tab-indented)
**Cause (traced):** nvim 0.12.6 `runtime/lua/vim/lsp/util.lua:1537-1600` `_make_floating_popup_size`:
`width = math.min(width, screen_width - border_width)`, with `screen_width = nvim_win_get_width(0)` (the float
is cursor-relative) and `border_width = 2` for `float.border = "single"` (`diagnostic-conf.lua:22`). In a
window of 1 or 2 columns that is `<= 0`, and `nvim_open_win` at `util.lua:1760` throws
`Invalid 'width': expected positive Integer`. Reproduced: live run `1104-121901-2809686`
`evidence/14-screen-screen.txt` (traceback through `diagnostic-conf.lua:61`, "Press ENTER").
Headless measurement during planning (`--clean`, same float config, explicit `width = 100`):
window 1 → error, 2 → error, 3 → float width 1, 4 → width 2, 150 → width 100. So the guard is
"at least 3 columns", and the runtime already caps the width to `window - 2` in every window that passes
it: no second cap is added in the config (see Principles applied).
**Code:** exact replacement (tabs):

old:
```lua
		if not vim.deep_equal(cursor_pos, vim.b.diagnostics_pos) then
			diagnostic.open_float({ width = 100 })
		end
```
new:
```lua
		-- float.border = "single" takes one column on each side, and nvim caps the float's width to
		-- the window's width minus the border: in a window of 2 columns or fewer that leaves no
		-- column, and nvim_open_win throws "Invalid 'width'". Skip the float there.
		local fits_float = api.nvim_win_get_width(0) - 2 >= 1
		if fits_float and not vim.deep_equal(cursor_pos, vim.b.diagnostics_pos) then
			diagnostic.open_float({ width = 100 })
		end
```
The full callback after the change (for reference; only the lines above change):
```lua
api.nvim_create_autocmd("CursorHold", {
	pattern = "*",
	callback = function()
		if #vim.diagnostic.get(0) == 0 then
			return
		end

		if not vim.b.diagnostics_pos then
			vim.b.diagnostics_pos = { nil, nil }
		end

		local cursor_pos = api.nvim_win_get_cursor(0)

		-- float.border = "single" takes one column on each side, and nvim caps the float's width to
		-- the window's width minus the border: in a window of 2 columns or fewer that leaves no
		-- column, and nvim_open_win throws "Invalid 'width'". Skip the float there.
		local fits_float = api.nvim_win_get_width(0) - 2 >= 1
		if fits_float and not vim.deep_equal(cursor_pos, vim.b.diagnostics_pos) then
			diagnostic.open_float({ width = 100 })
		end

		vim.b.diagnostics_pos = cursor_pos
	end,
})
```
**Impact:** no error and no float in a 1-2 column window; `vim.b.diagnostics_pos` still records the
position (so widening the window does not pop a float until the cursor moves, as before for any
already-shown position). Normal windows: unchanged, float width 100 in a 160-column window.

### Step 3: fidget avoids nvim-tree explicitly (R6, fidget)
**File:** `lua/config/fidget-nvim.lua:1` (whole file is one line: `require("fidget").setup {}`)
**Cause (traced):** fidget `e32b672` (live and seed lock agree) `lua/fidget/health.lua:55-60` warns
`nvim-tree.lua integration is implicitly enabled` when `integration.nvim-tree.enable` is still the
`DEPRECATED(true, ...)` default table and `nvim-tree.api` is loadable. Today's behaviour:
`notification/window.lua:214-226` `check_integration()` appends `"NvimTree"` to
`notification.window.avoid` on the first window positioning, so fidget's window avoids nvim-tree windows.
Measured headless (`--clean`, fidget + nvim-tree on rtp), four variants:
- `setup {}` (today): `WARNING nvim-tree.lua integration is implicitly enabled`; avoid becomes `{ "NvimTree" }` lazily.
- `setup { integration = { ["nvim-tree"] = { enable = false } }, notification = { window = { avoid = { "NvimTree" } } } }`:
  `WARNING Deprecated setup option: 'integration.nvim-tree.enable'` (`options.lua:117-118` logs any
  user value for a deprecated key). Rejected.
- `setup { notification = { window = { avoid = { "NvimTree" } } } }` alone: implicit warning stays. Rejected.
- avoid in `setup`, then `package.loaded["fidget.integration.nvim-tree"].options.enable = false`:
  `OK All user-specified options are known and accounted for`, no WARNING; avoid = `{ "NvimTree" }`
  after `get_window_position()`. **Chosen.**
**Code:** replace the whole file with:
```lua
-- fidget keeps its notification window off nvim-tree's window. That used to be an implicit
-- integration (`integration["nvim-tree"].enable`, default on), which :checkhealth fidget flags
-- because a future release removes it; its advice is to list the filetype in
-- notification.window.avoid instead, which keeps the same behaviour.
require("fidget").setup {
  notification = {
    window = {
      avoid = { "NvimTree" },
    },
  },
}

-- Passing `integration["nvim-tree"].enable` to setup() is itself reported as a deprecated option, so
-- the implicit integration is switched off on its module after setup; the avoid list above already
-- does what it did. Once fidget drops the module there is nothing to switch off.
local nvim_tree_integration = package.loaded["fidget.integration.nvim-tree"]
if nvim_tree_integration then
  nvim_tree_integration.options.enable = false
end
```
**Impact:** `:checkhealth fidget` has no WARNING; `require("fidget.notification.window").options.avoid`
is `{ "NvimTree" }` from setup on (before: the same list, added lazily at first positioning).

### Step 4: `features/startup.md`: `v:errmsg` end state and the directory hijack
**File:** `.claude/skills/verify-nvim-config/features/startup.md`, as it stands after phase 1. Insert a new
subsection immediately **before** `## Gotchas` (today `:110`; after phase 1 it follows phase 1's PATH
subsection, which follows `9cea538`'s `### Deleted working directory`). Do not edit either of those
subsections. Anchor on the `## Gotchas` heading plus the first line of its first bullet, which neither
phase 1 nor `9cea538` changes.

old:
```markdown
## Gotchas

- gofumpt and stylua are kept by mason-tool-installer alone (`auto_update = true`,
```
new:
````markdown
### v:errmsg after startup and the directory hijack

nvim-tree used to run `silent! autocmd! FileExplorer *` at load (`hijack_netrw = true`). netrw is off
before any plugin loads (`globals.lua`), so the group never exists, and `silent!` hid the message but
left `E216: No such group or event: FileExplorer *` in `v:errmsg`. `config/nvim-tree.lua` now sets
`disable_netrw = true, hijack_netrw = false`; `hijack_directories` stays on with `disable_netrw`.

```sh
$V up                                                     # or up --live
$V lua RUN 'vim.v.errmsg'
$V keys RUN : e Space . Enter
$V lua RUN 'vim.inspect({ cwd = vim.fn.getcwd(), wins = vim.tbl_map(function(w) return vim.bo[vim.api.nvim_win_get_buf(w)].filetype end, vim.api.nvim_tabpage_list_wins(0)), msgs = vim.fn.execute("messages") })'
```

End state seen (0.12.6, seeded and `--live`, RUNS-FROM-EVIDENCE-PHASE-2): `vim.v.errmsg` is `""` (base:
`E216: No such group or event: FileExplorer *`). `:e .` leaves one window whose filetype is `NvimTree`, cwd
`<WORK>`, `:messages` empty, the same as on the base.

## Gotchas

- gofumpt and stylua are kept by mason-tool-installer alone (`auto_update = true`,
````
Replace `RUNS-FROM-EVIDENCE-PHASE-2` with the after run ids from `evidence-phase-2.md` (seeded and live).
**Impact:** doc only.

### Step 5: `features/lsp.md`: CursorHold float and fidget health
**File:** `.claude/skills/verify-nvim-config/features/lsp.md:38-40`. Insert two subsections between the end of
the "End states seen" paragraph (`:38`) and `## Gotchas` (`:40`). Phase 3 adds its completion journey to
this file after this phase; it must append its own subsection and leave these two intact.

old:
```markdown
clients are `lua_ls,stylua` (mason-lspconfig auto-enables Mason's stylua as a language server).

## Gotchas
```
new:
````markdown
clients are `lua_ls,stylua` (mason-lspconfig auto-enables Mason's stylua as a language server).

### CursorHold diagnostic float

`diagnostic-conf.lua` opens `vim.diagnostic.open_float({ width = 100 })` on CursorHold (`updatetime` 500)
when the cursor moved in a buffer with diagnostics. nvim caps the float's width to the window's width
minus the `single` border (2), so in a window of 1-2 columns `nvim_open_win` used to throw. The callback
now skips the float there. Repro (the `:2vsplit` window is the narrow one, and it gets the cursor):

```sh
$V keys RUN : e Space sample.lua Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="lua_ls"})), ",")' lua_ls 60
$V keys RUN G o
$V keys RUN --paste 'x = undefined_thing'
$V keys RUN Escape Escape
$V wait RUN '#vim.diagnostic.get(0, {lnum = vim.fn.line(".") - 1}) > 0' true 60
$V keys RUN k j
$V wait RUN '(function() for _, w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(w).relative ~= "" and vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, 1, false)[1] == "Diagnostics:" then return vim.api.nvim_win_get_width(w) end end return 0 end)()' 100 15
$V keys RUN : 2 v s p l i t Enter
$V keys RUN k j
$V keys RUN h
$V screen RUN narrow
$V wait RUN 'vim.deep_equal(vim.b.diagnostics_pos, vim.api.nvim_win_get_cursor(0))' true 10
$V lua RUN '{ width = vim.api.nvim_win_get_width(0), floats = #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative ~= "" and vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, 1, false)[1] == "Diagnostics:" end, vim.api.nvim_list_wins()), messages = vim.fn.execute("messages") }'
```

End state seen (0.12.6, seeded and `--live`, RUNS-FROM-EVIDENCE-PHASE-2): in the full-width window the
diagnostic float opens with width `100`. In the 2-column window the screen has no `Invalid 'width'`,
`diagnostics_pos` equals the cursor (the hold ran), and the probe is `{ width = 2, floats = 0, messages = "" }`.
On the base the `screen` after `h` showed `Error in CursorHold Autocommands for "*"` ... `util.lua:1760:
Invalid 'width': expected positive Integer` and `Press ENTER` (live run `1104-121901-2809686`,
`evidence/14-screen-screen.txt`); press `Enter` before any `lua`/`wait`, which block on that prompt.

### fidget health

fidget keeps its notification window off nvim-tree through `notification.window.avoid = { "NvimTree" }`;
`config/fidget-nvim.lua` turns the deprecated implicit integration off after `setup()` (passing it to
`setup()` is reported as a deprecated option).

```sh
$V keys RUN : e Space sample.lua Enter                    # fidget loads on BufRead
$V keys RUN : checkhealth Space fidget Enter
$V wait RUN 'vim.bo.filetype' checkhealth 15
$V lua RUN 'table.concat(vim.tbl_filter(function(l) return l:find("WARNING", 1, true) ~= nil end, vim.api.nvim_buf_get_lines(0, 0, -1, false)), "\n")'
$V keys RUN : q Enter
$V lua RUN 'require("fidget.notification.window").get_window_position(); return vim.inspect(require("fidget.notification.window").options.avoid)'
```

End state seen (RUNS-FROM-EVIDENCE-PHASE-2): no WARNING line (base:
`- ⚠️ WARNING nvim-tree.lua integration is implicitly enabled`), and avoid is `{ "NvimTree" }`, as on the base.

## Gotchas
````
Replace `RUNS-FROM-EVIDENCE-PHASE-2` with the after run ids.
**Impact:** doc only.

### Step 6: `evidence-phase-2.md`
**File:** `.workflows/plan/nvim-0-12-clean/evidence-phase-2.md` (create). Fill it from the Proof runs; every
cell is a real path under `~/.local/state/nvim-config-verify/<run>/evidence/`.
```markdown
# Phase 2 evidence: E216, CursorHold width, fidget integration

Base for "before": the worktree with phase 2's three Lua edits stashed (`9cea538` + phase 1).
"After": the same run after `git stash pop` + `verify.sh sync`.

| Journey | Mode | Run | Before (failure) | After |
|---|---|---|---|---|
| J1 `v:errmsg` after startup (R5) | live | <run> | <path> `E216: ... FileExplorer *` | <path> `""` |
| J1 `v:errmsg` after startup (R5) | seeded | <run> | <path> | <path> |
| J2 `:e .` opens nvim-tree | live | <run> | <path> | <path> |
| J2 `:e .` opens nvim-tree | seeded | <run> | <path> | <path> |
| J3 CursorHold `:2vsplit` (R3) | live | <run> | <screen path> traceback | <screen path> + probe |
| J3 CursorHold `:2vsplit` (R3) | seeded | <run> | <path> | <path> |
| J3 full-width float width 100 | live | <run> | <path> | <path> |
| J3 full-width float width 100 | seeded | <run> | <path> | <path> |
| J4 `:checkhealth fidget` (R6) | live | <run> | <path> WARNING | <path> none |
| J4 `:checkhealth fidget` (R6) | seeded | <run> | <path> | <path> |
| J4 fidget avoid list | live | <run> | <path> | <path> |
| J4 fidget avoid list | seeded | <run> | <path> | <path> |
| `:messages` + doctor after | live | <run> | — | <path>, doctor exit 0 |
| `:messages` + doctor after | seeded | <run> | — | <path>, doctor exit 0 |
| Neighbor: lsp.md lua_ls/gopls/pyright attach | seeded | <run> | — | <path> |

Planning measurements: live `1104-121455-2789754/evidence/01-lua-vim.v.errmsg.txt` (E216),
live `1104-121901-2809686/evidence/14-screen-screen.txt` (Invalid 'width'), seeded
`1104-123239-2888928/evidence/03`-`06` (hijack on base; errmsg empty + hijack with Step 1 in the run snapshot).
```
**Impact:** doc only.

## Principles applied

- Fix root causes: each fix states the reproduction and the line (nvim-tree `manage_netrw` `:125-126`;
  `lsp/util.lua` width clamp `:1537-1600` → `:1760`; fidget `health.lua:55-60` + `options.lua:117-118`).
  For E216 the cause is fixed (stop running the autocmd) rather than clearing `v:errmsg` after startup.
- Laziness protocol: the CursorHold fix is one guard; no width cap is added in the config because the
  runtime already caps to `window - 2` (measured: 3 cols → 1, 150 cols → 100), so `width = 100` stays and a
  duplicate `math.min` would only restate nvim's rule. nvim-tree: two option values, no new code.
- Prove it works: every journey runs on `up --live` and `up`, failure first, with the user's keys
  (`:e .`, `:2vsplit`, `k j h`, `:checkhealth fidget`); `lua` only reads state.
- Test behavior, not implementation: the fidget proof asserts the observable result (no WARNING, avoid list
  `{ "NvimTree" }` after positioning), not the option value it sets; the CursorHold proof asserts "no error,
  no float, the hold ran" rather than inspecting the guard.

## Verification

**Build:** `nvim --headless -u NONE -c 'lua for _, f in ipairs({"lua/config/nvim-tree.lua","lua/diagnostic-conf.lua","lua/config/fidget-nvim.lua"}) do assert(loadfile(f)) end' -c 'qa!'` from the worktree root (syntax check; prints nothing on success, exit 0).
**Tests:** none in this repo; the Proof journeys are the tests.
**Proof:**
- Harness: `.claude/skills/verify-nvim-config` (`scripts/verify.sh`), with phase 1 landed (`sync` keeps `run_path`).
- Feature-map entries: `features/startup.md` (Step 4), `features/lsp.md` (Step 5).
- Recipe (the skill's stash/sync, per mode). From the worktree root, with Steps 1-3 applied and
  **uncommitted**:
  ```sh
  cd /home/miftah/.worktrees/nvim/nvim-0-12-clean
  V=.claude/skills/verify-nvim-config/scripts/verify.sh
  git stash push -- lua/config/nvim-tree.lua lua/diagnostic-conf.lua lua/config/fidget-nvim.lua
  $V up --live            # note RUN; snapshot = base Lua files
  $V doctor RUN           # exit 0
  # BEFORE: J1, J4, J3, J2 below, in that order
  git stash pop
  $V sync RUN             # restarts nvim on the fixed files (phase 1: same PATH)
  $V doctor RUN           # exit 0, "messages ok"
  # AFTER: J1, J4, J3, J2 below, in that order
  $V lua RUN 'vim.fn.execute("messages")'     # ""
  $V down RUN
  ```
  Then the same block with `$V up` (seeded) in place of `$V up --live`. `.claude/` is not snapshotted, so
  the doc edits need not be stashed. If `git stash pop` conflicts, stop: nothing else should touch those files.
  Do not paste `x = undefined_thing` twice per drive check: each drive (before, after) pastes its own line at
  the end of `sample.lua` with `G o`; the cursor is always on the newest one.

- **J1 (R5) `v:errmsg` after startup** — first probe after `up` / `sync`, before any key:
  ```sh
  $V lua RUN 'vim.v.errmsg'
  ```
  Before: `E216: No such group or event: FileExplorer *`. After: empty string (the evidence file's result
  line is blank). Failing condition after the fix: any non-empty value.

- **J4 (R6) fidget health** — commands as in Step 5 "fidget health". Before: one line
  `- ⚠️ WARNING nvim-tree.lua integration is implicitly enabled`. After: the WARNING probe returns an empty
  string. Avoid-list probe: `{ "NvimTree" }` both before and after (behaviour unchanged).

- **J3 (R3) CursorHold float** — commands as in Step 5 "CursorHold diagnostic float" (sample.lua is already
  open from J4; the `: e Space sample.lua Enter` is harmless). Before: the full-width `wait ... 100 15` passes;
  after `h`, `$V screen RUN narrow` shows `Error in CursorHold Autocommands for "*"` and
  `Invalid 'width': expected positive Integer` with `Press ENTER` — **do not** run the following `wait`/`lua`
  lines on the before; run `$V keys RUN Enter` instead, then `$V keys RUN : o n l y Enter`. After: the
  full-width wait returns `100`; the narrow screen has no `Invalid` text; `wait ... diagnostics_pos ... true`
  passes; the probe prints `width = 2, floats = 0, messages = ""`. Then `$V keys RUN : o n l y Enter`.
  If the `#vim.diagnostic.get(...)` wait times out (lua_ls not attached), the journey is inconclusive, not passed.

- **J2 directory hijack (invariant 5)** — commands as in Step 4:
  ```sh
  $V keys RUN : e Space . Enter
  $V lua RUN 'vim.inspect({ cwd = vim.fn.getcwd(), wins = vim.tbl_map(function(w) return vim.bo[vim.api.nvim_win_get_buf(w)].filetype end, vim.api.nvim_tabpage_list_wins(0)), msgs = vim.fn.execute("messages") })'
  ```
  Before and after: `cwd = "<WORK>"`, `wins = { "NvimTree" }`, `msgs = ""`. Planning measured the before on
  seeded run `1104-123239-2888928` (`evidence/03`).

- **Neighbor check:** the `features/lsp.md` "Driving it with verify.sh" block (lua_ls, gopls, pyright attach
  + the `reportAssignmentType` diagnostic) on the seeded after-run (or a fresh `$V up` after the commit):
  `wait ok` for all three clients and `reportAssignmentType`. Also `$V doctor RUN` exit 0 with
  `messages ok` after each AFTER drive, and `messages-at-down.txt` free of `E\d+:` and `Invalid`.
- Cost: none (no paid drives). Two runs (~7 s live, ~1 s seeded to start), plus lua_ls attach time.

**Exit criteria:** on both `up --live` and `up`, recorded in `evidence-phase-2.md`: J1 before `E216...`,
after `""`; J3 before the "Invalid 'width'" traceback, after no error, `floats = 0` in the 2-column window and
a width-100 float in the full window; J4 before one WARNING, after none, avoid `{ "NvimTree" }` in both;
J2 `:e .` → single `NvimTree` window before and after; `:messages` empty and doctor exit 0 after.

## Handoffs

- Phase 4 (`features/health.md` allow-list, R6 sweep): the `fidget` section should be all OK after this
  phase; do not allow-list `nvim-tree.lua integration is implicitly enabled` or
  `Deprecated setup option: 'integration.nvim-tree.enable'`. If a fidget bump ever removes
  `fidget.integration.nvim-tree`, the guard in `config/fidget-nvim.lua` makes the after-setup line a no-op.
- Phase 4 (`features/README.md`, owned there): the "Known on the base" cells for Startup (E216 fixed) and
  LSP (CursorHold "Invalid 'width'" fixed) should mention these fixes.
- Phase 3 (`features/lsp.md`): append the completion journey as its own subsection; leave
  "CursorHold diagnostic float" and "fidget health" intact.
- Not done, out of scope: nvim-tree is loaded at startup despite its `keys = { "<space>s" }` spec
  (`package.loaded["nvim-tree"]` true right after `up`); harmless, and the directory hijack relies on it
  being loaded. No phase owns changing it.

## Rollback

`git revert <phase-2 commit>` on `feature/nvim-0-12-clean` (or drop the commit before land). It restores the
three Lua files and the two feature docs and removes `evidence-phase-2.md`. Nothing outside the worktree was
written except run evidence under `~/.local/state/nvim-config-verify/`; the seed and the owner's live dirs are
untouched.
