-- /home/devmiftahul/.config/nvim/lua/custom-autocmd.lua

local fn = vim.fn
local api = vim.api

local utils = require("utils")

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
			vim.cmd("checktime")
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
	callback = function()
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		vim.cmd("silent %!stylua -")
		vim.api.nvim_win_set_cursor(0, cursor_pos)
	end,
})

-- Create diagnostic namespace for JavaScript/TypeScript syntax errors
local js_ts_syntax_ns = vim.api.nvim_create_namespace("js_ts_syntax_errors")

-- Helper function to check if node is available for syntax validation
local function check_node_executable()
	return vim.fn.executable("node") == 1
end

-- Helper function to parse JavaScript/TypeScript syntax errors
local function parse_js_ts_syntax_error(error_output)
	local diagnostics = {}

	-- Pattern for TypeScript/JavaScript syntax errors
	-- Example: "test.ts:5:1 - error TS1002: Unterminated string literal."
	for file_path, line_num, col_num, error_msg in error_output:gmatch('([^:]+):(%d+):(%d+)%s*%-%s*error[^:]*:%s*([^\n]*)') do
		table.insert(diagnostics, {
			lnum = tonumber(line_num) - 1, -- 0-based line numbers for diagnostics
			col = tonumber(col_num) - 1, -- 0-based column numbers for diagnostics
			end_col = tonumber(col_num), -- End at the same column for syntax errors
			severity = vim.diagnostic.severity.ERROR,
			message = error_msg,
			source = "TypeScript/JavaScript Syntax",
		})
	end

	-- Fallback pattern for other types of JS/TS errors
	for error_msg in error_output:gmatch('[Ee]rror[:]?%s*([^\n]*)') do
		if error_msg ~= "" then
			table.insert(diagnostics, {
				lnum = 0,
				col = 0,
				end_col = 0,
				severity = vim.diagnostic.severity.ERROR,
				message = error_msg,
				source = "TypeScript/JavaScript Syntax",
			})
		end
	end

	return diagnostics
end

-- JavaScript/TypeScript syntax validation (non-destructive)
local function validate_js_ts_syntax(bufnr, content)
	-- Check if node is available for syntax validation
	if not check_node_executable() then
		return -- Silent exit if node not available
	end

	-- Clear previous syntax diagnostics for this buffer
	vim.diagnostic.reset(js_ts_syntax_ns, bufnr)

	local filetype = vim.bo[bufnr].filetype
	local temp_file = vim.fn.tempname()
	local file_ext = filetype:match("typescript") and ".ts" or ".js"
	temp_file = temp_file .. file_ext

	-- Write current content to temp file for syntax checking
	vim.fn.writefile(content, temp_file)

	local syntax_check_cmd
	if filetype:match("typescript") then
		-- Try to use TypeScript compiler if available
		if vim.fn.executable("tsc") == 1 then
			syntax_check_cmd = string.format('tsc --noEmit --strict "%s" 2>&1', temp_file)
		else
			-- Fallback to node with basic syntax check
			syntax_check_cmd = string.format('node -c "%s" 2>&1', temp_file)
		end
	else
		-- JavaScript syntax check
		syntax_check_cmd = string.format('node -c "%s" 2>&1', temp_file)
	end

	local syntax_result = vim.fn.system(syntax_check_cmd)

	-- Clean up temp file
	vim.fn.delete(temp_file)

	-- If syntax check failed, publish diagnostics
	if vim.v.shell_error ~= 0 then
		local diagnostics = parse_js_ts_syntax_error(syntax_result)

		if #diagnostics > 0 then
			-- Set the diagnostics for the current buffer
			vim.diagnostic.set(js_ts_syntax_ns, bufnr, diagnostics, {
				severity = vim.diagnostic.severity.ERROR,
			})
		else
			-- Fallback if parsing failed
			vim.diagnostic.set(js_ts_syntax_ns, bufnr, {{
				lnum = 0,
				col = 0,
				end_col = 0,
				severity = vim.diagnostic.severity.ERROR,
				message = "JavaScript/TypeScript syntax error: " .. syntax_result,
				source = "TypeScript/JavaScript Syntax",
			}})
		end
		return false -- Syntax error detected
	end

	return true -- No syntax errors
end

-- Safe formatting function that only runs if there are no syntax errors
local function safe_format_prettierd()
	local bufnr = vim.api.nvim_get_current_buf()
	local original_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local cursor_pos = vim.api.nvim_win_get_cursor(0)

	-- First, validate syntax without modifying the buffer
	if not validate_js_ts_syntax(bufnr, original_content) then
		-- Syntax error found - don't format, just show diagnostics
		vim.notify("Formatting skipped due to syntax errors", vim.log.levels.WARN, { title = "nvim-config" })
		return
	end

	-- No syntax errors - proceed with safe formatting
	local temp_file = vim.fn.tempname() .. (vim.bo.filetype:match("typescript") and ".ts" or ".js")
	vim.fn.writefile(original_content, temp_file)

	-- Try to format the temp file
	local format_cmd = string.format('prettierd "%s" 2>&1', temp_file)
	local formatted_result = vim.fn.system(format_cmd)

	-- Clean up temp file
	vim.fn.delete(temp_file)

	-- Only apply formatting if prettierd succeeded
	if vim.v.shell_error == 0 and formatted_result ~= "" then
		-- Split formatted result into lines
		local formatted_lines = {}
		for line in formatted_result:gmatch("[^\r\n]+") do
			table.insert(formatted_lines, line)
		end

		-- Only apply formatting if the result is not empty
		if #formatted_lines > 0 then
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted_lines)

			-- Clamp cursor position to valid ranges after formatting
			local total_lines = vim.api.nvim_buf_line_count(bufnr)
			local max_line = math.max(1, total_lines)  -- Ensure at least line 1
			local clamped_line = math.min(cursor_pos[1], max_line)

			-- Get the line length to clamp column position as well
			local line_content = vim.api.nvim_buf_get_lines(bufnr, clamped_line - 1, clamped_line, false)[1] or ""
			local max_col = math.max(0, #line_content)  -- Allow cursor at end of line
			local clamped_col = math.min(cursor_pos[2], max_col)

			vim.api.nvim_win_set_cursor(0, {clamped_line, clamped_col})
		else
			vim.notify("Prettierd returned empty result, formatting skipped", vim.log.levels.WARN, { title = "nvim-config" })
		end
	else
		vim.notify("Prettierd formatting failed, preserving original content", vim.log.levels.WARN, { title = "nvim-config" })
	end
end

-- Format JS, TS, HTML, CSS files with prettierd on save (non-destructive)
api.nvim_create_autocmd("BufWritePre", {
	group = api.nvim_create_augroup("auto_format_prettierd_on_save", { clear = true }),
	pattern = {
		-- "*.html",
		"*.css",
		"*.javascript",
		"*.javascriptreact",
		"*.typescript",
		"*.typescriptreact",
		"*.js",
		"*.jsx",
		"*.ts",
		"*.tsx",
	},
	desc = "Safe format web development files with prettierd on save",
	callback = function()
		safe_format_prettierd()
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
