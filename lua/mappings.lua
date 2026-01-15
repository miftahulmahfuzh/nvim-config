-- /home/devmiftahul/.config/nvim/lua/mappings.lua

local keymap = vim.keymap

-- Save key strokes (now we do not need to press shift to enter command mode).
keymap.set({ "n", "x" }, ";", ":")

-- Turn the word under cursor to upper case
keymap.set("i", "<c-u>", "<Esc>viwUea")

-- Turn the current word into title case
keymap.set("i", "<c-t>", "<Esc>b~lea")

-- Paste non-linewise text above or below current line, see https://stackoverflow.com/a/1346777/6064933
keymap.set("n", "<leader>p", "m`o<ESC>p``", { desc = "paste below current line" })
keymap.set("n", "<leader>P", "m`O<ESC>p``", { desc = "paste above current line" })

-- Shortcut for faster save and quit
keymap.set("n", "<leader>w", "<cmd>update<cr>", { silent = true, desc = "save buffer" })

-- Saves the file if modified and quit
keymap.set("n", "<leader>q", "<cmd>x<cr>", { silent = true, desc = "quit current window" })

-- Quit all opened buffers
keymap.set("n", "<leader>Q", "<cmd>qa!<cr>", { silent = true, desc = "quit nvim" })

-- Close location list or quickfix list if they are present, see https://superuser.com/q/355325/736190
keymap.set("n", [[\x]], "<cmd>windo lclose <bar> cclose <cr>", {
  silent = true,
  desc = "close qf and location list",
})

-- Delete a buffer, without closing the window, see https://stackoverflow.com/q/4465095/6064933
keymap.set("n", [[\d]], "<cmd>bprevious <bar> bdelete #<cr>", {
  silent = true,
  desc = "delete current buffer",
})

keymap.set("n", [[\D]], function()
  local buf_ids = vim.api.nvim_list_bufs()
  local cur_buf = vim.api.nvim_win_get_buf(0)

  for _, buf_id in pairs(buf_ids) do
    -- do not Delete unlisted buffers, which may lead to unexpected errors
    if vim.api.nvim_get_option_value("buflisted", { buf = buf_id }) and buf_id ~= cur_buf then
      vim.api.nvim_buf_delete(buf_id, { force = true })
    end
  end
end, {
  desc = "delete other buffers",
})

-- Insert a blank line below or above current line (do not move the cursor),
-- see https://stackoverflow.com/a/16136133/6064933
keymap.set("n", "<space>o", "printf('m`%so<ESC>``', v:count1)", {
  expr = true,
  desc = "insert line below",
})

keymap.set("n", "<space>O", "printf('m`%sO<ESC>``', v:count1)", {
  expr = true,
  desc = "insert line above",
})

-- Move the cursor based on physical lines, not the actual lines.
keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })
keymap.set("n", "^", "g^")
keymap.set("n", "0", "g0")

-- Do not include white space characters when using $ in visual mode,
-- see https://vi.stackexchange.com/q/12607/15292
keymap.set("x", "$", "g_")

-- Go to start or end of line easier
keymap.set({ "n", "x" }, "H", "^")
keymap.set({ "n", "x" }, "L", "g_")

-- Continuous visual shifting (does not exit Visual mode), `gv` means
-- to reselect previous visual area, see https://superuser.com/q/310417/736190
keymap.set("x", "<", "<gv")
keymap.set("x", ">", ">gv")

-- Edit and reload nvim config file quickly
keymap.set("n", "<leader>ev", "<cmd>tabnew $MYVIMRC <bar> tcd %:h<cr>", {
  silent = true,
  desc = "open init.lua",
})

keymap.set("n", "<leader>sv", function()
  vim.cmd([[
      update $MYVIMRC
      source $MYVIMRC
    ]])
  vim.notify("Nvim config successfully reloaded!", vim.log.levels.INFO, { title = "nvim-config" })
end, {
  silent = true,
  desc = "reload init.lua",
})

-- Reselect the text that has just been pasted, see also https://stackoverflow.com/a/4317090/6064933.
keymap.set("n", "<leader>v", "printf('`[%s`]', getregtype()[0])", {
  expr = true,
  desc = "reselect last pasted area",
})

-- Always use very magic mode for searching
-- keymap.set("n", "/", [[/\v]])

-- Search in selected region
-- xnoremap / :<C-U>call feedkeys('/\%>'.(line("'<")-1).'l\%<'.(line("'>")+1)."l")<CR>

-- Colorscheme picker
vim.keymap.set("n", "<leader>cc", function()
  require("colorscheme_picker").open()
end, { desc = "Choose a colorscheme" })

-- Changes CWD to the file's directory,
-- but copies the FULL file path (including filename) to the clipboard.
keymap.set("n", "<leader>cd", function()
  -- Get the full path of the current file (e.g., /path/to/file.go)
  local full_path = vim.fn.expand("%:p")

  -- Get just the directory part for the lcd command (e.g., /path/to)
  local file_dir = vim.fn.expand("%:p:h")

  -- Handle case where buffer is not saved and has no path
  if full_path == "" then
    vim.notify("Buffer has no file path", vim.log.levels.INFO, { title = "CWD & Copy" })
    return
  end

  -- 1. Change the 'local' (window-specific) working directory
  vim.cmd("lcd " .. vim.fn.fnameescape(file_dir))

  -- 2. Set the system clipboard register '+' to the FULL path
  vim.fn.setreg("+", full_path)

  -- 3. Display a confirmation message showing what was copied
  local message = string.format("Path copied: %s", full_path)
  vim.notify(message, vim.log.levels.INFO, { title = "Path Copied & CWD Set" })
end, { desc = "Change CWD to dir & copy full file path" })

-- Git shortcuts (requires a plugin like vim-fugitive)
keymap.set("n", "<leader>gt", "<cmd>Git status<cr>", { silent = true, desc = "Git status" })
keymap.set("n", "<leader>ga", "<cmd>Git add .<cr>", { silent = true, desc = "Git add all" })
keymap.set("n", "<leader>gc", "<cmd>Git commit<cr>", { silent = true, desc = "Git commit" })
keymap.set("n", "<leader>gp", "<cmd>Git push<cr>", { silent = true, desc = "Git push" })
vim.keymap.set("n", "<leader>gf", ":Flog -all<CR>", { desc = "Git: Flog all" })

keymap.set("n", "<leader>gd", function()
  require("gitsigns").diffthis()
end, { desc = "Git Diff" })

-- Quit diff mode and close extra window
keymap.set("n", "<leader>ds", "<cmd>diffoff! | only<cr>", {
  silent = true,
  desc = "quit diff and close window",
})

-- Git tag utilities (add after your existing git mappings)
local git_tags = require("custom.git_tags")

-- Show tag interactively
keymap.set("n", "<leader>gts", git_tags.select_and_show_tag, { desc = "Git: Select and show tag" })

-- List all tags with details
keymap.set("n", "<leader>gtl", git_tags.list_tags_detailed, { desc = "Git: List tags with details" })

-- Compare two tags
keymap.set("n", "<leader>gtc", git_tags.compare_tags, { desc = "Git: Compare tags" })

-- Quick show tag (prompts for input)
keymap.set("n", "<leader>gts", function()
  local tag = vim.fn.input("Show tag: ")
  if tag ~= "" then
    git_tags.show_tag(tag)
  end
end, { desc = "Git: Show specific tag" })

-- Show tag under cursor
keymap.set("n", "<leader>gtS", function()
  local word = vim.fn.expand("<cword>")
  git_tags.show_tag(word)
end, { desc = "Git: Show tag under cursor" })

-- Simple search and replace for visually selected text
keymap.set("x", "<leader>r", function()
  -- Get the selected text using a simpler method
  vim.cmd('normal! "zy')
  local selected_text = vim.fn.getreg("z")

  -- Clean up the text (remove newlines, trim whitespace)
  selected_text = selected_text:gsub("\n", ""):gsub("^%s+", ""):gsub("%s+$", "")

  if selected_text and selected_text ~= "" then
    -- Escape special characters for search
    local escaped_text = vim.fn.escape(selected_text, [[/\]])

    -- Prompt for replacement
    local replacement = vim.fn.input("Replace '" .. selected_text .. "' with: ")

    if replacement and replacement ~= "" then
      -- Perform the replacement across the entire file
      vim.cmd(":%s/" .. escaped_text .. "/" .. replacement .. "/g")
      vim.notify("Replaced all '" .. selected_text .. "' with '" .. replacement .. "'")
    end
  else
    vim.notify("No text selected")
  end
end, { desc = "search and replace selected text" })

-- Search and replace with confirmation for visually selected text
keymap.set("x", "<leader>R", function()
  -- Get the selected text using the same simple method
  vim.cmd('normal! "zy')
  local selected_text = vim.fn.getreg("z")

  -- Clean up the text (remove newlines, trim whitespace)
  selected_text = selected_text:gsub("\n", ""):gsub("^%s+", ""):gsub("%s+$", "")

  if selected_text and selected_text ~= "" then
    -- Escape special characters for search
    local escaped_text = vim.fn.escape(selected_text, [[/\]])

    -- Prompt for replacement
    local replacement = vim.fn.input("Replace '" .. selected_text .. "' with: ")

    if replacement and replacement ~= "" then
      -- Perform the replacement with confirmation (gc flag)
      vim.cmd(":%s/" .. escaped_text .. "/" .. replacement .. "/gc")
    end
  else
    vim.notify("No text selected")
  end
end, { desc = "search and replace selected text (with confirmation)" })

-- Quick search and replace for word under cursor (normal mode)
keymap.set("n", "<leader>r", function()
  local word = vim.fn.expand("<cword>")
  if word ~= "" then
    local replacement = vim.fn.input("Replace '" .. word .. "' with: ")
    if replacement and replacement ~= "" then
      vim.cmd(":%s/\\<" .. word .. "\\>/" .. replacement .. "/g")
      vim.notify("Replaced all '" .. word .. "' with '" .. replacement .. "'")
    end
  end
end, { desc = "search and replace word under cursor" })

-- Quick search and replace for word under cursor with confirmation (normal mode)
keymap.set("n", "<leader>R", function()
  local word = vim.fn.expand("<cword>")
  if word ~= "" then
    local replacement = vim.fn.input("Replace '" .. word .. "' with: ")
    if replacement and replacement ~= "" then
      vim.cmd(":%s/\\<" .. word .. "\\>/" .. replacement .. "/gc")
    end
  end
end, { desc = "search and replace word under cursor (with confirmation)" })

-- Direct tab navigation
for i = 1, 9 do
  keymap.set("n", "<leader>" .. i, "<cmd>tabnext " .. i .. "<cr>", {
    desc = "Go to tab " .. i,
    silent = true,
  })
end

-- Use Esc to quit builtin terminal
keymap.set("t", "<Esc>", [[<c-\><c-n>]])

-- Toggle spell checking
keymap.set("n", "<F11>", "<cmd>set spell!<cr>", { desc = "toggle spell" })
keymap.set("i", "<F11>", "<c-o><cmd>set spell!<cr>", { desc = "toggle spell" })

-- Change text without putting it into the vim register,
-- see https://stackoverflow.com/q/54255/6064933
keymap.set("n", "c", '"_c')
keymap.set("n", "C", '"_C')
keymap.set("n", "cc", '"_cc')
keymap.set("x", "c", '"_c')

-- Remove trailing whitespace characters
keymap.set("n", "<leader><space>", "<cmd>StripTrailingWhitespace<cr>", { desc = "remove trailing space" })

-- Helper function to remove leading whitespace from current line
local function remove_leading_whitespace()
  local line = vim.api.nvim_get_current_line()
  local first_char = line:find("[^%s]")
  if first_char then
    vim.api.nvim_set_current_line(line:sub(first_char))
  else
    -- Line is all whitespace, make it empty
    vim.api.nvim_set_current_line("")
  end
end

-- Remove leading whitespace from current line
keymap.set("n", "<leader>s", remove_leading_whitespace, { desc = "remove leading whitespace from line" })

-- Paste and remove leading whitespace from current line
keymap.set("n", "<C-m>", function()
  -- Paste first (using normal! to avoid recursive mapping)
  vim.cmd("normal! p")
  -- Then remove leading whitespace from the current line
  remove_leading_whitespace()
end, { desc = "paste and remove leading whitespace from line" })

-- Copy entire buffer.
keymap.set("n", "<leader>y", "<cmd>%yank<cr>", { desc = "yank entire buffer" })

-- Toggle cursor column
keymap.set("n", "<leader>cl", "<cmd>call utils#ToggleCursorCol()<cr>", { desc = "toggle cursor column" })

-- Move current line up and down
keymap.set("n", "<A-k>", '<cmd>call utils#SwitchLine(line("."), "up")<cr>', { desc = "move line up" })
keymap.set("n", "<A-j>", '<cmd>call utils#SwitchLine(line("."), "down")<cr>', { desc = "move line down" })

-- Move current visual-line selection up and down
keymap.set("x", "<A-k>", '<cmd>call utils#MoveSelection("up")<cr>', { desc = "move selection up" })

keymap.set("x", "<A-j>", '<cmd>call utils#MoveSelection("down")<cr>', { desc = "move selection down" })

-- Replace visual selection with text in register, but not contaminate the register,
-- see also https://stackoverflow.com/q/10723700/6064933.
keymap.set("x", "p", '"_c<Esc>p')

-- Go to a certain buffer
keymap.set("n", "gb", '<cmd>call buf_utils#GoToBuffer(v:count, "forward")<cr>', {
  desc = "go to buffer (forward)",
})
keymap.set("n", "gB", '<cmd>call buf_utils#GoToBuffer(v:count, "backward")<cr>', {
  desc = "go to buffer (backward)",
})

-- Switch windows
keymap.set("n", "<left>", "<c-w>h")
keymap.set("n", "<Right>", "<C-W>l")
keymap.set("n", "<Up>", "<C-W>k")
keymap.set("n", "<Down>", "<C-W>j")

-- Text objects for URL
keymap.set({ "x", "o" }, "iu", "<cmd>call text_obj#URL()<cr>", { desc = "URL text object" })

-- Text objects for entire buffer
keymap.set({ "x", "o" }, "iB", ":<C-U>call text_obj#Buffer()<cr>", { desc = "buffer text object" })

-- Do not move my cursor when joining lines.
keymap.set("n", "J", function()
  vim.cmd([[
      normal! mzJ`z
      delmarks z
    ]])
end, {
  desc = "join lines without moving cursor",
})

keymap.set("n", "gJ", function()
  -- we must use `normal!`, otherwise it will trigger recursive mapping
  vim.cmd([[
      normal! mzgJ`z
      delmarks z
    ]])
end, {
  desc = "join lines without moving cursor",
})

-- Break inserted text into smaller undo units when we insert some punctuation chars.
local undo_ch = { ",", ".", "!", "?", ";", ":" }
for _, ch in ipairs(undo_ch) do
  keymap.set("i", ch, ch .. "<c-g>u")
end

-- insert semicolon in the end
keymap.set("i", "<A-;>", "<Esc>miA;<Esc>`ii")

-- Go to the beginning and end of current line in insert mode quickly
keymap.set("i", "<C-A>", "<HOME>")
keymap.set("i", "<C-E>", "<END>")

-- Go to beginning of command in command-line mode
keymap.set("c", "<C-A>", "<HOME>")

-- Delete the character to the right of the cursor
keymap.set("i", "<C-D>", "<DEL>")

-- Exit insert mode and save with jk
keymap.set("i", "jk", "<Esc>:write<CR>", { silent = true, desc = "exit insert mode and save" })

-- Prettify selected JSON (Handles both raw and escaped JSON)
keymap.set("x", "H", function()
  -- 1. Grab the visual selection
  vim.cmd('noau normal! "vy')
  local text = vim.fn.getreg("v")

  -- 2. Clean the input
  -- If we see escaped quotes (\") or newlines (\n), try to unescape them first.
  -- This makes it compatible with JSON copied from logs or code strings.
  if text:find('\\"') or text:find("\\n") then
    -- Remove the outer quotes if it looks like a string literal
    text = text:gsub('^"', ""):gsub('"$', "")
    -- Unescape backslashes
    text = text:gsub('\\"', '"'):gsub("\\n", "\n")
  end

  -- 3. Run through jq
  local job_cmd = "echo " .. vim.fn.shellescape(text) .. " | jq '.'"
  local output = vim.fn.system(job_cmd)

  -- 4. Check for success
  if vim.v.shell_error ~= 0 then
    -- Fallback: If cleaning failed, maybe it was just a weird raw JSON error?
    -- Let's show the error but NOT modify the buffer.
    vim.notify("JSON formatting failed: " .. output, vim.log.levels.ERROR)
    return
  end

  -- 5. Paste the result
  vim.fn.setreg("v", output)
  vim.cmd('normal! gv"vp')
end, { desc = "Prettify selected JSON" })

--- Opens the visually selected text as a file path in a new buffer.
local function open_visual_path()
  -- 1. Get the visually selected text:
  -- Save the current register, then yank the visual selection into a temporary register (z),
  -- then restore the original register.
  local old_reg = vim.fn.getreg("z")
  local old_regtype = vim.fn.getregtype("z")
  vim.cmd('normal! "zy')
  local path_rel = vim.fn.getreg("z")
  vim.fn.setreg("z", old_reg, old_regtype)

  -- 2. Clean up and resolve the path
  -- Remove newlines and trim whitespace from the selected text
  path_rel = path_rel:gsub("[\r\n]", ""):gsub("^%s+", ""):gsub("%s+$", "")

  if path_rel == "" then
    vim.notify("No text selected or selected text is empty.", vim.log.levels.WARN)
    return
  end

  -- Resolve to a full path using the current working directory (CWD)
  local full_path = vim.fn.resolve(path_rel)

  -- If `full_path` is still relative, it means `resolve` didn't find it based on path_rel.
  -- We assume it's relative to CWD in this specific use case.
  if vim.fn.isdirectory(full_path) == 0 and vim.fn.filereadable(full_path) == 0 then
    -- Try resolving relative to CWD if the simple resolve failed
    full_path = vim.fn.getcwd() .. "/" .. path_rel

    -- Final check
    if vim.fn.isdirectory(full_path) == 0 and vim.fn.filereadable(full_path) == 0 then
      vim.notify("File not found at: " .. full_path, vim.log.levels.ERROR)
      return
    end
  end

  -- 3. Open the file in a new tab
  -- Using `<cmd>tabedit` to open in a new tab is safer/less disruptive than just a new buffer/window.
  vim.cmd("tabedit " .. vim.fn.fnameescape(full_path))
  vim.notify("Opened file: " .. path_rel, vim.log.levels.INFO)
end

-- Keymap in Visual mode (x) for Shift + K
keymap.set("x", "<S-k>", open_visual_path, { desc = "Open visually selected text as file path" })

--- Opens a file path detected in the current line.
local function open_path_under_cursor()
  -- 1. Get the current line and cursor position
  local line = vim.api.nvim_get_current_line()
  local cursor_col = vim.fn.col(".") -- 1-indexed column

  -- 2. Find all potential file paths in the line

  -- Common file extensions to look for
  local extensions = {
    "md",
    "txt",
    "go",
    "lua",
    "py",
    "js",
    "ts",
    "json",
    "yaml",
    "yml",
    "toml",
    "vim",
    "sh",
    "bash",
    "zsh",
    "fish",
    "rs",
    "c",
    "cpp",
    "h",
    "hpp",
    "java",
    "kt",
    "swift",
    "rb",
    "php",
    "css",
    "html",
    "xml",
    "sql",
    "conf",
    "cfg",
    "ini",
    "env",
    "gitignore",
    "mod",
    "sum",
  }

  local paths = {}

  -- Pattern 1: Paths with slashes (relative/path, /absolute/path, path/to/file.ext)
  for path_match in line:gmatch("[^%s\"'`]+[/][^%s\"'`]+") do
    local start_pos = line:find(path_match, 1, true)
    local end_pos = start_pos + #path_match - 1

    table.insert(paths, {
      text = path_match,
      start_col = start_pos,
      end_col = end_pos,
    })
  end

  -- Pattern 2: Filenames with extensions (e.g., file.md, main.go, @README.md)
  -- This catches cases without slashes
  -- Lua patterns don't support alternation, so we try each extension separately
  for _, ext in ipairs(extensions) do
    -- Pattern: word characters + dot + extension
    -- Example: [%w_-]+%.md matches README.md, file.md, etc.
    local ext_pattern = "[%w_-]+%." .. ext

    for full_match in line:gmatch(ext_pattern) do
      local start_pos = line:find(full_match, 1, true)
      local end_pos = start_pos + #full_match - 1

      -- Avoid duplicates
      local is_duplicate = false
      for _, existing in ipairs(paths) do
        if existing.text == full_match then
          is_duplicate = true
          break
        end
      end

      if not is_duplicate then
        table.insert(paths, {
          text = full_match,
          start_col = start_pos,
          end_col = end_pos,
        })
      end
    end
  end

  -- Also check for paths inside quotes (common in code)
  for quoted_path in line:gmatch('["\']([^"\']+/[^"]*)["\']') do
    local start_pos = line:find(quoted_path, 1, true)
    if start_pos then
      local end_pos = start_pos + #quoted_path - 1
      table.insert(paths, {
        text = quoted_path,
        start_col = start_pos,
        end_col = end_pos,
      })
    end
  end

  -- If no paths found, notify user
  if #paths == 0 then
    vim.notify("No file path found in current line", vim.log.levels.INFO, { title = "Path Detection" })
    return
  end

  -- 3. Find the path nearest to the cursor
  local nearest_path = nil
  local min_distance = math.huge

  for _, path_info in ipairs(paths) do
    -- Check if cursor is within or near the path
    if cursor_col >= path_info.start_col and cursor_col <= path_info.end_col + 1 then
      nearest_path = path_info
      break
    end

    -- Calculate distance to the path
    local dist = math.min(math.abs(path_info.start_col - cursor_col), math.abs(path_info.end_col - cursor_col))
    if dist < min_distance then
      min_distance = dist
      nearest_path = path_info
    end
  end

  if not nearest_path then
    vim.notify("Could not determine which path to open", vim.log.levels.WARN, { title = "Path Detection" })
    return
  end

  -- 4. Clean the path - remove surrounding punctuation and quotes
  local raw_path = nearest_path.text
  local clean_path = raw_path

  -- Remove leading unwanted characters one by one
  clean_path = clean_path:gsub("^@+", "") -- Remove leading @ (common in imports like @module/path)
  clean_path = clean_path:gsub("^%[+", "") -- Remove leading [
  clean_path = clean_path:gsub("^%(+", "") -- Remove leading (
  clean_path = clean_path:gsub('^"+', "") -- Remove leading "
  clean_path = clean_path:gsub("^'+", "") -- Remove leading '
  clean_path = clean_path:gsub("^`+", "") -- Remove leading `

  -- Remove trailing unwanted characters one by one
  clean_path = clean_path:gsub("%.+$", "") -- Remove trailing . (common in punctuation at end of sentence)
  clean_path = clean_path:gsub("%]+$", "") -- Remove trailing ]
  clean_path = clean_path:gsub("%)$", "") -- Remove trailing )
  clean_path = clean_path:gsub('"$', "") -- Remove trailing "
  clean_path = clean_path:gsub("'$", "") -- Remove trailing '
  clean_path = clean_path:gsub("`$", "") -- Remove trailing `
  clean_path = clean_path:gsub(",$", "") -- Remove trailing ,
  clean_path = clean_path:gsub(";$", "") -- Remove trailing ;
  clean_path = clean_path:gsub(":$", "") -- Remove trailing :
  clean_path = clean_path:gsub("!$", "") -- Remove trailing !
  clean_path = clean_path:gsub("@$", "") -- Remove trailing @
  clean_path = clean_path:gsub("#$", "") -- Remove trailing #
  clean_path = clean_path:gsub("%$$", "") -- Remove trailing $
  clean_path = clean_path:gsub("%%$", "") -- Remove trailing %
  clean_path = clean_path:gsub("%^$", "") -- Remove trailing ^
  clean_path = clean_path:gsub("&$", "") -- Remove trailing &
  clean_path = clean_path:gsub("%*$", "") -- Remove trailing *
  clean_path = clean_path:gsub(">$", "") -- Remove trailing >
  clean_path = clean_path:gsub("<$", "") -- Remove trailing <

  -- 5. Try to resolve the path using multiple strategies
  local candidates = {}

  -- Strategy 1: Try as-is (could be absolute or already correct relative)
  table.insert(candidates, clean_path)

  -- Strategy 2: Relative to current file's directory
  local current_file = vim.fn.expand("%:p:h")
  if current_file and current_file ~= "" then
    table.insert(candidates, current_file .. "/" .. clean_path)
  end

  -- Strategy 3: Relative to current working directory
  local cwd = vim.fn.getcwd()
  table.insert(candidates, cwd .. "/" .. clean_path)

  -- Strategy 4: Try with findfile (searches in path)
  table.insert(candidates, vim.fn.findfile(clean_path))

  -- 6. Try each candidate until we find a readable file
  local found_path = nil
  for _, candidate in ipairs(candidates) do
    if candidate ~= "" and vim.fn.filereadable(candidate) == 1 then
      found_path = candidate
      break
    end
  end

  -- 7. Open the file or show error
  if found_path then
    vim.cmd("edit " .. vim.fn.fnameescape(found_path))
    vim.notify("Opened: " .. clean_path, vim.log.levels.INFO, { title = "File Opened" })
  else
    vim.notify("File not found: " .. clean_path, vim.log.levels.ERROR, { title = "Path Not Found" })
  end
end

-- Normal mode: Ctrl-o to open file path under cursor
keymap.set("n", "<C-o>", open_path_under_cursor, { desc = "Open file path detected in current line" })
