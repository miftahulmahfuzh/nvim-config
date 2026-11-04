# Code Analysis: verify-nvim-config findings, opencode purge, Neovim 0.12.6

**Type:** Bug Investigation (with a refactor/purge and a toolchain upgrade)
**Date:** 2026-11-04 10:34 (+07)
**Session ID:** 20261104-102452-MRDD
**Plan:** `docs/plans/FIX_BUGS_NVIM_0_12_PLAN.md` (9 phases + a post-land Deploy section)
**Worktree:** `/home/miftah/.worktrees/nvim/fix-bugs-nvim-0-12` on `feature/fix-bugs-nvim-0-12` (base `origin/main` @ `a14aef9`; the live checkout `~/.config/nvim` is clean and equal to it)

---

## User Input

### Original User Request

```
bug ~/.config/nvim --permission-mode bypassPermissions
Fix every bug the verify-nvim-config pass found, purge opencode, and upgrade Neovim. Unattended: decide everything yourself, record decisions, commit and push to main. No human in the loop.

ANCHOR: ~/.config/nvim is the owner's LIVE config (the nvim they use daily) and a clone of https://github.com/miftahulmahfuzh/nvim-config. It was fast-forwarded to origin/main a14aef9 just before this session. Plan, prove and land from here. ~/nvim-config is another clone of the same repo; leave it alone. When the work lands, ~/.config/nvim's main must equal origin/main again with a clean tree (`git -C ~/.config/nvim fetch origin && git -C ~/.config/nvim merge --ff-only origin/main`; plain `git pull --ff-only` fails in this checkout with "Cannot fast-forward to multiple branches").

PROOF: the repo's skill .claude/skills/verify-nvim-config (read SKILL.md and features/*.md first). Every fix gets a before/after on `verify.sh up --live` (the change on a copy of the live plugins/Mason/lock) AND on `verify.sh up` (seeded), with the failure shown first on the base. Update the matching features/*.md end states in the same change.

BUGS (root causes already found, see the feature files):
1. Data loss: lua/custom-autocmd.lua (~line 254) runs `silent %!stylua -` on BufWritePre without checking the exit status; on a Lua syntax error stylua's error text replaces the buffer, and the file on disk when the cursor restore does not throw (repro in features/format-on-save.md: 11-line file -> 3 lines of error text). Format via vim.system with stdin, replace lines only on exit 0, keep the cursor safe, never lose content.
2. pyright never starts: after/lsp/pyright.lua sets cmd = { "delance-langserver", "--stdio" }; Mason installs pyright. Make Python buffers get a working server (features/lsp.md).
3. lua/plugin_specs.lua: nvim-treesitter has no branch pin, so lazy follows GitHub's default `main` (incompatible with require("nvim-treesitter.configs")); the live lock says master. Pin what the config actually supports (or migrate deliberately) so `:Lazy update`/a fresh install cannot break it.
4. phaazon/hop.nvim was deleted from GitHub; switch to the maintained fork smoka7/hop.nvim (same API).
5. plugin_specs.lua mason config calls get_package("gofumpt"):install() unconditionally on every start (a reinstall + go install per launch); mason-tool-installer already ensures gofumpt. Remove the per-start reinstall.
6. Dashboard: on the start screen ,bg / ,bv save the new art but do not redraw (create_dashboard() never sets ascii_art_win). Make the visible art follow the selection.
7. The lazy bootstrap git clone result is unchecked; offline first start dies with E5113 in require("lazy"). Fail gracefully (clear message, rest of init.lua still loads).

ALSO:
8. Purge opencode entirely: lua/custom/opencode.lua, its require in lua/config/fzf-lua.lua, any mapping/doc mention; then remove the fake-opencode machinery from the verify skill (verify.sh write_fake_opencode, doctor's opencode line, SKILL.md/features mentions) since nothing will call it.
9. Upgrade Neovim to the latest stable release (from github.com/neovim/neovim/releases, nvim-linux-x86_64.tar.gz, verify its sha256). It lives at /opt/nvim-linux-x86_64 (dir owned by miftah, /opt itself root-owned and sudo needs a password: replace the directory's CONTENTS in place, keep a backup of 0.11.5 under ~/.local/opt/). Bump init.lua's expected_version to match, check every plugin still loads on the new version (verify.sh up --live, doctor, the feature journeys), and fix what breaks.
10. Fix the verify skill's deploy hint (cmd_live prints `pull --ff-only`, which fails here) to the fetch + merge --ff-only form above.

LANDING: commit with conventional messages, push to main of https://github.com/miftahulmahfuzh/nvim-config, then fast-forward ~/.config/nvim to it and finish with one `verify.sh up --live` + doctor + the format-on-save and lsp journeys from ~/.config/nvim itself. Report each bug's before/after evidence paths.
```

### User-Provided Context
- Root causes for 1-7 come from the verify-nvim-config pass recorded in `.claude/skills/verify-nvim-config/features/*.md` (all re-read for this analysis).
- Constraints: `/opt` is root-owned, sudo needs a password, `/opt/nvim-linux-x86_64` is owned by `miftah` → replace its contents in place. `~/nvim-config` must not be touched. `git pull --ff-only` fails in `~/.config/nvim`.

### User-Provided Files
None marked with `@`. Named: `lua/custom-autocmd.lua`, `after/lsp/pyright.lua`, `lua/plugin_specs.lua`, `lua/config/fzf-lua.lua`, `lua/custom/opencode.lua`, `init.lua`, `.claude/skills/verify-nvim-config/{SKILL.md,features/*.md,scripts/verify.sh}`.

### Requirement IDs

| ID | What the user asked for |
|---|---|
| R1 | Stylua format-on-save never loses content: `vim.system` + stdin, replace only on exit 0, cursor safe |
| R2 | Python buffers get a working pyright server |
| R3 | nvim-treesitter pinned to what the config supports, or migrated deliberately, so `:Lazy update`/fresh install cannot break it |
| R4 | hop.nvim from the maintained fork `smoka7/hop.nvim` |
| R5 | No per-start `get_package("gofumpt"):install()` |
| R6 | Dashboard start screen redraws on `,bg` / `,bv` |
| R7 | Offline first start (lazy bootstrap clone fails) fails gracefully: clear message, rest of init.lua loads |
| R8 | Purge opencode from the config and the verify skill's fake-opencode machinery |
| R9 | Neovim upgraded to the latest stable (v0.12.6), sha256-verified, contents replaced in place, 0.11.5 backed up under `~/.local/opt/`, `expected_version` bumped, every plugin loading, breaks fixed |
| R10 | The verify skill's deploy hint uses `fetch` + `merge --ff-only origin/main` |
| R11 | Land: conventional commits pushed to `main`, `~/.config/nvim` fast-forwarded and clean, final `up --live` + doctor + format-on-save and lsp journeys from `~/.config/nvim`, before/after evidence paths reported per bug |

---

## Detailed Requirements Understanding

**Problem/Requirement Statement.** Seven product bugs in the live Neovim config (one data-loss bug, one dead LSP server, two supply-chain hazards in plugin specs, one wasteful per-start install, one UI redraw bug, one crash-on-offline-bootstrap), one purge (opencode, in config and in the verify harness), a Neovim major-minor upgrade (0.11.5 → 0.12.6) that turns out to *force* the treesitter decision in R3, one doc/hint fix in the harness, and a landing onto the owner's live checkout and live plugin data.

**Success Criteria.**
- Each of R1–R7, R10 has a before (failure on the base) and an after (fixed) on both `verify.sh up --live` and `verify.sh up`, and its `features/*.md` end state is rewritten.
- No `opencode` string remains in the repo outside git history and this analysis/plan (R8).
- `/opt/nvim-linux-x86_64/bin/nvim --version` says v0.12.6; `~/.local/opt/nvim-0.11.5/` holds the old tree; `init.lua` expects 0.12.6; all journeys pass on 0.12.6 (R9).
- `origin/main` carries the work; `~/.config/nvim` HEAD == `origin/main`, `git status` clean; the final live verify passes (R11).

**Key Considerations (measured in this session, not assumed).**
1. **0.12.6 is the latest stable** (GitHub API `releases/latest`: tag `v0.12.6`, published 2026-10-09). Asset digest for `nvim-linux-x86_64.tar.gz`: `sha256:474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87`; downloaded and `sha256sum -c` → OK (scratch copy only; nothing installed).
2. **A probe run of the unchanged config on 0.12.6** (`VERIFY_NVIM=<scratch>/nvim verify.sh up --live`, run `1104-102617-1863253`, evidence kept at `~/.local/state/nvim-config-verify/1104-102617-1863253/evidence/`):
   - startup clean except the expected `Expect nvim version 0.11.5, but your current nvim version is 0.12.6`; doctor all ok; `count=93 loaded=63`;
   - treesitter highlight active on markdown and lua; lua_ls and gopls attach; pyright 0 (R2, unrelated to version);
   - `gnn` incremental selection and `=` (treesitter indentexpr) still work;
   - **`vaf` (nvim-treesitter-textobjects select) fails**: `E5108: ...nvim-treesitter/lua/nvim-treesitter/tsrange.lua:27: attempt to call method 'start' (a nil value)`. Root cause: frozen `master`'s `lua/nvim-treesitter/query.lua:251` calls `query:iter_matches(..., { all = false })`; 0.12 no longer honours `all = false`, so captures arrive as node *lists*.
   - `:checkhealth vim.deprecated`: only plugin-side warnings (git-conflict.nvim uses `vim.highlight`, `vim.validate{}`); not breakages.
3. **`master` of nvim-treesitter is archived** (HEAD `42fc28ba` "docs(readme)!: announce archiving of master branch", 2025-05-24) and textobjects `master` is frozen (`5ca4aaa` "docs: master is frozen"). Pinning `master` (R3's first option) leaves textobjects broken on 0.12 (R9) with no upstream fix possible. → R3 and R9 are coupled: the deliberate migration to `main` is the only path that satisfies both.
4. **nvim-treesitter `main`** (upstream tip `0195cd62`, 2026-11-02) requires Neovim ≥ 0.12.0, `tar`, `curl`, a C compiler (`/usr/bin/cc` present) and **`tree-sitter-cli` ≥ 0.26.1** (absent on this machine; Mason's registry carries `tree-sitter-cli` = `pkg:github/tree-sitter/tree-sitter@v0.27.1`). `main` has no `nvim-treesitter.configs`; highlighting is `vim.treesitter.start()` per FileType, indent is `vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"`, parsers install to `stdpath('data')/site` via `require('nvim-treesitter').install{...}`. Incremental selection is gone from the plugin; Neovim 0.12 ships `v_an`/`v_in`/`v_]n`/`v_[n` and `vim.treesitter.select()` (runtime `doc/news.txt:409-411`).
5. **textobjects `main`** (`5c7b026`): `require("nvim-treesitter-textobjects").setup{ select = {...} }` + explicit `vim.keymap.set({"x","o"}, ..., function() require("nvim-treesitter-textobjects.select").select_textobject(cap, "textobjects") end)`.
6. **Other plugins requiring nvim-treesitter modules** (grep of the live `~/.local/share/nvim/lazy`): go.nvim (15 files), guihua.lua (5), nvim-autopairs (2), render-markdown (2), nvim-bqf (1), rose-pine (1). The live go.nvim (`81bb94c`, 2025-11-07) has unguarded `require("nvim-treesitter.ts_utils")` (fixplurals) and `require('nvim-treesitter.parsers')` (ginkgo); upstream go.nvim master (`5622d97`, 2026-10-18) guards them with `pcall` and has an explicit main/master switch (`lua/go.lua:234`).
7. **hop**: `git ls-remote` of `phaazon/hop.nvim` → `ERROR: Repository not found.` `smoka7/hop.nvim` (default branch `master`, tip `6e83486`, tags up to `v2.7.2`) contains the live lock's commit `1a1eceaf` and 94 commits after it; the config uses only `require("hop")`, `hop.setup`, `hint_words`, `hint_char1`, `require("hop.hint").HintDirection`.
8. **`lazy-lock.json` is gitignored** (`.gitignore:7`). The only locks are the live one (`~/.config/nvim/lazy-lock.json`) and the seed's (`$VERIFY_HOME/.seed/lazy-lock.json`). A spec branch/url change therefore never reaches the live plugin dirs by itself: lazy only re-targets on install/update/restore, not at startup. Landing must update the owner's live plugin state explicitly (Deploy section).
9. **The verify harness assumes a changed plugin is *absent* from live** (`cmd_up` live mode fills only missing dirs from the seed, `verify.sh:304-314`) and **pins every seed plugin to its lock commit** (`seed.lua:37-63`) regardless of a spec branch/url change. Both assumptions break the proofs for R3 and R4 unless the harness learns "moved" plugins.
10. **Stylua config**: `.stylua.toml` at repo root (2-space indent). `stylua -` resolves config from nvim's cwd; WORK has none, so the fixture formats with tabs. Keeping the same argv semantics keeps the existing end states comparable.
11. **Running nvim processes of the owner** keep the old binary inode after an in-place replace, but lazily-sourced runtime files would come from the new tree. Unavoidable without sudo; recorded as a decision.

**Assumptions.** "Latest stable" = GitHub's `releases/latest` at plan time (v0.12.6); if a newer stable appears before the phase runs, the phase still installs v0.12.6 (the digest above is the one checked). Running the machine online during seed and Deploy steps is allowed (the user's request needs downloads).

---

## Analysis Scope

### Explicitly Mentioned Files
- `lua/custom-autocmd.lua`, `after/lsp/pyright.lua`, `lua/plugin_specs.lua`, `lua/config/fzf-lua.lua`, `lua/custom/opencode.lua`, `init.lua`
- `.claude/skills/verify-nvim-config/SKILL.md`, `features/*.md`, `scripts/verify.sh`

### Discovered Related Files
- `lua/config/dashboard-nvim.lua` (R6; loaded by plugin_specs.lua:200-203)
- `lua/config/treesitter.lua`, `lua/config/treesitter-textobjects.lua` (R3; required by plugin_specs.lua:65,73)
- `lua/config/hop.lua` (R4 API surface)
- `lua/colorschemes.lua` (R7: `rand_colorscheme()` is the last line of init.lua and raises with no plugins)
- `lua/utils.lua:57-80` (`is_compatible_version`, R9)
- `viml_conf/plugins.vim:4` (`lua require('plugin_specs')`, R7 entry)
- `.claude/skills/verify-nvim-config/scripts/seed.lua` (R3/R4/R5 seed behaviour)
- `.claude/skills/verify-nvim-config/features/lua/dashboard_art.lua` (R6 probe)
- `README.md:13` (Neovim version badge, 0.11.2)
- `.stylua.toml`, `.gitignore`

---

## Current Dataflow

### Entry Point A: startup (`init.lua`)
`vim.loader.enable()` → `utils.is_compatible_version("0.11.5")` (`init.lua:16-17`; exact `version.cmp`, mismatch echoes an error-highlighted message, never aborts) → `globals` → `viml_conf/options.vim` → `custom-autocmd` (registers BufWritePre stylua, python syntax check, VimEnter nvim-tree) → `mappings` → `viml_conf/plugins.vim` → `lua require('plugin_specs')` → `diagnostic-conf` → `colorschemes.rand_colorscheme()`.

### Processing chain: `lua/plugin_specs.lua`
1. **Bootstrap** `:5-18`: if `stdpath("data")/lazy/lazy.nvim` missing → `vim.fn.system{ "git","clone","--filter=blob:none","https://github.com/folke/lazy.nvim.git","--branch=stable",lazypath }`, result and `vim.v.shell_error` ignored; `rtp:prepend(lazypath)`.
2. **Specs** `:25-584`: notable entries
   - `:61-67` `nvim-treesitter/nvim-treesitter`, `lazy = true`, `build = ":TSUpdate"`, no `branch` → lazy follows GitHub default `main`; config `require("config.treesitter")` → `require("nvim-treesitter.configs").setup{ ensure_installed = {python,http,cpp,lua,vim,json,toml,markdown,markdown_inline,html,css,javascript,go}, highlight = {enable, disable={"help"}, additional_vim_regex_highlighting={"markdown"}}, incremental_selection = {gnn/grn/grc/grm}, indent = {enable, disable={"yaml"}} }`.
   - `:68-75` `nvim-treesitter-textobjects`, `event = "VeryLazy"`, `branch = "master"` → `config.treesitter-textobjects` → `require("nvim-treesitter.configs").setup{ textobjects = { select = { lookahead, keymaps af/if/ac/ic, selection_modes, include_surrounding_whitespace=false } } }`.
   - `:200-203` dashboard-nvim → `require("config.dashboard-nvim")` (custom implementation; the plugin itself is unused).
   - `:512-518` `phaazon/hop.nvim`, `event = "VeryLazy"` → `config.hop`.
   - `:521-529` `williamboman/mason.nvim` config: `require("mason").setup()` then `require("mason-registry").get_package("gofumpt"):install()` (unconditional, every start).
   - `:530-543` mason-tool-installer `ensure_installed = {"gofumpt","stylua"}, auto_update = true, run_on_start = true`.
   - `:544-553` mason-lspconfig `ensure_installed = {lua_ls,yamlls,bashls,pyright,gopls,html,cssls}`.
   - `:554-583` go.nvim (`gofmt = "gofumpt"`, own BufWritePre `*.go`), deps include nvim-treesitter.
3. **`require("lazy").setup{...}`** `:587` — raises E5113 `module 'lazy' not found` when the bootstrap clone failed; that aborts `plugins.vim`, so `diagnostic-conf` and `colorschemes` never run (`features/startup.md`, `--bare`).

### Entry Point B: BufWritePre `*.lua` (`lua/custom-autocmd.lua:249-258`)
`cursor_pos = nvim_win_get_cursor(0)` → `vim.cmd("silent %!stylua -")` (filter: stdout **and stderr** replace the buffer, exit status ignored) → `nvim_win_set_cursor(0, cursor_pos)`. On a syntax error the buffer becomes 3 lines of `error: could not format from stdin...`; if the saved cursor row ≤ 3 the restore succeeds and the write proceeds (file on disk replaced); otherwise `Cursor position outside buffer` aborts the write but the buffer keeps the error text.

### Entry Point C: LSP for Python
mason-lspconfig v2 `automatic_enable` → `vim.lsp.enable("pyright")` → merged config from nvim-lspconfig's `lsp/pyright.lua` (default `cmd = { "pyright-langserver", "--stdio" }`) **overridden** by `after/lsp/pyright.lua:22` `cmd = { "delance-langserver", "--stdio" }` → `lsp.log`: `invalid "pyright" config ... delance-langserver is not executable`. Mason installs `pyright` (`mason/bin/pyright-langserver` exists in live).

### Entry Point D: dashboard (`lua/config/dashboard-nvim.lua`)
- VimEnter (`:410-418`) → `create_dashboard()` with no split → `nvim_win_set_buf(0, buf)` (`:384`); **`ascii_art_win`/`ascii_art_buf` stay nil** (only set in the `split_mode == "right"` branch, `:370-371`).
- `,bg` → `cycle_next_ascii_art()` (`:275-298`) → `update_ascii_art(next)` (`:149-246`): `save_current_art()` writes `stdpath("cache")/dashboard_ascii_art.txt`, then redraws **only if** `ascii_art_win` is valid. `,bv` → `vim.ui.select` → same. `,bh` → `select_bikini()` → same.
- `,b` → `create_dashboard("right")` → split, sets `ascii_art_win`/`ascii_art_buf`.
- BufLeave (`:421-438`) wipes a dashboard buffer when the next buffer is not NvimTree/qf/vista; WinClosed (`:441-450`) clears the tracking.

### Entry Point E: opencode
`lua/config/fzf-lua.lua:4` `local opencode = require("custom.opencode")` — the local is never used in the file. `lua/custom/opencode.lua` (137 lines) defines tmux helpers that `send-keys` into an `opencode` pane or spawn `opencode -p`. No mapping references it.

### Entry Point F: verify harness
- `verify.sh:39` `NVIM_BIN="${VERIFY_NVIM:-/opt/nvim-linux-x86_64/bin/nvim}"` — every subcommand honours `VERIFY_NVIM`.
- `verify.sh:84-90` run PATH comment mentions `~/.opencode`/opencode; `:110` `VERIFY_SINK="$dir/sink"`; `:212-224` `write_fake_opencode()`; `:283` mkdir `sink`; `:330` call; `:434-435` doctor `opencode` line; `:672` `down` copies `sink` into evidence; `:677` cleanup removes `sink`.
- `verify.sh:619-643` `cmd_live` prints `deploy (the owner's step, never run by verify): git -C $LIVE_CONFIG pull --ff-only` (`:639`).
- `cmd_up` live branch (`:297-317`) copies live `lazy/ mason/ rplugin.vim` and fills only *missing* plugin dirs from the seed.
- `seed.lua:37-63` pins every plugin to the seed lock's commit; `:67-69` removes `.cloning` markers; `:75-114` treesitter step already supports both `TSInstallSync` (master) and `require("nvim-treesitter").install(todo):wait()` (main), checking `parser/<lang>.so` on the runtimepath; `:117-166` Mason step installs gofumpt, stylua and the 7 LSP packages, with a special case for "the config itself installs gofumpt on every start".
- `cmd_seed` (`:158-210`) after the seed copies `lock.orig.json` back as the seed lock ("the commits actually checked out").
- doctor's `messages` check (`:456-457`) WARNs on `E[0-9]+:|Error` in `:messages`; `up` (`:394-397`) prints startup errors matching `E[0-9]+:|Error|error`.

### Data Persistence
- `~/.cache/nvim/dashboard_ascii_art.txt` (art name).
- Files the owner edits (stylua path writes them).
- `$VERIFY_HOME=~/.local/state/nvim-config-verify/{.seed,<run>}`; evidence under `<run>/evidence/`.
- Live: `~/.config/nvim/lazy-lock.json` (untracked), `~/.local/share/nvim/{lazy,mason,site}`.

### Exit Points
Buffer/file writes, LSP client processes, `:messages`, `mason.log`, `lsp.log`, the cache file, verify evidence.

---

## Key Data Structures

- **lazy spec** (`plugin_specs.lua`): `{ "<owner>/<repo>", branch?, lazy?, event?, build?, config? }`; lock entry `{ branch, commit }` keyed by repo basename (so `smoka7/hop.nvim` keeps the key `hop.nvim`).
- **seed lock / live lock** JSON: `{ "<name>": { "branch": "...", "commit": "..." } }`.
- **dashboard state**: module locals `ascii_art_win`, `ascii_art_buf`, `fname`, `cache_file`.

---

## Dependencies

- **Binaries**: `/opt/nvim-linux-x86_64/bin/nvim` (0.11.5), Mason `stylua`, `gofumpt`, `pyright-langserver`, `lua-language-server`, `gopls`; system `git`, `cc`, `curl`, `tar`, `unshare`/`nsenter`, `tmux`, `jq`, `fzf` (`~/.fzf/bin`). Missing: `tree-sitter` CLI (needed by nvim-treesitter `main`; Mason `tree-sitter-cli` v0.27.1 available).
- **Network**: only `verify.sh seed` and the Deploy step go online. Runs are fenced (`unshare -n`).
- **Remote**: `origin` = `https://github.com/miftahulmahfuzh/nvim-config.git` (fetch refspec `+refs/heads/main:refs/remotes/origin/main`).

---

## Reference List

| Symbol / key | File:line | Kind | Area |
|---|---|---|---|
| `silent %!stylua -` | `lua/custom-autocmd.lua:249-258` | def | R1 |
| stylua journey / gotcha | `features/format-on-save.md:7,33-46,66-70` | doc | R1 |
| `cmd = { "delance-langserver", "--stdio" }` | `after/lsp/pyright.lua:22` | config | R2 |
| pyright journey / gotcha | `features/lsp.md:21-34` | doc | R2 |
| `"nvim-treesitter/nvim-treesitter"` (no branch) | `lua/plugin_specs.lua:61-67` | config | R3 |
| `"nvim-treesitter/nvim-treesitter-textobjects"`, `branch="master"` | `lua/plugin_specs.lua:68-75` | config | R3 |
| `require("nvim-treesitter.configs")` | `lua/config/treesitter.lua:3`, `lua/config/treesitter-textobjects.lua:3` | call | R3 |
| `"nvim-treesitter/nvim-treesitter"` as dependency | `lua/plugin_specs.lua:560` (go.nvim) | config | R3 |
| lock-branch gotcha | `SKILL.md` Gotchas "lazy ignores a lock entry..." | doc | R3 |
| seed pin loop / treesitter step | `scripts/seed.lua:37-63,75-114` | impl | R3/R4 |
| `"phaazon/hop.nvim"` | `lua/plugin_specs.lua:513` | config | R4 |
| hop gotcha | `SKILL.md` Gotchas "`phaazon/hop.nvim` is gone" | doc | R4 |
| live fill-from-seed | `scripts/verify.sh:304-314` | impl | R3/R4 |
| `get_package("gofumpt"):install()` | `lua/plugin_specs.lua:526-527` | call | R5 |
| gofumpt mentions | `features/startup.md:6-7,27-37,48-52`; `SKILL.md` Gotchas "Downloads are the seed's job"; `seed.lua:147-153` | doc/impl | R5 |
| `create_dashboard` else-branch (no tracking) | `lua/config/dashboard-nvim.lua:382-385` | def | R6 |
| `update_ascii_art` guard | `lua/config/dashboard-nvim.lua:154-155` | def | R6 |
| dashboard gotcha | `features/dashboard.md:22-27,41-43` | doc | R6 |
| bootstrap clone | `lua/plugin_specs.lua:8-17` | def | R7 |
| `require("lazy").setup` | `lua/plugin_specs.lua:587` | call | R7 |
| `rand_colorscheme` | `lua/colorschemes.lua:136-141`, `init.lua:43` | call | R7 |
| `--bare` gotcha / startup | `SKILL.md` Gotchas "`--bare` fails at require(lazy)"; `features/startup.md:39-45,54-55` | doc | R7 |
| `require("custom.opencode")` | `lua/config/fzf-lua.lua:4` | call | R8 |
| opencode module | `lua/custom/opencode.lua:1-137` | def | R8 |
| `write_fake_opencode`, sink, doctor line, PATH comments | `scripts/verify.sh:84,90,110,212-224,283,330,434-435,672,677` | impl | R8 |
| opencode docs | `SKILL.md:67,114,143-146`; `features/fzf-lua.md:29` | doc | R8 |
| `expected_version = "0.11.5"` | `init.lua:16` | config | R9 |
| version mention | `features/startup.md:5`; `README.md:13` badge 0.11.2 | doc | R9 |
| `NVIM_BIN` default | `scripts/verify.sh:39` | impl | R9 (unchanged path) |
| `pull --ff-only` hint | `scripts/verify.sh:639`; `SKILL.md` Gotchas "Never driven" (deploying is the owner's `git -C ~/.config/nvim pull --ff-only`); `features/live-environment.md:15,42-43` | impl/doc | R10 |
| feature index "Known on the base" | `features/README.md:6-17` | doc | all |
| live journeys summary | `features/live-environment.md:28-31` | doc | R1, R2 |

---

## Impact Points (files that WILL need changes)
1. `lua/custom-autocmd.lua` — stylua via `vim.system` (R1, phase 1).
2. `features/format-on-save.md` — end states (R1, phase 1).
3. `after/lsp/pyright.lua` — drop the delance `cmd` (R2, phase 2).
4. `features/lsp.md` — end states (R2, phase 2).
5. `lua/config/dashboard-nvim.lua` — redraw every visible dashboard window (R6, phase 3).
6. `features/dashboard.md` — end states (R6, phase 3).
7. `lua/custom/opencode.lua` (delete), `lua/config/fzf-lua.lua` (R8, phase 4).
8. `scripts/verify.sh` — opencode/sink removal (phase 4), deploy hint (phase 5), moved-plugin live handling (phase 8), version-agnostic docs (phase 9 if needed).
9. `SKILL.md` — phases 4, 5, 6, 7, 8, 9 (sequenced).
10. `features/fzf-lua.md` (phase 4), `features/live-environment.md` (phase 5 hint text; phase 9 journey summary), `features/startup.md` (phases 6, 7, 9), `features/README.md` (phase 9).
11. `lua/plugin_specs.lua` — bootstrap (phase 6), mason (phase 7), hop (phase 8), treesitter/textobjects/tool-installer (phase 9).
12. `lua/colorschemes.lua` — fallback when the picked scheme cannot load (phase 6).
13. `scripts/seed.lua` — gofumpt special case (phase 7), moved plugins + lock rewrite (phase 8), treesitter main + stale parser cleanup + tree-sitter-cli ordering (phase 9).
14. `lua/config/treesitter.lua`, `lua/config/treesitter-textobjects.lua`, `init.lua`, `README.md` (phase 9).
15. Outside the repo: `/opt/nvim-linux-x86_64/*`, `~/.local/opt/`, `~/.config/nvim` (ff), `~/.config/nvim/lazy-lock.json` + `~/.local/share/nvim/{lazy,mason,site}` (Deploy, after land).

**This document describes. The plan files prescribe.**
