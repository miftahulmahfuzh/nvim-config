# Phase 9: Neovim 0.12.6 + nvim-treesitter main migration

**Plan set:** `FIX_BUGS_NVIM_0_12_PLAN.md`
**Analysis:** `docs/analyzer/20261104-102452-MRDD_code_analyzer.md`
**Satisfies:** R3 (nvim-treesitter cannot drift onto an incompatible branch), R9 (Neovim 0.12.6, every plugin loads, breaks fixed), R11 (evidence index + the Deploy runbook the coordinator runs after land)
**Depends on:** Phase 1, 2, 3, 8 (and through 8: 4, 5, 6, 7)
**Difficulty:** HARD
**Package:** `lua/` (`lua/config/treesitter*.lua`, `lua/plugin_specs.lua`), `init.lua`, `.claude/skills/verify-nvim-config/`

---

> **Set-wide execution rules** (plan index § Execution rules; they override any command below that disagrees):
> 1. `$WT` is **this phase's own worktree root** (`WT=$(git rev-parse --show-toplevel)`). Wave-1 phases run
>    concurrently in separate worktrees, so never `cd` into another phase's tree.
> 2. **No `git stash`** (the stash stack is shared by every worktree of the repo). Swap base and fix per file:
>    `SW=$(mktemp -d)`; BASE = `cp <path> "$SW/" && git show "$PHASE_BASE:<path>" ><path>`; FIX = `cp "$SW/<file>" <path>`,
>    where `PHASE_BASE=$(git rev-parse HEAD)` is recorded before this phase's first edit. A new file's BASE is `mv <path> "$SW/"`.
> 3. Commit with an explicit pathspec: `git add -- <new files>` then `git commit -m "..." -- <every path>`.
> 4. Evidence goes to `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-9.md`, this phase's own file (never a shared one),
>    written only **after every run of the phase is down** (the file is inside the snapshotted tree; a mid-run write makes
>    `doctor` print `code WARN`). It is committed as the phase's last commit:
>    `git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-9.md && git commit -m "docs(evidence): phase 9 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-9.md`.
>    `.workflows/` is tracked (the orchestrator commits the plan set); commit nothing else under it unless this plan says so.
> 5. Never `git push`. Never write `~/.config/nvim`, `~/.local/share/nvim` or `/opt/nvim-linux-x86_64`
>    (the **Deploy runbook** at the end of this file does, and only the coordinator runs it, after land).
> 6. Phase 9 also builds the set's `evidence.md` index from every `evidence-phase-*.md` (Step 14).

## Goal

The config runs on Neovim 0.12.6 with nvim-treesitter and nvim-treesitter-textobjects pinned to
their `main` branches: highlighting, indent, `af`/`if`/`ac`/`ic` and `gnn`/`grn`/`grm` work, go.nvim
loads and its treesitter commands work, nothing errors at startup, and every feature journey passes
on 0.12.6 in both `up --live` and `up`. The verify seed and harness know the new layout (parsers in
`stdpath("data")/site`, `tree-sitter-cli` from Mason). Neovim 0.12.6 is staged in `~/.local/opt/` with
0.11.5 backed up beside it. This file also holds the Deploy runbook the coordinator runs after land.

## Facts this plan rests on (measured while planning)

- **Base failure (R9).** The unchanged config on 0.12.6, run `1104-102617-1863253`: `v a f` in `app.py`
  gives `E5108: ...nvim-treesitter/lua/nvim-treesitter/tsrange.lua:27: attempt to call method 'start'
  (a nil value)`. Cause: frozen `master` `lua/nvim-treesitter/query.lua:251` calls
  `iter_matches(..., { all = false })`, which 0.12 ignores, so captures arrive as node lists.
  `00-up-messages.txt` = `Expect nvim version 0.11.5, but your current nvim version is 0.12.6. Use at
  your own risk!`.
- **Base failure (R3).** `lua/plugin_specs.lua:61-67` has no `branch`. lazy's
  `manage/git.lua:83-101` `get_branch` returns `plugin.branch`, else `refs/remotes/origin/HEAD`.
  GitHub's HEAD for nvim-treesitter is `main` (fresh clone ⇒ `main`), and `main` has no
  `lua/nvim-treesitter/configs.lua` (upstream clone `0195cd62`), so `require("nvim-treesitter.configs")`
  in `lua/config/treesitter.lua:3` fails on a fresh install. (The owner's own clone has
  `origin/HEAD -> origin/master` from when it was cloned, which is why it has not broken yet.)
- **nvim-treesitter `main`** (`0195cd62`): requires Neovim >= 0.12, `tar`, `curl`, `cc`, and
  `tree-sitter` CLI >= 0.26.1 (`do_compile` runs `tree-sitter build`, `install.lua:308`). Install dir
  defaults to `stdpath("data")/site` (`config.lua:10`), which lazy keeps on the rtp
  (`lazy/core/config.lua:308`). `install(langs)` is async, skips installed languages
  (`install.lua:515-520`), guards concurrent installs of one language (`installing[lang]`,
  `install.lua:474-485`), and returns a task with `:wait(ms)`. Queries are installed as **symlinks**
  `site/queries/<lang> -> <plugin dir>/runtime/queries/<lang>` (`do_link_queries`, `install.lua:343`).
  All 13 configured languages exist in `parsers.lua` (cpp pulls `c`, html pulls `html_tags`,
  javascript pulls `ecma`,`jsx`, markdown pulls `markdown_inline`). The plugin does not support
  lazy-loading (README).
- **Mason `tree-sitter-cli`**: `pkg:github/tree-sitter/tree-sitter@v0.27.1`, bin `tree-sitter`
  (live registry `mason/registries/github/mason-org/mason-registry/registry.json`).
  mason-tool-installer fires `User MasonToolsUpdateCompleted` after its run (`init.lua:172`).
- **Neovim 0.12.6 built-ins** (`runtime/doc/treesitter.txt:611-636`, `_core/defaults.lua:470-484`):
  Visual `an`/`in`/`]n`/`[n`/`]N`/`[N`, and public `vim.treesitter.select(target, count)` with
  `target` in `'parent'|'child'|'next'|'prev'|'extend_next'|'extend_prev'`
  (`runtime/lua/vim/treesitter.lua:520`). From Normal mode it starts a Visual selection
  (`_select.lua:382` reads `getpos('v')` = cursor). The built-in `an` falls back to
  `vim.lsp.buf.selection_range(count)` when the buffer has no parser. Normal-mode `grn` is 0.11+'s
  default LSP rename, so `grn` is mapped in `x` mode only.
- **0.12 ftplugins start treesitter themselves** for `help`, `lua`, `markdown`, `query`
  (`runtime/ftplugin/*.lua`), and `vim.treesitter.start()` clears `'syntax'`
  (`treesitter/highlighter.lua:171`). The config never runs `:filetype plugin indent on`, so Neovim
  registers the ftplugin/indent FileType handlers after `init.lua`, i.e. after this config's FileType
  autocmd: anything this config sets that an ftplugin or indent script also sets (`'syntax'` for
  markdown, `'indentexpr'`) must be applied after them (`vim.schedule`).
- **textobjects `main`** (`5c7b026`): `require("nvim-treesitter-textobjects").setup{ select = {...} }`
  plus explicit `vim.keymap.set({"x","o"}, lhs, function() require("nvim-treesitter-textobjects.select")
  .select_textobject(capture, "textobjects") end)`. It requires no `nvim-treesitter` module, so
  `event = "VeryLazy"` stays (the keymaps exist before any journey; `up` waits for VeryLazy).
- **go.nvim.** Live `81bb94c` has unguarded `require('nvim-treesitter.ts_utils')` in
  `lua/go/ts/go.lua:2` (reached by `:GoCmt`, `:GoFillStruct`, test-name lookup) and in
  `lua/go/ts/nodes.lua:2`; on `main` those modules do not exist. Upstream master `5622d97` guards
  them but `lua/go/ts/nodes.lua:9` requires `guihua.ts_utils`, which the live guihua.lua (`ef44ba4`)
  does not have (it was added upstream with go.nvim `9a28898`, 2026-04-02). **`4755deffda8eeb0ceed53b535cce29f0e29a640a`**
  (2026-03-31, "fix treesitter node recursion for nvim v0.12", on master) is the newest go.nvim
  commit that is main-aware (`pcall(require, 'nvim-treesitter.config')` switch in `go.lua:234`,
  `ts/nodes.lua:2-15`, `comment.lua:9-12`, `ts/textobjects.lua` returns early on main) **and** only
  needs guihua modules the live guihua has (`guihua.ts_obsolete.{ts_utils,query,locals,parsers}`,
  gui, input, listview, log, lspkind, panel: all present). This phase bumps go.nvim to that commit.
- **Other plugins that name nvim-treesitter modules** (live dirs): guihua.lua `util.lua:244,343`
  (pcall), `ts_obsolete/*` (loaded only through go.nvim at 4755def, which handles main); nvim-bqf
  `preview/treesitter.lua:115-136` (pcall, explicit main/master switch); render-markdown and
  nvim-autopairs (no reference); rose-pine (comment only). None needs a change.
- **verify harness.** `--live` copies only `lazy/ mason/ rplugin.vim` (`verify.sh:306-307`); live has
  no `~/.local/share/nvim/site` before Deploy. Lazy's clones are partial (`remote.origin.promisor=true`),
  so asking git for a missing object can try a network fetch; git here is 2.43 (no `--no-lazy-fetch`).
- `/opt/nvim-linux-x86_64` is 0.11.5, 39 MB, every file owned by `miftah`. `~/.local/opt` does not
  exist yet. A sha256-verified tarball is at
  `/tmp/claude-1000/-home-miftah--config-nvim/d03b1b26-53bd-4fb4-b0b2-da62e63b4892/scratchpad/dl/nvim-linux-x86_64.tar.gz`
  (re-verify; download again if gone).

## Interface Contract

**Deletes:**
- `require("nvim-treesitter.configs").setup{...}` in `lua/config/treesitter.lua` and
  `lua/config/treesitter-textobjects.lua` (whole bodies replaced).
- Keymap `grc` (Visual, was `incremental_selection.scope_incremental`): no replacement.
- `seed.lua` treesitter step's `master` path (`TSInstallSync`, runtime-file `missing()`), base
  `seed.lua:75-116`; the step moves below the Mason step.

**Renames:** none.

**Creates:**
- Keymaps: `n gnn`, `x grn`, `x grm` (onto `vim.treesitter.select`); `x/o af if ac ic` (onto
  `nvim-treesitter-textobjects.select.select_textobject`).
- Augroup `config_treesitter` (FileType: `vim.treesitter.start`, markdown `'syntax'` back on,
  `'indentexpr'` = `v:lua.require'nvim-treesitter'.indentexpr()` except yaml).
- `verify.sh`: function `seed_commit_unknown_to_live`; live-mode copy of `$LIVE_DATA/site`; the entry
  `PLUGIN_EXTRA_DATA[nvim-treesitter]="site/parser site/parser-info site/queries"` in phase 8's hook;
  `repoint_data "$dir" "$SEED/data"` after phase 8's replacement loop when anything was replaced.
  No new meta key and no second copy path (parsers reach `--live` only through phase 8's hook).
- `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-9.md` and the set's index
  `.workflows/plan/fix-bugs-nvim-0-12/evidence.md` (built from every `evidence-phase-*.md`).
- `features/treesitter.md`.
- Outside the repo: `~/.local/opt/nvim-0.12.6/nvim-linux-x86_64/` (staged 0.12.6),
  `~/.local/opt/nvim-0.11.5/nvim-linux-x86_64/` (backup), the re-seeded verify seed (seed lock
  `go.nvim` = `4755def…`, `nvim-treesitter`/`-textobjects` = `main@<tip>`, `data/nvim/site/` with 13
  parsers, Mason `tree-sitter-cli`).

**Signature changes:**
- `lua/plugin_specs.lua` nvim-treesitter spec: `lazy = true`, no branch → `branch = "main"`, `lazy = false`.
- textobjects spec: `branch = "master"` → `branch = "main"`.
- mason-tool-installer `ensure_installed`: `{ "gofumpt", "stylua" }` → `{ "gofumpt", "stylua", "tree-sitter-cli" }`.
- `init.lua:16` `expected_version = "0.11.5"` → `"0.12.6"`.
- `seed.lua` Mason `names` gains `"tree-sitter-cli"`.
- `verify.sh` `--live` replacement test: phase 8's "moved branch/url" test **OR** `seed_commit_unknown_to_live`.

**Requires (from earlier phases):**
- Phase 8 (contract in phase-8.md, quoted where Step 7 edits it): hop spec is `smoka7/hop.nvim`;
  `seed.lua` treats a plugin as MOVED when the spec's `branch` differs from the lock entry's or its url
  differs from the entry's `url` (else the live dir's origin), follows the spec for it and logs
  `MOVED plugin <name>: ...`; `seed.lua` writes the seed lock (`SEED_LOCK_OUT` -> `$SEED/lazy-lock.json`)
  from what is checked out, one `{ "branch", "commit", "url" }` entry per plugin; `verify.sh` has
  `origin_url DIR`, the `declare -A PLUGIN_EXTRA_DATA=()` hook, and in `cmd_up`'s `live)` arm a loop over
  `"$SEED/data/nvim/lazy"/*/` that fills a missing plugin (`filled`) or replaces one whose seed lock
  branch differs from the live lock's or whose origin url differs (`replaced`, meta
  `replaced_from_seed`, `evidence/00-up-replaced.txt`, lock entry copied, `PLUGIN_EXTRA_DATA[name]`
  paths copied from the seed). Phase 8 re-seeded once (hop on smoka7). Phase 8 does **not** copy
  `site/` and does not detect commit-only bumps: Step 7 adds exactly those, inside phase 8's loop.
- Phase 7: `seed.lua` Mason step without the `is_installing` special case; `names` is still
  `local names = { "gofumpt", "stylua" }`.
- Phase 6: `plugin_specs.lua` bootstrap rewritten (line numbers below are base numbers; find blocks by text).
- Phases 1, 2, 3: their journeys and `features/*.md` end states are final; this phase re-drives them on 0.12.6.
- Phases 4, 5: no opencode, deploy hint is `fetch` + `merge --ff-only`.
- Every earlier phase committed its own `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-N.md` (N = 1..8).
- Phase 4 removed `$dir/bin`, `sink/`, `VERIFY_SINK` and changed `run_path` to take no argument; nothing
  in this phase references them.

**Leaves alone (owned by others):** `lua/custom-autocmd.lua` (1), `after/lsp/pyright.lua` (2),
`lua/config/dashboard-nvim.lua` (3), the hop spec and `lua/config/hop.lua` (8), the bootstrap/
`lazy.setup` guard and `colorschemes.lua` (6), mason.nvim's `config` (7), `cmd_live` (5),
`features/{format-on-save,lsp,dashboard,fzf-lua,git,tmux-bindings,img2braille,editing-mappings}.md`
(phase 8 documented hop's `f`/`F` journey in `editing-mappings.md`; there is no `hop.md`) except where a 0.12 breakage found in Step 13 forces an end-state change (then that file's owner
phase has landed and this phase edits only the changed line, and says so in evidence).
`/opt/nvim-linux-x86_64`, `~/.config/nvim`, `~/.local/share/nvim` are **never written** by this
phase (Deploy does it).

## Files

| File | Action | What changes |
|---|---|---|
| `init.lua:16` | modify | `expected_version = "0.12.6"` |
| `README.md:13` | modify | badge `Neovim-0.11.2` → `Neovim-0.12.6` |
| `lua/plugin_specs.lua:60-75` (base) | modify | nvim-treesitter `branch = "main"`, `lazy = false`; textobjects `branch = "main"` |
| `lua/plugin_specs.lua:535-538` (base) | modify | `tree-sitter-cli` in mason-tool-installer `ensure_installed` |
| `lua/config/treesitter.lua` | rewrite | `main` API: parser install, FileType highlight/indent, `gnn`/`grn`/`grm` |
| `lua/config/treesitter-textobjects.lua` | rewrite | `main` API: `setup{select=…}` + `af`/`if`/`ac`/`ic` keymaps |
| `.claude/skills/verify-nvim-config/scripts/seed.lua` | modify | `tree-sitter-cli` in Mason names; treesitter step after Mason, `main` only, stale `parser/` cleanup |
| `.claude/skills/verify-nvim-config/scripts/verify.sh` | modify | `PLUGIN_EXTRA_DATA[nvim-treesitter]`, `seed_commit_unknown_to_live` + its clause in phase 8's loop, live copy of `site/`, repoint after a replacement |
| `.claude/skills/verify-nvim-config/SKILL.md` | modify | seed counts, `--live` copy list + commit-bump rule (phase 8's bullet), the treesitter clause of phase 8's "lazy never re-targets" gotcha, new treesitter + `VERIFY_NVIM` gotchas |
| `.claude/skills/verify-nvim-config/features/treesitter.md` | create | journeys + end states |
| `.claude/skills/verify-nvim-config/features/README.md` | rewrite | header, treesitter row, hop in the editing-mappings row, "Known on the base" column (handoffs of phases 1-8) |
| `.claude/skills/verify-nvim-config/features/live-environment.md` (`:21`, `:24-31`, `:39-40`; not phase 5's deploy lines `:13-14`/`:43`) | modify | doctor line, `live` end state and journey summary on 0.12.6; `site/` copy + `replaced_from_seed` gotcha |
| `.claude/skills/verify-nvim-config/features/startup.md` (`:5`, phase 7's Mason Sub-features bullet) | modify | `expects 0.12.6`; `tree-sitter-cli` named with gofumpt/stylua |
| `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-9.md` | create | `## Phase 9` (committed, Step 15) |
| `.workflows/plan/fix-bugs-nvim-0-12/evidence.md` | create | the set's index: per-requirement before/after table built from `evidence-phase-1..9.md` (committed, Step 15) |

## Implementation Steps

All `verify.sh` commands in this file run from the worktree root with:

```sh
cd "$WT"   # this phase's own worktree root (index § Execution rules)
export VERIFY_NVIM=$HOME/.local/opt/nvim-0.12.6/nvim-linux-x86_64/bin/nvim
V=.claude/skills/verify-nvim-config/scripts/verify.sh
VH=$HOME/.local/state/nvim-config-verify
P9=$VH/phase9-evidence; mkdir -p "$P9"     # durable evidence outside the repo (not a run dir: `ls` lists only [0-9]* dirs)
UP=$P9/upstream; mkdir -p "$UP"           # scratch clones of upstream repos
```

`VERIFY_NVIM` must be exported for **every** `verify.sh` call, `seed` included (each invocation reads
it; nvim-treesitter `main` needs Neovim >= 0.12, so seeding under 0.11.5 would fail).

### Step 0: Stage 0.12.6 and back up 0.11.5 (outside the repo)
**File:** none in the repo. Writes only `~/.local/opt/` and a scratch dir.
**Code:**
```sh
set -euo pipefail
DL=$P9/dl                                   # this phase's own download dir (setup block above)
TGZ=$DL/nvim-linux-x86_64.tar.gz
SHA=474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87
# The planning session's verified copy, read only (never written; may be gone or unreadable).
PRE=/tmp/claude-1000/-home-miftah--config-nvim/d03b1b26-53bd-4fb4-b0b2-da62e63b4892/scratchpad/dl/nvim-linux-x86_64.tar.gz
mkdir -p "$DL"
if [ ! -f "$TGZ" ] && [ -r "$PRE" ]; then cp "$PRE" "$TGZ"; fi
if ! echo "$SHA  $TGZ" | sha256sum -c - >/dev/null 2>&1; then
  curl -fL -o "$TGZ" https://github.com/neovim/neovim/releases/download/v0.12.6/nvim-linux-x86_64.tar.gz
fi
echo "$SHA  $TGZ" | sha256sum -c -                                   # must print: OK
mkdir -p ~/.local/opt/nvim-0.12.6
[ -e ~/.local/opt/nvim-0.12.6/nvim-linux-x86_64 ] || tar -xzf "$TGZ" -C ~/.local/opt/nvim-0.12.6
~/.local/opt/nvim-0.12.6/nvim-linux-x86_64/bin/nvim --version | head -1   # NVIM v0.12.6
mkdir -p ~/.local/opt/nvim-0.11.5
[ -e ~/.local/opt/nvim-0.11.5/nvim-linux-x86_64 ] || cp -a /opt/nvim-linux-x86_64 ~/.local/opt/nvim-0.11.5/
~/.local/opt/nvim-0.11.5/nvim-linux-x86_64/bin/nvim --version | head -1   # NVIM v0.11.5
diff -r /opt/nvim-linux-x86_64 ~/.local/opt/nvim-0.11.5/nvim-linux-x86_64 && echo backup-identical
```
**Impact:** none on the owner's nvim (`/opt` is only read). Record the three printed lines in evidence.

### Step 1: Record the base on 0.12.6 (must fail before any edit)
**File:** none edited. The worktree is at phase 8's tip (phases 1-8 landed), clean.
**Code:**
```sh
git status --porcelain                     # empty
base_journey() {   # $1 = "--live" or ""
  out=$($V up $1); echo "$out"; RUN=$(sed -n 's/^RUN=//p' <<<"$out")
  cat ~/.local/state/nvim-config-verify/$RUN/evidence/00-up-messages.txt
  $V doctor $RUN
  $V note $RUN "phase 9 BASE on 0.12.6 (phases 1-8 tip, nvim-treesitter master)"
  $V lua $RUN 'tostring(vim.version())'
  $V keys $RUN : e Space app.py Enter
  $V keys $RUN g g v a f
  $V keys $RUN Escape Escape
  $V lua $RUN 'vim.v.errmsg'
  $V lua $RUN 'require("lazy.core.config").plugins["nvim-treesitter"].branch or "(spec has no branch)"'
  $V cli $RUN sh -c 'git -C "$XDG_DATA_HOME/nvim/lazy/nvim-treesitter" rev-parse --abbrev-ref HEAD; git -C "$XDG_DATA_HOME/nvim/lazy/nvim-treesitter" log -1 --format=%h'
  $V down $RUN
}
base_journey --live
base_journey ""
# R3: what a fresh install gets (no run can show it offline; the seed's clone is read-only):
git ls-remote --symref https://github.com/nvim-treesitter/nvim-treesitter HEAD | head -1
# A fresh clone, exactly as an unpinned install gets it (the default branch). Must exist before the ls,
# or the ls's "No such file" proves nothing.
[ -d "$UP/nvim-treesitter/.git" ] || GIT_CONFIG_GLOBAL=/dev/null git clone -q --filter=blob:none https://github.com/nvim-treesitter/nvim-treesitter "$UP/nvim-treesitter"
git -C "$UP/nvim-treesitter" rev-parse --abbrev-ref HEAD          # main
ls "$UP/nvim-treesitter/lua/nvim-treesitter/configs.lua" 2>&1
sed -n 83,101p ~/.local/share/nvim/lazy/lazy.nvim/lua/lazy/manage/git.lua
```
Note: `cli` runs `sh -c` in the run's env, where `XDG_DATA_HOME` is set (`run_env`); `cli` refuses
literal owner paths, not the run's.
**Expected (both modes):** `00-up-messages.txt` contains `Expect nvim version 0.11.5, but your current
nvim version is 0.12.6`; version `0.12.6`; `vim.v.errmsg` contains
`tsrange.lua:27: attempt to call method 'start' (a nil value)`; spec branch `(spec has no branch)`;
plugin dir on `master` / `42fc28b`. `ls-remote` prints `ref: refs/heads/main	HEAD`; the `ls` prints
`No such file or directory`; `get_branch` lines show the `remotes/origin/HEAD` fallback.
**Impact:** evidence only. If `vaf` does **not** fail here, stop and report: the premise of R9's fix is gone.

### Step 2: Version check
**File:** `init.lua:16`
**Code:**
```lua
local expected_version = "0.12.6"
```
**File:** `README.md:13`
**Code:**
```html
      <img src="https://img.shields.io/badge/Neovim-0.12.6-blueviolet.svg?style=flat-square&logo=Neovim&logoColor=green" alt="Neovim minimum version"/>
```
**Impact:** on 0.11.5 the owner now sees `Expect nvim version 0.12.6 ...` until Deploy swaps the
binary (Deploy runs right after land, so the window is the land→Deploy gap only).

### Step 3: Plugin specs
**File:** `lua/plugin_specs.lua:60-75` (base numbering; after phase 6 find the block starting
`    "nvim-treesitter/nvim-treesitter",` that has `build = ":TSUpdate"`). Replace both specs (from the
`{` before `"nvim-treesitter/nvim-treesitter",` through the `},` after the textobjects `config`) with:
**Code:**
```lua
  {
    "nvim-treesitter/nvim-treesitter",
    -- `main`, the rewrite for Neovim 0.12+. `master` is archived and its textobjects break on 0.12;
    -- without a pin a fresh install follows GitHub's default branch, whatever the lock says.
    branch = "main",
    -- main does not support lazy-loading: config.treesitter's FileType autocmd must exist before
    -- the first buffer is read.
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("config.treesitter")
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = "VeryLazy",
    branch = "main",
    config = function()
      require("config.treesitter-textobjects")
    end,
  },
```
**File:** `lua/plugin_specs.lua:535-538` (base; the `ensure_installed` inside
`require("mason-tool-installer").setup {`).
**Code:**
```lua
        ensure_installed = {
          "gofumpt",
          "stylua",
          -- nvim-treesitter `main` compiles parsers with the `tree-sitter` CLI (>= 0.26.1).
          "tree-sitter-cli",
        },
```
**Impact:** the go.nvim spec still lists `"nvim-treesitter/nvim-treesitter"` as a dependency; with
`lazy = false` that is a no-op. go.nvim is **not** changed in the spec (its bump is a lock change, Step 8).

### Step 4: Rewrite `lua/config/treesitter.lua`
**File:** `lua/config/treesitter.lua` (whole file; tabs, as before)
**Code:**
```lua
-- nvim-treesitter `main` (Neovim 0.12+). The plugin only installs parsers and queries, into
-- stdpath("data")/site. Highlighting, indentation and incremental selection are Neovim's own,
-- switched on here per buffer.

local parsers = {
	"python",
	"http",
	"cpp",
	"lua",
	"vim",
	"json",
	"toml",
	"markdown",
	"markdown_inline",
	"html",
	"css",
	"javascript",
	"go",
}

-- Install the parsers that are missing (asynchronous; nothing to do once all are installed).
-- Compiling needs the `tree-sitter` CLI, which Mason installs (tree-sitter-cli in
-- mason-tool-installer, plugin_specs.lua). On a first start Mason installs it after VimEnter.
local function install_missing()
	if vim.fn.executable("tree-sitter") ~= 1 then
		return false
	end
	local ts = require("nvim-treesitter")
	local installed = ts.get_installed("parsers")
	local missing = vim.tbl_filter(function(lang)
		return not vim.list_contains(installed, lang)
	end, parsers)
	if #missing > 0 then
		ts.install(missing)
	end
	return true
end

if not install_missing() then
	vim.api.nvim_create_autocmd("User", {
		pattern = "MasonToolsUpdateCompleted",
		once = true,
		callback = function()
			install_missing()
		end,
		desc = "Install treesitter parsers once Mason has the tree-sitter CLI",
	})
end

-- Filetypes that keep Vim's regex syntax on top of treesitter highlighting.
local keep_regex_syntax = { markdown = true }
-- Filetypes whose treesitter indentation is worse than Vim's own.
local no_treesitter_indent = { yaml = true }

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("config_treesitter", { clear = true }),
	callback = function(args)
		local buf, ft = args.buf, args.match
		if ft == "help" then
			return
		end
		local lang = vim.treesitter.language.get_lang(ft)
		if not lang then
			return
		end
		local ok_add, added = pcall(vim.treesitter.language.add, lang)
		if not (ok_add and added) then
			return
		end
		if not pcall(vim.treesitter.start, buf, lang) then
			return
		end
		local indent = not no_treesitter_indent[ft] and vim.treesitter.query.get(lang, "indents") ~= nil
		-- Neovim registers the ftplugin and indent FileType handlers after init.lua, so they run
		-- after this one: ftplugin/markdown.lua restarts treesitter (which clears 'syntax') and
		-- indent scripts set 'indentexpr'. Apply these two after them.
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			if keep_regex_syntax[ft] then
				vim.bo[buf].syntax = "ON"
			end
			if indent then
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end
		end)
	end,
	desc = "Treesitter highlighting and indentation where a parser is installed",
})

-- Incremental selection. nvim-treesitter `main` dropped its module; Neovim 0.12 has it built in
-- (Visual `an`/`in`). The old keys stay: `gnn` starts, `grn` grows, `grm` shrinks. `grc`
-- (scope_incremental) has no built-in equivalent and is gone. Normal-mode `grn` stays Neovim's
-- LSP rename. Like the built-in `an`/`in`, fall back to LSP selection ranges without a parser.
local function select_node(target, lsp_direction)
	return function()
		if vim.treesitter.get_parser(nil, nil, { error = false }) then
			vim.treesitter.select(target, vim.v.count1)
		else
			vim.lsp.buf.selection_range(lsp_direction * vim.v.count1)
		end
	end
end

vim.keymap.set("n", "gnn", select_node("parent", 1), { desc = "Start treesitter node selection" })
vim.keymap.set("x", "grn", select_node("parent", 1), { desc = "Grow selection to the parent node" })
vim.keymap.set("x", "grm", select_node("child", -1), { desc = "Shrink selection to the child node" })
```
**Impact:** `require("nvim-treesitter.configs")` is gone from the config. In a fenced run the
install is a no-op when the parsers are present (seeded, or filled from the seed in `--live`), and
does nothing when `tree-sitter` is absent (live Mason before Deploy).

### Step 5: Rewrite `lua/config/treesitter-textobjects.lua`
**File:** `lua/config/treesitter-textobjects.lua` (whole file; tabs)
**Code:**
```lua
-- nvim-treesitter-textobjects `main`: setup() takes the options, the keymaps are set here.

require("nvim-treesitter-textobjects").setup({
	select = {
		-- Automatically jump forward to textobj, similar to targets.vim
		lookahead = true,
		-- The select mode per capture (default is charwise 'v')
		selection_modes = {
			["@function.inner"] = "V", -- linewise
			["@function.outer"] = "V", -- linewise
			["@class.outer"] = "V", -- linewise
			["@class.inner"] = "V", -- linewise
			["@parameter.outer"] = "v", -- charwise
		},
		-- true would extend every textobject with the whitespace around it, like the built-in `ap`
		include_surrounding_whitespace = false,
	},
})

-- The capture groups come from the plugin's queries/<lang>/textobjects.scm.
local textobjects = {
	{ lhs = "af", capture = "@function.outer", desc = "Select outer part of a function" },
	{ lhs = "if", capture = "@function.inner", desc = "Select inner part of a function" },
	{ lhs = "ac", capture = "@class.outer", desc = "Select outer part of a class region" },
	{ lhs = "ic", capture = "@class.inner", desc = "Select inner part of a class region" },
}

for _, obj in ipairs(textobjects) do
	vim.keymap.set({ "x", "o" }, obj.lhs, function()
		require("nvim-treesitter-textobjects.select").select_textobject(obj.capture, "textobjects")
	end, { desc = obj.desc })
end
```
**Impact:** `vaf` etc. no longer go through `nvim-treesitter.configs`/`tsrange.lua`.

### Step 6: `seed.lua`: tree-sitter-cli first, then `main` parsers
**File:** `.claude/skills/verify-nvim-config/scripts/seed.lua`
**Change A** (Mason step, base `:128`, unchanged by phases 7/8):
```lua
  local names = { "gofumpt", "stylua", "tree-sitter-cli" }
```
**Change B:** delete the whole `step("treesitter parsers", function() ... end)` block (base
`:75-116`; after phase 8 it directly follows phase 8's `step("seed lock", function() ... end)` block.
Anchor on the text `step("treesitter parsers", function()` through its closing `end)`), and insert this
block after the Mason step's closing `end)` (the step phase 7 rewrote) and before `log("done")`:
```lua
-- After the Mason step: nvim-treesitter `main` compiles parsers with the `tree-sitter` CLI, which
-- Mason just installed (tree-sitter-cli). Parsers and queries go into stdpath("data")/site.
step("treesitter parsers", function()
  -- The parsers config/treesitter.lua installs.
  local langs = {
    "python",
    "http",
    "cpp",
    "lua",
    "vim",
    "json",
    "toml",
    "markdown",
    "markdown_inline",
    "html",
    "css",
    "javascript",
    "go",
  }
  lazy.load { plugins = { "nvim-treesitter" } }
  assert(pcall(require, "nvim-treesitter.config"), "nvim-treesitter is not on its `main` branch")
  -- A plugin dir that was on `master` keeps master's untracked build output after the checkout
  -- to `main`. It is on the runtimepath, so nvim would load those stale parsers.
  local plugin_dir = require("lazy.core.config").plugins["nvim-treesitter"].dir
  for _, sub in ipairs { "parser", "parser-info" } do
    if vim.uv.fs_stat(plugin_dir .. "/" .. sub) then
      vim.fn.delete(plugin_dir .. "/" .. sub, "rf")
      log("WARN plugin nvim-treesitter: removed %s/ left over from master", sub)
    end
  end
  assert(vim.fn.executable("tree-sitter") == 1, "no tree-sitter CLI on PATH (Mason tree-sitter-cli)")
  local ts = require("nvim-treesitter")
  local function missing()
    local installed = ts.get_installed("parsers")
    return vim.tbl_filter(function(l)
      return not vim.list_contains(installed, l)
    end, langs)
  end
  local todo = missing()
  if #todo > 0 then
    ts.install(todo, { summary = true }):wait(600000)
  end
  for _, f in ipairs(vim.fn.glob(vim.fn.stdpath("data") .. "/tree-sitter-*", false, true)) do
    vim.fn.delete(f, "rf")
  end
  assert(#missing() == 0, "parsers missing after install: " .. table.concat(missing(), ","))
end)
```
Also update the file's header comment line 3-4 to:
```lua
-- Installs/restores every lazy plugin, installs every Mason package the config names, then
-- compiles the treesitter parsers the config installs (they need Mason's tree-sitter CLI).
-- Writes one line per step to $SEED_LOG.
```
**Impact:** the seed log order becomes `lazy ...`, plugin WARNs, `mason ...` lines, `treesitter
parsers`, `done`. The `master` install path is removed: the config is `main`-only now, and a revert
of this phase restores the old seed.lua together with the old config.

### Step 7: `verify.sh`: `--live` knows `site/` and lock-only bumps (on top of phase 8's loop)
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh`. Every hunk is anchored on text as
phase 8 leaves the file (phase 4 has shifted all line numbers; never use base numbers here). Phase 8
created the moved-plugin loop, `origin_url`, the `PLUGIN_EXTRA_DATA` hook, the `replaced_from_seed`
meta key and the `00-up-replaced.txt` evidence file; this step **extends** that machinery and adds no
second copy path. There is no `site_filled_from_seed` key and no separate fill loop: parsers and
queries reach a `--live` run only through the hook, when nvim-treesitter is replaced.

**7a. Register nvim-treesitter's data with phase 8's hook.** Phase 8 leaves this line (inserted after
`LIVE_TMUX_CONF=...`):
```bash
declare -A PLUGIN_EXTRA_DATA=()
```
Replace it with:
```bash
declare -A PLUGIN_EXTRA_DATA=(
  # nvim-treesitter `main` installs parsers (+ their revision info) and query links under site/.
  [nvim-treesitter]="site/parser site/parser-info site/queries"
)
```

**7b. `seed_commit_unknown_to_live`.** Insert right after phase 8's line
`origin_url() { git -C "$1" config --get remote.origin.url 2>/dev/null | sed 's#/*$##; s#\.git$##'; }`:
```bash

# True when the seed lock pins plugin $1 to a commit the clone $2 (the run's copy of the live
# plugin) has never fetched: a plugin bumped on purpose in the seed lock (go.nvim's commit bump).
# A live clone that is merely newer than the seed already contains the seed's commit and is kept.
# After `seed --update`, every plugin newer upstream than live qualifies.
seed_commit_unknown_to_live() {
  local p=$1 clone=$2 commit
  commit="$(jq -r --arg p "$p" '.[$p].commit // empty' "$SEED/lazy-lock.json" 2>/dev/null || true)"
  [ -n "$commit" ] && [ -d "$clone/.git" ] || return 1
  # In an empty network namespace: lazy's clones are partial (blob:none) and git 2.43 would try to
  # fetch a missing object from the promisor remote.
  ! unshare --map-current-user -n git -C "$clone" cat-file -e "$commit^{commit}" 2>/dev/null
}
```

**7c. Copy live's `site/`.** In `cmd_up`'s `live)` arm, phase 8 leaves these two lines unchanged
from the base:
```bash
      cp -a "$LIVE_DATA/lazy" "$LIVE_DATA/mason" "$dir/xdg/data/nvim/"
      [ -f "$LIVE_DATA/rplugin.vim" ] && cp -a "$LIVE_DATA/rplugin.vim" "$dir/xdg/data/nvim/"
```
Insert between them (so it runs before the `repoint_data "$dir" "$(dirname "$LIVE_DATA")"` that
follows, which repoints live's `site/queries/*` links at the run's copy):
```bash
      # nvim-treesitter `main` keeps parsers and query links in ~/.local/share/nvim/site.
      [ -d "$LIVE_DATA/site" ] && cp -a "$LIVE_DATA/site" "$dir/xdg/data/nvim/"
```
Before Deploy live has no `site/`, so this copies nothing; after Deploy it is the owner's parsers.
In the same arm, phase 8's header comment `Only lazy/, mason/ and` / `# rplugin.vim: the rest of
~/.local/share/nvim ...` becomes `Only lazy/, mason/, site/ and` / `# rplugin.vim: ...` (comment only;
the rest of the sentence unchanged), so the code and its comment agree.

**7d. One more replacement clause.** Phase 8's loop has exactly this test line:
```bash
          [ "$sb" != "${lb:-$sb}" ] || [ "$su" != "$lu" ] || continue
```
It becomes:
```bash
          [ "$sb" != "${lb:-$sb}" ] || [ "$su" != "$lu" ] || seed_commit_unknown_to_live "$p" "$dir/xdg/data/nvim/lazy/$p" || continue
```
Everything after it in the loop body (the `00-up-replaced.txt` line, `rm -rf` + `cp -a` of the
plugin dir, the lock entry copy, the `PLUGIN_EXTRA_DATA` loop, `replaced="$replaced $p"`) is phase
8's code, unchanged.

**7e. Repoint the seed's query links after a replacement.** The hook copies `site/queries/<lang>`
symlinks that point into `$SEED/data/nvim/lazy/nvim-treesitter/runtime/queries/`. Phase 8's loop is
followed by:
```bash
        done
        flock -u 9
      fi
```
Insert between `done` and `flock -u 9`:
```bash
        # Links copied from the seed (PLUGIN_EXTRA_DATA, e.g. site/queries/*) point into the seed's
        # plugin dirs; point them at the run's copies, as seeded mode does.
        if [ -n "$replaced" ]; then repoint_data "$dir" "$SEED/data"; fi
```
(An `if`, not `[ ] &&`, so `set -e` never sees a false final status.)

No meta, stderr or doctor change: phase 8's `replaced_from_seed` key, its stderr line and doctor's
`replaced from seed (spec moved): ...` already name the replaced plugins, and
`evidence/00-up-replaced.txt` lists each `+ site/... from the seed` line.

**Impact:** before Deploy, `up --live` replaces `nvim-treesitter` and `nvim-treesitter-textobjects`
(branch `master` -> `main`), `hop.nvim` (url, phase 8) and, after Step 8 stage 2, `go.nvim` (commit
unknown to live), and nvim-treesitter's replacement brings `site/parser`, `site/parser-info` and
`site/queries` from the seed. After Deploy nothing is replaced and live's own `site/` is used. A
seeded run is unchanged (`cp -al` of `data/nvim` already includes `site/`, and seeded mode already
runs `repoint_data "$dir" "$SEED/data"`). Syntax check: `bash -n .claude/skills/verify-nvim-config/scripts/verify.sh`.

### Step 8: Re-seed in two stages (outside the repo: the verify seed only)
Two stages so the go.nvim bump has its own before/after.

**Seed guard (invariant 5), before each `seed`:** wait until no verify run is up, because a seed
rewrites the shared seed under any seeded run still alive and that run's `doctor` would FAIL its
`seed` line: `until [ -z "$($V ls | awk '$2 == "up"')" ]; do sleep 30; done` (Monitor tool with this
until-loop; never a foreground sleep). Down this phase's own runs first.

**Stage 1** (working tree has Steps 2-7; seed lock still pins go.nvim `81bb94c`):
```sh
$V seed 2>&1 | tee "$P9/seed-stage1.log"; cp ~/.local/state/nvim-config-verify/.seed/seed.log "$P9/seed-stage1.seed.log"
jq '{"nvim-treesitter","nvim-treesitter-textobjects","hop.nvim","go.nvim"}' ~/.local/state/nvim-config-verify/.seed/lazy-lock.json
ls ~/.local/state/nvim-config-verify/.seed/data/nvim/site/parser
ls ~/.local/state/nvim-config-verify/.seed/data/nvim/lazy/nvim-treesitter/parser 2>&1
~/.local/state/nvim-config-verify/.seed/data/nvim/mason/bin/tree-sitter --version
```
(`tee` to a file, never `head`: SKILL.md zsh gotcha.) **Expected:** no `FAIL` line;
`MOVED plugin nvim-treesitter: branch master -> main; not pinned to the lock's master@42fc28b, follows the spec: main@<sha7>`
and the same line for `nvim-treesitter-textobjects` (`master@5ca4aaa` -> `main@<sha7>`), and **no** MOVED line
for `hop.nvim` (phase 8's seed lock already records smoka7's `url`);
`ok   mason tree-sitter-cli`; `WARN plugin nvim-treesitter: removed parser/ left over from master`
(and `parser-info/`); `ok   treesitter parsers`; `done`; seed lock `nvim-treesitter` and
`nvim-treesitter-textobjects` on `main`; `go.nvim` still `81bb94c…`; `site/parser` lists at least the
13 `.so` (+`c.so`); the plugin's `parser` dir is gone; `tree-sitter 0.27.1`; `meta` `mason=10`.

Then run Step 9's **go.nvim before** journey (both modes).

**Stage 2:** pin go.nvim in the seed lock (phase 8's entry format: only `commit` changes; `branch`
and `url` stay, so seed.lua does not see a move and simply pins the new commit) and re-seed (seed
guard first):
```sh
SEED_LOCK=$HOME/.local/state/nvim-config-verify/.seed/lazy-lock.json
tmp=$(mktemp) && jq '."go.nvim".commit = "4755deffda8eeb0ceed53b535cce29f0e29a640a"' "$SEED_LOCK" >"$tmp" && cp "$tmp" "$SEED_LOCK" && rm -f "$tmp"
jq -c '."go.nvim"' "$SEED_LOCK"                                      # branch master, the new commit, url ray-x/go.nvim
$V seed 2>&1 | tee "$P9/seed-stage2.log"; cp ~/.local/state/nvim-config-verify/.seed/seed.log "$P9/seed-stage2.seed.log"
jq '."go.nvim"' "$SEED_LOCK"                                         # commit 4755deff…, url kept
git -C ~/.local/state/nvim-config-verify/.seed/data/nvim/lazy/go.nvim rev-parse HEAD   # 4755deff…
```
**Impact:** shared verify state only (invariant 5: phase 9 is the only seeder in its wave). The
seed lock edit is how a single-plugin bump is expressed (the repo's `lazy-lock.json` is gitignored).

### Step 9: Prove (both modes): see **Verification → Proof** for the journeys and pass conditions.
Drive J1-J11 on `up --live` and on `up`. Anything that fails gets the generic loop: diagnose from
`vim.v.errmsg`/`:messages`/`logs/` → smallest fix in this phase's files (or the owning file, see
Leaves alone) → `sync` → re-drive the failing journey and its neighbor → record both transcripts.

### Step 10: `features/treesitter.md` (new)
**File:** `.claude/skills/verify-nvim-config/features/treesitter.md`
**Code** (end states are the ones J2-J8 must produce; if a measured value differs and the journey
still passes, write the measured value):
````markdown
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
$V keys RUN 2 G w g n n
$V lua RUN '{ vim.fn.mode(), vim.fn.line("v"), vim.fn.col("v"), vim.fn.line("."), vim.fn.col(".") }'
$V keys RUN g r n                       # range grows (strictly contains the previous one)
$V keys RUN g r m                       # back to the gnn range
$V keys RUN Escape Escape
$V keys RUN 2 G < < = =
$V lua RUN 'vim.fn.getline(2)'          # "    return sum(item[\"price\"] for item in items)"
```

End state seen: highlighter active on `sample.lua`, `main.go`, `app.py`, `notes.md`
(`vim.b.current_syntax == "markdown"` there too); `vaf` on line 1 of `app.py` is linewise lines
1-2; `vac` on a two-method class is linewise over the class; `gnn` → `grn` grows, `grm` returns to
the `gnn` range; `<<` then `==` restores the 4-space indent; `:GoCmt` on `func add` inserts
`// add ...` above it (go.nvim's treesitter path).

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
- go.nvim is at `4755def` (the newest commit that runs on the installed guihua.lua). Upstream
  master needs `guihua.ts_utils`, which guihua.lua `ef44ba4` lacks: bumping go.nvim further needs
  guihua.lua bumped too.
- Base finding (0.12 on nvim-treesitter `master`): `vaf` → `E5108 ... tsrange.lua:27: attempt to
  call method 'start' (a nil value)`.
````

### Step 11: `features/README.md`, `live-environment.md`, `startup.md` (phase 9 owns these; every earlier phase handed off here)
Handoffs collected (each must be visible in the result): phase 1 (format row; live-environment's
"stylua error text" clause), phase 2 (LSP row; "pyright 0 clients"), phase 3 (dashboard row), phase 4
(fzf-lua row: opencode gone), phase 5 (`live` end state and doctor line still quote `d7bf9fe`/`24ff768`;
its new deploy line), phase 6 (startup row: `--bare`), phase 7 (startup row: gofumpt; name
`tree-sitter-cli` in the Mason bullet), phase 8 (editing-mappings row covers hop `f`/`F`;
`replaced_from_seed` gotcha; `site/` copy). Phase 5's two deploy mentions in `live-environment.md`
(`:13-14` "The owner deploys with ..." and `:43` "Deploying (fetch + ...)") are phase 5's text: leave
them exactly as phase 5 wrote them.

**File:** `.claude/skills/verify-nvim-config/features/README.md` (whole file). `<DATE>`, `<SHA>`,
`<LIVE>` are filled from the final runs. Hop has no file of its own: phase 8 put its journey in
`editing-mappings.md`.
**Code:**
```markdown
# Feature map: verify-nvim-config

One file per feature the owner touches. Each has proven recipes and the end states they produced
on <DATE> on Neovim 0.12.6 (checkout `<SHA>`, live `<LIVE>`), in both `up` and `up --live`. No drive
costs money; none goes online.

| Feature | File | Surfaces | Known on the base |
|---|---|---|---|
| Startup and run modes | [startup.md](startup.md) | `up`, `doctor`, `lua`, `headless` | none (fixed: per-start gofumpt reinstall, `--bare` E5113, version warning on 0.12.6) |
| Dashboard / ASCII art | [dashboard.md](dashboard.md) | `keys`, `lua @dashboard_art.lua` | none (fixed: `,bg`/`,bv`/`,bh` redraw the start screen) |
| Format and check on save | [format-on-save.md](format-on-save.md) | `keys`, `cli git diff`, `lua` | none (fixed: stylua error text no longer replaces the file) |
| LSP | [lsp.md](lsp.md) | `keys`, `wait`, `lsp.log` | none (fixed: pyright attaches) |
| Treesitter | [treesitter.md](treesitter.md) | `keys`, `lua` | none (fixed: `vaf` E5108 on 0.12; nvim-treesitter pinned to `main`) |
| Editing mappings (incl. hop `f`/`F`) | [editing-mappings.md](editing-mappings.md) | `keys`, `lua`, `screen` | none (fixed: hop from `smoka7/hop.nvim`; `phaazon/hop.nvim` is gone) |
| fzf-lua pickers | [fzf-lua.md](fzf-lua.md) | `keys`, `wait` | none (opencode removed) |
| Git mappings | [git.md](git.md) | `keys`, `cli git` | |
| tmux bindings | [tmux-bindings.md](tmux-bindings.md) | `tmux`, `panes` | |
| img2braille | [img2braille.md](img2braille.md) | `cli`, `keys`, `lua` | |
| Live environment | [live-environment.md](live-environment.md) | `up --live`, `live`, `doctor` | live lags this set until Deploy (binary, 4 plugins, parsers) |

A change to what a feature does updates its file in the same change.
```

**File:** `features/live-environment.md`, four hunks, anchored on text (phase 5 has already changed
`:13-14` and `:43`; do not touch those).

(a) The doctor comment line in the recipe:
`$V doctor RUN                # live ok ... unchanged since up; live info live checkout @ d7bf9fe`
becomes (with the measured short sha):
```
$V doctor RUN                # live ok ... unchanged since up; live info live checkout @ <LIVE>, ... replaced from seed (spec moved): ...
```

(b) The `live` end state paragraph (from `End state seen (\`live\`): live \`d7bf9fe\`` through
`(the owner's real tmux file is already current; only the nvim clone is behind).`) becomes the
measured values of the final `$V live` run, with this shape:
```markdown
End state seen (`live`, <DATE>): live `<LIVE>`, checkout `<SHA>`, <N> commits the live checkout lacks
(this set), the files that differ (`<list>`), `~/.tmux.conf.local == checkout's`, and the last line
`deploy (the owner's step, never run by verify): git -C /home/miftah/.config/nvim fetch origin && git -C /home/miftah/.config/nvim merge --ff-only origin/main`.
```

(c) The journey summary paragraph (from `On \`--live\`, the journeys in lsp.md` through
`printed 0).`) becomes:
```markdown
On `--live` with Neovim 0.12.6 (`VERIFY_NVIM`), every journey in this directory gave the same end
state as seeded: lua_ls, gopls and pyright attach; a Lua syntax error leaves `sample.lua` intact with
a warning; `vaf`/`gnn` select through nvim-treesitter `main`; `,bg` redraws the start screen; `f`
shows hop hints. Before the owner deploys, `replaced_from_seed` lists `nvim-treesitter
nvim-treesitter-textobjects hop.nvim go.nvim`, `evidence/00-up-replaced.txt` adds `+ site/parser`,
`+ site/parser-info` and `+ site/queries` under nvim-treesitter, and no file in the run's Mason copy
still named `~/.local/share/nvim` (`grep -rIlF "$HOME/.local/share/nvim" <run>/xdg/data/nvim/mason`
printed 0).
```

(d) The Gotcha `- Only \`lazy/\`, \`mason/\` and \`rplugin.vim\` are copied. ...` (two lines) becomes:
```markdown
- Only `lazy/`, `mason/`, `site/` (treesitter parsers and query links) and `rplugin.vim` are
  copied. `avante/`, `backup/`, `telescope_history` in `~/.local/share/nvim` are private state and
  stay where they are.
- A live plugin is replaced from the seed (`replaced_from_seed`, details in
  `evidence/00-up-replaced.txt`) when the seed moved it: another branch or remote than the live
  lock/dir, or a commit the live clone has never fetched (a bump written into the seed lock). A
  replaced plugin brings its seed lock entry and whatever `PLUGIN_EXTRA_DATA` in `verify.sh` names
  for it (nvim-treesitter: `site/parser`, `site/parser-info`, `site/queries`).
```
The `filled_from_seed` gotcha that follows stays.

**File:** `features/startup.md`, two hunks:
- `:5`: `version check (expects 0.11.5)` -> `version check (expects 0.12.6)` (rest of the line unchanged).
- Phase 7's Sub-features Mason bullet, which reads
  ```markdown
  - Mason (`mason.nvim`, mason-tool-installer for `gofumpt`/`stylua` with `auto_update` and
    `run_on_start`, mason-lspconfig's `ensure_installed`). A start where every tool is installed and
    matches the registry's version installs nothing.
  ```
  becomes
  ```markdown
  - Mason (`mason.nvim`, mason-tool-installer for `gofumpt`/`stylua`/`tree-sitter-cli` with
    `auto_update` and `run_on_start`, mason-lspconfig's `ensure_installed`). A start where every tool
    is installed and matches the registry's version installs nothing.
  ```

### Step 12: SKILL.md (as phases 4-8 left it; anchor on text, never on line numbers)
**File:** `.claude/skills/verify-nvim-config/SKILL.md`. Four replacements and one insertion; every
`old` below is text phase 8 wrote (phase-8.md Step 7) and no other phase touches it.

(a) Phase 8's seed bullet, first line. Old:
```markdown
- **seed** (`$VERIFY_HOME/.seed`, 93 plugins + 13 treesitter parsers + 9 Mason packages, ~570 MB)
```
New (`<SIZE>` = `du -sh ~/.local/state/nvim-config-verify/.seed/data | cut -f1`; reflow the rest of
the bullet only if the line overflows ~100 columns):
```markdown
- **seed** (`$VERIFY_HOME/.seed`, 93 plugins, 13 treesitter parsers in `data/nvim/site`, 10 Mason
  packages with `tree-sitter-cli`, <SIZE>)
```

(b) Phase 8's live bullet, the copy list. Old: `~/.local/share/nvim/{lazy,mason,rplugin.vim}`.
New: `~/.local/share/nvim/{lazy,mason,site,rplugin.vim}`.

(c) Phase 8's live bullet, the end of its "moved" sentence. Old:
```markdown
  lock's, or the seed dir's `origin` url differs from the live dir's), listed as
  `replaced_from_seed`.
```
New:
```markdown
  lock's, or the seed dir's `origin` url differs from the live dir's, or the seed lock pins a commit
  the live clone has never fetched: a one-plugin bump written into the seed lock), listed as
  `replaced_from_seed`.
```
Phase 8's following sentence about `PLUGIN_EXTRA_DATA` ("e.g. parsers under `site/`") already
covers the parsers; keep it.

(d) Phase 8's Gotcha "**lazy never re-targets an installed plugin at startup.**", the clause. Old:
```markdown
  every plugin to its lock commit itself (`WARN ... pinned to the lock` when lazy left it
  elsewhere; at this commit that is `nvim-treesitter`, unpinned, default branch `main`, lock
  `master`), **unless the spec moved**:
```
New:
```markdown
  every plugin to its lock commit itself (`WARN ... pinned to the lock` when lazy left it
  elsewhere), **unless the spec moved** (nvim-treesitter and its textobjects pin `branch = "main"`,
  so a lock that still says `master` makes them MOVED):
```
The rest of phase 8's bullet, and its hop bullet, stay as phase 8 wrote them.

(e) Insert after phase 8's hop Gotcha (the bullet starting ``- **`phaazon/hop.nvim` is gone from
GitHub**``):
```markdown
- **Another Neovim**: every subcommand runs `$VERIFY_NVIM` when set (default
  `/opt/nvim-linux-x86_64/bin/nvim`). Export it for `seed` too: the seed runs the config.
- **nvim-treesitter `main`** installs parsers into `data/nvim/site` with Mason's `tree-sitter`
  CLI; the seed installs `tree-sitter-cli` first and removes a `master` checkout's stale
  `parser/`. A one-plugin bump: write the commit into the seed lock with `jq` (keep `branch` and
  `url`), `seed`, and `--live` replaces that plugin (its commit is unknown to the live clone). See
  features/treesitter.md.
```

### Step 13: Re-drive every feature journey on 0.12.6 and fix what breaks
Covered by Proof J11. A failure is fixed in this phase (Step 9's loop) and recorded in evidence with
before/after paths; a fix in a file owned by an earlier phase changes only the lines the breakage
needs.

### Step 14: Evidence (`evidence-phase-9.md`) and the set's index (`evidence.md`)
Written after the last run of this phase is down (execution rule 4), both committed in Step 15.

**File:** `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-9.md` (new):
```markdown
## Phase 9: Neovim 0.12.6 + nvim-treesitter main (R3, R9)

- nvim: staged 0.12.6 (`VERIFY_NVIM=$HOME/.local/opt/nvim-0.12.6/nvim-linux-x86_64/bin/nvim`), sha256 OK; backup 0.11.5 at `~/.local/opt/nvim-0.11.5/`; commits: <shas>
- base live `<RUN>` / seeded `<RUN>`: version warning `00-up-messages.txt`, `vaf` E5108 `<NN-lua-vim.v.errmsg.txt>`; fresh-install branch: `ls-remote` + upstream clone's `configs.lua` absent (in LOG.md note)
- seed: stage 1 `$P9/seed-stage1.log` + `seed-stage1.seed.log`, stage 2 `$P9/seed-stage2.log` + `seed-stage2.seed.log`, seed lock entries `<...>`
- go.nvim before (stage 1) live `<RUN>/<NN>` seeded `<RUN>/<NN>`: `module 'nvim-treesitter.ts_utils' not found`
- after live `<RUN>` / seeded `<RUN>`: J1..J11 table below
| Journey | live | seeded | evidence |
|---|---|---|---|
| J1 startup/version/doctor | pass | pass | <paths> |
| ... one row per J and per features/*.md journey ... | | | |
- verdict: pass | fail | inconclusive (<reason>)
```

**File:** `.workflows/plan/fix-bugs-nvim-0-12/evidence.md` (new; the set's index). Built by reading
every `evidence-phase-1.md` ... `evidence-phase-9.md` (all committed on the branch by now):
```markdown
# Evidence: fix-bugs-nvim-0-12

Per-phase detail: `evidence-phase-1.md` ... `evidence-phase-9.md` in this directory. Run evidence
lives under `~/.local/state/nvim-config-verify/<RUN>/evidence/` (outside the repo, kept after `down`).

## Before/after per requirement

| Req | Bug | Before (live / seeded) | After (live / seeded) | Phase | Detail |
|---|---|---|---|---|---|
| R1 | stylua data loss | <from evidence-phase-1.md> | <...> | 1 | `evidence-phase-1.md` |
| R2 | pyright never starts | <from evidence-phase-2.md> | <...> | 2 | `evidence-phase-2.md` |
| R3 | nvim-treesitter unpinned | <phase 9 base> | <phase 9 after> | 9 | `evidence-phase-9.md` |
| R4 | hop.nvim gone | <from evidence-phase-8.md> | <...> | 8 | `evidence-phase-8.md` |
| R5 | gofumpt reinstall per start | <from evidence-phase-7.md> | <...> | 7 | `evidence-phase-7.md` |
| R6 | dashboard redraw | <from evidence-phase-3.md> | <...> | 3 | `evidence-phase-3.md` |
| R7 | offline bootstrap E5113 | <from evidence-phase-6.md> | <...> | 6 | `evidence-phase-6.md` |
| R8 | opencode | <from evidence-phase-4.md> | <...> | 4 | `evidence-phase-4.md` |
| R9 | Neovim 0.12.6 | <phase 9 base> | <phase 9 after> | 9 | `evidence-phase-9.md` |
| R10 | deploy hint | <from evidence-phase-5.md> | <...> | 5 | `evidence-phase-5.md` |
| R11 | land + live verify | — | the Deploy run's report, `~/.local/state/nvim-config-verify/deploy-<DATE>.md` (written by runbook D7; never into the repo, so `~/.config/nvim` stays clean) | Deploy | — |
```
Every cell is an evidence path copied from that phase's file; a phase file missing a path is
reported in the cell as `missing in evidence-phase-N.md`, never invented.

### Step 15: Commits (do not push; pathspec commits, execution rule 3)
```sh
git commit -m "feat(nvim): require Neovim 0.12.6" -- init.lua README.md
git commit -m "fix(treesitter): migrate nvim-treesitter and textobjects to main" -- lua/plugin_specs.lua lua/config/treesitter.lua lua/config/treesitter-textobjects.lua
git commit -m "fix(verify): seed treesitter parsers for nvim-treesitter main" -- .claude/skills/verify-nvim-config/scripts/seed.lua .claude/skills/verify-nvim-config/scripts/verify.sh
git add -- .claude/skills/verify-nvim-config/features/treesitter.md
git commit -m "docs(verify): refresh feature end states for 0.12.6" -- .claude/skills/verify-nvim-config/SKILL.md .claude/skills/verify-nvim-config/features
# after every run is down (Step 14):
git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-9.md .workflows/plan/fix-bugs-nvim-0-12/evidence.md
git commit -m "docs(evidence): phase 9 evidence and the set's before/after index" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-9.md .workflows/plan/fix-bugs-nvim-0-12/evidence.md
```
Each message ends with the attribution line from the session's system reminder. The first two
commits are only meaningful together with the third (the config needs `main` parsers); the tree is
proven at the last code commit.

## Principles applied

- Fix root causes: the base journey (Step 1) reproduces `vaf` E5108 and the plan traces it to
  master `query.lua:251` (`iter_matches {all=false}`); the go.nvim break is traced to
  `go/ts/go.lua:2` and gets its own before/after (two-stage re-seed) instead of riding on the migration.
- Laziness protocol: go.nvim goes to `4755def`, not upstream HEAD, because HEAD needs `guihua.ts_utils`
  and would make guihua.lua a fifth moved plugin; incremental selection reuses Neovim 0.12's
  `vim.treesitter.select` instead of a plugin; no go.nvim spec pin (the bump is a lock change).
- Subtract before you add: the seed's `master` install path (`TSInstallSync`, runtime-file probe) is
  deleted rather than kept beside the `main` path; `grc` is dropped rather than emulated.
- Sequence into verifiable units: staging → base proof → code → stage-1 seed (go.nvim before) →
  stage-2 seed (go.nvim after) → full journey sweep; each stage ends in a check that can fail.
- Encode lessons in structure: both treesitter specs pin `branch = "main"`, so lazy cannot follow
  a remote default branch again (R3's root cause); `seed_commit_unknown_to_live` makes a lock-only
  bump visible to `--live` instead of relying on someone remembering to copy a plugin.

## Verification

**Build:**
```sh
cd "$WT"   # this phase's own worktree root (index § Execution rules)
for f in init.lua lua/plugin_specs.lua lua/config/treesitter.lua lua/config/treesitter-textobjects.lua .claude/skills/verify-nvim-config/scripts/seed.lua; do
  $HOME/.local/opt/nvim-0.12.6/nvim-linux-x86_64/bin/nvim --headless -u NONE +"lua assert(loadfile('$f'))" +qa || echo "PARSE FAIL $f"
done
bash -n .claude/skills/verify-nvim-config/scripts/verify.sh
```
Exit 0, no `PARSE FAIL`.

**Tests:** none in the repo; the Proof journeys are the tests.

**Proof:**
- Harness: `.claude/skills/verify-nvim-config` (`scripts/verify.sh`), every call with
  `VERIFY_NVIM=$HOME/.local/opt/nvim-0.12.6/nvim-linux-x86_64/bin/nvim` exported.
- Feature-map entries: `features/treesitter.md` (new), `features/README.md`,
  `features/live-environment.md`, `features/startup.md`; all other `features/*.md` are re-driven (J11).
- Journeys. Run the block once with `MODE=--live` and once with `MODE=` (seeded), after Step 8 stage 2.

```sh
out=$($V up $MODE); echo "$out"; RUN=$(sed -n 's/^RUN=//p' <<<"$out"); E=~/.local/state/nvim-config-verify/$RUN/evidence
# J1 startup + version + doctor
cat $E/00-up-messages.txt                      # PASS: no "Expect nvim version", no E[0-9]+:/Error
$V doctor $RUN; echo "doctor=$?"               # PASS: doctor=0, "messages ok"
$V lua $RUN 'tostring(vim.version())'          # PASS: 0.12.6
grep -E '^(filled|replaced)_from_seed=' ~/.local/state/nvim-config-verify/$RUN/meta
cat $E/00-up-replaced.txt 2>/dev/null
  # --live PASS: replaced_from_seed has nvim-treesitter, nvim-treesitter-textobjects, hop.nvim, go.nvim
  #              (and nothing else); 00-up-replaced.txt has `+ site/parser from the seed`,
  #              `+ site/parser-info from the seed`, `+ site/queries from the seed` under nvim-treesitter.
  #              Seeded: the keys are absent and there is no 00-up-replaced.txt.
# J2 parsers installed, no stale master parsers on the rtp
$V lua $RUN 'table.concat((function() local t = require("nvim-treesitter").get_installed("parsers") table.sort(t) return t end)(), ",")'
  # PASS: contains python,http,cpp,lua,vim,json,toml,markdown,markdown_inline,html,css,javascript,go
$V lua $RUN 'table.concat(vim.api.nvim_get_runtime_file("parser/python.so", true), " ")'
  # PASS: one path, under xdg/data/nvim/site/parser/; none under lazy/nvim-treesitter/parser
$V lua $RUN 'require("lazy.core.config").plugins["nvim-treesitter"].branch .. " " .. require("lazy.core.config").plugins["nvim-treesitter-textobjects"].branch'   # PASS: main main
# J3 highlight on lua/go/python/markdown
for f in sample.lua main.go app.py notes.md; do
  $V keys $RUN : e Space $f Enter
  $V lua $RUN 'vim.bo.filetype .. " " .. tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil)'   # PASS: "<ft> true"
done
$V lua $RUN 'tostring(vim.b.current_syntax)'   # on notes.md, PASS: markdown
# J4 textobjects: vaf / vif in app.py, vac / vic in a class
$V keys $RUN : e Space app.py Enter
$V keys $RUN g g v a f
$V lua $RUN '{ vim.fn.mode(), vim.fn.line("v"), vim.fn.line(".") }'   # PASS: { "V", 1, 2 }
$V keys $RUN Escape Escape
$V keys $RUN 2 G v i f
$V lua $RUN '{ vim.fn.mode(), vim.fn.line("v"), vim.fn.line(".") }'   # PASS: { "V", 2, 2 }
$V keys $RUN Escape Escape
$V lua $RUN 'vim.v.errmsg'                                            # PASS: no tsrange / E5108
$V cli $RUN sh -c 'printf "class Box:\n    def size(self):\n        return 1\n\n    def name(self):\n        return \"box\"\n" > cls.py'
$V keys $RUN : e Space cls.py Enter
$V keys $RUN 2 G v a c
$V lua $RUN '{ vim.fn.mode(), vim.fn.line("v"), vim.fn.line(".") }'   # PASS: { "V", 1, 6 }
$V keys $RUN Escape Escape
$V keys $RUN 2 G v i c
$V lua $RUN '{ vim.fn.mode(), vim.fn.line("v"), vim.fn.line(".") }'   # PASS: { "V", 2, 6 }
$V keys $RUN Escape Escape
# J5 incremental selection gnn / grn / grm; Normal grn is still LSP rename
$V keys $RUN : e Space app.py Enter
$V keys $RUN 2 G w w
$V keys $RUN g n n
$V lua $RUN '{ vim.fn.mode(), vim.fn.line("v"), vim.fn.col("v"), vim.fn.line("."), vim.fn.col(".") }'   # A: mode "v"
$V keys $RUN g r n
$V lua $RUN '{ vim.fn.mode(), vim.fn.line("v"), vim.fn.col("v"), vim.fn.line("."), vim.fn.col(".") }'   # B: mode "v", B strictly contains A
$V keys $RUN g r m
$V lua $RUN '{ vim.fn.mode(), vim.fn.line("v"), vim.fn.col("v"), vim.fn.line("."), vim.fn.col(".") }'   # PASS: equals A
$V keys $RUN Escape Escape
$V lua $RUN 'vim.fn.maparg("grn", "n", false, true).desc or ""'   # PASS: mentions rename
$V lua $RUN 'vim.fn.maparg("grc", "x")'                           # PASS: "" (dropped)
# J6 indent: treesitter indentexpr, = re-indents; yaml keeps Vim's
$V lua $RUN 'vim.bo.indentexpr'          # in app.py, PASS: v:lua.require'nvim-treesitter'.indentexpr()
$V keys $RUN 2 G < < = =
$V lua $RUN 'vim.fn.getline(2)'          # PASS: starts with 4 spaces then "return sum("
$V keys $RUN u u
$V cli $RUN sh -c 'printf "a:\n  b: 1\n" > cfg.yaml'
$V keys $RUN : e Space cfg.yaml Enter
$V lua $RUN 'vim.bo.indentexpr'          # PASS: not the nvim-treesitter expression
# J7 go.nvim loads and its treesitter path works (:GoCmt)
$V keys $RUN : e Space main.go Enter
$V lua $RUN 'package.loaded["go"] ~= nil'   # PASS: true
$V keys $RUN 5 G : G o C m t Enter
$V keys $RUN Escape Escape
$V lua $RUN 'vim.fn.getline(5) .. " | " .. vim.v.errmsg'   # PASS: line 5 starts with "// add", no "ts_utils" error
$V keys $RUN : e ! Enter
# J8 go format-on-save still gofumpt (format-on-save.md go journey)
$V keys $RUN 6 G : w Enter
$V cli $RUN git diff main.go               # PASS: "-	var x = a+b" / "+	x := a + b"
$V cli $RUN git checkout -- main.go cls.py cfg.yaml 2>/dev/null; $V cli $RUN rm -f cls.py cfg.yaml
# J9 no errors left
$V lua $RUN 'vim.fn.execute("messages")'   # PASS: no E[0-9]+: / Error lines
$V doctor $RUN; echo "doctor=$?"           # PASS: doctor=0
$V down $RUN
```
(J8: `:w` on unmodified `main.go` still runs BufWritePre; if the format-on-save.md go journey edits
first, follow its exact keys instead and compare to its end state.)

  - **J0 (base, Step 1)** must fail first: `vaf` E5108 + version warning, both modes.
  - **go.nvim before (after Step 8 stage 1)**, both modes: J7 → `vim.v.errmsg` contains
    `module 'nvim-treesitter.ts_utils' not found` (live go.nvim `81bb94c` on `main`), line 5 unchanged.
    After stage 2: J7 passes.
  - **J10 (Steps 8)**: seed logs as listed in Step 8 (no `FAIL`, `ok   treesitter parsers`, stale `parser/` removed).
  - **J11: every journey in `features/*.md` on 0.12.6, both modes**: startup.md, live-environment.md
    (incl. `$V live`), format-on-save.md (valid + syntax-error variants + go), lsp.md (lua_ls, gopls,
    pyright), dashboard.md (`,bg`/`,bv`/`,bh` redraw, split view), editing-mappings.md (`V H` on
    data.json, `C-o`), fzf-lua.md (`,ff` → guide.txt), git.md, tmux-bindings.md (`C-b @`, `C-b !`),
    img2braille.md, and the hop journey in editing-mappings.md (phase 8: `f` hints + jump, `F /`). Each journey's
    end state must equal the one its file records; record pass/fail per journey per mode in the
    evidence table. A failure is fixed per Step 9 and re-driven.
- Neighbor check: LSP (`grn` Normal-mode rename must still be Neovim's; lua_ls attach in
  `sample.lua` since lua's ftplugin and this config both start treesitter): lsp.md journey + J5's
  `maparg` line.
- Cost: no paid drives. Two online seeds (~2-6 min each, parsers compile locally).

**Exit criteria:** J0 fails on the base (live + seeded) as stated; after: J1-J9 pass in both modes,
go.nvim before/after shown, J10 seed logs clean, J11 every features journey passes on 0.12.6 in both
modes; the four code/doc commits and the evidence commit exist on `feature/fix-bugs-nvim-0-12` (not
pushed); `evidence-phase-9.md` has `## Phase 9` and `evidence.md` has the per-requirement table with a
path in every R1-R10 cell (R11 points at the Deploy report); `/opt/nvim-linux-x86_64/bin/nvim --version` still says v0.11.5 and
`~/.config/nvim`/`~/.local/share/nvim` are untouched by this phase (`git -C ~/.config/nvim status
--porcelain` empty, live lock unchanged).

## Handoffs

- **Deploy (coordinator, after land):** the runbook below. It is the only step that writes
  `/opt/nvim-linux-x86_64`, `~/.config/nvim` and `~/.local/share/nvim`.
- **Phase 8 (resolved at reconciliation):** Step 7 builds on phase 8's final code (quoted there):
  parsers go through phase 8's `PLUGIN_EXTRA_DATA` hook, commit bumps through one extra clause in
  phase 8's test line. No second copy path, no extra meta key.
- **Decision (recorded in the index):** go.nvim goes to `4755def`, not upstream master (`5622d97`),
  because master needs `guihua.ts_utils` and guihua.lua is not one of the four plugins that move. A
  later set can bump go.nvim + guihua.lua together.
- **Later set:** `live_fingerprint` does not cover `~/.local/share/nvim/site` (doctor's live check
  would not notice the owner installing a parser mid-run). Not needed for any proof here.
- Plugin-side 0.12 deprecation warnings (git-conflict.nvim `vim.highlight`/`vim.validate{}`) stay out of scope.

## Rollback

Before land: `git revert` the four commits (or `git reset --keep` to phase 8's tip on the branch),
then `$V seed` with `VERIFY_NVIM` unset to rebuild the seed for the reverted config (restore the
seed lock's `go.nvim` to `81bb94c1d21648245eb14c69461f5c7f8c705752` and the treesitter entries to
`master`/`42fc28ba918343ebfd5565147a42a26580579482`, `5ca4aaa6efdcc59be46b95a3e876300cfead05ef`
with `jq` first). `~/.local/opt/nvim-0.12.6` and `~/.local/opt/nvim-0.11.5` can stay; nothing reads
them unless `VERIFY_NVIM` names them. After Deploy: the Deploy runbook's per-step rollbacks.

---

## Deploy runbook

Run by the coordinator **after** land: the set is merged and pushed to `origin/main` (D0 asserts it
from `origin/main`'s content), from a bash shell, never from the deleted worktree. Order: D0 checks,
D1 backup, D2 binary swap, **D3 `git -C ~/.config/nvim fetch origin && git -C ~/.config/nvim merge
--ff-only origin/main`**, then everything that depends on the landed config (D4 plugins, D5 Mason, D6
parsers, D7 proof, D8 final) strictly after D3. Every step asserts (`set -euo pipefail`: a failed
assertion stops the script). On a failed assertion in D2-D7 run the **full rollback** at the end
(D6 -> D2 rollbacks in reverse order), then stop and report. Nothing in this runbook writes inside
`~/.config/nvim` except D3's fast-forward and D4's gitignored `lazy-lock.json`; the run report goes to
`$VH/deploy-$DATE.md`, outside the repo, so the checkout stays clean.

### D0: Variables and preconditions (writes nothing but `git fetch`'s remote refs)
```bash
set -euo pipefail
DATE=$(date +%Y%m%d-%H%M%S)
VH=$HOME/.local/state/nvim-config-verify
REPORT=$VH/deploy-$DATE.md
BK=$HOME/.local/opt/deploy-backup-$DATE
STAGED=$HOME/.local/opt/nvim-0.12.6/nvim-linux-x86_64
OLD=$HOME/.local/opt/nvim-0.11.5/nvim-linux-x86_64
LIVE=$HOME/.config/nvim
DATA=$HOME/.local/share/nvim
SEED=$VH/.seed
SEED_LOCK=$SEED/lazy-lock.json
PLUGINS="nvim-treesitter nvim-treesitter-textobjects hop.nvim go.nvim"
LANGS='"python","http","cpp","lua","vim","json","toml","markdown","markdown_inline","html","css","javascript","go"'
NVIM=/opt/nvim-linux-x86_64/bin/nvim
origin_raw() { git -C "$1" config --get remote.origin.url; }   # never `remote get-url`: it applies insteadOf

"$STAGED/bin/nvim" --version | head -1 | grep -qx 'NVIM v0.12.6'
"$OLD/bin/nvim" --version | head -1 | grep -qx 'NVIM v0.11.5'
"$NVIM" --version | head -1 | grep -qx 'NVIM v0.11.5'           # not swapped yet
[ -z "$(git -C "$LIVE" status --porcelain)" ]
git -C "$LIVE" fetch origin
git -C "$LIVE" merge-base --is-ancestor HEAD origin/main          # a fast-forward is possible
# The set has landed: origin/main carries its config (never deploy a half-landed main).
git -C "$LIVE" show origin/main:init.lua | grep -q 'expected_version = "0.12.6"'
git -C "$LIVE" show origin/main:lua/plugin_specs.lua | grep -q '"smoka7/hop.nvim"'
[ "$(git -C "$LIVE" show origin/main:lua/plugin_specs.lua | grep -c 'branch = "main"')" -ge 2 ]
git -C "$LIVE" show origin/main:.workflows/plan/fix-bugs-nvim-0-12/evidence.md >/dev/null
# The seed lock is phase 8's format and holds phase 9's targets.
[ "$(jq -r '."nvim-treesitter".branch' "$SEED_LOCK")" = main ]
[ "$(jq -r '."nvim-treesitter-textobjects".branch' "$SEED_LOCK")" = main ]
[ "$(jq -r '."go.nvim".commit' "$SEED_LOCK")" = 4755deffda8eeb0ceed53b535cce29f0e29a640a ]
jq -r '."hop.nvim".url' "$SEED_LOCK" | grep -q '^https://github.com/smoka7/hop.nvim'
for p in $PLUGINS; do
  [ -n "$(jq -r --arg p "$p" '.[$p].url // empty' "$SEED_LOCK")" ]          # every entry carries its url
  [ "$(git -C "$SEED/data/nvim/lazy/$p" rev-parse HEAD)" = "$(jq -r --arg p "$p" '.[$p].commit' "$SEED_LOCK")" ]
  [ -d "$DATA/lazy/$p/.git" ]; [ ! -e "$DATA/lazy/$p.cloning" ]
done
pgrep -a -x nvim || true     # informational: running sessions keep the old binary until restarted
printf '# Deploy %s\n\n- origin/main: %s\n' "$DATE" "$(git -C "$LIVE" rev-parse --short origin/main)" >"$REPORT"
```
Rollback D0: nothing to undo (only remote-tracking refs were fetched).

### D1: Backup
```bash
mkdir -p "$BK/lazy"
cp -a "$LIVE/lazy-lock.json" "$BK/lazy-lock.json"
for p in $PLUGINS; do cp -a "$DATA/lazy/$p" "$BK/lazy/"; done
if [ -d "$DATA/site" ]; then cp -a "$DATA/site" "$BK/site"; fi
git -C "$LIVE" rev-parse HEAD >"$BK/config-head.txt"
cmp "$LIVE/lazy-lock.json" "$BK/lazy-lock.json"
for p in $PLUGINS; do [ "$(git -C "$BK/lazy/$p" rev-parse HEAD)" = "$(git -C "$DATA/lazy/$p" rev-parse HEAD)" ]; done
echo "- backup: $BK (config head $(cat "$BK/config-head.txt"))" >>"$REPORT"
```
Rollback D1: none needed (`$BK` only holds copies; keep it).

### D2: Swap the binary in place
```bash
find /opt/nvim-linux-x86_64 -mindepth 1 -delete
cp -a "$STAGED/." /opt/nvim-linux-x86_64/
"$NVIM" --version | head -1 | grep -qx 'NVIM v0.12.6'
diff -rq "$STAGED" /opt/nvim-linux-x86_64
echo "- D2 binary: $("$NVIM" --version | head -1)" >>"$REPORT"
```
Rollback D2:
```bash
find /opt/nvim-linux-x86_64 -mindepth 1 -delete && cp -a "$OLD/." /opt/nvim-linux-x86_64/
/opt/nvim-linux-x86_64/bin/nvim --version | head -1 | grep -qx 'NVIM v0.11.5'
```

### D3: Fast-forward the live config (the user's exact command)
```bash
git -C "$LIVE" fetch origin && git -C "$LIVE" merge --ff-only origin/main
[ "$(git -C "$LIVE" rev-parse HEAD)" = "$(git -C "$LIVE" rev-parse origin/main)" ]
[ -z "$(git -C "$LIVE" status --porcelain)" ]
grep -q 'expected_version = "0.12.6"' "$LIVE/init.lua"
echo "- D3 config: $(git -C "$LIVE" log --oneline -1)" >>"$REPORT"
```
Rollback D3: `git -C "$LIVE" reset --keep "$(cat "$BK/config-head.txt")"` (the fast-forward is the only
write D3 makes; `--keep` refuses rather than discard anything).

### D4: Move the 4 plugins to the seed lock's entries and record them in the live lock
Plain git, not `Lazy! restore`: restore would also run each updated plugin's `build` (nvim-treesitter's
async `:TSUpdate`, which needs the `tree-sitter` CLI D5 installs, and go.nvim's async
`:GoUpdateBinaries`, ~20 `go install`s that `+qa` would cut off). The url comes from the seed lock's
`url` field (phase 8's format; the raw `.git/config` value), so hop's live clone is re-pointed from
`phaazon/hop.nvim` to `smoka7/hop.nvim` with `remote set-url`; never from `git remote get-url`, which
would store the owner's `insteadOf` rewrite (`git@github.com:...`) and make every later `--live` run
see hop as moved again.
```bash
for p in $PLUGINS; do
  url=$(jq -r --arg p "$p" '.[$p].url' "$SEED_LOCK")
  branch=$(jq -r --arg p "$p" '.[$p].branch' "$SEED_LOCK")
  commit=$(jq -r --arg p "$p" '.[$p].commit' "$SEED_LOCK")
  git -C "$DATA/lazy/$p" remote set-url origin "$url"
  git -C "$DATA/lazy/$p" fetch -q origin "+refs/heads/$branch:refs/remotes/origin/$branch"
  git -C "$DATA/lazy/$p" checkout -q "$commit"
  [ "$(git -C "$DATA/lazy/$p" rev-parse HEAD)" = "$commit" ]
  [ "$(origin_raw "$DATA/lazy/$p")" = "$url" ]
  echo "- D4 $p $branch $commit $url" >>"$REPORT"
done
tmp=$(mktemp)
jq --slurpfile seed "$SEED_LOCK" '. + ($seed[0] | {"nvim-treesitter","nvim-treesitter-textobjects","hop.nvim","go.nvim"})' "$LIVE/lazy-lock.json" >"$tmp"
cp "$tmp" "$LIVE/lazy-lock.json" && rm -f "$tmp"
for p in $PLUGINS; do
  [ "$(jq -r --arg p "$p" '.[$p].commit' "$LIVE/lazy-lock.json")" = "$(git -C "$DATA/lazy/$p" rev-parse HEAD)" ]
  [ "$(jq -r --arg p "$p" '.[$p].branch' "$LIVE/lazy-lock.json")" = "$(jq -r --arg p "$p" '.[$p].branch' "$SEED_LOCK")" ]
done
# master's untracked build output would shadow main's parsers on the runtimepath
rm -rf "$DATA/lazy/nvim-treesitter/parser" "$DATA/lazy/nvim-treesitter/parser-info"
[ ! -e "$DATA/lazy/nvim-treesitter/parser" ] && [ ! -e "$DATA/lazy/nvim-treesitter/parser-info" ]
[ -z "$(git -C "$LIVE" status --porcelain)" ]       # lazy-lock.json is gitignored
```
(The live lock entries gain phase 8's `url` key; lazy ignores it and drops it on its next rewrite.)
Rollback D4:
```bash
for p in $PLUGINS; do rm -rf "$DATA/lazy/$p" && cp -a "$BK/lazy/$p" "$DATA/lazy/"; done
cp -a "$BK/lazy-lock.json" "$LIVE/lazy-lock.json"
for p in $PLUGINS; do [ "$(git -C "$DATA/lazy/$p" rev-parse HEAD)" = "$(git -C "$BK/lazy/$p" rev-parse HEAD)" ]; done
```

### D5: tree-sitter-cli into the live Mason (synchronous)
The script runs from `-c`, i.e. before VimEnter, so mason-tool-installer has not started its own run.
```bash
cat >"$BK/mason-tree-sitter.lua" <<'EOF'
local reg = require("mason-registry")
local refreshed = false
reg.refresh(function() refreshed = true end)
vim.wait(120000, function() return refreshed end, 200)
local pkg = reg.get_package("tree-sitter-cli")
if not pkg:is_installed() then
  local result
  pkg:install({}, function(success) result = success end)
  vim.wait(300000, function() return result ~= nil end, 500)
  if not result then
    io.stderr:write("tree-sitter-cli install failed\n")
    vim.cmd("cquit 1")
  end
end
io.stdout:write("tree-sitter-cli installed\n")
vim.cmd("qa!")
EOF
(cd "$HOME" && "$NVIM" --headless -c "luafile $BK/mason-tree-sitter.lua")
"$DATA/mason/bin/tree-sitter" --version | tee -a "$REPORT"     # tree-sitter 0.27.x (>= 0.26.1)
```
Rollback D5: `"$NVIM" --headless -c 'lua require("mason-registry").get_package("tree-sitter-cli"):uninstall()' -c 'sleep 5' -c 'qa!'` (optional; an extra Mason tool harms nothing).

### D6: The 13 parsers (synchronous) into `~/.local/share/nvim/site`
```bash
cat >"$BK/ts-install.lua" <<EOF
local langs = { $LANGS }
local ts = require("nvim-treesitter")
ts.install(langs, { summary = true }):wait(600000)
local installed = ts.get_installed("parsers")
local missing = vim.tbl_filter(function(l) return not vim.list_contains(installed, l) end, langs)
if #missing > 0 then
  io.stderr:write("missing parsers: " .. table.concat(missing, ",") .. "\n")
  vim.cmd("cquit 1")
end
table.sort(installed)
io.stdout:write("parsers: " .. table.concat(installed, ",") .. "\n")
vim.cmd("qa!")
EOF
(cd "$HOME" && "$NVIM" --headless -c "luafile $BK/ts-install.lua") | tee -a "$REPORT"
for l in python http cpp lua vim json toml markdown markdown_inline html css javascript go; do [ -f "$DATA/site/parser/$l.so" ]; done
"$NVIM" --headless -c 'lua io.stdout:write(table.concat(vim.api.nvim_get_runtime_file("parser/python.so", true), " ") .. "\n")' -c 'qa!' >"$BK/rtp-python.txt"
[ "$(wc -w <"$BK/rtp-python.txt")" -eq 1 ] && grep -q "$DATA/site/parser/python.so" "$BK/rtp-python.txt"
```
Rollback D6: `rm -rf "$DATA/site"; if [ -d "$BK/site" ]; then cp -a "$BK/site" "$DATA/site"; fi`.

### D7: Final proof from `~/.config/nvim` (R11)
Expected end states are the ones the phases recorded: format-on-save.md (phase 1), lsp.md (phase 2),
treesitter.md (phase 9).
```bash
cd "$LIVE"
unset VERIFY_NVIM                                   # /opt is 0.12.6 now
V=.claude/skills/verify-nvim-config/scripts/verify.sh
NOTIFY='vim.inspect(vim.tbl_map(function(n) return { n.level, n.message } end, require("notify").history()))'
$V live | tee "$BK/live.txt"
tail -1 "$BK/live.txt" | grep -q 'fetch origin && git -C /home/miftah/.config/nvim merge --ff-only origin/main'
grep -q '^commits in the checkout that live lacks (0)' "$BK/live.txt"
out=$($V up --live); echo "$out"; RUN=$(sed -n 's/^RUN=//p' <<<"$out"); E=$VH/$RUN/evidence
# (`if`, not `! grep`: bash's `set -e` ignores a negated command)
if grep -qE 'Expect nvim version|E[0-9]+:|Error' "$E/00-up-messages.txt"; then echo "FAIL startup messages"; exit 1; fi
grep -E '^(filled|replaced)_from_seed=' "$VH/$RUN/meta"
[ -z "$(sed -n 's/^replaced_from_seed=//p' "$VH/$RUN/meta")" ]    # live now has what the seed has
[ ! -e "$E/00-up-replaced.txt" ]
$V doctor $RUN                                      # exit 0
$V lua $RUN 'tostring(vim.version())'               # 0.12.6
# format-on-save, valid code (format-on-save.md j_valid)
$V cli $RUN git checkout -- sample.lua; $V sync $RUN
$V keys $RUN : e Space sample.lua Enter
$V keys $RUN G O; $V keys $RUN --paste 'local   z   =   1'; $V keys $RUN Escape Escape
$V keys $RUN : w Enter
$V cli $RUN git diff sample.lua                     # tab-indented, `function M.sum(a, b)` split over 3 lines, `+local z = 1`
# format-on-save, syntax error on line 1 (format-on-save.md j_err1): content kept
$V cli $RUN git checkout -- sample.lua; $V sync $RUN
$V keys $RUN : e Space sample.lua Enter
$V keys $RUN g g O; $V keys $RUN --paste 'local x = = 1'; $V keys $RUN Escape Escape
$V keys $RUN : w Enter
$V cli $RUN sh -c 'wc -l < sample.lua; head -1 sample.lua'   # 11 / "local x = = 1"
$V lua $RUN "$NOTIFY"                               # a "WARN" entry starting "stylua failed, buffer left unformatted: error: could not format from stdin"
$V cli $RUN git checkout -- sample.lua; $V sync $RUN
# lsp: lua_ls, gopls, pyright (lsp.md)
$V keys $RUN : e Space sample.lua Enter; $V wait $RUN '#vim.lsp.get_clients({bufnr=0, name="lua_ls"})' 1 60
$V keys $RUN : e Space main.go Enter;    $V wait $RUN '#vim.lsp.get_clients({bufnr=0, name="gopls"})' 1 90
$V keys $RUN : e Space app.py Enter;     $V wait $RUN '#vim.lsp.get_clients({bufnr=0, name="pyright"})' 1 90
# treesitter on the live data (treesitter.md)
$V keys $RUN g g v a f
$V lua $RUN '{ vim.fn.mode(), vim.fn.line("v"), vim.fn.line(".") }'   # { "V", 1, 2 }
$V keys $RUN Escape Escape
$V doctor $RUN                                      # exit 0
$V down $RUN
[ -z "$(git -C "$LIVE" status --porcelain)" ]       # verify wrote nothing into the checkout
{ echo "- D7 run $RUN: evidence $E (live: $BK/live.txt)"; } >>"$REPORT"
```
Every `wait`/`grep`/`[ ]` above is an assertion; a `lua`/`cli` line whose output differs from its
comment fails D7 by the operator's reading, recorded in `$REPORT`.
Rollback D7: `$V down $RUN` if still up; the run is read-only. A failed D7 assertion triggers the
full rollback below (the owner must not be left on an unproven deploy).

### D8: Final assertions and the report
```bash
/opt/nvim-linux-x86_64/bin/nvim --version | head -1 | grep -qx 'NVIM v0.12.6'
git -C "$LIVE" fetch origin
[ "$(git -C "$LIVE" rev-parse HEAD)" = "$(git -C "$LIVE" rev-parse origin/main)" ]
[ -z "$(git -C "$LIVE" status --porcelain)" ]
for p in $PLUGINS; do echo "- D8 $p $(git -C "$DATA/lazy/$p" rev-parse --short HEAD) $(origin_raw "$DATA/lazy/$p")"; done >>"$REPORT"
echo "- deploy ok; backup kept at $BK" >>"$REPORT"
cat "$REPORT"
```
Rollback D8: none (read-only). The coordinator's final report quotes `$REPORT` and the per-bug
before/after paths from `.workflows/plan/fix-bugs-nvim-0-12/evidence.md` (on `origin/main`).

### Full rollback (any assertion in D2-D7 failed)
D6 -> D5 -> D4 -> D3 -> D2 rollbacks, each only if its step had started, in that order. Then assert
`/opt/nvim-linux-x86_64/bin/nvim --version` = v0.11.5, `git -C ~/.config/nvim rev-parse HEAD` =
`$(cat $BK/config-head.txt)`, the 4 plugin dirs' HEADs = the backup's, and append to `$REPORT` which
assertion failed with its output. `origin/main` keeps the landed set; the report says the owner's
checkout is back on the pre-deploy commit and why.
