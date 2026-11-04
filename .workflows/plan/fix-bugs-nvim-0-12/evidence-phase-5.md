## Phase 5 — Deploy hint: fetch + merge --ff-only (R10)

Base `348241b` (set branch after phase 4), fix `233b949`. Harness `.claude/skills/verify-nvim-config`,
nvim 0.11.5. All runs below are down. Evidence root `E=~/.local/state/nvim-config-verify`.

| Journey | Before (base) | After (fix) |
|---|---|---|
| 1. standalone `verify.sh live`, last line | `$E/live-1104-112503.txt` → `... git -C /home/miftah/.config/nvim pull --ff-only` | `$E/live-1104-112514.txt` → `... git -C /home/miftah/.config/nvim fetch origin && git -C /home/miftah/.config/nvim merge --ff-only origin/main` |
| 2. `live RUN` inside `up --live` | — | `$E/1104-112528-2222909/evidence/01-live-drift.txt` (doctor exit 0); rerun `$E/1104-112546-2233489/evidence/01-live-drift.txt` |
| 3. `live RUN` inside seeded `up` | — | `$E/1104-112532-2225951/evidence/01-live-drift.txt` (doctor exit 0, `seed ok`, `messages ok`) |
| 4. `git grep -n "pull --ff-only" -- .claude/` | 2 hits (verify.sh echo, live-environment.md:13) + SKILL.md's wrapped `pull`/`--ff-only` | no output (exit 1); `git grep "merge --ff-only origin/main"` = 4 lines (verify.sh, SKILL.md, live-environment.md x2) |

`bash -n verify.sh` exits 0. The rest of `live`'s report (`live:`, `checkout:`, `live uncommitted:`,
`files that differ`, `tmux:`, `live lock:`) is unchanged.

Neighbor note (not caused by this phase): in both `--live` runs `doctor` prints
`live WARN the owner's live dirs changed since up`, already **before** `live RUN` is called
(run `1104-112546-2233489`, doctor before and after). The writer is the swarm itself: the
coordinator's gitignored `~/.config/nvim/.workflows/orchestration/fix-bugs-nvim-0-12/ledger.json`
is rewritten during runs, and `live_fingerprint` hashes every file under `$LIVE_CONFIG` except
`.git`. `live` stays read-only (`--no-optional-locks`, only `echo`).

Decision: Journey 4 expects the `merge --ff-only origin/main` string on one line in
live-environment.md:13-14, while Step 3's wrap split it; the sentence was reflowed (same words)
so both hold. Rung 2 (exit criteria) over rung 3 (code block line breaks; text kept verbatim).
