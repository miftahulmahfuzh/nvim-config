-- /home/devmiftahul/.config/nvim/lua/config/treesitter.lua

require("nvim-treesitter.configs").setup {
  ensure_installed = { "go", "markdown", "python", "http", "cpp", "lua", "vim", "json", "toml" },
  ignore_install = {}, -- List of parsers to ignore installing
  highlight = {
    enable = true, -- false will disable the whole extension
    disable = { "help" }, -- list of language that will be disabled
  },
}
