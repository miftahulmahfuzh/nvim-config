## Phase 6

R7: graceful offline lazy bootstrap. Installed nvim 0.11.5, harness `.claude/skills/verify-nvim-config`.
Base = `2065448` (phase-5 tip), fix = `8b5d871`. Evidence dirs are `~/.local/state/nvim-config-verify/<RUN>/evidence`.

- J1 before bare: RUN=1104-112754-2269985 ~/.local/state/nvim-config-verify/1104-112754-2269985/evidence, `up --bare` printed `startup :messages contain errors` with `E5113 ... plugin_specs.lua:587: module 'lazy' not found` (3 hits); `colors = "nil", ul = true`; doctor `messages WARN errors in :messages`
- J4 before seeded: RUN=1104-112802-2272909 ~/.local/state/nvim-config-verify/1104-112802-2272909/evidence, no startup errors, `00-up-messages.txt` blank, lazy count 93, doctor `nvim ok ... VeryLazy plugins loaded` / `messages ok`
- J4 before live: RUN=1104-112806-2275887 ~/.local/state/nvim-config-verify/1104-112806-2275887/evidence, no startup errors, `00-up-messages.txt` blank, lazy count 93, doctor `nvim ok` / `messages ok`
- J2 after bare: RUN=1104-112845-2281232 ~/.local/state/nvim-config-verify/1104-112845-2281232/evidence, no `startup :messages contain errors`/E5113; `00-up-messages.txt` = one line `lazy.nvim clone failed (git exit 128): plugins off until an online restart`; `colors = "habamax", underline = false, severity_sort = true, leader = ",", save = "<Cmd>update<CR>", gts = true, lazy = false, lazy_dir = 0, did = 1`; doctor `nvim info --bare run: 1` / `messages ok   no errors in :messages`
- J3 after bare (broken dir): RUN=1104-112852-2284398 ~/.local/state/nvim-config-verify/1104-112852-2284398/evidence (01-headless-*), an empty `lazy/lazy.nvim` → `lazy.nvim not loadable: plugins off until you delete <run>/xdg/data/nvim/lazy/lazy.nvim and restart online` + `habamax`, no E5113/traceback; after `rmdir` (02-headless-*) → `lazy.nvim clone failed (git exit 128): plugins off until an online restart` + `habamax`, and `xdg/data/nvim/lazy/` empty (partial clone deleted). The line shows twice in the headless output: the stderr echo plus the probe's `:messages`
- J4 after seeded: RUN=1104-112858-2286673 ~/.local/state/nvim-config-verify/1104-112858-2286673/evidence, identical to before: no startup errors, blank messages, count 93, doctor `nvim ok` / `messages ok`
- J4 after live: RUN=1104-112902-2290249 ~/.local/state/nvim-config-verify/1104-112902-2290249/evidence, identical to before: no startup errors, blank messages, count 93, doctor `nvim ok` / `messages ok`
- Invariant 1 (seeded doctor on the fix commit): RUN=1104-112920-2301942 ~/.local/state/nvim-config-verify/1104-112920-2301942/evidence, `doctor` exit 0, `code ok`, `seed ok`, `messages ok`

Build check: `stylua --check lua/plugin_specs.lua` exit 0; lines 1-45 match the plan's Interface Contract text verbatim.
Proof: verified-first-pass (every journey passed on the first run, no fix iterations).
