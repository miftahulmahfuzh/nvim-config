# LSP

## Sub-features

- `config/lsp.lua` + `after/lsp/*.lua` with mason-lspconfig v2 (`automatic_enable`):
  lua_ls, gopls, pyright, yamlls, bashls, html, cssls. LspAttach mappings (`gd`, ...), detach from
  fugitive/git buffers.
- Mason binaries resolved through `stdpath("data")/mason/bin` (prepended to PATH by mason).

## How to get to it (user POV)

Open a `.lua`, `.go` or `.py` file; diagnostics and `gd` work once the server attaches.

## Driving it with verify.sh

```sh
$V keys RUN : e Space sample.lua Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="lua_ls"})), ",")' lua_ls 60
$V keys RUN : e Space main.go Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="gopls"})), ",")' gopls 90
$V keys RUN : e Space app.py Enter
$V lua RUN '#vim.lsp.get_clients({bufnr=0, name="pyright"})'
grep -c 'delance-langserver is not executable' ~/.local/state/nvim-config-verify/RUN/xdg/state/nvim/lsp.log
```

End states seen (seeded and `--live`): `wait ok ... lua_ls`, `wait ok ... gopls`, pyright `0`,
and `1` matching log line: `invalid "pyright" config: ... cmd: expected ... executable command
... Info: delance-langserver is not executable`. On a Lua buffer the clients are `lua_ls,stylua`
(mason-lspconfig auto-enables Mason's stylua as a language server).

## Gotchas

- Product finding (base, also live): `after/lsp/pyright.lua:23` sets
  `cmd = { "delance-langserver", "--stdio" }` (inherited from the upstream config). Mason installs
  `pyright`, not delance, so Python buffers never get a language server. Only the
  custom-autocmd syntax check runs.
- gopls takes up to ~30 s to attach on the first Go file: wait, do not sleep.
- lua_ls writes `log/` and `meta/` into its install dir. `up` re-points Mason's launcher to the
  run's copy (see SKILL.md Gotchas); `doctor`'s `seed`/`live` lines prove nothing wrote through.
- `lsp.log` also carries harmless `Cannot find request with id N whilst attempting to cancel`.
