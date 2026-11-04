# Editing mappings

## Sub-features

- `H` (visual): prettify the selected JSON through `jq` (handles escaped JSON too).
- `<C-o>` (normal): open the file path nearest the cursor on the current line (paths with `/`,
  or bare names with a known extension), trying cwd, the file's dir and `findfile`.
- `K` (visual): open the selected text as a path in a new tab. `,r`/`,R`: replace word/selection.
- `jk` save, `,w` update, `,q` `:x`, `\d` delete buffer, `<space>o`/`<space>O` blank lines.

## How to get to it (user POV)

Select a JSON line with `V` and press `H`; put the cursor on a path in prose and press `Ctrl-o`.

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

## Gotchas

- `H` needs `jq` on PATH; the run's PATH includes jq's directory (and fzf, rg, ctags).
- `,r`/`,R` prompt with `input()`: RPC (`lua`, `wait`) blocks until the prompt is answered, so
  drive the whole prompt with `keys` before reading state. Not proven here.
- `<C-o>` replaces the built-in jump-back (`<C-o>` in the jumplist) in normal mode.
