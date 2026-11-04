# Health: the `:checkhealth` allow-list and the sweep's known noise

## Sub-features

- `:checkhealth` runs every health check on the runtimepath: Neovim's own `vim.*` checks and those
  of every loaded plugin. For this config, clean means that every WARNING/ERROR line left is in the
  allow-list below, with the reason it stays. Nothing the config causes, or can fix, is on the list.
- `lua/health_diff.lua` turns the `health://` report into one key per WARNING/ERROR line and
  compares the keys with the list. `unexpected=0` is the pass.
- `lua/noise.lua` reports, after each journey, what the journey printed: new `:messages` lines,
  nvim-notify entries at WARN/ERROR or naming a deprecation, and a changed `v:errmsg`. Entries in
  the known-noise list below are excluded. `noise=0` is the pass.
- `lua/load_all.lua` loads every lazy plugin that is not loaded yet (the sweep's "every plugin
  loads" step).

## How to get to it (user POV)

Run `:checkhealth`, or `:checkhealth <name>` for one check. The report opens in a new tab.

## Driving it with verify.sh

```sh
P=.claude/skills/verify-nvim-config/features/lua
$V lua RUN @$P/noise.lua                  # right after up: noise=0 known=0
$V keys RUN : e Space main.go Enter
$V wait RUN '#vim.lsp.get_clients({bufnr=0, name="gopls"})' 1 90
$V keys RUN : checkhealth Enter
$V wait RUN 'vim.bo.filetype' checkhealth 120
$V lua RUN @$P/health_diff.lua            # sections=20 findings=.. allowed=.. unexpected=0 unused=..
$V keys RUN : tabclose Enter
$V lua RUN @$P/noise.lua                  # noise=0
$V keys RUN : e Space notes.md Enter
$V keys RUN y y                           # a line in the run's tmux buffer (see Gotchas)
$V lua RUN @$P/load_all.lua               # tried=.. failed=0 unloaded=0
$V lua RUN @$P/noise.lua                  # noise=0 known=1 (KNOWN errmsg: E31, from notes.md)
$V keys RUN : checkhealth Enter
$V wait RUN 'vim.bo.filetype' checkhealth 120
$V lua RUN @$P/health_diff.lua            # sections=22 (+ render-markdown, telescope) ... unexpected=0
```

This set's lever `.workflows/plan/nvim-0-12-clean/phase-4-health.sh seeded|live` runs this whole
block, plus the startup and true-colour checks, and exits 1 on any failure.

A key has the form `<section>[ / <subsection>]: <LEVEL> <message>`. A message that ends in `:`
takes its first indented continuation line, so the `targets` keys name the mapping and the
`snacks` keys name the missing languages. An entry that ends in `*` matches every key that starts
with the text before the `*`. `UNUSED` entries are information only, because what is reported
depends on the mode (live Mason has more servers enabled than the seed) and on what is loaded.

## The allow-list

Each block below is one group, with one origin and one reason. The probes read every line inside
the ```` ```allow ```` fences; a line that starts with `#` is a comment.

**Optional tools the owner never installed** (environment-only; installing them is out of scope).
- snacks enables only `input` and `picker` (`plugin_specs.lua`). Its other modules report
  `setup {disabled}` by design.
- snacks `image`/`lazygit`/`picker`, telescope, fzf-lua, diffview and Mason list tools that are
  absent on this machine as well as in the run. `command -v` finds none of kitty, wezterm,
  ghostty, magick, convert, gs, mmdc, lazygit, fd, fdfind, hg, viu, chafa, ueberzugpp, luarocks,
  composer, php, javac or julia.
- The owner's terminal does not speak the kitty graphics protocol.
- The treesitter languages snacks would use (`latex`, `norg`, `scss`, `svelte`, `tsx`, `typst`,
  `vue`, `regex`) are not among the 13 that `config/treesitter.lua` installs.

```allow
snacks / Snacks.bigfile: WARNING setup {disabled}
snacks / Snacks.dashboard: WARNING setup {disabled}
snacks / Snacks.explorer: WARNING setup {disabled}
snacks / Snacks.image: WARNING setup {disabled}
snacks / Snacks.notifier: WARNING setup {disabled}
snacks / Snacks.quickfile: WARNING setup {disabled}
snacks / Snacks.scope: WARNING setup {disabled}
snacks / Snacks.scroll: WARNING setup {disabled}
snacks / Snacks.statuscolumn: WARNING setup {disabled}
snacks / Snacks.words: WARNING setup {disabled}
snacks / Snacks.notifier: ERROR is not ready
snacks / Snacks.image: ERROR None of the tools found: 'kitty', 'wezterm', 'ghostty'
snacks / Snacks.image: ERROR None of the tools found: 'magick', 'convert'
snacks / Snacks.image: ERROR `magick` is required to convert images. Only PNG files will be displayed.
snacks / Snacks.image: WARNING Missing Treesitter languages: `latex`, `norg`, `scss`, `svelte`, `tsx`, `typst`, `vue`
snacks / Snacks.image: WARNING Image rendering in docs with missing treesitter parsers won't work
snacks / Snacks.image: ERROR Tool not found: 'gs'
snacks / Snacks.image: WARNING `gs` is required to render PDF files
snacks / Snacks.image: WARNING The `latex` treesitter parser is required to render LaTeX math expressions
snacks / Snacks.image: ERROR Tool not found: 'mmdc'
snacks / Snacks.image: WARNING `mmdc` is required to render Mermaid diagrams
snacks / Snacks.image: ERROR your terminal does not support the kitty graphics protocol
snacks / Snacks.lazygit: ERROR {lazygit} not installed
snacks / Snacks.picker: WARNING Missing Treesitter languages: `regex`
snacks / Snacks.picker: ERROR None of the tools found: 'fd', 'fdfind'
snacks / Snacks.picker: ERROR 'fd' `v8.4` is required for searching with `Snacks.picker.explorer()`
telescope / Checking external dependencies: WARNING fd: not found. Install [sharkdp/fd](https://github.com/sharkdp/fd) for extended capabilities
fzf_lua / fzf-lua [optional:media]: WARNING 'viu' not found
fzf_lua / fzf-lua [optional:media]: WARNING 'chafa' not found
fzf_lua / fzf-lua [optional:media]: WARNING 'ueberzugpp' not found
diffview / Checking VCS tools: WARNING Configured `hg_cmd` is not executable: 'hg'
mason / mason.nvim [Languages]: WARNING luarocks: not available
mason / mason.nvim [Languages]: WARNING Composer: not available
mason / mason.nvim [Languages]: WARNING PHP: not available
mason / mason.nvim [Languages]: WARNING javac: not available
mason / mason.nvim [Languages]: WARNING julia: not available
```

**go.nvim's optional extras** (environment and upstream; recorded per phase 1's handoff, measured
once the go check stopped crashing).
- `treesitter parser <x> is optional but it is not found`: go.nvim's optional parsers (`gowork`,
  `gomod`, `gosum`, `sql`, `gotmpl`, `comment`, `json`) are not all among the 13 that
  `treesitter.lua` installs. `json` is installed, so its entry is normally `UNUSED`.
- Any missing parser also triggers the summary `Some binaries are not installed …`
  (`go/health.lua:122`, `no_err = false`); every Go tool itself is found.
- `nvim-treesitter main module loaded, WIP` is go.nvim's own label for nvim-treesitter `main`
  (`health.lua:154`), not a fault.
- `GOBIN is not in PATH`: neither the owner nor the run sets `GOBIN` (`go env GOBIN` is empty), and
  go.nvim's `path_check` (`health.lua:240`) warns whenever it is unset.
- `nvim-dap`, `nvim-dap-ui`, `nvim-dap-virtual-text: not installed/loaded` and their summary
  `Not all plugin installed`: go.nvim's `plugin_check` (`health.lua:125-180`) lists its optional
  debugger plugins. The config declares none of them (no `dap` in `lua/`, none in the live
  `lazy/`), and adding plugins is out of scope.
- Not on the list but still upstream: go.nvim `health.lua:58` calls `vim.system` without an
  `executable()` guard and crashes the whole check when `golangci-lint` is missing. It is
  unreachable now that phase 1 puts the Go tools on `run_path`. A ❌ there is `UNEXPECTED`, as it
  should be.

```allow
go / Binaries: WARNING treesitter parser gowork is optional but it is not found*
go / Binaries: WARNING treesitter parser gomod is optional but it is not found*
go / Binaries: WARNING treesitter parser gosum is optional but it is not found*
go / Binaries: WARNING treesitter parser sql is optional but it is not found*
go / Binaries: WARNING treesitter parser gotmpl is optional but it is not found*
go / Binaries: WARNING treesitter parser comment is optional but it is not found*
go / Binaries: WARNING treesitter parser json is optional but it is not found*
go / Binaries: WARNING Some binaries are not installed, please check if your $HOME/go/bin or $GOBIN $exists and in your $PATH
go / Go Plugin Check: WARNING nvim-treesitter main module loaded, WIP
go / Go Plugin Check: WARNING GOBIN is not in PATH
go / Go Plugin Check: WARNING nvim-dap: not installed/loaded
go / Go Plugin Check: WARNING nvim-dap-ui: not installed/loaded
go / Go Plugin Check: WARNING nvim-dap-virtual-text: not installed/loaded
go / Go Plugin Check: WARNING Not all plugin installed
```

**Fixed upstream, not moved here** (upstream; a plugin bump is out of this set's scope).
- `health_diff.lua` names a `vim.deprecated` key after the plugin in its first stack frame, so
  these entries allow only these two plugins. The same deprecation from another plugin (say
  git-conflict.nvim's old `vim.validate{}`) is still `UNEXPECTED`.
- go.nvim `4755def` calls `vim.lsp.codelens.refresh({ bufnr = bufnr })` (`go/codelens.lua:59`).
  Upstream `5622d97` uses `codelens.enable`. The check lists it once a Go buffer refreshed its
  lenses. Turning `lsp_codelens` off would hide it and change behaviour.
- glance.nvim calls `vim.validate{<table>}` in `setup` (`glance/init.lua:333`, `:367`). Upstream
  `5a8eab1` has no `vim.validate{}` in `init.lua`.
- Follow-up: "bump go.nvim + glance.nvim D4-style, re-seed" in `.workflows/todos.md`.

```allow
vim.deprecated / go.nvim: WARNING vim.lsp.codelens.refresh({ bufnr = bufnr}) is deprecated.*
vim.deprecated / glance.nvim: WARNING vim.validate{<table>} is deprecated. Feature will be removed in Nvim 1.0
```

**The run's fence** (environment-only; these never show in the owner's own nvim).
- `cargo` lives in `~/.cargo/bin`, a per-user dir that `run_path` leaves out on purpose
  (SKILL.md). The owner's nvim finds it.
- PyPI is unreachable because no run has network (`unshare -n`). Online, the provider check
  reports pynvim's latest version instead.

```allow
mason / mason.nvim [Languages]: WARNING cargo: not available
vim.provider / Python 3 provider (optional): WARNING Could not contact PyPI to get latest version.
vim.provider / Python 3 provider (optional): ERROR HTTP request failed: error: curl error with https://pypi.org/pypi/pynvim/json: 6
```

**Upstream-only** (nvim-lspconfig).
- The default `filetypes` of gopls (`gotmpl`), ts_ls (`javascript.jsx`, `typescript.tsx`) and
  yamlls (`yaml.docker-compose`, `yaml.gitlab`, `yaml.helm-values`) name compound filetypes that
  Neovim 0.12 does not know.
- Overriding `filetypes` in `after/lsp/*.lua` would only hide the check and drift from upstream's
  defaults.
- ts_ls is enabled only where Mason has it (the owner's live Mason), so its two lines are
  `UNUSED` on a seeded run.

```allow
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'gotmpl' (Hint: filename extension != filetype).
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'javascript.jsx' (Hint: filename extension != filetype).
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'typescript.tsx' (Hint: filename extension != filetype).
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'yaml.docker-compose' (Hint: filename extension != filetype).
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'yaml.gitlab' (Hint: filename extension != filetype).
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'yaml.helm-values' (Hint: filename extension != filetype).
```

**The owner's deliberate mappings** (intentional; changing them would change behaviour).
- targets.vim reports the `iB` buffer text object (`text_obj#Buffer`) and vim-sandwich's
  `ab`/`ib`, which take those keys before targets.
- which-key lists every prefix that also has longer mappings. Its own report says the overlaps
  are "for informational purposes only".
- The overlap lists come in no fixed order, so each entry matches only up to `overlaps with`.
- A new prefix with overlaps is still reported as `UNEXPECTED`.

```allow
targets: WARNING Conflicting mapping found: iB → :<C-U>call text_obj#Buffer()<CR>
targets: WARNING Conflicting mapping found: ab → <Plug>(textobj-sandwich-auto-a)
targets: WARNING Conflicting mapping found: ib → <Plug>(textobj-sandwich-auto-i)
which-key / checking for overlapping keymaps: WARNING In mode `n`, <c> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <sr> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <sd> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <,b> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <,s> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <gc> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <,gt> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <,gp> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <gr> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <\> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <^> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `x`, <a> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `x`, <i> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `x`, <@> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `o`, <a> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `o`, <i> overlaps with*
```

**Informational, always printed.** blink.cmp v1's `health.lua` calls `vim.health.warn` for this
line unconditionally, whatever the config.

```allow
blink.cmp / Sources: WARNING Some providers may show up as "disabled" but are enabled dynamically (e.g. cmdline)
```

## Known noise (`noise.lua`)

**Silent, upstream-only.** Opening a markdown buffer sets `v:errmsg` to `E31: No such mapping`.
1. Neovim 0.12's `ftplugin/markdown.vim` and `ftplugin/markdown.lua` both append
   `nunmap <buffer> ]]` / `[[` to `b:undo_ftplugin`.
2. After lazy.nvim's `ft` handler loads the `ft = "markdown"` plugins (render-markdown, tabular,
   vim-markdownfootnotes), it fires `FileType` a second time.
3. The undo runs, and the second `sil! nunmap` of the same map fails.

`sil!` keeps the error off the screen and out of `:messages`. Nothing is lost, because the
ftplugins map both keys again.

```noise
errmsg: E31: No such mapping
```

**Fixed upstream, not moved here.** Once a Go buffer refreshes its code lenses, go.nvim's
`vim.lsp.codelens.refresh` deprecation (allow-list above) is also printed to `:messages`, once per
nvim. Neovim prints each deprecated name only once, so it shows after the first Go journey only.

```noise
messages: vim.lsp.codelens.refresh({ bufnr = bufnr}) is deprecated. Run ":checkhealth vim.deprecated" for more information
```

**Silent, config + upstream (git-conflict).** After resolving a conflict (`ct`, `co`, ...),
`v:errmsg` holds `E565`.
1. git-conflict.nvim fires `User GitConflictResolved` twice. The second firing comes from its
   redraw hook, under textlock.
2. `config/git-conflict.lua`'s callback runs `silent! GitConflictListQf` there, and `copen` fails.
3. `silent!` hides it. The first firing already refreshed the quickfix list.

The index of nvim-0-12-clean keeps `lua/config/git-conflict.lua` unchanged. The fix
(`vim.schedule` in the callback) is follow-up `P2-NVIM-R4JW` (git.md Gotchas).

```noise
errmsg: E565: Not allowed to change text or change window: copen
```

## Findings kept as they are (config behaviour, not changed by this set)

**Command-line `<Tab>` inserts a literal `^I`.** `:e sam` + `<Tab>` leaves `:e sam^I` instead of
completing to `:e sample.lua`. This is the same on blink.cmp v0.14.2 and v1.10.2, and in a real
terminal as in a run. It is the config, not the harness. Measured by nvim-0-12-clean phase 4's
sweep, runs `1104-135505-3642755` (seeded) and `1104-135833-3831128` (live):
- How the Tab is sent makes no difference: tmux `Tab`, tmux `C-i`, `nvim_input("<Tab>")` and
  remappable `nvim_feedkeys` all give `^I`.
- Only a Tab that bypasses the mapping completes: `nvim_feedkeys(…, "nt")`, or the run with
  blink's cmdline `<Tab>` map deleted.
- Cause: `lua/config/blink-cmp.lua` maps cmdline `<Tab>` to `{ "select_next", "fallback" }`, with
  `cmdline.sources = {}`. There is never a menu, so `fallback` returns `<Tab>` from an expr mapping.
  A key produced by a mapping is not typed, so `'wildchar'` (9) ignores it, and `'wildcharm'` is 0.
  The comment there, which says Tab reaches the wildmenu through `fallback`, does not hold.
- Kept: invariant 5 of nvim-0-12-clean (cmdline completion behaves as before).
- Fix candidates: `wildcharm=<Tab>`, or drop the cmdline `<Tab>`/`<S-Tab>` keys. Follow-up
  `P2-NVIM-6CQH` in `.workflows/todos.md`.

## Fixed by this set (none of these is on the list; they must never come back)

| Section | Was | Fix |
|---|---|---|
| `vim.deprecated` | `vim.highlight` and `vim.validate{<table>}` from git-conflict.nvim; blink v0.14's `client.request` | phase 3: `stryukovsky/git-conflict.nvim@63c5b42`, blink.cmp v1.10.2 |
| `go` | ❌ `Failed to run healthcheck` (golangci-lint ENOENT) + 19 `Missing tool` | phase 1: go.nvim's tool dir on `run_path` (affected runs only; the owner's nvim always had the tools) |
| `fidget` | `nvim-tree.lua integration is implicitly enabled` | phase 2: `config/fidget-nvim.lua` (`notification.window.avoid = { "NvimTree" }` in `setup`, then the `fidget.integration.nvim-tree` module's `options.enable = false` after setup; passing the integration option to `setup` re-warns as deprecated) |
| `vim.health / tmux` | `True color support could not be detected` | phase 4: `tmux_conf_24b_colour=true` in `.tmux.conf.local` (tmux-bindings.md) |
| `render-markdown` | `latex`/`yaml` parser not installed, `ABI: unknown` ×2, no latex converter (5 warnings, once a markdown file loaded it) | phase 4: `opts = { latex = { enabled = false }, yaml = { enabled = false } }` (neither ever rendered: no parser, no converter) |
| `blink.cmp` | v0.14's version of the informational line (`i.e.` instead of `e.g.`) | phase 3: v1.10.2 |

## Gotchas

- `:checkhealth` lists only the plugins whose `health.lua` is on the runtimepath, i.e. the loaded
  ones. `render-markdown` and `telescope` appear only after a markdown file or `load_all.lua`, so
  run the comparison in both states.
- `load_all.lua` in a fresh run prints `clipboard: error: no buffers` (WarningMsg):
  1. yanky.nvim reads the `+` register on setup (`clipboard=unnamedplus`).
  2. The run's fresh tmux server has no paste buffer, and nvim's tmux clipboard provider fails on
     the read.

  The owner's long-lived tmux server has buffers. Yank a line first with `y y`.
- A full `:checkhealth` runs blink's source health, which sends an LSP request. Before blink v1
  that printed `client.request is deprecated`.
- A new WARNING/ERROR after a change is a finding. Fix it when the config causes it. Otherwise add
  it to the right group above, with its origin and reason, in the same change.
- Never allow a whole section (`snacks*`): each entry names one line.
