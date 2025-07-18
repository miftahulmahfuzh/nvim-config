-- /home/devmiftahul/.config/nvim/lua/config/treesitter.lua

require("nvim-treesitter.configs").setup({
	ensure_installed = {
		"python",
		"http",
		"cpp",
		"lua",
		"vim",
		"json",
		"toml",
		"markdown",
		"markdown_inline",
		"html",
		"css",
		"javascript",
		"go",
	},
	ignore_install = {}, -- List of parsers to ignore installing
	highlight = {
		enable = true, -- false will disable the whole extension
		disable = { "help" }, -- list of language that will be disabled
		additional_vim_regex_highlighting = { "markdown" }, -- Enable vim regex highlighting for markdown
	},
	-- Add incremental selection for better markdown editing
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "gnn",
			node_incremental = "grn",
			scope_incremental = "grc",
			node_decremental = "grm",
		},
	},
	-- Add indentation support
	indent = {
		enable = true,
		disable = { "yaml" }, -- YAML indentation can be problematic
	},
})
