-- /home/devmiftahul/.config/nvim/lua/plugin_specs.lua

local utils = require("utils")

local plugin_dir = vim.fn.stdpath("data") .. "/lazy"
local lazypath = plugin_dir .. "/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

-- check if firenvim is active
local firenvim_not_active = function()
  return not vim.g.started_by_firenvim
end

local plugin_specs = {
  -- auto-completion engine
  { "hrsh7th/cmp-nvim-lsp", lazy = true },
  { "hrsh7th/cmp-path", lazy = true },
  { "hrsh7th/cmp-buffer", lazy = true },
  { "hrsh7th/cmp-omni", lazy = true },
  { "hrsh7th/cmp-cmdline", lazy = true },
  { "quangnguyen30192/cmp-nvim-ultisnips", lazy = true },
  {
    "hrsh7th/nvim-cmp",
    name = "nvim-cmp",
    event = "VeryLazy",
    config = function()
      require("config.nvim-cmp")
    end,
  },
  -- {
  --   "saghen/blink.cmp",
  --   -- optional: provides snippets for the snippet source
  --   dependencies = { "rafamadriz/friendly-snippets" },
  --   -- use a release tag to download pre-built binaries
  --   version = "1.*",
  --   config = function()
  --     require("config.blink-cmp")
  --   end,
  --   opts_extend = { "sources.default" },
  -- },
  {
    "neovim/nvim-lspconfig",
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

  -- IDE for Lisp
  -- 'kovisoft/slimv'
  {
    "vlime/vlime",
    enabled = function()
      return utils.executable("sbcl")
    end,
    config = function(plugin)
      vim.opt.rtp:append(plugin.dir .. "/vim")
    end,
    ft = { "lisp" },
  },

  -- Super fast buffer jump
  {
    "smoka7/hop.nvim",
    keys = { "f" },
    config = function()
      require("config.nvim_hop")
    end,
  },

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
  {
    "MeanderingProgrammer/markdown.nvim",
    main = "render-markdown",
    opts = {},
    ft = { "markdown" },
  },
  -- A list of colorscheme plugin you may want to try. Find what suits you.
  { "navarasu/onedark.nvim", lazy = true },
  { "sainnhe/edge", lazy = true },
  { "sainnhe/sonokai", lazy = true },
  { "sainnhe/gruvbox-material", lazy = true },
  { "sainnhe/everforest", lazy = true },
  { "EdenEast/nightfox.nvim", lazy = true },
  { "catppuccin/nvim", name = "catppuccin", lazy = true },
  { "olimorris/onedarkpro.nvim", lazy = true },
  { "marko-cerovac/material.nvim", lazy = true },
  {
    "rockyzhang24/arctic.nvim",
    dependencies = { "rktjmp/lush.nvim" },
    name = "arctic",
    branch = "v2",
  },
  { "rebelot/kanagawa.nvim", lazy = true },
  { "miikanissi/modus-themes.nvim", lazy = true},
  { "wtfox/jellybeans.nvim", lazy = true},
  { "projekt0n/github-nvim-theme", name = "github-theme", lazy = true},
  { "e-ink-colorscheme/e-ink.nvim", lazy = true},
  { "ficcdaf/ashen.nvim", lazy = true},
  { "savq/melange-nvim", lazy = true},
  { "Skardyy/makurai-nvim", lazy = true},
  { "vague2k/vague.nvim", lazy = true},
  { "webhooked/kanso.nvim", lazy = true},
  { "zootedb0t/citruszest.nvim", lazy = true},

  -- plugins to provide nerdfont icons
  {
    "echasnovski/mini.icons",
    version = false,
    config = function()
      -- this is the compatibility fix for plugins that only support nvim-web-devicons
      require("mini.icons").mock_nvim_web_devicons()
      require("mini.icons").tweak_lsp_kind()
    end,
    lazy = true,
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
      mini_indent.setup {
        draw = {
          animation = mini_indent.gen_animation.none(),
        },
        symbol = "▏",
      }
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

  -- Snippet engine and snippet template
  {
    "SirVer/ultisnips",
    dependencies = {
      "honza/vim-snippets",
    },
    event = "InsertEnter",
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

  -- Markdown previewing (only for Mac and Windows)
  {
    "iamcco/markdown-preview.nvim",
    enabled = function()
      return vim.g.is_win or vim.g.is_mac
    end,
    build = "cd app && npm install && git restore .",
    ft = { "markdown" },
  },

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

  -- Edit text area in browser using nvim
  {
    "glacambre/firenvim",
    enabled = function()
      return vim.g.is_win or vim.g.is_mac
    end,
    -- it seems that we can only call the firenvim function directly.
    -- Using vim.fn or vim.cmd to call this function will fail.
    build = function()
      local firenvim_path = plugin_dir .. "/firenvim"
      vim.opt.runtimepath:append(firenvim_path)
      vim.cmd("runtime! firenvim.vim")

      -- macOS will reset the PATH when firenvim starts a nvim process, causing the PATH variable to change unexpectedly.
      -- Here we are trying to get the correct PATH and use it for firenvim.
      -- See also https://github.com/glacambre/firenvim/blob/master/TROUBLESHOOTING.md#make-sure-firenvims-path-is-the-same-as-neovims
      local path_env = vim.env.PATH
      local prologue = string.format('export PATH="%s"', path_env)
      -- local prologue = "echo"
      local cmd_str = string.format(":call firenvim#install(0, '%s')", prologue)
      vim.cmd(cmd_str)
    end,
  },
  -- Debugger plugin
  {
    "sakhnik/nvim-gdb",
    enabled = function()
      return vim.g.is_win or vim.g.is_linux
    end,
    build = { "bash install.sh" },
    lazy = true,
  },

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
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false, -- Never set this value to "*"! Never!
    opts = {
      provider = "openai",
      auto_suggestions_provider = "openai",
      providers = {
        openai = {
          -- endpoint = "https://api.openai.com/v1",
          -- model = "gpt-4o-mini",
          endpoint = "https://api.deepseek.com/v1",
          model = "deepseek-chat",
          timeout = 30000, -- Timeout in milliseconds, increase this for reasoning models
          extra_request_body = {
            temperature = 0,
            -- max_completion_tokens = 16384, -- for gpt-4o-mini
            max_completion_tokens = 128000, -- for gpt-4o-mini
          }
        },
      }
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "echasnovski/mini.pick", -- for file_selector provider mini.pick
      "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
      "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
      "ibhagwan/fzf-lua", -- for file_selector provider fzf
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    },
    web_search_engine = {
      provider = "tavily", -- tavily, serpapi, searchapi, google, kagi, brave, or searxng
      proxy = nil, -- proxy support, e.g., http://127.0.0.1:7890
    },
  },
  {
    "smjonas/live-command.nvim",
    -- live-command supports semantic versioning via Git tags
    -- tag = "2.*",
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
    opts = { -- set to setup table
    },
  },

  -- Personal addition
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
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
          "gofumpt", -- Add gofumpt here
        },
        auto_update = true,
        run_on_start = true,
      })
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    -- This plugin makes sure that your lspconfig is aware of servers installed with mason
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("mason-lspconfig").setup({
        -- A list of servers to automatically install if they're not already installed
        ensure_installed = { "lua_ls", "yamlls", "bashls", },
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
      -- Set up autocommand to format and save Go files
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("go_format_on_save", { clear = true }),
        pattern = { "*.go" },
        callback = function()
          -- Run gofmt (using gofumpt as configured)
          require("go.format").gofmt()
          -- Ensure the file is saved after formatting
          vim.cmd("write")
        end,
        desc = "Format Go file with gofumpt and save on BufWritePre",
      })
    end,
    event = { "CmdlineEnter" },
    ft = { "go", "gomod" },
    build = ":GoUpdateBinaries",
  },
}

---@diagnostic disable-next-line: missing-fields
require("lazy").setup {
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
}
