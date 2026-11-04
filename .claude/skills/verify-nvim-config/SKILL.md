---
name: verify-nvim-config
description: Prove a change to this Neovim config (Lua + lazy.nvim + Mason) or its tmux config by driving a real nvim inside a real tmux, with evidence, against either the verify seed or a copy of the owner's LIVE environment (~/.config/nvim's lock, ~/.local/share/nvim's plugins and Mason tools, the oh-my-tmux ~/.tmux.conf points at). Use after editing init.lua, lua/, plugin/, after/, viml_conf/, ascii_art/, scripts/ or .tmux.conf(.local), before deploying to ~/.config/nvim, and whenever a plan's Proof section names verify-nvim-config. Every run has its own XDG dirs, HOME, tmux socket and network namespace. It never writes the owner's ~/.config/nvim, ~/.local/share/nvim, ~/.local/state/nvim, ~/.cache/nvim or tmux server, never pushes to a real remote, never logs into anything.
---

# verify-nvim-config

"The app" is Neovim started with this checkout's config, as the owner uses it: inside tmux,
editing files, pressing mappings. A run is a throwaway tmux server (this repo's `.tmux.conf` +
`.tmux.conf.local`) whose first pane runs `nvim`, a pty client attached to it (so tmux prefix
bindings can be pressed), and a fixture project (`WORK`) for nvim to edit. Everything the run
starts lives in its own network namespace: no route anywhere.

The owner's **live** config is a separate clone at `~/.config/nvim` (it lags this checkout until
the owner pulls). `up --live` drives the checkout's change on a copy of that live environment, and
`live` reports the drift between them. Prove a change on `--live` before telling the owner it is
safe to deploy.

The lever is one script. Never hand-write an `nvim` or `tmux` launch.

```sh
V=.claude/skills/verify-nvim-config/scripts/verify.sh   # from the repo root (any worktree)
```

## Launch

```sh
$V seed              # ONLINE, once per machine (and after adding a plugin/Mason tool): ~2 min
$V up --live         # the change on a copy of the owner's live plugins/Mason/lock/oh-my-tmux (~7 s)
$V up                # the change on the verify seed (hard-linked, ~1 s)
$V up --bare         # no plugins, no Mason: a fresh machine with no network (fault injection)
$V up --size 200x50  # terminal size (default 160x45)
```

`up` prints `RUN=`, `EVIDENCE=`, `WORK=` and `MODE=` (seeded / live / bare), and returns once nvim
answers on its socket, VimEnter ran and the VeryLazy plugins (fzf-lua) loaded. It snapshots the
**working tree** (uncommitted edits count; `.git`, `.claude`, `lazy-lock.json` excluded) into
the run's `XDG_CONFIG_HOME/nvim`. Startup `:messages` go to `evidence/00-up-messages.txt`, and
errors in them are printed. The start screen is `00-up-screen.txt`.

- **seed** (`$VERIFY_HOME/.seed`, 93 plugins + 13 treesitter parsers + 9 Mason packages, ~570 MB)
  is the only step that goes online: GitHub (lazy clones), the Mason registry, npm, PyPI and the Go
  proxy (Go may fetch a newer toolchain into the seed). The first seed starts from the owner's
  **live** `lazy-lock.json` and pins every plugin to it, even where lazy will not (see Gotchas).
  A plugin GitHub no longer serves is copied from the live dir. `seed --update` takes the latest
  of everything instead (what `:Lazy update` / a fresh install would get). Seed files are read-only.
  Runs hard-link them, and `doctor` fails if anything wrote through.
- **live** copies (never links) `~/.local/share/nvim/{lazy,mason,rplugin.vim}`, the live
  `lazy-lock.json`, the dashboard's cached art and the oh-my-tmux behind `~/.tmux.conf`. A plugin
  the change adds is not in the live dirs yet, so it is taken from the seed and listed as
  `filled_from_seed` (live nvim would fetch it online on its next start).

**Edited the config after `up`?** `$V sync RUN` re-snapshots and restarts nvim in the pane (as
the owner would, by restarting nvim). tmux config changes need `down` + `up`: the running server
keeps the config it started with.

## Doctor

Run `$V doctor RUN` before the first drive and after any surprise. It is read-only and exits 1
on any FAIL.

- `tmux` / `netns`: the run's server answers on its own socket and lives in its own network
  namespace (`netns` lists how many processes are inside).
- `nvim`: answers on `nvim-N.sock` and is ready. `stdpath`: config/data/state/cache are the run's.
- `code WARN`: the working tree changed since `up`/`sync`. `sync`.
- `egress`: `curl https://github.com` from inside the namespace fails (exit 6).
- `clipbrd`: the clipboard provider is `tmux`, i.e. the run's own server buffer.
- `git`: WORK's `origin` is the run's bare repo.
- `seed` (seeded runs): the shared seed is unchanged. `live` (live runs): the owner's live
  config/plugins/Mason/tmux fingerprint is unchanged since `up`. A WARN there means the owner used
  nvim meanwhile; the run itself never writes them.
- `tmuxconf`: oh-my-tmux did not rewrite the run's `~/.tmux.conf.local` (its "self-heal").
- `owner info`: the owner's tmux processes, only listed. `messages`: errors in `:messages`.

## Drive

| Command | Does | Evidence |
|---|---|---|
| `$V keys RUN KEY...` | `tmux send-keys` into nvim's pane (tmux key names: `Escape`, `Enter`, `C-o`, `Space`; `,` is the leader), waits for the screen to settle | `NN-keys-*.txt` (keys + screen), `.ansi` with colours |
| `$V keys RUN --paste TEXT` | Bracketed paste: how to put text into a buffer (no completion menu, no `jk`) | same |
| `$V tmux RUN KEY...` | Keys on the attached tmux **client** (`C-b @`): prefix bindings | `NN-tmux-*.txt` (every pane, where the client is) |
| `$V screen RUN [NAME]` | The visible pane | `NN-screen-*.txt` + `.ansi` |
| `$V lua RUN 'EXPR'` | Read state from the running nvim (expression, chunk with `return`, or `@probe.lua`) | `NN-lua-*.txt` |
| `$V wait RUN 'EXPR' VALUE [SECS]` | Poll until `tostring(EXPR) == VALUE` (default 30 s) | a line in `LOG.md` |
| `$V panes RUN` | tmux sessions, panes, clients | `NN-panes-state.txt` |
| `$V headless RUN [ARGS]` | One-shot `nvim --headless ARGS +qa!` with the run's config/data | `NN-headless-*.txt` |
| `$V cli RUN CMD...` | A command in the run's namespace, cwd WORK (`$CONFIG` = the run's config snapshot, `$WORK`) | `NN-cli-*.txt` |
| `$V live [RUN]` | Drift: live `~/.config/nvim` vs this checkout | `NN-live-drift.txt` |
| `$V note RUN "text"` | Append to `evidence/LOG.md` | |

Actions go through `keys`/`tmux` (the user's path), and `lua`/`wait`/`cli` read the result.
`lua` can technically run anything; never use it to *do* what the journey is proving. One example
per surface:

```sh
$V keys RUN : e Space sample.lua Enter          # open a fixture file
$V keys RUN g g O; $V keys RUN --paste 'local x = 1'; $V keys RUN Escape Escape
$V keys RUN : w Enter                            # BufWritePre hooks run here
$V cli RUN git diff sample.lua                   # the file on disk
$V lua RUN 'vim.lsp.get_clients({bufnr=0})[1].name'
$V tmux RUN C-b @                                # break the pane into its own session
$V lua RUN @.claude/skills/verify-nvim-config/features/lua/dashboard_art.lua
```

WORK (`features/fixtures/work/`) is a git repo with `sample.lua` (badly formatted), `main.go` +
`go.mod` (gofumpt-able), `app.py`, `data.json` (one line), `notes.md` (mentions
`docs/guide.txt`, `main.go`, `sample.lua`), and `origin` = a bare repo inside the run, tracked.

## Evidence

`~/.local/state/nvim-config-verify/<run>/evidence/`: outside the repo, kept after `down`,
numbered by drive order. `down` adds `messages-at-down.txt` and nvim's logs (`logs/lsp.log`,
`mason.log`, `log`).

- Drive the user's path: keys and mappings, not `lua` calls into the config's functions.
- Capture the action and the state after it: the file on disk (`cli git diff`), the LSP clients,
  the tmux panes, the cache file the dashboard writes.
- For a bug fix, show the failure first: drive the base, `git stash`, `sync`, drive again, `git
  stash pop`, `sync`. Keep both transcripts. Do it on `--live` when the bug was seen live.
- Before calling something "fine to deploy", drive it on `up --live` as well as `up`.
- A journey that could not be driven is `inconclusive`, with the reason. Never weaken it to pass.
- The colorscheme is random per start (`colorschemes.lua`). Never assert a colorscheme name.

## Cleanup

`$V down RUN` (or `down --all`) asks tmux to exit, then kills every process left in the run's
network namespace (that set is exactly what the run started), copies logs into evidence, and
deletes the run's XDG dirs, HOME, WORK and remote. `$V ls` shows the seed and every run.

## Feature map

`features/README.md` indexes one file per feature with proven recipes and the end states they
produced. A change to what the owner sees or does in nvim/tmux updates its entry in the same
change. Probes for `lua RUN @...` live in `features/lua/`.

## Gotchas

- **Never driven, no flag turns it on.** A `git push` to any real remote (WORK's only remote is
  the run's bare repo; `GIT_SSH_COMMAND=/bin/false`, no global git config, no credentials, and no
  network anyway). Writing `~/.config/nvim` (deploying is the owner's `git -C ~/.config/nvim
  fetch origin && git -C ~/.config/nvim merge --ff-only origin/main`, which `live` prints and
  never runs; plain `git pull` fails in that checkout with "Cannot fast-forward to multiple
  branches"). The owner's tmux server (`-L default`). AI or Copilot-style plugins: none in the
  spec; `~/.local/share/nvim/avante` and other leftovers are never copied. Clipboard: `+` goes to
  the run's tmux buffer, never the Windows clipboard (no `clip.exe` on the run's PATH, no
  DISPLAY).
- **No paid or messaging dependency** in the config, so there is no budget and no `--real` flag.
  If an AI plugin is added, classify it first: it would need the owner's login, so it is harmful.
- **Downloads are the seed's job.** Runs have no network at all (`unshare -n`). This is a real
  fence: raw sockets and native code are blocked too, not only proxied HTTP. At startup, in every
  mode, lazy's install of a missing plugin fails, and Mason's registry refresh and the config's
  unconditional `get_package("gofumpt"):install()` fail into `mason.log`. Mason stages installs,
  so the installed gofumpt stays.
- **lazy ignores a lock entry whose branch differs from the spec's.** The spec leaves
  `nvim-treesitter` unpinned, so lazy follows GitHub's default branch (`main`, the incompatible
  rewrite) while the live lock says `master`. The seed pins every plugin to the lock with `git
  checkout` and logs `pinned to the lock`. Treat `seed --update` as "what a fresh install gets".
- **`phaazon/hop.nvim` is gone from GitHub.** The seed copies it from the live dir and removes
  lazy's `hop.nvim.cloning` marker; a leftover marker makes lazy delete and re-clone on every start.
- **The owner's port**: nothing in this repo listens on TCP, and CLAUDE.md pins no port. nvim
  and tmux use unix sockets under the run dir only (`nvim-N.sock`, a new one per (re)start;
  `tmux.sock`), so runs never collide with the owner's sessions or each other.
- **Insert mode is fragile under `send-keys`.** blink.cmp maps `<Esc>` to `cancel` while its menu
  is open, so the first Escape stays in insert mode. Typed text triggers completion and
  insert-mode mappings (`jk` saves; `, . ! ? ; :` break undo). Use `--paste` for text and
  `Escape Escape` to leave insert mode. A prompt (y/n, "Press ENTER") eats the next keys: `screen`
  after any surprise. RPC (`lua`, `wait`) blocks while nvim waits on `input()`, and the call
  times out after 10 s.
- **zsh**: the Bash tool's shell is zsh. Quote `?`/`*`, never `echo ====` (`=` expands), and
  never pipe `seed` into `head`/`sed -n` (a SIGPIPE kills it before it locks the seed).
- **Mason's lua-language-server launcher names its install dir by absolute path**, and lua_ls
  writes `log/` and `meta/` beside its binary. `up` rewrites every text file under `mason/` that
  names the source data dir (seed or live) to the run's copy, as a new file, so runs never write
  into the seed or the owner's `~/.local/share/nvim`.
- **`--bare` starts without plugins, by design**: the lazy bootstrap clone fails (no network),
  `plugin_specs.lua` warns once (`lazy.nvim clone failed (git exit 128): plugins off until an online
  restart`) and returns, and the rest of `init.lua` loads with the builtin `habamax` colorscheme (the
  one run where asserting the name is valid). The warning is not an error: `up` prints nothing and
  `doctor` says `messages ok`. Any `E\d+:` on a bare start is a regression. `sync` cannot restart a
  bare run (it waits for fzf-lua): `down`, then `up --bare` again.
- **The live checkout may lag.** `live` lists the commits it lacks; a `--live` run still drives
  the checkout's config, on live's plugins.
- **Name clash check**: state lives in `~/.local/state/nvim-config-verify`; no sibling uses it.
