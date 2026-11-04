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

End states seen (seeded and `--live`, nvim 0.11.5; re-driven unchanged on 0.12.6 by nvim-0-12-clean phase 4): `wait ok ... lua_ls`, `wait ok ... gopls`,
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
$V keys RUN k
$V wait RUN 'vim.deep_equal(vim.b.diagnostics_pos, vim.api.nvim_win_get_cursor(0))' true 10   # the hold ran on the line above
$V keys RUN j                # a separate send: the cursor now differs from diagnostics_pos
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

`k` and `j` go in separate sends with the hold in between. In one `keys RUN k j` the cursor is back on
the diagnostic line before the next CursorHold. When an earlier hold already recorded that position
(diagnostics arrive while the cursor rests there), no new float opens, and the width-100 wait times
out about 3 times in 4 (nvim-0-12-clean phase 4 sweep, runs `1104-135431-3607302`, `1104-135702-3789564`,
`1104-135731-3798863`, `1104-135808-3822763`). The config is right; the recipe was racy.

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

### Completion (blink.cmp v1)

blink.cmp `1.*` (v1.10.2, `78336bc`) with its Rust fuzzy matcher: the prebuilt
`target/release/libblink_cmp_fuzzy.so` for the checked-out tag, fetched by `seed` (runs have no network).
Keymaps (`config/blink-cmp.lua`): `<Tab>`/`<S-Tab>` select next/previous (else snippet jump, else the key),
`<Enter>` selects and accepts, `<C-U>`/`<C-D>` scroll the documentation, and `<C-E>`/`<Esc>` cancel. blink has
no command-line sources (`cmdline.sources = {}`, what the v0 config's table shape meant too).

```sh
DEPS=@.claude/skills/verify-nvim-config/features/lua/deprecations.lua
MENU='tostring(require("blink.cmp").is_menu_visible())'
$V keys RUN : e Space sample.lua Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="lua_ls"})), ",")' lua_ls 60
$V keys RUN G o
$V keys RUN vim.p
$V wait RUN "$MENU" true 30
$V screen RUN completion-lua
$V keys RUN Escape
$V lua RUN "$MENU"' .. " " .. vim.fn.mode()'
$V keys RUN BSpace p
$V wait RUN "$MENU" true 30
$V keys RUN Tab
$V keys RUN Enter
$V lua RUN 'tostring(vim.api.nvim_get_current_line():match("^vim%.[%w_]+") ~= nil)'
$V keys RUN Escape
$V keys RUN Escape
$V wait RUN 'vim.fn.mode()' n 10
$V keys RUN : e Space main.go Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="gopls"})), ",")' gopls 90
$V keys RUN : 1 1 Enter
$V keys RUN o
$V keys RUN fmt.
$V wait RUN "$MENU" true 60
$V keys RUN Escape
$V keys RUN Escape
$V wait RUN 'vim.fn.mode()' n 10
$V keys RUN : e Space app.py Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="pyright"})), ",")' pyright 90
$V keys RUN G o
$V keys RUN str.
$V wait RUN "$MENU" true 60
$V keys RUN Escape
$V keys RUN Escape
$V wait RUN 'vim.fn.mode()' n 10
$V lua RUN "$DEPS"
$V lua RUN 'require("blink.cmp.fuzzy").implementation_type'
$V lua RUN '(function() local d = vim.fn.stdpath("data") .. "/lazy/blink.cmp" return vim.fn.readfile(d .. "/target/release/version")[1] .. " " .. vim.trim(vim.fn.system({ "git", "-C", d, "describe", "--tags", "--exact-match" })) end)()'
$V keys RUN : checkhealth Space blink.cmp Enter
$V lua RUN 'table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")'
$V keys RUN : q Enter
$V keys RUN : checkhealth Space vim.deprecated Enter
$V lua RUN 'table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")'
$V keys RUN : q Enter
$V keys RUN : e Space sam Tab
$V screen RUN cmdline-tab
$V lua RUN "$MENU"' .. " " .. vim.fn.getcmdline()'
$V keys RUN Escape
```

End states seen (seeded `1104-133721-3343691` and `--live` `1104-133718-3342035`, nvim 0.12.6, blink v1.10.2):
- typing `vim.p` opens the menu. The first `Escape` closes it and stays in insert mode (`false i`). After
  `BSpace p` `Tab` `Enter` the line matches `^vim%.[%w_]+` (`true`).
- the menu opens in Go (`fmt.`) and Python (`str.`), and two separate `Escape`s reach normal mode each time.
- no blink.cmp or git-conflict.nvim deprecation: no `client.request`, no `vim.highlight`. The probe prints `1`, and
  that line is go.nvim's `vim.lsp.codelens.refresh({ bufnr = bufnr}) is deprecated` (main.go's codelens).
  `:checkhealth vim.deprecated` lists 2 warnings: that one and glance.nvim's `vim.validate{<table>}`
  (`glance/init.lua:367`). Both plugins are outside this change and were hidden on the base: nvim reports each
  deprecated name once, and blink's `client.request` and git-conflict's `vim.validate{}` came first.
- `implementation_type` is `rust`; the version line is `v1.10.2 v1.10.2`.
- `:checkhealth blink.cmp` has `OK blink_cmp_fuzzy lib is downloaded/built`, with `Default sources` lsp, path,
  buffer, snippets and no `Cmdline sources` section.
- `:e sam<Tab>` leaves `:e sam^I` on the command line (a literal tab), and the blink menu is `false`.

Before (blink v0.14.2): seeded `1104-132438-3160384` and `--live` `1104-132435-3158849` (the first recipe, which
typed `vim.` and `Escape Escape`), and `--live` `1104-133804-3361630` (this recipe, from a checkout of `d90b730`,
whose rule left live's v0.14.2 in place). The screen's last line was
`client.request is deprecated. Run ":checkhealth vim.deprecated" for more information` from the first insert on,
the probe printed that line, and `:checkhealth vim.deprecated` had 4 warnings: `client.request`
(`blink/cmp/sources/lsp/completion.lua:17`), `vim.highlight` (blink's docs window, and git-conflict.nvim on the
first runs), go.nvim's codelens, and `vim.validate{<table>}` (`git-conflict/colors.lua:12`). The keymap
(`false i`, `true`) and `:e sam^I` end states were the same.

Completion gotchas:
- The fuzzy library must match the checked-out tag: `target/release/{libblink_cmp_fuzzy.so,
  libblink_cmp_fuzzy.so.sha256, version}`, plus the tag in the clone (`git describe --tags --exact-match`). If they
  do not match, blink v1 tries to download in every run, fails (no network), and notifies "Falling back to Lua
  implementation". `seed` fetches the library (`seed.lua` step `blink.cmp fuzzy library`). A seed lock bump of
  blink.cmp needs nothing else.
- `vim.` alone opens no menu in WORK (v0.14.2 and v1 alike): lua_ls has no `vim` library for files outside the
  config and answers with the buffer's words only. Type a letter after the dot.
- Send the two `Escape`s as two `keys` calls. One `keys RUN Escape Escape` while the menu is open leaves insert
  mode on (both arrive before blink's `cancel` has closed the menu), and the next `:` command becomes buffer text.
- The command line's `<Tab>` inserts a literal tab (`^I`) instead of completing, on v0.14.2 and v1 alike: blink's
  cmdline `<Tab>` mapping finds no menu and its `fallback` feeds a plain `<Tab>`, which is not `'wildchar'` when
  it comes from a mapping. Kept unchanged here (no behaviour change); recorded as a finding.
- `:checkhealth blink.cmp`'s `WARNING Some providers may show up as "disabled"` is always printed (upstream's
  `health.lua`).
- Never drive completion with `--paste` (a paste opens no menu). Type with `keys`.

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
