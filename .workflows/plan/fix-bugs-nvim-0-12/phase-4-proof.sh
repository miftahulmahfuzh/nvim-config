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
