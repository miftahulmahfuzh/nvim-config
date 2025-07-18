-- /home/devmiftahul/.config/nvim/lua/colorschemes.lua

--- This module will load a random colorscheme on nvim startup process.
local utils = require("utils")

local M = {}

-- Colorscheme to its directory name mapping, because colorscheme repo name is not necessarily
-- the same as the colorscheme name itself.
M.colorscheme_conf = {
	onedark = function()
		-- Lua
		require("onedark").setup({
			style = "darker",
		})
		require("onedark").load()
	end,
	edge = function()
		vim.g.edge_style = "default"
		vim.g.edge_enable_italic = 1
		vim.g.edge_better_performance = 1

		vim.cmd([[colorscheme edge]])
	end,
	sonokai = function()
		vim.g.sonokai_enable_italic = 1
		vim.g.sonokai_better_performance = 1

		vim.cmd([[colorscheme sonokai]])
	end,
	gruvbox_material = function()
		-- foreground option can be material, mix, or original
		vim.g.gruvbox_material_foreground = "original"
		--background option can be hard, medium, soft
		vim.g.gruvbox_material_background = "hard"
		vim.g.gruvbox_material_enable_italic = 1
		vim.g.gruvbox_material_better_performance = 1

		vim.cmd([[colorscheme gruvbox-material]])
	end,
	everforest = function()
		vim.g.everforest_background = "hard"
		vim.g.everforest_enable_italic = 1
		vim.g.everforest_better_performance = 1

		vim.cmd([[colorscheme everforest]])
	end,
	nightfox = function()
		vim.cmd([[colorscheme carbonfox]])
	end,
	onedarkpro = function()
		-- set colorscheme after options
		-- onedark_vivid does not enough contrast
		vim.cmd("colorscheme onedark_dark")
	end,
	material = function()
		vim.g.material_style = "darker"
		vim.cmd("colorscheme material")
	end,
	kanagawa = function()
		vim.cmd("colorscheme kanagawa-dragon")
	end,
	modus = function()
		vim.cmd([[colorscheme modus]])
	end,
	jellybeans = function()
		vim.cmd([[colorscheme jellybeans]])
	end,
	github = function()
		vim.cmd([[colorscheme github_dark_default]])
	end,
	e_ink = function()
		require("e-ink").setup()
		vim.cmd.colorscheme("e-ink")
	end,
	ashen = function()
		vim.cmd([[colorscheme ashen]])
	end,
	melange = function()
		vim.cmd([[colorscheme melange]])
	end,
	makurai = function()
		vim.cmd.colorscheme("makurai_dark")
	end,
	vague = function()
		vim.cmd([[colorscheme vague]])
	end,
	kanso = function()
		vim.cmd([[colorscheme kanso]])
	end,
	citruszest = function()
		vim.cmd([[colorscheme citruszest]])
	end,

	-- >>> New colorschemes added here <<<
	tokyonight = function()
		require("tokyonight").setup({
			style = "storm", -- available: storm, night, moon, day
		})
		vim.cmd.colorscheme("tokyonight")
	end,
	rose_pine = function()
		require("rose-pine").setup({
			variant = "main", -- available: main, moon, dawn
		})
		vim.cmd.colorscheme("rose-pine")
	end,
	dracula = function()
		-- dracula is a classic and typically doesn't need a setup call
		vim.cmd([[colorscheme dracula]])
	end,
	nord = function()
		vim.cmd([[colorscheme nord]])
	end,
	solarized_osaka = function()
		require("solarized-osaka").setup({
			style = "night", -- available: night, day
		})
		vim.cmd.colorscheme("solarized-osaka")
	end,
	oxocarbon = function()
		vim.cmd([[colorscheme oxocarbon]])
	end,
	-- >>> End of new colorschemes <<<

	-- Added catppuccin configuration
	catppuccin = function()
		require("catppuccin").setup({
			flavour = "mocha", -- latte, frappe, macchiato, mocha
		})
		vim.cmd.colorscheme("catppuccin")
	end,
}

--- Use a random colorscheme from the pre-defined list of colorschemes.
M.rand_colorscheme = function()
	local colorscheme = utils.rand_element(vim.tbl_keys(M.colorscheme_conf))

	-- Load the colorscheme and its settings
	M.colorscheme_conf[colorscheme]()
end

return M
