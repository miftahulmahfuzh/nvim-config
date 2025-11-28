-- /home/devmiftahul/.config/nvim/lua/plugin_specs.lua

local utils = require("utils")

local plugin_dir = vim.fn.stdpath("data") .. "/lazy"
local lazypath = plugin_dir .. "/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- check if firenvim is active
local firenvim_not_active = function()
	return not vim.g.started_by_firenvim
end

local plugin_specs = {
	-- auto-completion engine with blink-cmp
	{
		"saghen/blink.cmp",
		version = "v0.*",
		lazy = false,
		priority = 100,
		dependencies = {
			"rafamadriz/friendly-snippets",
			-- Optional dependencies
			"onsails/lspkind.nvim",
		},
		config = function()
			require("config.blink-cmp")
		end,
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			-- This is the critical change. It ensures mason-lspconfig runs before lspconfig.
			"williamboman/mason-lspconfig.nvim",
			"williamboman/mason.nvim",
		},
		config = function()
			require("config.lsp")
		end,
	},
	{
		"dnlhc/glance.nvim",
		config = function()
			require("config.glance")
		end,
		event = "VeryLazy",
	},
	{
		"nvim-treesitter/nvim-treesitter",
		lazy = true,
		build = ":TSUpdate",
		config = function()
			require("config.treesitter")
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		event = "VeryLazy",
		branch = "master",
		config = function()
			require("config.treesitter-textobjects")
		end,
	},
	{ "machakann/vim-swap", event = "VeryLazy" },

	-- Show match number and index for searching
	{
		"kevinhwang91/nvim-hlslens",
		branch = "main",
		keys = { "*", "#", "n", "N" },
		config = function()
			require("config.hlslens")
		end,
	},
	{
		"nvim-telescope/telescope.nvim",
		cmd = "Telescope",
		dependencies = {
			"nvim-telescope/telescope-symbols.nvim",
		},
	},
	{
		"ibhagwan/fzf-lua",
		config = function()
			require("config.fzf-lua")
		end,
		event = "VeryLazy",
	},
	-- Simplified markdown rendering
	{
		"MeanderingProgrammer/markdown.nvim",
		main = "render-markdown",
		name = "render-markdown", -- let's use the same name as the main file for clarity
		ft = "markdown",
		opts = {}, -- The defaults are sane. Stop over-configuring.
	},
	-- A list of colorscheme plugin you may want to try. Find what suits you.
	{ "navarasu/onedark.nvim" },
	{ "sainnhe/edge" },
	{ "sainnhe/sonokai" },
	{ "sainnhe/gruvbox-material" },
	{ "sainnhe/everforest" },
	{ "EdenEast/nightfox.nvim" },
	{ "olimorris/onedarkpro.nvim" },
	{ "marko-cerovac/material.nvim" },
	{ "rebelot/kanagawa.nvim" },
	{ "miikanissi/modus-themes.nvim" },
	{ "wtfox/jellybeans.nvim" },
	{ "e-ink-colorscheme/e-ink.nvim" },
	{ "ficcdaf/ashen.nvim" },
	{ "savq/melange-nvim" },
	{ "Skardyy/makurai-nvim" },
	{ "vague2k/vague.nvim" },
	{ "webhooked/kanso.nvim" },
	{ "zootedb0t/citruszest.nvim" },
	{ "folke/tokyonight.nvim" },
	{ "Mofiqul/dracula.nvim" },
	{ "shaunsingh/nord.nvim" },
	{ "craftzdog/solarized-osaka.nvim" },
	{ "nyoom-engineering/oxocarbon.nvim" },
	{ "catppuccin/nvim", name = "catppuccin" },
	{ "rose-pine/neovim", name = "rose-pine" },
	{ "projekt0n/github-nvim-theme", name = "github-theme" },

	-- plugins to provide nerdfont icons
	{
		"echasnovski/mini.icons",
		version = false,
		config = function()
			local mini_icons = require("mini.icons")
			mini_icons.setup({
				file = {
					[".go"] = { glyph = "󰟓", hl = "MiniIconsBlue" }, -- Go
					[".lua"] = { glyph = "󰢱", hl = "MiniIconsBlue" }, -- Lua
					[".py"] = { glyph = "󰌠", hl = "MiniIconsYellow" }, -- Python
					[".js"] = { glyph = "󰌞", hl = "MiniIconsYellow" }, -- JavaScript
					[".ts"] = { glyph = "󰛦", hl = "MiniIconsBlue" }, -- TypeScript
					[".xlsx"] = { glyph = "󰈛", hl = "MiniIconsGreen" }, -- Excel
					[".csv"] = { glyph = "󰈛", hl = "MiniIconsGreen" }, -- CSV
					[".md"] = { glyph = "󰍔", hl = "MiniIconsBlue" }, -- Markdown
					[".json"] = { glyph = "󰘦", hl = "MiniIconsYellow" }, -- JSON
					[".yaml"] = { glyph = "󰈼", hl = "MiniIconsOrange" }, -- YAML
					[".yml"] = { glyph = "󰈼", hl = "MiniIconsOrange" }, -- YAML
					[".toml"] = { glyph = "󰬷", hl = "MiniIconsOrange" }, -- TOML
					[".sh"] = { glyph = "󰐣", hl = "MiniIconsGreen" }, -- Shell script
					[".cpp"] = { glyph = "󰙲", hl = "MiniIconsBlue" }, -- C++
					[".c"] = { glyph = "󰙱", hl = "MiniIconsBlue" }, -- C
					[".rs"] = { glyph = "󱘗", hl = "MiniIconsRed" }, -- Rust
					[".java"] = { glyph = "󰬷", hl = "MiniIconsRed" }, -- Java
					[".html"] = { glyph = "󰌝", hl = "MiniIconsOrange" }, -- HTML
					[".css"] = { glyph = "󰌜", hl = "MiniIconsBlue" }, -- CSS
					[".rb"] = { glyph = "󰴭", hl = "MiniIconsRed" }, -- Ruby
					[".php"] = { glyph = "󰌟", hl = "MiniIconsPurple" }, -- PHP
					[".sql"] = { glyph = "󰆼", hl = "MiniIconsBlue" }, -- SQL
					[".Dockerfile"] = { glyph = "󰡨", hl = "MiniIconsBlue" }, -- Dockerfile
					[".gitignore"] = { glyph = "󰊢", hl = "MiniIconsGrey" }, -- Gitignore
				},
			})

			-- Compatibility fix for plugins expecting nvim-web-devicons
			mini_icons.mock_nvim_web_devicons()
			mini_icons.tweak_lsp_kind()
		end,
		lazy = false, -- Load immediately to ensure icons are available
		priority = 1000, -- High priority to load early
	},

	{
		"nvim-lualine/lualine.nvim",
		event = "BufRead",
		cond = firenvim_not_active,
		config = function()
			require("config.lualine")
		end,
	},

	{
		"akinsho/bufferline.nvim",
		event = { "BufEnter" },
		cond = firenvim_not_active,
		config = function()
			require("config.bufferline")
		end,
	},

	-- fancy start screen
	{
		"nvimdev/dashboard-nvim",
		cond = firenvim_not_active,
		config = function()
			require("config.dashboard-nvim")
		end,
	},

	{
		"echasnovski/mini.indentscope",
		version = false,
		config = function()
			local mini_indent = require("mini.indentscope")
			mini_indent.setup({
				draw = {
					animation = mini_indent.gen_animation.none(),
				},
				symbol = "▏",
			})
		end,
	},
	{
		"luukvbaal/statuscol.nvim",
		opts = {},
		config = function()
			require("config.nvim-statuscol")
		end,
	},
	{
		"kevinhwang91/nvim-ufo",
		dependencies = "kevinhwang91/promise-async",
		event = "VeryLazy",
		opts = {},
		init = function()
			vim.o.foldcolumn = "1" -- '0' is not bad
			vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
			vim.o.foldlevelstart = 99
			vim.o.foldenable = true
		end,
		config = function()
			require("config.nvim_ufo")
		end,
	},
	-- Highlight URLs inside vim
	{ "itchyny/vim-highlighturl", event = "BufReadPost" },

	-- notification plugin
	{
		"rcarriga/nvim-notify",
		event = "VeryLazy",
		config = function()
			require("config.nvim-notify")
		end,
	},

	{ "nvim-lua/plenary.nvim", lazy = true },

	-- For Windows and Mac, we can open an URL in the browser. For Linux, it may
	-- not be possible since we maybe in a server which disables GUI.
	{
		"chrishrb/gx.nvim",
		keys = { { "gx", "<cmd>Browse<cr>", mode = { "n", "x" } } },
		cmd = { "Browse" },
		init = function()
			vim.g.netrw_nogx = 1 -- disable netrw gx
		end,
		enabled = function()
			return vim.g.is_win or vim.g.is_mac
		end,
		config = true, -- default settings
		submodules = false, -- not needed, submodules are required only for tests
	},

	-- Only install these plugins if ctags are installed on the system
	-- show file tags in vim window
	{
		"liuchengxu/vista.vim",
		enabled = function()
			return utils.executable("ctags")
		end,
		cmd = "Vista",
	},

	
	-- Automatic insertion and deletion of a pair of characters
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = true,
	},

	-- Comment plugin
	{
		"tpope/vim-commentary",
		keys = {
			{ "gc", mode = "n" },
			{ "gc", mode = "v" },
		},
	},

	-- Multiple cursor plugin like Sublime Text?
	-- 'mg979/vim-visual-multi'

	-- Show undo history visually
	{ "simnalamburt/vim-mundo", cmd = { "MundoToggle", "MundoShow" } },

	-- Manage your yank history
	{
		"gbprod/yanky.nvim",
		config = function()
			require("config.yanky")
		end,
		cmd = "YankyRingHistory",
	},

	-- Handy unix command inside Vim (Rename, Move etc.)
	{ "tpope/vim-eunuch", cmd = { "Rename", "Delete" } },

	-- Repeat vim motions
	{ "tpope/vim-repeat", event = "VeryLazy" },

	{
		"lyokha/vim-xkbswitch",
		enabled = function()
			return vim.g.is_mac and utils.executable("xkbswitch")
		end,
		event = { "InsertEnter" },
	},

	{
		"Neur1n/neuims",
		enabled = function()
			return vim.g.is_win
		end,
		event = { "InsertEnter" },
	},

	-- Git command inside vim
	{
		"tpope/vim-fugitive",
		event = "User InGitRepo",
		config = function()
			require("config.fugitive")
		end,
	},
	{
		"NeogitOrg/neogit",
		dependencies = {
			"nvim-lua/plenary.nvim", -- required
			"sindrets/diffview.nvim", -- optional - Diff integration
			-- Only one of these is needed.
			"ibhagwan/fzf-lua", -- optional
		},
		event = "User InGitRepo",
	},

	-- Better git log display
	{ "rbong/vim-flog", cmd = { "Flog" } },
	{
		"akinsho/git-conflict.nvim",
		version = "*",
		event = "VeryLazy",
		config = function()
			require("config.git-conflict")
		end,
	},
	{
		"ruifm/gitlinker.nvim",
		event = "User InGitRepo",
		config = function()
			require("config.git-linker")
		end,
	},

	-- Show git change (change, delete, add) signs in vim sign column
	{
		"lewis6991/gitsigns.nvim",
		config = function()
			require("config.gitsigns")
		end,
		event = "BufRead",
	},

	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen" },
	},

	{
		"kevinhwang91/nvim-bqf",
		ft = "qf",
		config = function()
			require("config.bqf")
		end,
	},

	-- Faster footnote generation
	{ "vim-pandoc/vim-markdownfootnotes", ft = { "markdown" } },

	-- Vim tabular plugin for manipulate tabular, required by markdown plugins
	{ "godlygeek/tabular", ft = { "markdown" } },

	{ "chrisbra/unicode.vim", keys = { "ga" }, cmd = { "UnicodeSearch" } },

	-- Additional powerful text object for vim, this plugin should be studied
	-- carefully to use its full power
	{ "wellle/targets.vim", event = "VeryLazy" },

	-- Plugin to manipulate character pairs quickly
	{ "machakann/vim-sandwich", event = "VeryLazy" },

	-- Since tmux is only available on Linux and Mac, we only enable these plugins
	-- for Linux and Mac
	-- .tmux.conf syntax highlighting and setting check
	{
		"tmux-plugins/vim-tmux",
		enabled = function()
			return utils.executable("tmux")
		end,
		ft = { "tmux" },
	},

	-- Modern matchit implementation
	{ "andymass/vim-matchup", event = "BufRead" },
	{ "tpope/vim-scriptease", cmd = { "Scriptnames", "Messages", "Verbose" } },

	-- Asynchronous command execution
	{ "skywind3000/asyncrun.vim", lazy = true, cmd = { "AsyncRun" } },
	{ "cespare/vim-toml", ft = { "toml" }, branch = "main" },

	-- Session management plugin
	{ "tpope/vim-obsession", cmd = "Obsession" },

	{
		"ojroques/vim-oscyank",
		enabled = function()
			return vim.g.is_linux
		end,
		cmd = { "OSCYank", "OSCYankReg" },
	},

	-- showing keybindings
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		config = function()
			require("config.which-key")
		end,
	},
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			-- more beautiful vim.ui.input
			input = {
				enabled = true,
				win = {
					relative = "cursor",
					backdrop = true,
				},
			},
			-- more beautiful vim.ui.select
			picker = { enabled = true },
		},
	},
	-- show and trim trailing whitespaces
	{ "jdhao/whitespace.nvim", event = "VeryLazy" },

	-- file explorer
	{
		"nvim-tree/nvim-tree.lua",
		keys = { "<space>s" },
		config = function()
			require("config.nvim-tree")
		end,
	},

	{
		"j-hui/fidget.nvim",
		event = "BufRead",
		config = function()
			require("config.fidget-nvim")
		end,
	},
	{
		"folke/lazydev.nvim",
		ft = "lua", -- only load on lua files
		opts = {
			library = {
				-- See the configuration section for more details
				-- Load luvit types when the `vim.uv` word is found
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
	},
	{
		"smjonas/live-command.nvim",
		event = "VeryLazy",
		config = function()
			require("config.live-command")
		end,
	},
	{
		"Bekaboo/dropbar.nvim",
		event = "VeryLazy",
	},
	{
		"catgoose/nvim-colorizer.lua",
		event = "BufReadPre",
		opts = {},
	},

	-- Personal addition
	{
		"williamboman/mason.nvim",
		-- Removed `cmd` so it loads on startup as a dependency for other plugins.
		config = function()
			require("mason").setup()
			-- Ensure gofumpt is installed
			require("mason-registry").get_package("gofumpt"):install()
		end,
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-tool-installer").setup({
				ensure_installed = {
					"gofumpt",
					"stylua",
				},
				auto_update = true,
				run_on_start = true,
			})
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		-- This plugin is now a dependency of nvim-lspconfig, ensuring it loads first.
		config = function()
			require("mason-lspconfig").setup({
				-- A list of servers to automatically install if they're not already installed
				ensure_installed = { "lua_ls", "yamlls", "bashls", "pyright", "gopls", "html", "cssls" },
			})
		end,
	},
	-- Go development
	{
		"ray-x/go.nvim",
		dependencies = { -- Dependencies are optional, but recommended
			"ray-x/guihua.lua",
			"neovim/nvim-lspconfig",
			"nvim-treesitter/nvim-treesitter",
		},
		config = function()
			require("go").setup({
				diag_signs = false,
				diag_virtual_text = false,
				diag_underline = false,
				gofmt = "gofumpt", -- Use gofumpt for formatting
				run_in_floaterm = false, -- Optional: Run commands in a floating terminal
			})
			-- Set up autocommand to format Go files on save
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = vim.api.nvim_create_augroup("go_format_on_save", { clear = true }),
				pattern = { "*.go" },
				callback = function()
					require("go.format").gofmt()
				end,
				desc = "Format Go file with gofumpt on BufWritePre",
			})
		end,
		event = { "CmdlineEnter" },
		ft = { "go", "gomod" },
		build = ":GoUpdateBinaries",
	},
}

---@diagnostic disable-next-line: missing-fields
require("lazy").setup({
	spec = plugin_specs,
	ui = {
		border = "rounded",
		title = "Plugin Manager",
		title_pos = "center",
	},
	rocks = {
		enabled = false,
		hererocks = false,
	},
})
