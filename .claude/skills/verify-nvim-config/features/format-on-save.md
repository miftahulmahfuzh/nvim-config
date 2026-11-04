# Format and check on save

## Sub-features

- Lua: `BufWritePre *.lua` (custom-autocmd.lua, augroup `auto_format_lua_on_save`) pipes the
  buffer into `vim.system({ "stylua", "-" })` (stylua from Mason, run in nvim's cwd) and replaces
  the lines only when stylua exits 0 and its output differs. On failure the buffer is saved as
  typed and nvim-notify shows a WARN `stylua failed, buffer left unformatted: <stylua's first
  stderr line>`. The cursor of every window showing the buffer is restored, clamped to the new
  text. No stylua on PATH: saved as typed, no message.
- Go: go.nvim's `BufWritePre *.go` runs `require("go.format").gofmt()` with `gofmt = "gofumpt"`.
- Python: `BufWritePre *.py` compiles a temp copy with `py_compile` and publishes diagnostics in
  the `python_syntax_errors` namespace (no formatting).
- `jk` in insert mode = `<Esc>:write<CR>`; `,w` = `:update`.

## How to get to it (user POV)

Edit a `.lua`/`.go`/`.py` file and save (`:w`, `,w`, or `jk` from insert mode).

## Driving it with verify.sh

Probes used below:

```sh
NOTIFY='vim.inspect(vim.tbl_map(function(n) return { n.level, n.message } end, require("notify").history()))'
MSGS='vim.api.nvim_exec2("messages", { output = true }).output'
```

Lua, valid code (formatted on save):

```sh
$V cli RUN git checkout -- sample.lua; $V sync RUN
$V keys RUN : e Space sample.lua Enter
$V keys RUN G O; $V keys RUN --paste 'local   z   =   1'; $V keys RUN Escape Escape
$V keys RUN : w Enter
$V cli RUN git diff sample.lua
```

End state seen (same before and after the fix): tabs for indentation, `function M.sum(a, b)` split
over three lines, `+local z = 1`.

Lua, a syntax error on line 1:

```sh
$V cli RUN git checkout -- sample.lua; $V sync RUN   # fresh nvim: no stale prompts
$V keys RUN : e Space sample.lua Enter
$V keys RUN g g O; $V keys RUN --paste 'local x = = 1'; $V keys RUN Escape Escape
$V keys RUN : w Enter
$V cli RUN sh -c 'wc -l < sample.lua; head -1 sample.lua; sed -n 5p sample.lua'
$V lua RUN 'vim.api.nvim_buf_line_count(0)'
$V lua RUN 'vim.api.nvim_win_get_cursor(0)'
$V lua RUN "$NOTIFY"
$V lua RUN "$MSGS"
```

End state after the fix: `11` lines, line 1 `local x = = 1`, line 5 still `      local   msg = ...`
(unformatted, as typed). The buffer has 11 lines, the cursor is `{ 1, 12 }`, and the notify
history has `{ "WARN", { "stylua failed, buffer left unformatted: error: could not format from
stdin: failed to format from stdin: error parsing:" } }`. The screen shows `"sample.lua" 11L, ...
written`; `:messages` is empty (re-measured 2026-11-04 by nvim-0-12-clean's sweep: Neovim 0.12.6
does not keep a write message in the history, `nvim --clean` alike).
Before (base `a14aef9`, `silent %!stylua -`): `3` lines, line 1 `error: could not format from
stdin: failed to format from stdin: error parsing:`, `:messages` `"sample.lua" 3L, 230B written`.
The 11-line file was gone.

Lua, a syntax error further down (cursor below line 3):

```sh
$V cli RUN git checkout -- sample.lua; $V sync RUN
$V keys RUN : e Space sample.lua Enter
$V keys RUN 8 G O; $V keys RUN --paste 'local y = = 2'; $V keys RUN Escape Escape
$V keys RUN : w Enter
$V cli RUN sh -c 'wc -l < sample.lua; sed -n 8p sample.lua'
$V lua RUN 'vim.api.nvim_buf_line_count(0)'
$V lua RUN 'vim.api.nvim_win_get_cursor(0)'
$V lua RUN "$NOTIFY"
```

End state after the fix: the file has `11` lines with line 8 `local y = = 2`, the buffer has 11
lines, the cursor is `{ 8, 12 }`, and there is one WARN as above. `:messages` has no `Cursor
position outside buffer`.
Before: `nvim_win_set_cursor` raised `Cursor position outside buffer` and the `:w` aborted, with
the buffer already holding the 3 lines of error text (buffer line count `3`). The file showed `11`
lines only because `auto_save_on_normal` had written the typed text on Escape (see Gotchas);
pressing Enter at the error's hit-enter prompt returned to normal mode, and that same auto-save
then wrote the 3 lines to disk (`:messages`: `"sample.lua" 3L, 230B written`).

Lua, valid code that formats shorter than the cursor row (cursor clamp):

```sh
$V cli RUN git checkout -- sample.lua; $V sync RUN
$V keys RUN : e Space sample.lua Enter
$V keys RUN -l ":0put =repeat([''], 12)"; $V keys RUN Enter
$V keys RUN G                                  # cursor on line 22 of 22
$V keys RUN : w Enter
$V cli RUN sh -c 'wc -l < sample.lua; head -1 sample.lua'
$V lua RUN 'vim.api.nvim_win_get_cursor(0)'
$V lua RUN "$MSGS"
```

End state after the fix: the file has `12` lines and line 1 is `local M = {}` (stylua dropped the
blank lines and split `M.sum`). The cursor is `{ 12, 0 }` (`return M`), and there is no error in
`:messages`.
Before: `Cursor position outside buffer` in `:messages` and the `:w` aborted; the file still had
the `22` lines the auto-save wrote after `:0put`, and the cursor was left at `{ 1, 0 }`. The
formatted buffer only reached disk through the auto-save after the hit-enter prompt.

Go:

```sh
$V keys RUN : e Space main.go Enter; $V keys RUN 6 G A Space Escape; $V keys RUN : w Enter
$V cli RUN git diff main.go
```

End state seen: `-	var x = a+b` / `+	x := a + b`, `+	fmt.Println(add(1, 2))`. The screen
shows the file written twice (go.nvim rewrites after formatting); `:messages` does not keep the
write messages on Neovim 0.12.6 (see the Lua block above).

Python:

```sh
$V keys RUN : e Space app.py Enter; $V keys RUN G o; $V keys RUN --paste 'def broken(:'
$V keys RUN Escape Escape; $V keys RUN : w Enter
$V lua RUN 'vim.tbl_map(function(d) return d.source .. "@" .. (d.lnum+1) .. ": " .. d.message end, vim.diagnostic.get(0, {namespace = vim.api.nvim_create_namespace("python_syntax_errors")}))'
```

End state seen: `{ "Python Syntax@6: invalid syntax" }`; the file is saved as typed.

## Gotchas

- Fixed (was a product finding on base `a14aef9` and live `d7bf9fe`): `vim.cmd("silent %!stylua
  -")` ignored stylua's exit status, and nvim's filter put stderr into the buffer, so any Lua
  syntax error at save time replaced the buffer (and, when the cursor restore did not throw, the
  file) with stylua's error. The autocmd now uses `vim.system` with stdin and replaces lines only
  on exit 0. The WARN goes through nvim-notify, so read it from `require("notify").history()`;
  the popup disappears after about 2 s and `:messages` does not have it.
- `lua/config/lsp.lua`'s `auto_save_on_normal` (ModeChanged `*:n`) runs `:write` whenever a
  modified buffer returns to normal mode, so `Escape Escape` already saves. That `:write` runs
  inside an autocmd (not nested), so `BufWritePre` and stylua do **not** run for it: the typed
  text lands on disk first, and the explicit `:w` is the save that formats.
- A multi-line error from a `BufWritePre` leaves nvim at a hit-enter prompt, and `lua`/`wait`
  then time out (`Caught deadly signal 'SIGTERM'` in the evidence). `screen`, press `Enter`, then
  probe.
- A line after `return M` is a syntax error too ("return must be last"): add test lines above it.
- Type text with `--paste`: typed `jk` would save, and blink's menu eats the first Escape.
- Reset between journeys with `$V cli RUN git checkout -- FILE` and `:e!` or `sync`; a "file
  changed since reading" y/n prompt otherwise eats the next keys.
