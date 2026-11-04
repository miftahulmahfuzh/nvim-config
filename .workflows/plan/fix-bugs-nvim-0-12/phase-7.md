# Phase 7: Drop the per-start gofumpt reinstall

**Plan set:** `FIX_BUGS_NVIM_0_12_PLAN.md`
**Analysis:** `docs/analyzer/20261104-102452-MRDD_code_analyzer.md`
**Satisfies:** R5 — no per-start `get_package("gofumpt"):install()`; starting nvim no longer runs a Mason install + `go install` when gofumpt is already there
**Depends on:** Phase 6
**Difficulty:** EASY
**Package:** `lua/` + `.claude/skills/verify-nvim-config/`

---

> **Set-wide execution rules** (plan index § Execution rules; they override any command below that disagrees):
> 1. `$WT` is **this phase's own worktree root** (`WT=$(git rev-parse --show-toplevel)`). Wave-1 phases run
>    concurrently in separate worktrees, so never `cd` into another phase's tree.
> 2. **No `git stash`** (the stash stack is shared by every worktree of the repo). Swap base and fix per file:
>    `SW=$(mktemp -d)`; BASE = `cp <path> "$SW/" && git show "$PHASE_BASE:<path>" ><path>`; FIX = `cp "$SW/<file>" <path>`,
>    where `PHASE_BASE=$(git rev-parse HEAD)` is recorded before this phase's first edit. A new file's BASE is `mv <path> "$SW/"`.
> 3. Commit with an explicit pathspec: `git add -- <new files>` then `git commit -m "..." -- <every path>`.
> 4. Evidence goes to `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-7.md`, this phase's own file (never a shared one),
>    written only **after every run of the phase is down** (the file is inside the snapshotted tree; a mid-run write makes
>    `doctor` print `code WARN`). It is committed as the phase's last commit:
>    `git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-7.md && git commit -m "docs(evidence): phase 7 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-7.md`.
>    `.workflows/` is tracked (the orchestrator commits the plan set); commit nothing else under it unless this plan says so.
> 5. Never `git push`. Never write `~/.config/nvim`, `~/.local/share/nvim` or `/opt/nvim-linux-x86_64`.

## Goal

mason.nvim's spec config stops calling `require("mason-registry").get_package("gofumpt"):install()`
on every start. gofumpt stays installed and kept current by mason-tool-installer, which the config
already runs (`ensure_installed = { "gofumpt", "stylua" }`, `auto_update = true`, `run_on_start = true`).
The verify seed drops its special case for that startup install, and the feature docs and SKILL.md
describe the new end state.

## Root cause (reproduced while planning, base `a14aef9`, nvim 0.11.5, seeded run `1104-104107-1927603`)

- `lua/plugin_specs.lua:526-527` (base numbering), in mason.nvim's `config`:
  `require("mason-registry").get_package("gofumpt"):install()`. mason.nvim has no lazy trigger, so
  this runs on every start. In mason v2.1.0 (`57e5a8a`), `install()` on an installed package
  reinstalls it.
- Evidence: after a plain `verify.sh up`, `<run>/xdg/state/nvim/mason.log` contains
  `InstallRunner.lua:40: Executing installer for Package(name=gofumpt)`, then (offline)
  `InstallRunner.lua:93: Installation failed for Package(name=gofumpt) error=spawn: go failed with exit code 1`.
  The same file also has two registry-refresh ERROR blocks (`providers.lua:81 ... wget failed`,
  `mason-registry/init.lua:126: Failed to update registries`). Those come from
  `mason-registry.refresh()`, which mason-tool-installer's `check_install` and mason-lspconfig both
  call. They are not from the gofumpt call and **stay after the fix**. Evidence kept at
  `~/.local/state/nvim-config-verify/1104-104107-1927603/`.

### What mason-tool-installer does without the call (read from `~/.local/share/nvim/lazy/mason-tool-installer.nvim` @ `517ef59`)

- `plugin/mason-tool-installer.lua`: a one-shot `VimEnter` autocmd calls `run_on_start()`, which
  runs `vim.defer_fn(check_install, start_delay=0)`. It does **not** run inside `nvim --headless -c ...`
  before VimEnter.
- `check_install` calls `mr.refresh(ensure_installed)`. The callback ignores the refresh result,
  so offline it falls back to the cached registry. For each tool:
  - **not installed**: `do_install(p)` → `p:install()`. A missing gofumpt is installed, and
    `mason.log` shows `Executing installer for Package(name=gofumpt)`. The notify comes from
    mason-tool-installer (`gofumpt: installing`, and offline `gofumpt: failed to install`).
  - **installed, `auto_update = true`** (mason v2 path, `init.lua:210-217`): it compares
    `p:get_latest_version()` from the (cached or refreshed) registry with `p:get_installed_version()`
    and installs **only if they differ**. So it does not reinstall on every start: online it updates
    once per upstream release, and offline nothing happens while the cached registry matches.
    Measured: seed and live both have gofumpt `v0.12.0` installed, and their registries list
    `v0.12.0`. stylua is `v2.6.0` = `v2.6.0`.
  - `do_install` skips when `p:is_installing()` (v2 path), so it never collides with another install.
- mason-lspconfig (`7d527c7`) `init.lua:31`: `if not platform.is_headless and #ensure_installed > 0`,
  so its ensure_installed never runs in a headless nvim.

Consequence for the seed: `seed.lua` runs as `nvim --headless -c "luafile seed.lua"`, after init.lua
and before VimEnter, and ends with `qa!`. Once the config's call is gone, nothing is installing when
the seed's Mason step starts. That makes the `pkg:is_installing()` branch at `seed.lua:143-153` dead.

## Interface Contract

**Deletes:** the call `require("mason-registry").get_package("gofumpt"):install()` and its comment
`-- Ensure gofumpt is installed` in `lua/plugin_specs.lua`, mason.nvim spec `config`
(base `:526-527`); the `if pkg:is_installing() then ... (installed by the config's own startup install)`
branch in `.claude/skills/verify-nvim-config/scripts/seed.lua:143-153`.
**Renames:** none
**Creates:** none (the startup.md journeys are rewritten, and one is added for mason-tool-installer)
**Signature changes:** none. The mason.nvim spec's final text:

```lua
  -- Personal addition
  {
    "williamboman/mason.nvim",
    -- Removed `cmd` so it loads on startup as a dependency for other plugins.
    -- gofumpt/stylua are ensured by mason-tool-installer below (installs a missing tool,
    -- updates when the registry has a newer version); never install from here on every start.
    config = function()
      require("mason").setup()
    end,
  },
```

**Requires (from earlier phases):** Phase 6 has rewritten `plugin_specs.lua` lines 1-18 (bootstrap)
and the final `require("lazy").setup` guard, plus `features/startup.md`'s `--bare` section, its
second Gotcha ("the lazy bootstrap ... never checks the result") and SKILL.md's `--bare` bullet.
This phase locates its hunks by text, not by line number, so phase 6's line shift does not matter.
Phase 4 has removed opencode sentences from SKILL.md, and phase 5 changed SKILL.md's deploy sentence.
None of them touches the "Downloads are the seed's job" bullet.
**Leaves alone (owned by others):** mason-tool-installer's spec and `ensure_installed` list (phase 9
adds `tree-sitter-cli`); mason-lspconfig spec; the hop spec just above mason (phase 8); seed.lua's
pin loop (phase 8) and treesitter step (phase 9); `verify.sh` (phases 4, 5, 8); `features/README.md`
"Known on the base" column (phase 9, invariant 6); startup.md's bare section and bootstrap gotcha
(phase 6) and its version line (phase 9).

## Files

| File | Action | What changes |
|---|---|---|
| `lua/plugin_specs.lua` (~:521-529 base; the `"williamboman/mason.nvim",` spec that has `config`, not the dependency mention at :47) | modify | drop the gofumpt install and its comment; add a 2-line comment saying where gofumpt is ensured |
| `.claude/skills/verify-nvim-config/scripts/seed.lua:118, :140-160` | modify | drop the `is_installing` special case; rewrite the step comment to say why nothing installs concurrently |
| `.claude/skills/verify-nvim-config/features/startup.md:7-8, :27-37, :50-53` (base numbering) | modify | Sub-features Mason bullet, the "Mason's startup install with no network" journey (rewritten, plus a mason-tool-installer journey), first Gotcha |
| `.claude/skills/verify-nvim-config/SKILL.md:151-155` | modify | "Downloads are the seed's job" bullet: remove the gofumpt sentence |

## Implementation Steps

### Step 1: Remove the per-start install from mason.nvim's config
**File:** `lua/plugin_specs.lua:521-529` (base numbering; after phase 6 find the block by its text `"williamboman/mason.nvim",` followed by `-- Removed \`cmd\``)
**Change:** replace the whole spec block (from `-- Personal addition` through its closing `},`) with:
**Code:**
```lua
  -- Personal addition
  {
    "williamboman/mason.nvim",
    -- Removed `cmd` so it loads on startup as a dependency for other plugins.
    -- gofumpt/stylua are ensured by mason-tool-installer below (installs a missing tool,
    -- updates when the registry has a newer version); never install from here on every start.
    config = function()
      require("mason").setup()
    end,
  },
```
Base text being replaced (verbatim):
```lua
  -- Personal addition
  {
    "williamboman/mason.nvim",
    -- Removed `cmd` so it loads on startup as a dependency for other plugins.
    config = function()
      require("mason").setup()
      -- Ensure gofumpt is installed
      require("mason-registry").get_package("gofumpt"):install()
    end,
  },
```
Do not touch the following `"WhoIsSethDaniel/mason-tool-installer.nvim"` block.
**Impact:** no Mason install runs at startup when every tool is present and up to date. A missing
gofumpt is still installed by mason-tool-installer on VimEnter. With network, gofumpt is updated
only when the registry publishes a new version, no longer reinstalled on every launch.

### Step 2: Drop the seed's special case for the config's startup install
**File:** `.claude/skills/verify-nvim-config/scripts/seed.lua:118` and `:140-160`
**Change:** replace the step comment at :118 and the `pending`/install loop at :140-160.
**Code:** line 118 becomes:
```lua
-- Mason: the tools mason-tool-installer and mason-lspconfig ensure, installed synchronously.
-- Nothing else is installing here: this file runs from `-c` before VimEnter (mason-tool-installer's
-- run_on_start), mason-lspconfig skips ensure_installed in a headless nvim, and the config's own
-- Mason spec installs nothing.
```
and lines 140-160 (from `local pending = {}` through the `end` that closes the `for _, name` loop) become:
```lua
  local pending = {}
  for _, name in ipairs(names) do
    local pkg = registry.get_package(name)
    if pkg:is_installed() and not update then
      log("ok   mason %s already installed", name)
    else
      pending[name] = true
      pkg:install({}, function(success, err)
        log("%s mason %s%s", success and "ok  " or "FAIL", name, success and "" or (": " .. tostring(err)))
        pending[name] = nil
      end)
    end
  end
```
The rest of the step is unchanged: `vim.wait(900000, ...)`, the timeout loop, `log("done")`, `vim.cmd("qa!")`.
gofumpt stays in `local names = { "gofumpt", "stylua" }` (:128, unchanged), so the seed still installs it.
**Impact:** the seed installs gofumpt through the same path as every other tool. This phase does not
re-seed (invariant 5). Phase 8's re-seed is the first run of this code: its seed log must show
`ok   mason gofumpt already installed` (or `ok   mason gofumpt` on a fresh seed) and no `FAIL mason`.
Journey 3 below shows ahead of that re-seed that nothing is installing in the seed's context.

### Step 3: Rewrite `features/startup.md` Mason text
**File:** `.claude/skills/verify-nvim-config/features/startup.md`

(a) Sub-features bullet, base `:7-8`. Replace
```markdown
- Mason (`mason.nvim`, mason-tool-installer for `gofumpt`/`stylua`, mason-lspconfig's
  `ensure_installed`), plus an unconditional `get_package("gofumpt"):install()` on every start.
```
with
```markdown
- Mason (`mason.nvim`, mason-tool-installer for `gofumpt`/`stylua` with `auto_update` and
  `run_on_start`, mason-lspconfig's `ensure_installed`). A start where every tool is installed and
  matches the registry's version installs nothing.
```

(b) The journey, base `:27-37` (from `Mason's startup install with no network:` through
`... because Mason stages installs.`). Replace the whole paragraph group with the text below. The
implementer replaces each `<measured ...>` with the value actually observed in the Proof run
(seeded), and quotes the run id the way the other end states do.
````markdown
Mason at startup with no network (nothing reinstalls):

```sh
$V headless RUN +'lua local r = require("mason-registry"); local t = {}; for _, n in ipairs { "gofumpt", "stylua" } do if r.get_package(n):is_installing() then t[#t + 1] = n end end; io.stdout:write("installing=", table.concat(t, ","), "\n")'
cat <run>/xdg/state/nvim/mason.log 2>/dev/null | grep -c 'Executing installer for Package(name=gofumpt)'
```

End state seen: `installing=` (empty), no `Neovim exited while the following packages were
installing` line, and the grep prints `0`. `mason.log` still carries the offline registry-refresh
ERRORs (`Failed to update registries`) whenever the cached registry is due for a refresh. Those come
from `mason-registry.refresh()`, called by mason-tool-installer and mason-lspconfig, not from an
install. <measured: number of `Failed to update registries` lines, seeded run id>

mason-tool-installer still ensures a missing gofumpt (`--live` only, because live Mason files are
copies; never delete from a seeded run, whose files are hard links into the seed):

```sh
$V up --live                                    # note RUN and EVIDENCE
D=$(dirname "$EVIDENCE")
rm -rf "$D/xdg/data/nvim/mason/packages/gofumpt" "$D/xdg/data/nvim/mason/bin/gofumpt"
$V sync RUN
$V wait RUN 'vim.fn.join(vim.fn.readfile(vim.fn.stdpath("state") .. "/mason.log"), "\n"):find("Installation failed for Package%(name=gofumpt%)") ~= nil' true 60
```

End state seen: `mason.log` gains `Executing installer for Package(name=gofumpt)` then
`Installation failed for Package(name=gofumpt)` (offline), and `:messages` shows
mason-tool-installer's `gofumpt: installing` / `gofumpt: failed to install`. With network, the
install succeeds. <measured: live run id>
````

(c) First Gotcha, base `:50-53`. Replace
```markdown
- Product finding (base): `plugin_specs.lua:527` calls `get_package("gofumpt"):install()` in
  mason's `config` on every start. With network, that is a download plus `go install` per nvim
  launch (Go may first fetch a 1.26 toolchain), and quitting fast aborts it with the message above.
  `mason-tool-installer` already ensures gofumpt.
```
with
```markdown
- gofumpt and stylua are kept by mason-tool-installer alone (`auto_update = true`,
  `run_on_start = true`). On VimEnter it refreshes the registry, installs a missing tool, and
  reinstalls an installed one only when the registry's latest version differs from the installed
  one. Online that happens once per upstream release; offline it compares against the cached
  registry, so nothing installs. It never runs in `nvim --headless -c ...` before VimEnter, which
  is why the seed installs every Mason tool itself. (Before `perf(mason)`, mason's `config` also
  ran `get_package("gofumpt"):install()` on every start: a `go install` per launch.)
```
Leave the second Gotcha (the bootstrap one), as phase 6 left it, and the `--bare` section alone.

**Impact:** the feature map records the new end state and the proof recipe. User-facing: no Mason
install at startup.

### Step 4: SKILL.md Gotcha "Downloads are the seed's job"
**File:** `.claude/skills/verify-nvim-config/SKILL.md:151-155`
**Change:** replace
```markdown
- **Downloads are the seed's job.** Runs have no network at all (`unshare -n`). This is a real
  fence: raw sockets and native code are blocked too, not only proxied HTTP. At startup, in every
  mode, lazy's install of a missing plugin fails, and Mason's registry refresh and the config's
  unconditional `get_package("gofumpt"):install()` fail into `mason.log`. Mason stages installs,
  so the installed gofumpt stays.
```
with
```markdown
- **Downloads are the seed's job.** Runs have no network at all (`unshare -n`). This is a real
  fence: raw sockets and native code are blocked too, not only proxied HTTP. At startup, in every
  mode, lazy's install of a missing plugin fails, and Mason's registry refresh fails into
  `mason.log`, as does any install mason-tool-installer or mason-lspconfig starts for a tool the
  run lacks. Mason stages installs, so an installed tool stays.
```
**Impact:** docs only.

### Step 5: Commit
`git commit -m "perf(mason): stop reinstalling gofumpt on every start" -m "<attribution trailer>" -- lua/plugin_specs.lua .claude/skills/verify-nvim-config/scripts/seed.lua .claude/skills/verify-nvim-config/features/startup.md .claude/skills/verify-nvim-config/SKILL.md`,
then, after every run is down, the evidence commit of execution rule 4 (`evidence-phase-7.md` alone).
Do not push.

## Principles applied

- Subtract before you add: the seed's `is_installing` branch existed only for the call this phase deletes, so it is deleted rather than reworded (Step 2). A comment records why no concurrent install can happen.
- Laziness protocol: no replacement guard such as `if not pkg:is_installed() then install()` in mason's config. mason-tool-installer already does exactly that, so Step 1 only deletes the call.
- Fix root causes: the reproduction (mason.log `Executing installer for Package(name=gofumpt)` on a plain start) is traced to `plugin_specs.lua:527` and shown on the base before the fix (Journey 1). The leftover registry-refresh ERRORs are attributed to `mason-registry.refresh()` so they are not mistaken for the bug.
- Prove it works: the proof checks the real startup in both modes, the seed's headless context, the mason-tool-installer fallback (missing gofumpt is still installed) and the go format-on-save journey, not just the diff.

## Verification

**Build:** `nvim --headless -u NONE +'lua assert(loadfile("lua/plugin_specs.lua")); assert(loadfile(".claude/skills/verify-nvim-config/scripts/seed.lua"))' +qa` from the worktree root. It exits 0 with no output, which shows both files parse.
**Tests:** no unit tests in this repo; the Proof journeys are the tests.
**Proof:**
- Harness: `.claude/skills/verify-nvim-config` (`V=.claude/skills/verify-nvim-config/scripts/verify.sh`, run from the worktree root, default `NVIM_BIN` = installed 0.11.5; do **not** set `VERIFY_NVIM`).
- Feature-map entries: `features/startup.md` (rewritten here), `features/format-on-save.md` (Go journey, read-only neighbour check).
- Procedure: run the base drives with the base files swapped in (execution rule 2: `SW=$(mktemp -d)`, copy `lua/plugin_specs.lua` and `scripts/seed.lua` to `$SW`, `git show "$PHASE_BASE:<path>" ><path>` for both; never `git stash`), then copy them back from `$SW` and use **fresh `up` runs** for the after drives. Use new runs rather than `sync`, because `mason.log` is cumulative per run. `down` every run when done.

Helper used below (`MLOG` = the run's mason log, missing file counts as 0):
```sh
V=.claude/skills/verify-nvim-config/scripts/verify.sh
mcount() { cat "$(dirname "$EVIDENCE")/xdg/state/nvim/mason.log" 2>/dev/null | grep -c "$1"; }
```
Each `up` prints `RUN=` and `EVIDENCE=`; `eval "$($V up ... | grep -E '^(RUN|EVIDENCE)=')"` captures them.

- **Journey 1 — reproduce on the base (must FAIL before the fix), seeded and live.** With the base files swapped in:
  ```sh
  SW=$(mktemp -d); for f in lua/plugin_specs.lua .claude/skills/verify-nvim-config/scripts/seed.lua; do cp "$f" "$SW/"; git show "$PHASE_BASE:$f" >"$f"; done
  eval "$($V up | grep -E '^(RUN|EVIDENCE)=')"
  $V wait $RUN 'vim.fn.join(vim.fn.readfile(vim.fn.stdpath("state") .. "/mason.log"), "\n"):find("Installation failed for Package%(name=gofumpt%)") ~= nil' true 60
  mcount 'Executing installer for Package(name=gofumpt)'      # base: >= 1
  $V down $RUN
  eval "$($V up --live | grep -E '^(RUN|EVIDENCE)=')"
  $V wait $RUN 'vim.fn.join(vim.fn.readfile(vim.fn.stdpath("state") .. "/mason.log"), "\n"):find("Installation failed for Package%(name=gofumpt%)") ~= nil' true 60
  mcount 'Executing installer for Package(name=gofumpt)'      # base: >= 1
  $V down $RUN
  ```
  Base end state: both `wait`s succeed and both counts are `>= 1` (planning measured `1` seeded, run `1104-104107-1927603`).
- **Journey 2 — after the fix: no gofumpt install on start, seeded and live.** Copy the fix back (`cp "$SW/plugin_specs.lua" lua/plugin_specs.lua; cp "$SW/seed.lua" .claude/skills/verify-nvim-config/scripts/seed.lua`), then for each of `$V up` and `$V up --live`:
  ```sh
  eval "$($V up | grep -E '^(RUN|EVIDENCE)=')"          # then again with: $V up --live
  $V lua $RUN 'vim.g.p7_t0 = vim.uv.hrtime(); return vim.g.p7_t0'
  $V wait $RUN '(vim.uv.hrtime() - vim.g.p7_t0) > 15e9' true 30   # 15 s window; on the base the failure lands within ~1 s
  mcount 'Executing installer for Package(name=gofumpt)'      # after: 0
  mcount 'Installation failed for Package(name=gofumpt)'      # after: 0
  mcount 'Failed to update registries'                        # record the number: refresh errors that remain, not an install
  $V lua $RUN 'require("mason-registry").get_package("gofumpt"):is_installed()'   # true
  $V cli $RUN test -x "$(dirname "$EVIDENCE")/xdg/data/nvim/mason/bin/gofumpt"    # exit 0 (path is the run dir; inside the netns the host path is the same)
  $V doctor $RUN                                              # exit 0, messages ok
  ```
  End state: both gofumpt counts are `0` in both modes, `is_installed()` returns `true`, `mason/bin/gofumpt` exists (if `cli`'s cwd/namespace hides the path, run `test -x` from the host shell instead; it is the same file), and `doctor` exits 0. If any gofumpt line still appears, record which line it is and from which file (`InstallRunner.lua` = an install; `providers.lua`/`init.lua:126` = refresh only). Anything from `InstallRunner.lua` naming gofumpt fails the journey.
- **Journey 3 — the seed's context has nothing installing (backs Step 2).** In an after-fix seeded run (and, for contrast, in the base seeded run of Journey 1 before `down`):
  ```sh
  $V headless $RUN +'lua local r = require("mason-registry"); local t = {}; for _, n in ipairs { "gofumpt", "stylua" } do if r.get_package(n):is_installing() then t[#t + 1] = n end end; io.stdout:write("installing=", table.concat(t, ","), "\n")'
  ```
  End state: the `NN-headless-*.txt` evidence shows `installing=` (empty) and no `Neovim exited while the following packages were installing` after the fix. The base shows `installing=gofumpt` plus that abort message.
- **Journey 4 — mason-tool-installer still installs a missing gofumpt (after the fix, `--live` only).** Run the `--live` recipe from the new startup.md section (Step 3b): `up --live`, `rm -rf` the run's `mason/packages/gofumpt` and `mason/bin/gofumpt`, `$V sync $RUN`, then `wait` for `Installation failed for Package(name=gofumpt)`. End state: `mcount 'Executing installer for Package(name=gofumpt)'` = `1` (only mason-tool-installer's attempt) and `$V lua $RUN 'vim.fn.execute("messages")'` contains `gofumpt: installing`. Never run this on a seeded run: its Mason files are hard links into the seed.
- **Neighbor check — Go format-on-save (features/format-on-save.md), after the fix, seeded and live:**
  ```sh
  $V keys $RUN : e Space main.go Enter; $V keys $RUN 6 G A Space Escape; $V keys $RUN : w Enter
  $V cli $RUN git diff main.go
  ```
  End state: the diff shows `-	var x = a+b` / `+	x := a + b` and `+	fmt.Println(add(1, 2))`, the same as the base end state in format-on-save.md.
- Evidence: after the last `down`, write a `## Phase 7` section into `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-7.md` (this phase's own file; phase 9 indexes it). It lists every run id and evidence path: Journey 1 base (seeded + live), Journey 2 after (seeded + live, with the three counts), Journey 3 headless files (base + after), Journey 4 live run, and the neighbour-check `cli` files (seeded + live).
- Cost: none (no paid drives; everything runs offline).

**Exit criteria:** On 0.11.5, a plain start writes `Executing installer for Package(name=gofumpt)`
to `mason.log` on the base (seeded and live). After the fix it writes none from the config (count `0`, seeded
and live). `mason/bin/gofumpt` is still present. A missing gofumpt is still picked up by
mason-tool-installer (Journey 4). The Go journey still turns `var x = a+b` into `x := a + b`.
`git grep -n 'get_package("gofumpt")'` prints matches only under `docs/` and `.workflows/` and in startup.md's
historical parenthesis. The commit `perf(mason): stop reinstalling gofumpt on every start` exists
on the branch and is not pushed.

## Handoffs

- `features/README.md:8` "Known on the base" still says `gofumpt reinstalled on every start`. Phase 9 owns that column (invariant 6) and should drop that phrase when it rewrites the table.
- Phase 8 (first re-seed after this change): check the seed log for `ok   mason gofumpt ...` and no `FAIL mason`. That is the first execution of Step 2's simplified loop.
- Phase 9 adds `tree-sitter-cli` to mason-tool-installer's `ensure_installed`. With `auto_update = true` it follows the same rule described in startup.md's new Gotcha (install when missing, update only on a newer registry version). That text needs no change, but phase 9 may want to name the tool in the Sub-features bullet ("for `gofumpt`/`stylua`").

## Rollback

`git revert <phase-7 commit>`. This restores the call, the seed special case and the docs. No
re-seed or live state is involved. The seed's installed gofumpt is unaffected either way.
