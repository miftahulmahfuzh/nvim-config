# Evidence: nvim-0-12-clean

Per-phase detail lives in `evidence-phase-1.md` ... `evidence-phase-4.md` in this directory. Run evidence
lives under `~/.local/state/nvim-config-verify/<RUN>/evidence/`, outside the repo, and is kept
after `down`. `E=~/.local/state/nvim-config-verify` below. Every run used Neovim 0.12.6
(`/opt/nvim-linux-x86_64`). Base: `origin/main` @ `8bcb55c`, then `9cea538`, whose only change is
an unrelated startup fix.

Phase 4's lever (`phase-4-health.sh`) re-proves R2, R4, R5, R6a-f in one run per mode. Its evidence file numbers:
- `01` `v:errmsg == ""`; `02` noise at startup;
- `03` `terminal-overrides`; `04` setrgb count;
- `07` checkhealth vs allow-list with gopls attached;
- `12` load_all; `13` noise after load_all;
- `15` checkhealth vs allow-list with all plugins loaded;
- `17` deprecations;
- `phase4-doctor.txt`.

Lever runs:
- Before Step 3/4: seeded `$E/1104-135135-3546728`, live `$E/1104-135146-3552065`.
- After: seeded `$E/1104-135215-3559599`, live `$E/1104-135227-3564882`.

## Before/after per requirement and known leftover

| Item | Leftover | What | Before (live / seeded) | After (live / seeded) | Phase | Detail |
|---|---|---|---|---|---|---|
| R1 | 1 | `sync` respawns nvim with `run_path`; doctor `path` | `$E/1104-112534-2226714` (repro); `$E/1104-121901-2809686/evidence/16-lua-vim.env.PATH.txt` vs `17-lua-vim.env.PATH.txt` (caller's PATH after sync); `$E/1104-130336-2985618` `01-`/`02-lua-vim.env.PATH.txt` / `$E/1104-130404-2996131` `05-`/`06-lua-vim.env.PATH.txt` | `$E/1104-130537-3002073` `01-`/`02-lua-vim.env.PATH.txt`, `doctor-after-sync.txt` (`path ok`) / `$E/1104-130602-3008952` (same); fault injection `$E/1104-130609-3013951` `doctor-leak.txt` (`path FAIL`, exit 1); phase 4 lever `phase4-doctor.txt` in `$E/1104-135227-3564882` / `$E/1104-135215-3559599` | 1 | `evidence-phase-1.md` |
| R2 | 2 | no `client.request is deprecated` (blink.cmp v1.10.2) | `$E/1104-121455-2789754/evidence/15-screen-screen.txt`; `$E/1104-132435-3158849` `02-keys-G_o.txt`, `21-lua-…` / `$E/1104-123952-2930953/evidence/08-lua-vim.fn.execute__messages__.txt` + stack `13-lua-…`; `$E/1104-132438-3160384` `21-lua-…` | `$E/1104-133718-3342035` `04-screen-completion-lua.txt`, `24-lua-…`, `25-`/`26-lua-…` (`rust`, `v1.10.2 v1.10.2`) / `$E/1104-133721-3343691` (same); lever `17-lua-…` (`0`) in `$E/1104-135227-3564882` / `$E/1104-135215-3559599` | 3 | `evidence-phase-3.md` |
| R3 | 3 | CursorHold `open_float` "Invalid 'width'" in a 2-column window | `$E/1104-121901-2809686/evidence/14-screen-screen.txt`; `$E/1104-131054-3055370/evidence/15-screen-narrow.txt` / `$E/1104-131214-3068043/evidence/15-screen-narrow.txt` | `$E/1104-131054-3055370` `34-screen-narrow.txt`, `35-lua-…` (`width = 2, floats = 0`) / `$E/1104-131214-3068043` (same) | 2 | `evidence-phase-2.md` |
| R4 | 4 | no git-conflict `vim.highlight` / `vim.validate{}` | `$E/1104-121901-2809686/evidence/03-lua-return_table.concat_vim.api.nvim_buf_get.txt` (vim.deprecated); `$E/1104-132435-3158849` `28-lua-…` / `$E/1104-123911-2920493/evidence/03-lua-…`; `$E/1104-132438-3160384` `28-lua-…` | `$E/1104-133718-3342035` `31-lua-…` / `$E/1104-133721-3343691` `31-lua-…` (no blink / git-conflict line); lever `07-`/`15-lua-…` (`unexpected=0`; the `vim.deprecated` keys are plugin-attributed) in `$E/1104-135227-3564882` / `$E/1104-135215-3559599` | 3 | `evidence-phase-3.md` |
| R5 | 5 | `v:errmsg` empty after startup (no E216) | `$E/1104-121455-2789754/evidence/01-lua-vim.v.errmsg.txt`; `$E/1104-131054-3055370/evidence/01-lua-vim.v.errmsg.txt` / `$E/1104-123952-2930953/evidence/03-lua-vim.v.errmsg.txt`; `$E/1104-131214-3068043/evidence/01-lua-vim.v.errmsg.txt` | `$E/1104-131054-3055370/evidence/20-lua-vim.v.errmsg.txt` / `$E/1104-131214-3068043/evidence/20-lua-vim.v.errmsg.txt`; lever `01-lua-…` (`true`) in `$E/1104-135227-3564882` / `$E/1104-135215-3559599` | 2 | `evidence-phase-2.md` |
| R6a | 6 | go.nvim health: no ❌, no `Missing tool` (Go tools on run PATH) | `$E/1104-130357-2992108/evidence/03-lua-…` (`ERROR=1 missing=19`) / `$E/1104-130404-2996131/evidence/03-lua-…` | `$E/1104-130537-3002073/evidence/09-lua-…` / `$E/1104-130602-3008952/evidence/09-lua-…` (`ERROR=0 missing=0`) | 1 | `evidence-phase-1.md` |
| R6b | 6 | fidget health: no implicit-integration warning | `$E/1104-131054-3055370/evidence/04-lua-…` / `$E/1104-131214-3068043/evidence/04-lua-…` | `$E/1104-131054-3055370/evidence/23-lua-…` / `$E/1104-131214-3068043/evidence/23-lua-…` (empty) | 2 | `evidence-phase-2.md` |
| R6c | 6 | tmux true colour | `$E/1104-135146-3552065` / `$E/1104-135135-3546728`: `03-lua-…` (empty), `04-lua-…` (`0`), `07-lua-…` (`UNEXPECTED vim.health / tmux`) | `$E/1104-135227-3564882` / `$E/1104-135215-3559599`: `03-lua-…` (`*256col*:Tc`), `04-lua-…` (`2`), `07-lua-…` (`unexpected=0`) | 4 | `evidence-phase-4.md` § True colour |
| R6d | 6 | render-markdown latex/yaml warnings | `$E/1104-123923-2924758/evidence/11-lua-…` / `$E/1104-123911-2920493/evidence/11-lua-…`; `$E/1104-135146-3552065/evidence/15-lua-…` / `$E/1104-135135-3546728/evidence/15-lua-…` (5 `render-markdown` keys) | `$E/1104-135227-3564882/evidence/15-lua-…` / `$E/1104-135215-3559599/evidence/15-lua-…` (`unexpected=0`) | 4 | `evidence-phase-4.md` § Findings 1 |
| R6e | 6 | checkhealth minus allow-list empty (gopls attached; all loaded) | `$E/1104-123923-2924758/evidence/03-lua-…`, `11-lua-…` / `$E/1104-123911-2920493/evidence/03-lua-…`, `11-lua-…` | `$E/1104-135227-3564882/evidence/07-lua-…`, `15-lua-…` / `$E/1104-135215-3559599/evidence/07-lua-…`, `15-lua-…` (`sections=20` and `22`, `unexpected=0`) | 4 | `evidence-phase-4.md` § After |
| R6f | 6 | every plugin loads, no noise | `$E/1104-123923-2924758/evidence/08-lua-…` / `$E/1104-123911-2920493/evidence/08-lua-…` | `$E/1104-135227-3564882/evidence/12-`, `13-lua-…` / `$E/1104-135215-3559599/evidence/12-`, `13-lua-…` (`tried=17 failed=0 unloaded=0`, `noise=0 known=1`) | 4 | `evidence-phase-4.md` § After |
| R6g | 6 | `:messages`/notify clean after every `features/*.md` journey | — (not swept on the base) | live: `$E/1104-135343-3578529`, `1104-135458-*`, `1104-135511-*` (startup, dashboard, format), `1104-135420-3595239` … `1104-135600-3728770` (lsp, treesitter, editing, fzf), `1104-135407-3589592`, `1104-135627-3767397`, `1104-135747-3809749` (git, tmux, img2braille, live-environment, health) / seeded: `$E/1104-135610-*`, `1104-135619-*`, `1104-135425-3601917` … `1104-135529-3699488`, `1104-135818-3827299`, `1104-135856-3841678`, `1104-140027-3942593`; one row per block × mode, every row matched with `noise=0` or only expected/KNOWN noise | 4 | `evidence-phase-4.md` § Sweep |
| R7 | — | land, Deploy, final `up --live` + doctor from `~/.config/nvim` | — | the Deploy report `~/.local/state/nvim-config-verify/deploy-<DATE>.md` (written by runbook D6; never into the repo, so `~/.config/nvim` stays clean) | Deploy | `phase-4.md` § Deploy runbook |

## Recorded, not fixed (upstream- or environment-only)

The allow-list and known noise in `.claude/skills/verify-nvim-config/features/health.md` hold each
line's origin and reason. In short:
- optional tools not installed (snacks, fzf-lua, telescope, diffview, Mason languages);
- go.nvim's optional extras, including its debugger plugins (`nvim-dap*`), which the config does not use;
- the run's fence (`cargo` outside `run_path`, PyPI offline);
- nvim-lspconfig's compound default filetypes;
- the owner's deliberate mappings (targets, which-key);
- blink v1's always-printed providers line;
- fixed upstream, not moved here: go.nvim's `vim.lsp.codelens.refresh` and glance.nvim's
  `vim.validate{}` deprecations (follow-up `P2-NVIM-F6PG` in `.workflows/todos.md`);
- `E31` on markdown buffers (Neovim runtime ftplugins + lazy's `ft` re-fire).
