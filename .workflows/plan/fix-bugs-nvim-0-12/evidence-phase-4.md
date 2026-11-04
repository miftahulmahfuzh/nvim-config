## Phase 4 (R8: purge opencode)

Proof script: `.workflows/plan/fix-bugs-nvim-0-12/phase-4-proof.sh` (nvim 0.11.5, default `NVIM_BIN`, shared seed not re-seeded).
Base = `f186cea`; commit 1 = `83dec62` (config); commit 2 = `96a6aa1` (verify skill).

- base live:      RUN=1104-112215-2105476  EVIDENCE=~/.local/state/nvim-config-verify/1104-112215-2105476/evidence  (doctor-phase4.txt: `opencode ok   resolves to the run's fake (.../1104-112215-2105476/bin/opencode)`; evidence/sink present)
- base seeded:    RUN=1104-112227-2113637  EVIDENCE=~/.local/state/nvim-config-verify/1104-112227-2113637/evidence  (same: fake opencode line, `command -v opencode` -> `<run>/bin/opencode`, evidence/sink present)
- mid (commit 1): RUN=1104-112241-2125362  EVIDENCE=~/.local/state/nvim-config-verify/1104-112241-2125362/evidence  (config without `custom/opencode.lua` starts clean; base harness checks still hold)
- after live:     RUN=1104-112323-2153473  EVIDENCE=~/.local/state/nvim-config-verify/1104-112323-2153473/evidence  (doctor-phase4.txt: no opencode line, exit 0; `command -v opencode` -> none although the owner has `~/.opencode/bin/opencode`; no bin/ or sink/; fzf-lua `,ff` -> docs/guide.txt)
- after seeded:   RUN=1104-112330-2158146  EVIDENCE=~/.local/state/nvim-config-verify/1104-112330-2158146/evidence  (same end state; doctor `seed ok`)
- static: `bash -n verify.sh` ok; `git grep -n -i opencode -- . ':!docs' ':!.workflows'` empty (exit 1); `git grep -n -i -E 'VERIFY_SINK|\bsink\b|\$dir/bin' -- .claude` empty (exit 1)

Proof: verified-first-pass (all 5 journeys passed without a fix in between).
Decision: Step 3 of /implement (todos.md tasks) skipped — execution rule 4 lets phases commit only their evidence file (+ this proof script).
