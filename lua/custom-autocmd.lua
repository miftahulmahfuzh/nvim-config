-- /home/devmiftahul/.config/nvim/lua/custom-autocmd.lua

local fn = vim.fn
local api = vim.api

local utils = require("utils")

-- Keep a working directory that exists. When nvim's cwd is deleted (a git worktree removed while nvim,
-- or the process that launched it, stood in it), uv.cwd() returns nil and every vim.fs.abspath() call
-- fails its assert. vim.filetype.match() calls it, so mini.icons (via dropbar) raises
-- "vim/fs:837: assertion failed!" on every redraw of a new file name. Move to the nearest directory
-- that still exists instead.
local last_cwd = vim.uv.cwd() or vim.env.PWD

local function ensure_cwd()
	local cwd = vim.uv.cwd()
	if cwd then
		last_cwd = cwd
		return
	end
	local dir = last_cwd or vim.env.HOME
	while dir ~= "/" and not vim.uv.fs_stat(dir) do
		dir = vim.fs.dirname(dir)
	end
	vim.cmd.cd(fn.fnameescape(dir))
	vim.notify(
		string.format("working directory %s was deleted, now in %s", last_cwd or "?", dir),
		vim.log.levels.WARN,
		{ title = "nvim-config" }
	)
	last_cwd = dir
end

ensure_cwd()
api.nvim_create_autocmd({ "DirChanged", "FocusGained", "BufEnter", "CursorMoved", "CursorMovedI", "CursorHold", "TermLeave" }, {
	group = api.nvim_create_augroup("ensure_cwd", { clear = true }),
	callback = ensure_cwd,
})

-- Display a message when the current file is not in utf-8 format.
-- Note that we need to use `unsilent` command here because of this issue:
-- https://github.com/vim/vim/issues/4379
api.nvim_create_autocmd({ "BufRead" }, {
	pattern = "*",
	group = api.nvim_create_augroup("non_utf8_file", { clear = true }),
	callback = function()
		if vim.bo.fileencoding ~= "utf-8" then
			vim.notify("File not in UTF-8 format!", vim.log.levels.WARN, { title = "nvim-config" })
		end
	end,
})

-- highlight yanked region, see `:h lua-highlight`
local yank_group = api.nvim_create_augroup("highlight_yank", { clear = true })
api.nvim_create_autocmd({ "TextYankPost" }, {
	pattern = "*",
	group = yank_group,
	callback = function()
		vim.hl.on_yank({ higroup = "YankColor", timeout = 300 })
	end,
})

api.nvim_create_autocmd({ "CursorMoved" }, {
	pattern = "*",
	group = yank_group,
	callback = function()
		vim.g.current_cursor_pos = vim.fn.getcurpos()
	end,
})

api.nvim_create_autocmd("TextYankPost", {
	pattern = "*",
	group = yank_group,
	---@diagnostic disable-next-line: unused-local
	callback = function(context)
		if vim.v.event.operator == "y" then
			vim.fn.setpos(".", vim.g.current_cursor_pos)
		end
	end,
})

-- Auto-create dir when saving a file, in case some intermediate directory does not exist
api.nvim_create_autocmd({ "BufWritePre" }, {
	pattern = "*",
	group = api.nvim_create_augroup("auto_create_dir", { clear = true }),
	callback = function(ctx)
		local dir = fn.fnamemodify(ctx.file, ":p:h")
		utils.may_create_dir(dir)
	end,
})

-- Automatically reload the file if it is changed outside of Nvim, see https://unix.stackexchange.com/a/383044/221410.
-- It seems that `checktime` does not work in command line. We need to check if we are in command
-- line before executing this command, see also https://vi.stackexchange.com/a/20397/15292 .
api.nvim_create_augroup("auto_read", { clear = true })

api.nvim_create_autocmd({ "FileChangedShellPost" }, {
	pattern = "*",
	group = "auto_read",
	callback = function()
		vim.notify("File changed on disk. Buffer reloaded!", vim.log.levels.WARN, { title = "nvim-config" })
	end,
})

api.nvim_create_autocmd({ "FocusGained", "CursorHold" }, {
	pattern = "*",
	group = "auto_read",
	callback = function()
		if fn.getcmdwintype() == "" then
			-- The event can fire under textlock (e.g. targets.vim waiting in getchar() inside an
			-- <expr> mapping), where checktime raises E565. Skip it, the next event retries.
			local ok, err = pcall(vim.cmd, "checktime")
			if not ok and not tostring(err):find("E565") then
				error(err, 0)
			end
		end
	end,
})

-- Resize all windows when we resize the terminal
api.nvim_create_autocmd("VimResized", {
	group = api.nvim_create_augroup("win_autoresize", { clear = true }),
	desc = "autoresize windows on resizing operation",
	command = "wincmd =",
})

local function open_nvim_tree(data)
	-- check if buffer is a directory
	local directory = vim.fn.isdirectory(data.file) == 1

	if not directory then
		return
	end

	-- create a new, empty buffer
	vim.cmd.enew()

	-- wipe the directory buffer
	vim.cmd.bw(data.buf)

	-- open the tree
	require("nvim-tree.api").tree.open()
end

api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })

-- Do not use smart case in command line mode, extracted from https://vi.stackexchange.com/a/16511/15292.
api.nvim_create_augroup("dynamic_smartcase", { clear = true })
api.nvim_create_autocmd("CmdLineEnter", {
	group = "dynamic_smartcase",
	pattern = ":",
	callback = function()
		vim.o.smartcase = false
	end,
})

api.nvim_create_autocmd("CmdLineLeave", {
	group = "dynamic_smartcase",
	pattern = ":",
	callback = function()
		vim.o.smartcase = true
	end,
})

api.nvim_create_autocmd("TermOpen", {
	group = api.nvim_create_augroup("term_start", { clear = true }),
	pattern = "*",
	callback = function()
		-- Do not use number and relative number for terminal inside nvim
		vim.wo.relativenumber = false
		vim.wo.number = false

		-- Go to insert mode by default to start typing command
		vim.cmd("startinsert")
	end,
})

local number_toggle_group = api.nvim_create_augroup("numbertoggle", { clear = true })
api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave", "WinEnter" }, {
	pattern = "*",
	group = number_toggle_group,
	desc = "togger line number",
	callback = function()
		if vim.wo.number then
			vim.wo.relativenumber = true
		end
	end,
})

api.nvim_create_autocmd({ "BufLeave", "FocusLost", "InsertEnter", "WinLeave" }, {
	group = number_toggle_group,
	desc = "togger line number",
	callback = function()
		if vim.wo.number then
			vim.wo.relativenumber = false
		end
	end,
})

api.nvim_create_autocmd("ColorScheme", {
	group = api.nvim_create_augroup("custom_highlight", { clear = true }),
	pattern = "*",
	desc = "Define or overrride some highlight groups",
	callback = function()
		-- For yank highlight
		vim.api.nvim_set_hl(0, "YankColor", { fg = "#34495E", bg = "#2ECC71", ctermfg = 59, ctermbg = 41 })

		-- For cursor colors
		vim.api.nvim_set_hl(0, "Cursor", { fg = "black", bg = "#00c918", bold = true })
		vim.api.nvim_set_hl(0, "Cursor2", { fg = "red", bg = "red" })

		-- For floating windows border highlight
		vim.api.nvim_set_hl(0, "FloatBorder", { fg = "LightGreen", bg = "None", bold = true })

		local hl = vim.api.nvim_get_hl(0, { name = "NormalFloat" })
		-- change the background color of floating window to None, so it blenders better
		vim.api.nvim_set_hl(0, "NormalFloat", { fg = hl.fg, bg = "None" })

		-- highlight for matching parentheses
		vim.api.nvim_set_hl(0, "MatchParen", { bold = true, underline = true })
	end,
})

api.nvim_create_autocmd("BufEnter", {
	pattern = "*",
	group = api.nvim_create_augroup("auto_close_win", { clear = true }),
	desc = "Quit Nvim if we have only one window, and its filetype match our pattern",
	---@diagnostic disable-next-line: unused-local
	callback = function(context)
		local quit_filetypes = { "qf", "vista", "NvimTree" }

		local should_quit = true
		local tabwins = api.nvim_tabpage_list_wins(0)

		for _, win in pairs(tabwins) do
			local buf = api.nvim_win_get_buf(win)
			local buf_type = vim.api.nvim_get_option_value("filetype", { buf = buf })

			if not vim.tbl_contains(quit_filetypes, buf_type) then
				should_quit = false
			end
		end

		if should_quit then
			vim.cmd("qall")
		end
	end,
})

api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
	group = api.nvim_create_augroup("git_repo_check", { clear = true }),
	pattern = "*",
	desc = "check if we are inside Git repo",
	callback = function()
		utils.inside_git_repo()
	end,
})

-- ref: https://vi.stackexchange.com/a/169/15292
api.nvim_create_autocmd("BufReadPre", {
	group = api.nvim_create_augroup("large_file", { clear = true }),
	pattern = "*",
	desc = "optimize for large file",
	callback = function(ev)
		local file_size_limit = 524288 -- 0.5MB
		local f = ev.file

		if fn.getfsize(f) > file_size_limit or fn.getfsize(f) == -2 then
			vim.o.eventignore = "all"

			-- show ruler
			vim.o.ruler = true

			--  turning off relative number helps a lot
			vim.wo.relativenumber = false
			vim.wo.number = false

			vim.bo.swapfile = false
			vim.bo.bufhidden = "unload"
			vim.bo.undolevels = -1
		end
	end,
})

api.nvim_create_autocmd("BufWritePre", {
	group = api.nvim_create_augroup("auto_format_lua_on_save", { clear = true }),
	pattern = "*.lua",
	desc = "Format Lua file with stylua on save",
	callback = function(args)
		-- No stylua (Mason not set up yet): save the buffer as typed, say nothing.
		if fn.executable("stylua") ~= 1 then
			return
		end

		local bufnr = args.buf
		local timeout_ms = 5000
		local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
		-- The buffer as it would be written: every line ends with a newline.
		local text = table.concat(lines, "\n") .. "\n"

		local ok, result = pcall(function()
			return vim.system({ "stylua", "-" }, { stdin = text, text = true }):wait(timeout_ms)
		end)

		-- On any failure the buffer is left exactly as typed and the write goes ahead.
		local failure
		if not ok then
			failure = tostring(result)
		elseif result.code == 124 then
			failure = string.format("timed out after %d ms", timeout_ms)
		elseif result.code ~= 0 then
			failure = vim.trim((result.stderr or ""):match("[^\r\n]+") or "")
			if failure == "" then
				failure = "exit code " .. result.code
			end
		end
		if failure then
			vim.notify(
				"stylua failed, buffer left unformatted: " .. failure,
				vim.log.levels.WARN,
				{ title = "nvim-config" }
			)
			return
		end

		-- stylua ends its output with a newline; drop it so the lines match the buffer's model.
		local formatted = result.stdout or ""
		if formatted:sub(-1) == "\n" then
			formatted = formatted:sub(1, -2)
		end
		local new_lines = vim.split(formatted, "\n", { plain = true })
		if vim.deep_equal(new_lines, lines) then
			return
		end

		-- Remember the cursor of every window showing this buffer, not only the current one.
		local cursors = {}
		for _, win in ipairs(fn.win_findbuf(bufnr)) do
			cursors[win] = api.nvim_win_get_cursor(win)
		end

		local set_ok, set_err = pcall(api.nvim_buf_set_lines, bufnr, 0, -1, false, new_lines)
		if not set_ok then
			vim.notify(
				"stylua: could not update the buffer, left unformatted: " .. tostring(set_err),
				vim.log.levels.WARN,
				{ title = "nvim-config" }
			)
			return
		end

		-- Clamp to the new line count and line length: the restore must never throw,
		-- because an error here aborts the write.
		local line_count = api.nvim_buf_line_count(bufnr)
		for win, pos in pairs(cursors) do
			local row = math.max(1, math.min(pos[1], line_count))
			local line = api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
			local col = math.max(0, math.min(pos[2], #line - 1))
			pcall(api.nvim_win_set_cursor, win, { row, col })
		end
	end,
})



-- Create diagnostic namespace for Python syntax errors
local python_syntax_ns = vim.api.nvim_create_namespace("python_syntax_errors")

-- Helper function to parse Python compilation errors
local function parse_python_syntax_error(error_output, filename)
	local diagnostics = {}

	-- Pattern to match Python syntax errors like:
	-- File "test.py", line 5
	--   print("hello"
	--          ^
	-- SyntaxError: EOL while scanning string literal
	for line_num, content, marker, error_msg in error_output:gmatch('File "[^"]*", line (%d+)%s*\n([^[]*)%s*(%^.*)%s*\n%w*Error: ([^\n]*)') do
		table.insert(diagnostics, {
			lnum = tonumber(line_num) - 1, -- 0-based line numbers for diagnostics
			col = 0, -- Start of line for syntax errors
			end_col = #content, -- End of the problematic line
			severity = vim.diagnostic.severity.ERROR,
			message = error_msg,
			source = "Python Syntax",
		})
	end

	-- Alternative pattern for simpler error messages
	for file_part, line_num, error_msg in error_output:gmatch('File "[^"]*", line (%d+)[^\n]*\n%w*Error: ([^\n]*)') do
		table.insert(diagnostics, {
			lnum = tonumber(line_num) - 1,
			col = 0,
			end_col = 0,
			severity = vim.diagnostic.severity.ERROR,
			message = error_msg,
			source = "Python Syntax",
		})
	end

	return diagnostics
end

-- Python syntax validation on save (no formatting)
api.nvim_create_autocmd("BufWritePre", {
	group = api.nvim_create_augroup("python_syntax_check_on_save", { clear = true }),
	pattern = "*.py",
	desc = "Check Python syntax on save",
	callback = function()
		-- Check if python is available for syntax validation
		if vim.fn.executable("python") == 0 and vim.fn.executable("python3") == 0 then
			return -- Silent exit if python not available
		end

		local bufnr = vim.api.nvim_get_current_buf()
		local original_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

		-- Clear previous syntax diagnostics for this buffer
		vim.diagnostic.reset(python_syntax_ns, bufnr)

		-- Validate Python syntax
		local python_cmd = vim.fn.executable("python") == 1 and "python" or "python3"
		local temp_file = vim.fn.tempname() .. ".py"

		-- Write current content to temp file for syntax checking
		vim.fn.writefile(original_content, temp_file)

		-- Use a shell command that captures both stdout and stderr
		local syntax_check_cmd = string.format('%s -m py_compile "%s" 2>&1', python_cmd, temp_file)
		local syntax_result = vim.fn.system(syntax_check_cmd)

		-- Clean up temp file
		vim.fn.delete(temp_file)

		-- If syntax check failed, publish diagnostics
		if vim.v.shell_error ~= 0 then
			local diagnostics = parse_python_syntax_error(syntax_result, temp_file)

			if #diagnostics > 0 then
				-- Set the diagnostics for the current buffer
				vim.diagnostic.set(python_syntax_ns, bufnr, diagnostics, {
					severity = vim.diagnostic.severity.ERROR,
				})
			else
				-- Fallback if parsing failed
				vim.diagnostic.set(python_syntax_ns, bufnr, {{
					lnum = 0,
					col = 0,
					end_col = 0,
					severity = vim.diagnostic.severity.ERROR,
					message = "Python syntax error: " .. syntax_result,
					source = "Python Syntax",
				}})
			end
		end
	end,
})
