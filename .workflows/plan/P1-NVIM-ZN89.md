> Adopted from `.workflows/orchestration/nvim-0-12-clean/PLAN.md` phase 1. Source: `.workflows/plan/nvim-0-12-clean/phase-1.md`.
> Written and reconciled by /analyze — edit the source, not this copy.

# Phase 1: verify.sh: sync keeps run_path, doctor checks PATH, Go tools on run PATH

**Plan set:** `NVIM_0_12_CLEAN_PLAN.md`
**Analysis:** `.workflows/analyze/20261104-121422-N12C_code_analyzer.md`
**Satisfies:** R1 (`verify.sh sync` respawns nvim with `run_path`), R6 (Go tools on the run PATH so `:checkhealth go` is judged on the owner's tool set)
**Depends on:** none
**Difficulty:** NORMAL
**Package:** `.claude/skills/verify-nvim-config`

---

## Goal

After this phase, nvim in a verify run starts on the same PATH whether `up` or `sync` started it.
`up` writes that PATH into the run's `meta` as `run_path=`, and `start_nvim_cmd` sets it explicitly,
so it no longer depends on what tmux inherits. `doctor` gets a `path` line that FAILs when nvim's
PATH differs from the recorded one, and the run PATH now includes the directory holding go.nvim's
tools, so `:checkhealth go` in a run shows no ERROR and no `Missing tool` line.

## Cause (traced to the line)

- `verify.sh:656` `cmd_sync` runs `tmx "$dir" respawn-pane -k ... "$(start_nvim_cmd "$dir")"` from the
  caller's shell. tmux 3.4's `spawn.c` gives the new pane the issuing client's `PATH` when that client
  has no session, which is always the case for a `tmux -S ... respawn-pane` command client. The pane
  therefore gets the caller's PATH. `start_nvim_cmd` (`verify.sh:228-231`) is
  `$NVIM_BIN --listen <sock>` and sets no environment. Only PATH leaks: HOME/XDG come from the
  server's global environment, which is the run's `env -i` set.
  Measured: live run `1104-121901-2809686`, `evidence/16-lua-vim.env.PATH.txt` (before sync: the
  run's PATH) vs `evidence/17-lua-vim.env.PATH.txt` (after sync: `~/.opencode/bin`,
  `~/.gvm/pkgsets/...`, `~/.cargo/bin`, `/mnt/c/...`, all from the caller).
- Passing `respawn-pane -e PATH=...` does not work in tmux 3.4. `spawn.c` copies `-e` into the
  child environment and then overwrites PATH with the session-less client's PATH. That is why the
  fix sets PATH with an `env PATH=...` prefix in the command line, and `up` and `sync` both use it.
- `cmd_doctor` (`verify.sh:455-507`) has no PATH line, so the leak went unnoticed.
- `run_path` (`verify.sh:100`) adds only the directories of `$PY $NODE $GO fzf rg jq ctags`. go.nvim's
  tools live in `~/.gvm/pkgsets/go1.25.7/global/bin` (the caller's `go env GOPATH`/bin), which the
  owner's nvim sees and a run does not. go.nvim `health.lua:58` calls
  `vim.system({'golangci-lint','--version'})` without first checking that the tool exists, so it
  throws ENOENT and `:checkhealth go` reports an ERROR plus 19 `Missing tool` warnings.
- Also measured, and it matters for the doctor check: inside nvim, Mason prepends
  `<stdpath data>/mason/bin` (`mason-core/installer/InstallLocation.lua:91`), and go.nvim
  (`go/env.lua:90`, no `GOBIN`/`GOHOME` set) appends `$HOME/go/bin` once it loads. It loads on
  `ft=go` **and on `CmdlineEnter`**, so it loads after any `:` typed. Evidence 16 ends in
  `:<run>/home/go/bin`. The doctor check strips exactly these two entries and nothing else.

## Interface Contract

**Deletes:** none
**Renames:** none
**Creates:**
- `run_path_of DIR` (`verify.sh`, a shell function placed after `run_path`): returns the run's
  recorded `run_path=` from `DIR/meta`, or `run_path` when the run has none (runs started before
  this phase)
- meta key `run_path=` (written by `cmd_up`)
- doctor output line `path     ok|FAIL ...`
- `features/startup.md` section "The run's PATH (`up`, `sync`, `doctor`)"
- `.workflows/plan/nvim-0-12-clean/evidence-phase-1.md`
**Signature changes:** `start_nvim_cmd DIR` now prints `env PATH=<run_path_of DIR> <NVIM_BIN> --listen <sock>`, where it used to print `<NVIM_BIN> --listen <sock>`. Callers are unchanged (`cmd_up:408`, `cmd_sync:656`).
**Behaviour changes:** `run_path` gains the directory of `golangci-lint` when the caller has one
(on this machine `~/.gvm/pkgsets/go1.25.7/global/bin`, appended after the existing entries and before
`/usr/local/bin:/usr/bin:/bin`). Every process the run starts sees it: nvim, LSP servers, `cli`,
`headless`.
**Requires (from earlier phases):** none
**Provides to later phases:** `run_path_of`, meta `run_path=`, doctor `path` line, `start_nvim_cmd`'s `env PATH=` form
(phase 2's stash/`sync` recipe, phase 4's lever and Deploy D5 rely on doctor exit 0 with `path ok`).
**Leaves alone (owned by others):** `lua/**`, `lua/plugin_specs.lua`, the seed and `verify.sh seed`,
`PLUGIN_EXTRA_DATA`, `seed_commit_unknown_to_live` and the comment + caller in `cmd_up`'s live block,
`seed.lua`, the SKILL.md Launch **live** bullet and Gotchas nvim-treesitter bullet (phase 3), `features/lsp.md`, `features/git.md` (phases 2/3),
`features/README.md`, `features/live-environment.md`, `features/health.md`,
`features/tmux-bindings.md`, `.tmux.conf.local` (phase 4); `features/editing-mappings.md` (no phase edits it). In
`features/startup.md` this phase adds one new `###` subsection after the `9cea538` "Deleted working directory" subsection (kept intact), before `## Gotchas`. Phase 2 adds its
`v:errmsg` end state after this phase and must not rewrite the new section.

## Files

| File | Action | What changes |
|---|---|---|
| `.claude/skills/verify-nvim-config/scripts/verify.sh` | modify | `run_path` adds `golangci-lint`'s dir (`:92-106`); new `run_path_of` (after `:106`); `start_nvim_cmd` sets PATH (`:228-231`); `cmd_up` records `run_path=` in meta (`:399`); `cmd_doctor` gains a `path` line (after `:472`); `cmd_sync` comment (`:654`) |
| `.claude/skills/verify-nvim-config/SKILL.md` | modify | Launch: a run-PATH paragraph (after `:39`); sync paragraph (`:62-64`); doctor list gains `path` (after `:73`) |
| `.claude/skills/verify-nvim-config/features/startup.md` | modify | new `###` subsection after "Deleted working directory" (after `:108`), before `## Gotchas` (`:110`): PATH survives `sync`, doctor `path` ok/FAIL, `:checkhealth go`, gofumpt from Mason |
| `.workflows/plan/nvim-0-12-clean/evidence-phase-1.md` | create | before/after run ids and evidence paths for every journey below |

## Implementation Steps

Run the two **before** journeys (Proof J1, J2) first, while the base behaviour is still easy to
show. They use the base script extracted from `9cea538` (the rebased base; verify.sh is unchanged from `8bcb55c`), so they still work after the edits below.
Recording them first keeps the failure-first order of the evidence.

### Step 1: `run_path` adds go.nvim's tool directory
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:92-106`
**Change:** add `golangci-lint` to the tool list and update both comments. Lookup is by the
tool's own directory, the same rule `fzf`, `rg`, `jq` and `ctags` already follow. On this machine the
directory holds only Go tools (callgraph, dlv, errcheck, fillswitch, ginkgo, gitleaks, goconst,
gocritic, gocyclo, go-enum, gofumpt, goimports, gojsonstruct, golangci-lint, golines, gomodifytags,
gomvp, gonew, gopls, gosec, gotests, gotestsum, govulncheck, iferr, impl, json-to-struct, mockgen,
revive, richgo, staticcheck), so it shadows no system tool. It comes after `go`'s own dir. Inside
nvim, Mason's prepended `mason/bin` still wins for `gofumpt` and `gopls`.
**Old:**
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
```
**New:**
```bash
# PATH for every process the run owns: nvim's own directory, the tools below and the system dirs.
# No per-user tool dir as such (~/.cargo, ~/.local/bin, ~/.opencode/bin), nothing else the caller exported.
run_path() {
  local p t d
  p="$(dirname "$NVIM_BIN")"
  # The interpreters Mason's servers need, plus the external tools the config shells out to (fzf for
  # fzf-lua, rg for live_grep, jq for the JSON prettify mapping, ctags for vista, golangci-lint for
  # go.nvim: its directory is the caller's Go bin, which holds every tool go.nvim runs and lists in
  # :checkhealth go), each by its own directory, so nothing else from the caller's PATH (cargo,
  # ~/.local/bin, other dirs under ~) comes along. Inside nvim, Mason prepends its own bin, so
  # Mason's gofumpt and gopls still win over the Go bin's copies.
  for t in "$PY" "$NODE" "$GO" fzf rg jq ctags golangci-lint; do
```
The loop body and the `echo` after it (`:101-105`) are unchanged.
**Impact:** every run started after this phase has the Go bin dir on PATH. A caller with no
`golangci-lint` behaves as before: the `continue` on an empty `command -v` skips it.

### Step 2: `run_path_of`: the run's recorded PATH
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh`, insert directly after `run_path`'s
closing `}` (`:106`), before the `# env -i plus the run's own values only.` comment (`:108`).
**Code:**
```bash

# The PATH a run started with, as `up` recorded it (meta run_path=). `sync` and `doctor` use it, so
# a call from a shell with another PATH (another agent, a cron, a login without gvm) still means the
# run's PATH. A run started before run_path was recorded falls back to this caller's run_path.
run_path_of() {
  local p=""
  [ -f "$1/meta" ] && p="$(meta "$1" run_path)"
  if [ -n "$p" ]; then echo "$p"; else run_path; fi
}
```
**Impact:** new function. Its callers are `start_nvim_cmd` (Step 3) and `cmd_doctor` (Step 5).
`run_env` keeps calling `run_path` directly. Inside `cmd_up` both values are computed in the same
shell at the same moment, so they are equal. The `[ -f ] &&` guard keeps `set -euo pipefail` from
aborting on a missing meta: `meta`'s `sed` would fail and `pipefail` would fail the assignment.

### Step 3: `start_nvim_cmd` sets PATH itself
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:228-231`
**Old:**
```bash
start_nvim_cmd() {
  # The pane runs the user's real entry point: `nvim`, from WORK, with a socket the driver reads.
  echo "$NVIM_BIN --listen $(nvim_sock "$1")"
}
```
**New:**
```bash
start_nvim_cmd() {
  # The pane runs the user's real entry point: `nvim`, from WORK, with a socket the driver reads.
  # PATH is set here, never inherited: tmux gives a pane spawned by a command client that has no
  # session (`sync`'s respawn-pane, run from the caller's shell) that CLIENT's PATH, and it applies
  # that after `respawn-pane -e`, so -e PATH=... cannot win. `up` and `sync` run this same command,
  # so nvim always starts on the run's recorded PATH.
  printf 'env PATH=%q %q --listen %q\n' "$(run_path_of "$1")" "$NVIM_BIN" "$(nvim_sock "$1")"
}
```
**Impact:** `up`'s first pane and `sync`'s respawned pane both run
`env PATH=<run_path> /opt/nvim-linux-x86_64/bin/nvim --listen <run>/nvim-N.sock`. In `up` the PATH
is unchanged, because the server already had `run_path`. In `sync` the leak is gone. `env` execs
nvim, so `#{pane_current_command}` is still `nvim`, and doctor's `pane info` line reads the same.
`%q` leaves `/`, `:`, `.`, `-` and `_` unquoted, so the command is byte-identical to a hand-written
one for the paths on this machine. `cmd_up` writes meta before it calls `start_nvim_cmd` (`:385-401` before
`:406`), so `run_path_of` finds `run_path=` there (Step 4).

### Step 4: `up` records `run_path=` in meta
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:399` (inside `cmd_up`'s `{ ... } >"$dir/meta"` block)
**Old:**
```bash
    echo "size=$size"
    echo "nvim_gen=1"
  } >"$dir/meta"
```
**New:**
```bash
    echo "size=$size"
    echo "run_path=$(run_path)"
    echo "nvim_gen=1"
  } >"$dir/meta"
```
**Impact:** `doctor`'s `meta` dump (`:473`) now also prints `meta     run_path=...`. `sync` appends
only `head/dirty/tree/nvim_gen`, so `run_path=` keeps its `up` value for the run's whole life.

### Step 5: `doctor` checks nvim's PATH
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh`, insert after the `stdpath` `case`
line (`:472`), before `sed 's/^/meta     /' "$dir/meta"` (`:473`).
**Code:**
```bash
  # nvim's PATH must be the one the run started with. Two entries are nvim's own doing and are
  # dropped before comparing: Mason prepends <data>/mason/bin, and go.nvim (no GOBIN set) appends
  # $HOME/go/bin once it loads (ft=go or any `:`). Anything else came from a caller's PATH.
  local np want; want="$(run_path_of "$dir")"
  np="$(lua_eval "$dir" 'vim.env.PATH' 2>&1 || true)"
  np="${np#"$dir/xdg/data/nvim/mason/bin:"}"
  np="${np%":$dir/home/go/bin"}"
  if [ "$np" = "$want" ]; then echo "path     ok   nvim's PATH is the run's run_path (plus Mason's bin, go.nvim's \$HOME/go/bin)"
  else echo "path     FAIL nvim's PATH is not the run's: $np (run_path: $want)"; ok=0; fi
```
**Impact:** doctor exits 1 when nvim runs on any PATH other than the run's. On a `--bare` run there is
no Mason and no go.nvim, so neither strip matches and the PATH compares as is (`ok`). If nvim does not
answer, `np` holds the RPC error and the line FAILs next to the existing `nvim FAIL`.

### Step 6: `cmd_sync` comment says why PATH survives
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:654`
**Old:**
```bash
  # A config change takes effect on the next nvim start, as for the owner: restart nvim in its pane.
```
**New:**
```bash
  # A config change takes effect on the next nvim start, as for the owner: restart nvim in its pane,
  # on the run's recorded PATH (start_nvim_cmd sets it; this respawn-pane would otherwise pass on ours).
```
The `respawn-pane` line (`:656`) itself is unchanged. The fix is in `start_nvim_cmd` (Step 3), so
`up` and `sync` share one command.
**Impact:** comment only.

### Step 7: SKILL.md: run PATH, sync, doctor
**File:** `.claude/skills/verify-nvim-config/SKILL.md`

7a. Launch: the run-PATH paragraph. Insert after `:39` (the paragraph ending
`The start screen is \`00-up-screen.txt\`.`), as a new paragraph before the `- **seed**` bullet (`:41`):
```markdown

Every process a run starts gets the run's PATH, recorded as `run_path=` in the run's `meta`:
nvim's own directory, the directories of `python3`, `node`, `go`, `fzf`, `rg`, `jq`, `ctags` and
`golangci-lint` (the caller's Go bin, which holds every tool go.nvim runs: `~/.gvm/pkgsets/go1.25.7/global/bin`
here), then `/usr/local/bin:/usr/bin:/bin`. No other per-user directory, nothing else from the
caller's PATH. Inside nvim, Mason prepends its `mason/bin` (so Mason's `gofumpt` and `gopls` win)
and go.nvim appends `$HOME/go/bin` once it loads.
```

7b. Sync paragraph, `:62-64`.
**Old:**
```markdown
**Edited the config after `up`?** `$V sync RUN` re-snapshots and restarts nvim in the pane (as
the owner would, by restarting nvim). tmux config changes need `down` + `up`: the running server
keeps the config it started with.
```
**New:**
```markdown
**Edited the config after `up`?** `$V sync RUN` re-snapshots and restarts nvim in the pane (as
the owner would, by restarting nvim), on the PATH `up` recorded (`run_path=`), whatever the PATH
of the shell that calls `sync`. tmux config changes need `down` + `up`: the running server keeps
the config it started with.
```

7c. Doctor list: add a bullet after `:73`
(`- \`nvim\`: answers on \`nvim-N.sock\` and is ready. \`stdpath\`: config/data/state/cache are the run's.`):
```markdown
- `path`: nvim's `vim.env.PATH`, minus Mason's prepended `mason/bin` and go.nvim's appended
  `$HOME/go/bin`, equals the run's `run_path=`. A FAIL means nvim started on another PATH (a
  caller's PATH leaked in).
```
**Impact:** docs only.

### Step 8: `features/startup.md`: PATH end states
**File:** `.claude/skills/verify-nvim-config/features/startup.md`. The file is as it stands after
the rebase onto `9cea538`, which added the `### Deleted working directory` subsection (`:88-108`).
Leave that subsection untouched. Insert after its last line (`:108`,
`ends the same way. It goes to the nearest existing parent, or \`/\`.`) and before `## Gotchas`
(`:110`), so the new subsection follows "Deleted working directory" with one blank line on each
side.
**Code:** in the text below, replace each `<...>` with the run id measured in Proof J3/J4/J5.
They are measured values, not code.
````markdown

### The run's PATH (`up`, `sync`, `doctor`)

nvim starts on the PATH `up` recorded, and keeps it across `sync`:

```sh
$V up --live                                   # or $V up; note RUN, EVIDENCE
D=$(dirname "$EVIDENCE")
grep '^run_path=' "$D/meta"
$V lua RUN 'vim.env.PATH'
$V sync RUN
$V lua RUN 'vim.env.PATH'
$V doctor RUN | grep '^path'
```

End state seen: both `vim.env.PATH` reads are `<D>/xdg/data/nvim/mason/bin:` followed by `meta`'s
`run_path` (nvim's dir, miniconda, node, `~/.gvm/gos/go1.25.7/bin`, `~/.fzf/bin`,
`~/.gvm/pkgsets/go1.25.7/global/bin`, `/usr/local/bin:/usr/bin:/bin`), and doctor prints
`path     ok`. Before the fix (base `9cea538`), the read after `sync` was the caller's whole PATH
(`~/.opencode/bin`, `~/.cargo/bin`, `/mnt/c/...`) and doctor had no `path` line. Live
`<RUN-J3>`, seeded `<RUN-J4>`.

Fault injection (doctor catches a foreign PATH):

```sh
$V lua RUN 'vim.fn.setenv("PATH", vim.env.PATH .. ":/leak/bin")'
$V doctor RUN; echo "exit=$?"
```

End state seen: `path     FAIL nvim's PATH is not the run's: ...:/leak/bin (run_path: ...)` and
`exit=1`. Run `<RUN-J5>`.

go.nvim's tools are on the run PATH, Mason's still win:

```sh
$V keys RUN : e Space main.go Enter
$V wait RUN 'package.loaded["go"] ~= nil' true 30
$V lua RUN '{ gofumpt = vim.fn.exepath("gofumpt"), gopls = vim.fn.exepath("gopls"), lint = vim.fn.exepath("golangci-lint") }'
$V keys RUN : checkhealth Space go Enter
$V lua RUN 'table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")'
```

End state seen: `gofumpt` and `gopls` are `<D>/xdg/data/nvim/mason/bin/...`, and `lint` is
`~/.gvm/pkgsets/go1.25.7/global/bin/golangci-lint`. The report has no `ERROR` line and no
`Missing tool` line, and it shows `golangci-lint version: 2.10`. Warnings that remain belong to the
environment, not to the config: `GOBIN is not in PATH` (the run sets no GOBIN), optional treesitter
parsers, and `nvim-treesitter main module loaded, WIP`. Phase 4's `features/health.md` records them.
Before the fix: `ERROR Failed to run healthcheck for "go" plugin ... ENOENT ... 'golangci-lint'`
plus 19 `Missing tool` warnings. Live `<RUN-J3>`, seeded `<RUN-J4>`.
````
**Impact:** docs only. This is a user-facing change to the harness (`sync`/`doctor`), so the
feature map moves with it.

### Step 9: evidence file
**File:** `.workflows/plan/nvim-0-12-clean/evidence-phase-1.md` (create)
**Code:** fill every `<...>` from the Proof runs. Each run id is the `RUN=` that `up` printed. Each
path is a file under `~/.local/state/nvim-config-verify/<RUN>/evidence/` that the run's `lua`,
`keys` or `doctor` output named, or `LOG.md`.
```markdown
# Phase 1 evidence: verify.sh sync keeps run_path, doctor checks PATH, Go tools on run PATH

Base for "before": `9cea538`'s verify skill, extracted with `git archive` to
`~/.local/state/nvim-config-verify/phase1-base-9cea538/` and run from the worktree root.
Evidence root: `~/.local/state/nvim-config-verify/<RUN>/evidence/`.

| Journey | Mode | Script | Run | Result | Evidence |
|---|---|---|---|---|---|
| J1 before: PATH after sync, doctor, checkhealth go | live | base | `<RUN-J1>` | PATH differs after sync; doctor exit 0, no `path` line; go health ERROR + Missing tool | `<NN-lua-vim.env.PATH.txt>` x2, `<doctor output saved by J1>`, `<NN-lua-table.concat...txt>` |
| J2 before: same | seeded | base | `<RUN-J2>` | same as J1 | same files |
| J3 after: PATH kept, doctor path ok, checkhealth go, gofumpt/gopls from Mason, Go format on save | live | new | `<RUN-J3>` | identical PATH; `path ok`; 0 ERROR, 0 Missing tool; `x := a + b` | ... |
| J4 after: same | seeded | new | `<RUN-J4>` | same as J3 | ... |
| J5 fault injection: doctor path FAIL | seeded | new | `<RUN-J5>` | `path     FAIL`, exit 1 | ... |

Analysis repro (live, base, earlier): `1104-121901-2809686` `evidence/16-lua-vim.env.PATH.txt` vs
`evidence/17-lua-vim.env.PATH.txt`; original `1104-112534-2226714`.
```
**Impact:** evidence index. Phase 4's set-wide `evidence.md` links to it.

## Principles applied

- Fix root causes: the cause is traced to tmux's PATH rule for session-less command clients
  (`verify.sh:656`). The fix sets PATH in the spawned command, where it cannot be overridden. It
  does not use `respawn-pane -e`, because tmux applies the client's PATH after `-e`, so that
  option would not fix the bug. J1/J2 reproduce the bug on the base before any change.
- Make illegal states unrepresentable: `up` and `sync` used to build nvim's environment two
  different ways, from the server env and from the client env. Now one command (`start_nvim_cmd`)
  and one recorded value (`meta run_path=`, read through `run_path_of`) feed both, and `doctor`
  compares against that same value. A `sync` or `doctor` called from a shell with a different PATH
  can no longer change or misjudge the run's PATH.
- Encode lessons in structure: the leak went unnoticed after the earlier set removed the opencode
  doctor line that used to expose it. The new `path` doctor line is a check that FAILs (exit 1),
  where the old guard was only a doc sentence.
- Laziness protocol: one word (`golangci-lint`) in the existing "each tool by its own directory"
  loop covers all 19+ go.nvim tools. It adds no new mechanism and no go.nvim-specific list.
  `run_env` is left on `run_path` (equal in practice, and changing it is not needed for R1).

## Verification

**Build:** `bash -n /home/miftah/.worktrees/nvim/nvim-0-12-clean/.claude/skills/verify-nvim-config/scripts/verify.sh && echo syntax-ok`
(and `shellcheck` on it, if installed: no new warnings compared with `git show 9cea538:.claude/skills/verify-nvim-config/scripts/verify.sh`)
**Tests:** none in this repo for verify.sh. The Proof journeys are the tests.
**Proof:**
- Harness: `.claude/skills/verify-nvim-config` (`scripts/verify.sh`). The skill's rules apply: never
  launch nvim or tmux by hand, drive only through `verify.sh`. The Bash tool's shell is zsh, so every
  journey below is a `bash -s <<'EOF'` heredoc (quoted, so zsh expands nothing in it).
- Feature-map entries: `features/startup.md` (Step 8).
- Journeys (run in this order: J1 and J2 are the failure, recorded first):

**J1: before, live (base script): PATH leaks on sync, doctor is silent, go health errors.** Must show the bug.
```sh
bash -s <<'EOF'
cd /home/miftah/.worktrees/nvim/nvim-0-12-clean || exit 1
BASE=$HOME/.local/state/nvim-config-verify/phase1-base-9cea538
rm -rf "$BASE"; mkdir -p "$BASE"
git archive 9cea538 .claude/skills/verify-nvim-config | tar -x -C "$BASE"
B=$BASE/.claude/skills/verify-nvim-config/scripts/verify.sh
out=$($B up --live); echo "$out"; RUN=$(sed -n 's/^RUN=//p' <<<"$out")
P1=$($B lua "$RUN" 'vim.env.PATH' | tail -1)
$B sync "$RUN"
P2=$($B lua "$RUN" 'vim.env.PATH' | tail -1)
echo "P1=$P1"; echo "P2=$P2"
[ "$P1" = "$P2" ] && echo "PATH-AFTER-SYNC: SAME" || echo "PATH-AFTER-SYNC: DIFF"
$B doctor "$RUN" > "$HOME/.local/state/nvim-config-verify/$RUN/evidence/doctor-after-sync.txt"; echo "doctor-exit=$?"
echo "doctor-path-lines=$(grep -c '^path' "$HOME/.local/state/nvim-config-verify/$RUN/evidence/doctor-after-sync.txt")"
$B keys "$RUN" : e Space main.go Enter >/dev/null
$B wait "$RUN" 'package.loaded["go"] ~= nil' true 30
$B keys "$RUN" : checkhealth Space go Enter >/dev/null
H=$($B lua "$RUN" 'table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")')
echo "health-ERROR=$(grep -c 'ERROR' <<<"$H") health-missing=$(grep -c 'Missing tool' <<<"$H")"
$B down "$RUN"
EOF
```
Passes (as a "before") when it prints `PATH-AFTER-SYNC: DIFF`, `P2` contains the caller's dirs
(`/.cargo/bin` or `/.local/bin` or `/mnt/c/`), `doctor-exit=0`, `doctor-path-lines=0`,
`health-ERROR=` ≥ 1 and `health-missing=` ≥ 1. The before snapshot uses the worktree's lua (the
same as the base's: `snapshot` excludes `.claude`, so after this phase the config under test is identical).

**J2: before, seeded (base script).** Same script as J1 with `$B up` in place of `$B up --live`
(and without the `rm -rf`/`git archive` lines if J1 already extracted the base). Same pass condition.

**J3: after, live (new script): PATH kept across sync, doctor `path ok`, go health clean, Mason's binaries win, Go format on save.**
```sh
bash -s <<'EOF'
cd /home/miftah/.worktrees/nvim/nvim-0-12-clean || exit 1
V=.claude/skills/verify-nvim-config/scripts/verify.sh
out=$($V up --live); echo "$out"; RUN=$(sed -n 's/^RUN=//p' <<<"$out")
D=$HOME/.local/state/nvim-config-verify/$RUN
RP=$(sed -n 's/^run_path=//p' "$D/meta" | tail -1); echo "meta run_path=$RP"
case ":$RP:" in *":$(dirname "$(command -v golangci-lint)"):"*) echo "GOBIN-DIR-ON-RUN-PATH: yes" ;; *) echo "GOBIN-DIR-ON-RUN-PATH: no" ;; esac
P1=$($V lua "$RUN" 'vim.env.PATH' | tail -1)
$V sync "$RUN"
P2=$($V lua "$RUN" 'vim.env.PATH' | tail -1)
echo "P1=$P1"; echo "P2=$P2"
[ "$P1" = "$P2" ] && echo "PATH-AFTER-SYNC: SAME" || echo "PATH-AFTER-SYNC: DIFF"
[ "$P2" = "$D/xdg/data/nvim/mason/bin:$RP" ] && echo "PATH-IS-RUN-PATH: yes" || echo "PATH-IS-RUN-PATH: no"
$V doctor "$RUN" > "$D/evidence/doctor-after-sync.txt"; echo "doctor-exit=$?"; grep '^path' "$D/evidence/doctor-after-sync.txt"
$V keys "$RUN" : e Space main.go Enter >/dev/null
$V wait "$RUN" 'package.loaded["go"] ~= nil' true 30
$V lua "$RUN" '{ gofumpt = vim.fn.exepath("gofumpt"), gopls = vim.fn.exepath("gopls"), lint = vim.fn.exepath("golangci-lint") }'
$V keys "$RUN" 6 G A Space Escape >/dev/null; $V keys "$RUN" : w Enter >/dev/null
$V cli "$RUN" git diff main.go
$V keys "$RUN" : checkhealth Space go Enter >/dev/null
H=$($V lua "$RUN" 'table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")')
echo "health-ERROR=$(grep -c 'ERROR' <<<"$H") health-missing=$(grep -c 'Missing tool' <<<"$H")"
grep -o 'golangci-lint version: [0-9.]*' <<<"$H"
$V keys "$RUN" : tabclose Enter >/dev/null
$V doctor "$RUN" > "$D/evidence/doctor-end.txt"; echo "doctor-end-exit=$?"; grep -E '^(path|messages)' "$D/evidence/doctor-end.txt"
$V down "$RUN"
EOF
```
Passes when: `GOBIN-DIR-ON-RUN-PATH: yes`, `PATH-AFTER-SYNC: SAME`, `PATH-IS-RUN-PATH: yes`,
`doctor-exit=0` with `path     ok`, the exepath table has `gofumpt` and `gopls` under
`$D/xdg/data/nvim/mason/bin/` and `lint` under `~/.gvm/pkgsets/go1.25.7/global/bin/`, `git diff main.go`
shows `-	var x = a+b` / `+	x := a + b` (neighbor: Go format-on-save with gofumpt), `health-ERROR=0
health-missing=0`, `golangci-lint version: 2.10` printed, and `doctor-end-exit=0` with
`path     ok` (go.nvim is now loaded and appended `$HOME/go/bin`, which the check strips) and
`messages ok`.

**J4: after, seeded (new script).** Same as J3 with `$V up` in place of `$V up --live`. Same pass
condition.

**J5: fault injection: doctor FAILs on a foreign PATH.**
```sh
bash -s <<'EOF'
cd /home/miftah/.worktrees/nvim/nvim-0-12-clean || exit 1
V=.claude/skills/verify-nvim-config/scripts/verify.sh
out=$($V up); echo "$out"; RUN=$(sed -n 's/^RUN=//p' <<<"$out")
$V doctor "$RUN" | grep '^path'
$V lua "$RUN" 'vim.fn.setenv("PATH", vim.env.PATH .. ":/leak/bin")'
$V doctor "$RUN" > "$HOME/.local/state/nvim-config-verify/$RUN/evidence/doctor-leak.txt"; echo "doctor-exit=$?"
grep '^path' "$HOME/.local/state/nvim-config-verify/$RUN/evidence/doctor-leak.txt"
$V down "$RUN"
EOF
```
Passes when the first `path` line is `path     ok`, then `doctor-exit=1` and
`path     FAIL nvim's PATH is not the run's: ...:/leak/bin (run_path: ...)`. (`lua` is used only to
break the state on purpose. The thing being proven is doctor's verdict.)

- Neighbor check: Go format-on-save (`features/format-on-save.md` "Go") runs inside J3/J4. A wrong
  `gofumpt` (the Go bin's instead of Mason's) or a broken PATH would change or fail its diff. Also
  `doctor`'s other lines (`tmux`, `netns`, `nvim`, `stdpath`, `egress`, `git`, `seed`/`live`,
  `messages`) are still `ok` in J3/J4 (`doctor-exit=0`). The `--bare` startup journey in
  `features/startup.md` (`$V up --bare; $V doctor RUN`) must still end with `doctor` exit 0 and a
  `path     ok` line: run it once.
- Cost: none. No paid drives. About 7 s per `up --live`, 1 s per `up`, five runs in total.

**Exit criteria:** J1 and J2 show the failure on the base (PATH differs after `sync`, doctor exits 0
with no `path` line, go health has an ERROR and `Missing tool` lines). J3 and J4 show the fix in
both modes (the same PATH before and after `sync`, equal to Mason's bin + `meta`'s `run_path`;
doctor `path     ok`; `:checkhealth go` with 0 ERROR and 0 `Missing tool`; `gofumpt`/`gopls` from
Mason; Go format-on-save diff unchanged). J5 shows doctor `path     FAIL` with exit 1. `--bare`
doctor is still exit 0. `evidence-phase-1.md` has a run id and evidence path in every cell.

## Handoffs

- Phase 4 (R6 allow-list, `features/health.md`): after this phase, the `go` section in runs still
  has WARNINGs that come from the environment: `GOBIN is not in PATH` (go.nvim `health.lua:236`; the
  run sets no GOBIN, and the owner has none either: `go env GOBIN` is empty), `treesitter parser
  <gowork|gomod|gosum|sql|gotmpl|json|comment> is optional but it is not found` (only if the seed
  or live site lacks it), `nvim-treesitter main module loaded, WIP`, and the summary `Some
  binaries are not installed ...` that any of those triggers. There is also the upstream go.nvim crash
  (`health.lua:58`, `vim.system` with no executable check), which is now unreachable in runs but still
  upstream. Record all of these in the allow-list.
- Phase 4 (`features/README.md`, owns it): the startup row's "Driven by" may add `sync` and the
  "Findings" cell may add "fixed: `sync` leaked the caller's PATH".
- `features/editing-mappings.md:67` ("the run's PATH includes jq's directory (and fzf, rg, ctags)") stays
  as is (reconciled: still true; SKILL.md's new run-PATH paragraph is the canonical list). No phase edits it.
- Phase 2 (`features/startup.md`): this phase inserts a section before `## Gotchas`. Phase 2 inserts
  its `v:errmsg` subsection after this one (also directly before `## Gotchas`) and must not rewrite it.
- Phase 3 (reconciled): phase 3 edits `verify.sh` (`seed_commit_unknown_to_live` -> `live_lacks_seed_commit`,
  `cmd_up`'s live-block comment and its caller) and two `SKILL.md` sentences (the Launch **live** bullet, the
  Gotchas nvim-treesitter bullet) after this phase. None of those lines is in this phase's hunks; leave them.
- Phase 3 (`seed`): `cmd_seed` builds its own PATH (`verify.sh:185-186`), not `run_path`, so this
  phase does not change what the seed sees. Seeded runs started after this phase use the new
  `run_path` whether or not the seed is rebuilt.
- Not done (scope): `run_env` still calls `run_path` rather than `run_path_of`. `cli`/`headless`
  from a shell with a different PATH would use that shell's tool dirs. That is harmless for R1, so
  it is left as is.

## Rollback

`git revert` this phase's commit(s) on `feature/nvim-0-12-clean`. That restores `verify.sh`,
`SKILL.md` and `features/startup.md` and removes `evidence-phase-1.md`. Runs started with the new
script keep a `run_path=` line in their `meta`, which the old script ignores. Delete the extracted
base with `rm -rf ~/.local/state/nvim-config-verify/phase1-base-9cea538`. Nothing outside the worktree
and `~/.local/state/nvim-config-verify/` was written, and the seed was not touched.
