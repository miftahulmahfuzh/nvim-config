# Feature map: verify-nvim-config

One file per feature the owner touches. Each has proven recipes and the end states they produced
on 2026-11-04 on Neovim 0.12.6 (checkout `43009df` plus phase 9's change, live `a14aef9`), in both `up` and `up --live`. No drive
costs money; none goes online.

| Feature | File | Surfaces | Known on the base |
|---|---|---|---|
| Startup and run modes | [startup.md](startup.md) | `up`, `doctor`, `lua`, `headless` | none (fixed: per-start gofumpt reinstall, `--bare` E5113, version warning on 0.12.6) |
| Dashboard / ASCII art | [dashboard.md](dashboard.md) | `keys`, `lua @dashboard_art.lua` | none (fixed: `,bg`/`,bv`/`,bh` redraw the start screen) |
| Format and check on save | [format-on-save.md](format-on-save.md) | `keys`, `cli git diff`, `lua` | none (fixed: stylua error text no longer replaces the file) |
| LSP | [lsp.md](lsp.md) | `keys`, `wait`, `lsp.log` | none (fixed: pyright attaches) |
| Treesitter | [treesitter.md](treesitter.md) | `keys`, `lua` | none (fixed: `vaf` E5108 on 0.12; nvim-treesitter pinned to `main`) |
| Editing mappings (incl. hop `f`/`F`) | [editing-mappings.md](editing-mappings.md) | `keys`, `lua`, `screen` | none (fixed: hop from `smoka7/hop.nvim`; `phaazon/hop.nvim` is gone) |
| fzf-lua pickers | [fzf-lua.md](fzf-lua.md) | `keys`, `wait` | none (opencode removed) |
| Git mappings | [git.md](git.md) | `keys`, `cli git` | |
| tmux bindings | [tmux-bindings.md](tmux-bindings.md) | `tmux`, `panes` | |
| img2braille | [img2braille.md](img2braille.md) | `cli`, `keys`, `lua` | |
| Live environment | [live-environment.md](live-environment.md) | `up --live`, `live`, `doctor` | live lags this set until Deploy (binary, 4 plugins, parsers) |

A change to what a feature does updates its file in the same change.
