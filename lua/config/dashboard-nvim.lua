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
