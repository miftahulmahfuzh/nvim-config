-- /home/devmiftahul/.config/nvim/lua/custom/opencode.lua
-- A dedicated module for handling all interactions with the 'opencode' CLI tool via tmux.

local M = {}

-- Configuration for the opencode tool.
M.config = {
	nvim_executable = "/opt/nvim-linux-x86_64/bin/nvim",
}
M.config.nvim_bin_path = vim.fn.fnamemodify(M.config.nvim_executable, ":h")

--- Finds the tmux pane ID of a running 'opencode' session.
--- @return string|nil pane_id The tmux pane ID if found, otherwise nil.
local function find_opencode_pane()
	local find_pane_cmd = 'tmux list-panes -F "#{pane_id}:#{pane_current_command}"'
	local panes_info = vim.fn.system(find_pane_cmd)
	if vim.v.shell_error ~= 0 then
		return nil -- tmux command failed
	end

	for line in vim.gsplit(panes_info, "\n") do
		if line:find("opencode") then
			return line:match("([^:]+)")
		end
	end
	return nil
end

--- Gets the current visual selection in a safe way.
--- This is the one, true function for this job. No more duplicates.
--- @return string The selected text.
local function get_visual_selection()
	local old_reg_z = vim.fn.getreg("z")
	local old_reg_z_type = vim.fn.getregtype("z")
	vim.cmd('noau normal! "zy"')
	local selected_text = vim.fn.getreg("z")
	vim.fn.setreg("z", old_reg_z, old_reg_z_type)
	return selected_text:gsub("\n", " ") -- Replace newlines for cleaner prompts
end

--- Sends a list of file paths to the opencode tool.
--- @param selected_files table A list of file paths.
local function send_files(selected_files)
	if not selected_files or #selected_files == 0 then
		vim.notify("No files selected.", vim.log.levels.WARN, { title = "OpenCode" })
		return
	end

	local target_pane_id = find_opencode_pane()
	local file_args = table.concat(
		vim.tbl_map(function(file)
			return "@" .. file
		end, selected_files),
		" and "
	)

	if target_pane_id then
		-- Pane exists: send keys to it.
		local opencode_prompt = string.format("analyze %s as well", file_args)
		vim.fn.system(string.format("tmux select-pane -t %s", target_pane_id))
		vim.fn.system(string.format("tmux send-keys -t %s %s", target_pane_id, vim.fn.shellescape(opencode_prompt)))
		vim.fn.system(string.format("tmux send-keys -t %s Escape", target_pane_id))
		vim.notify(
			"Sent " .. #selected_files .. " file(s) to existing OpenCode pane.",
			vim.log.levels.INFO,
			{ title = "OpenCode" }
		)
	else
		-- Pane does not exist: create it.
		local opencode_cmd = string.format('opencode -p "analyze %s"', file_args)
		local current_dir = vim.fn.getcwd()
		local full_shell_cmd = string.format(
			"export PATH=%s:$PATH && export EDITOR=%s && %s",
			vim.fn.shellescape(M.config.nvim_bin_path),
			vim.fn.shellescape(M.config.nvim_executable),
			opencode_cmd
		)
		local tmux_cmd = string.format(
			"tmux split-window -h -c %s bash -c %s",
			vim.fn.shellescape(current_dir),
			vim.fn.shellescape(full_shell_cmd)
		)
		vim.fn.system(tmux_cmd)
		vim.notify(
			"Sent " .. #selected_files .. " file(s) to NEW OpenCode pane.",
			vim.log.levels.INFO,
			{ title = "OpenCode" }
		)
	end
end

--- Sends selected text to the opencode tool.
--- @param selected_text string The text to send.
local function send_text(selected_text)
	if not selected_text or vim.fn.trim(selected_text) == "" then
		vim.notify("No text selected.", vim.log.levels.WARN, { title = "OpenCode" })
		return
	end

	local file_path = vim.fn.expand("%")
	if file_path == "" then
		vim.notify(
			"Cannot get context from an unsaved buffer. Save the file.",
			vim.log.levels.WARN,
			{ title = "OpenCode" }
		)
		return
	end

	local target_pane_id = find_opencode_pane()
	local opencode_prompt =
		string.format('analyze @%s, then explain the following snippet: "%s"', file_path, selected_text)

	if target_pane_id then
		-- Pane exists: send keys to it.
		vim.fn.system(string.format("tmux select-pane -t %s", target_pane_id))
		vim.fn.system(string.format("tmux send-keys -t %s %s", target_pane_id, vim.fn.shellescape(opencode_prompt)))
		vim.fn.system(string.format("tmux send-keys -t %s Escape", target_pane_id))
		vim.notify("Sent selection to existing OpenCode pane.", vim.log.levels.INFO, { title = "OpenCode" })
	else
		-- Pane does not exist: create it.
		local opencode_cmd = string.format("opencode -p %s", vim.fn.shellescape(opencode_prompt))
		local current_dir = vim.fn.getcwd()
		local full_shell_cmd = string.format(
			"export PATH=%s:$PATH && export EDITOR=%s && %s",
			vim.fn.shellescape(M.config.nvim_bin_path),
			vim.fn.shellescape(M.config.nvim_executable),
			opencode_cmd
		)
		local tmux_cmd = string.format(
			"tmux split-window -h -c %s bash -c %s",
			vim.fn.shellescape(current_dir),
			vim.fn.shellescape(full_shell_cmd)
		)
		vim.fn.system(tmux_cmd)
		vim.notify("Sent selection to NEW OpenCode pane.", vim.log.levels.INFO, { title = "OpenCode" })
	end
end

--- Public interface for fzf-lua action.
--- @param selected table The list of files selected in fzf.
function M.send_files_from_fzf(selected)
	send_files(selected)
end

--- Public interface for the visual mode keymap.
function M.send_visual_selection()
	local selection = get_visual_selection()
	send_text(selection)
end

return M
