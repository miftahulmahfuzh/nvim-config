-- /home/devmiftahul/.config/nvim/lua/config/fzf-lua.lua

-- import the standard fzf-lua actions module
local actions = require("fzf-lua.actions")

require("fzf-lua").setup {
  defaults = {
    file_icons = "mini",
    -- This table maps keybindings within the fzf window to specific functions.
    -- By placing it in 'defaults', these bindings will work for any provider
    -- that opens files (e.g., 'files', 'buffers', 'oldfiles').
    actions = {
      -- The default action for <CR> (Enter) is to open in the current window.
      ["default"] = actions.file_edit,
      -- Your custom request: <C-x> opens the file in a horizontal split.
      ["ctrl-x"] = actions.file_split,
      -- Your custom request: <C-l> opens the file in a vertical split.
      -- Note: The default for vsplit is often <C-v>, so we'll add that too.
      ["ctrl-l"] = actions.file_vsplit,
      -- A useful bonus: <C-t> opens the file in a new tab.
      ["ctrl-t"] = actions.file_tabedit,
    },
  },
  winopts = {
    row = 0.5,
    height = 0.7,
  },
  files = {
    previewer = true,
  },
}

vim.keymap.set("n", "<leader>ff", "<cmd>FzfLua files<cr>", { desc = "Fuzzy find files" })
vim.keymap.set("n", "<leader>fg", "<cmd>FzfLua live_grep<cr>", { desc = "Fuzzy grep files" })
vim.keymap.set("n", "<leader>fh", "<cmd>FzfLua helptags<cr>", { desc = "Fuzzy grep tags in help files" })
vim.keymap.set("n", "<leader>ft", "<cmd>FzfLua btags<cr>", { desc = "Fuzzy search buffer tags" })
vim.keymap.set("n", "<leader>fb", "<cmd>FzfLua buffers<cr>", { desc = "Fuzzy search opened buffers" })

-- keymap for live_grep with word under cursor or visual selection
vim.keymap.set({ "n", "v" }, "<leader>m", function()
  local fzf_lua = require("fzf-lua")
  local search_term

  -- Check if we are in visual mode by checking the result of vim.fn.mode()
  if vim.fn.mode():find("[vV]") then
    -- This is a safe way to get the visual selection without clobbering any registers
    -- that the user might be actively using. We temporarily use register 'z'.
    local old_reg_z = vim.fn.getreg('z')
    local old_reg_z_type = vim.fn.getregtype('z')
    vim.cmd('noau normal! "zy"') -- yank current visual selection into register 'z'
    search_term = vim.fn.getreg('z')
    vim.fn.setreg('z', old_reg_z, old_reg_z_type) -- restore register 'z' to its previous state

    -- For multi-line selections, it's better to replace newlines with spaces
    search_term = search_term:gsub('\n', ' ')
  else
    -- In normal mode, get the word under the cursor
    search_term = vim.fn.expand("<cword>")
  end

  -- Trim leading/trailing whitespace to avoid issues
  search_term = vim.fn.trim(search_term)

  if search_term == "" then
    -- If no word is found (e.g., on a blank line), just open live_grep with an empty prompt
    fzf_lua.live_grep()
  else
    -- Call the live_grep Lua function with the 'search' option pre-filled
    fzf_lua.live_grep({
      search = search_term,
    })
  end
end, { desc = "Grep for word/selection" })

-- OPENCODE SECTION

-- Helper function to find OpenCode tmux pane
local function find_opencode_pane()
  local find_pane_cmd = 'tmux list-panes -F "#{pane_id}:#{pane_current_command}"'
  local panes_info = vim.fn.system(find_pane_cmd)

  for line in vim.gsplit(panes_info, "\n") do
    if line:find("opencode") then
      return line:match("([^:]+)")
    end
  end
  return nil
end

-- Smart function to send files to OpenCode (toggles between new/existing)
local function send_files_to_opencode(selected_files)
  if not selected_files or #selected_files == 0 then
    vim.notify("No files selected.", vim.log.levels.WARN, { title = "OpenCode" })
    return
  end

  local target_pane_id = find_opencode_pane()

  if target_pane_id then
    -- Existing OpenCode pane found - send to it
    local formatted_files = {}
    for _, file_path in ipairs(selected_files) do
      table.insert(formatted_files, "@" .. vim.fn.fnameescape(file_path))
    end
    local file_args = table.concat(formatted_files, " and ")
    local opencode_prompt = string.format('analyze %s as well', file_args)

    -- Select the pane and send the command
    vim.fn.system(string.format("tmux select-pane -t %s", target_pane_id))
    vim.fn.system(string.format("tmux send-keys -t %s %s",
                                target_pane_id,
                                vim.fn.shellescape(opencode_prompt)))
    vim.fn.system(string.format("tmux send-keys -t %s Escape", target_pane_id))

    vim.notify("Sent " .. #selected_files .. " additional file(s) to existing OpenCode pane.", vim.log.levels.INFO, { title = "OpenCode" })
  else
    -- No existing OpenCode pane - create new one
    local formatted_files = {}
    for _, file_path in ipairs(selected_files) do
      table.insert(formatted_files, "@" .. file_path)
    end
    local file_args = table.concat(formatted_files, " and ")
    local opencode_cmd = string.format('opencode -p "analyze %s"', file_args)
    local current_dir = vim.fn.getcwd()

    -- Set both PATH and EDITOR environment variables to ensure OpenCode uses the correct nvim
    local nvim_bin_path = "/opt/nvim-linux-x86_64/bin"
    local nvim_full_path = "/opt/nvim-linux-x86_64/bin/nvim"

    -- Create a shell command that exports the environment variables and then runs opencode
    local full_shell_cmd = string.format("export PATH=%s:$PATH && export EDITOR=%s && %s",
                                         vim.fn.shellescape(nvim_bin_path),
                                         vim.fn.shellescape(nvim_full_path),
                                         opencode_cmd)

    -- Build the final tmux command using bash to ensure the export commands work
    local tmux_cmd = string.format("tmux split-window -h -c %s bash -c %s",
                                   vim.fn.shellescape(current_dir),
                                   vim.fn.shellescape(full_shell_cmd))

    vim.fn.system(tmux_cmd)
    vim.notify("Sent " .. #selected_files .. " file(s) to NEW OpenCode pane.", vim.log.levels.INFO, { title = "OpenCode" })
  end
end

-- Smart function to send text to OpenCode (toggles between new/existing)
local function send_text_to_opencode(selected_text)
  if not selected_text or vim.fn.trim(selected_text) == "" then
    vim.notify("No text selected.", vim.log.levels.WARN, { title = "OpenCode" })
    return
  end

  local file_path = vim.fn.expand('%')
  if file_path == "" then
    vim.notify("Cannot get context from an unsaved buffer. Please save the file first.", vim.log.levels.WARN, { title = "OpenCode" })
    return
  end

  local target_pane_id = find_opencode_pane()

  if target_pane_id then
    -- Existing OpenCode pane found - send to it
    local opencode_prompt = string.format(
      'analyze @%s , then explain the following snippet : " %s "',
      file_path,
      selected_text
    )

    -- Select the pane and send the command
    vim.fn.system(string.format("tmux select-pane -t %s", target_pane_id))
    vim.fn.system(string.format("tmux send-keys -t %s %s",
                                target_pane_id,
                                vim.fn.shellescape(opencode_prompt)))
    vim.fn.system(string.format("tmux send-keys -t %s Escape", target_pane_id))

    vim.notify("Sent selection from " .. vim.fn.expand('%:t') .. " to existing OpenCode pane.", vim.log.levels.INFO, { title = "OpenCode" })
  else
    -- No existing OpenCode pane - create new one
    local opencode_prompt = string.format(
      'analyze @%s , then explain the following snippet : " %s "',
      file_path,
      selected_text
    )

    local opencode_cmd = string.format('opencode -p %s', vim.fn.shellescape(opencode_prompt))
    local current_dir = vim.fn.getcwd()

    -- Set both PATH and EDITOR environment variables
    local nvim_bin_path = "/opt/nvim-linux-x86_64/bin"
    local nvim_full_path = "/opt/nvim-linux-x86_64/bin/nvim"

    local full_shell_cmd = string.format("export PATH=%s:$PATH && export EDITOR=%s && %s",
                                         vim.fn.shellescape(nvim_bin_path),
                                         vim.fn.shellescape(nvim_full_path),
                                         opencode_cmd)

    local tmux_cmd = string.format("tmux split-window -h -c %s bash -c %s",
                                   vim.fn.shellescape(current_dir),
                                   vim.fn.shellescape(full_shell_cmd))

    vim.fn.system(tmux_cmd)
    vim.notify("Sent selection from " .. vim.fn.expand('%:t') .. " to NEW OpenCode pane.", vim.log.levels.INFO, { title = "OpenCode" })
  end
end

-- Helper function to get visual selection
local function get_visual_selection()
  local old_reg_z = vim.fn.getreg('z')
  local old_reg_z_type = vim.fn.getregtype('z')

  vim.cmd('noau normal! "zy')
  local selected_text = vim.fn.getreg('z')

  vim.fn.setreg('z', old_reg_z, old_reg_z_type)
  return selected_text
end

-- <leader>fo - Fuzzy find files and open with OpenCode (smart toggle)
vim.keymap.set("n", "<leader>fo", function()
  local fzf = require("fzf-lua")
  fzf.files({
    actions = {
      ["default"] = send_files_to_opencode
    }
  })
end, { desc = "Fuzzy find files and open with OpenCode (smart toggle)" })

-- <leader>z - Send visual selection to OpenCode (smart toggle)
vim.keymap.set("v", "<leader>z", function()
  local selected_text = get_visual_selection()
  send_text_to_opencode(selected_text)
end, { desc = "Send visual selection to OpenCode (smart toggle)" })
