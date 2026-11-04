# Phase 5: Deploy hint: fetch + merge --ff-only

**Plan set:** `docs/plans/FIX_BUGS_NVIM_0_12_PLAN.md`
**Analysis:** `docs/analyzer/20261104-102452-MRDD_code_analyzer.md`
**Satisfies:** R10 (the verify skill's deploy hint uses `fetch` + `merge --ff-only origin/main`)
**Depends on:** Phase 4
**Difficulty:** EASY
**Package:** `.claude/skills/verify-nvim-config`

---

> **Set-wide execution rules** (plan index § Execution rules; they override any command below that disagrees):
> 1. `$WT` is **this phase's own worktree root** (`WT=$(git rev-parse --show-toplevel)`). Wave-1 phases run
>    concurrently in separate worktrees, so never `cd` into another phase's tree.
> 2. **No `git stash`** (the stash stack is shared by every worktree of the repo). Swap base and fix per file:
>    `SW=$(mktemp -d)`; BASE = `cp <path> "$SW/" && git show "$PHASE_BASE:<path>" ><path>`; FIX = `cp "$SW/<file>" <path>`,
>    where `PHASE_BASE=$(git rev-parse HEAD)` is recorded before this phase's first edit. A new file's BASE is `mv <path> "$SW/"`.
> 3. Commit with an explicit pathspec: `git add -- <new files>` then `git commit -m "..." -- <every path>`.
> 4. Evidence goes to `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-5.md`, this phase's own file (never a shared one),
>    written only **after every run of the phase is down** (the file is inside the snapshotted tree; a mid-run write makes
>    `doctor` print `code WARN`). It is committed as the phase's last commit:
>    `git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-5.md && git commit -m "docs(evidence): phase 5 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-5.md`.
>    `.workflows/` is tracked (the orchestrator commits the plan set); commit nothing else under it unless this plan says so.
> 5. Never `git push`. Never write `~/.config/nvim`, `~/.local/share/nvim` or `/opt/nvim-linux-x86_64`.

## Goal

`verify.sh live` currently tells the owner to deploy with `git -C ~/.config/nvim pull --ff-only`,
which fails in the live checkout with "Cannot fast-forward to multiple branches". After this
phase `live` prints `git -C <live> fetch origin && git -C <live> merge --ff-only origin/main`
(with `$LIVE_CONFIG` expanded), and the two docs that quote the deploy command say the same,
with a short note on why plain `git pull` is not used.

## Interface Contract

**Deletes:** the string `pull --ff-only` everywhere under `.claude/skills/verify-nvim-config/`
(`scripts/verify.sh` `cmd_live` deploy echo, `SKILL.md` Gotchas "Never driven" bullet,
`features/live-environment.md:13`).
**Renames:** none
**Creates:** none
**Signature changes:** none. `cmd_live`'s output changes in its last line only:
`deploy (the owner's step, never run by verify): git -C $LIVE_CONFIG pull --ff-only` ->
`deploy (the owner's step, never run by verify): git -C $LIVE_CONFIG fetch origin && git -C $LIVE_CONFIG merge --ff-only origin/main`
**Requires (from earlier phases):** Phase 4 has removed the opencode sentences ("The real
`opencode` ... so no journey reaches it.") from the SKILL.md "Never driven" bullet and the
opencode/sink code from `verify.sh` (line numbers in `verify.sh` above `cmd_live` shift; locate
the line by content, not number).
**Leaves alone (owned by others):** everything else in `features/live-environment.md`,
including its "End state seen" journey summary (lines 24-31) (Phase 9); `features/README.md`
(Phase 9); SKILL.md `--bare` gotcha and `features/startup.md` (Phase 6); the rest of the "Never
driven" bullet (Phase 4); SKILL.md:15 "it lags this checkout until the owner pulls" (prose, not
a command; deliberately untouched).

## Files

| File | Action | What changes |
|---|---|---|
| `.claude/skills/verify-nvim-config/scripts/verify.sh` | modify | `cmd_live` deploy echo (base `:639`; after phase 4, the `echo "deploy (the owner's step ...` line near the end of `cmd_live`) |
| `.claude/skills/verify-nvim-config/SKILL.md` | modify | Gotchas "Never driven" bullet, the "Writing `~/.config/nvim` (...)" sentence (base `:141-142`) |
| `.claude/skills/verify-nvim-config/features/live-environment.md` | modify | `:13-14` "The owner deploys with ..." sentence, `:43` "Deploying (pulling into ...)" gotcha |

## Implementation Steps

### Step 0: Record the base behavior (before any edit)
**File:** none (evidence only)
**Change:** From the worktree root, before Step 1, run Journey 1's "base" commands below and
save the output. It must show the `pull --ff-only` line. This is the failing reproduction.
**Impact:** none.

### Step 1: Fix the deploy line `live` prints
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:639` (base numbering; after phase 4
it is the last `echo` inside the `{ ... } >"$out"` block of `cmd_live`)
**Change:** Replace exactly this line

```bash
    echo "deploy (the owner's step, never run by verify): git -C $LIVE_CONFIG pull --ff-only"
```

with

```bash
    # Not plain `git pull`: in the live checkout it fails with "Cannot fast-forward to multiple branches".
    echo "deploy (the owner's step, never run by verify): git -C $LIVE_CONFIG fetch origin && git -C $LIVE_CONFIG merge --ff-only origin/main"
```

The full `cmd_live` after this step (and after phase 4, which does not touch this function):

```bash
cmd_live() {
  local root out lh rh; root="$(repo_root)"
  [ -d "$LIVE_CONFIG/.git" ] || die "no live checkout at $LIVE_CONFIG"
  if [ -n "${1:-}" ]; then out="$(next_evidence "$(run_dir "$1")" live drift)"; else mkdir -p "$VERIFY_HOME"; out="$VERIFY_HOME/live-$(date +%m%d-%H%M%S).txt"; fi
  # Read-only throughout: --no-optional-locks keeps `git status` from refreshing the live index.
  lh="$(git -C "$LIVE_CONFIG" --no-optional-locks rev-parse HEAD)"; rh="$(git -C "$root" rev-parse HEAD)"
  {
    echo "live:     $LIVE_CONFIG @ $(git -C "$LIVE_CONFIG" --no-optional-locks log --oneline -1)"
    echo "checkout: $root @ $(git -C "$root" log --oneline -1)  (working tree dirty: $(git -C "$root" status --porcelain | wc -l))"
    echo "live uncommitted:"; git -C "$LIVE_CONFIG" --no-optional-locks status --porcelain | sed 's/^/  /'
    if git -C "$root" cat-file -e "$lh^{commit}" 2>/dev/null; then
      echo "commits in the checkout that live lacks ($(git -C "$root" rev-list --count "$lh..$rh")):"; git -C "$root" log --oneline "$lh..$rh" | sed 's/^/  /'
      echo "commits in live that the checkout lacks ($(git -C "$root" rev-list --count "$rh..$lh")):"; git -C "$root" log --oneline "$rh..$lh" | sed 's/^/  /'
    else
      echo "live HEAD $lh is unknown to the checkout (fetch first; never fetched by verify)"
    fi
    echo "files that differ, live tree vs checkout working tree (what deploying would change):"
    diff -rq --exclude=.git --exclude=.claude --exclude=lazy-lock.json --exclude=__pycache__ --exclude='*_code_analyzer.md' "$LIVE_CONFIG" "$root" 2>&1 | sed "s#$LIVE_CONFIG#live#g; s#$root#checkout#g; s/^/  /" || true
    echo "tmux: ~/.tmux.conf -> $LIVE_TMUX_CONF; ~/.tmux.conf.local $(cmp -s "$REAL_HOME/.tmux.conf.local" "$root/.tmux.conf.local" && echo "== checkout's" || echo "DIFFERS from checkout's")"
    echo "live lock: $(jq length "$LIVE_CONFIG/lazy-lock.json" 2>/dev/null) plugins, modified $(date -d "@$(stat -c %Y "$LIVE_CONFIG/lazy-lock.json")" -Iseconds)"
    # Not plain `git pull`: in the live checkout it fails with "Cannot fast-forward to multiple branches".
    echo "deploy (the owner's step, never run by verify): git -C $LIVE_CONFIG fetch origin && git -C $LIVE_CONFIG merge --ff-only origin/main"
  } >"$out"
  cat "$out"
  echo "[evidence: $out]" >&2
}
```

The comment says "plain `git pull`" on purpose: Journey 4 greps the skill for the old
form and must print nothing. verify never runs the
printed command; it stays an `echo` and `LIVE_CONFIG` is expanded at print time, as before.
**Impact:** last line of `live` / `live RUN` output and its evidence file changes. Nothing parses
that line (`git grep -n "deploy (the owner" .claude` shows only this echo).

### Step 2: SKILL.md "Never driven" bullet
**File:** `.claude/skills/verify-nvim-config/SKILL.md:141-142` (base numbering; phase 4 removes
lines after this sentence, not before, so the location is unchanged)
**Change:** Replace the sentence

```markdown
Writing `~/.config/nvim` (deploying is the owner's `git -C ~/.config/nvim pull
  --ff-only`, which `live` prints and never runs).
```

with the sentence below, reflowing the bullet to the file's ~100-column wrap. The `old_string` is
phase 4's final bullet, quoted in phase-4.md's Interface Contract (its line 4 ends at
``(`-L default`).`` with no trailing ` The`). After phases 4 and 5 the whole bullet reads (only the
"Writing `~/.config/nvim`" sentence changes in wording; the rest is phase 4's text, reflowed):

```markdown
- **Never driven, no flag turns it on.** A `git push` to any real remote (WORK's only remote is
  the run's bare repo; `GIT_SSH_COMMAND=/bin/false`, no global git config, no credentials, and no
  network anyway). Writing `~/.config/nvim` (deploying is the owner's `git -C ~/.config/nvim
  fetch origin && git -C ~/.config/nvim merge --ff-only origin/main`, which `live` prints and
  never runs; plain `git pull` fails in that checkout with "Cannot fast-forward to multiple
  branches"). The owner's tmux server (`-L default`). AI or Copilot-style plugins: none in the
  spec; `~/.local/share/nvim/avante` and other leftovers are never copied. Clipboard: `+` goes to
  the run's tmux buffer, never the Windows clipboard (no `clip.exe` on the run's PATH, no
  DISPLAY).
```

**Impact:** docs only.

### Step 3: features/live-environment.md, the two deploy mentions
**File:** `.claude/skills/verify-nvim-config/features/live-environment.md:13-14` and `:43`
**Change:** Replace lines 13-14

```markdown
The owner deploys with `git -C ~/.config/nvim pull --ff-only` and restarts nvim. These two
commands answer "what will that change, and will it work on my machine?" first.
```

with

```markdown
The owner deploys with `git -C ~/.config/nvim fetch origin && git -C ~/.config/nvim merge
--ff-only origin/main` (plain `git pull` fails in that checkout: "Cannot fast-forward to multiple
branches") and restarts nvim. These two commands answer "what will that change, and will it work
on my machine?" first.
```

and line 43

```markdown
- Deploying (pulling into `~/.config/nvim`) is the owner's step. verify never runs it.
```

with

```markdown
- Deploying (fetch + `merge --ff-only origin/main` in `~/.config/nvim`) is the owner's step.
  verify never runs it.
```

Touch nothing else in this file (lines 24-31 belong to phase 9).
**Impact:** feature-map entry for `live` now matches what `live` prints.

### Step 4: Evidence and commit
Run the Proof journeys, then commit the three files with a pathspec:

```
git commit -m "fix(verify): print a deploy command that works in the live checkout" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" \
  -- .claude/skills/verify-nvim-config/scripts/verify.sh .claude/skills/verify-nvim-config/SKILL.md .claude/skills/verify-nvim-config/features/live-environment.md
```

After every run is down, write `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-5.md` (`## Phase 5`,
the evidence paths) and commit it on its own (execution rule 4).

Do not push. Do not run the printed deploy command.

## Principles applied

- Fix root causes: Step 0 reproduces the wrong hint (base `live` prints `pull --ff-only`) before
  the edit; the cause is the literal at `verify.sh:639`. Why `git pull` refuses in the live
  checkout was not traced (its `.git/config` has a single `branch.main.merge`); the user supplied
  the working form, so the plan replaces the hint rather than changing the owner's git config.
- Laziness protocol: one echo and three doc sentences; no new flag, no deploy subcommand, no
  helper that runs the command.
- Prove it works: Proof drives the real `verify.sh live`, standalone and inside both a `--live`
  and a seeded run, and reads the line back from the evidence file.
- Encode lessons in structure: the exit check `git grep -n "pull --ff-only"` over the skill is
  part of Proof, which is why the verify.sh comment says "plain `git pull`" rather than quoting
  the failing form.

## Verification

**Build:** `bash -n .claude/skills/verify-nvim-config/scripts/verify.sh` (exit 0)
**Tests:** no test suite for the skill; the Proof journeys are the tests.
**Proof:**
- Harness: `.claude/skills/verify-nvim-config`
- Prerequisite: run every command from the worktree root
  this phase's worktree root (`$WT`, index § Execution rules), with
  `V=.claude/skills/verify-nvim-config/scripts/verify.sh`. `nvim --version | head -1` prints
  `NVIM v0.11.5` (phase 9 has not run). The seed exists (`$V up` works); if not, stop and report,
  do not seed from this phase.
- Feature-map entries: `features/live-environment.md`
- Journeys:
  1. Standalone `live` (base, then after).
     Base (before Step 1; after it, swap the base file in per execution rule 2 with
     `git show "$PHASE_BASE:.claude/skills/verify-nvim-config/scripts/verify.sh"`; never `git stash`,
     never by editing `~/.config/nvim`):
     ```sh
     $V live 2>/dev/null | tail -1
     ```
     Passes base when it prints
     `deploy (the owner's step, never run by verify): git -C /home/miftah/.config/nvim pull --ff-only`.
     After:
     ```sh
     $V live 2>/dev/null | tail -1
     ```
     Passes when it prints exactly
     `deploy (the owner's step, never run by verify): git -C /home/miftah/.config/nvim fetch origin && git -C /home/miftah/.config/nvim merge --ff-only origin/main`
     (the path is expanded, no literal `$LIVE_CONFIG`).
  2. Inside a `--live` run (evidence written):
     ```sh
     RUN=$($V up --live | sed -n 's/^RUN=//p')
     EV=$($V live "$RUN" 2>&1 >/dev/null | sed -n 's/^\[evidence: \(.*\)\]$/\1/p')
     echo "$EV"; tail -1 "$EV"
     $V down "$RUN"
     ```
     Passes when `$EV` is a file under the run's `evidence/` and its last line is the "after"
     line from Journey 1.
  3. Inside a seeded run (both-modes invariant):
     ```sh
     RUN=$($V up | sed -n 's/^RUN=//p')
     EV=$($V live "$RUN" 2>&1 >/dev/null | sed -n 's/^\[evidence: \(.*\)\]$/\1/p')
     echo "$EV"; tail -1 "$EV"
     $V down "$RUN"
     ```
     Passes on the same condition as Journey 2.
  4. No stale mention left:
     ```sh
     git grep -n "pull --ff-only" -- .claude/
     git grep -n "merge --ff-only origin/main" -- .claude/
     ```
     Passes when the first prints nothing (exit 1) and the second prints exactly four lines:
     `scripts/verify.sh` (the echo), `SKILL.md` (one), `features/live-environment.md` (two: the
     line-13/14 sentence and the line-43 gotcha).
- Do NOT run the printed `fetch` / `merge` command: it writes `~/.config/nvim` (the post-land
  Deploy section does that).
- Neighbor check: the rest of `live`'s report is unchanged. In Journey 1's "after" output the
  lines `live:`, `checkout:`, `live uncommitted:`, `files that differ`, `tmux:` and `live lock:`
  are all present, and `$V doctor "$RUN"` in Journey 2 (run it before `down`) exits 0 with its
  `live ok ... unchanged since up` line, showing `live` stayed read-only.
- Cost: none (no paid drives; `live` and `up` are offline).
- Evidence: after the last `down`, write Journey 1 base/after outputs (saved under
  `$VERIFY_HOME/live-*.txt`, path printed on stderr) and the `$EV` paths of Journeys 2-3 into
  `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-5.md` under `## Phase 5` (phase 9 indexes it).
**Exit criteria:** base `verify.sh live` prints `pull --ff-only`; after, it (and `live RUN` in both
a `--live` and a seeded run) prints
`git -C /home/miftah/.config/nvim fetch origin && git -C /home/miftah/.config/nvim merge --ff-only origin/main`;
`git grep -n "pull --ff-only" -- .claude/` prints nothing; `bash -n verify.sh` exits 0.

## Handoffs

- Phase 9: `features/live-environment.md` "End state seen" (lines 24-31) still quotes an old
  `live` run (`d7bf9fe` / `24ff768`); refreshing it is phase 9's journey-summary edit. If phase 9
  quotes a `live` output, its last line is now the fetch + merge form.
- Post-land Deploy (index): use exactly the command this phase prints; it is the only step that
  runs it.
- Not done anywhere (out of every phase's scope, noted for the reconciler): why `git pull` in
  `~/.config/nvim` reports "Cannot fast-forward to multiple branches" (its `.git/config` has one
  `branch.main.merge`); diagnosing it would mean running git operations on the live checkout.

## Rollback

`git revert <phase-5 commit>`; it touches only the three files above, and no other phase's code
reads the changed line.
