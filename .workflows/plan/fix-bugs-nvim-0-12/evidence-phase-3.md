## Phase 3

R6: dashboard redraw follows the selection. nvim 0.11.5 (installed). Evidence dirs are under `/home/miftah/.local/state/nvim-config-verify/<run>/evidence/`.

- base, live:   A `1104-112221-2107843`, B `1104-112229-2116167`, C `1104-112332-2160051` (C first ran as `1104-112235-2122743` with the plan's float-counting probe)
- base, seeded: A `1104-112256-2136885`, B `1104-112303-2141968`, C `1104-112340-2168652` (first C: `1104-112308-2146705`)
- fix, live:    A `1104-112404-2180461`, B `1104-112411-2185867`, C `1104-112419-2193162`
- fix, seeded:  A `1104-112427-2205368`, B `1104-112433-2210131`, C `1104-112438-2213405`
- Every `up` had no startup errors, every `doctor` exited 0, and no `messages-at-down.txt` had `E5108`/`Error`.

Verdicts (live S=assassins_creed; seeded S=eyes, saved=(none)):

| Journey | base live | base seeded | fix live | fix seeded |
|---|---|---|---|---|
| J1 start screen `,bg` | `shown=assassins_creed saved=beafis` ✗ | `shown=eyes saved=family_guy_1` ✗ | `shown=beafis saved=beafis` ✓ | `shown=family_guy_1 saved=family_guy_1` ✓ |
| J2 `,bh` | `shown=assassins_creed saved=bikini` ✗ | `shown=eyes saved=bikini` ✗ | `shown=bikini saved=bikini` ✓ | same ✓ |
| J3 `,bv` skull | `shown=assassins_creed saved=skull` ✗ | `shown=eyes saved=skull` ✗ | `shown=skull saved=skull`, ft `dashboard` ✓ | same ✓ |
| J4 behind nvim-tree | `shown=assassins_creed saved=beafis` ✗ | `shown=eyes saved=family_guy_1` ✗ | `shown=beafis saved=beafis`, ft `NvimTree` ✓ | `shown=family_guy_1 saved=family_guy_1`, `NvimTree` ✓ |
| J5 `e` then `,bg` | `(no dashboard window)`, `\|\|1\|1` ✓ | same ✓ | same ✓ | same ✓ |
| J6 split `,bg` | `shown=bikini saved=bikini` ✓ | `shown=family_guy_2` ✓ | `shown=bikini saved=bikini` ✓ | `shown=family_guy_2` ✓ |
| J7 split `e` then `,bg` | `shown=bison`, `dashboard\|nofile\|37\|2` ✗ (hijack) | `shown=git`, `dashboard\|nofile\|26\|2` ✗ | `(no dashboard window) saved=bison`, `\|\|1\|2` ✓ | `(no dashboard window) saved=git`, `\|\|1\|2` ✓ |

Proof: verified-first-pass (every fix journey passed on its first run).

Decision: the plan's window-count probe `#nvim_tabpage_list_wins(0)` counted the "Switched to:" nvim-notify float (first base C runs read `||1|2` / `|4`); the probe in `features/dashboard.md` now counts only non-floating windows (rung 2: exit criteria). Base C was re-run with it.
