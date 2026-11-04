## Phase 9: Neovim 0.12.6 + nvim-treesitter main (R3, R9)

Harness `.claude/skills/verify-nvim-config`, every call with
`VERIFY_NVIM=$HOME/.local/opt/nvim-0.12.6/nvim-linux-x86_64/bin/nvim`. Run evidence:
`~/.local/state/nvim-config-verify/<RUN>/evidence/`; phase logs: `P9=~/.local/state/nvim-config-verify/phase9-evidence/`.
Base = `43009df` (phase 8 tip). Commits: `fe75a21` feat(nvim), `eace1e8` fix(treesitter), `c90a7ca` fix(verify), `1aa35e1` docs(verify).

- nvim: staged 0.12.6 at `~/.local/opt/nvim-0.12.6/nvim-linux-x86_64` (tarball sha256 `474430d5…1d87` OK), backup 0.11.5 at `~/.local/opt/nvim-0.11.5/nvim-linux-x86_64` (`diff -r` identical to `/opt`): `$P9/step0.txt`. `/opt/nvim-linux-x86_64` still v0.11.5, `~/.config/nvim` clean @ `a14aef9`, live lock mtime unchanged, no `~/.local/share/nvim/site`, live hop still phaazon (checked after the last run).
- base (J0) live `1104-114225-2494333` / seeded `1104-114158-2487124`: `00-up-messages.txt` = `Expect nvim version 0.11.5, but your current nvim version is 0.12.6`; `vaf` → `05-lua-vim.v.errmsg.txt` = `E5108 ... tsrange.lua:27: attempt to call method 'start' (a nil value)`; spec branch `(spec has no branch)`, plugin dir `42fc28ba` (`07-cli-*`). Transcripts `$P9/step1-base.txt`, `$P9/step1-base-live-retry.txt`. (The first live base run `1104-114152-2476680` never got an nvim socket; a plain retry came up, so it was a harness flake, not the config.) Fresh-install branch (R3): `git ls-remote --symref` = `ref: refs/heads/main HEAD`, an upstream clone (`$P9/upstream/nvim-treesitter`) is on `main` and has no `lua/nvim-treesitter/configs.lua`; lazy's `get_branch` falls back to `remotes/origin/HEAD` (all in `$P9/step1-base.txt`).
- seed (J10): stage 1 `$P9/seed-stage1-try1.log` + `.seed.log` (`MOVED plugin nvim-treesitter: branch master -> main ... main@0195cd6`, same for `-textobjects` `main@5c7b026`, no hop MOVED, `ok mason tree-sitter-cli`, `WARN ... removed parser/` and `parser-info/`, then `FAIL treesitter parsers: ... attempt to call field 'get_installed'`), fixed, retried `$P9/seed-stage1.log` + `.seed.log` (no FAIL, `ok treesitter parsers`, 14 `.so` in `site/parser`, `tree-sitter 0.27.1`, meta `mason=10`); stage 2 `$P9/seed-stage2.log` + `.seed.log` (go.nvim `4755deff…` with `branch master`, url `ray-x/go.nvim.git` kept); the master→main transition re-proved after the fix: `$P9/seed-transition.log` + `.seed.log` (both MOVED lines, `ok treesitter parsers`, no FAIL, resulting seed lock byte-identical to `$P9/seed-lock-before-transition.json`).
- go.nvim before (stage 1) live `1104-114545-2522191` / seeded `1104-114553-2526955`: `06-lua-vim.fn.getline_5__...txt` = `module 'nvim-treesitter.ts_utils' not found` (go.nvim `81bb94c`), line 5 unchanged. After: J7 below. Transcript `$P9/gonvim-before.txt`.
- after: live `1104-115433-2628306` (J1-J9, format-on-save, lsp; `$P9/after-live.txt`) + `1104-115219-2595907` (hop, editing, fzf, git, img2braille, tmux; `$P9/after-live-edit.txt`); seeded `1104-115534-2646457` (`$P9/after-seeded.txt`) + `1104-115615-2661338` (`$P9/after-seeded-edit.txt`); dashboard live `1104-115650-2669657`/`115659-2674233`/`115706-2678908`, seeded `1104-115716-2683781`/`115722-2686879`/`115726-2689781` (`$P9/dash--live.txt`, `$P9/dashseeded.txt`); startup seeded `1104-115733-2693009`, live `1104-115752-2696708`, bare `1104-115759-2701396` + `live` drift (`$P9/startup.txt`).

| Journey | live | seeded | evidence |
|---|---|---|---|
| J1 startup: no version warning, doctor 0, 0.12.6, `replaced_from_seed` | pass (`go.nvim hop.nvim nvim-treesitter nvim-treesitter-textobjects`; `00-up-replaced.txt` has the 3 `+ site/...` lines) | pass (no keys, no `00-up-replaced.txt`) | `00-up-messages.txt` (empty), doctor in transcripts |
| J2 parsers in `site/`, one `parser/python.so`, `main main` | pass | pass | `$P9/after-*.txt` § J2 |
| J3 highlight lua/go/python/markdown, `current_syntax=markdown` | pass | pass | § J3 |
| J4 `vaf` {V,1,2}, `vif` {V,2,2}, `vac` {V,1,6}, `vic` {V,2,6}, no E5108 | pass | pass | § J4 |
| J5 `gnn` {v,2,12,2,14} → `grn` {v,2,12,2,47} → `grm` back; Normal `grn` = `vim.lsp.buf.rename()`; `grc` gone | pass | pass | § J5 |
| J6 treesitter `indentexpr`; `>>` then `==` restores 4 spaces; yaml `GetYAMLIndent` | pass | pass | § J6 |
| J7 go.nvim loaded, `:GoCmt` inserts `// add function`, no ts_utils error | pass | pass | `54-lua-vim.fn.getline_5_*` |
| J8 go format-on-save (`x := a + b`) | pass | pass | `58-cli-git_diff_main.go.txt` |
| J9 no errors in `:messages`, doctor 0 | pass (`messages ok`) | pass | doctor at FINAL |
| format-on-save.md (valid, err line 1, err line 8, clamp, python) | pass | pass | § FOS |
| lsp.md (lua_ls, gopls, pyright, `reportAssignmentType`, 0 delance lines) | pass | pass | § LSP |
| dashboard.md (start screen `,bg`/`,bh`/`,bv`, behind nvim-tree, leave + split) | pass | pass | dash transcripts |
| editing-mappings.md (`V H` 11 lines, `C-o` guide.txt/main.go, hop `v`→{3,0}, `F /`→{1,18}, `f Escape` stays) | pass | pass | `*-screen-f-hints.txt`, § HOP |
| fzf-lua.md (`,ff` → docs/guide.txt) | pass | pass | § FZF |
| git.md (commit + push to the run's remote) | pass | pass | § GIT |
| img2braille.md (`40x27 cells`, `shown=verify_art saved=verify_art`) | pass | pass | § IMG2BRAILLE |
| tmux-bindings.md (`C-b -`, `C-b @`, `C-b !`) | pass | pass | § TMUX |
| startup.md (stats count 93 loaded 63; Mason offline `installing=` + 0 installer lines; live gofumpt re-ensure; bare habamax + broken-dir message) | pass | pass | `$P9/startup.txt` |
| live-environment.md (`live`: 34 commits, fetch + merge deploy line) | pass | n/a | `$P9/startup.txt` § live drift |

- Decisions:
  - seed.lua's treesitter step also drops cached `nvim-treesitter*` modules before loading the plugin. The seed's nvim had loaded master's `nvim-treesitter` module before the step checked out `main`, so `get_installed` was nil. Measured fail, then pass, then re-proved on the transition. Rung 3: the step's job, in the plan's own code block, is to install the parsers.
  - J5 keys `2 G w w` → `2 G 0 w w`: `2 G` keeps the column, so after J4 the cursor landed on a blank line and `gnn` selected the whole module. Rung 2: exit criterion "`gnn`/`grn`/`grm` selection works".
  - J6 `<<` → `>>`: a dedented Python body is a syntax error, and its tree gives indent 0. Rung 2: exit criterion "`=` indents".
  - Hop on `--live` waits for floats to close before `f`: before Deploy, mason-tool-installer's offline `tree-sitter-cli` notifications cover the hint line. Rung 6; documented in treesitter.md and live-environment.md.
- Not fixed (out of scope, recorded): plugin-side `client.request is deprecated` in `:messages` (a warning, not an error; doctor `messages ok`). A CursorHold `open_float` "Invalid 'width'" error appeared once, only in the void first live sweep (`$P9/after-live-try1.txt`, where my script pressed non-journey keys). The same width code is in 0.11.5's `lsp/util.lua`, and no clean journey reproduced it.
- Deploy runbook re-checked against the final code: a headless start of the landed config has Mason's `tree-sitter` on PATH and `mason-registry` loadable (seeded run `1104-115936-2706920`, the premise of D5/D6). A D6 install racing the config's own startup install waits on `installing[lang]` (`install.lua`) and is asserted after. D7's `replaced_from_seed` stays empty once D4 has written the seed lock entries. No runbook change needed.
- verdict: pass (verified-after-fix: the seed parser step and two journey key sequences were fixed during the phase; every journey passed after that)
