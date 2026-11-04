# tmux bindings

## Sub-features

- oh-my-tmux (`.tmux.conf`, a vendored copy; `--live` uses the one `~/.tmux.conf` points at)
  with the repo's `.tmux.conf.local`: prefix `C-b` (and `C-a` as prefix2), `-` split vertical,
  `_` split horizontal.
- `!` stock `break-pane` (pane into a new window of the same session).
- `@` break the pane into its **own new session** `brk_<pane#>_<pid>` and switch the client to
  it (`run-shell` with a placeholder window, killed after the break).

## How to get to it (user POV)

In tmux: `C-b -` to split, then `C-b @` (own session) or `C-b !` (own window).

## Driving it with verify.sh

`tmux` presses keys on the run's attached client (`send-keys -K`), as a person would:

```sh
$V panes RUN                 # main:1.1 %0 cmd=nvim; client on main 160x45
$V tmux RUN C-b -            # main:1.2 %1 cmd=bash, client on main:1.2
$V tmux RUN C-b @            # brk_1_<pid>:1.1 %1 bash; main:1.1 %0 nvim; client on brk_1_<pid>:1.1
$V tmux RUN C-b -            # brk_1_<pid>:1.2 %3
$V tmux RUN C-b !            # brk_1_<pid>:2.1 %3 (new window, same session)
$V doctor RUN                # tmuxconf ok: ~/.tmux.conf.local not rewritten by self-heal
```

End states seen exactly as in the comments, with no `__ph` placeholder window left.

## Gotchas

- `keys` types into nvim's pane; it never triggers tmux bindings. Use `tmux` for prefix keys.
- tmux config edits need `down` + `up` (the server keeps its config; `sync` restarts only nvim).
- oh-my-tmux's `_apply_configuration` runs at server start in the namespace. Its plugin update
  (`tmux_conf_update_plugins_on_launch=true`) has no `@plugin` to fetch and no network.
- The owner's tmux server (`/tmp/tmux-1000/default`) is never contacted: every call passes `-S
  <run>/tmux.sock`, and the run's processes have their own `TMUX`.
