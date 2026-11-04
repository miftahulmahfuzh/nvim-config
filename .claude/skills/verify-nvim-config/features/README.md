# Feature map: verify-nvim-config

One file per feature the owner touches. Each has proven recipes and the end states they produced
on 2026-11-04 (checkout `24ff768`, live `d7bf9fe`). No drive costs money; none goes online.

| Feature | File | Surfaces | Known on the base |
|---|---|---|---|
| Startup and run modes | [startup.md](startup.md) | `up`, `doctor`, `lua`, `headless` | gofumpt reinstalled on every start; `--bare` dies at `require("lazy")` |
| Dashboard / ASCII art | [dashboard.md](dashboard.md) | `keys`, `lua @dashboard_art.lua` | `,bg` on the start screen does not redraw |
| Format and check on save | [format-on-save.md](format-on-save.md) | `keys`, `cli git diff`, `lua` | **stylua error text replaces a Lua file with a syntax error** |
| LSP | [lsp.md](lsp.md) | `keys`, `wait`, `lsp.log` | **pyright never starts** (`delance-langserver`) |
| Editing mappings | [editing-mappings.md](editing-mappings.md) | `keys`, `lua` | |
| fzf-lua pickers | [fzf-lua.md](fzf-lua.md) | `keys`, `wait` | |
| Git mappings | [git.md](git.md) | `keys`, `cli git` | |
| tmux bindings | [tmux-bindings.md](tmux-bindings.md) | `tmux`, `panes` | |
| img2braille | [img2braille.md](img2braille.md) | `cli`, `keys`, `lua` | |
| Live environment | [live-environment.md](live-environment.md) | `up --live`, `live`, `doctor` | live lags 4 commits |

A change to what a feature does updates its file in the same change.
