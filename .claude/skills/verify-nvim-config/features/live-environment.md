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
$V doctor RUN                # live ok ... unchanged since up; live info live checkout @ a14aef9, ... replaced from seed (spec moved): ...
```

End state seen (`live`, 2026-11-04): live `a14aef9`, checkout `43009df` (plus phase 9's
uncommitted change), 34 commits the live checkout lacks (this set), the files that differ
(`after/lsp/pyright.lua`, `init.lua`, `README.md`, `lua/colorschemes.lua`,
`lua/config/{dashboard-nvim,fzf-lua,treesitter,treesitter-textobjects}.lua`,
`lua/custom-autocmd.lua`, `lua/plugin_specs.lua`, `lua/custom/opencode.lua` only in live, plus
`docs/plans` and `.workflows/`), `~/.tmux.conf.local == checkout's`, and the last line
`deploy (the owner's step, never run by verify): git -C /home/miftah/.config/nvim fetch origin && git -C /home/miftah/.config/nvim merge --ff-only origin/main`.

On `--live` with Neovim 0.12.6 (`VERIFY_NVIM`), every journey in this directory gave the same end
state as seeded: lua_ls, gopls and pyright attach; a Lua syntax error leaves `sample.lua` intact with
a warning; `vaf`/`gnn` select through nvim-treesitter `main`; `,bg` redraws the start screen; `f`
shows hop hints. Before the owner deploys, `replaced_from_seed` lists `go.nvim hop.nvim
nvim-treesitter nvim-treesitter-textobjects`, `evidence/00-up-replaced.txt` adds `+ site/parser`,
`+ site/parser-info` and `+ site/queries` under nvim-treesitter, and nvim-notify shows
`tree-sitter-cli: installing` / `failed to install` at start (live Mason has no tree-sitter CLI and
the run is offline; see treesitter.md). No file in the run's Mason copy still named
`~/.local/share/nvim` (`grep -rIlF "$HOME/.local/share/nvim" <run>/xdg/data/nvim/mason`
printed 0).

## Gotchas

- Read only, always: `--live` copies with `cp -a` (never hard links, because the owner's files
  are writable); `live` uses `git --no-optional-locks` so `git status` cannot refresh the live
  index. `doctor`/`down` compare a fingerprint of the live config, plugin and Mason dirs and the
  tmux files; `down` writes `live-at-down.txt`.
- Only `lazy/`, `mason/`, `site/` (treesitter parsers and query links) and `rplugin.vim` are
  copied. `avante/`, `backup/`, `telescope_history` in `~/.local/share/nvim` are private state and
  stay where they are.
- A live plugin is replaced from the seed (`replaced_from_seed`, details in
  `evidence/00-up-replaced.txt`) when the seed moved it: another branch or remote than the live
  lock/dir, or a commit the live clone has never fetched (a bump written into the seed lock). A
  replaced plugin brings its seed lock entry and whatever `PLUGIN_EXTRA_DATA` in `verify.sh` names
  for it (nvim-treesitter: `site/parser`, `site/parser-info`, `site/queries`).
- A plugin the checkout adds is not in the live dirs: it comes from the seed and is listed in
  `filled_from_seed` (run `seed` first). Live nvim would fetch it online on its next start.
- Deploying (fetch + `merge --ff-only origin/main` in `~/.config/nvim`) is the owner's step.
  verify never runs it.
