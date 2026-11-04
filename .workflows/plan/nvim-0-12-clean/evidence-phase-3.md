# Evidence: phase 3 (blink.cmp v1, git-conflict fork)

Worktree `feature/nvim-0-12-clean` @ `d90b730` + this phase's edits; nvim 0.12.6; seed lock before:
`~/.local/state/nvim-config-verify/seed-lock.before-nvim-0-12-clean-phase-3.json`.
Evidence dirs are `~/.local/state/nvim-config-verify/<run>/evidence/`.

| Journey | Mode | Before (run / evidence) | After (run / evidence) | Result |
|---|---|---|---|---|
| B1/A1 completion lua: deprecation on screen + probe | live | `1104-132435-3158849` `02-keys-G_o.txt` (last line `client.request is deprecated…`), `21-lua-…featu.txt` (`1`, client.request); recipe-equal before `1104-133804-3361630` `04-screen-completion-lua.txt`, `24-lua-…featu.txt` | `1104-133718-3342035` `04-screen-completion-lua.txt` (no deprecation line), `24-lua-…featu.txt` (`1`: go.nvim codelens only) | pass (no blink/git-conflict line; go.nvim line handed to phase 4) |
| B1/A1 completion lua: deprecation on screen + probe | seeded | `1104-132438-3160384` `02-keys-G_o.txt`, `21-lua-…featu.txt` (`1`, client.request) | `1104-133721-3343691` `04-screen-completion-lua.txt`, `24-lua-…featu.txt` (`1`: go.nvim codelens only) | pass (same) |
| A1 completion go/python, keymaps (Esc stays in insert, Tab+Enter accept) | live / seeded | live `1104-133804-3361630` `06-lua-…` `false i`, `10-lua-…` `true`; first-recipe runs derailed (see notes) | `1104-133718-3342035` / `1104-133721-3343691`: `06-lua-…` `false i`, `10-lua-…` `true`, `LOG.md` waits ok for gopls/pyright menus and `mode() == n` | pass |
| B2/A2 `:checkhealth vim.deprecated` | live | `1104-132435-3158849` `28-lua-…` (4: client.request, vim.highlight, go.nvim codelens, vim.validate{} from `git-conflict/colors.lua:12`) | `1104-133718-3342035` `31-lua-…` (2: go.nvim codelens, glance.nvim vim.validate{}; 0 lines naming blink or git-conflict) | pass for R2/R4; 2 other-plugin warnings handed to phase 4 |
| B2/A2 `:checkhealth vim.deprecated` | seeded | `1104-132438-3160384` `28-lua-…` (same 4) | `1104-133721-3343691` `31-lua-…` (same 2) | same |
| A3 `:checkhealth blink.cmp` + `implementation_type` + version | live / seeded | `1104-132435-3158849` `22-lua-…` `rust`, `23-lua-…` `485c034… v0.14.2` (live cargo build); `1104-132438-3160384` `v0.14.2 v0.14.2` | `1104-133718-3342035` / `1104-133721-3343691`: `25-lua-…` `rust`, `26-lua-…` `v1.10.2 v1.10.2`, `28-lua-…` `OK blink_cmp_fuzzy lib is downloaded/built`, no `Cmdline sources` | pass |
| B3/A4 `:e sam<Tab>` command line | live / seeded | `1104-132435-3158849` `31-screen-cmdline-tab.txt`, `1104-132438-3160384` `31-screen-cmdline-tab.txt`, `1104-133804-3361630` `34-screen-cmdline-tab.txt`: `:e sam^I` | `1104-133718-3342035` / `1104-133721-3343691` `34-screen-cmdline-tab.txt` `:e sam^I`, `35-lua-…` `false e sam<tab>` | unchanged (invariant 5); the plan's expected `:e sample.lua` was never true, finding handed to phase 4 |
| B4/A5 git-conflict journey (co, ]x, ct, ListQf, Resolved refresh) | live / seeded | `1104-132441-3164010` / `1104-132444-3165892`: `03-lua-…maparg` `<Plug>(git-conflict-ours) …`, `08-lua-…` `true`, `12-cli-cat_conflict_a.txt.txt`, `13-lua-…featu.txt` `0` | `1104-133102-3257898` / `1104-133105-3259740`: `15-lua-…maparg`, `20-lua-…` `true`, `24-cli-cat_conflict_a.txt.txt` (`top ours`, `keep 1`…`keep 8`, `bottom theirs`), `25-lua-…featu.txt` `0`; QF waits ok in `LOG.md` | pass |
| A0 rule, before the seed bump | live | — | `1104-133014-3237199` meta `replaced_from_seed=` (empty); rule sanity on a scratch repo: `0` / `1` / `128` | pass |
| A6 `replaced_from_seed` | live | `1104-132435-3158849` meta `replaced_from_seed=` (empty: old rule kept live v0.14.2) | `1104-133718-3342035` meta `replaced_from_seed=blink.cmp git-conflict.nvim`, `00-up-replaced.txt` (`blink.cmp: live main@485c0340 … -> seed main@78336bc …`, `git-conflict.nvim: live main@4bbfdd9 …akinsho… -> seed main@63c5b42 …stryukovsky…`) | pass |
| Seed | — | — | `~/.local/state/nvim-config-verify/.seed/seed.log`: `MOVED plugin git-conflict.nvim: url …akinsho… -> …stryukovsky…; not pinned to the lock's main@4bbfdd9, follows the spec: main@63c5b42`, `info blink.cmp fuzzy library v1.10.2 (downloaded)`, `ok   blink.cmp fuzzy library`, `done`, no `FAIL`; lock lines and `version`/`describe` = `v1.10.2`, git-conflict HEAD `63c5b42…` | pass |
| Neighbor: git.md fugitive commit + push | live / seeded | — | `1104-133102-3257898` remote `3bac284 verify: commit through fugitive`; `1104-133105-3259740` remote `bc7b004 verify: commit through fugitive` | pass |
| Neighbor: startup `:messages` + doctor | live / seeded | all before runs: doctor exit 0, `messages ok` | all after runs: `00-up-messages.txt` 0 lines, doctor exit 0 (incl. `path ok`) before and after driving | pass |

Notes:
- The plan's completion recipe (typing `vim.`, and `Escape Escape` in one `keys` call) derailed on both
  v0.14.2 (`1104-132435-3158849`, `1104-132438-3160384`) and v1.10.2 (`1104-133055-3252529`,
  `1104-133058-3253957`). Cause 1: lua_ls in WORK has no `vim` library, so `vim.` gets plain words and no menu.
  Cause 2: two Escapes in one send both arrive while blink's menu is open, so insert mode stays on and the next
  `:e app.py` is typed into main.go (measured in `1104-133531-3322399`: separate calls give `false i` then
  `false n`). The recipe in `features/lsp.md` types `vim.p` and sends each Escape on its own. Assertions are the
  same.
- Hidden by the base, surfaced by this phase: go.nvim `vim.lsp.codelens.refresh({ bufnr = bufnr})`
  (`go/codelens.lua:59`) and glance.nvim `vim.validate{<table>}` (`glance/init.lua:367`). nvim reports each
  deprecated name once. Out of this phase's two plugins; for phase 4's sweep.
