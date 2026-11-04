# fzf-lua pickers

## Sub-features

- `,ff` files, `,fe` oldfiles, `,fg` live_grep, `,fh` helptags, `,fb` buffers, `,ft` tabs,
  `,m` grep the word/selection, `<C-f>` (insert) inserts ` @path .` for picked files.
- Actions: Enter edit, `ctrl-x` split, `ctrl-l` vsplit, `ctrl-t` tab. File icons from mini.icons.

## How to get to it (user POV)

Press `,ff`, type part of a name, Enter.

## Driving it with verify.sh

```sh
$V keys RUN , f f                     # floating "Files" picker, "7/7", preview of sample.lua
$V keys RUN -l guide
$V keys RUN Enter
$V wait RUN 'vim.fn.expand("%:.")' docs/guide.txt 10
```

End state seen: the picker listed `sample.lua data.json main.go go.mod notes.md app.py
docs/guide.txt`, and `wait ok: vim.fn.expand("%:.") == docs/guide.txt`.

## Gotchas

- Needs the `fzf` binary (`~/.fzf/bin` on this machine), which the run's PATH carries by directory.
- Inside the fzf terminal, typed keys go to fzf's prompt. `-l` is safe there; blink is not involved.
