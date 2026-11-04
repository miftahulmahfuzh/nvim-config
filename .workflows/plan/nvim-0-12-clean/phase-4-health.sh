#!/usr/bin/env bash
# Phase 4 lever (nvim-0-12-clean). In one run of the given mode it checks:
#   - doctor, startup :messages, v:errmsg and noise;
#   - tmux true colour;
#   - :checkhealth against features/health.md, with gopls attached and again once every lazy
#     plugin is loaded;
#   - that every plugin loads.
# Run it from a repo root (a worktree or ~/.config/nvim). It prints one "check <name> PASS|FAIL
# <detail>" line per check, then RUN= and EVIDENCE=, and exits 1 on any FAIL. KEEP=1 leaves the
# run up; by default it is taken down.
#   .workflows/plan/nvim-0-12-clean/phase-4-health.sh seeded|live
set -uo pipefail
case "${1:-}" in
  seeded) up_args=() ;;
  live) up_args=(--live) ;;
  *) echo "usage: $0 seeded|live" >&2; exit 2 ;;
esac
V=.claude/skills/verify-nvim-config/scripts/verify.sh
P=$PWD/.claude/skills/verify-nvim-config/features/lua
VH=$HOME/.local/state/nvim-config-verify
[ -x "$V" ] && [ -f "$P/health_diff.lua" ] || { echo "run from the repo root (needs $V and $P)" >&2; exit 2; }

fail=0
check() { if [ "$2" = 1 ]; then echo "check $1 PASS $3"; else echo "check $1 FAIL $3"; fail=1; fi; }
yes_if() { if "$@"; then echo 1; else echo 0; fi; }
val() { "$V" lua "$RUN" "$1" 2>/dev/null | tail -n +2; }   # result lines, without the "> lua:" echo
first() { val "$1" | sed -n 1p; }

health() {   # $1 = check name, $2 = minimum number of sections
  local res head n min=$2   # $2 must not be read inside yes_if's eval (that would be yes_if's own $2)
  "$V" keys "$RUN" : checkhealth Enter >/dev/null 2>&1
  if ! "$V" wait "$RUN" 'vim.bo.filetype' checkhealth 120 >/dev/null 2>&1; then
    check "$1" 0 "no complete checkhealth report after 120 s"
    return
  fi
  res=$(val "@$P/health_diff.lua")
  head=$(sed -n 1p <<<"$res")
  n=${head#sections=}; n=${n%% *}
  check "$1" "$(yes_if eval '[ "${n:-0}" -ge "$min" ] && [[ $head == *" unexpected=0 "* ]]')" "$head"
  grep '^UNEXPECTED' <<<"$res" | sed 's/^/    /'
  "$V" keys "$RUN" : tabclose Enter >/dev/null 2>&1
}

out=$("$V" up "${up_args[@]}") || { echo "$out"; echo "up failed" >&2; exit 1; }
echo "$out"
RUN=$(sed -n 's/^RUN=//p' <<<"$out")
E=$VH/$RUN/evidence
grep -E '^(filled|replaced)_from_seed=' "$VH/$RUN/meta" || true

"$V" doctor "$RUN" >"$E/phase4-doctor.txt" 2>&1; rc=$?
check doctor "$(yes_if [ "$rc" = 0 ])" "exit $rc ($E/phase4-doctor.txt)"
check startup-messages "$(yes_if [ -z "$(tr -d '[:space:]' <"$E/00-up-messages.txt")" ])" "$E/00-up-messages.txt"
r=$(first 'vim.v.errmsg == ""')
check errmsg "$(yes_if [ "$r" = true ])" "vim.v.errmsg empty: $r"
r=$(first "@$P/noise.lua")
check noise-startup "$(yes_if eval '[[ $r == noise=0* ]]')" "$r"

r=$(first 'vim.trim(vim.fn.system({ "tmux", "show-options", "-gv", "terminal-overrides" }))')
check tc-override "$(yes_if eval '[[ $r == *"*256col*:Tc"* ]]')" "terminal-overrides: ${r:-<empty>}"
r=$(first '#vim.tbl_filter(function(l) return l:find(" setrgb[bf]: %(string%)") ~= nil end, vim.split(vim.fn.system({ "tmux", "show-messages", "-T" }), "\n"))')
check tc-rgb "$(yes_if [ "${r:-0}" -ge 2 ] 2>/dev/null)" "setrgbb/setrgbf lines in show-messages -T: ${r:-0}"

"$V" keys "$RUN" : e Space main.go Enter >/dev/null 2>&1
"$V" wait "$RUN" '#vim.lsp.get_clients({bufnr=0, name="gopls"})' 1 90 >/dev/null 2>&1; rc=$?
check gopls "$(yes_if [ "$rc" = 0 ])" "gopls attached to main.go"
health health-lsp 20
r=$(first "@$P/noise.lua")
check noise-health "$(yes_if eval '[[ $r == noise=0* ]]')" "$r"

"$V" keys "$RUN" : e Space notes.md Enter >/dev/null 2>&1
"$V" keys "$RUN" y y >/dev/null 2>&1
r=$(val "@$P/load_all.lua"); h=$(sed -n 1p <<<"$r")
check load-all "$(yes_if eval '[[ $h == *" failed=0 unloaded=0" ]]')" "$h"
"$V" wait "$RUN" '#require("lazy").plugins() == require("lazy").stats().loaded' true 30 >/dev/null 2>&1 || true
r=$(val "@$P/noise.lua")
check noise-load-all "$(yes_if eval '[[ $(sed -n 1p <<<"$r") == noise=0* ]]')" "$(tr '\n' ' ' <<<"$r")"
health health-all-loaded 22
# phase 3's probe, cumulative. Not counted: go.nvim's codelens.refresh and glance.nvim's
# vim.validate{} ("fixed upstream, not moved here" in health.md); any other line fails.
r=$(val "@$PWD/.claude/skills/verify-nvim-config/features/lua/deprecations.lua" | tail -n +2 \
  | grep -vF -e 'vim.lsp.codelens.refresh({ bufnr = bufnr}) is deprecated.' -e 'vim.validate{<table>} is deprecated.' | grep -c .)
check deprecations "$(yes_if [ "$r" = 0 ])" "deprecation/blink-fallback notices so far, minus health.md's two upstream ones: $r"

echo "RUN=$RUN"
echo "EVIDENCE=$E"
[ "${KEEP:-0}" = 1 ] || "$V" down "$RUN" >/dev/null 2>&1
exit "$fail"
