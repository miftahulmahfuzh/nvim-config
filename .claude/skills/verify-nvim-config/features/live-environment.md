# Live environment

## Sub-features

- `up --live`: the checkout's config on a **copy** of the owner's live plugins
  (`~/.local/share/nvim/lazy`), Mason tools, lock (`~/.config/nvim/lazy-lock.json`), cached
  dashboard art and oh-my-tmux, in the same fenced run.
- `live [RUN]`: read-only drift report between `~/.config/nvim` and this checkout, and the deploy
  command the owner would run.

## How to get to it (user POV)

The owner deploys with `git -C ~/.config/nvim fetch origin &&
git -C ~/.config/nvim merge --ff-only origin/main` (plain `git pull` fails in that checkout:
"Cannot fast-forward to multiple branches") and restarts nvim. These two commands answer "what
will that change, and will it work on my machine?" first.

## Driving it with verify.sh

```sh
$V live                      # or: $V live RUN (saved into that run's evidence)
$V up --live                 # MODE=live, ~7 s
$V doctor RUN                # live ok ... unchanged since up; live info live checkout @ 9cea538, ... replaced from seed (spec moved): blink.cmp git-conflict.nvim
$V lua RUN @.claude/skills/verify-nvim-config/features/lua/noise.lua   # noise=0 known=0
```

End state seen with `live` (2026-11-04, before Deploy):
- Live `9cea538`; the checkout is `feature/nvim-0-12-clean` with this set's commits, which
  the live checkout lacks (8 at phase 3's tip `7635778`). Live has none that the checkout lacks.
- The files that differ are the set's: `lua/plugin_specs.lua`, `lua/config/blink-cmp.lua`,
  `lua/config/nvim-tree.lua`, `lua/config/fidget-nvim.lua`, `lua/diagnostic-conf.lua`,
  `.tmux.conf.local`, plus `.workflows/`.
- `~/.tmux.conf.local DIFFERS from checkout's`: the checkout sets `tmux_conf_24b_colour=true`.
- The last line is the deploy command.

Before Deploy, `replaced_from_seed` is exactly `blink.cmp git-conflict.nvim`:
- blink.cmp because the seed lock pins `78336bc` (v1.10.2), which is not live HEAD (`485c034`,
  v0.14.2) or an ancestor of it.
- git-conflict.nvim because the seed dir's `origin` is
  `https://github.com/stryukovsky/git-conflict.nvim.git` and the live dir's is `akinsho`'s.

`evidence/00-up-replaced.txt` shows live's and the seed's branch, commit and url for both. It has
no `+ site/...` line, because `PLUGIN_EXTRA_DATA` names nothing for them. blink's prebuilt fuzzy
library (`target/release/libblink_cmp_fuzzy.so`, its `.sha256` and `version`) comes with the
seed's plugin dir. `filled_from_seed` is empty (phase 4 sweep: run `1104-135407-3589592`, `live-1104-135401.txt`).

After Deploy (the runbook in `.workflows/plan/nvim-0-12-clean/phase-4.md`):
- `replaced_from_seed` and `filled_from_seed` are empty, and there is no `00-up-replaced.txt`.
- `live` reports `commits in the checkout that live lacks (0)` and
  `~/.tmux.conf.local == checkout's`.

On `--live`, every journey in this directory gave the same end state as seeded, and `noise.lua`
printed `noise=0` after each (health.md). The full `:checkhealth` minus the allow-list was empty,
both with gopls attached and with every plugin loaded. No file in the run's Mason copy still named
`~/.local/share/nvim` (`grep -rIlF "$HOME/.local/share/nvim" <run>/xdg/data/nvim/mason` printed 0).

## Gotchas

- Always read-only:
  - `--live` copies with `cp -a`, never hard links, because the owner's files are writable.
  - `live` uses `git --no-optional-locks` so `git status` cannot refresh the live index.
  - `doctor`/`down` compare a fingerprint of the live config, plugin and Mason dirs and the tmux
    files; `down` writes `live-at-down.txt`.
- Only `lazy/`, `mason/`, `site/` (treesitter parsers and query links) and `rplugin.vim` are
  copied. `avante/`, `backup/` and `telescope_history` in `~/.local/share/nvim` are private state
  and stay where they are.
- A live plugin is replaced from the seed (`replaced_from_seed`, details in
  `evidence/00-up-replaced.txt`) when the seed moved it in one of these ways:
  - another branch or remote than the live lock/dir;
  - a seed lock commit that the live checkout does not contain, neither as HEAD nor as an ancestor
    (a bump written into the seed lock). This is `live_lacks_seed_commit` in `verify.sh`. A live
    clone that merely has the object, as blink.cmp's had, still counts as moved.

  A replaced plugin brings its seed lock entry and whatever `PLUGIN_EXTRA_DATA` in `verify.sh`
  names for it (nvim-treesitter: `site/parser`, `site/parser-info`, `site/queries`).
- A plugin the checkout adds is not in the live dirs: it comes from the seed and is listed in
  `filled_from_seed` (run `seed` first). Live nvim would fetch it online on its next start.
- `--live` uses the owner's oh-my-tmux (`~/.tmux.conf` → `~/.tmux/.tmux.conf`) with the
  **checkout's** `.tmux.conf.local`, so a run already has true colour before Deploy. The owner's own
  tmux gets it after Deploy D4 copies the file and the owner starts a new server.
- Deploying (fetch + `merge --ff-only origin/main` in `~/.config/nvim`) is the owner's step, or
  the Deploy runbook's. verify never runs it.
