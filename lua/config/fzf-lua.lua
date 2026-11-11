-- /home/miftah/.config/nvim/lua/config/fzf-lua.lua

local actions = require("fzf-lua.actions")

require("fzf-lua").setup({
	defaults = {
		file_icons = "mini",
		-- These actions apply to any provider that opens files.
		actions = {
			["default"] = actions.file_edit,
			["ctrl-x"] = actions.file_split,
			["ctrl-l"] = actions.file_vsplit,
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
	grep = {
		-- Search dot-dirs too (.workflows/, .claude/, .github/), but never .git internals.
		-- .gitignore is still respected. `-e` must stay last: the query follows it.
		rg_opts = '--hidden -g "!.git" --column --line-number --no-heading --color=always --smart-case '
			.. "--max-columns=4096 -e",
	},
})

-- Grep the cwd plus every other worktree of its git repo, so a task ID that only
-- lives on a feature branch's worktree (~/.worktrees/...) is still found from main.
local function grep_paths()
	local out = vim.system({ "git", "worktree", "list", "--porcelain" }, { text = true }):wait()
	if out.code ~= 0 then
		return nil
	end
	local cwd = vim.fs.normalize(vim.uv.cwd())
	local paths = { "." }
	for root in out.stdout:gmatch("worktree ([^\n]+)") do
		root = vim.fs.normalize(root)
		local contains_cwd = cwd == root or vim.startswith(cwd, root .. "/")
		if not contains_cwd and vim.fn.isdirectory(root) == 1 then
			table.insert(paths, root)
		end
	end
	return #paths > 1 and paths or nil
end

local function live_grep(opts)
	opts = opts or {}
	opts.search_paths = grep_paths()
	require("fzf-lua").live_grep(opts)
end

-- Standard fzf-lua keymaps. Clean, simple, effective.
vim.keymap.set("n", "<leader>ff", "<cmd>FzfLua files<cr>", { desc = "Fuzzy find files" })
vim.keymap.set("n", "<leader>fe", "<cmd>FzfLua oldfiles<cr>", { desc = "Fuzzy find recent files" })
vim.keymap.set("n", "<leader>fg", live_grep, { desc = "Fuzzy grep files (cwd + git worktrees)" })
vim.keymap.set("n", "<leader>fh", "<cmd>FzfLua helptags<cr>", { desc = "Fuzzy grep tags in help files" })
vim.keymap.set("n", "<leader>fr", "<cmd>FzfLua btags<cr>", { desc = "Fuzzy search buffer tags" })
vim.keymap.set("n", "<leader>fb", "<cmd>FzfLua buffers<cr>", { desc = "Fuzzy search opened buffers" })
vim.keymap.set("n", "<leader>ft", "<cmd>FzfLua tabs<cr>", { desc = "Fuzzy search opened tabs" })

-- Keymap for live_grep with word under cursor or visual selection.
-- This logic is fine and stays here.
vim.keymap.set({ "n", "v" }, "<leader>m", function()
	local search_term

	if vim.fn.mode():find("[vV]") then
		-- A safe way to get the visual selection without clobbering registers.
		local old_reg_z = vim.fn.getreg("z")
		local old_reg_z_type = vim.fn.getregtype("z")
		vim.cmd('noau normal! "zy"') -- Yank selection into register 'z'
		search_term = vim.fn.getreg("z")
		vim.fn.setreg("z", old_reg_z, old_reg_z_type) -- Restore register 'z'
		search_term = search_term:gsub("\n", " ")
	else
		search_term = vim.fn.expand("<cword>")
	end

	search_term = vim.fn.trim(search_term)

	if search_term == "" then
		live_grep()
	else
		live_grep({
			search = search_term,
		})
	end
end, { desc = "Grep for word/selection" })

-- Insert Mode Keymap: <C-f>
-- Opens fzf file picker, but inserts the relative path instead of opening it.
vim.keymap.set("i", "<C-f>", function()
	require("fzf-lua").files({
		-- We override the default actions for this specific call
		actions = {
			["default"] = function(selected)
				-- 'selected' is a lua table (list) containing the selected items
				if not selected or #selected < 1 then
					return
				end

				-- We handle multiple selections (using Tab in fzf) just in case
				local paths_to_insert = {}

				for _, item in ipairs(selected) do
					-- entry_to_file cleans up the string (removes icons, etc)
					local entry = require("fzf-lua").path.entry_to_file(item)
					table.insert(paths_to_insert, entry.path)
				end

				-- Join multiple paths with " @", prepend "@" to the first item, and append " ."
				local text_to_insert = " @" .. table.concat(paths_to_insert, " @") .. " ."

				-- Insert the text at the current cursor position
				-- 'c' = characterwise
				-- true, true = follow indentation and place cursor after text
				vim.api.nvim_put({ text_to_insert }, "c", true, true)
			end,
		},
	})
end, { desc = "Insert file path" })
