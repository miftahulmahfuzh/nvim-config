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
$V up --bare               # prints the startup errors, MODE=bare
```

End state seen: `E5113: ... plugin_specs.lua:587: module 'lazy' not found`, the dashboard absent,
`[No Name]` buffer. `doctor` reports `nvim info --bare run: 1`.

## Gotchas

- Product finding (base): `plugin_specs.lua:527` calls `get_package("gofumpt"):install()` in
  mason's `config` on every start. With network, that is a download plus `go install` per nvim
  launch (Go may first fetch a 1.26 toolchain), and quitting fast aborts it with the message above.
  `mason-tool-installer` already ensures gofumpt.
- Product finding (base): the lazy bootstrap (`vim.fn.system { "git", "clone", ... }`) never
  checks the result, so an offline first start dies with E5113 and skips the rest of `init.lua`.
- Never assert the colorscheme name: `utils.rand_int` seeds with `os.time()`.
- `loaded` counts depend on what the dashboard and VeryLazy pulled in; assert `count`, not
  `loaded`.
