# Phase 6: Graceful offline lazy bootstrap

**Plan set:** `FIX_BUGS_NVIM_0_12_PLAN.md`
**Analysis:** `docs/analyzer/20261104-102452-MRDD_code_analyzer.md`
**Satisfies:** R7: an offline first start (lazy bootstrap clone fails) degrades gracefully. One clear message, and the rest of `init.lua` still loads.
**Depends on:** Phase 5 (and, through it, Phase 4; both only edit SKILL.md text outside this phase's bullet)
**Difficulty:** NORMAL
**Package:** `lua/` (+ `.claude/skills/verify-nvim-config/` docs)

---

> **Set-wide execution rules** (plan index § Execution rules; they override any command below that disagrees):
> 1. `$WT` is **this phase's own worktree root** (`WT=$(git rev-parse --show-toplevel)`). Wave-1 phases run
>    concurrently in separate worktrees, so never `cd` into another phase's tree.
> 2. **No `git stash`** (the stash stack is shared by every worktree of the repo). Swap base and fix per file:
>    `SW=$(mktemp -d)`; BASE = `cp <path> "$SW/" && git show "$PHASE_BASE:<path>" ><path>`; FIX = `cp "$SW/<file>" <path>`,
>    where `PHASE_BASE=$(git rev-parse HEAD)` is recorded before this phase's first edit. A new file's BASE is `mv <path> "$SW/"`.
> 3. Commit with an explicit pathspec: `git add -- <new files>` then `git commit -m "..." -- <every path>`.
> 4. Evidence goes to `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-6.md`, this phase's own file (never a shared one),
>    written only **after every run of the phase is down** (the file is inside the snapshotted tree; a mid-run write makes
>    `doctor` print `code WARN`). It is committed as the phase's last commit:
>    `git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-6.md && git commit -m "docs(evidence): phase 6 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-6.md`.
>    `.workflows/` is tracked (the orchestrator commits the plan set); commit nothing else under it unless this plan says so.
> 5. Never `git push`. Never write `~/.config/nvim`, `~/.local/share/nvim` or `/opt/nvim-linux-x86_64`.

## Goal

Today a start with no `lazy.nvim` and no network dies with `E5113 ... plugin_specs.lua:587: module 'lazy' not found`.
That aborts `viml_conf/plugins.vim`, so `diagnostic-conf` and the colorscheme never load. After this phase,
`plugin_specs.lua` checks the clone, deletes any partial clone, prints ONE `WarningMsg` line saying what failed,
that plugins are off and how to retry, and returns before `lazy.setup`. The rest of `plugins.vim`, `diagnostic-conf`
and `colorschemes` then load, and `rand_colorscheme` falls back to the builtin `habamax`. Seeded and live
startups behave exactly as before.

## Reproduction and cause (base, measured 2026-11-04 on nvim 0.11.5)

- `verify.sh up --bare` on base prints `E5113: Error while calling lua chunk: ... plugins.vim, line 4: Vim(lua):E5108: Error executing lua ...lua/plugin_specs.lua:587: module 'lazy' not found:` plus a traceback. The screen shows only `[No Name]`. `doctor` reports `messages WARN errors in :messages`.
- `$V lua RUN '{ colors = tostring(vim.g.colors_name), ul = vim.diagnostic.config().underline, sev = tostring(vim.diagnostic.config().severity_sort) }'` gives `colors = "nil", sev = "false", ul = true`: diagnostic-conf (which sets `underline = false`, `severity_sort = true`) never ran.
- Cause: `lua/plugin_specs.lua:8-17` runs `vim.fn.system { "git", "clone", ... }` and ignores `vim.v.shell_error`. Line 18 prepends a lazypath that does not exist, and line 587 `require("lazy").setup` raises.
- Second cause on the same path: `lua/colorschemes.lua:136-141` `rand_colorscheme` calls a random plugin scheme unguarded. With no plugins it would raise next (`init.lua:43`).
- Mappings and leader are already present on base (`init.lua:28` runs `mappings` before `plugins.vim`), and they still must be after the change.

## Interface Contract

**Deletes:** the unguarded `require("lazy").setup {` call at `lua/plugin_specs.lua:587` (replaced by `lazy.setup {` using a local)
**Renames:** none
**Creates:**
- `local function disable_plugins(cause, retry)` (file-local, `lua/plugin_specs.lua:10`)
- `local lazy_loaded, lazy` (file-local, `lua/plugin_specs.lua:36`)
- `M.fallback_colorscheme = "habamax"` (`lua/colorschemes.lua`, public module field)

**Signature changes:** none. `require("plugin_specs")` may now return early (it returns nothing either way). `colorschemes.rand_colorscheme()` no longer raises when the picked scheme fails.
**Line shift for later phases:** `lua/plugin_specs.lua` grows by **22 lines**, all inserted before the first spec. Every line after base line 18 moves down by 22. Base `local firenvim_not_active` at :20 is now :42. The mason spec at base ~:522-529 is now ~:544-551. The last block becomes `lazy.setup {` at base :587 -> :609. Phases 7/8/9 must anchor on text, not on base line numbers.
**Final text of `lua/plugin_specs.lua` lines 1-45** (for phases 7/8/9 to quote):

```lua
-- /home/miftah/.config/nvim/lua/plugin_specs.lua

local utils = require("utils")

local plugin_dir = vim.fn.stdpath("data") .. "/lazy"
local lazypath = plugin_dir .. "/lazy.nvim"

-- Without lazy.nvim no plugin can load: say so once, as a warning, and return, so the rest of
-- init.lua (options, mappings, diagnostics, a builtin colorscheme) still loads.
local function disable_plugins(cause, retry)
  vim.api.nvim_echo({
    { string.format("lazy.nvim %s: plugins off until %s", cause, retry), "WarningMsg" },
  }, true, {})
end

if not vim.uv.fs_stat(lazypath) then
  local cloned = pcall(vim.fn.system, {
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
  if not cloned or vim.v.shell_error ~= 0 or not vim.uv.fs_stat(lazypath .. "/lua/lazy/init.lua") then
    -- a partial clone would skip this bootstrap on the next start
    vim.fn.delete(lazypath, "rf")
    local cause = cloned and string.format("clone failed (git exit %d)", vim.v.shell_error)
      or "clone failed (git not runnable)"
    disable_plugins(cause, "an online restart")
    return
  end
end
vim.opt.rtp:prepend(lazypath)

local lazy_loaded, lazy = pcall(require, "lazy")
if not lazy_loaded then
  disable_plugins("not loadable", "you delete " .. lazypath .. " and restart online")
  return
end

-- check if firenvim is active
local firenvim_not_active = function()
  return not vim.g.started_by_firenvim
end
```

**Requires (from earlier phases):** Phase 4 removed the opencode text from SKILL.md, and Phase 5 rewrote the "Never driven" bullet's deploy sentence. Neither touches the `--bare` Gotcha bullet this phase replaces, so it is anchored by its text (`- **\`--bare\` fails at \`require("lazy")\`**`), not by a line number.
**Leaves alone (owned by others):** every plugin spec in `plugin_specs.lua` (mason ~:544 is Phase 7, hop is Phase 8, treesitter/textobjects/tool-installer are Phase 9), `init.lua` (Phase 9), the Sub-features Mason bullet, the Mason paragraph `startup.md:27-37` and the first Gotcha `startup.md:50-53` (Phase 7), the `expects 0.11.5` text `startup.md:5` and `features/README.md` (Phase 9), `verify.sh` (no change; see Handoffs), and SKILL.md's Launch `up --bare` line (its text, "no plugins, no Mason: a fresh machine with no network (fault injection)", stays accurate, so it is unchanged).

## Files

| File | Action | What changes |
|---|---|---|
| `lua/plugin_specs.lua` | modify | `:8-18` bootstrap: checked clone, partial-dir cleanup, one warning, early return, `pcall(require, "lazy")`; `:586-587` `require("lazy").setup` -> `lazy.setup` |
| `lua/colorschemes.lua` | modify | `:135-141`: `M.fallback_colorscheme`, `rand_colorscheme` pcall + builtin fallback |
| `.claude/skills/verify-nvim-config/features/startup.md` | modify | Fault-injection section `:39-46` rewritten to the new end state, plus the broken-dir journey; second Gotcha `:54-55` replaced; colorscheme Gotcha `:56` gains the bare exception |
| `.claude/skills/verify-nvim-config/SKILL.md` | modify | Gotchas bullet "`--bare` fails at `require(\"lazy\")`" (base `:177-179`, shifted up by Phases 4/5) replaced |
| `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-6.md` | create (after all runs are down) | `## Phase 6` evidence paths; own commit (execution rule 4) |

## Implementation Steps

### Step 0: Record the base (must fail before the fix)
Before editing anything, on the Phase-5 tip, run Proof journeys **J1** and **J4-base** and keep their RUN ids and evidence paths for Step 6.

### Step 1: Checked bootstrap with an early return
**File:** `lua/plugin_specs.lua:8-18`
**Change:** Replace these base lines:

```lua
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)
```

with the following. Lines 1-7 and everything from `-- check if firenvim is active` onward are unchanged. 2-space indent; it passes `stylua --check` with the repo's `.stylua.toml`.

**Code:**
```lua
-- Without lazy.nvim no plugin can load: say so once, as a warning, and return, so the rest of
-- init.lua (options, mappings, diagnostics, a builtin colorscheme) still loads.
local function disable_plugins(cause, retry)
  vim.api.nvim_echo({
    { string.format("lazy.nvim %s: plugins off until %s", cause, retry), "WarningMsg" },
  }, true, {})
end

if not vim.uv.fs_stat(lazypath) then
  local cloned = pcall(vim.fn.system, {
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
  if not cloned or vim.v.shell_error ~= 0 or not vim.uv.fs_stat(lazypath .. "/lua/lazy/init.lua") then
    -- a partial clone would skip this bootstrap on the next start
    vim.fn.delete(lazypath, "rf")
    local cause = cloned and string.format("clone failed (git exit %d)", vim.v.shell_error)
      or "clone failed (git not runnable)"
    disable_plugins(cause, "an online restart")
    return
  end
end
vim.opt.rtp:prepend(lazypath)

local lazy_loaded, lazy = pcall(require, "lazy")
if not lazy_loaded then
  disable_plugins("not loadable", "you delete " .. lazypath .. " and restart online")
  return
end
```

Design notes (keep these in the commit message, not in the code):
- `pcall(vim.fn.system, ...)`: with no `git` on PATH, `system()` itself raises E475. That is the "git not runnable" branch.
- The check is `shell_error` plus the presence of `lua/lazy/init.lua`. A clone that exits 0 but is unusable is treated as failed.
- `vim.fn.delete(lazypath, "rf")` removes a partial clone. Without it, the next start's `fs_stat(lazypath)` would skip the bootstrap and hit the second guard forever.
- The second guard covers a `lazy.nvim` dir that exists but cannot be loaded (an old interrupted clone). Restarting alone cannot fix that, so its retry text names the dir to delete.
- The message uses `WarningMsg` and `history = true`, and has no `E\d+:`/`error`/`Error` in it. It is a deliberate degraded mode, not an error, so `verify.sh up` does not print "startup :messages contain errors" and `doctor` says `messages ok`. The harness's grep is unchanged. Any real error on a bare start still trips it.
- Width: the clone message is 74 characters (`lazy.nvim clone failed (git exit 128): plugins off until an online restart`). It fits an 80-column command line, so it never scrolls into a hit-enter prompt that blocks startup.
- Requiring `lazy` before the spec table is built does not change normal starts. `require("lazy")` only loads the module, and `setup` does the work, exactly as before. Measured on the prototype: `up` and `up --live` gave empty `00-up-messages.txt` and `count = 93` both before and after the change.

**Impact:** When lazy is missing, nothing after line 40 runs (no spec table, no `lazy.setup`, so no `:Lazy`/`:Mason`/plugin commands). When lazy is present, behavior is identical.

### Step 2: Use the guarded local for setup
**File:** `lua/plugin_specs.lua:586-587` (base numbering; after Step 1 these are `:608-609`)
**Change:** The final block becomes:
**Code:**
```lua
---@diagnostic disable-next-line: missing-fields
lazy.setup {
  spec = plugin_specs,
  ui = {
    border = "rounded",
    title = "Plugin Manager",
    title_pos = "center",
  },
  rocks = {
    enabled = false,
    hererocks = false,
  },
}
```
**Impact:** none at runtime (`lazy` is the same module table that `require("lazy")` returned).

### Step 3: Builtin colorscheme fallback
**File:** `lua/colorschemes.lua:135-141`
**Change:** Replace the base block

```lua
--- Use a random colorscheme from the pre-defined list of colorschemes.
M.rand_colorscheme = function()
	local colorscheme = utils.rand_element(vim.tbl_keys(M.colorscheme_conf))

	-- Load the colorscheme and its settings
	M.colorscheme_conf[colorscheme]()
end
```

with the following (tabs, matching the file; the file is already not stylua-formatted, so do not run stylua on it):

**Code:**
```lua
-- Builtin (ships with nvim), so it loads with no plugins at all.
M.fallback_colorscheme = "habamax"

--- Use a random colorscheme from the pre-defined list of colorschemes.
M.rand_colorscheme = function()
	local colorscheme = utils.rand_element(vim.tbl_keys(M.colorscheme_conf))

	-- Load the colorscheme and its settings
	local ok, err = pcall(M.colorscheme_conf[colorscheme])
	if ok then
		return
	end

	vim.cmd.colorscheme(M.fallback_colorscheme)
	-- With lazy.nvim missing, no plugin colorscheme can load and plugin_specs.lua has already said why.
	if package.loaded["lazy"] then
		vim.notify(
			string.format("colorscheme %s failed, using %s: %s", colorscheme, M.fallback_colorscheme, err),
			vim.log.levels.WARN
		)
	end
end
```

**Impact:** On a bare start, `habamax` loads silently, so plugin_specs' line stays the only message. On a normal start where a plugin scheme breaks (base: an E5113 traceback that aborts the end of init.lua), the owner now gets `habamax` plus one WARN that carries the original error text. That text contains the `E\d+:` code, so the harness still flags it. `habamax` exists in nvim 0.11.5 (`/opt/nvim-linux-x86_64/share/nvim/runtime/colors/habamax.vim`) and in 0.12 (Phase 9).

### Step 4: Feature map `features/startup.md`
**File:** `.claude/skills/verify-nvim-config/features/startup.md:39-46` (Fault-injection section). Replace from `Fault injection (fresh machine, no network):` through `` `doctor` reports `nvim info --bare run: 1`. `` with:

**Code:**
````markdown
Fault injection (fresh machine, no network):

```sh
$V up --bare               # MODE=bare; no "startup :messages contain errors"
cat EVIDENCE/00-up-messages.txt
$V lua RUN '{ colors = vim.g.colors_name, underline = vim.diagnostic.config().underline, severity_sort = vim.diagnostic.config().severity_sort, leader = vim.g.mapleader, save = vim.fn.maparg("<leader>w", "n"), lazy = package.loaded.lazy ~= nil, lazy_dir = vim.fn.isdirectory(vim.fn.stdpath("data") .. "/lazy/lazy.nvim") }'
$V doctor RUN
```

End state seen: `00-up-messages.txt` holds one line (WarningMsg): `lazy.nvim clone failed (git exit
128): plugins off until an online restart`. The Lua table is `colors = "habamax", underline = false,
severity_sort = true, leader = ",", save = "<Cmd>update<CR>", lazy = false, lazy_dir = 0`, which means
diagnostic-conf ran, the builtin fallback colorscheme is active, mappings are in place, and the partial
clone was deleted. The screen shows a `[No Name]` buffer and no dashboard (the dashboard is a plugin).
`doctor` reports `nvim info --bare run: 1` and `messages ok   no errors in :messages`.
The warning shows on the command line at start, but the harness's client attach resizes the pane
and the redraw can clear it, so read `00-up-messages.txt`, not the screen.

A `lazy.nvim` dir that exists but cannot load (an old interrupted clone):

```sh
mkdir -p ~/.local/state/nvim-config-verify/RUN/xdg/data/nvim/lazy/lazy.nvim
$V headless RUN +'lua io.stdout:write(vim.fn.execute("messages"), "\n", tostring(vim.g.colors_name), "\n")' +qa
```

End state seen: `lazy.nvim not loadable: plugins off until you delete <run>/xdg/data/nvim/lazy/lazy.nvim
and restart online`, then `habamax`, with no traceback.
````

**File:** `features/startup.md:54-55`. Replace the Gotcha bullet `- Product finding (base): the lazy bootstrap ... skips the rest of \`init.lua\`.` with:

```markdown
- With lazy.nvim missing, `plugin_specs.lua` returns before the spec table: no plugin command
  exists (`:Lazy`, `:Mason`, `:FzfLua`), and `colorschemes.lua` falls back to `habamax` without a
  second message. With lazy loaded, a plugin scheme that fails also falls back to `habamax`, but warns
  with the scheme name and its error. `verify.sh sync` cannot restart a bare run (it waits for
  fzf-lua). Use `down`, then `up --bare` again.
```

**File:** `features/startup.md:56`. Replace `- Never assert the colorscheme name: \`utils.rand_int\` seeds with \`os.time()\`.` with:

```markdown
- Never assert the colorscheme name on a seeded or `--live` run: `utils.rand_int` seeds with
  `os.time()`. On `--bare` it is always `habamax` (the builtin fallback).
```

Leave lines 1-38 and 47-53 (Phase 7/9 territory) and line 57-58 untouched.

### Step 5: SKILL.md Gotcha
**File:** `.claude/skills/verify-nvim-config/SKILL.md`, the Gotchas bullet starting `- **\`--bare\` fails at \`require("lazy")\`**` (base `:177-179`; locate it by text after Phases 4/5). Replace the whole 3-line bullet with:

**Code:**
```markdown
- **`--bare` starts without plugins, by design**: the lazy bootstrap clone fails (no network),
  `plugin_specs.lua` warns once (`lazy.nvim clone failed (git exit 128): plugins off until an online
  restart`) and returns, and the rest of `init.lua` loads with the builtin `habamax` colorscheme (the
  one run where asserting the name is valid). The warning is not an error: `up` prints nothing and
  `doctor` says `messages ok`. Any `E\d+:` on a bare start is a regression. `sync` cannot restart a
  bare run (it waits for fzf-lua): `down`, then `up --bare` again.
```

### Step 6: Prove, record evidence, commit
Run every Proof journey below. **After** the last run is down, write
`$WT/.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-6.md` (heading `## Phase 6`; phase 9 builds the
set's `evidence.md` index from it) with one line per journey:
`- J<n> <before|after> <mode>: RUN=<id> <evidence dir>, <one-line end state>`. Write it after the runs,
because the file is inside the snapshotted tree and editing it mid-run makes `doctor` print `code WARN`.
Then commit only this phase's files (do not push):

```sh
cd "$WT"   # this phase's own worktree root (index § Execution rules)
git commit -m "fix(bootstrap): keep starting when lazy.nvim cannot be cloned" -m "The lazy bootstrap ignored the git clone result, so an offline first start died with E5113 in require(\"lazy\") and skipped diagnostics and the colorscheme. Check shell_error and the cloned module, delete a partial clone, warn once (WarningMsg) and return before lazy.setup; pcall(require, \"lazy\") guards a broken existing dir. rand_colorscheme falls back to the builtin habamax when the picked scheme fails." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" \
  -- lua/plugin_specs.lua lua/colorschemes.lua .claude/skills/verify-nvim-config/features/startup.md .claude/skills/verify-nvim-config/SKILL.md
git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-6.md
git commit -m "docs(evidence): phase 6 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-6.md
```

## Principles applied

- Fix root causes: the plan states the measured reproduction (`up --bare` E5113 at `plugin_specs.lua:587`, `colors_name = nil`, `underline = true`) and traces it to the unchecked `vim.fn.system` at `:9`. The fix checks the clone where it happens instead of only wrapping the `require`.
- Laziness protocol: no new module or config option. One file-local helper, used by the two failure branches; one local reused by `lazy.setup`; the fallback is a single `pcall` in the existing function. The prototype's richer git-stderr reporting was dropped because it pushed the line past 80 columns and into a hit-enter prompt.
- Boundary discipline: the external input (git's result) is checked once, at the bootstrap. Downstream code (`colorschemes`) only reads `package.loaded["lazy"]` to decide whether to stay silent. It does not re-check the clone.
- Prove it works: Proof uses the repo's verify harness on the real nvim in tmux with no network. It includes a base journey that must fail first and neighbor journeys on `up` and `up --live`. All of it was measured on a prototype clone before this plan was written.

## Verification

**Build:** `~/.local/share/nvim/mason/bin/stylua --check lua/plugin_specs.lua` (exit 0; `colorschemes.lua` is tab-indented and already not stylua-clean, so do not check it) and `/opt/nvim-linux-x86_64/bin/nvim --version | head -1` = `NVIM v0.11.5`.
**Tests:** no unit-test suite in this repo; the harness journeys below are the tests.
**Proof:**
- Harness: `.claude/skills/verify-nvim-config` (`V=.claude/skills/verify-nvim-config/scripts/verify.sh`, run from this phase's worktree root (`$WT`, index § Execution rules); zsh: never `echo ====`). Installed nvim 0.11.5, no `VERIFY_NVIM` override.
- Feature-map entries: `.claude/skills/verify-nvim-config/features/startup.md`
- Journeys (`RUN`/`EVIDENCE` are the values `up` prints; `down RUN` after each):
  - **J1 (base, must fail)**: before any edit (or with the base files swapped in per execution rule 2; never `git stash`), `$V up --bare 2>&1 | tee /dev/stderr | grep -c "module 'lazy' not found"` gives `>= 1`, and stderr shows `verify: startup :messages contain errors:` with `E5113`. `$V lua RUN '{ colors = tostring(vim.g.colors_name), ul = vim.diagnostic.config().underline }'` gives `colors = "nil", ul = true`. `$V doctor RUN | grep '^messages'` gives `messages WARN errors in :messages:`.
  - **J2 (after, offline clone fails)**: `$V up --bare 2>&1`. Its output contains no `startup :messages contain errors` and no `E5113`. `cat EVIDENCE/00-up-messages.txt` shows exactly one non-empty line: `lazy.nvim clone failed (git exit 128): plugins off until an online restart`. Run `$V lua RUN '{ colors = vim.g.colors_name, underline = vim.diagnostic.config().underline, severity_sort = vim.diagnostic.config().severity_sort, leader = vim.g.mapleader, save = vim.fn.maparg("<leader>w", "n"), gts = vim.fn.maparg(",gts", "n") ~= "", lazy = package.loaded.lazy ~= nil, lazy_dir = vim.fn.isdirectory(vim.fn.stdpath("data") .. "/lazy/lazy.nvim"), did = vim.v.vim_did_enter }'`. It must return `colors = "habamax", underline = false, severity_sort = true, leader = ",", save = "<Cmd>update<CR>", gts = true, lazy = false, lazy_dir = 0, did = 1`. `$V doctor RUN | grep -E '^(nvim|messages)'` gives `nvim     info --bare run: 1` and `messages ok   no errors in :messages`.
  - **J3 (after, broken existing dir; second guard)**: on a fresh `up --bare` RUN, `mkdir -p ~/.local/state/nvim-config-verify/RUN/xdg/data/nvim/lazy/lazy.nvim`, then `$V headless RUN +'lua io.stdout:write(vim.fn.execute("messages"), "\n", tostring(vim.g.colors_name), "\n")' +qa`. The output contains `lazy.nvim not loadable: plugins off until you delete ~/.local/state/nvim-config-verify/RUN/xdg/data/nvim/lazy/lazy.nvim and restart online` (absolute path) and `habamax`, and no `E5113`/`traceback`. Then `rmdir` that dir and re-run the same `headless` command: the output contains `lazy.nvim clone failed (git exit 128): plugins off until an online restart` and `habamax`, and `ls ~/.local/state/nvim-config-verify/RUN/xdg/data/nvim/lazy/` lists no `lazy.nvim`, because the partial clone was deleted.
- Neighbor check (**J4**, both before = J4-base and after): for each of `$V up` and `$V up --live`, the output has no `startup :messages contain errors`, and `EVIDENCE/00-up-messages.txt` is empty or whitespace-only. `$V lua RUN 'require("lazy").stats().count'` gives `93`. `$V doctor RUN | grep -E '^(nvim|messages)'` gives `nvim     ok ...VeryLazy plugins loaded` and `messages ok   no errors in :messages`. The base and after values must be identical. Measured on the prototype: base and after both gave count 93 and empty messages in both modes.
- Cost: none (no paid or LLM drives).

**Exit criteria:** J1 fails on the base as described. J2 and J3 pass after the change. J4 is identical before and after in both seeded and `--live` modes. `features/startup.md` and the SKILL.md Gotcha describe the J2 end state. The commit `fix(bootstrap): keep starting when lazy.nvim cannot be cloned` is on `feature/fix-bugs-nvim-0-12` (not pushed). The evidence paths are under `## Phase 6` in the committed `evidence-phase-6.md`.

## Handoffs

- `verify.sh` (not in this phase's scope): `nvim_ready` accepts `vim.g.verify_bare == 1`, but nothing sets that global, so `verify.sh sync` on a `--bare` run waits for fzf-lua and dies "nvim not ready after sync". This phase documents it in SKILL.md and startup.md. Making `sync`/`nvim_ready` accept a bare run (for example by passing `vim.v.vim_did_enter` for `mode=bare`, as `cmd_up` already does) is a harness change for a later set, not R7.
- Phases 7/8/9: `lua/plugin_specs.lua` lines after base :18 shift by +22. The final call is now `lazy.setup {` (not `require("lazy").setup {`). Anchor edits on text.
- Phase 9 (version line, `startup.md:5`): unaffected; `habamax` exists on 0.12, so J2's `colors = "habamax"` holds after the upgrade.
- Phase 7 owns `startup.md:7-8, 27-37, 50-53`. This phase edits only `:39-46`, `:54-55` and `:56`. If Phase 7 deletes the first Gotcha (`:50-53`), the bullets this phase wrote move up, and their text is unchanged.

## Rollback

`git revert <phase-6 commit>` on the feature branch. It touches only `lua/plugin_specs.lua`, `lua/colorschemes.lua`, `features/startup.md` and SKILL.md's one Gotcha bullet. Phases 7/8/9 edit other hunks of `plugin_specs.lua` and `startup.md`, so the revert applies cleanly unless they rewrote the same lines. No seed or live state changes in this phase.
