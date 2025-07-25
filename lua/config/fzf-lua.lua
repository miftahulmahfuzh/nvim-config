-- /home/devmiftahul/.config/nvim/lua/config/fzf-lua.lua

local actions = require("fzf-lua.actions")
local opencode = require("custom.opencode") -- Require our new, clean module

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
})

-- Standard fzf-lua keymaps. Clean, simple, effective.
vim.keymap.set("n", "<leader>ff", "<cmd>FzfLua files<cr>", { desc = "Fuzzy find files" })
vim.keymap.set("n", "<leader>fg", "<cmd>FzfLua live_grep<cr>", { desc = "Fuzzy grep files" })
vim.keymap.set("n", "<leader>fh", "<cmd>FzfLua helptags<cr>", { desc = "Fuzzy grep tags in help files" })
vim.keymap.set("n", "<leader>fr", "<cmd>FzfLua btags<cr>", { desc = "Fuzzy search buffer tags" })
vim.keymap.set("n", "<leader>fb", "<cmd>FzfLua buffers<cr>", { desc = "Fuzzy search opened buffers" })
vim.keymap.set("n", "<leader>ft", "<cmd>FzfLua tabs<cr>", { desc = "Fuzzy search opened tabs" })

-- Keymap for live_grep with word under cursor or visual selection.
-- This logic is fine and stays here.
vim.keymap.set({ "n", "v" }, "<leader>m", function()
	local fzf_lua = require("fzf-lua")
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
		fzf_lua.live_grep()
	else
		fzf_lua.live_grep({
			search = search_term,
		})
	end
end, { desc = "Grep for word/selection" })

-- OpenCode Integration Keymaps
-- These now call the clean, modularized functions.

-- <leader>fo - Fuzzy find files and send to OpenCode
vim.keymap.set("n", "<leader>fo", function()
	require("fzf-lua").files({
		actions = {
			-- The action calls our clean, reusable function.
			["default"] = opencode.send_files_from_fzf,
		},
	})
end, { desc = "Fuzzy find files and send to OpenCode" })

-- <leader>z - Send visual selection to OpenCode
vim.keymap.set("v", "<leader>z", opencode.send_visual_selection, { desc = "Send visual selection to OpenCode" })
