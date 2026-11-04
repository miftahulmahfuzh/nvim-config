-- nvim-treesitter-textobjects `main`: setup() takes the options, the keymaps are set here.

require("nvim-treesitter-textobjects").setup({
	select = {
		-- Automatically jump forward to textobj, similar to targets.vim
		lookahead = true,
		-- The select mode per capture (default is charwise 'v')
		selection_modes = {
			["@function.inner"] = "V", -- linewise
			["@function.outer"] = "V", -- linewise
			["@class.outer"] = "V", -- linewise
			["@class.inner"] = "V", -- linewise
			["@parameter.outer"] = "v", -- charwise
		},
		-- true would extend every textobject with the whitespace around it, like the built-in `ap`
		include_surrounding_whitespace = false,
	},
})

-- The capture groups come from the plugin's queries/<lang>/textobjects.scm.
local textobjects = {
	{ lhs = "af", capture = "@function.outer", desc = "Select outer part of a function" },
	{ lhs = "if", capture = "@function.inner", desc = "Select inner part of a function" },
	{ lhs = "ac", capture = "@class.outer", desc = "Select outer part of a class region" },
	{ lhs = "ic", capture = "@class.inner", desc = "Select inner part of a class region" },
}

for _, obj in ipairs(textobjects) do
	vim.keymap.set({ "x", "o" }, obj.lhs, function()
		require("nvim-treesitter-textobjects.select").select_textobject(obj.capture, "textobjects")
	end, { desc = obj.desc })
end
