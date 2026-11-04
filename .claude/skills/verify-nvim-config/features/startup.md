# Startup and run modes

## Sub-features

- `init.lua`: version check (expects 0.12.6), globals (leader `,`, python3 required), options,
  autocmds, mappings, lazy.nvim with 93 plugin specs, diagnostics, a random colorscheme.
- Mason (`mason.nvim`, mason-tool-installer for `gofumpt`/`stylua`/`tree-sitter-cli` with
  `auto_update` and `run_on_start`, mason-lspconfig's `ensure_installed`). A start where every tool
  is installed and matches the registry's version installs nothing.
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

Mason at startup with no network (nothing reinstalls):

```sh
$V headless RUN +'lua local r = require("mason-registry"); local t = {}; for _, n in ipairs { "gofumpt", "stylua" } do if r.get_package(n):is_installing() then t[#t + 1] = n end end; io.stdout:write("installing=", table.concat(t, ","), "\n")'
cat ~/.local/state/nvim-config-verify/RUN/xdg/state/nvim/mason.log 2>/dev/null | grep -c 'Executing installer for Package(name=gofumpt)'
```

End state seen: `installing=` (empty), no `Neovim exited while the following packages were
installing` line, and the grep prints `0`. `mason.log` still carries the offline registry-refresh
ERRORs (`Failed to update registries`) whenever the cached registry is due for a refresh. Those come
from `mason-registry.refresh()`, called by mason-tool-installer and mason-lspconfig, not from an
install. Seeded run `1104-113158-2349813`: one `Failed to update registries` line after 15 s, and
`mason/bin/gofumpt` still present.

mason-tool-installer still ensures a missing gofumpt (`--live` only, because live Mason files are
copies; never delete from a seeded run, whose files are hard links into the seed):

```sh
$V up --live                                    # note RUN and EVIDENCE
D=$(dirname "$EVIDENCE")
rm -rf "$D/xdg/data/nvim/mason/packages/gofumpt" "$D/xdg/data/nvim/mason/bin/gofumpt"
$V sync RUN
$V wait RUN 'vim.fn.join(vim.fn.readfile(vim.fn.stdpath("state") .. "/mason.log"), "\n"):find("Installation failed for Package%(name=gofumpt%)") ~= nil' true 60
$V lua RUN 'vim.inspect(vim.tbl_map(function(n) return n.message end, require("notify").history()))'
```

End state seen: `mason.log` gains one `Executing installer for Package(name=gofumpt)` then
`Installation failed for Package(name=gofumpt)` (offline: `go` cannot fetch `mvdan.cc/gofumpt`), and
the notify history is `{ { "gofumpt: installing" }, { "gofumpt: failed to install" } }` (nvim-notify,
not `:messages`, which stays empty). With network, the install succeeds. Live run
`1104-113258-2368613`.

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

### Deleted working directory

When nvim's cwd is deleted, either before nvim starts or while it runs (for example a git worktree
removed under it), `uv.cwd()` returns nil and `vim.fs.abspath()` asserts. On the base, dropbar →
mini.icons → `vim.filetype.match` then printed `vim.schedule callback: vim/fs:837: assertion failed!`
and a Press ENTER prompt for every new file name. `ensure_cwd` in `lua/custom-autocmd.lua` runs at
startup and on cursor/buffer/focus events, and moves nvim to the nearest directory that still exists:

```sh
$V keys RUN : e Space sample.lua Enter
$V lua RUN 'vim.fn.mkdir(vim.uv.cwd() .. "/gone", "p"); vim.cmd.cd(vim.uv.cwd() .. "/gone"); vim.fn.delete(vim.uv.cwd(), "rf"); return tostring(vim.uv.cwd())'   # nil
$V keys RUN : e Space <WORK>/claude-prompt-1234.md Enter   # absolute path: a name mini.icons has not cached
$V keys RUN i x Escape j k
$V lua RUN 'vim.uv.cwd() .. " | " .. vim.bo.filetype'       # "<WORK> | markdown"
$V lua RUN 'vim.inspect(vim.tbl_map(function(n) return n.message end, require("notify").history()))'
```

End state seen (0.12.6, seeded and `--live`, 2026-11-04): no assertion on screen or in `:messages`,
cwd back at `<WORK>`, filetype `markdown`, one nvim-notify WARN `working directory <WORK>/gone was
deleted, now in <WORK>`, doctor exits 0. The startup case, `nvim` launched from a removed directory,
ends the same way. It goes to the nearest existing parent, or `/`.

## Gotchas

- gofumpt and stylua are kept by mason-tool-installer alone (`auto_update = true`,
  `run_on_start = true`). On VimEnter it refreshes the registry, installs a missing tool, and
  reinstalls an installed one only when the registry's latest version differs from the installed
  one. Online that happens once per upstream release; offline it compares against the cached
  registry, so nothing installs. It never runs in `nvim --headless -c ...` before VimEnter, which
  is why the seed installs every Mason tool itself. (Before `perf(mason)`, mason's `config` also
  ran `get_package("gofumpt"):install()` on every start: a `go install` per launch.)
- With lazy.nvim missing, `plugin_specs.lua` returns before the spec table: no plugin command
  exists (`:Lazy`, `:Mason`, `:FzfLua`), and `colorschemes.lua` falls back to `habamax` without a
  second message. With lazy loaded, a plugin scheme that fails also falls back to `habamax`, but warns
  with the scheme name and its error. `verify.sh sync` cannot restart a bare run (it waits for
  fzf-lua). Use `down`, then `up --bare` again.
- Never assert the colorscheme name on a seeded or `--live` run: `utils.rand_int` seeds with
  `os.time()`. On `--bare` it is always `habamax` (the builtin fallback).
- `loaded` counts depend on what the dashboard and VeryLazy pulled in; assert `count`, not
  `loaded`.
