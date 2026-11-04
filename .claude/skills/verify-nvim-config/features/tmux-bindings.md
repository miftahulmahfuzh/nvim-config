# tmux bindings

## Sub-features

- oh-my-tmux (`.tmux.conf`, a vendored copy; `--live` uses the one `~/.tmux.conf` points at)
  with the repo's `.tmux.conf.local`: prefix `C-b` (and `C-a` as prefix2), `-` split vertical,
  `_` split horizontal.
- `!` stock `break-pane` (pane into a new window of the same session).
- `@` break the pane into its **own new session** `brk_<pane#>_<pid>` and switch the client to
  it (`run-shell` with a placeholder window, killed after the break).
- True colour: `tmux_conf_24b_colour=true` makes oh-my-tmux's `_apply_24b` append
  `terminal-overrides ',*256col*:Tc'` at server start.
  - The client terminal (`xterm-256color` outside tmux) then gets `setrgbb`/`setrgbf`, so nvim's
    `termguicolors` colours reach the screen as 24-bit.
  - With `auto`, oh-my-tmux only did that when `COLORTERM` was `truecolor`/`24bit` or
    `tput colors` printed 16777216. The owner's terminal sets neither, so tmux downsampled every
    colour to 256 and `:checkhealth vim.health` warned "True color support could not be detected".

## How to get to it (user POV)

In tmux: `C-b -` to split, then `C-b @` (own session) or `C-b !` (own window).
True colour: start a new tmux server, open nvim and run `:checkhealth vim.health`. Its `tmux`
section has no true-colour warning. A server that is already running keeps its old config until
it restarts.

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

True colour (a tmux config change needs `down` + `up`, never `sync`). nvim reads the run's own
server through its `$TMUX`:

```sh
$V up                        # or --live: the owner's oh-my-tmux with the checkout's .tmux.conf.local
$V lua RUN 'vim.trim(vim.fn.system({ "tmux", "show-options", "-gv", "terminal-overrides" }))'   # *256col*:Tc
$V lua RUN '#vim.tbl_filter(function(l) return l:find(" setrgb[bf]: %(string%)") ~= nil end, vim.split(vim.fn.system({ "tmux", "show-messages", "-T" }), "\n"))'   # 2
$V keys RUN : checkhealth Space vim.health Enter
$V wait RUN 'vim.bo.filetype' checkhealth 30
$V lua RUN 'vim.fn.search("True color support could not be detected", "nw")'   # 0
```

End states seen (2026-11-04, nvim-0-12-clean phase 4): `*256col*:Tc`, `2`, `0`, seeded
`1104-135818-3827299` and `--live` `1104-135407-3589592`. On the base (`tmux_conf_24b_colour=auto`,
seeded `1104-140108-3948797`, `--live` `1104-140129-3953555`) they were empty, `0` and `32` (the
warning's line in the report).

## Gotchas

- `keys` types into nvim's pane; it never triggers tmux bindings. Use `tmux` for prefix keys.
- tmux config edits need `down` + `up`: the server keeps its config, and `sync` restarts only
  nvim.
- oh-my-tmux's `_apply_configuration` runs at server start, inside the namespace. Its plugin
  update (`tmux_conf_update_plugins_on_launch=true`) has no `@plugin` to fetch and no network.
- `_apply_24b` runs while the config loads, with the starting client's `TERM`
  (`xterm-256color` in a run). The `screen-*|tmux-*` case that skips the override never applies.
- The owner's tmux server (`/tmp/tmux-1000/default`) is never contacted:
  - Every call passes `-S <run>/tmux.sock`, and the run's processes have their own `TMUX`.
  - Deploy only copies `~/.tmux.conf.local`. It takes effect when the owner next starts a server.
