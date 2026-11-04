# Live environment

## Sub-features

- `up --live`: the checkout's config on a **copy** of the owner's live plugins
  (`~/.local/share/nvim/lazy`), Mason tools, lock (`~/.config/nvim/lazy-lock.json`), cached
  dashboard art and oh-my-tmux, in the same fenced run.
- `live [RUN]`: read-only drift report between `~/.config/nvim` and this checkout, and the deploy
  command the owner would run.

## How to get to it (user POV)

The owner deploys with `git -C ~/.config/nvim pull --ff-only` and restarts nvim. These two
commands answer "what will that change, and will it work on my machine?" first.

## Driving it with verify.sh

```sh
$V live                      # or: $V live RUN (saved into that run's evidence)
$V up --live                 # MODE=live, ~7 s
$V doctor RUN                # live ok ... unchanged since up; live info live checkout @ d7bf9fe
```

End state seen (`live`): live `d7bf9fe`, checkout `24ff768`, 4 commits the live checkout lacks
(all tmux), one differing file (`.tmux.conf.local`), and `~/.tmux.conf.local == checkout's`
(the owner's real tmux file is already current; only the nvim clone is behind).

On `--live`, the journeys in lsp.md and format-on-save.md gave the same end states as seeded
(lua_ls attaches, pyright 0 clients, stylua error text written over `sample.lua`), and no file
in the run's Mason copy still named `~/.local/share/nvim`
(`grep -rIlF "$HOME/.local/share/nvim" <run>/xdg/data/nvim/mason` printed 0).

## Gotchas

- Read only, always: `--live` copies with `cp -a` (never hard links, because the owner's files
  are writable); `live` uses `git --no-optional-locks` so `git status` cannot refresh the live
  index. `doctor`/`down` compare a fingerprint of the live config, plugin and Mason dirs and the
  tmux files; `down` writes `live-at-down.txt`.
- Only `lazy/`, `mason/` and `rplugin.vim` are copied. `avante/`, `backup/`, `telescope_history`
  in `~/.local/share/nvim` are private state and stay where they are.
- A plugin the checkout adds is not in the live dirs: it comes from the seed and is listed in
  `filled_from_seed` (run `seed` first). Live nvim would fetch it online on its next start.
- Deploying (pulling into `~/.config/nvim`) is the owner's step. verify never runs it.
