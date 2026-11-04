# Phase 1: Stylua format-on-save without data loss

**Plan set:** `FIX_BUGS_NVIM_0_12_PLAN.md`
**Analysis:** `docs/analyzer/20261104-102452-MRDD_code_analyzer.md`
**Satisfies:** R1: stylua format-on-save never loses content (`vim.system` + stdin, replace only on exit 0, cursor safe)
**Depends on:** none
**Difficulty:** NORMAL
**Package:** `lua/` (`lua/custom-autocmd.lua`) + `.claude/skills/verify-nvim-config/features/format-on-save.md`

---

> **Set-wide execution rules** (plan index § Execution rules; they override any command below that disagrees):
> 1. `$WT` is **this phase's own worktree root** (`WT=$(git rev-parse --show-toplevel)`). Wave-1 phases run
>    concurrently in separate worktrees, so never `cd` into another phase's tree.
> 2. **No `git stash`** (the stash stack is shared by every worktree of the repo). Swap base and fix per file:
>    `SW=$(mktemp -d)`; BASE = `cp <path> "$SW/" && git show "$PHASE_BASE:<path>" ><path>`; FIX = `cp "$SW/<file>" <path>`,
>    where `PHASE_BASE=$(git rev-parse HEAD)` is recorded before this phase's first edit. A new file's BASE is `mv <path> "$SW/"`.
> 3. Commit with an explicit pathspec: `git add -- <new files>` then `git commit -m "..." -- <every path>`.
> 4. Evidence goes to `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-1.md`, this phase's own file (never a shared one),
>    written only **after every run of the phase is down** (the file is inside the snapshotted tree; a mid-run write makes
>    `doctor` print `code WARN`). It is committed as the phase's last commit:
>    `git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-1.md && git commit -m "docs(evidence): phase 1 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-1.md`.
>    `.workflows/` is tracked (the orchestrator commits the plan set); commit nothing else under it unless this plan says so.
> 5. Never `git push`. Never write `~/.config/nvim`, `~/.local/share/nvim` or `/opt/nvim-linux-x86_64`.

## Goal

Saving a `*.lua` buffer runs stylua through `vim.system` with the buffer text on stdin. The
buffer is replaced only when stylua exits 0 and its output differs from the buffer. On any failure
(syntax error, stylua missing, timeout, spawn error) the buffer and the written file keep exactly
what the user typed, the write goes ahead, and one WARN notification names stylua's error. The
cursor in every window showing the buffer is restored and clamped, so the restore can never throw
or abort the write.

## Root cause (reproduction traced to a line)

`lua/custom-autocmd.lua:248-257` (base `a14aef9`):

```lua
	callback = function()
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		vim.cmd("silent %!stylua -")          -- line 254
		vim.api.nvim_win_set_cursor(0, cursor_pos)  -- line 255
	end,
```

- Line 254: the `:%!` filter replaces the whole buffer with the command's stdout **and stderr**
  and ignores the exit status. On a Lua syntax error stylua exits 2 and prints 3 lines
  (`error: could not format from stdin: failed to format from stdin: error parsing: ` plus two
  ` - unexpected token ...` lines). Those 3 lines become the buffer. I measured this on this
  machine: `printf 'local x = = 1\n' | ~/.local/share/nvim/mason/bin/stylua -` gives `code=2`
  and that text. If `stylua` is not on PATH, the filter writes `sh: stylua: not found` into the
  buffer the same way.
- Line 255: the saved cursor row is restored without clamping. If the row is 3 or less, the
  restore succeeds and the write proceeds, so the **file on disk** becomes the error text. If
  the row is greater than 3, `Cursor position outside buffer` is raised, the write aborts, and the
  **buffer** keeps the error text, which the next save writes. A second case on the base: valid
  code whose formatted form is shorter than the cursor row (stylua collapses blank lines) also
  throws there and aborts the write.
  I measured that 13 leading blank lines plus the 10-line fixture (23 lines) format to 12 lines.

Repro recipe: `features/format-on-save.md` "Lua, a syntax error on line 1", observed as an
11-line file turned into 3 lines.

## Interface Contract

**Deletes:** the `vim.cmd("silent %!stylua -")` filter call and the unclamped `nvim_win_set_cursor(0, ...)` in the `auto_format_lua_on_save` callback (`lua/custom-autocmd.lua:252-256`)
**Renames:** none
**Creates:** none. No new module, function or global. The logic stays inline in the autocmd callback, which now takes `args`.
**Signature changes:** the autocmd callback goes from `function()` to `function(args)` and uses `args.buf`. The augroup name `auto_format_lua_on_save`, `pattern = "*.lua"`, the `desc` and the event `BufWritePre` are unchanged.
**Behaviour kept byte for byte:** argv `{ "stylua", "-" }`, run in nvim's cwd. Stylua config resolution is unchanged, so the valid-code end state (tabs in WORK, which has no `.stylua.toml`) is identical.
**Behaviour added:** on stylua failure, `vim.notify(<msg>, vim.log.levels.WARN, { title = "nvim-config" })`. The message starts `stylua failed, buffer left unformatted: ` followed by stylua's first stderr line, trimmed. `vim.notify` is nvim-notify after VeryLazy, so it appears in `require("notify").history()` and not in `:messages`.
**Requires (from earlier phases):** none
**Later phases can rely on:** a Lua save with a syntax error keeps the buffer and file content. Phase 9 re-drives the four journeys in `features/format-on-save.md` on 0.12.6 and can expect the "after" end states written there. `vim.system(...):wait(timeout)` and `fn.win_findbuf` behave the same on 0.11.5 and 0.12.
**Leaves alone (owned by others):** the Python syntax-check autocmd in the same file (`lua/custom-autocmd.lua:261+`), go.nvim formatting, and `features/README.md` (its "Known on the base" cell for this feature, line 10) plus `features/live-environment.md:28-29` ("stylua error text written over `sample.lua`"), both owned by Phase 9. `after/lsp/*` (Phase 2), `lua/plugin_specs.lua` (Phases 6/7/8/9), `verify.sh`/`SKILL.md` (Phases 4-9).

## Files

| File | Action | What changes |
|---|---|---|
| `lua/custom-autocmd.lua` | modify, lines 248-257 | replace the `auto_format_lua_on_save` autocmd with the `vim.system` version |
| `.claude/skills/verify-nvim-config/features/format-on-save.md` | modify, whole file | Sub-features line, Lua journeys (base result marked "before", fixed end state "after"), two new Lua journeys (error further down, cursor clamp), the product-finding gotcha replaced |

`.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-1.md` (new) is written after every Proof run is
down and committed on its own as this phase's last commit (execution rule 4). It is not part of the
`fix(format)` commit.

## Implementation Steps

### Step 1: Replace the stylua autocmd
**File:** `lua/custom-autocmd.lua:248-257`. Replace exactly the block from
`api.nvim_create_autocmd("BufWritePre", {` (line 248) through its closing `})` (line 257). Leave
the blank lines after it and the Python block that starts at `-- Create diagnostic namespace for
Python syntax errors` unchanged.
**Change:** run stylua with `vim.system` on the text of `args.buf`. Skip silently when `stylua` is
not executable. Replace lines only on exit 0 and only when the output differs. Notify WARN on
failure. Save the cursor of every window showing the buffer and restore it, clamped, in a pcall.
The file already declares `local fn = vim.fn` and `local api = vim.api` at lines 3-4. Tab
indentation, matching the file.
**Code:**
```lua
api.nvim_create_autocmd("BufWritePre", {
	group = api.nvim_create_augroup("auto_format_lua_on_save", { clear = true }),
	pattern = "*.lua",
	desc = "Format Lua file with stylua on save",
	callback = function(args)
		-- No stylua (Mason not set up yet): save the buffer as typed, say nothing.
		if fn.executable("stylua") ~= 1 then
			return
		end

		local bufnr = args.buf
		local timeout_ms = 5000
		local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
		-- The buffer as it would be written: every line ends with a newline.
		local text = table.concat(lines, "\n") .. "\n"

		local ok, result = pcall(function()
			return vim.system({ "stylua", "-" }, { stdin = text, text = true }):wait(timeout_ms)
		end)

		-- On any failure the buffer is left exactly as typed and the write goes ahead.
		local failure
		if not ok then
			failure = tostring(result)
		elseif result.code == 124 then
			failure = string.format("timed out after %d ms", timeout_ms)
		elseif result.code ~= 0 then
			failure = vim.trim((result.stderr or ""):match("[^\r\n]+") or "")
			if failure == "" then
				failure = "exit code " .. result.code
			end
		end
		if failure then
			vim.notify(
				"stylua failed, buffer left unformatted: " .. failure,
				vim.log.levels.WARN,
				{ title = "nvim-config" }
			)
			return
		end

		-- stylua ends its output with a newline; drop it so the lines match the buffer's model.
		local formatted = result.stdout or ""
		if formatted:sub(-1) == "\n" then
			formatted = formatted:sub(1, -2)
		end
		local new_lines = vim.split(formatted, "\n", { plain = true })
		if vim.deep_equal(new_lines, lines) then
			return
		end

		-- Remember the cursor of every window showing this buffer, not only the current one.
		local cursors = {}
		for _, win in ipairs(fn.win_findbuf(bufnr)) do
			cursors[win] = api.nvim_win_get_cursor(win)
		end

		local set_ok, set_err = pcall(api.nvim_buf_set_lines, bufnr, 0, -1, false, new_lines)
		if not set_ok then
			vim.notify(
				"stylua: could not update the buffer, left unformatted: " .. tostring(set_err),
				vim.log.levels.WARN,
				{ title = "nvim-config" }
			)
			return
		end

		-- Clamp to the new line count and line length: the restore must never throw,
		-- because an error here aborts the write.
		local line_count = api.nvim_buf_line_count(bufnr)
		for win, pos in pairs(cursors) do
			local row = math.max(1, math.min(pos[1], line_count))
			local line = api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
			local col = math.max(0, math.min(pos[2], #line - 1))
			pcall(api.nvim_win_set_cursor, win, { row, col })
		end
	end,
})
```
**Impact:**
- Valid code formats as before. Same argv, same cwd, same output lines.
- Syntax errors, a missing stylua or a stuck stylua no longer touch the buffer or the file. The
  user sees one WARN notification instead.
- The cursor restore cannot throw, so the write is never aborted by this autocmd.
- `nvim_buf_set_lines` makes one undo step, as the `:%!` filter did.
- `vim.system` with `stdin` as a string closes stdin after writing, so stylua sees EOF. With
  `text = true`, CRLF in the output is normalised to LF, and stylua writes LF by default anyway.
- The file's `'eol'`/`'fixeol'` are not touched. The buffer always gets a trailing newline when
  fed to stylua, which is how nvim writes it with `fixeol` on (the default), and the final `"\n"`
  of stylua's output is stripped before splitting. The empty-buffer case gives `{ "" }` on both
  sides, so there is no change.
- Timeout: `wait(5000)` kills stylua and reports code 124. That case gets its own message. On the
  fixture stylua takes milliseconds.

### Step 2: Rewrite `features/format-on-save.md` to the fixed end states
**File:** `.claude/skills/verify-nvim-config/features/format-on-save.md`, whole file (currently
70 lines). Lines that change: 5 (Sub-features Lua bullet), 30-46 (syntax-error journey and its end
state), 66-70 (product-finding gotcha). Two journeys are added after the syntax-error one. The Go,
Python, `jk`/`,w` bullets, the "line after `return M`", `--paste` and reset gotchas stay word for
word.
**Change:** replace the file with:
**Code:**
````markdown
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
$V cli RUN sh -c 'wc -l < sample.lua; head -1 sample.lua; sed -n 4p sample.lua'
$V lua RUN 'vim.api.nvim_buf_line_count(0)'
$V lua RUN 'vim.api.nvim_win_get_cursor(0)'
$V lua RUN "$NOTIFY"
$V lua RUN "$MSGS"
```

End state after the fix: `11` lines, line 1 `local x = = 1`, line 4 still `      local   msg = ...`
(unformatted, as typed). The buffer has 11 lines, the cursor is `{ 1, 12 }`, and the notify
history has `{ "WARN", { "stylua failed, buffer left unformatted: error: could not format from
stdin: failed to format from stdin: error parsing:" } }`. `:messages` has `"sample.lua" 11L, ...
written`.
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
Before: `nvim_win_set_cursor` raised `Cursor position outside buffer`, the write aborted (`git
diff` empty), and the buffer held the 3 lines of error text, which the next successful save
wrote. Saving again grew it (371 lines seen).

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
Before: `Cursor position outside buffer` in `:messages`, the write aborted (`git diff` empty),
and the buffer was formatted but unsaved.

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

- Fixed (was a product finding on base `a14aef9` and live `d7bf9fe`): `vim.cmd("silent %!stylua
  -")` ignored stylua's exit status, and nvim's filter put stderr into the buffer, so any Lua
  syntax error at save time replaced the buffer (and, when the cursor restore did not throw, the
  file) with stylua's error. The autocmd now uses `vim.system` with stdin and replaces lines only
  on exit 0. The WARN goes through nvim-notify, so read it from `require("notify").history()`;
  the popup disappears after about 2 s and `:messages` does not have it.
- A line after `return M` is a syntax error too ("return must be last"): add test lines above it.
- Type text with `--paste`: typed `jk` would save, and blink's menu eats the first Escape.
- Reset between journeys with `$V cli RUN git checkout -- FILE` and `:e!` or `sync`; a "file
  changed since reading" y/n prompt otherwise eats the next keys.
````
**Impact:** the doc only. `features/README.md:10` and `features/live-environment.md:28-29`
still describe the base bug. Phase 9 owns them (see Handoffs).

### Step 3: Syntax check, prove, record evidence, commit
**Change:**
1. `nvim --headless -u NONE -c 'lua assert(loadfile("lua/custom-autocmd.lua"))' -c 'qa!'`
   from the worktree root exits 0 with no output.
2. Run every journey in **Verification → Proof**, before (base) and after, on `up --live` and
   `up`.
3. After every run is down, write the evidence file
   `$WT/.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-1.md` in the format given under Proof.
4. Commit only the two files (no push):
   ```sh
   cd "$WT"   # this phase's own worktree root (index § Execution rules)
   git commit -m "fix(format): never replace a Lua buffer with stylua's error output" -m "Run stylua via vim.system with the buffer on stdin; replace lines only on exit 0, warn with stylua's first stderr line otherwise, and restore every window's cursor clamped so the write is never aborted." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" \
     -- lua/custom-autocmd.lua .claude/skills/verify-nvim-config/features/format-on-save.md
   ```
   Then the evidence commit (execution rule 4):
   ```sh
   git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-1.md
   git commit -m "docs(evidence): phase 1 before/after evidence" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-1.md
   ```
**Impact:** one commit on `feature/fix-bugs-nvim-0-12`. Nothing outside the worktree is written
except the verify runs' own state under `~/.local/state/nvim-config-verify/`.

## Principles applied

- Fix root causes: the plan states the reproduction (fixture plus `local x = = 1` gives 3 lines on disk) and traces it to `custom-autocmd.lua:254` (the filter takes stderr and ignores the exit code) and `:255` (unclamped restore aborts the write). The fix removes both, and the first Proof journey reproduces it on the base.
- Laziness protocol: the logic stays inline in the existing autocmd. There is no new `utils` helper and no stylua module, and the whole buffer is replaced with `nvim_buf_set_lines` rather than a minimal diff with `vim.diff`. The argv and cwd are unchanged, so the valid-code end state needs no new expectation.
- Prove it works / Sequence into verifiable units: four journeys that can fail (valid, error on line 1, error on line 8, cursor clamp), each driven on the base first and then on the fix, on both `--live` and seeded. The clamp journey was added because the unclamped restore is a second, independent way the base aborts a write, and a fix to the error path alone would not exercise it.
- Test behavior, not implementation: the end states are the file on disk (`wc -l`, `sed -n`), buffer line count, cursor and notification history. None of them asserts on `vim.system` being called.

## Verification

**Build:** `cd "$WT" && nvim --headless -u NONE -c 'lua assert(loadfile("lua/custom-autocmd.lua"))' -c 'qa!'` (exit 0, no output)
**Tests:** no unit test suite in this repo. Invariant 1 check: `$V up` prints no startup errors and `$V doctor RUN` exits 0.
**Proof:**
- Harness: `.claude/skills/verify-nvim-config` (`scripts/verify.sh`), on the installed nvim 0.11.5 (do **not** set `VERIFY_NVIM`).
- Feature-map entries: `.claude/skills/verify-nvim-config/features/format-on-save.md`
- Cost: none (no paid drives). Each `up --live` takes about 7 s and each `sync` a few seconds.

All commands run from the worktree root in zsh:

```sh
cd "$WT"   # this phase's own worktree root (index § Execution rules)
V=.claude/skills/verify-nvim-config/scripts/verify.sh
NOTIFY='vim.inspect(vim.tbl_map(function(n) return { n.level, n.message } end, require("notify").history()))'
MSGS='vim.api.nvim_exec2("messages", { output = true }).output'
```

**Swapping base and fix.** `sync` snapshots the working tree, so the config under test is
whatever `lua/custom-autocmd.lua` holds at the time of the `sync`.
- If the fix is still uncommitted (the implementer): BASE = `SW=${SW:-$(mktemp -d)}; cp lua/custom-autocmd.lua "$SW/" && git show "$PHASE_BASE:lua/custom-autocmd.lua" >lua/custom-autocmd.lua`; FIX = `cp "$SW/custom-autocmd.lua" lua/custom-autocmd.lua`. Never `git stash` (execution rule 2).
- If the fix is committed (a verifier): BASE = `git checkout a14aef9 -- lua/custom-autocmd.lua`; FIX = `git checkout HEAD -- lua/custom-autocmd.lua`.
After the FIX command, `git status --porcelain lua/custom-autocmd.lua` must print nothing if the
fix is committed, or ` M lua/custom-autocmd.lua` if it is uncommitted.

**Journeys.** Define them once per shell. Each one resets `sample.lua` in WORK and runs `sync`,
so it starts on a fresh nvim with the current working tree:

```sh
j_valid() {
  $V cli $RUN git checkout -- sample.lua; $V sync $RUN
  $V keys $RUN : e Space sample.lua Enter
  $V keys $RUN G O; $V keys $RUN --paste 'local   z   =   1'; $V keys $RUN Escape Escape
  $V keys $RUN : w Enter
  $V cli $RUN git diff sample.lua
}
j_err1() {
  $V cli $RUN git checkout -- sample.lua; $V sync $RUN
  $V keys $RUN : e Space sample.lua Enter
  $V keys $RUN g g O; $V keys $RUN --paste 'local x = = 1'; $V keys $RUN Escape Escape
  $V keys $RUN : w Enter
  $V cli $RUN sh -c 'wc -l < sample.lua; head -1 sample.lua; sed -n 4p sample.lua'
  $V lua $RUN 'vim.api.nvim_buf_line_count(0)'
  $V lua $RUN 'vim.api.nvim_win_get_cursor(0)'
  $V lua $RUN "$NOTIFY"
  $V lua $RUN "$MSGS"
}
j_err8() {
  $V cli $RUN git checkout -- sample.lua; $V sync $RUN
  $V keys $RUN : e Space sample.lua Enter
  $V keys $RUN 8 G O; $V keys $RUN --paste 'local y = = 2'; $V keys $RUN Escape Escape
  $V keys $RUN : w Enter
  $V cli $RUN sh -c 'wc -l < sample.lua; sed -n 8p sample.lua'
  $V cli $RUN git diff --stat sample.lua
  $V lua $RUN 'vim.api.nvim_buf_line_count(0)'
  $V lua $RUN 'vim.api.nvim_win_get_cursor(0)'
  $V lua $RUN "$NOTIFY"
  $V lua $RUN "$MSGS"
}
j_clamp() {
  $V cli $RUN git checkout -- sample.lua; $V sync $RUN
  $V keys $RUN : e Space sample.lua Enter
  $V keys $RUN -l ":0put =repeat([''], 12)"; $V keys $RUN Enter
  $V keys $RUN G
  $V lua $RUN 'vim.api.nvim_win_get_cursor(0)'
  $V keys $RUN : w Enter
  $V cli $RUN sh -c 'wc -l < sample.lua; head -1 sample.lua'
  $V cli $RUN git diff --stat sample.lua
  $V lua $RUN 'vim.api.nvim_win_get_cursor(0)'
  $V lua $RUN "$MSGS"
}
```

**Run order, done twice: first with `MODE=--live`, then with `MODE=` (seeded):**

```sh
out=$($V up $MODE); echo "$out"; RUN=$(sed -n 's/^RUN=//p' <<<"$out")
$V doctor $RUN                                    # exit 0
# BEFORE: run the BASE swap command (see above), then:
$V note $RUN "phase 1 BEFORE (base a14aef9 autocmd)"
j_valid; j_err1; j_err8; j_clamp
# AFTER: run the FIX swap command, then:
$V note $RUN "phase 1 AFTER (vim.system autocmd)"
j_valid; j_err1; j_err8; j_clamp
$V doctor $RUN                                    # exit 0
$V down $RUN
```

On `--live`, `doctor`'s `live` line may WARN if the owner used nvim during the run. That is not a
failure of this phase.

**Pass/fail end states.** Each line is read from the evidence file that the command prints as
`[evidence: ...]`.

| Journey | BEFORE (base) must show | AFTER (fix) must show |
|---|---|---|
| `j_valid` | `git diff` has tab-indented `M.greet`, `function M.sum(a, b)` split over 3 lines, `+local z = 1` | the same diff hunk body as BEFORE, line for line |
| `j_err1` | `wc -l` = `3`; head = `error: could not format from stdin: failed to format from stdin: error parsing:`; `:messages` has `3L` written | `wc -l` = `11`; head = `local x = = 1`; line 4 = `      local   msg = "hello, " .. name` (unformatted); buffer lines `11`; cursor `{ 1, 12 }`; notify history has a `"WARN"` entry starting `stylua failed, buffer left unformatted: error: could not format from stdin`; `:messages` has `"sample.lua" 11L` written |
| `j_err8` | `:messages` has `Cursor position outside buffer`; `git diff --stat` empty; buffer lines `3` | `wc -l` = `11`; line 8 = `local y = = 2`; `git diff --stat` = `1 file changed, 1 insertion(+)`; buffer lines `11`; cursor `{ 8, 12 }`; one `"WARN"` stylua entry; no `Cursor position outside buffer` in `:messages` |
| `j_clamp` | cursor before save `{ 22, 0 }`; `:messages` has `Cursor position outside buffer`; `git diff --stat` empty | cursor before save `{ 22, 0 }`; `wc -l` = `12`; head = `local M = {}`; `git diff --stat` non-empty; cursor after `{ 12, 0 }`; no `E5108`/`Cursor position outside buffer` in `:messages` |

A row is `inconclusive` (never weakened to pass) if a prompt ate keys. Run `$V screen $RUN`,
record why, and re-run that journey once.

- Neighbor check: the Go format-on-save journey, run once in the AFTER state of the seeded run
  before `down` (the go.nvim BufWritePre must be unaffected):
  `$V keys $RUN : e Space main.go Enter; $V keys $RUN 6 G A Space Escape; $V keys $RUN : w Enter; $V cli $RUN git diff main.go`.
  It passes when the diff shows `-	var x = a+b` / `+	x := a + b`. The Python journey in
  `format-on-save.md` is also unaffected and is optional here.
- Not driven: the `jk` save path. It triggers the same `BufWritePre` as `:w`.

**Evidence record.** After the last `down`, write
`$WT/.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-1.md` (this phase's own file; phase 9 builds
the set's `evidence.md` index from it, so keep the shape):

```markdown
## Phase 1: Stylua format-on-save without data loss (R1)

- nvim: 0.11.5 (installed), commit: <short sha of the phase commit>
- live run `<RUN>`: evidence `~/.local/state/nvim-config-verify/<RUN>/evidence/`
  - before: j_valid `<NN-cli-*.txt>`, j_err1 `<NN-cli-*.txt>` (3 lines), j_err8 `<NN-lua-*.txt>` (messages), j_clamp `<NN-lua-*.txt>`
  - after:  j_valid `<...>`, j_err1 `<...>` (11 lines) + notify `<...>`, j_err8 `<...>`, j_clamp `<...>`
- seeded run `<RUN>`: evidence `~/.local/state/nvim-config-verify/<RUN>/evidence/`
  - before: ... / after: ... (same shape), neighbor go `<NN-cli-*.txt>`
- doctor: live `<NN-...>` exit 0, seeded `<NN-...>` exit 0
- verdict: pass | fail | inconclusive (<reason>)
```

**Exit criteria:** on both `up --live` and `up`, every BEFORE cell of the table above is observed
on the base autocmd and every AFTER cell on the fix. The Go neighbor check passes. `doctor` exits
0 on both runs. `features/format-on-save.md` states the AFTER end states. The commit
`fix(format): never replace a Lua buffer with stylua's error output` contains exactly
`lua/custom-autocmd.lua` and `features/format-on-save.md`. Nothing is pushed.

## Handoffs

- **Phase 9** (owns `features/README.md` and `features/live-environment.md`, the latter except
  phase 5's deploy line):
  - `features/README.md:10`: the "Known on the base" cell for "Format and check on save" still
    reads **stylua error text replaces a Lua file with a syntax error**. Update it to the fixed
    state, e.g. "fixed in phase 1: buffer kept, WARN shown".
  - `features/live-environment.md:28-29`: drop "stylua error text written over `sample.lua`" from
    the `--live` journey summary.
  - Re-drive `j_valid`/`j_err1`/`j_err8`/`j_clamp` on 0.12.6. The code uses only APIs present in
    both 0.11 and 0.12.
- **Deploy section / R11**: the final from-`~/.config/nvim` proof runs "the format-on-save
  journeys (valid + syntax error)". `j_valid` and `j_err1` above are those journeys, with the
  AFTER end states.
- Not taken (out of scope, noted only): `.stylua.toml` at the repo root uses 2-space indent while
  `lua/custom-autocmd.lua` is tab-indented. Running stylua with this repo as cwd would reindent
  the file. That is pre-existing and not R1.

## Rollback

`git revert <phase-1 commit>` on `feature/fix-bugs-nvim-0-12`. It restores the base autocmd and
the base feature doc. No seed, live or binary state is touched by this phase, so nothing else
needs undoing. The verify runs are already gone after `down`, and their evidence directories can
stay.
