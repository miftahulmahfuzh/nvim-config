# Phase 2: pyright starts on Python buffers

**Plan set:** `docs/plans/FIX_BUGS_NVIM_0_12_PLAN.md`
**Analysis:** `docs/analyzer/20261104-102452-MRDD_code_analyzer.md` (Entry Point C)
**Satisfies:** R2: Python buffers get a working pyright server
**Depends on:** none (wave 1)
**Difficulty:** EASY
**Package:** `after/lsp/` + `.claude/skills/verify-nvim-config/features/`

---

> **Set-wide execution rules** (plan index § Execution rules; they override any command below that disagrees):
> 1. `$WT` is **this phase's own worktree root** (`WT=$(git rev-parse --show-toplevel)`). Wave-1 phases run
>    concurrently in separate worktrees, so never `cd` into another phase's tree.
> 2. **No `git stash`** (the stash stack is shared by every worktree of the repo). Swap base and fix per file:
>    `SW=$(mktemp -d)`; BASE = `cp <path> "$SW/" && git show "$PHASE_BASE:<path>" ><path>`; FIX = `cp "$SW/<file>" <path>`,
>    where `PHASE_BASE=$(git rev-parse HEAD)` is recorded before this phase's first edit. A new file's BASE is `mv <path> "$SW/"`.
> 3. Commit with an explicit pathspec: `git add -- <new files>` then `git commit -m "..." -- <every path>`.
> 4. Evidence goes to `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-2.md`, this phase's own file (never a shared one),
>    written only **after every run of the phase is down** (the file is inside the snapshotted tree; a mid-run write makes
>    `doctor` print `code WARN`). It is committed as the phase's last commit:
>    `git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-2.md && git commit -m "docs(evidence): phase 2 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-2.md`.
>    `.workflows/` is tracked (the orchestrator commits the plan set); commit nothing else under it unless this plan says so.
> 5. Never `git push`. Never write `~/.config/nvim`, `~/.local/share/nvim` or `/opt/nvim-linux-x86_64`.

## Goal

Opening a `.py` file attaches a `pyright` client launched from Mason's `pyright-langserver`, and
pyright's diagnostics show up in the buffer. Today `after/lsp/pyright.lua:23` overrides the command
with `delance-langserver`, which exists nowhere, so 0.11 rejects the config and no Python server ever
starts. The settings and capabilities in the file do not change. `features/lsp.md` records the new
end states.

## Root cause (reproduced, traced to a line)

- Chain: mason-lspconfig v2 `automatic_enable` runs `vim.lsp.enable("pyright")`. Neovim builds the
  config by deep-merging (`tbl_deep_extend("force")`) every `lsp/pyright.lua` on the runtimepath
  in order: nvim-lspconfig's `lsp/pyright.lua` (`cmd = { 'pyright-langserver', '--stdio' }`), then
  this repo's `after/lsp/pyright.lua`, whose `cmd = { "delance-langserver", "--stdio" }` (line 23)
  wins. 0.11 checks that `cmd[1]` is executable, writes
  `invalid "pyright" config: ... delance-langserver is not executable` to `lsp.log`, and never
  starts the client.
- Measured on 2026-11-04: `delance-langserver` is on no PATH. Mason's `pyright-langserver` exists in
  live `~/.local/share/nvim/mason/bin` (pyright 1.1.407) and in the seed
  `~/.local/state/nvim-config-verify/.seed/data/nvim/mason/bin` (pyright 1.1.414). Its shebang is
  `#!/usr/bin/env node`, and `node` (`~/tools/node-v22.23.1-linux-x64/bin`) is on every run's PATH
  through `run_path`'s `$NODE`.
- There is a second `pyright-langserver` at `~/miniconda3/bin` (pip's pyright wrapper), and it is on
  the run PATH because `python3` lives there. Mason puts its `bin` first on PATH (`PATH = "prepend"`
  is the default), so Mason's copy resolves first. The proof checks that with `vim.fn.exepath`.
  The pip wrapper would try to download node packages at first start, which the run's network fence
  blocks.
- Repro journey: Journey 1 below (base, both modes): pyright `0` clients, `lsp.log` has the
  delance line, and no `Pyright` diagnostic appears.

## Interface Contract

**Deletes:** the `cmd` key of the table returned by `after/lsp/pyright.lua` (line 23), so `cmd` is
inherited from nvim-lspconfig's `lsp/pyright.lua`.
**Renames:** none
**Creates:** none in the config. `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-2.md` (this
phase's own evidence file, execution rule 4)
**Signature changes:** none. `after/lsp/pyright.lua` still returns `{ settings = ..., capabilities = ... }`
with the same values.
**Requires (from earlier phases):** nothing
**Leaves alone (owned by others):** `lua/config/lsp.lua` (its `enabled_lsp_servers` loop and the
`pyright = "pyright"` executable check stay as they are), `lua/plugin_specs.lua` (mason-lspconfig
`ensure_installed`, phases 6-9), `features/README.md` and `features/live-environment.md` (phase 9;
the README's "**pyright never starts**" cell is now stale, see Handoffs), `SKILL.md` (phases 4-8),
`verify.sh` (phases 4, 5, 8), every other `after/lsp/*.lua`.

## Files

| File | Action | What changes |
|---|---|---|
| `after/lsp/pyright.lua` | modify | drop `cmd` (line 23). Rewrite the stale "provided by pylance?" comment (line 40) and add a header line saying where `cmd` comes from. `settings` and `capabilities` keep the same values. |
| `.claude/skills/verify-nvim-config/features/lsp.md` | modify | pyright recipe (lines 21-23), end states (lines 26-29) and the Gotchas product finding (lines 33-36) describe the fixed behaviour |
| `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-2.md` | create (after all runs are down) | a `## Phase 2` section with the run IDs and evidence paths; own commit |

## Implementation Steps

### Step 1: Remove the delance override and fix the stale comments
**File:** `after/lsp/pyright.lua:1-51` (the change is at line 23 `cmd = ...`, line 40 comment, and a
new comment at the top)
**Change:** Delete the `cmd` entry so the merged config keeps nvim-lspconfig's
`{ 'pyright-langserver', '--stdio' }`. Do not write an explicit `cmd = { "pyright-langserver", "--stdio" }`.
Inheriting lspconfig's default means this file cannot drift from the server Mason installs again.
Replace the line-40 comment `-- inlay hint settings are provided by pylance?`. It is stale:
open-source pyright implements no `textDocument/inlayHint`, so the block is inert under pyright.
The block stays because R2 changes only the command. Every value in `settings` and
`new_capability` stays byte-for-byte the same.
**Code:** full final file content:
```lua
-- The server command is not set here: it comes from nvim-lspconfig's lsp/pyright.lua
-- ({ "pyright-langserver", "--stdio" }), the binary Mason's `pyright` package puts on PATH.
-- For what diagnostic is enabled in which type checking mode, check doc:
-- https://github.com/microsoft/pyright/blob/main/docs/configuration.md#diagnostic-settings-defaults
-- Currently, the pyright also has some issues displaying hover documentation:
-- https://www.reddit.com/r/neovim/comments/1gdv1rc/what_is_causeing_the_lsp_hover_docs_to_looks_like/

local new_capability = {
  -- this will remove some of the diagnostics that duplicates those from ruff, idea taken and adapted from
  -- here: https://github.com/astral-sh/ruff-lsp/issues/384#issuecomment-1989619482
  textDocument = {
    publishDiagnostics = {
      tagSupport = {
        valueSet = { 2 },
      },
    },
    hover = {
      contentFormat = { "plaintext" },
      dynamicRegistration = true,
    },
  },
}

return {
  settings = {
    pyright = {
      -- disable import sorting and use Ruff for this
      disableOrganizeImports = true,
      disableTaggedHints = false,
    },
    python = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = "workspace",
        typeCheckingMode = "standard",
        useLibraryCodeForTypes = true,
        -- we can this setting below to redefine some diagnostics
        diagnosticSeverityOverrides = {
          deprecateTypingAliases = false,
        },
        -- pyright itself serves no inlay hints; these keys are read by Pylance/basedpyright only
        inlayHints = {
          callArgumentNames = "partial",
          functionReturnTypes = true,
          pytestParameters = true,
          variableTypes = true,
        },
      },
    },
  },
  capabilities = new_capability,
}
```
**Impact:** `vim.lsp.config.pyright.cmd` becomes `{ "pyright-langserver", "--stdio" }`. Every Python
buffer under a root marker (the fixture WORK is a git repo, so `.git` qualifies) gets a pyright
client. lspconfig's `on_attach` (`:LspPyrightOrganizeImports`, `:LspPyrightSetPythonPath`) was never
overridden, and it now actually runs because a client attaches. Nothing else reads this file.
Check that no other `delance` or `pylance` text is left:
`git grep -n -i -e delance -e pylance -- after lua init.lua` must print only the new line-40
comment (`Pylance/basedpyright`).

### Step 2: Rewrite the feature entry
**File:** `.claude/skills/verify-nvim-config/features/lsp.md:14-40` (the "Driving it" recipe, the
end states, and the first Gotcha)
**Change:** Replace the pyright recipe lines (21-23) with the attach, binary, log and diagnostic
checks from the Proof. Replace the end-state paragraph (26-29). Replace the "Product finding"
gotcha (33-36) with the fixed history and the miniconda shadowing note. The other sections stay.
**Code:** full final file content:
````markdown
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
- gopls takes up to ~30 s to attach on the first Go file: wait, do not sleep. pyright's first
  attach on the fixture takes a few seconds.
- lua_ls writes `log/` and `meta/` into its install dir. `up` re-points Mason's launcher to the
  run's copy (see SKILL.md Gotchas); `doctor`'s `seed`/`live` lines prove nothing wrote through.
- `lsp.log` also carries harmless `Cannot find request with id N whilst attempting to cancel`.
````
**Impact:** doc only. The pyright versions, the `reportAssignmentType` code and the "a few seconds"
claim must match what the Proof runs print. If they differ, write what was observed, not this
draft.

### Step 3: Prove it (Verification -> Proof), record evidence, commit
Run Journeys 1-3 below in order. After the last `down`, write
`.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-2.md` (template in the Proof section). Then commit the
two source files, then the evidence file on its own (execution rule 4):
```sh
cd "$WT"   # this phase's own worktree root (index § Execution rules)
git commit -m "fix(lsp): start pyright with Mason's pyright-langserver

after/lsp/pyright.lua overrode cmd with delance-langserver, which no
machine has, so 0.11 rejected the config and Python buffers never got a
server. Drop the override and inherit nvim-lspconfig's
pyright-langserver --stdio (Mason's pyright). Settings and capabilities
are unchanged.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- after/lsp/pyright.lua .claude/skills/verify-nvim-config/features/lsp.md
git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-2.md
git commit -m "docs(evidence): phase 2 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-2.md
```
Do not push (invariant 8).

## Principles applied

- Laziness protocol: delete the `cmd` override rather than replace it with an explicit
  `pyright-langserver` command. The file then has no command to keep in sync with Mason. The fix
  is one deleted line plus comments, and `settings`/`capabilities` keep their values.
- Fix root causes: the plan quotes the repro (0 clients + the `lsp.log` line) and traces it to
  `after/lsp/pyright.lua:23` through the runtimepath merge. Journey 1 must reproduce it before the
  fix is synced in.
- Prove it works / Test behavior, not implementation: the proof does not read
  `vim.lsp.config.pyright.cmd`. It checks what the user gets: a client attached to `app.py`, the
  binary it really resolves to (`exepath`, which catches the miniconda shadow), and a real Pyright
  diagnostic on a pasted type error.

## Verification

**Build:** none (Lua config). The proof's `up` runs fail on any startup error in `:messages`.
**Tests:** no unit tests in this repo. `doctor` exits 0 on each run, which is invariant 1.
**Proof:**
- Harness: `.claude/skills/verify-nvim-config` (`scripts/verify.sh`), installed nvim 0.11.5
  (default `NVIM_BIN=/opt/nvim-linux-x86_64/bin/nvim`; do not export `VERIFY_NVIM`).
- Feature-map entries: `features/lsp.md` (edited in Step 2). `features/README.md` is phase 9's.
- Setup, for every journey (the Bash tool's shell is zsh, so run each block through `bash -c`
  or a script file. Never write `echo ====`):
  ```sh
  cd "$WT"   # this phase's own worktree root (index § Execution rules)
  V=.claude/skills/verify-nvim-config/scripts/verify.sh
  VH=$HOME/.local/state/nvim-config-verify
  CLIENTS='table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="pyright"})), ",")'
  BIN='vim.lsp.get_clients({bufnr=0, name="pyright"})[1].config.cmd[1] .. " " .. vim.fn.exepath("pyright-langserver")'
  DELANCE_SEEN='#vim.tbl_filter(function(l) return l:find("delance-langserver is not executable", 1, true) ~= nil end, vim.fn.readfile(vim.lsp.log.get_filename())) > 0'
  DIAG='(function() for _, d in ipairs(vim.diagnostic.get(0, {lnum = 5})) do if d.source == "Pyright" then return d.code end end return "none" end)()'
  ```

- **Journey 1: base reproduces the bug (must FAIL R2), `--live` then seeded.** Step 1's edit is
  already in the tree, so swap the base file in first (execution rule 2; never `git stash`). `up`
  snapshots the working tree.
  ```sh
  SW=$(mktemp -d); cp after/lsp/pyright.lua "$SW/"
  git show "$PHASE_BASE:after/lsp/pyright.lua" >after/lsp/pyright.lua   # base config: delance cmd back
  out=$($V up --live); echo "$out"; RUN=$(sed -n 's/^RUN=//p' <<<"$out")
  $V doctor $RUN
  $V keys $RUN : e Space app.py Enter
  $V wait $RUN 'vim.bo.filetype' python 10
  $V wait $RUN "$DELANCE_SEEN" true 30             # the log line appears
  $V lua $RUN "$CLIENTS"                           # prints an empty line (no pyright)
  $V lua $RUN '#vim.lsp.get_clients({bufnr=0, name="pyright"})'   # 0
  $V keys $RUN G o; $V keys $RUN --paste 'count: int = "three"'; $V keys $RUN Escape Escape
  $V lua $RUN "$DIAG"                              # none
  grep -c 'delance-langserver is not executable' $VH/$RUN/xdg/state/nvim/lsp.log   # >= 1
  ```
  Passes (that is, the bug is shown) when: `wait ok ... == true` for `DELANCE_SEEN`, the pyright
  count is `0`, `DIAG` prints `none`, and grep prints `1` or more.
  Keep `RUN` as `LIVE_RUN` for Journey 2. Do not `down` yet.
  Then repeat the same block with `$V up` instead of `$V up --live` (base file still in place), and keep
  that `RUN` as `SEED_RUN`. End state is the same.

- **Journey 2: the fix, same runs (must PASS R2).**
  ```sh
  cp "$SW/pyright.lua" after/lsp/pyright.lua      # Step 1's edit back
  for RUN in $LIVE_RUN $SEED_RUN; do
    L=$VH/$RUN/xdg/state/nvim/lsp.log; n=$(wc -l <"$L")   # base lines stay in the log; only count new ones
    $V sync $RUN                                   # snapshot + restart nvim in the pane
    $V doctor $RUN                                 # exit 0; `code` line not WARN
    $V keys $RUN : e Space app.py Enter
    $V wait $RUN "$CLIENTS" pyright 90
    $V lua $RUN "$BIN"
    $V keys $RUN G o; $V keys $RUN --paste 'count: int = "three"'; $V keys $RUN Escape Escape
    $V wait $RUN "$DIAG" reportAssignmentType 60
    $V screen $RUN pyright-diagnostic
    tail -n +$((n + 1)) "$L" | grep -c delance || true     # must print 0
  done
  ```
  Passes when, for both runs: `wait ok ... == pyright`. `BIN` prints
  `pyright-langserver $VH/<RUN>/xdg/data/nvim/mason/bin/pyright-langserver`, which must contain
  `/xdg/data/nvim/mason/bin/` and must not contain `miniconda3`. `wait ok ... ==
  reportAssignmentType`. The screen shows a diagnostic sign/virtual text on line 6. The tail grep
  prints `0`. If `DIAG` times out but the client attached, record the `screen` output and
  `vim.diagnostic.get(0)` via `$V lua`, and mark that journey `inconclusive` with the reason. Never
  loosen the expected value.

- **Journey 3: fresh seeded start with the fix (no base lines in the log at all).**
  ```sh
  out=$($V up); echo "$out"; RUN=$(sed -n 's/^RUN=//p' <<<"$out")
  $V keys $RUN : e Space app.py Enter
  $V wait $RUN "$CLIENTS" pyright 90
  grep -c delance $VH/$RUN/xdg/state/nvim/lsp.log || true    # 0
  $V down $LIVE_RUN; $V down $SEED_RUN; $V down $RUN
  ```
  Passes when `wait ok ... == pyright`, grep prints `0`, and `$V up` printed no startup errors.

- **Neighbor check:** the existing lua_ls/gopls journey in `features/lsp.md`, run in the Journey 3
  run before `down`:
  `$V keys $RUN : e Space sample.lua Enter; $V wait $RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="lua_ls"})), ",")' lua_ls 60`
  and the same for `main.go`/`gopls` (90 s). Both `wait ok`. Also
  `$V lua $RUN 'vim.tbl_isempty(vim.lsp.config.pyright.settings.python.analysis.inlayHints) == false and vim.lsp.config.pyright.settings.python.analysis.typeCheckingMode'`
  prints `standard`, which shows the settings still merge in.
- **Evidence record:** after the last `down`, write `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-2.md`
  (this phase's own file; phase 9 builds the set's `evidence.md` index from it):
  ```markdown
  ## Phase 2 (R2: pyright)
  - base --live: RUN=<LIVE_RUN>, ~/.local/state/nvim-config-verify/<LIVE_RUN>/evidence/ (NN-lua-* pyright 0, DIAG none; logs/lsp.log delance line)
  - base seeded: RUN=<SEED_RUN>, .../<SEED_RUN>/evidence/
  - fix --live (sync): same LIVE_RUN, LOG.md `wait ok ... pyright`, `... reportAssignmentType`, NN-screen-pyright-diagnostic.txt
  - fix seeded (sync): same SEED_RUN, same files
  - fresh seeded: RUN=<RUN>, LOG.md wait ok pyright, logs/lsp.log 0 delance
  ```
- Cost: none (no paid drives; runs are offline).

**Exit criteria:** on base, both `--live` and seeded show pyright `0` clients, the `delance-langserver
is not executable` line in `lsp.log`, and no Pyright diagnostic. After the fix, both modes show
`wait ok ... pyright`, the command resolving to the run's Mason `pyright-langserver`, a `Pyright`
`reportAssignmentType` diagnostic on the pasted line, and no new `delance` line in `lsp.log`.
`settings`/`capabilities` values are unchanged (`git diff` of `after/lsp/pyright.lua` shows only
the `cmd` line removed and comment lines changed). `doctor` exits 0. `features/lsp.md` states the
observed end states. The commit
`fix(lsp): start pyright with Mason's pyright-langserver` is on the branch and not pushed.

## Handoffs

- **Phase 9 (R3/R9/R11):** `features/README.md:11` LSP row's "Known on the base" cell still says
  **pyright never starts** (`delance-langserver`). Phase 9 owns that file. Rewrite the cell to the
  fixed state (or "fixed by phase 2"). The phase 9 re-drive on 0.12.6 should include the pyright
  journey from `features/lsp.md`, which matters for the Deploy section's final "lsp journey
  (lua_ls, gopls, pyright)".
- **Phase 9 / `features/live-environment.md`:** if its journey summary mentions pyright `0`, it is
  stale after this phase. Phase 9 owns it.
- **Unassigned, out of scope (not R2):** `lua/config/lsp.lua:171-189` still calls
  `vim.lsp.enable` for `lua_ls/gopls/pyright/vimls` in addition to mason-lspconfig's
  `automatic_enable`. That is a duplicate enable path and `vimls` is not installed (it warns when
  missing). Left alone per scope. A lint that every `after/lsp/*.lua` `cmd[1]` is executable in the
  seed (principle 10) would also be a new verify-skill check, not R2. Possible follow-up card.

## Rollback

`git revert <phase-2 commit>` on the feature branch. That restores the delance `cmd`, the old
comment and the old `features/lsp.md`. `evidence-phase-2.md` may stay as history (or be
reverted with its own commit). No seed, live or Mason state was written.
