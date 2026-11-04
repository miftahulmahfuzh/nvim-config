# Evidence: phase 4 (sweep, tmux true colour, health allow-list)

`E=~/.local/state/nvim-config-verify`. Neovim 0.12.6. Probes: `.claude/skills/verify-nvim-config/features/lua/{health_diff,noise,load_all}.lua`;
lever: `.workflows/plan/nvim-0-12-clean/phase-4-health.sh`. Evidence file numbers in a lever run:
`01` errmsg, `02` noise at startup, `03` terminal-overrides, `04` setrgb count, `07` checkhealth vs
allow-list (gopls attached), `09` noise after it, `12` load_all, `13` noise after it, `15`
checkhealth vs allow-list (all loaded), `17` deprecations, `phase4-doctor.txt`.

## Base (planning, base `9cea538`, probes run from the planner's scratch copy)

| What | Seeded | Live |
|---|---|---|
| checkhealth vs allow-list, gopls attached | `$E/1104-123911-2920493/evidence/03-lua-…` (`sections=20 … unexpected=25`) | `$E/1104-123923-2924758/evidence/03-lua-…` (`unexpected=25`) |
| noise after checkhealth + notes.md | `$E/1104-123911-2920493/evidence/07-lua-…` (`client.request`, `E31`) | `$E/1104-123923-2924758/evidence/07-lua-…` |
| load_all | `…/08-lua-…` (`tried=18 failed=0 unloaded=0`) | `…/08-lua-…` |
| checkhealth vs allow-list, all loaded | `…/11-lua-…` (`sections=22 … unexpected=31`, incl. render-markdown ×5) | `…/11-lua-…` |
| yanky `clipboard: error: no buffers` | `$E/1104-123349-2896788/evidence/01-lua-…`; gone after `y y`: `$E/1104-123424-2900903/evidence/04-lua-…` | — |
| blink `client.request` triggered by `:checkhealth` | `$E/1104-123952-2930953/evidence/08-lua-…`, stack `13-lua-…` | — |
| `E31` on markdown (FileType fired twice) | `$E/1104-124053-2938291/evidence/03-lua-…`; probe KNOWN `$E/1104-124133-2941539/evidence/03-lua-…` | — |
| full checkhealth (analysis) | — | `$E/1104-121901-2809686/evidence/03-lua-return_table.concat_vim.api.nvim_buf_get.txt` |

## Before (phase-3 tip, Step 2)

The first try, seeded `$E/1104-134953-3535637`, also showed 6 keys outside the plan's prediction:
go.nvim's `nvim-dap`, `nvim-dap-ui`, `nvim-dap-virtual-text: not installed/loaded`, `Not all plugin installed`,
and glance.nvim's `vim.validate{<table>}` (Findings 4, 5). After they were recorded, the before runs
fail exactly where the plan predicted:

Seeded `RUN=1104-135135-3546728`, live `RUN=1104-135146-3552065` (`replaced_from_seed=blink.cmp git-conflict.nvim`); both exit 1, identical checks:

```
check doctor PASS exit 0
check startup-messages PASS
check errmsg PASS vim.v.errmsg empty: true
check noise-startup PASS noise=0 known=0
check tc-override FAIL terminal-overrides: <empty>
check tc-rgb FAIL setrgbb/setrgbf lines in show-messages -T: 0
check gopls PASS gopls attached to main.go
check health-lsp FAIL sections=20 findings=75 allowed=74 unexpected=1 unused=7      (live: findings=77 allowed=76 unused=5)
    UNEXPECTED vim.health / tmux: WARNING True color support could not be detected. |'termguicolors'| won't work properly.
check noise-health PASS noise=0 known=0
check load-all PASS tried=17 failed=0 unloaded=0
check noise-load-all PASS noise=0 known=1 KNOWN errmsg: E31: No such mapping
check health-all-loaded FAIL sections=22 findings=83 allowed=77 unexpected=6 unused=4   (live: findings=85 allowed=79 unused=2)
    UNEXPECTED render-markdown / render-markdown.nvim [tree-sitter latex]: WARNING parser: not installed
    UNEXPECTED render-markdown / render-markdown.nvim [tree-sitter latex]: WARNING ABI: unknown
    UNEXPECTED render-markdown / render-markdown.nvim [tree-sitter yaml]: WARNING parser: not installed
    UNEXPECTED render-markdown / render-markdown.nvim [tree-sitter yaml]: WARNING ABI: unknown
    UNEXPECTED render-markdown / render-markdown.nvim [latex]: WARNING none installed: { "utftex", "latex2text" }
    UNEXPECTED vim.health / tmux: WARNING True color support could not be detected. |'termguicolors'| won't work properly.
check deprecations PASS … minus health.md's two upstream ones: 0
```

## After (Step 5)

Seeded `RUN=1104-135215-3559599`, live `RUN=1104-135227-3564882` (`replaced_from_seed=blink.cmp git-conflict.nvim`); both exit 0:

```
check doctor PASS exit 0
check startup-messages PASS
check errmsg PASS vim.v.errmsg empty: true
check noise-startup PASS noise=0 known=0
check tc-override PASS terminal-overrides: *256col*:Tc
check tc-rgb PASS setrgbb/setrgbf lines in show-messages -T: 2
check gopls PASS gopls attached to main.go
check health-lsp PASS sections=20 findings=74 allowed=74 unexpected=0 unused=7          (live: findings=76 allowed=76 unused=5)
check noise-health PASS noise=0 known=0
check load-all PASS tried=17 failed=0 unloaded=0
check noise-load-all PASS noise=0 known=1 KNOWN errmsg: E31: No such mapping
check health-all-loaded PASS sections=22 findings=77 allowed=77 unexpected=0 unused=4   (live: findings=79 allowed=79 unused=2)
check deprecations PASS … minus health.md's two upstream ones: 0
```

Final re-run after all of phase 4's doc and allow-list edits: § Final lever.

## Final lever

After every phase 4 edit (allow-list, noise list, doc corrections), seeded `RUN=1104-140507-4017271`, live
`RUN=1104-140519-4022631`: both exit 0, with every check identical to § After.

## True colour (Step 7)

| | Seeded | Live |
|---|---|---|
| before (`auto`) | `$E/1104-140108-3948797` (run from a scratch copy with `9cea538`'s `.tmux.conf.local`): `<empty>`, `0`, `32`; lever `$E/1104-135135-3546728` `03-`/`04-lua-…` | `$E/1104-140129-3953555`: `<empty>`, `0`, `32`; lever `$E/1104-135146-3552065` `03-`/`04-lua-…` |
| after (`true`) | `$E/1104-135818-3827299`: `*256col*:Tc`, `2`, `0`; lever `$E/1104-135215-3559599` | `$E/1104-135407-3589592` (`13`-`16`): `*256col*:Tc`, `2`, `0`; lever `$E/1104-135227-3564882` |

The values are `terminal-overrides`, the `setrgb[bf]` count in `show-messages -T`, and
`search("True color support could not be detected")` in `:checkhealth vim.health`.

## Sweep (Step 6): every journey, both modes

Driven by three parallel sweep agents on the tree with Steps 3-4 applied. Every run's baseline
after `up` was `noise=0 known=0`, and doctor exited 0 on every run except the asserted PATH fault
injection. `deprecations.lua` printed `0` after every block, apart from go.nvim's codelens line once
a Go buffer loaded (allowed, coordinator decision). Each run was taken `down`.
`deps` = `deprecations.lua` minus the two upstream lines.

| File | Block | Mode | End state matched | noise.lua | Evidence |
|---|---|---|---|---|---|
| startup.md | lazy stats (`up`, doctor, stats) | live | yes (93/63) | noise=0 known=0 | `1104-135343-3578529` `02-lua-…` |
| startup.md | lazy stats | seeded | yes | noise=0 known=0 | `1104-135610-3734096` |
| startup.md | Mason headless, nothing reinstalls | live | yes (2 offline `Failed to update registries` lines, doc mentions one) | noise=0 known=0 | `1104-135343-3578529` `05-headless-…`, `logs/mason.log` |
| startup.md | Mason headless | seeded | yes | noise=0 known=0 | `1104-135610-3734096` |
| startup.md | gofumpt missing, reinstall attempt | live | yes | noise=1 (expected `notify ERROR: gofumpt: failed to install`) | `1104-135511-3664861` |
| startup.md | `--bare` fault injection | bare | yes (doctor `path ok`, exit 0) | noise=0 known=0 | `1104-135619-3757582` |
| startup.md | broken lazy.nvim dir | bare | yes | noise=0 known=0 | `1104-135619-3757582` `06-headless-…` |
| startup.md | deleted working directory | live | yes | noise=1 (expected cwd WARN) known=1 (E31) | `1104-135343-3578529` `15`-`21` |
| startup.md | deleted working directory | seeded | yes | same | `1104-135610-3734096` |
| startup.md | run PATH (`up`, `sync`, doctor) | live | yes (`path ok`) | noise=0 known=0 | `1104-135458-3629061` |
| startup.md | run PATH | seeded | yes | noise=0 known=0 | `1104-135610-3734103` |
| startup.md | PATH fault injection | live | yes (`path FAIL …:/leak/bin`, exit 1, asserted) | noise=0 known=0 | `1104-135458-3629061` |
| startup.md | PATH fault injection | seeded | yes | noise=0 known=0 | `1104-135610-3734103` |
| startup.md | go.nvim tools, `:checkhealth go` | live | yes (0 ERROR, 0 Missing tool) | noise=0 known=0 | `1104-135343-3578529` `09-`, `11-lua-…` |
| startup.md | go.nvim tools | seeded | yes | noise=0 known=0 | `1104-135610-3734096` |
| startup.md | `v:errmsg` + `:e .` | live | yes (`""`; `{NvimTree}`) | noise=0 known=0 | `1104-135458-3629058` |
| startup.md | `v:errmsg` + `:e .` | seeded | yes | noise=0 known=0 | `1104-135610-3734098` |
| dashboard.md | start screen | live | yes | noise=0 known=0 | `1104-135458-3629059` |
| dashboard.md | start screen | seeded | yes | noise=0 known=0 | `1104-135610-3734101` |
| dashboard.md | behind nvim-tree | live | yes | noise=0 known=0 | `1104-135458-3629060` |
| dashboard.md | behind nvim-tree | seeded | yes | noise=0 known=0 | `1104-135610-3734102` |
| dashboard.md | leaving the dashboard, the split | live | yes | noise=0 known=0 | `1104-135511-3664857` |
| dashboard.md | leaving the dashboard, the split | seeded | yes | noise=0 known=0 | `1104-135619-3757579` |
| format-on-save.md | Lua, valid code | live | yes | noise=0 known=0 | `1104-135511-3664859` |
| format-on-save.md | Lua, valid code | seeded | yes | noise=0 known=0 | `1104-135619-3757581` |
| format-on-save.md | Lua, syntax error line 1 | live | yes after doc correction (Finding 6: `:messages` empty, written line on screen only) | noise=1 (expected stylua WARN) | `1104-135511-3664859` |
| format-on-save.md | Lua, syntax error line 1 | seeded | same | noise=1 (expected) | `1104-135619-3757581` |
| format-on-save.md | Lua, syntax error line 8 | live | yes | noise=1 (expected) | `1104-135511-3664859` |
| format-on-save.md | Lua, syntax error line 8 | seeded | yes | noise=1 (expected) | `1104-135619-3757581` |
| format-on-save.md | cursor clamp | live | yes | noise=0 known=0 | `1104-135511-3664859` |
| format-on-save.md | cursor clamp | seeded | yes | noise=0 known=0 | `1104-135619-3757581` |
| format-on-save.md | Go | live | yes after doc correction (Finding 6) | noise=0 known=1 (codelens) | `1104-135511-3664859` |
| format-on-save.md | Go | seeded | same | noise=0 known=1 | `1104-135619-3757581` |
| format-on-save.md | Python | live | yes | noise=0 known=0 | `1104-135511-3664859` |
| format-on-save.md | Python | seeded | yes | noise=0 known=0 | `1104-135619-3757581` |
| lsp.md | attach lua/go/py + pyright diagnostic | live | yes | noise=0; deps 0 | `1104-135420-3595239` |
| lsp.md | attach lua/go/py + pyright diagnostic | seeded | yes | noise=0; deps 0 | `1104-135425-3601917` |
| lsp.md | CursorHold float + `:2vsplit` | live | old recipe: no (width-100 wait timed out; narrow part `{width=2, floats=0}` matched). Fixed recipe: yes, 3/3 (Finding 7) | noise=0; deps 0 | old `1104-135431-3607302` (+ `1104-135702-3789564`, `1104-135731-3798863`, `1104-135808-3822763`); fixed `1104-140136-3958113`, `1104-140156-3985374`, `1104-140218-4007904` |
| lsp.md | CursorHold float + `:2vsplit` | seeded | old recipe: yes (1 of its runs); fixed recipe: yes, 3/3 | noise=0; deps 0 | old `1104-135432-3608772`; fixed `1104-140127-3951734`, `1104-140148-3968334`, `1104-140210-4004840` |
| lsp.md | fidget health | live | yes (no WARNING; avoid `{ "NvimTree" }`) | noise=0; deps 0 | `1104-135456-3628437` |
| lsp.md | fidget health | seeded | yes | noise=0; deps 0 | `1104-135440-3618059` |
| lsp.md | Completion (blink.cmp v1) | live | yes (`false i`, `true`, `rust`, `v1.10.2 v1.10.2`, `:e sam^I`) | noise=0 known=1 (codelens) | `1104-135508-3658432` |
| lsp.md | Completion (blink.cmp v1) | seeded | yes | noise=0 known=1 (codelens) | `1104-135445-3622277` |
| treesitter.md | highlight/indent/`vaf`/gnn-grn-grm/`==`/vac-vic | live | yes | noise=0 (KNOWN E31 after notes.md); deps 0 | `1104-135533-3705361` + `1104-135638-3775665` |
| treesitter.md | same | seeded | yes | same | `1104-135504-3639746` + `1104-135651-3784806` |
| editing-mappings.md | `V H` jq | live | yes | noise=0; deps 0 | `1104-135544-3717143` |
| editing-mappings.md | `V H` jq | seeded | yes | noise=0; deps 0 | `1104-135514-3670406` |
| editing-mappings.md | `<C-o>` paths | live | yes | noise=0 known=1 (E31) | `1104-135550-3722166` |
| editing-mappings.md | `<C-o>` paths | seeded | yes | noise=0 known=1 (E31) | `1104-135520-3688507` |
| editing-mappings.md | hop `f`/`F`/Escape | live | yes | noise=0; deps 0 | `1104-135600-3728770` |
| editing-mappings.md | hop `f`/`F`/Escape | seeded | yes | noise=0; deps 0 | `1104-135529-3699488` |
| fzf-lua.md | `,ff` → guide | live | yes | noise=0; deps 0 | `1104-135403-3586377` |
| fzf-lua.md | `,ff` → guide | seeded | yes | noise=0; deps 0 | `1104-135420-3595240` |
| git.md | `,ga`/`,gc`/`,gp` | live | yes in a fresh run (`bd85b2e`); after other journeys in one run the commit went out blank (Finding 9) | noise=0 known=1 (E31) | `1104-135627-3767397`; ordering case `1104-135407-3589592` `31`-`45` |
| git.md | `,ga`/`,gc`/`,gp` | seeded | yes (`80c4865`) | noise=0 known=1 (E31) | `1104-135856-3841678` |
| git.md | conflict journey (last in its run) | live | yes (every listed end state; deps `0`) | noise=1 `errmsg: E565` → KNOWN after Finding 8 | `1104-135627-3767397` |
| git.md | conflict journey (last in its run) | seeded | yes | same | `1104-135856-3841678`; trace `1104-135941-3872925` |
| tmux-bindings.md | `C-b -`, `@`, `-`, `!`, doctor | live | yes (`brk_1_<pid>:2.1 %3`, no `__ph`, tmuxconf ok) | noise=0 | `1104-135407-3589592` `02`-`12` |
| tmux-bindings.md | `C-b -`, `@`, `-`, `!`, doctor | seeded | yes | noise=0 | `1104-135818-3827299` |
| tmux-bindings.md | true colour | live | yes (`*256col*:Tc`, `2`, `0`) | noise=0 | `1104-135407-3589592` `13`-`16` |
| tmux-bindings.md | true colour | seeded | yes | noise=0 | `1104-135818-3827299` |
| img2braille.md | script → `,bv` → `,b` | live | yes (`40x27 cells`, `27 1107`, checkout clean) | noise=0 | `1104-135407-3589592` `23`-`28` |
| img2braille.md | script → `,bv` → `,b` | seeded | yes | noise=0 | `1104-135818-3827299` |
| live-environment.md | `live`, `up --live`, doctor, noise | live | mechanics yes; recorded values were phase 9's, rewritten in Step 9 to the measured ones (live `9cea538`, 8 commits, `replaced_from_seed=blink.cmp git-conflict.nvim`, tmux.conf.local differs on line 18) | noise=0 | `live-1104-135401.txt`, `1104-135407-3589592` |
| health.md | the whole "Driving" block | live | yes (`sections=20 … unexpected=0 unused=5`; `tried=17 failed=0 unloaded=0`; `sections=22 … unexpected=0 unused=2`) | 0 / 0 / known=1 (E31) | `1104-135747-3809749` |
| health.md | the whole "Driving" block | seeded | yes (`unused=7` / `4`) | 0 / 0 / known=1 (E31) | `1104-140027-3942593` |

## Findings

| # | Finding | Class (a/b/c/d) | Cause (file:line) | Disposition | Before / after |
|---|---|---|---|---|---|
| 1 | render-markdown `latex`/`yaml` health warnings (5) | a | `lua/plugin_specs.lua` render-markdown `opts = {}` (defaults enable both) | Step 4: both disabled | `$E/1104-135135-3546728`, `$E/1104-135146-3552065` `15-lua-…` (`unexpected=6`) / `$E/1104-135215-3559599`, `$E/1104-135227-3564882` `15-lua-…` (`unexpected=0`) |
| 2 | `clipboard: error: no buffers` after loading yanky in a fresh run | b (run-only) | nvim `autoload/provider/clipboard.vim:43` on an empty tmux buffer list | health.md Gotchas; sweep yanks first | base rows above |
| 3 | `E31: No such mapping` in `v:errmsg` on markdown | b (upstream) | runtime `ftplugin/markdown.vim:35` + `ftplugin/markdown.lua` undo, FileType fired twice by lazy's `ft` handler | health.md ```` ```noise ```` | base rows above |
| 4 | go.nvim `nvim-dap`, `nvim-dap-ui`, `nvim-dap-virtual-text: not installed/loaded`, `Not all plugin installed` (measured once phase 1 let the go check run; also in evidence-phase-1.md's notes) | b (optional plugins never installed) | go.nvim `lua/go/health.lua:125-180` `plugin_check`; the config declares no dap plugin | health.md go `allow` block (allow-list text correction + 4 entries) | `$E/1104-134953-3535637` (UNEXPECTED) / `$E/1104-135135-3546728` (ALLOWED) |
| 5 | `vim.deprecated`: glance.nvim `vim.validate{<table>}` (setup) and go.nvim `vim.lsp.codelens.refresh` (Go buffers) | c → recorded as b (coordinator decision after phase 3) | glance `lua/glance/init.lua:333`, `:367`; go.nvim `lua/go/codelens.lua:59` | health.md "Fixed upstream, not moved here": `allow` entries keyed by plugin (`health_diff.lua` now names a `vim.deprecated` key's plugin from its first stack frame, so a git-conflict regression stays UNEXPECTED) + codelens `noise` entry; the lever and Deploy D5 exclude exactly these two lines from `deprecations.lua`; follow-up `P2-NVIM-F6PG` | `$E/1104-134953-3535637` (UNEXPECTED) / `$E/1104-135135-3546728` (`ALLOWED vim.deprecated / glance.nvim: …`) |
| 6 | format-on-save.md recorded a `"… written"` line in `:messages`; Neovim 0.12.6 shows it on screen but keeps it out of `:messages` (`nvim --clean` alike) | b (upstream behaviour; the doc's end state was stale) | Neovim 0.12.6 message history; config not involved (`viml_conf/options.vim:118` `messagesopt=hit-enter,history:500`) | format-on-save.md end states corrected (Lua line-1 block, Go block); "Before" lines left as recorded | `1104-135511-3664859`, `1104-135619-3757581` |
| 7 | lsp.md CursorHold recipe `keys RUN k j` + wait for the width-100 float is racy (failed 3 of 4 extra runs); Deploy D5 used the same recipe | d (journey recipe) | one `send-keys` returns the cursor to `vim.b.diagnostics_pos` before the next CursorHold (`lua/diagnostic-conf.lua:64` opens only when the position changed) | lsp.md and Deploy D5: `k`, wait `diagnostics_pos == cursor`, then `j` (separate sends); end states unchanged | old: `1104-135431-3607302`, `1104-135702-3789564`, `1104-135731-3798863`, `1104-135808-3822763` / new: 6/6 pass, `1104-140127-3951734` … `1104-140218-4007904` |
| 8 | `E565: Not allowed to change text or change window: copen` in `v:errmsg` after `ct` (silent; quickfix list right) | a + b (kept: index Decision "`lua/config/git-conflict.lua` unchanged") | git-conflict fires `User GitConflictResolved` twice, the second under textlock (`git-conflict.lua:673` → `process:481` → `parse_buffer:408`); `lua/config/git-conflict.lua:12` `silent! GitConflictListQf` | health.md `noise` entry + git.md Gotcha; follow-up `P2-NVIM-R4JW` (`vim.schedule` in the callback) | `1104-135627-3767397`, `1104-135856-3841678`; trace `1104-135941-3872925` |
| 9 | git.md's commit journey, driven after several other journeys in one run, committed a blank line | d (journey ordering) | nvim still consuming earlier keys (screens `32`-`35` frozen with `o` pending); not reproduced in fresh runs | git.md Gotcha: drive it early or in a fresh run; plus the `,gp` Press-ENTER Gotcha | `1104-135407-3589592` `31`-`45` / `1104-135627-3767397`, `1104-135856-3841678` |
| 10 | Cmdline `:e sam<Tab>` inserts a literal `^I` (handed over by phase 3) | a, kept (invariant 5; coordinator decision) | `lua/config/blink-cmp.lua` cmdline `<Tab>` = `{ "select_next", "fallback" }` with `sources = {}`: fallback returns `<Tab>` from an expr map, which `'wildchar'` ignores (`'wildcharm'` = 0). Config, not harness: tmux Tab, `C-i`, `nvim_input`, remapped feedkeys all `^I`; `feedkeys(…,"nt")` or the map deleted completes | health.md "Findings kept as they are"; follow-up `P2-NVIM-6CQH` | `1104-135505-3642755` (seeded), `1104-135833-3831128` (live) |
| 11 | lsp.md attach block still said "nvim 0.11.5" | d (doc) | — | note added: re-driven unchanged on 0.12.6 | `1104-135420-3595239`, `1104-135425-3601917` |

The go.nvim allow-list entries the plan wrote from code were checked against the measured report:
the seven optional-parser entries (`json` is installed, so it is `UNUSED`), `Some binaries …`, `main
module loaded, WIP` and `GOBIN is not in PATH` match as written. The only correction is Finding 4's
four additions.

## Handoffs

- Plugin moves (class c): go.nvim (`5622d97`, `codelens.enable`) and glance.nvim (`5a8eab1`, no
  `vim.validate{}` in `init.lua`). Follow-up `P2-NVIM-F6PG` in `.workflows/todos.md`.
- Config follow-ups kept out of this set by its invariants/decisions: `P2-NVIM-6CQH` (cmdline
  `<Tab>`), `P2-NVIM-R4JW` (git-conflict Resolved callback under textlock).
- To the coordinator (Deploy runbook in `phase-4.md`, also mirrored into
  `.workflows/orchestration/nvim-0-12-clean/phase-4.md` and `.workflows/plan/P1-NVIM-IS7R.md`):
  - D5 now excludes go.nvim's codelens and glance.nvim's `vim.validate{}` lines from
    `deprecations.lua` (`deps_other`). The strict `= 0` would have failed on the codelens line once
    D5 opens `main.go`, and rolled back a good deploy.
  - D5's CursorHold step sends `k` and `j` separately (Finding 7).
  - `bash -n` passes.
- None to phases 1-3.
