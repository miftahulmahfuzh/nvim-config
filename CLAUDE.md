# Neovim Configuration

This is a cross-platform Neovim configuration using Lua and Lazy.nvim for plugin management.

## Quick Reference

- **Plugin Manager**: Lazy.nvim
- **LSP Manager**: Mason.nvim
- **Auto-completion**: blink.cmp
- **Leader Key**: `,`
- **Config Entry**: `init.lua`
- **Plugin Specs**: `lua/plugin_specs.lua`

## Structure

```
├── init.lua                 # Main entry point
├── ginit.vim               # GUI settings
├── lua/
│   ├── config/             # Plugin configs (lsp.lua, treesitter.lua, etc.)
│   ├── plugin_specs.lua    # Plugin declarations
│   ├── mappings.lua        # Key mappings
│   ├── globals.lua         # Global settings
│   └── utils.lua           # Utility functions
├── viml_conf/              # VimScript configs
├── ftdetect/               # File type detection
├── plugin/                 # Plugin scripts
├── my_snippets/            # Custom snippets
└── after/                  # Post-load configs
```

## Plugin Management

Plugins are defined in `lua/plugin_specs.lua` using Lazy.nvim spec format:

```lua
{
  "author/plugin",
  event = "VeryLazy",      -- or ft, cmd, keys
  dependencies = { ... },
  config = function()
    require("config.plugin").setup()
  end,
}
```

Plugins install to `~/.local/share/nvim/lazy/` and are version-locked in `lazy-lock.json`.

## Key Mappings

Leader key: `,`

Common mappings:
- `<leader>w` - Save
- `<leader>q` - Quit
- `<leader>d` - Close buffer
- `<leader>ev` - Edit init.lua
- `<leader>sv` - Source init.lua

## LSP Setup

Language servers are configured in `lua/config/lsp.lua` and managed via Mason. Supported languages include:
- Lua (lua_ls)
- Python (pyright)
- Go (gopls)
- HTML/CSS (html, cssls)
- YAML (yamlls)
- Bash (bashls)

Add new LSPs by configuring them in `lsp.lua` and installing via `:Mason`.

## Language-Specific Notes

### Go
- Formatter: gofumpt
- Auto-format on save: enabled
- LSP: gopls via go.nvim

### Python
- LSP: pyright
- Treesitter parser enabled

### Web
- HTML/CSS: LSP + Treesitter
- Markdown: render-markdown.nvim for rendering

## Customization

### Add a plugin
Edit `lua/plugin_specs.lua` with the plugin spec.

### Change keymaps
Edit `lua/mappings.lua`.

### Add LSP server
1. Install via `:Mason`
2. Configure in `lua/config/lsp.lua`

### Modify colorscheme
Edit `lua/colorschemes.lua` (currently random on startup).

## Utilities

### Key files
- `lua/utils.lua` - Helper functions
- `lua/lsp_utils.lua` - LSP utilities
- `lua/diagnostic-conf.lua` - Diagnostic settings

### Autocommands
Custom autocmds in `lua/custom-autocmd.lua` and `plugin/` directory.

> [!IMPORTANT]

> when user type in "p" : you must git add . commit push in a new subagent. USE haiku model for this task.

> when user type in "s" : you must summarize what you just did in the current session into a concise task item in the most appropriate todos.md file in this codebase. put it in Completed Tasks section . do it in new subagent. USE haiku model for this task.

