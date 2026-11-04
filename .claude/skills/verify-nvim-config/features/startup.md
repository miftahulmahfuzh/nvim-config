# Startup and run modes

## Sub-features

- `init.lua`: version check (expects 0.11.5), globals (leader `,`, python3 required), options,
  autocmds, mappings, lazy.nvim with 93 plugin specs, diagnostics, a random colorscheme.
- Mason (`mason.nvim`, mason-tool-installer for `gofumpt`/`stylua`, mason-lspconfig's
  `ensure_installed`), plus an unconditional `get_package("gofumpt"):install()` on every start.
- Three run modes: seeded, `--live`, `--bare`.

## How to get to it (user POV)

Type `nvim` in a tmux pane with no file: the dashboard appears, plugins load lazily, nothing is
printed in red.

## Driving it with verify.sh

```sh
$V up                      # MODE=seeded, ~1 s
$V doctor RUN              # all ok; "messages ok   no errors in :messages"
$V lua RUN '{ loaded = require("lazy").stats().loaded, count = require("lazy").stats().count, ms = math.floor(require("lazy").stats().startuptime), leader = vim.g.mapleader, colors = vim.g.colors_name }'
```

End state seen: `count = 93, loaded = 63, ms = 171, leader = ","` and a colorscheme name from
`colorschemes.lua` (random: `kanso`, then `citruszest` on the next start).

Mason's startup install with no network:

```sh
$V headless RUN +'lua io.stdout:write(tostring(require("lazy").stats().count), "\n")'
grep gofumpt ~/.local/state/nvim-config-verify/RUN/xdg/state/nvim/mason.log
```

End state seen: `93`, then `[mason.nvim] Neovim exited while the following packages were
installing. Installation was aborted. - gofumpt`. `mason.log` shows `Executing installer for
Package(name=gofumpt)` on every start (a `go install mvdan.cc/gofumpt@v0.12.0`). The installed
`mason/bin/gofumpt` stays, because Mason stages installs.

Fault injection (fresh machine, no network):

```sh
$V up --bare               # MODE=bare; no "startup :messages contain errors"
cat EVIDENCE/00-up-messages.txt
$V lua RUN '{ colors = vim.g.colors_name, underline = vim.diagnostic.config().underline, severity_sort = vim.diagnostic.config().severity_sort, leader = vim.g.mapleader, save = vim.fn.maparg("<leader>w", "n"), lazy = package.loaded.lazy ~= nil, lazy_dir = vim.fn.isdirectory(vim.fn.stdpath("data") .. "/lazy/lazy.nvim") }'
$V doctor RUN
```

End state seen: `00-up-messages.txt` holds one line (WarningMsg): `lazy.nvim clone failed (git exit
128): plugins off until an online restart`. The Lua table is `colors = "habamax", underline = false,
severity_sort = true, leader = ",", save = "<Cmd>update<CR>", lazy = false, lazy_dir = 0`, which means
diagnostic-conf ran, the builtin fallback colorscheme is active, mappings are in place, and the partial
clone was deleted. The screen shows a `[No Name]` buffer and no dashboard (the dashboard is a plugin).
`doctor` reports `nvim info --bare run: 1` and `messages ok   no errors in :messages`.
The warning shows on the command line at start, but the harness's client attach resizes the pane
and the redraw can clear it, so read `00-up-messages.txt`, not the screen.

A `lazy.nvim` dir that exists but cannot load (an old interrupted clone):

```sh
mkdir -p ~/.local/state/nvim-config-verify/RUN/xdg/data/nvim/lazy/lazy.nvim
$V headless RUN +'lua io.stdout:write(vim.fn.execute("messages"), "\n", tostring(vim.g.colors_name), "\n")' +qa
```

End state seen: `lazy.nvim not loadable: plugins off until you delete <run>/xdg/data/nvim/lazy/lazy.nvim
and restart online`, then `habamax`, with no traceback.

## Gotchas

- Product finding (base): `plugin_specs.lua:527` calls `get_package("gofumpt"):install()` in
  mason's `config` on every start. With network, that is a download plus `go install` per nvim
  launch (Go may first fetch a 1.26 toolchain), and quitting fast aborts it with the message above.
  `mason-tool-installer` already ensures gofumpt.
- With lazy.nvim missing, `plugin_specs.lua` returns before the spec table: no plugin command
  exists (`:Lazy`, `:Mason`, `:FzfLua`), and `colorschemes.lua` falls back to `habamax` without a
  second message. With lazy loaded, a plugin scheme that fails also falls back to `habamax`, but warns
  with the scheme name and its error. `verify.sh sync` cannot restart a bare run (it waits for
  fzf-lua). Use `down`, then `up --bare` again.
- Never assert the colorscheme name on a seeded or `--live` run: `utils.rand_int` seeds with
  `os.time()`. On `--bare` it is always `habamax` (the builtin fallback).
- `loaded` counts depend on what the dashboard and VeryLazy pulled in; assert `count`, not
  `loaded`.
