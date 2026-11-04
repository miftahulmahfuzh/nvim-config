# Format and check on save

## Sub-features

- Lua: `BufWritePre *.lua` runs `silent %!stylua -` (custom-autocmd.lua:249-258), with stylua from Mason.
- Go: go.nvim's `BufWritePre *.go` runs `require("go.format").gofmt()` with `gofmt = "gofumpt"`.
- Python: `BufWritePre *.py` compiles a temp copy with `py_compile` and publishes diagnostics in
  the `python_syntax_errors` namespace (no formatting).
- `jk` in insert mode = `<Esc>:write<CR>`; `,w` = `:update`.

## How to get to it (user POV)

Edit a `.lua`/`.go`/`.py` file and save (`:w`, `,w`, or `jk` from insert mode).

## Driving it with verify.sh

Lua, valid code (formatted on save):

```sh
$V keys RUN : e Space sample.lua Enter
$V keys RUN G O; $V keys RUN --paste 'local   z   =   1'; $V keys RUN Escape Escape
$V keys RUN : w Enter
$V cli RUN git diff sample.lua
```

End state seen: tabs for indentation, `function M.sum(a, b)` split over three lines, `+local z = 1`.

Lua, a syntax error on line 1 (**data loss on the base**):

```sh
$V cli RUN git checkout -- sample.lua
$V sync RUN                                  # fresh nvim: no stale prompts
$V keys RUN : e Space sample.lua Enter
$V keys RUN g g O; $V keys RUN --paste 'local x = = 1'; $V keys RUN Escape Escape
$V keys RUN : w Enter
$V cli RUN sh -c 'wc -l < sample.lua; head -1 sample.lua'
```

End state seen: `3` lines, `error: could not format from stdin: failed to format from stdin:
error parsing:`. `:messages` has `"sample.lua" 3L, 230B written`. The 11-line file is gone. With
the error further down (the cursor below line 3), the callback's `nvim_win_set_cursor` raises
`Cursor position outside buffer`, the write aborts, and the *buffer* holds the error text instead
(the next successful save writes it). Saving that again grows it (371 lines seen).

Go:

```sh
$V keys RUN : e Space main.go Enter; $V keys RUN 6 G A Space Escape; $V keys RUN : w Enter
$V cli RUN git diff main.go
```

End state seen: `-	var x = a+b` / `+	x := a + b`, `+	fmt.Println(add(1, 2))`. `:messages`
shows the file written twice (go.nvim rewrites after formatting).

Python:

```sh
$V keys RUN : e Space app.py Enter; $V keys RUN G o; $V keys RUN --paste 'def broken(:'
$V keys RUN Escape Escape; $V keys RUN : w Enter
$V lua RUN 'vim.tbl_map(function(d) return d.source .. "@" .. (d.lnum+1) .. ": " .. d.message end, vim.diagnostic.get(0, {namespace = vim.api.nvim_create_namespace("python_syntax_errors")}))'
```

End state seen: `{ "Python Syntax@6: invalid syntax" }`; the file is saved as typed.

## Gotchas

- Product finding (base, also live `d7bf9fe`): `vim.cmd("silent %!stylua -")` ignores stylua's
  exit status, and nvim's filter puts stderr into the buffer. Any Lua syntax error at save time
  replaces the buffer (and, when the cursor restore does not throw, the file) with stylua's error.
  Fix direction: run `vim.system({"stylua", "-"}, {stdin = ...})` and only replace lines on
  exit 0.
- A line after `return M` is a syntax error too ("return must be last"): add test lines above it.
- Type text with `--paste`: typed `jk` would save, and blink's menu eats the first Escape.
- Reset between journeys with `$V cli RUN git checkout -- FILE` and `:e!` or `sync`; a "file
  changed since reading" y/n prompt otherwise eats the next keys.
