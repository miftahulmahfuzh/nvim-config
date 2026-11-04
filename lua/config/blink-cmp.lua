-- /home/miftah/.config/nvim/lua/config/blink-cmp.lua
-- blink.cmp v1 (spec: version = "1.*"). Every key is checked against v1.10.2's option schema
-- (lua/blink/cmp/config/*.lua); blink rejects unknown keys at setup.

local lspkind = require("lspkind")

require("blink.cmp").setup({
	-- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
	-- 'super-tab' for mappings similar to vscode (tab to accept)
	-- 'enter' for enter to accept
	-- 'none' for no mappings
	keymap = {
		preset = "default",
		["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
		["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
		["<Enter>"] = { "select_and_accept", "fallback" },
		["<C-U>"] = { "scroll_documentation_up", "fallback" },
		["<C-D>"] = { "scroll_documentation_down", "fallback" },
		["<C-E>"] = { "cancel", "fallback" },
		["<Esc>"] = { "cancel", "fallback" },
	},

	appearance = {
		-- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
		-- Adjusts spacing to ensure icons are aligned
		nerd_font_variant = "mono",
	},

	completion = {
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 500,
		},
		menu = {
			border = "rounded",
			draw = {
				treesitter = { "lsp" },
			},
		},
		ghost_text = {
			enabled = true,
		},
	},

	-- Default list of enabled providers defined so that you can extend it
	-- elsewhere in your config, without redefining it, due to `opts_extend`
	sources = {
		default = { "lsp", "path", "buffer", "snippets" },
		providers = {
			lsp = {
				name = "LSP",
				module = "blink.cmp.sources.lsp",
				fallbacks = { "buffer" },
			},
			path = {
				name = "Path",
				module = "blink.cmp.sources.path",
				score_offset = 3, -- Boost priority so it appears above 'buffer' suggestions
				-- When typing a path, we usually want it to activate immediately
				opts = {
					trailing_slash = false,
					label_trailing_slash = true,
					get_cwd = function(context)
						return vim.fn.expand(("#%d:p:h"):format(context.bufnr))
					end,
					show_hidden_files_by_default = true,
				},
			},
			buffer = {
				name = "Buffer",
				module = "blink.cmp.sources.buffer",
				fallbacks = {},
			},
			snippets = {
				name = "Snippets",
				module = "blink.cmp.sources.snippets",
				fallbacks = {},
			},
		},
	},

	-- Command line
	cmdline = {
		completion = {
			menu = {
				auto_show = true,
			},
		},
		keymap = {
			["<Enter>"] = { "select_and_accept", "fallback" },
			["<Tab>"] = { "select_next", "fallback" },
			["<S-Tab>"] = { "select_prev", "fallback" },
		},
		-- No blink sources on the command line: it keeps Neovim's own completion (wildmenu), which
		-- <Tab>/<S-Tab>/<Enter> reach through "fallback". This is what the v0 config did too: it passed
		-- { default = {...}, providers = {...} } here, a shape blink reads as a list (ipairs), i.e. as
		-- no sources (`:checkhealth blink.cmp` listed no "Cmdline sources"). Adding "cmdline"/"path"
		-- would turn on blink's command-line menu, and <Enter> would accept its first item instead of
		-- running the command.
		sources = {},
	},
})
