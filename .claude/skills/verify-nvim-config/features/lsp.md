# LSP

## Sub-features

- `config/lsp.lua` + `after/lsp/*.lua` with mason-lspconfig v2 (`automatic_enable`):
  lua_ls, gopls, pyright, yamlls, bashls, html, cssls. LspAttach mappings (`gd`, ...), detach from
  fugitive/git buffers.
- Mason binaries resolved through `stdpath("data")/mason/bin` (prepended to PATH by mason).
- `after/lsp/pyright.lua` adds settings and capabilities only; the command is nvim-lspconfig's
  default `pyright-langserver --stdio` (Mason's `pyright` package).

## How to get to it (user POV)

Open a `.lua`, `.go` or `.py` file; diagnostics and `gd` work once the server attaches.

## Driving it with verify.sh

```sh
$V keys RUN : e Space sample.lua Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="lua_ls"})), ",")' lua_ls 60
$V keys RUN : e Space main.go Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="gopls"})), ",")' gopls 90
$V keys RUN : e Space app.py Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="pyright"})), ",")' pyright 90
$V lua RUN 'vim.lsp.get_clients({bufnr=0, name="pyright"})[1].config.cmd[1] .. " " .. vim.fn.exepath("pyright-langserver")'
$V lua RUN '#vim.tbl_filter(function(l) return l:find("delance", 1, true) ~= nil end, vim.fn.readfile(vim.lsp.log.get_filename()))'
$V keys RUN G o
$V keys RUN --paste 'count: int = "three"'
$V keys RUN Escape Escape
$V wait RUN '(function() for _, d in ipairs(vim.diagnostic.get(0, {lnum = 5})) do if d.source == "Pyright" then return d.code end end return "none" end)()' reportAssignmentType 60
```

End states seen (seeded and `--live`, nvim 0.11.5): `wait ok ... lua_ls`, `wait ok ... gopls`,
`wait ok ... pyright`. The client's command is `pyright-langserver`, and it resolves to the run's
`.../xdg/data/nvim/mason/bin/pyright-langserver` (pyright 1.1.414 seeded, 1.1.407 live). `lsp.log`
has `0` lines naming `delance`. After pasting `count: int = "three"` as line 6 of `app.py`, the
buffer has a `Pyright` diagnostic with code `reportAssignmentType` on that line. On a Lua buffer the
clients are `lua_ls,stylua` (mason-lspconfig auto-enables Mason's stylua as a language server).

### CursorHold diagnostic float

`diagnostic-conf.lua` opens `vim.diagnostic.open_float({ width = 100 })` on CursorHold (`updatetime` 500)
when the cursor moved in a buffer with diagnostics. nvim caps the float's width to the window's width
minus the `single` border (2), so in a window of 1-2 columns `nvim_open_win` used to throw. The callback
now skips the float there. Repro (the `:2vsplit` window is the narrow one, and it gets the cursor):

```sh
$V keys RUN : e Space sample.lua Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="lua_ls"})), ",")' lua_ls 60
$V keys RUN G o
$V keys RUN --paste 'x = undefined_thing'
$V keys RUN Escape Escape
$V wait RUN '#vim.diagnostic.get(0, {lnum = vim.fn.line(".") - 1}) > 0' true 60
$V keys RUN k j
$V wait RUN '(function() for _, w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(w).relative ~= "" and vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, 1, false)[1] == "Diagnostics:" then return vim.api.nvim_win_get_width(w) end end return 0 end)()' 100 15
$V keys RUN : 2 v s p l i t Enter
$V keys RUN k j
$V keys RUN h
$V screen RUN narrow
$V wait RUN 'vim.deep_equal(vim.b.diagnostics_pos, vim.api.nvim_win_get_cursor(0))' true 10
$V lua RUN '{ width = vim.api.nvim_win_get_width(0), floats = #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative ~= "" and vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, 1, false)[1] == "Diagnostics:" end, vim.api.nvim_list_wins()), messages = vim.fn.execute("messages") }'
```

End state seen (0.12.6, seeded `1104-131214-3068043` and `--live` `1104-131054-3055370`): in the
full-width window the diagnostic float opens with width `100`. In the 2-column window the screen has no
`Invalid 'width'`, `diagnostics_pos` equals the cursor (the hold ran), and the probe is
`{ width = 2, floats = 0 }` with no error in `messages` (until phase 3 of nvim-0-12-clean lands it holds
blink.cmp's `client.request is deprecated`, from the insert). On the base the `screen` after `h` showed
`Error in CursorHold Autocommands for "*"` ... `util.lua:1760: Invalid 'width': expected positive Integer`
and `Press ENTER` (same runs, `evidence/15-screen-narrow.txt`); press `Enter` before any `lua`/`wait`,
which block on that prompt.

### fidget health

fidget keeps its notification window off nvim-tree through `notification.window.avoid = { "NvimTree" }`;
`config/fidget-nvim.lua` turns the deprecated implicit integration off after `setup()` (passing it to
`setup()` is reported as a deprecated option).

```sh
$V keys RUN : e Space sample.lua Enter                    # fidget loads on BufRead
$V keys RUN : checkhealth Space fidget Enter
$V wait RUN 'vim.bo.filetype' checkhealth 15
$V lua RUN 'table.concat(vim.tbl_filter(function(l) return l:find("WARNING", 1, true) ~= nil end, vim.api.nvim_buf_get_lines(0, 0, -1, false)), "\n")'
$V keys RUN : q Enter
$V lua RUN 'require("fidget.notification.window").get_window_position(); return vim.inspect(require("fidget.notification.window").options.avoid)'
```

End state seen (seeded `1104-131214-3068043`, `--live` `1104-131054-3055370`): no WARNING line (base:
`- ⚠️ WARNING nvim-tree.lua integration is implicitly enabled`), and avoid is `{ "NvimTree" }`, as on the base.

## Gotchas

- Fixed 2026-11-04 (R2): `after/lsp/pyright.lua` used to set
  `cmd = { "delance-langserver", "--stdio" }` (copied from the upstream config). No such binary
  exists, so 0.11 logged `invalid "pyright" config: ... delance-langserver is not executable` and
  Python buffers got no language server (pyright `0` clients, seeded and live). The file no longer
  sets `cmd`. Do not add one back: inheriting lspconfig's default keeps it matched to what Mason
  installs.
- `~/miniconda3/bin` is on the run's PATH (that is where `python3` lives) and carries pip's own
  `pyright-langserver` wrapper, which wants the network on first start. Mason prepends its `bin`,
  so Mason's copy wins. Check `vim.fn.exepath("pyright-langserver")` if pyright ever hangs on start.
- pyright publishes diagnostics with `source = "Pyright"`. Filter on it, because the custom-autocmd
  Python syntax check also writes diagnostics on save.
- The fixture's `app.py` is saved on `Escape` (the line count in the statusline grows), so a run
  that already pasted the type error keeps it across `sync`; the pasted line then lands on line 7
  and line 6 still carries the diagnostic.
- gopls takes up to ~30 s to attach on the first Go file: wait, do not sleep. pyright's first
  attach on the fixture takes a few seconds.
- lua_ls writes `log/` and `meta/` into its install dir. `up` re-points Mason's launcher to the
  run's copy (see SKILL.md Gotchas); `doctor`'s `seed`/`live` lines prove nothing wrote through.
- `lsp.log` also carries harmless `Cannot find request with id N whilst attempting to cancel`.
