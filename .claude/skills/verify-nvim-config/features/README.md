# Feature map: verify-nvim-config

One file per feature the owner touches. Each file holds proven recipes and the end states they
produced on 2026-11-04, on Neovim 0.12.6 (checkout `feature/nvim-0-12-clean` after phases 1-4 of
nvim-0-12-clean; live `9cea538`), in both `up` and `up --live`. No drive costs money and none
goes online. After every journey the sweep read `lua/noise.lua` (`noise=0`), and full
`:checkhealth` minus the allow-list in [health.md](health.md) was empty, both with gopls attached
and with every plugin loaded.

| Feature | File | Surfaces | Known on the base (`8bcb55c`) |
|---|---|---|---|
| Startup and run modes | [startup.md](startup.md) | `up`, `sync`, `doctor`, `lua`, `headless` | fixed: `sync` respawned nvim with the caller's PATH (R1; doctor now has a `path` line); `v:errmsg` held `E216: No such group or event: FileExplorer *` after startup (R5) |
| Dashboard / ASCII art | [dashboard.md](dashboard.md) | `keys`, `lua @dashboard_art.lua` | none |
| Format and check on save | [format-on-save.md](format-on-save.md) | `keys`, `cli git diff`, `lua` | none |
| LSP | [lsp.md](lsp.md) | `keys`, `wait`, `lsp.log`, `lua @deprecations.lua` | fixed: `client.request is deprecated` on completion (R2, blink.cmp v1.10.2); CursorHold float "Invalid 'width'" in a 2-column window (R3); fidget's implicit nvim-tree integration |
| Treesitter | [treesitter.md](treesitter.md) | `keys`, `lua` | none |
| Editing mappings (incl. hop `f`/`F`) | [editing-mappings.md](editing-mappings.md) | `keys`, `lua`, `screen` | none |
| fzf-lua pickers | [fzf-lua.md](fzf-lua.md) | `keys`, `wait` | none |
| Git mappings (incl. git-conflict) | [git.md](git.md) | `keys`, `cli git`, `lua @deprecations.lua` | fixed: git-conflict.nvim's `vim.highlight` / `vim.validate{}` deprecations (R4, `stryukovsky` fork `63c5b42`) |
| tmux bindings (incl. true colour) | [tmux-bindings.md](tmux-bindings.md) | `tmux`, `panes`, `lua` | fixed: no true colour in tmux (`tmux_conf_24b_colour=auto`, no `COLORTERM`) |
| img2braille | [img2braille.md](img2braille.md) | `cli`, `keys`, `lua` | none |
| Health and the sweep | [health.md](health.md) | `keys`, `lua @health_diff.lua`, `@noise.lua`, `@load_all.lua` | fixed: render-markdown `latex`/`yaml` warnings; recorded: the allow-list (incl. go.nvim's `vim.lsp.codelens.refresh` and glance.nvim's `vim.validate{}` deprecations, fixed upstream, not moved here), `E31` in `v:errmsg` on markdown buffers (upstream) |
| Live environment | [live-environment.md](live-environment.md) | `up --live`, `live`, `doctor` | live lags this set until Deploy (`blink.cmp`, `git-conflict.nvim` replaced from seed; `~/.tmux.conf.local` differs) |

A change to what a feature does updates its file in the same change. A new `:checkhealth`
WARNING/ERROR, or a new line from `noise.lua`, is either fixed or recorded in health.md with its
reason.
