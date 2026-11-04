# Editing mappings

## Sub-features

- `H` (visual): prettify the selected JSON through `jq` (handles escaped JSON too).
- `<C-o>` (normal): open the file path nearest the cursor on the current line (paths with `/`,
  or bare names with a known extension), trying cwd, the file's dir and `findfile`.
- `K` (visual): open the selected text as a path in a new tab. `,r`/`,R`: replace word/selection.
- `jk` save, `,w` update, `,q` `:x`, `\d` delete buffer, `<space>o`/`<space>O` blank lines.
- `f` (normal, visual): hop.nvim (`smoka7/hop.nvim`) draws a one- or two-letter label over the
  first letter of every word in the visible windows; typing a label jumps there, `Escape`
  cancels. `F`: type a character, then a label for its occurrences before the cursor (a single
  occurrence jumps straight there). Replaces the built-in `f{char}`/`F{char}` motions.

## How to get to it (user POV)

Select a JSON line with `V` and press `H`; put the cursor on a path in prose and press `Ctrl-o`. Press `f`, read the label drawn over the word you want, type it.

## Driving it with verify.sh

```sh
$V keys RUN : e Space data.json Enter
$V keys RUN V H
$V lua RUN 'vim.api.nvim_buf_line_count(0) .. " lines | " .. table.concat(vim.api.nvim_buf_get_lines(0,0,4,false), " / ")'
```

End state seen: `11 lines | { /   "name": "verify", /   "tags": [ /     "nvim",`.

```sh
$V keys RUN : e Space notes.md Enter
$V keys RUN 3 G 0 w w                 # cursor on docs/guide.txt
$V keys RUN C-o                       # notification "Opened: docs/guide.txt"
$V lua RUN 'vim.fn.expand("%:.")'     # docs/guide.txt
$V keys RUN : e Space notes.md Enter
$V keys RUN 4 G 0
$V keys RUN C-o                       # "Opened: main.go" (nearest to column 1)
```

hop (`f` labels, jump, cancel; `F` with a unique character). `go.mod` has 7 words, so every label
is one letter (`sample.lua` has as many words as hop has label keys, so some labels get two
letters there):

```sh
$V keys RUN : e Space go.mod Enter
$V lua RUN 'vim.api.nvim_win_get_cursor(0)'      # { 1, 0 }
$V keys RUN f                                    # labels over every word
$V screen RUN f-hints
S=$(ls -t "$EVIDENCE"/*-screen-f-hints.txt | head -1)
L=$(awk 'NF >= 2 && $(NF-1) ~ /^[a-z]o$/ && $NF ~ /2$/ {print substr($(NF-1),1,1)}' "$S")   # the label over `go` (line 3)
$V keys RUN "$L"
$V lua RUN 'vim.api.nvim_win_get_cursor(0)'      # { 3, 0 }
$V keys RUN F /                                  # `/` occurs once before the cursor: no label, jumps
$V lua RUN 'vim.api.nvim_win_get_cursor(0)'      # { 1, 18 }
$V keys RUN f Escape                             # cancelled: the cursor stays at { 1, 18 }
```

End state seen on the base (`phaazon/hop.nvim@1a1ecea`, seeded, 2026-11-04): after `f` the
screen shows `eodule xxample.qom/pork` and `to o.v2` (label `t` over `go`); `t` -> `{ 3, 0 }`;
`F /` -> `{ 1, 18 }`; `f Escape` leaves `{ 1, 18 }`.
End state seen (`smoka7/hop.nvim@6e83486`, seeded and `--live`, 2026-11-04): after `f` the screen
shows `module example.tom/oork` and `vo x.q2` (label `v` over `go`); `v` -> `{ 3, 0 }`; `F /` ->
`{ 1, 18 }`; `f Escape` leaves `{ 1, 18 }`; no errors in `:messages`. On `sample.lua`, `f` overlays
`local M = {}` (`local e = {}`) and `Escape` restores it.

## Gotchas

- `H` needs `jq` on PATH; the run's PATH includes jq's directory (and fzf, rg, ctags).
- `,r`/`,R` prompt with `input()`: RPC (`lua`, `wait`) blocks until the prompt is answered, so
  drive the whole prompt with `keys` before reading state. Not proven here.
- `<C-o>` replaces the built-in jump-back (`<C-o>` in the jumplist) in normal mode.
- hop maps `f`/`F` on `VeryLazy`; `up` returns after VeryLazy, so they exist by then. Labels depend
  on hop's ordering and the words on screen: read the label from the screen, never hard-code it.
  An extracted label of `g` means no labels were drawn (`go` unchanged). RPC (`lua`, `wait`) while
  hop waits for a label: not tried; press the label or `Escape` first.
- On `--live` before the owner deploys, hop comes from the seed (`replaced_from_seed: hop.nvim`):
  the live dir still tracks the deleted `phaazon/hop.nvim`.
