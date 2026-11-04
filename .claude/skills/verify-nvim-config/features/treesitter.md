# Treesitter

## Sub-features

- nvim-treesitter **`main`** (pinned with `branch = "main"`, `lazy = false`): installs 13 parsers
  (python, http, cpp, lua, vim, json, toml, markdown, markdown_inline, html, css, javascript, go,
  plus their dependencies c, html_tags, ecma, jsx) into `stdpath("data")/site`. Compiling needs the
  `tree-sitter` CLI from Mason (`tree-sitter-cli` in mason-tool-installer).
- Highlighting: `vim.treesitter.start()` on every FileType with an installed parser (not `help`);
  markdown keeps Vim's regex syntax too.
- Indentation: `indentexpr = v:lua.require'nvim-treesitter'.indentexpr()` where the language has
  an `indents` query, except yaml.
- Textobjects (nvim-treesitter-textobjects `main`): `af`/`if`/`ac`/`ic` in Visual and
  operator-pending mode, linewise.
- Incremental selection on Neovim 0.12's built-in: `gnn` (Normal) starts, `grn` (Visual) grows,
  `grm` (Visual) shrinks. `grc` is gone. Normal `grn` is still LSP rename. Neovim's own Visual
  `an`/`in`/`]n`/`[n` work too.

## How to get to it (user POV)

Open a source file: it is coloured. `vaf` selects the function around the cursor; `gnn` then `grn`
grows a selection node by node; `==` re-indents a line.

## Driving it with verify.sh

```sh
$V keys RUN : e Space app.py Enter
$V lua RUN 'vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil'   # true
$V lua RUN 'vim.bo.indentexpr'          # v:lua.require'nvim-treesitter'.indentexpr()
$V keys RUN g g v a f
$V lua RUN '{ vim.fn.mode(), vim.fn.line("v"), vim.fn.line(".") }'   # { "V", 1, 2 }
$V keys RUN Escape Escape
$V keys RUN 2 G 0 w w g n n             # cursor on `sum`
$V lua RUN '{ vim.fn.mode(), vim.fn.line("v"), vim.fn.col("v"), vim.fn.line("."), vim.fn.col(".") }'   # { "v", 2, 12, 2, 14 }
$V keys RUN g r n                       # { "v", 2, 12, 2, 47 }: the whole call
$V keys RUN g r m                       # { "v", 2, 12, 2, 14 }: back to the gnn range
$V keys RUN Escape Escape
$V keys RUN 2 G '>' '>' = =
$V lua RUN 'vim.fn.getline(2)'          # "    return sum(item[\"price\"] for item in items)"
```

End state seen (Neovim 0.12.6, seeded and `--live`, 2026-11-04): `get_installed("parsers")` is
`c,cpp,css,go,html,http,javascript,json,lua,markdown,markdown_inline,python,toml,vim`, and
`parser/python.so` resolves once, under `xdg/data/nvim/site/parser/`. The highlighter is active on
`sample.lua`, `main.go`, `app.py`, `notes.md` (`vim.b.current_syntax == "markdown"` there too).
`vaf` on line 1 of `app.py` is `{ "V", 1, 2 }`, `vif` on line 2 `{ "V", 2, 2 }`; on a two-method
class (`cls.py`, 6 lines) `vac` is `{ "V", 1, 6 }` and `vic` `{ "V", 2, 6 }`. `gnn` → `grn` →
`grm` as in the comments above; Normal `grn` is `vim.lsp.buf.rename()` and `maparg("grc", "x")` is
empty. `>>` then `==` restores the 4-space indent; `cfg.yaml` keeps `GetYAMLIndent(v:lnum)`.
`:GoCmt` on line 5 of `main.go` inserts `// add function` above `func add` (go.nvim's treesitter
path), and saving still runs gofumpt (`x := a + b`).

## Gotchas

- `--live` before the owner deploys `main`: live has no `~/.local/share/nvim/site` and no Mason
  `tree-sitter-cli`. `up --live` replaces nvim-treesitter from the seed (its live lock still says
  `master`: `replaced_from_seed`), and with it the seed's `site/parser`, `site/parser-info` and
  `site/queries` (`PLUGIN_EXTRA_DATA` in `verify.sh`; each listed in `evidence/00-up-replaced.txt`).
  After Deploy nothing is replaced and the run copies live's own `site/`. The config's install does
  nothing without the CLI, so no error appears.
- A plugin dir switched from `master` to `main` keeps master's untracked `parser/` and
  `parser-info/`; they are on the runtimepath and would shadow the new parsers. The seed removes
  them (seed log `WARN ... removed parser/`); the Deploy runbook does the same for live.
- Neovim 0.12 ftplugins (`lua`, `markdown`, `help`, `query`) start treesitter themselves, and their
  FileType handlers run after the config's, so the config applies markdown's `syntax=ON` and the
  `indentexpr` in a `vim.schedule`. Read them after the buffer is shown, not inside FileType.
- `2 G` keeps the column (`startofline` is off), so start `gnn` from a known column (`0 w w`):
  from a blank line it selects the whole module. Test `==` after `>>`, not `<<`: a dedented Python
  body is a syntax error, and the tree it parses to gives indent `0`.
- `--live` before Deploy: live Mason has no `tree-sitter-cli`, so mason-tool-installer tries it
  offline at every start (nvim-notify `tree-sitter-cli: installing`, then `failed to install`;
  nothing in `:messages`). The notification floats cover the right edge of the screen for a few
  seconds; wait for them to close before reading a screen (`$V wait RUN '#vim.tbl_filter(function(w)
  return vim.api.nvim_win_get_config(w).relative ~= "" end, vim.api.nvim_list_wins())' 0 30`).
- go.nvim is at `4755def` (the newest commit that runs on the installed guihua.lua). Upstream
  master needs `guihua.ts_utils`, which guihua.lua `ef44ba4` lacks: bumping go.nvim further needs
  guihua.lua bumped too.
- Base finding (0.12 on nvim-treesitter `master`): `vaf` → `E5108 ... tsrange.lua:27: attempt to
  call method 'start' (a nil value)`, and `:GoCmt` with go.nvim `81bb94c` on `main` → `module
  'nvim-treesitter.ts_utils' not found`.
