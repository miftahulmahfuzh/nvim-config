# Phase 3: Dashboard redraw follows the selection

**Plan set:** `FIX_BUGS_NVIM_0_12_PLAN.md`
**Analysis:** `docs/analyzer/20261104-102452-MRDD_code_analyzer.md` (Entry Point D)
**Satisfies:** R6 — on the start screen, `,bg` / `,bv` / `,bh` change the art you are looking at, not only the saved name
**Depends on:** none
**Difficulty:** NORMAL
**Package:** `lua/config` (`lua/config/dashboard-nvim.lua`) + `.claude/skills/verify-nvim-config/features/dashboard.md`

---

> **Set-wide execution rules** (plan index § Execution rules; they override any command below that disagrees):
> 1. `$WT` is **this phase's own worktree root** (`WT=$(git rev-parse --show-toplevel)`). Wave-1 phases run
>    concurrently in separate worktrees, so never `cd` into another phase's tree.
> 2. **No `git stash`** (the stash stack is shared by every worktree of the repo). Swap base and fix per file:
>    `SW=$(mktemp -d)`; BASE = `cp <path> "$SW/" && git show "$PHASE_BASE:<path>" ><path>`; FIX = `cp "$SW/<file>" <path>`,
>    where `PHASE_BASE=$(git rev-parse HEAD)` is recorded before this phase's first edit. A new file's BASE is `mv <path> "$SW/"`.
> 3. Commit with an explicit pathspec: `git add -- <new files>` then `git commit -m "..." -- <every path>`.
> 4. Evidence goes to `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-3.md`, this phase's own file (never a shared one),
>    written only **after every run of the phase is down** (the file is inside the snapshotted tree; a mid-run write makes
>    `doctor` print `code WARN`). It is committed as the phase's last commit:
>    `git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-3.md && git commit -m "docs(evidence): phase 3 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-3.md`.
>    `.workflows/` is tracked (the orchestrator commits the plan set); commit nothing else under it unless this plan says so.
> 5. Never `git push`. Never write `~/.config/nvim`, `~/.local/share/nvim` or `/opt/nvim-linux-x86_64`.

## Goal

After this phase, changing the art (`,bg`, `,bv`, `,bh`) redraws every window whose buffer is a
dashboard buffer: the start screen, the `,b` split, and a dashboard that sits behind a focused
nvim-tree window. A window the user has moved to another buffer is never redrawn. Before, only the
window tracked in `ascii_art_win` was redrawn, and only `,b` ever set it.

## Root cause (reproduced)

- Reproduction (seeded, 0.11.5): `$V up` → probe `shown=eyes saved=(none)` → `,bg` → probe
  `shown=eyes saved=family_guy_1`. The planner reproduced it headless against the base file
  (`-u NONE`, nvim-tree stubbed): after `cycle_next_ascii_art()` on the start screen, the window
  keeps the same buffer and the cache file holds the new name.
- Cause: `lua/config/dashboard-nvim.lua:382-385`. The no-split branch of `create_dashboard` runs
  `nvim_win_set_buf(0, buf)` and never sets `ascii_art_win` / `ascii_art_buf`. `update_ascii_art`
  redraws only `if ascii_art_win and api.nvim_win_is_valid(ascii_art_win)` (`:155`).
- A second defect from the same design, also reproduced against the base: `ascii_art_win` points
  at a window, not a dashboard. After `,b` then `e` (`:enew`) in the split, the window is still
  valid, so `,bg` puts the art back into the window the user just moved off (base headless run:
  `w1002 b5 ft=` becomes `w1002 b6 ft=dashboard`). That breaks the index's decision ("never touch a
  window that no longer shows the dashboard buffer"), so this phase fixes both by asking which
  windows show a dashboard buffer at redraw time, instead of remembering one.

## Interface Contract

**Deletes:** module locals `ascii_art_win`, `ascii_art_buf` (`lua/config/dashboard-nvim.lua:11-12`);
the `WinClosed` autocmd and its augroup `CustomDashboardWinCleanup` (`:440-450`); the
scheduled `nvim_buf_delete(ascii_art_buf)` cleanup (`:198-205`); the focus jump
`nvim_set_current_win(ascii_art_win)` after a redraw (`:237-244`).
**Renames:** none
**Creates:** local `render_dashboard(win)` (`lua/config/dashboard-nvim.lua`, between
`load_saved_art` and `update_ascii_art`). File-local, not exported.
**Signature changes:** none. `create_dashboard(split_mode)`, `update_ascii_art(art_name)` keep
their signatures; `_G.show_ascii_art_split`, `_G.select_ascii_art`, `_G.cycle_next_ascii_art`,
`_G.select_bikini_ascii_art` and the `<leader>b`, `<leader>bv`, `<leader>bg`, `<leader>bh` keymaps are
unchanged.
**Behaviour changes a user can see:** (1) the start screen redraws on `,bg`/`,bv`/`,bh`; (2) a
window that left the dashboard is not redrawn; (3) `,bg` no longer moves the cursor into the
dashboard split; (4) the `,b` split centres the art for the split's width (padding used to be
computed from the window before `vsplit`, i.e. about twice as wide). The probe strips padding, so
(4) changes no probe output.
**Unchanged on purpose:** the `VimEnter` and `BufLeave` autocmds (`:410-438`), buffer-local `q`,
`e`, `<space>s`, buffer options (`bufhidden=wipe`, `buftype=nofile`, `noswapfile`,
`filetype=dashboard`, `nomodifiable`), window options, the cache file path and format.
**Requires (from earlier phases):** nothing.
**Leaves alone (owned by others):** `ascii_art/*`, `.claude/skills/verify-nvim-config/features/lua/dashboard_art.lua`
(reused as is), `features/README.md` and `features/live-environment.md` (phase 9 / phase 5),
`lua/plugin_specs.lua` (phases 6, 7, 8), `init.lua` (phase 9).
**Note for phase 9:** this file no longer calls `nvim_buf_set_option` (deprecated on 0.12); it
uses `vim.bo[buf]`, which behaves the same on 0.11.5.

## Files

| File | Action | What changes |
|---|---|---|
| `lua/config/dashboard-nvim.lua` | modify | drop the window/buffer tracking and `WinClosed`; new `render_dashboard(win)` used by `create_dashboard` and by `update_ascii_art`, which redraws every window showing a dashboard buffer |
| `.claude/skills/verify-nvim-config/features/dashboard.md` | modify (rewrite) | new end states, the nvim-tree and non-hijack recipes, the base finding moved to history, new gotchas |
| `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-3.md` | create (after all runs are down) | `## Phase 3` with evidence paths; own commit (execution rule 4) |

## Why the BufLeave cleanup stays safe

`BufLeave` (`:421-438`) schedules `bwipeout! args.buf`, and `args.buf` is always the buffer being
**left**, i.e. the old dashboard buffer. `render_dashboard` creates the new buffer first and then
`nvim_win_set_buf(win, new)`, so the wipe can only ever target the old one:

- Current window (start screen): `BufLeave(old)` fires; the scheduled check sees filetype
  `dashboard` (the new buffer), calls `bwipeout!` on `old`, which `bufhidden=wipe` already wiped,
  so `nvim_buf_is_valid` is false and nothing happens.
- Non-current window (dashboard behind nvim-tree): `nvim_win_set_buf` switches to that window
  internally and `BufLeave(old)` fires there; the scheduled check runs back in the nvim-tree
  window (filetype `NvimTree`) and does nothing. `old` is wiped by `bufhidden=wipe` since no
  window shows it.
- Two windows on the same dashboard buffer (`:vsplit` on the start screen): the loop in
  `update_ascii_art` is synchronous and every scheduled wipe runs after it, so both windows hold
  their own new buffer before anything is wiped. Checked headless: both windows end on distinct
  new dashboard buffers and both survive.

None of these touch the new buffer, so its buffer-local keymaps survive. `render_dashboard` does
window options and the `normal! $` nudge inside `nvim_win_call(win, ...)`, so no window is entered
for real and no extra `BufLeave` fires from the redraw.

## Implementation Steps

Steps 1-4 all edit one file. The complete final file is in **Step 5**: write it verbatim; steps 1-4
explain each piece and where it lands in today's file. Indent is 2 spaces; the final file passes
`stylua --check` with the repo's `.stylua.toml` (checked by the planner).

### Step 1: Drop the window/buffer tracking
**File:** `lua/config/dashboard-nvim.lua:10-12`
**Change:** delete `ascii_art_win` and `ascii_art_buf` and their comment; replace with a comment
saying which windows count as dashboards.
**Code:**
```lua
-- Every window whose buffer has filetype "dashboard" shows the art; there is no other record of
-- which windows those are, so a window the user moved to another buffer is never redrawn.
```
**Impact:** every reader of the two locals is replaced in steps 2-4; nothing outside the file
reads them (grep of `lua/ plugin/ after/ viml_conf/ init.lua`).

### Step 2: One renderer for a given window
**File:** `lua/config/dashboard-nvim.lua`, inserted after `load_saved_art` (ends `:144`), before
`update_ascii_art` (`:146`).
**Change:** new local `render_dashboard(win)`: loads `fname`'s art, centres it for **`win`**'s
height and width, fills a fresh dashboard buffer, sets the buffer-local keymaps on that buffer,
shows it in `win`, sets window options in `win` via `nvim_win_call`, and schedules the existing
`normal! $` nudge in `win` (guarded: only if `win` still shows that buffer). 
**Code:**
```lua
---
-- Draws the current art (fname) into a window: a fresh dashboard buffer, centred for that
-- window's size, with the dashboard's buffer-local keymaps and window options. The buffer the
-- window showed before is hidden, and Neovim wipes it once no window shows it (bufhidden=wipe).
-- @param win The window to draw into.
local function render_dashboard(win)
  local header_file_path = vim.fn.stdpath("config") .. "/ascii_art/" .. fname .. ".txt"
  local lines = load_ascii_art(header_file_path)

  -- Find the longest line for horizontal centering
  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end

  -- Centre in this window, vertically and horizontally
  local top_padding = math.max(0, math.floor((api.nvim_win_get_height(win) - #lines) / 2))
  local left_padding = math.max(0, math.floor((api.nvim_win_get_width(win) - max_width) / 2))
  local padding_str = string.rep(" ", left_padding)

  local padded_lines = {}
  for _ = 1, top_padding do
    table.insert(padded_lines, "")
  end
  for _, line in ipairs(lines) do
    table.insert(padded_lines, padding_str .. line)
  end

  local buf = api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "dashboard"

  -- Set buffer content
  api.nvim_buf_set_lines(buf, 0, -1, false, padded_lines)
  vim.bo[buf].modifiable = false

  -- Set keymaps
  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set("n", "q", ":qa<CR>", opts)
  vim.keymap.set("n", "e", ":enew<CR>", opts)
  vim.keymap.set("n", "<space>s", require("nvim-tree.api").tree.toggle, opts)

  api.nvim_win_set_buf(win, buf)

  -- Set window options, in that window, without moving the cursor out of the current one
  api.nvim_win_call(win, function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.cursorline = false
    vim.opt_local.cursorcolumn = false
    vim.opt_local.colorcolumn = ""
    vim.opt_local.list = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.foldcolumn = "0"
    vim.opt_local.statuscolumn = ""
  end)

  -- Move cursor to end of line to show full ASCII art
  vim.schedule(function()
    vim.schedule(function()
      if api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == buf then
        api.nvim_win_call(win, function()
          vim.cmd("normal! $")
        end)
      end
    end)
  end)
end
```
**Impact:** padding is now always computed for the window that displays the art.

### Step 3: `update_ascii_art` redraws every dashboard window
**File:** `lua/config/dashboard-nvim.lua:146-246` (replace the whole function)
**Code:**
```lua
---
-- Switches to another ASCII art, saves the choice, and redraws every window showing the dashboard.
-- @param art_name The name of the ASCII art to switch to.
local function update_ascii_art(art_name)
  fname = art_name
  save_current_art(art_name)

  for _, win in ipairs(api.nvim_list_wins()) do
    if vim.bo[api.nvim_win_get_buf(win)].filetype == "dashboard" then
      render_dashboard(win)
    end
  end
end
```
**Impact:** `nvim_list_wins()` is every window in every tab, floating ones included. The cursor
stays in the window where the key was pressed (it used to jump to the split).

### Step 4: `create_dashboard` uses the renderer; `WinClosed` goes
**File:** `lua/config/dashboard-nvim.lua:307-403` (replace the whole function) and `:440-450`
(delete the `WinClosed` autocmd block and its preceding comment line).
**Code:**
```lua
---
-- Creates and displays the dashboard buffer in the current window or a right split
-- @param split_mode Optional: "right" to open in vertical split on right
local function create_dashboard(split_mode)
  -- Initialize fname from cache if not set
  if not fname then
    fname = load_saved_art()
  end

  if split_mode == "right" then
    -- Create vertical split on right side; it becomes the current window
    vim.cmd("rightbelow vsplit")
  end

  render_dashboard(api.nvim_get_current_win())
end
```
**Impact:** the split still takes focus (from `vsplit`, as before). `WinClosed` only cleared the
deleted locals.

### Step 5: Write the final file
**File:** `lua/config/dashboard-nvim.lua` (whole file, 375 lines)
**Change:** the result of steps 1-4. Everything not named above (the header, the commented-out
`fname` list, `load_ascii_art` and its fallback art, `get_ascii_art_files`, `save_current_art`,
`load_saved_art`, `select_ascii_art`, `cycle_next_ascii_art`, `select_bikini`, `VimEnter`,
`BufLeave`, the `_G` functions and keymaps) is byte-for-byte today's text.
**Code:**
```lua
-- /home/miftah/.config/nvim/lua/config/dashboard-nvim.lua
-- Custom minimal dashboard - shows only ASCII art on startup

local api = vim.api

-- ============================================================================
-- STATE TRACKING
-- ============================================================================

-- Every window whose buffer has filetype "dashboard" shows the art; there is no other record of
-- which windows those are, so a window the user moved to another buffer is never redrawn.

-- Path to cache file for storing the selected ASCII art
local cache_file = vim.fn.stdpath("cache") .. "/dashboard_ascii_art.txt"

-- Current ASCII art filename (without extension)
local fname = nil

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Define the ASCII art file to display (commented out - now using cache)
-- local fname = "donkey_head"
-- local fname = "death_eater"
-- local fname = "dragon_1"
-- local fname = "shaggy"
-- local fname = "bikini"
-- local fname = "cat_1"
-- local fname = "eagly"
-- local fname = "whatsapp"
-- local fname = "pacman"
-- local fname = "aot"
-- local fname = "lego"
-- local fname = "crescent_moon"
-- local fname = "unicorn"
-- local fname = "play"
-- local fname = "git"
-- local fname = "muppet"
-- local fname = "pin"
-- local fname = "troll"
-- local fname = "luffy"
-- local fname = "assassins_creed"
-- local fname = "beafis"
-- local fname = "goose"
-- local fname = "riding_bike"
-- local fname = "waist"
-- local fname = "max"
-- local fname = "bison"
-- local fname = "bomb"
-- local fname = "nike"
-- local fname = "cougar"
-- local fname = "cat_2"
-- local fname = "disapproving"
-- local fname = "neil_patrick"
-- local fname = "patrick"
-- local fname = "sasuke"
-- local fname = "monopoly"
-- local fname = "family_guy_1"
-- local fname = "south_park_1"
-- local fname = "family_guy_2"
-- local fname = "skull"
-- local fname = "eyes" -- Now loaded from cache

-- header_file_path will be set after loading from cache

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

---
-- Reads an ASCII art file and returns its content as a table of strings.
-- @param file_path The absolute path to the text file.
-- @return A table of strings for the header.
local function load_ascii_art(file_path)
  local lines = {}
  local success, file = pcall(io.open, file_path, "r")

  if not success or not file then
    -- Return a default fallback header
    return {
      "                                                       ",
      " ███╗   ██╗ ███████╗ ██████╗  ██╗   ██╗ ██╗ ███╗   ███╗",
      " ████╗  ██║ ██╔════╝██╔═══██╗ ██║   ██║ ██║ ████╗ ████║",
      " ██╔██╗ ██║ █████╗  ██║   ██║ ██║   ██║ ██║ ██╔████╔██║",
      " ██║╚██╗██║ ██╔══╝  ██║   ██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║",
      " ██║ ╚████║ ███████╗╚██████╔╝  ╚████╔╝  ██║ ██║ ╚═╝ ██║",
      " ╚═╝  ╚═══╝ ╚══════╝ ╚═════╝    ╚═══╝   ╚═╝ ╚═╝     ╚═╝",
      "                                                       ",
    }
  end

  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()

  return lines
end

---
-- Gets all ASCII art files from the ascii_art directory.
-- @return A sorted table of filenames (without extension).
local function get_ascii_art_files()
  local ascii_dir = vim.fn.stdpath("config") .. "/ascii_art"
  local files = vim.fn.glob(ascii_dir .. "/*.txt", false, true)

  -- Extract just the filenames without extension
  local art_names = {}
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    table.insert(art_names, name)
  end

  -- Sort alphabetically
  table.sort(art_names)

  return art_names
end

---
-- Saves the current ASCII art selection to cache file.
-- @param art_name The name of the ASCII art (without extension).
local function save_current_art(art_name)
  local file = io.open(cache_file, "w")
  if file then
    file:write(art_name)
    file:close()
  end
end

---
-- Loads the saved ASCII art selection from cache file.
-- @return The saved art name, or "eyes" as default fallback.
local function load_saved_art()
  local file = io.open(cache_file, "r")
  if file then
    local content = file:read("*all")
    file:close()
    return vim.trim(content)
  end
  return "eyes" -- Default fallback
end

---
-- Draws the current art (fname) into a window: a fresh dashboard buffer, centred for that
-- window's size, with the dashboard's buffer-local keymaps and window options. The buffer the
-- window showed before is hidden, and Neovim wipes it once no window shows it (bufhidden=wipe).
-- @param win The window to draw into.
local function render_dashboard(win)
  local header_file_path = vim.fn.stdpath("config") .. "/ascii_art/" .. fname .. ".txt"
  local lines = load_ascii_art(header_file_path)

  -- Find the longest line for horizontal centering
  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end

  -- Centre in this window, vertically and horizontally
  local top_padding = math.max(0, math.floor((api.nvim_win_get_height(win) - #lines) / 2))
  local left_padding = math.max(0, math.floor((api.nvim_win_get_width(win) - max_width) / 2))
  local padding_str = string.rep(" ", left_padding)

  local padded_lines = {}
  for _ = 1, top_padding do
    table.insert(padded_lines, "")
  end
  for _, line in ipairs(lines) do
    table.insert(padded_lines, padding_str .. line)
  end

  local buf = api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "dashboard"

  -- Set buffer content
  api.nvim_buf_set_lines(buf, 0, -1, false, padded_lines)
  vim.bo[buf].modifiable = false

  -- Set keymaps
  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set("n", "q", ":qa<CR>", opts)
  vim.keymap.set("n", "e", ":enew<CR>", opts)
  vim.keymap.set("n", "<space>s", require("nvim-tree.api").tree.toggle, opts)

  api.nvim_win_set_buf(win, buf)

  -- Set window options, in that window, without moving the cursor out of the current one
  api.nvim_win_call(win, function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.cursorline = false
    vim.opt_local.cursorcolumn = false
    vim.opt_local.colorcolumn = ""
    vim.opt_local.list = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.foldcolumn = "0"
    vim.opt_local.statuscolumn = ""
  end)

  -- Move cursor to end of line to show full ASCII art
  vim.schedule(function()
    vim.schedule(function()
      if api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == buf then
        api.nvim_win_call(win, function()
          vim.cmd("normal! $")
        end)
      end
    end)
  end)
end

---
-- Switches to another ASCII art, saves the choice, and redraws every window showing the dashboard.
-- @param art_name The name of the ASCII art to switch to.
local function update_ascii_art(art_name)
  fname = art_name
  save_current_art(art_name)

  for _, win in ipairs(api.nvim_list_wins()) do
    if vim.bo[api.nvim_win_get_buf(win)].filetype == "dashboard" then
      render_dashboard(win)
    end
  end
end

---
-- Shows a selection menu to choose ASCII art.
local function select_ascii_art()
  local art_files = get_ascii_art_files()

  if #art_files == 0 then
    vim.notify("No ASCII art files found in ascii_art directory", vim.log.levels.WARN)
    return
  end

  vim.ui.select(art_files, {
    prompt = "Select ASCII Art:",
    format_item = function(item)
      if item == fname then
        return item .. " (current)"
      end
      return item
    end,
  }, function(choice)
    if choice then
      update_ascii_art(choice)
    end
  end)
end

---
-- Cycles to the next ASCII art in alphabetical order.
local function cycle_next_ascii_art()
  local art_files = get_ascii_art_files()

  if #art_files == 0 then
    vim.notify("No ASCII art files found in ascii_art directory", vim.log.levels.WARN)
    return
  end

  -- Find current index
  local current_idx = 1
  for i, name in ipairs(art_files) do
    if name == fname then
      current_idx = i
      break
    end
  end

  -- Get next index (wrap around)
  local next_idx = (current_idx % #art_files) + 1
  local next_art = art_files[next_idx]

  update_ascii_art(next_art)
  vim.notify("Switched to: " .. next_art, vim.log.levels.INFO)
end

---
-- Quickly selects the 'bikini' ASCII art.
local function select_bikini()
  update_ascii_art("bikini")
  vim.notify("Switched to: bikini", vim.log.levels.INFO)
end

---
-- Creates and displays the dashboard buffer in the current window or a right split
-- @param split_mode Optional: "right" to open in vertical split on right
local function create_dashboard(split_mode)
  -- Initialize fname from cache if not set
  if not fname then
    fname = load_saved_art()
  end

  if split_mode == "right" then
    -- Create vertical split on right side; it becomes the current window
    vim.cmd("rightbelow vsplit")
  end

  render_dashboard(api.nvim_get_current_win())
end

-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================

-- Show dashboard on startup if no files are opened
api.nvim_create_autocmd("VimEnter", {
  group = api.nvim_create_augroup("CustomDashboard", { clear = true }),
  callback = function()
    -- Only show dashboard if we started with no files
    if vim.fn.argc() == 0 and vim.fn.line2byte("$") == -1 then
      create_dashboard()
    end
  end,
})

-- Clean up when leaving dashboard for a real file
api.nvim_create_autocmd("BufLeave", {
  group = api.nvim_create_augroup("CustomDashboardCleanup", { clear = true }),
  pattern = "*",
  callback = function(args)
    if vim.bo[args.buf].filetype == "dashboard" then
      -- Only wipe dashboard when opening a real file, not special buffers like nvim-tree
      vim.schedule(function()
        local current_ft = vim.bo.filetype
        -- Don't wipe if we're going to a special buffer
        if current_ft ~= "NvimTree" and current_ft ~= "qf" and current_ft ~= "vista" then
          if api.nvim_buf_is_valid(args.buf) then
            vim.cmd("bwipeout! " .. args.buf)
          end
        end
      end)
    end
  end,
})

-- ============================================================================
-- GLOBAL FUNCTIONS & KEYMAPS
-- ============================================================================

-- Create global functions
_G.show_ascii_art_split = function()
  create_dashboard("right")
end

_G.select_ascii_art = select_ascii_art
_G.cycle_next_ascii_art = cycle_next_ascii_art
_G.select_bikini_ascii_art = select_bikini

-- Set keymaps
vim.keymap.set("n", "<leader>b", _G.show_ascii_art_split, {
  silent = true,
  desc = "Show ASCII art in right split",
})

vim.keymap.set("n", "<leader>bv", _G.select_ascii_art, {
  silent = true,
  desc = "Select ASCII art from menu",
})

vim.keymap.set("n", "<leader>bg", _G.cycle_next_ascii_art, {
  silent = true,
  desc = "Cycle to next ASCII art",
})

vim.keymap.set("n", "<leader>bh", _G.select_bikini_ascii_art, {
  silent = true,
  desc = "Select bikini ASCII art",
})
```
**Impact:** see Interface Contract, "Behaviour changes a user can see".

### Step 6: Feature map
**File:** `.claude/skills/verify-nvim-config/features/dashboard.md` (whole file, replaces `:1-48`)
**Change:** new end states (start screen redraws; `,bh` and `,bv` recipes; nvim-tree-focused
redraw; `e` then `,bg` leaves the buffer alone, on the start screen and in the split), the base
finding moved to a history line, and two gotchas the planner confirmed headless on both base and
fix (moving to a normal window wipes the split via `BufLeave`; `,b` on the start screen ends with
one window). Do not edit `features/README.md` (phase 9 owns its "Known on the base" column).
**Code:**
~~~~markdown
# Dashboard / ASCII art

## Sub-features

- Start screen (`config/dashboard-nvim.lua`): with no file argument, one of `ascii_art/*.txt`,
  centred. The name lives in `stdpath("cache")/dashboard_ascii_art.txt` (default `eyes`).
- `,b` opens the art in a right split; `,bg` cycles to the next art; `,bv` picks one with
  `vim.ui.select` (snacks picker); `,bh` jumps to `bikini`. Buffer-local `q` quits, `e` new buffer,
  `<space>s` toggles nvim-tree.
- A change of art redraws **every window that shows a dashboard buffer** (start screen, split,
  a dashboard behind an nvim-tree window), in every tab, and leaves the cursor where it was. A
  window the user moved to another buffer is never touched.

## How to get to it (user POV)

Start `nvim` with no file. Press `,b` from any buffer for the split; `,bg` / `,bv` / `,bh` to
change art.

## Driving it with verify.sh

The probe names the art each visible dashboard window shows (by content) and the saved name.
`S` is the `saved=` the probe printed just before a block (right after `up`: seeded `(none)`, which
means `eyes`; live: the owner's cache), `S+1` the next name alphabetically. Each block below starts
from a fresh `up`.

Start screen (seeded names; on `--live` read them as `S`, `S+1`):

```sh
P=.claude/skills/verify-nvim-config/features/lua/dashboard_art.lua
$V up
$V lua RUN @$P                      # shown=eyes saved=(none)
$V keys RUN , b g                   # notification "Switched to: family_guy_1"
$V lua RUN @$P                      # shown=family_guy_1 saved=family_guy_1
$V keys RUN , b h
$V lua RUN @$P                      # shown=bikini saved=bikini
$V keys RUN , b v; $V keys RUN -l skull; $V keys RUN Enter
$V lua RUN @$P                      # shown=skull saved=skull
$V lua RUN 'vim.bo.filetype'        # dashboard (the cursor stayed on the start screen)
```

Dashboard behind another window (nvim-tree focused):

```sh
$V up
$V lua RUN @$P                      # shown=S saved=S
$V keys RUN Space s                 # buffer-local <space>s: nvim-tree opens and takes focus
$V keys RUN , b g
$V lua RUN @$P                      # shown=S+1 saved=S+1
$V lua RUN 'vim.bo.filetype'        # NvimTree (focus not moved)
```

Leaving the dashboard, then the split:

```sh
W='vim.bo.filetype .. "|" .. vim.bo.buftype .. "|" .. vim.api.nvim_buf_line_count(0) .. "|" .. #vim.api.nvim_tabpage_list_wins(0)'
$V up
$V lua RUN @$P                      # shown=S saved=S
$V keys RUN e                       # leave the start screen (buffer-local e = :enew)
$V keys RUN , b g
$V lua RUN @$P                      # shown=(no dashboard window) saved=S+1
$V lua RUN "$W"                     # ||1|1   the empty buffer stays empty
$V keys RUN , b                     # art in a right split
$V keys RUN , b g
$V lua RUN @$P                      # shown=S+2 saved=S+2
$V keys RUN e                       # the split leaves the dashboard
$V keys RUN , b g
$V lua RUN @$P                      # shown=(no dashboard window) saved=S+3
$V lua RUN "$W"                     # ||1|2   the split was not taken back
```

Picker with a fresh art: see img2braille.md (`saved=verify_art`).

## Gotchas

- Consumes: the cache file. Each `,bg` moves to the next name alphabetically from the current one,
  so expected names depend on the order you drove things in. Read `saved=` first.
- Moving the cursor from a dashboard window to a normal window wipes that dashboard (the
  `BufLeave` cleanup), which closes the split. Only nvim-tree, quickfix and vista keep it. So a
  "split behind the editing window" does not survive `C-w h`; drive `,bg` from inside the split,
  or from nvim-tree.
- `,b` on the start screen itself ends with one window: the new split's `BufLeave` wipes the start
  screen's buffer and its window closes. Press `e` first, as above.
- Braille blank cells (U+2800) are not whitespace, so compare whole art files (the probe does).
  First lines alone collide.
- Before phase 3 of fix-bugs-nvim-0-12 the start screen kept the old art until restart
  (`shown=S saved=S+1`), and `,bg` after `e` in the split put the art back into that window.
~~~~

### Step 7: Evidence and commit
- After the last `down`, write `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-3.md` (this phase's
  own file; phase 9 builds the set's `evidence.md` index from it):
  ```markdown
  ## Phase 3
  - base, seeded: <EVIDENCE dir of run A-base-seeded>, <run B-base-seeded>, <run C-base-seeded>
  - base, live:   <EVIDENCE dir of run A-base-live>, ...
  - fix, seeded:  <EVIDENCE dirs>
  - fix, live:    <EVIDENCE dirs>
  - verdicts: J1..J6 one line each, with the probe output that decided it
  ```
- Commit the two source files with a pathspec:
  `git commit -m "fix(dashboard): redraw the start screen when the art changes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lua/config/dashboard-nvim.lua .claude/skills/verify-nvim-config/features/dashboard.md`,
  then the evidence file on its own:
  `git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-3.md && git commit -m "docs(evidence): phase 3 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-3.md`.
  `.workflows/` is tracked (the orchestrator commits the plan set). Do not push.

## Principles applied

- Fix root causes: the reproduction and the cause are traced to `:382-385` and `:155`, and the
  fix removes the cause (a remembered window) instead of also setting `ascii_art_win` in the
  no-split branch, which would have left the "hijack a window that left the dashboard" bug.
- Subtract before you add: `ascii_art_win`, `ascii_art_buf`, the `WinClosed` autocmd and the
  manual `nvim_buf_delete` of the old buffer go; `bufhidden=wipe` already wipes it. The two
  copies of the padding/buffer/keymap/window-option code become one `render_dashboard`.
- Make illegal states unrepresentable: "which windows show the dashboard" is derived from each
  window's buffer filetype at redraw time, so a tracked window that no longer shows a dashboard
  cannot exist.
- Prove it works: every claim has a `verify.sh` journey on the base (fails) and the fix, seeded and
  live, including the two no-hijack checks.

## Verification

**Build:** `~/.local/share/nvim/mason/bin/stylua --check lua/config/dashboard-nvim.lua && luac -p lua/config/dashboard-nvim.lua`
**Tests:** none in this repo; the harness is the test. `$V up` must print no startup errors and
`$V doctor RUN` must exit 0 (Invariant 1).
**Proof:**
- Harness: `.claude/skills/verify-nvim-config` (`scripts/verify.sh`), on the installed nvim 0.11.5
  (do not set `VERIFY_NVIM`).
- Feature-map entries: `.claude/skills/verify-nvim-config/features/dashboard.md`
- Setup, from the worktree root, in zsh:
  ```sh
  cd "$WT"   # this phase's own worktree root (index § Execution rules)
  V=.claude/skills/verify-nvim-config/scripts/verify.sh
  P=.claude/skills/verify-nvim-config/features/lua/dashboard_art.lua
  W='vim.bo.filetype .. "|" .. vim.bo.buftype .. "|" .. vim.api.nvim_buf_line_count(0) .. "|" .. #vim.api.nvim_tabpage_list_wins(0)'
  ```
  Order: run A, B, C on the **base** (before editing, or with the base file swapped in:
  `SW=$(mktemp -d); cp lua/config/dashboard-nvim.lua "$SW/"; git show "$PHASE_BASE:lua/config/dashboard-nvim.lua" >lua/config/dashboard-nvim.lua`;
  never `git stash`, execution rule 2), first with `$V up --live`, then with `$V up`; then put the
  change back (`cp "$SW/dashboard-nvim.lua" lua/config/dashboard-nvim.lua`) and run A, B, C again,
  `--live` then seeded. Each run is a fresh `up` (so the cache starts at a known `S`) and ends
  with `$V down RUN`. Run `$V doctor RUN` after every `up`. `S` is the `saved=` the first probe
  of a run prints (`(none)` = `eyes` when seeded; the owner's cache, e.g. `assassins_creed`, on
  `--live`). `S+1` is the next name in `ls ascii_art` order. Record each run's `EVIDENCE=`.
  If a key does not do what the step says, take `$V screen RUN` and mark the journey
  `inconclusive` with the reason; never weaken it.

- **Run A, start screen (J1 `,bg`, J2 `,bh`, J3 `,bv`)**
  ```sh
  $V up            # or: $V up --live
  $V doctor RUN
  $V lua RUN @$P                                   # shown=S saved=S   (seeded: shown=eyes saved=(none))
  $V keys RUN , b g
  $V lua RUN @$P                                   # J1
  $V keys RUN , b h
  $V lua RUN @$P                                   # J2
  $V keys RUN , b v; $V keys RUN -l skull; $V keys RUN Enter
  $V lua RUN @$P                                   # J3
  $V lua RUN 'vim.bo.filetype'                     # still on the start screen
  $V down RUN
  ```
  - J1 base: `shown=S saved=S+1` (bug). Fix: `shown=S+1 saved=S+1`.
  - J2 base: `shown=S saved=bikini`. Fix: `shown=bikini saved=bikini`.
  - J3 base: `shown=S saved=skull`. Fix: `shown=skull saved=skull`.
  - Fix: last probe prints `dashboard`.
- **Run B, dashboard behind a focused nvim-tree (J4)**
  ```sh
  $V up
  $V lua RUN @$P                                   # shown=S saved=S
  $V keys RUN Space s                              # buffer-local <space>s: nvim-tree opens and is focused
  $V lua RUN 'vim.bo.filetype'                     # NvimTree
  $V keys RUN , b g
  $V lua RUN @$P                                   # J4
  $V lua RUN 'vim.bo.filetype'                     # focus did not move
  $V down RUN
  ```
  - J4 base: `shown=S saved=S+1`. Fix: `shown=S+1 saved=S+1`, and the last probe prints `NvimTree`.
  - If the probe after `Space s` already shows `(no dashboard window)`, nvim-tree replaced the
    start screen: J4 is `inconclusive` (record the screen), not a failure of this phase.
- **Run C, no hijack + split (J5 start screen `e`, J6 split, J7 split `e`)**
  ```sh
  $V up
  $V lua RUN @$P                                   # shown=S saved=S
  $V keys RUN e                                    # start screen -> empty buffer
  $V keys RUN , b g
  $V lua RUN @$P                                   # J5a
  $V lua RUN "$W"                                  # J5b
  $V keys RUN , b                                  # art in a right split, focus in it
  $V keys RUN , b g
  $V lua RUN @$P                                   # J6
  $V keys RUN e                                    # the split leaves the dashboard
  $V keys RUN , b g
  $V lua RUN @$P                                   # J7a
  $V lua RUN "$W"                                  # J7b
  $V down RUN
  ```
  - J5 base and fix: `shown=(no dashboard window) saved=S+1`, then `||1|1` (an empty normal
    buffer, one window). This one passes on the base too; it guards the "e then ,bg" edge.
  - J6 base and fix: `shown=S+2 saved=S+2` (the split redrew on the base already; neighbour check).
  - J7 base: `shown=S+3 saved=S+3` and `dashboard|nofile|<n>|2` (the split was taken back: second
    bug). Fix: `shown=(no dashboard window) saved=S+3`, then `||1|2`.
- Neighbor check: startup. Every `up` prints no startup errors, `00-up-screen.txt` shows the art,
  and `$V doctor RUN` exits 0 with no `messages` FAIL; J6 covers the split, J5 covers buffer-local
  `e`. Also grep each run's `messages-at-down.txt` (written by `down`) for `E5108`/`Error`: none.
- Cost: none (no paid drives). About 12 `up` runs at 1-7 s each.

**Exit criteria:** on both `--live` and seeded, after the fix: J1-J4 show `shown` equal to
`saved` for the new art; J5 and J7 show `(no dashboard window)` with the user's empty buffer
intact; J6 redraws the split; on the base, J1-J4 show `shown=S` (old art) and J7 shows the
hijack. `stylua --check` passes. Evidence paths are in `evidence-phase-3.md` under `## Phase 3`, committed. The
commit `fix(dashboard): redraw the start screen when the art changes` exists and is not pushed.

## Handoffs

- No owner, follow-up only: `cycle_next_ascii_art` uses `fname`, which is nil until a dashboard
  was drawn. After `nvim somefile`, the first `,bg` goes to the second art alphabetically, not to
  the one after the saved art. Fix would be `fname = fname or load_saved_art()` at the top of
  `cycle_next_ascii_art`. Left out: not R6 (the start screen and split already load `fname`).
- No owner, follow-up only: the `BufLeave` cleanup wipes a dashboard split as soon as the cursor
  moves to a normal window, and `,b` on the start screen closes the start screen window. Both are
  base behaviour, documented as gotchas in `features/dashboard.md`; changing them is a separate
  product decision.
- Phase 9: `features/README.md`'s "Known on the base" cell for the dashboard should drop the
  start-screen-redraw finding once this phase lands.
- Phase 9: nothing else to migrate in this file for 0.12 (no `nvim_buf_set_option` left).

## Rollback

`git revert <phase-3 commit>`. It restores `lua/config/dashboard-nvim.lua` and
`features/dashboard.md`; no other file, cache format or state depends on this phase.
