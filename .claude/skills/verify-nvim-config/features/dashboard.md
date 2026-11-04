# Dashboard / ASCII art

## Sub-features

- Start screen (`config/dashboard-nvim.lua`): with no file argument, one of `ascii_art/*.txt`,
  centred. The name lives in `stdpath("cache")/dashboard_ascii_art.txt` (default `eyes`).
- `,b` opens the art in a right split; `,bg` cycles to the next art; `,bv` picks one with
  `vim.ui.select` (snacks picker); `,bh` jumps to `bikini`. Buffer-local `q` quits, `e` new buffer,
  `<space>s` toggles nvim-tree.
- A change of art redraws **every window that shows a dashboard buffer** (start screen, split,
  a dashboard behind an nvim-tree window), in every tab, and leaves the cursor where it was. A
  window the user moved to another buffer is never touched.

## How to get to it (user POV)

Start `nvim` with no file. Press `,b` from any buffer for the split; `,bg` / `,bv` / `,bh` to
change art.

## Driving it with verify.sh

The probe names the art each visible dashboard window shows (by content) and the saved name.
`S` is the `saved=` the probe printed just before a block (right after `up`: seeded `(none)`, which
means `eyes`; live: the owner's cache), `S+1` the next name alphabetically. Each block below starts
from a fresh `up`.

Start screen (seeded names; on `--live` read them as `S`, `S+1`):

```sh
P=.claude/skills/verify-nvim-config/features/lua/dashboard_art.lua
$V up
$V lua RUN @$P                      # shown=eyes saved=(none)
$V keys RUN , b g                   # notification "Switched to: family_guy_1"
$V lua RUN @$P                      # shown=family_guy_1 saved=family_guy_1
$V keys RUN , b h
$V lua RUN @$P                      # shown=bikini saved=bikini
$V keys RUN , b v; $V keys RUN -l skull; $V keys RUN Enter
$V lua RUN @$P                      # shown=skull saved=skull
$V lua RUN 'vim.bo.filetype'        # dashboard (the cursor stayed on the start screen)
```

Dashboard behind another window (nvim-tree focused):

```sh
$V up
$V lua RUN @$P                      # shown=S saved=S
$V keys RUN Space s                 # buffer-local <space>s: nvim-tree opens and takes focus
$V keys RUN , b g
$V lua RUN @$P                      # shown=S+1 saved=S+1
$V lua RUN 'vim.bo.filetype'        # NvimTree (focus not moved)
```

Leaving the dashboard, then the split:

```sh
# last field: non-floating windows (the "Switched to:" notification is a float)
W='vim.bo.filetype .. "|" .. vim.bo.buftype .. "|" .. vim.api.nvim_buf_line_count(0) .. "|" .. #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == "" end, vim.api.nvim_tabpage_list_wins(0))'
$V up
$V lua RUN @$P                      # shown=S saved=S
$V keys RUN e                       # leave the start screen (buffer-local e = :enew)
$V keys RUN , b g
$V lua RUN @$P                      # shown=(no dashboard window) saved=S+1
$V lua RUN "$W"                     # ||1|1   the empty buffer stays empty
$V keys RUN , b                     # art in a right split
$V keys RUN , b g
$V lua RUN @$P                      # shown=S+2 saved=S+2
$V keys RUN e                       # the split leaves the dashboard
$V keys RUN , b g
$V lua RUN @$P                      # shown=(no dashboard window) saved=S+3
$V lua RUN "$W"                     # ||1|2   the split was not taken back
```

Picker with a fresh art: see img2braille.md (`saved=verify_art`).

## Gotchas

- Consumes: the cache file. Each `,bg` moves to the next name alphabetically from the current one,
  so expected names depend on the order you drove things in. Read `saved=` first.
- Moving the cursor from a dashboard window to a normal window wipes that dashboard (the
  `BufLeave` cleanup), which closes the split. Only nvim-tree, quickfix and vista keep it. So a
  "split behind the editing window" does not survive `C-w h`; drive `,bg` from inside the split,
  or from nvim-tree.
- `,b` on the start screen itself ends with one window: the new split's `BufLeave` wipes the start
  screen's buffer and its window closes. Press `e` first, as above.
- Braille blank cells (U+2800) are not whitespace, so compare whole art files (the probe does).
  First lines alone collide.
- Before phase 3 of fix-bugs-nvim-0-12 the start screen kept the old art until restart
  (`shown=S saved=S+1`), and `,bg` after `e` in the split put the art back into that window.
