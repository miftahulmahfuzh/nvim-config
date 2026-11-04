# Dashboard / ASCII art

## Sub-features

- Start screen (`config/dashboard-nvim.lua`): with no file argument, one of `ascii_art/*.txt`,
  centred. The name lives in `stdpath("cache")/dashboard_ascii_art.txt` (default `eyes`).
- `,b` opens the art in a right split; `,bg` cycles to the next art; `,bv` picks one with
  `vim.ui.select` (snacks picker); `,bh` jumps to `bikini`. Buffer-local `q` quits, `e` new buffer.

## How to get to it (user POV)

Start `nvim` with no file. Press `,b` from any buffer for the split; `,bg` / `,bv` to change art.

## Driving it with verify.sh

The probe names the art each visible dashboard window shows (by content) and the saved name:

```sh
P=.claude/skills/verify-nvim-config/features/lua/dashboard_art.lua
$V up
$V lua RUN @$P                      # shown=eyes saved=(none)
$V keys RUN , b g                   # notification "Switched to: family_guy_1"
$V lua RUN @$P                      # shown=eyes saved=family_guy_1   <- start screen not redrawn
$V sync RUN                         # restart nvim
$V lua RUN @$P                      # shown=family_guy_1 saved=family_guy_1
```

Split view, where cycling redraws:

```sh
$V keys RUN e                       # leave the start screen (buffer-local e = :enew)
$V keys RUN , b                     # art in a right split
$V keys RUN , b g                   # "Switched to: family_guy_2"
$V lua RUN @$P                      # shown=family_guy_2 saved=family_guy_2
```

Picker: `$V keys RUN , b v`, then `$V keys RUN -l verify_art` and `$V keys RUN Enter`. That
gives `saved=verify_art` (see img2braille.md).

## Gotchas

- Product finding (base): on the **start screen** `,bg`/`,bv` save the new art and announce
  "Switched to: X", but the screen keeps the old art until the next start. `create_dashboard()`
  (no split) never sets `ascii_art_win`, and `update_ascii_art` only redraws when it is valid.
- Consumes: the cache file. Each `,bg` moves to the next name alphabetically from the saved one, so
  expected names depend on the order you drove things in. Read `saved=` first.
- Braille blank cells (U+2800) are not whitespace, so compare whole art files (the probe does).
  First lines alone collide.
