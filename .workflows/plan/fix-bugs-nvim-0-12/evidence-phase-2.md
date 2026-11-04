## Phase 2 (R2: pyright)

Harness: `.claude/skills/verify-nvim-config/scripts/verify.sh`, nvim 0.11.5. Root: `~/.local/state/nvim-config-verify/`.
Fix commit: `0004bf0 fix(lsp): start pyright with Mason's pyright-langserver`. Proof: verified-first-pass.

- base --live: RUN=1104-112312-2148274, `.../1104-112312-2148274/evidence/` (nvim-1: `wait ok` delance line seen, pyright `0` clients, DIAG `none`; `logs/lsp.log` has 1 `delance-langserver is not executable` line). doctor exit 0.
- base seeded: RUN=1104-112328-2155932, `.../1104-112328-2155932/evidence/` (same end state: pyright `0`, DIAG `none`, 1 delance line). doctor exit 0.
- fix --live (sync, nvim-2): same LIVE run, `LOG.md` `wait ok ... == pyright` and `... == reportAssignmentType`; `09-lua-vim.lsp.get_clients__bufnr_0__name__pyri.txt` = `pyright-langserver .../1104-112312-2148274/xdg/data/nvim/mason/bin/pyright-langserver` (pyright 1.1.407); `14-screen-pyright-diagnostic.txt` (E sign + virtual text on `count: int = "three"`); 0 new delance lines after sync.
- fix seeded (sync, nvim-2): same SEED run, same files (`.../1104-112328-2155932/xdg/data/nvim/mason/bin/pyright-langserver`, pyright 1.1.414); 0 new delance lines.
- fresh seeded: RUN=1104-112414-2186491, `up` no startup errors, doctor exit 0, `LOG.md` `wait ok ... pyright`, `wait ok ... lua_ls`, `wait ok ... gopls`; `04-lua-*` = `standard` (settings still merge); `05-lua-*` = `pyright,lua_ls,stylua,gopls`; `logs/lsp.log` 0 delance lines.

Notes:
- After `sync`, `doctor` exited 1 on both runs because of the base verify.sh `opencode FAIL resolves to '~/.opencode/bin/opencode', not the run's fake` (the restarted nvim's PATH loses the per-run fake). That is not related to R2, and phase 4 removes the opencode check and fake. The `--live` run also showed `live WARN the owner's live dirs changed since up` from concurrent activity outside the run. A fresh `up` doctor (seeded) exits 0.
- A first attempt (RUN=1104-112218-2105774) is void: zsh read `$PHASE_BASE:a` as a modifier, so the base swap wrote an empty `pyright.lua`. It was torn down and redone under bash.
