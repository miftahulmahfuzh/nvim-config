# Phase 4: Purge opencode (config + verify fake)

**Plan set:** `FIX_BUGS_NVIM_0_12_PLAN.md`
**Analysis:** `docs/analyzer/20261104-102452-MRDD_code_analyzer.md` (Entry Points E, F; Reference List rows R8)
**Satisfies:** R8 — purge opencode from the config and from the verify skill
**Depends on:** none
**Difficulty:** NORMAL
**Package:** `lua/` + `.claude/skills/verify-nvim-config/`

---

> **Set-wide execution rules** (plan index § Execution rules; they override any command below that disagrees):
> 1. `$WT` is **this phase's own worktree root** (`WT=$(git rev-parse --show-toplevel)`). Wave-1 phases run
>    concurrently in separate worktrees, so never `cd` into another phase's tree.
> 2. **No `git stash`** (the stash stack is shared by every worktree of the repo). Swap base and fix per file:
>    `SW=$(mktemp -d)`; BASE = `cp <path> "$SW/" && git show "$PHASE_BASE:<path>" ><path>`; FIX = `cp "$SW/<file>" <path>`,
>    where `PHASE_BASE=$(git rev-parse HEAD)` is recorded before this phase's first edit. A new file's BASE is `mv <path> "$SW/"`.
> 3. Commit with an explicit pathspec: `git add -- <new files>` then `git commit -m "..." -- <every path>`.
> 4. Evidence goes to `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-4.md`, this phase's own file (never a shared one),
>    written only **after every run of the phase is down** (the file is inside the snapshotted tree; a mid-run write makes
>    `doctor` print `code WARN`). It is committed as the phase's last commit:
>    `git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-4.md && git commit -m "docs(evidence): phase 4 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-4.md`.
>    `.workflows/` is tracked (the orchestrator commits the plan set); commit nothing else under it unless this plan says so.
> 5. Never `git push`. Never write `~/.config/nvim`, `~/.local/share/nvim` or `/opt/nvim-linux-x86_64`.

## Goal

After this phase the config no longer contains or loads an opencode helper: `lua/custom/opencode.lua` is
gone and `lua/config/fzf-lua.lua` no longer requires it. The verify skill no longer plants a fake
`opencode`, a per-run `bin/` or `sink/` dir, or a `VERIFY_SINK` env var. `doctor` has no opencode line,
and no doc mentions opencode. The run's PATH still leaves out every per-user tool dir, so the owner's
real `~/.opencode/bin/opencode` stays unreachable from a run (`command -v opencode` prints nothing).

## Interface Contract

**Deletes:**
- file `lua/custom/opencode.lua` (whole module, 152 lines; `M.send_files_from_fzf`, `M.send_visual_selection`, `M.config`). `lua/custom/` keeps `git_tags.lua`.
- `lua/config/fzf-lua.lua:4` `local opencode = require("custom.opencode")` (unused local).
- `verify.sh` `write_fake_opencode()` (`:212-224`) and its call (`:330`).
- `verify.sh` env var `VERIFY_SINK` (`:110`), the per-run `sink/` **and `bin/`** dirs (mkdir `:283`, PATH entry `:87`, down copy `:672`, down cleanup `:677`).
- `verify.sh` doctor `opencode` check (`:434-435`).
- `SKILL.md:67` doctor bullet `opencode`; "and the opencode sink" (`:114`); the opencode sentences in the Gotchas "Never driven" bullet (`:142-146`).
- `features/fzf-lua.md:29` gotcha.

**Renames:** none
**Creates:** none
**Signature changes:** `verify.sh` `run_path DIR` -> `run_path` (no argument; its only caller `run_env` at `:103` changes with it).
**Requires (from earlier phases):** none.
**Leaves alone (owned by others):**
- `verify.sh:639` `cmd_live` deploy line and the SKILL.md sentence "deploying is the owner's `git -C ~/.config/nvim pull --ff-only`, which `live` prints and never runs" (Phase 5). Lines 139-141 of the bullet stay byte-identical, and line 142 only loses its trailing ` The`.
- `verify.sh` `cmd_seed`, the `cmd_up` live branch `:298-322` (Phase 8). Phase 4 changes only the `cmd_up` mkdir line `:283` and the `write_fake_opencode` call `:330`, both outside the live branch.
- `features/README.md`, `features/live-environment.md` (Phase 9 / Phase 5), `features/startup.md` (Phases 6/7/9), `plugin_specs.lua`, `seed.lua`, everything tmux.

**Final text of the SKILL.md "Never driven" bullet (Phase 5 edits this next):**

```markdown
- **Never driven, no flag turns it on.** A `git push` to any real remote (WORK's only remote is
  the run's bare repo; `GIT_SSH_COMMAND=/bin/false`, no global git config, no credentials, and no
  network anyway). Writing `~/.config/nvim` (deploying is the owner's `git -C ~/.config/nvim pull
  --ff-only`, which `live` prints and never runs). The owner's tmux server (`-L default`).
  AI or Copilot-style plugins: none in the spec; `~/.local/share/nvim/avante` and other
  leftovers are never copied. Clipboard: `+` goes to the run's tmux buffer, never the Windows
  clipboard (no `clip.exe` on the run's PATH, no DISPLAY).
```

## Files

| File | Action | What changes |
|---|---|---|
| `lua/config/fzf-lua.lua` | modify (`:4`) | drop the unused `require("custom.opencode")` |
| `lua/custom/opencode.lua` | delete | the whole tmux-to-opencode helper, which nothing calls |
| `.claude/skills/verify-nvim-config/features/fzf-lua.md` | modify (`:29`) | drop the `custom.opencode` gotcha |
| `.claude/skills/verify-nvim-config/scripts/verify.sh` | modify (`:84-90`, `:103`, `:110`, `:212-225`, `:283`, `:330`, `:434-435`, `:672`, `:677`) | remove the fake opencode, `bin/`, `sink/`, `VERIFY_SINK`, the doctor line; reword the PATH comments |
| `.claude/skills/verify-nvim-config/SKILL.md` | modify (`:67`, `:113-114`, `:139-148`) | remove the doctor bullet, the sink mention and the opencode sentences in "Never driven" |

`git grep -n -i opencode` at base (`a14aef9`) has hits in exactly these 5 files plus the plan set
(`docs/plans/FIX_BUGS_NVIM_0_12_PLAN.md`, `.workflows/plan/...`, tracked once the orchestrator commits it), which is exempt. There are no hits in CLAUDE.md, README.md,
any todos.md, `.tmux.conf` or `.tmux.conf.local`. `git grep -n -i sink` hits only `verify.sh:110,219,283,672,677` and
`SKILL.md:114,145`, and all of them are opencode-only. `git grep -n '\$dir/bin'` hits only `verify.sh:87,215,223,283,435,677`,
and all of those are opencode-only too.

## Implementation Steps

Do Step 0 (the base proof) **before any edit**. It needs the base `verify.sh`.

### Step 0: Capture the base (failure-first evidence)
**File:** none. This step writes `.workflows/plan/fix-bugs-nvim-0-12/phase-4-proof.sh` (from **Verification**) and runs it.
**Change:** On the clean base tree, run `bash .workflows/plan/fix-bugs-nvim-0-12/phase-4-proof.sh base live`, then the same with `base seeded`. Both must exit 0 and print `PASS doctor shows the fake opencode line`, `PASS opencode resolves to the run's fake`, `PASS down copied a sink into evidence`, `PASS fzf-lua opens docs/guide.txt`. Keep the `RUN=` lines for the evidence file.
**Impact:** none. Runs are throwaway. The proof script lives under `.workflows/` and is written before the first run, so it is part of every snapshot from the start; it is committed with this phase's evidence commit (Step 13), never edited mid-run.

### Step 1: Drop the require in fzf-lua.lua
**File:** `lua/config/fzf-lua.lua:3-6`
**Change:** Delete line 4. The local `opencode` is never used in the file (`grep -n opencode` hits only line 4).
Before:
```lua
local actions = require("fzf-lua.actions")
local opencode = require("custom.opencode") -- Require our new, clean module

require("fzf-lua").setup({
```
After:
```lua
local actions = require("fzf-lua.actions")

require("fzf-lua").setup({
```
**Impact:** none at runtime. The module was loaded and then discarded.

### Step 2: Delete the opencode module
**File:** `lua/custom/opencode.lua` (whole file)
**Change:** `git rm lua/custom/opencode.lua`. `lua/custom/git_tags.lua` remains, and `lua/mappings.lua:162` still requires `custom.git_tags`.
**Impact:** Step 1 must land in the same commit. Otherwise every start fails with `module 'custom.opencode' not found` when fzf-lua's config runs.

### Step 3: Drop the fzf-lua.md gotcha
**File:** `.claude/skills/verify-nvim-config/features/fzf-lua.md:29`
**Change:** Delete the last line:
```markdown
- `fzf-lua.lua` requires `custom.opencode`, but no action calls it at this commit (see SKILL.md).
```
The Gotchas section then ends at line 28 (`- Inside the fzf terminal, typed keys go to fzf's prompt. ...`). The journey and the end state (lines 15-23) are unchanged, because the picker behaves the same.

**Commit 1:** `git commit -m "refactor(opencode): remove the opencode tmux helper" -m "<body>" -m "<trailer>" -- lua/config/fzf-lua.lua lua/custom/opencode.lua .claude/skills/verify-nvim-config/features/fzf-lua.md` (pathspec commit; `git rm` already staged the deletion), with the body `Nothing called custom/opencode.lua's public functions; fzf-lua.lua required it into an unused local. R8.` and the attribution trailer. Then run the mid-check from **Verification**: `bash .workflows/plan/fix-bugs-nvim-0-12/phase-4-proof.sh base seeded` still passes. The harness is unchanged, the fake still exists, and the startup messages are clean.

### Step 4: Reword the PATH comment and drop the run's `bin/` from PATH
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:84-97`
**Change:** `$dir/bin` existed only to put the fake `opencode` ahead of everything else. With the fake gone it would be an empty dir at the front of PATH, so it goes too, and `run_path` no longer needs the run dir. The PATH property itself does not change: only nvim's dir, the named tools' dirs and the system dirs are on PATH, so `~/.opencode/bin`, `~/.cargo/bin` and `~/.local/bin` are not.
Before:
```bash
# PATH for every process the run owns. No ~/.opencode (the fake opencode comes first), no ~/.cargo,
# no ~/.local/bin, nothing the caller exported.
run_path() {
  local dir=$1 p="$dir/bin:$(dirname "$NVIM_BIN")" t d
  # The interpreters Mason's servers need, plus the external tools the config shells out to (fzf for
  # fzf-lua, rg for live_grep, jq for the JSON prettify mapping, ctags for vista), each by its own
  # directory, so nothing else from the caller's PATH (opencode, cargo, ~/.local/bin) comes along.
  for t in "$PY" "$NODE" "$GO" fzf rg jq ctags; do
    t="$(command -v "$t" 2>/dev/null || true)"; [ -n "$t" ] || continue
    d="$(dirname "$t")"
    case ":$p:/usr/local/bin:/usr/bin:/bin:" in *":$d:"*) ;; *) p="$p:$d" ;; esac
  done
  echo "$p:/usr/local/bin:/usr/bin:/bin"
}
```
After:
```bash
# PATH for every process the run owns: nvim's own directory, the tools below and the system dirs.
# No per-user tool dir (~/.cargo, ~/.local/bin, a CLI installed under ~), nothing the caller exported.
run_path() {
  local p t d
  p="$(dirname "$NVIM_BIN")"
  # The interpreters Mason's servers need, plus the external tools the config shells out to (fzf for
  # fzf-lua, rg for live_grep, jq for the JSON prettify mapping, ctags for vista), each by its own
  # directory, so nothing else from the caller's PATH (cargo, ~/.local/bin, other dirs under ~) comes along.
  for t in "$PY" "$NODE" "$GO" fzf rg jq ctags; do
    t="$(command -v "$t" 2>/dev/null || true)"; [ -n "$t" ] || continue
    d="$(dirname "$t")"
    case ":$p:/usr/local/bin:/usr/bin:/bin:" in *":$d:"*) ;; *) p="$p:$d" ;; esac
  done
  echo "$p:/usr/local/bin:/usr/bin:/bin"
}
```
**Impact:** the run's PATH loses its first entry, `<run>/bin`, which only ever held the fake. Every other entry and its order stay the same.

### Step 5: run_env, drop the run_path argument and VERIFY_SINK
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:101-111`
**Change:**
Before:
```bash
run_env() {
  local dir=$1
  echo env -i PATH="$(run_path "$dir")" HOME="$dir/home" USER="$(id -un)" SHELL=/bin/bash \
    TERM=xterm-256color LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TZ=Asia/Jakarta \
    XDG_CONFIG_HOME="$dir/xdg/config" XDG_DATA_HOME="$dir/xdg/data" XDG_STATE_HOME="$dir/xdg/state" \
    XDG_CACHE_HOME="$dir/xdg/cache" XDG_RUNTIME_DIR="$dir/xdg/runtime" TMPDIR="$dir/tmp" \
    GIT_CONFIG_GLOBAL="$dir/home/.gitconfig" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 \
    GIT_ASKPASS=/bin/false SSH_ASKPASS=/bin/false GIT_SSH_COMMAND=/bin/false \
    GOPATH="$dir/tmp/go" GOMODCACHE="$dir/tmp/go/mod" GOCACHE="$dir/tmp/go/cache" GOFLAGS=-mod=mod GOTOOLCHAIN=local \
    npm_config_cache="$dir/tmp/npm" VERIFY_SINK="$dir/sink" CONFIG="$dir/xdg/config/nvim" WORK="$dir/work"
}
```
After:
```bash
run_env() {
  local dir=$1
  echo env -i PATH="$(run_path)" HOME="$dir/home" USER="$(id -un)" SHELL=/bin/bash \
    TERM=xterm-256color LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TZ=Asia/Jakarta \
    XDG_CONFIG_HOME="$dir/xdg/config" XDG_DATA_HOME="$dir/xdg/data" XDG_STATE_HOME="$dir/xdg/state" \
    XDG_CACHE_HOME="$dir/xdg/cache" XDG_RUNTIME_DIR="$dir/xdg/runtime" TMPDIR="$dir/tmp" \
    GIT_CONFIG_GLOBAL="$dir/home/.gitconfig" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 \
    GIT_ASKPASS=/bin/false SSH_ASKPASS=/bin/false GIT_SSH_COMMAND=/bin/false \
    GOPATH="$dir/tmp/go" GOMODCACHE="$dir/tmp/go/mod" GOCACHE="$dir/tmp/go/cache" GOFLAGS=-mod=mod GOTOOLCHAIN=local \
    npm_config_cache="$dir/tmp/npm" CONFIG="$dir/xdg/config/nvim" WORK="$dir/work"
}
```
**Impact:** `VERIFY_SINK` is no longer in any run process's env. Only the fake read it.

### Step 6: Delete write_fake_opencode
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:212-225`
**Change:** Delete these 14 lines: the function and the blank line after it. The `# Each nvim start gets its own socket` comment above `nvim_sock()` then directly follows the closing `}` of `cmd_seed` and one blank line.
```bash
write_fake_opencode() {
  # The real opencode is an AI CLI logged into the owner's accounts. This stand-in records what
  # the config hands it (argv, cwd, EDITOR, and every byte later typed into its pane by send-keys).
  cat >"$1/bin/opencode" <<'EOF'
#!/bin/bash
mkdir -p "$VERIFY_SINK"
{ printf 'argv:'; printf ' [%s]' "$@"; echo; echo "cwd: $PWD"; echo "EDITOR: ${EDITOR:-}"; } >>"$VERIFY_SINK/opencode.log"
echo "fake opencode (verify sink): $*"
stty -icanon -echo 2>/dev/null || true
exec cat >>"$VERIFY_SINK/opencode.stdin"
EOF
  chmod +x "$1/bin/opencode"
}

```

### Step 7: cmd_up, no bin/ or sink/ dir and no fake
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:283` and `:330` (base numbering)
**Change:**
Line 283, before:
```bash
  mkdir -p "$dir"/{evidence,xdg/config/nvim,xdg/data/nvim,xdg/state,xdg/cache/nvim,xdg/runtime,home,tmp,bin,sink}
```
After:
```bash
  mkdir -p "$dir"/{evidence,xdg/config/nvim,xdg/data/nvim,xdg/state,xdg/cache/nvim,xdg/runtime,home,tmp}
```
Line 330: delete the line `  write_fake_opencode "$dir"`. The lines around it become:
```bash
  printf '[user]\n\tname = verify\n\temail = verify@localhost\n[init]\n\tdefaultBranch = main\n[safe]\n\tdirectory = *\n' >"$dir/home/.gitconfig"
  # WORK: the fixture project nvim edits, a git repo whose origin is a bare repo in the run (so
```
**Impact:** new runs have no `bin/` or `sink/` dir.

### Step 8: Doctor, drop the opencode check
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:434-435`
**Change:** Delete both lines:
```bash
  local oc; oc="$(lua_eval "$dir" 'vim.fn.exepath("opencode")' 2>&1)"
  if [ "$oc" = "$dir/bin/opencode" ]; then echo "opencode ok   resolves to the run's fake ($oc)"; else echo "opencode FAIL resolves to '$oc', not the run's fake"; ok=0; fi
```
The egress `if ... fi` line (`:433`) is then directly followed by `  local cb; cb="$(lua_eval "$dir" 'vim.fn["provider#clipboard#Executable"]()' 2>&1 || true)"`.
**Impact:** doctor prints one line fewer. Its exit status is otherwise computed as before.

### Step 9: stop_run, no sink copy and no bin/sink cleanup
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:672` and `:677`
**Change:** Delete line 672:
```bash
  [ -d "$dir/sink" ] && cp -r "$dir/sink" "$dir/evidence/sink" 2>/dev/null || true
```
Line 677, before:
```bash
    rm -rf "$dir/xdg" "$dir/home" "$dir/work" "$dir/tmp" "$dir/bin" "$dir/sink" "$dir/remote.git" 2>/dev/null && break
```
After:
```bash
    rm -rf "$dir/xdg" "$dir/home" "$dir/work" "$dir/tmp" "$dir/remote.git" 2>/dev/null && break
```
**Impact:** a run started by the **base** script and stopped by the new one keeps an empty `bin/` with the fake and an empty `sink/` under `$VERIFY_HOME/<run>/`. `down` every base run (Step 0 does) before switching scripts. Pre-existing stopped runs are already cleaned.

### Step 10: SKILL.md doctor list
**File:** `.claude/skills/verify-nvim-config/SKILL.md:67`
**Change:** Delete the line:
```markdown
- `opencode`: `opencode` resolves to the run's fake (see Gotchas).
```
`- egress: ...` (line 66) is then followed by `- clipbrd: ...`.

### Step 11: SKILL.md Evidence paragraph
**File:** `.claude/skills/verify-nvim-config/SKILL.md:112-114`
Before:
```markdown
`~/.local/state/nvim-config-verify/<run>/evidence/`: outside the repo, kept after `down`,
numbered by drive order. `down` adds `messages-at-down.txt`, nvim's logs (`logs/lsp.log`,
`mason.log`, `log`) and the opencode sink.
```
After:
```markdown
`~/.local/state/nvim-config-verify/<run>/evidence/`: outside the repo, kept after `down`,
numbered by drive order. `down` adds `messages-at-down.txt` and nvim's logs (`logs/lsp.log`,
`mason.log`, `log`).
```

### Step 12: SKILL.md Gotchas "Never driven" bullet
**File:** `.claude/skills/verify-nvim-config/SKILL.md:139-148`
Before:
```markdown
- **Never driven, no flag turns it on.** A `git push` to any real remote (WORK's only remote is
  the run's bare repo; `GIT_SSH_COMMAND=/bin/false`, no global git config, no credentials, and no
  network anyway). Writing `~/.config/nvim` (deploying is the owner's `git -C ~/.config/nvim pull
  --ff-only`, which `live` prints and never runs). The owner's tmux server (`-L default`). The
  real `opencode` (an AI CLI logged into the owner's accounts): the run's PATH has a fake
  `opencode` that records argv, cwd, EDITOR and every byte typed into its pane to
  `evidence/sink/`. At this commit nothing calls `custom/opencode.lua`'s public functions, so no
  journey reaches it. AI or Copilot-style plugins: none in the spec; `~/.local/share/nvim/avante`
  and other leftovers are never copied. Clipboard: `+` goes to the run's tmux buffer, never the
  Windows clipboard (no `clip.exe` on the run's PATH, no DISPLAY).
```
After (lines 139-141 byte-identical; line 142 loses only its trailing ` The`; the deploy sentence is untouched for Phase 5):
```markdown
- **Never driven, no flag turns it on.** A `git push` to any real remote (WORK's only remote is
  the run's bare repo; `GIT_SSH_COMMAND=/bin/false`, no global git config, no credentials, and no
  network anyway). Writing `~/.config/nvim` (deploying is the owner's `git -C ~/.config/nvim pull
  --ff-only`, which `live` prints and never runs). The owner's tmux server (`-L default`).
  AI or Copilot-style plugins: none in the spec; `~/.local/share/nvim/avante` and other
  leftovers are never copied. Clipboard: `+` goes to the run's tmux buffer, never the Windows
  clipboard (no `clip.exe` on the run's PATH, no DISPLAY).
```

**Commit 2:** `bash -n .claude/skills/verify-nvim-config/scripts/verify.sh` must pass first. Then `git commit -m "refactor(verify): drop the fake opencode and its sink" -m "<body>" -m "<trailer>" -- .claude/skills/verify-nvim-config/scripts/verify.sh .claude/skills/verify-nvim-config/SKILL.md`, with the body `Nothing in the config calls opencode any more, so the run no longer needs a stand-in, its bin/ PATH entry, the sink dir or VERIFY_SINK. The run's PATH still excludes per-user tool dirs. R8.` and the attribution trailer. Do not push.

### Step 13: Evidence commit
After journeys 1-5 and the last `down`, write `evidence-phase-4.md` (template under **Verification**) and commit it together with the proof script:
`git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-4.md .workflows/plan/fix-bugs-nvim-0-12/phase-4-proof.sh && git commit -m "docs(evidence): phase 4 before/after evidence" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-4.md .workflows/plan/fix-bugs-nvim-0-12/phase-4-proof.sh`.
The proof script and the plan files contain the word `opencode`; that is why the exit check excludes `docs/` and `.workflows/`.

## Principles applied

- Subtract before you add: `$dir/bin` existed only to put the fake ahead on PATH, so Steps 4, 7 and 9 remove it with the fake instead of leaving an empty dir at the front of every run's PATH. `run_path` loses its now-unused argument (Steps 4 and 5).
- Laziness protocol: Step 8 only deletes the doctor check. It does not replace it with a new "opencode is unreachable" check, because nothing in the config can call opencode any more. Proof journey A3 shows unreachability once, from outside.
- Prove it works: every claim is checked on real runs (`up --live` and `up`) with the base captured first (Step 0). A mid-check after Commit 1 shows the config commit stands on its own.
- Sequence into verifiable units: the two commits are ordered so each one leaves the tree loading. The config goes first, and the harness still passes its own doctor with the fake still present. The harness change goes second.

## Verification

**Build:** `bash -n .claude/skills/verify-nvim-config/scripts/verify.sh` (exit 0). Lua has no build step. The startup check in the proof (no errors in `00-up-messages.txt`) is the load check.
**Tests:** none in the repo. `git grep -n -i opencode -- . ':!docs' ':!.workflows'` prints nothing (exit 1). `git grep -n -i -E 'VERIFY_SINK|\bsink\b|\$dir/bin' -- .claude` prints nothing (exit 1).
**Proof:**
- Harness: `.claude/skills/verify-nvim-config`, on the installed nvim 0.11.5 (default `NVIM_BIN`; do **not** set `VERIFY_NVIM`). The shared seed must already exist (`$V ls` shows `seed:`). Do not re-seed.
- Feature-map entries: `features/fzf-lua.md`
- Run everything from this phase's worktree root (`$WT`, index § Execution rules). The Bash tool's shell is zsh, so run the script with `bash`.

Save this as `.workflows/plan/fix-bugs-nvim-0-12/phase-4-proof.sh` before Step 0 (committed with the evidence in Step 13):

```bash
#!/usr/bin/env bash
# Phase 4 proof. usage: bash phase-4-proof.sh base|after live|seeded   (cwd: the worktree root)
set -uo pipefail
stage=${1:?base|after} mode=${2:?live|seeded}
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
V=.claude/skills/verify-nvim-config/scripts/verify.sh
VH=$HOME/.local/state/nvim-config-verify
fail=0
check() { local name=$1; shift; if "$@"; then echo "PASS $name"; else echo "FAIL $name"; fail=1; fi; }
has() { grep -q -- "$1" "$2"; }
hasnt() { ! grep -qi -- "$1" "$2"; }
eq() { [ "$1" = "$2" ]; }
absent() { [ ! -e "$1" ]; }

if [ "$mode" = live ]; then up_out=$($V up --live 2>&1); else up_out=$($V up 2>&1); fi
echo "$up_out"
RUN=$(sed -n 's/^RUN=//p' <<<"$up_out")
[ -n "$RUN" ] || { echo "FAIL up did not print RUN="; exit 1; }
EV=$VH/$RUN/evidence

# A1: startup is clean (no module 'custom.opencode' not found, no other error)
check "startup messages have no custom.opencode error" hasnt 'custom.opencode' "$EV/00-up-messages.txt"
if grep -qE 'E[0-9]+:|Error' "$EV/00-up-messages.txt"; then echo "FAIL startup messages contain errors"; fail=1; else echo "PASS startup messages contain no errors"; fi

# A2: doctor
$V doctor "$RUN" >"$EV/doctor-phase4.txt" 2>&1; drc=$?
cat "$EV/doctor-phase4.txt"
check "doctor exit 0" eq "$drc" 0

# A3: what `opencode` resolves to inside the run
oc=$($V cli "$RUN" sh -c 'command -v opencode || echo none' 2>/dev/null | tail -1)
echo "opencode resolves to: $oc"

if [ "$stage" = base ]; then
  check "doctor shows the fake opencode line" has "^opencode ok   resolves to the run's fake" "$EV/doctor-phase4.txt"
  check "opencode resolves to the run's fake" eq "$oc" "$VH/$RUN/bin/opencode"
else
  check "doctor has no opencode line" hasnt opencode "$EV/doctor-phase4.txt"
  check "opencode not on the run's PATH" eq "$oc" none
  check "no sink dir in the run" absent "$VH/$RUN/sink"
  check "no bin dir in the run" absent "$VH/$RUN/bin"
fi

# A4: fzf-lua journey (features/fzf-lua.md), the neighbour of the fzf-lua.lua edit
$V keys "$RUN" , f f
$V keys "$RUN" -l guide
$V keys "$RUN" Enter
check "fzf-lua opens docs/guide.txt" $V wait "$RUN" 'vim.fn.expand("%:.")' docs/guide.txt 10

# A5: the run's env still works for cli (git in WORK, the harness's own neighbour)
check "cli git status in WORK" $V cli "$RUN" git status --short

# A6: down
$V down "$RUN"
if [ "$stage" = base ]; then
  check "down copied a sink into evidence" test -d "$EV/sink"
else
  check "no sink copied into evidence" absent "$EV/sink"
  check "down left no sink dir" absent "$VH/$RUN/sink"
  check "down left no bin dir" absent "$VH/$RUN/bin"
  check "down removed xdg/work" absent "$VH/$RUN/xdg"
fi
echo "RUN=$RUN EVIDENCE=$EV stage=$stage mode=$mode result=$([ $fail = 0 ] && echo pass || echo FAIL)"
exit $fail
```

Journeys:
1. **Base, before any edit (Step 0):** `bash .workflows/plan/fix-bugs-nvim-0-12/phase-4-proof.sh base live` and `... base seeded`. Each exits 0. The doctor output contains `opencode ok   resolves to the run's fake (<VERIFY_HOME>/<RUN>/bin/opencode)`, A3 prints `<VERIFY_HOME>/<RUN>/bin/opencode`, and after `down` the dir `<EVIDENCE>/sink` exists. This is the "before" the phase removes.
2. **Mid-check after Commit 1:** `bash .workflows/plan/fix-bugs-nvim-0-12/phase-4-proof.sh base seeded` exits 0. The config without the module still starts clean, and the base harness's checks still hold.
3. **After Commit 2, live:** `bash .workflows/plan/fix-bugs-nvim-0-12/phase-4-proof.sh after live` exits 0. In `00-up-messages.txt` there is no `custom.opencode` and no `E\d+:`/`Error`. `doctor` exits 0 and its output has no line containing `opencode`. A3 prints `none`, even though the owner has a real `~/.opencode/bin/opencode`. The fzf-lua journey prints `verify: wait ok: vim.fn.expand("%:.") == docs/guide.txt`. After `down` there is no `<EVIDENCE>/sink`, `<VERIFY_HOME>/<RUN>/sink` or `<VERIFY_HOME>/<RUN>/bin`.
4. **After Commit 2, seeded:** `bash .workflows/plan/fix-bugs-nvim-0-12/phase-4-proof.sh after seeded` exits 0 with the same end state. Doctor also prints `seed     ok   shared seed unchanged since it was built`.
5. **Static:** `bash -n .claude/skills/verify-nvim-config/scripts/verify.sh; echo $?` prints `0`. `git grep -n -i opencode -- . ':!docs' ':!.workflows'; echo $?` prints only `1`.

- Neighbor check: the fzf-lua picker (A4, both modes) covers the edited `fzf-lua.lua`. `cli git status` (A5) shows that `run_env`/`run_path` still build a working env after the signature change.
- Cost: none. There are no paid drives and the runs are offline. Each live `up` copies the live plugins (about 7 s).
- Evidence: write `$WT/.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-4.md` (this phase's own file; phase 9 builds the set's `evidence.md` index from it). Do this **after** all runs are down, because the file is inside the snapshotted tree and writing it mid-run makes doctor print `code WARN`:
  ```markdown
  ## Phase 4
  - base live:      RUN=<id>  EVIDENCE=~/.local/state/nvim-config-verify/<id>/evidence  (doctor-phase4.txt: `opencode ok ... fake`; evidence/sink present)
  - base seeded:    RUN=<id>  EVIDENCE=...
  - mid (commit 1): RUN=<id>  EVIDENCE=...
  - after live:     RUN=<id>  EVIDENCE=...  (doctor-phase4.txt: no opencode line, exit 0; `command -v opencode` -> none; no sink)
  - after seeded:   RUN=<id>  EVIDENCE=...
  - static: bash -n ok; `git grep -i opencode` (outside docs/, .workflows/) empty
  ```

**Exit criteria:** journeys 1-5 pass as stated. Commits `refactor(opencode): remove the opencode tmux helper`, `refactor(verify): drop the fake opencode and its sink` and `docs(evidence): phase 4 before/after evidence` are on `feature/fix-bugs-nvim-0-12` and not pushed. `git grep -i opencode` prints nothing outside `docs/` and `.workflows/`.

## Handoffs

- **Phase 5:** edits the "Never driven" bullet starting from the final text quoted in the Interface Contract above. Line 142 now ends at `(`-L default`).` and no longer at ` The`. Phase 5's `old_string` must not include the removed trailing ` The` or the old opencode lines.
- **Phase 8 (verify.sh `cmd_up`):** the `cmd_up` mkdir line (`:283`) no longer lists `bin,sink`, and the `write_fake_opencode "$dir"` line after the `.gitconfig` printf is gone. Line numbers after `:212` shift up by 14 (Step 6), with further shifts below `:330`, `:434` and `:672`. Anchor edits on text, not numbers.
- **Any phase that wants a per-run tool shim (e.g. Phase 6 fault injection):** `$dir/bin` is no longer on PATH. Re-add it in that phase if needed. Phase 4 does not keep it speculatively.
- **Old base-script runs:** runs started with the base script and stopped after this phase keep `bin/` and `sink/` under their run dir. This is harmless, and the Step 0 runs are stopped with the base script anyway.

## Rollback

`git revert <commit 2> <commit 1>` (newest first) on `feature/fix-bugs-nvim-0-12`. Nothing outside the worktree is written apart from throwaway run dirs under `~/.local/state/nvim-config-verify/`, which `verify.sh down` and `rm -rf` clean up.
