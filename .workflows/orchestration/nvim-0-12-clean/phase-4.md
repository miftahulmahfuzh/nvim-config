# Phase 4: Sweep, tmux true colour, health allow-list, evidence index, Deploy runbook

**Plan set:** `NVIM_0_12_CLEAN_PLAN.md`
**Analysis:** `.workflows/analyze/20261104-121422-N12C_code_analyzer.md`
**Satisfies:** R6 (sweep: checkhealth, `:messages` after every journey, every plugin loads, notify
history; fix what is real, record what is upstream-only), R7 (land + Deploy + final live proof +
evidence paths per item)
**Depends on:** Phase 3 (and through it 1 and 2)
**Difficulty:** NORMAL
**Package:** `.claude/skills/verify-nvim-config/features/` + `.tmux.conf.local`

---

## Goal

After this phase, `:checkhealth` has no WARNING/ERROR line that is not in a recorded, reasoned
allow-list (`features/health.md`), proved by a script in both run modes before and after every
lazy plugin is loaded. tmux gives nvim true colour (`tmux_conf_24b_colour=true`). Every
`features/*.md` journey was re-driven on `up --live` and `up` with a noise probe after each.
The set has one evidence index with a before/after path per item. The coordinator gets a Deploy
runbook (D0-D6) that it can run line by line, where every step asserts and has a rollback.

## Facts this plan rests on (measured while planning, 2026-11-04)

- **True colour.** Scratch tmux servers (own sockets under the scratchpad, never the owner's), this
  repo's `.tmux.conf`, client `TERM=xterm-256color` like `run_env`:
  `tmux_conf_24b_colour=auto` → `show -gv terminal-overrides` empty, `show-messages -T` has **0**
  ` setrgb[bf]: (string)` lines. `=true` → `*256col*:Tc`, **2** lines. Nvim's check
  (`runtime/lua/vim/health/health.lua:356-366`) warns exactly when either line is missing.
  oh-my-tmux's `_apply_24b` (`.tmux.conf:887-912`, the same in the owner's `~/.tmux/.tmux.conf`)
  runs during config load. At that point the job's `TERM` is the starting client's, so the
  `screen-*|tmux-*` exclusion does not apply.
- **Checkhealth parse.** A probe (Step 1's `health_diff.lua`, tested in scratch) on the base's full
  report (`$E/1104-121901-2809686/evidence/03-lua-return_table.concat_vim.api.nvim_buf_get.txt`)
  gives `sections=20 findings=86 allowed=61 unexpected=25`. The 25 unexpected keys are exactly the
  ones phases 1-3 and this phase fix: go ×20, fidget, vim.deprecated ×2, vim.health tmux, and
  blink's v0 `(i.e. cmdline)` line.
- **Base runs with the probes** (planning, base `9cea538`):
  - seeded `$E/1104-123911-2920493`, live `$E/1104-123923-2924758`. With gopls attached:
    `unexpected=25`.
  - After `load_all`: `sections=22`, `unexpected=31`. The two extra sections are
    `render-markdown` (5 warnings: `latex`/`yaml` parser not installed, `ABI: unknown` ×2, no
    latex converter) and `telescope` (`fd` missing). `vim.deprecated` also gains blink's
    `client.request`.
  - `load_all`: `tried=18 failed=0 unloaded=0` (29 in a fresh seeded run, `$E/1104-123730-2914033`).
- **Run-only noise found on the base.**
  - `clipboard: error: no buffers`: yanky.nvim reads `+` on setup and the fresh run tmux has no
    paste buffer (`$E/1104-123349-2896788/evidence/01-lua-…`). It goes away after a `y y`
    (`$E/1104-123424-2900903`).
  - `client.request is deprecated` after a full `:checkhealth`: blink's stack, R2, fixed by phase 3
    (`$E/1104-123952-2930953/evidence/08-…`, `13-…`).
  - `E31: No such mapping` in `v:errmsg` on opening any markdown buffer, never shown
    (`$E/1104-124053-2938291/evidence/03-…`). Cause: Neovim 0.12's `ftplugin/markdown.vim` and
    `ftplugin/markdown.lua` both add `nunmap <buffer> ]]`/`[[` to `b:undo_ftplugin`. lazy's `ft`
    handler fires `FileType` twice (`ft` list `{3:…, 3:…}`), and the second `sil! nunmap` fails.
    Upstream only.
- **Allow-list ingredients.**
  - `ts_ls` is enabled only on `--live`: live Mason has `typescript-language-server`, the seed does
    not. So its two `Unknown filetype` lines are `UNUSED` on seeded runs.
  - which-key lists overlaps in a different order on each run, so those entries are prefixes.
  - blink v1.10.2 (`78336bc`, `lua/blink/cmp/health.lua:45`) always warns
    `Some providers may show up as "disabled" but are enabled dynamically (e.g. cmdline)`.
  - Of the optional tools, the owner's shell has only `cargo` (`~/.cargo/bin`, excluded from
    `run_path` by design) and `golangci-lint` (phase 1). None of the others exist.
- **render-markdown.** Its health checks the latex/yaml parsers and latex converters only when
  `latex.enabled`/`yaml.enabled` (`render-markdown/lua/render-markdown/health.lua:37-57`). Neither
  live nor seed has a `yaml` or `latex` parser (`site/parser/` holds the 14 `.so` of the 13
  configured languages + `c`), so neither feature ever rendered.
- **blink v1 prebuilt lib.** `lua/blink/cmp/fuzzy/download/files.lua`: `target/release/` holds
  `libblink_cmp_fuzzy.so`, `libblink_cmp_fuzzy.so.sha256` and `version`. `download/init.lua`
  loads the lib without downloading only when `version` equals `git describe --tags --exact-match`
  and the checksum file verifies. So Deploy copies **all three** files and the clone needs the tag
  (`fetch --tags`). The seed's `target/release/version` already reads `v1.10.2`.
- `origin/main` moved to `9cea538` (`fix(startup): recover when nvim's working directory is
  deleted`, `features/startup.md` + `lua/custom-autocmd.lua`). `.tmux.conf.local` is identical at
  `8bcb55c` and `9cea538`, and byte-identical to `~/.tmux.conf.local` (a regular file;
  `~/.tmux.conf` → `~/.tmux/.tmux.conf`).

`$E` = `~/.local/state/nvim-config-verify` throughout.

## Interface Contract

**Deletes:** none.
**Renames:** none.
**Creates:**
- `features/health.md`: the checkhealth allow-list in ```` ```allow ```` blocks, plus the known
  noise in ```` ```noise ```` blocks.
- `features/lua/health_diff.lua`: compares the `health://` buffer with the allow-list.
- `features/lua/noise.lua`: new `:messages`/notify WARN-ERROR-deprecation/`v:errmsg` since its
  previous call, minus the known noise.
- `features/lua/load_all.lua`: loads every not-yet-loaded lazy plugin.
- `.workflows/plan/nvim-0-12-clean/phase-4-health.sh seeded|live`: the lever.
- `.workflows/plan/nvim-0-12-clean/evidence-phase-4.md`
- `.workflows/plan/nvim-0-12-clean/evidence.md`: the set's evidence index.
- The Deploy runbook D0-D6 (this file).

(`features/` = `.claude/skills/verify-nvim-config/features/`)

**Signature changes:** none.
**Config value changes:**
- `.tmux.conf.local:18` `tmux_conf_24b_colour=auto` → `true`.
- `lua/plugin_specs.lua` render-markdown spec `opts = {}` → `opts = { latex = { enabled = false },
  yaml = { enabled = false } }`. This is the **only** edit in that file: no url/branch/version/
  commit/build change, so no plugin moves and no lock change. Reconciled: phase 3 edits the same
  file first (blink.cmp spec, post-phase-3 `:49-56`; git-conflict spec, `:384-395`); this edit is
  the render-markdown spec's `opts` line (post-phase-3 `:135`, base `:134`), outside both hunks.
  The index allows it ("fixing any new config-side finding it surfaces, no plugin moves").

**Requires (from earlier phases):**
- Phase 1:
  - `run_path` carries `golangci-lint`'s dir, so `:checkhealth go` is clean in both modes.
  - doctor prints a `path` line and exits 0 on a good run.
  - `sync` keeps `run_path`.
  - `features/startup.md` has its PATH subsection.
- Phase 2:
  - `v:errmsg == ""` after startup (no E216).
  - The CursorHold callback skips a window with fewer than 3 columns.
  - fidget health is clean.
  - `features/lsp.md` has `### CursorHold diagnostic float` and `### fidget health`; `startup.md`
    has `### v:errmsg after startup and the directory hijack`.
- Phase 3:
  - The spec has blink.cmp `version = "1.*"` and `"stryukovsky/git-conflict.nvim"`.
  - Seed lock: `blink.cmp` commit `78336bc89ee5365633bcf754d93df01678b5c08f`, and
    `git-conflict.nvim` commit `63c5b427038d85b20c32a25c7f3bd502241ce869` with url
    `https://github.com/stryukovsky/git-conflict.nvim…`. Both carry `branch` and `url`.
  - Seed dirs are checked out there, and the seed's `blink.cmp/target/release/` holds
    `libblink_cmp_fuzzy.so`, `.sha256` and `version` = `v1.10.2`.
  - `features/git.md` has a conflict journey, and `features/lsp.md` a completion journey.
  - `--live` lists exactly `blink.cmp git-conflict.nvim` in `replaced_from_seed`.
- Phase 3: `features/lua/deprecations.lua` (cumulative deprecation + blink-fallback probe; prints
  `0` when clean). `verify.sh`'s moved-plugin rule is `live_lacks_seed_commit` (seed commit not
  HEAD or an ancestor of live HEAD); live-environment.md is reworded to match.
- Phases 1-3: each has an `evidence-phase-N.md` with before/after run paths per item.

**Leaves alone (owned by others):**
- `verify.sh` (phases 1 and 3), `seed.lua` (phase 3) and `SKILL.md` (phases 1 and 3). The only
  exception is a sweep finding that needs a verify.sh change (Step 6 rule (d)); none was found
  while planning.
- `features/editing-mappings.md` (its `:67` run-PATH sentence stays: still true, SKILL.md is the
  canonical list).
- `lua/config/*` (phases 2/3).
- `features/startup.md`, `lsp.md`, `git.md` (phases 1-3). The sweep reads them; a finding that
  changes their end states is recorded in evidence-phase-4.md and, if config-side, fixed with the
  doc edit in the same commit.
- The verify seed (phase 3 only).
- `~/.config/nvim`, `~/.local/share/nvim`, `~/.tmux.conf.local`. Only the Deploy section writes
  these, after land.

## Files

| File | Action | What changes |
|---|---|---|
| `.tmux.conf.local:18` | modify | `tmux_conf_24b_colour=true` |
| `lua/plugin_specs.lua:135` (post-phase-3; base `:134`; render-markdown `opts`, anchor on the text) | modify | disable latex/yaml rendering, which never worked here |
| `.claude/skills/verify-nvim-config/features/health.md` | create | allow-list + known noise + fixed table |
| `.claude/skills/verify-nvim-config/features/lua/health_diff.lua` | create | checkhealth vs allow-list probe |
| `.claude/skills/verify-nvim-config/features/lua/noise.lua` | create | per-journey noise probe |
| `.claude/skills/verify-nvim-config/features/lua/load_all.lua` | create | load every lazy plugin |
| `.claude/skills/verify-nvim-config/features/tmux-bindings.md` | rewrite (38 lines) | true-colour sub-feature + journey |
| `.claude/skills/verify-nvim-config/features/README.md` | rewrite (21 lines) | dated header, Known-on-the-base column, health row |
| `.claude/skills/verify-nvim-config/features/live-environment.md` | rewrite (62 lines) | before/after-Deploy `replaced_from_seed`, tmux drift |
| `.workflows/plan/nvim-0-12-clean/phase-4-health.sh` | create | the lever (one mode per call) |
| `.workflows/plan/nvim-0-12-clean/evidence-phase-4.md` | create | this phase's evidence |
| `.workflows/plan/nvim-0-12-clean/evidence.md` | create | the set's index |

## Implementation Steps

`V=.claude/skills/verify-nvim-config/scripts/verify.sh`,
`F=.claude/skills/verify-nvim-config/features`. Run everything from the worktree root
`/home/miftah/.worktrees/nvim/nvim-0-12-clean` in **bash** (the Bash tool's shell is zsh: wrap
multi-line blocks in `bash -c '…'` or a script, and never `echo ====`).

### Step 0: Preconditions (read-only)
**Change:** none. Assert phases 1-3 are on the branch and the seed carries phase 3's targets before
writing anything.
**Code:**
```bash
set -euo pipefail
cd /home/miftah/.worktrees/nvim/nvim-0-12-clean
SEED=$HOME/.local/state/nvim-config-verify/.seed
grep -q '"stryukovsky/git-conflict.nvim"' lua/plugin_specs.lua
grep -q 'version = "1\.\*"' lua/plugin_specs.lua
[ "$(jq -r '."blink.cmp".commit' "$SEED/lazy-lock.json")" = 78336bc89ee5365633bcf754d93df01678b5c08f ]
[ "$(jq -r '."git-conflict.nvim".commit' "$SEED/lazy-lock.json")" = 63c5b427038d85b20c32a25c7f3bd502241ce869 ]
[ "$(cat "$SEED/data/nvim/lazy/blink.cmp/target/release/version")" = v1.10.2 ]
for n in 1 2 3; do [ -f ".workflows/plan/nvim-0-12-clean/evidence-phase-$n.md" ]; done
grep -qx 'tmux_conf_24b_colour=auto' .tmux.conf.local
grep -q 'opts = {}, -- The defaults are sane. Stop over-configuring.' lua/plugin_specs.lua
```
**Impact:** none. If an assertion fails, stop: an earlier phase has not landed.

### Step 1: The probes, the allow-list and the lever (no config change yet)

**File:** `.claude/skills/verify-nvim-config/features/lua/health_diff.lua` (new)
**Code:**
```lua
-- Compares the newest :checkhealth report with the allow-list in features/health.md. Read-only.
--   verify.sh lua RUN @.claude/skills/verify-nvim-config/features/lua/health_diff.lua
-- Every WARNING/ERROR line becomes a key "<section>[ / <subsection>]: <LEVEL> <message>"; a
-- message ending in ":" takes its first indented continuation line. A key is allowed when it
-- equals an entry of health.md's ```allow blocks, or starts with an entry's text before its
-- trailing "*". First line: "sections=N findings=N allowed=N unexpected=N unused=N" (pass:
-- unexpected=0), then one UNEXPECTED / ALLOWED / UNUSED line per key or entry.
local here = debug.getinfo(1, "S").source:gsub("^@", "")
local allow_file = vim.fn.fnamemodify(here, ":h:h") .. "/health.md"

local allow, inside = {}, false
for _, line in ipairs(vim.fn.readfile(allow_file)) do
  if line:match("^```allow%s*$") then
    inside = true
  elseif inside and line:match("^```") then
    inside = false
  elseif inside and line ~= "" and not line:match("^#") then
    table.insert(allow, { text = line, used = false })
  end
end

-- :checkhealth writes its report into the one buffer named health:// (it wipes the previous one)
-- and sets filetype=checkhealth last, so `wait ... vim.bo.filetype checkhealth` means "complete".
-- (blink.cmp's check creates scratch buffers with that filetype too: select by name.)
local buf = vim.fn.bufnr("health://")
if buf == -1 or vim.bo[buf].filetype ~= "checkhealth" then
  return "no complete checkhealth report: run :checkhealth and wait for filetype=checkhealth"
end
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

local keys, sections = {}, {}
local section, subsection = "?", nil
for i, line in ipairs(lines) do
  if line:match("^=+$") and lines[i + 1] then
    section = lines[i + 1]:match("^(%S+):") or "?"
    subsection = nil
    table.insert(sections, section)
  elseif line:match("%S ~$") then
    subsection = line:gsub("%s*~$", ""):gsub("^" .. vim.pesc(section) .. ": ", "")
  else
    local level, message = line:match("^%- %S+ (WARNING) (.*)$")
    if not level then
      level, message = line:match("^%- %S+ (ERROR) (.*)$")
    end
    if level then
      local nxt = lines[i + 1] or ""
      if message:match(":$") and nxt:match("^%s+%S") then
        message = message .. " " .. vim.trim(nxt)
      end
      table.insert(keys, ("%s%s: %s %s"):format(section, subsection and (" / " .. subsection) or "", level, message))
    end
  end
end

local function allowed(key)
  local hit = false
  for _, a in ipairs(allow) do
    local match
    if a.text:sub(-1) == "*" then
      match = key:sub(1, #a.text - 1) == a.text:sub(1, -2)
    else
      match = key == a.text
    end
    if match then
      a.used = true
      hit = true
    end
  end
  return hit
end

local out, unexpected, ok_count = {}, {}, 0
for _, key in ipairs(keys) do
  if allowed(key) then
    ok_count = ok_count + 1
    table.insert(out, "ALLOWED " .. key)
  else
    table.insert(unexpected, "UNEXPECTED " .. key)
  end
end
local unused = {}
for _, a in ipairs(allow) do
  if not a.used then
    table.insert(unused, "UNUSED " .. a.text)
  end
end
local head = ("sections=%d findings=%d allowed=%d unexpected=%d unused=%d"):format(
  #sections, #keys, ok_count, #unexpected, #unused)
return table.concat(vim.iter({ { head }, unexpected, out, unused }):flatten():totable(), "\n")
```

**File:** `.claude/skills/verify-nvim-config/features/lua/noise.lua` (new)
**Code:**
```lua
-- What went wrong since the previous call of this probe in this nvim: `:messages` lines and
-- nvim-notify history entries at WARN or ERROR or naming a deprecation, and a changed v:errmsg.
-- A finding listed in a ```noise block of features/health.md (exact, or a prefix ending in "*")
-- is KNOWN and not counted. Keeps its cursor in _G.__verify_noise (nothing else is written), so
-- each journey sees only what it caused.
--   verify.sh lua RUN @.claude/skills/verify-nvim-config/features/lua/noise.lua
-- First line: "noise=N known=N" (pass: noise=0), then one NOISE / KNOWN line per finding.
local here = debug.getinfo(1, "S").source:gsub("^@", "")
local known, inside = {}, false
for _, line in ipairs(vim.fn.readfile(vim.fn.fnamemodify(here, ":h:h") .. "/health.md")) do
  if line:match("^```noise%s*$") then
    inside = true
  elseif inside and line:match("^```") then
    inside = false
  elseif inside and line ~= "" and not line:match("^#") then
    table.insert(known, line)
  end
end
local function is_known(finding)
  for _, k in ipairs(known) do
    if finding == k or (k:sub(-1) == "*" and finding:sub(1, #k - 1) == k:sub(1, -2)) then
      return true
    end
  end
  return false
end

local seen = _G.__verify_noise or { messages = 0, notify = 0, errmsg = "" }
local findings = {}

local function noisy(text)
  local lower = text:lower()
  return text:find("E%d+:") ~= nil
    or lower:find("error", 1, true) ~= nil
    or lower:find("warn", 1, true) ~= nil
    or lower:find("deprecat", 1, true) ~= nil
    or lower:find("traceback", 1, true) ~= nil
end

local messages = vim.split(vim.api.nvim_exec2("messages", { output = true }).output, "\n", { trimempty = true })
for i = (#messages < seen.messages and 1 or seen.messages + 1), #messages do
  if noisy(messages[i]) then
    table.insert(findings, "messages: " .. messages[i])
  end
end

local history = {}
local has_notify, notify = pcall(require, "notify")
if has_notify then
  history = notify.history()
end
for i = (#history < seen.notify and 1 or seen.notify + 1), #history do
  local n = history[i]
  local text = type(n.message) == "table" and table.concat(n.message, " ") or tostring(n.message)
  local level = tostring(n.level)
  if level == "WARN" or level == "ERROR" or text:lower():find("deprecat", 1, true) then
    table.insert(findings, "notify " .. level .. ": " .. text)
  end
end

local errmsg = vim.v.errmsg
if errmsg ~= "" and errmsg ~= seen.errmsg then
  table.insert(findings, "errmsg: " .. errmsg)
end
_G.__verify_noise = { messages = #messages, notify = #history, errmsg = errmsg }

local noise, known_hits = {}, {}
for _, f in ipairs(findings) do
  if is_known(f) then
    table.insert(known_hits, "KNOWN " .. f)
  else
    table.insert(noise, "NOISE " .. f)
  end
end
local head = ("noise=%d known=%d"):format(#noise, #known_hits)
return table.concat(vim.list_extend(vim.list_extend({ head }, noise), known_hits), "\n")
```

**File:** `.claude/skills/verify-nvim-config/features/lua/load_all.lua` (new)
**Code:**
```lua
-- Loads every lazy.nvim plugin that is not loaded yet, one at a time, through lazy's own loader
-- (what its cmd/ft/keys/event triggers call), and reports what failed or stayed unloaded. No key
-- path loads all of them; this is the sweep's "every plugin loads" step. lazy reports a plugin's
-- config error through vim.notify, so read noise.lua right after.
--   verify.sh lua RUN @.claude/skills/verify-nvim-config/features/lua/load_all.lua
-- Returns "tried=N failed=N unloaded=N" and one line per failure / the names still unloaded.
local lazy = require("lazy")
local tried, failed = 0, {}
for _, plugin in ipairs(lazy.plugins()) do
  if not plugin._.loaded then
    tried = tried + 1
    local ok, err = pcall(lazy.load, { plugins = { plugin.name } })
    if not ok then
      table.insert(failed, "failed " .. plugin.name .. ": " .. tostring(err))
    end
  end
end
local left = {}
for _, plugin in ipairs(lazy.plugins()) do
  if not plugin._.loaded then
    table.insert(left, plugin.name)
  end
end
local lines = { ("tried=%d failed=%d unloaded=%d"):format(tried, #failed, #left) }
vim.list_extend(lines, failed)
if #left > 0 then
  table.insert(lines, "unloaded: " .. table.concat(left, ","))
end
return table.concat(lines, "\n")
```

**File:** `.claude/skills/verify-nvim-config/features/health.md` (new)
**Code:**
~~~~markdown
# Health: the `:checkhealth` allow-list and the sweep's known noise

## Sub-features

- `:checkhealth` runs every health check on the runtimepath: Neovim's own `vim.*` checks and those
  of every loaded plugin. For this config, clean means that every WARNING/ERROR line left is in the
  allow-list below, with the reason it stays. Nothing the config causes, or can fix, is on the list.
- `lua/health_diff.lua` turns the `health://` report into one key per WARNING/ERROR line and
  compares the keys with the list. `unexpected=0` is the pass.
- `lua/noise.lua` reports, after each journey, what the journey printed: new `:messages` lines,
  nvim-notify entries at WARN/ERROR or naming a deprecation, and a changed `v:errmsg`. Entries in
  the known-noise list below are excluded. `noise=0` is the pass.
- `lua/load_all.lua` loads every lazy plugin that is not loaded yet (the sweep's "every plugin
  loads" step).

## How to get to it (user POV)

Run `:checkhealth`, or `:checkhealth <name>` for one check. The report opens in a new tab.

## Driving it with verify.sh

```sh
P=.claude/skills/verify-nvim-config/features/lua
$V lua RUN @$P/noise.lua                  # right after up: noise=0 known=0
$V keys RUN : e Space main.go Enter
$V wait RUN '#vim.lsp.get_clients({bufnr=0, name="gopls"})' 1 90
$V keys RUN : checkhealth Enter
$V wait RUN 'vim.bo.filetype' checkhealth 120
$V lua RUN @$P/health_diff.lua            # sections=20 findings=.. allowed=.. unexpected=0 unused=..
$V keys RUN : tabclose Enter
$V lua RUN @$P/noise.lua                  # noise=0
$V keys RUN : e Space notes.md Enter
$V keys RUN y y                           # a line in the run's tmux buffer (see Gotchas)
$V lua RUN @$P/load_all.lua               # tried=.. failed=0 unloaded=0
$V lua RUN @$P/noise.lua                  # noise=0 known=1 (KNOWN errmsg: E31, from notes.md)
$V keys RUN : checkhealth Enter
$V wait RUN 'vim.bo.filetype' checkhealth 120
$V lua RUN @$P/health_diff.lua            # sections=22 (+ render-markdown, telescope) ... unexpected=0
```

This set's lever `.workflows/plan/nvim-0-12-clean/phase-4-health.sh seeded|live` runs this whole
block, plus the startup and true-colour checks, and exits 1 on any failure.

A key has the form `<section>[ / <subsection>]: <LEVEL> <message>`. A message that ends in `:`
takes its first indented continuation line, so the `targets` keys name the mapping and the
`snacks` keys name the missing languages. An entry that ends in `*` matches every key that starts
with the text before the `*`. `UNUSED` entries are information only, because what is reported
depends on the mode (live Mason has more servers enabled than the seed) and on what is loaded.

## The allow-list

Each block below is one group, with one origin and one reason. The probes read every line inside
the ```` ```allow ```` fences; a line that starts with `#` is a comment.

**Optional tools the owner never installed** (environment-only; installing them is out of scope).
- snacks enables only `input` and `picker` (`plugin_specs.lua`). Its other modules report
  `setup {disabled}` by design.
- snacks `image`/`lazygit`/`picker`, telescope, fzf-lua, diffview and Mason list tools that are
  absent on this machine as well as in the run. `command -v` finds none of kitty, wezterm,
  ghostty, magick, convert, gs, mmdc, lazygit, fd, fdfind, hg, viu, chafa, ueberzugpp, luarocks,
  composer, php, javac or julia.
- The owner's terminal does not speak the kitty graphics protocol.
- The treesitter languages snacks would use (`latex`, `norg`, `scss`, `svelte`, `tsx`, `typst`,
  `vue`, `regex`) are not among the 13 that `config/treesitter.lua` installs.

```allow
snacks / Snacks.bigfile: WARNING setup {disabled}
snacks / Snacks.dashboard: WARNING setup {disabled}
snacks / Snacks.explorer: WARNING setup {disabled}
snacks / Snacks.image: WARNING setup {disabled}
snacks / Snacks.notifier: WARNING setup {disabled}
snacks / Snacks.quickfile: WARNING setup {disabled}
snacks / Snacks.scope: WARNING setup {disabled}
snacks / Snacks.scroll: WARNING setup {disabled}
snacks / Snacks.statuscolumn: WARNING setup {disabled}
snacks / Snacks.words: WARNING setup {disabled}
snacks / Snacks.notifier: ERROR is not ready
snacks / Snacks.image: ERROR None of the tools found: 'kitty', 'wezterm', 'ghostty'
snacks / Snacks.image: ERROR None of the tools found: 'magick', 'convert'
snacks / Snacks.image: ERROR `magick` is required to convert images. Only PNG files will be displayed.
snacks / Snacks.image: WARNING Missing Treesitter languages: `latex`, `norg`, `scss`, `svelte`, `tsx`, `typst`, `vue`
snacks / Snacks.image: WARNING Image rendering in docs with missing treesitter parsers won't work
snacks / Snacks.image: ERROR Tool not found: 'gs'
snacks / Snacks.image: WARNING `gs` is required to render PDF files
snacks / Snacks.image: WARNING The `latex` treesitter parser is required to render LaTeX math expressions
snacks / Snacks.image: ERROR Tool not found: 'mmdc'
snacks / Snacks.image: WARNING `mmdc` is required to render Mermaid diagrams
snacks / Snacks.image: ERROR your terminal does not support the kitty graphics protocol
snacks / Snacks.lazygit: ERROR {lazygit} not installed
snacks / Snacks.picker: WARNING Missing Treesitter languages: `regex`
snacks / Snacks.picker: ERROR None of the tools found: 'fd', 'fdfind'
snacks / Snacks.picker: ERROR 'fd' `v8.4` is required for searching with `Snacks.picker.explorer()`
telescope / Checking external dependencies: WARNING fd: not found. Install [sharkdp/fd](https://github.com/sharkdp/fd) for extended capabilities
fzf_lua / fzf-lua [optional:media]: WARNING 'viu' not found
fzf_lua / fzf-lua [optional:media]: WARNING 'chafa' not found
fzf_lua / fzf-lua [optional:media]: WARNING 'ueberzugpp' not found
diffview / Checking VCS tools: WARNING Configured `hg_cmd` is not executable: 'hg'
mason / mason.nvim [Languages]: WARNING luarocks: not available
mason / mason.nvim [Languages]: WARNING Composer: not available
mason / mason.nvim [Languages]: WARNING PHP: not available
mason / mason.nvim [Languages]: WARNING javac: not available
mason / mason.nvim [Languages]: WARNING julia: not available
```

**go.nvim's optional extras** (environment and upstream; recorded per phase 1's handoff, measured
once the go check stopped crashing).
- `treesitter parser <x> is optional but it is not found`: go.nvim's optional parsers (`gowork`,
  `gomod`, `gosum`, `sql`, `gotmpl`, `comment`, `json`) are not all among the 13 that
  `treesitter.lua` installs. `json` is installed, so its entry is normally `UNUSED`.
- Any missing parser also triggers the summary `Some binaries are not installed …`
  (`go/health.lua:122`, `no_err = false`); every Go tool itself is found.
- `nvim-treesitter main module loaded, WIP` is go.nvim's own label for nvim-treesitter `main`
  (`health.lua:154`), not a fault.
- `GOBIN is not in PATH`: neither the owner nor the run sets `GOBIN` (`go env GOBIN` is empty), and
  go.nvim's `path_check` (`health.lua:240`) warns whenever it is unset.
- Not on the list but still upstream: go.nvim `health.lua:58` calls `vim.system` without an
  `executable()` guard and crashes the whole check when `golangci-lint` is missing. It is
  unreachable now that phase 1 puts the Go tools on `run_path`. A ❌ there is `UNEXPECTED`, as it
  should be.

```allow
go / Binaries: WARNING treesitter parser gowork is optional but it is not found*
go / Binaries: WARNING treesitter parser gomod is optional but it is not found*
go / Binaries: WARNING treesitter parser gosum is optional but it is not found*
go / Binaries: WARNING treesitter parser sql is optional but it is not found*
go / Binaries: WARNING treesitter parser gotmpl is optional but it is not found*
go / Binaries: WARNING treesitter parser comment is optional but it is not found*
go / Binaries: WARNING treesitter parser json is optional but it is not found*
go / Binaries: WARNING Some binaries are not installed, please check if your $HOME/go/bin or $GOBIN $exists and in your $PATH
go / Go Plugin Check: WARNING nvim-treesitter main module loaded, WIP
go / Go Plugin Check: WARNING GOBIN is not in PATH
```

**The run's fence** (environment-only; these never show in the owner's own nvim).
- `cargo` lives in `~/.cargo/bin`, a per-user dir that `run_path` leaves out on purpose
  (SKILL.md). The owner's nvim finds it.
- PyPI is unreachable because no run has network (`unshare -n`). Online, the provider check
  reports pynvim's latest version instead.

```allow
mason / mason.nvim [Languages]: WARNING cargo: not available
vim.provider / Python 3 provider (optional): WARNING Could not contact PyPI to get latest version.
vim.provider / Python 3 provider (optional): ERROR HTTP request failed: error: curl error with https://pypi.org/pypi/pynvim/json: 6
```

**Upstream-only** (nvim-lspconfig).
- The default `filetypes` of gopls (`gotmpl`), ts_ls (`javascript.jsx`, `typescript.tsx`) and
  yamlls (`yaml.docker-compose`, `yaml.gitlab`, `yaml.helm-values`) name compound filetypes that
  Neovim 0.12 does not know.
- Overriding `filetypes` in `after/lsp/*.lua` would only hide the check and drift from upstream's
  defaults.
- ts_ls is enabled only where Mason has it (the owner's live Mason), so its two lines are
  `UNUSED` on a seeded run.

```allow
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'gotmpl' (Hint: filename extension != filetype).
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'javascript.jsx' (Hint: filename extension != filetype).
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'typescript.tsx' (Hint: filename extension != filetype).
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'yaml.docker-compose' (Hint: filename extension != filetype).
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'yaml.gitlab' (Hint: filename extension != filetype).
vim.lsp / Enabled Configurations: WARNING Unknown filetype 'yaml.helm-values' (Hint: filename extension != filetype).
```

**The owner's deliberate mappings** (intentional; changing them would change behaviour).
- targets.vim reports the `iB` buffer text object (`text_obj#Buffer`) and vim-sandwich's
  `ab`/`ib`, which take those keys before targets.
- which-key lists every prefix that also has longer mappings. Its own report says the overlaps
  are "for informational purposes only".
- The overlap lists come in no fixed order, so each entry matches only up to `overlaps with`.
- A new prefix with overlaps is still reported as `UNEXPECTED`.

```allow
targets: WARNING Conflicting mapping found: iB → :<C-U>call text_obj#Buffer()<CR>
targets: WARNING Conflicting mapping found: ab → <Plug>(textobj-sandwich-auto-a)
targets: WARNING Conflicting mapping found: ib → <Plug>(textobj-sandwich-auto-i)
which-key / checking for overlapping keymaps: WARNING In mode `n`, <c> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <sr> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <sd> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <,b> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <,s> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <gc> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <,gt> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <,gp> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <gr> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <\> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `n`, <^> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `x`, <a> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `x`, <i> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `x`, <@> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `o`, <a> overlaps with*
which-key / checking for overlapping keymaps: WARNING In mode `o`, <i> overlaps with*
```

**Informational, always printed.** blink.cmp v1's `health.lua` calls `vim.health.warn` for this
line unconditionally, whatever the config.

```allow
blink.cmp / Sources: WARNING Some providers may show up as "disabled" but are enabled dynamically (e.g. cmdline)
```

## Known noise (`noise.lua`)

**Silent, upstream-only.** Opening a markdown buffer sets `v:errmsg` to `E31: No such mapping`.
1. Neovim 0.12's `ftplugin/markdown.vim` and `ftplugin/markdown.lua` both append
   `nunmap <buffer> ]]` / `[[` to `b:undo_ftplugin`.
2. After lazy.nvim's `ft` handler loads the `ft = "markdown"` plugins (render-markdown, tabular,
   vim-markdownfootnotes), it fires `FileType` a second time.
3. The undo runs, and the second `sil! nunmap` of the same map fails.

`sil!` keeps the error off the screen and out of `:messages`. Nothing is lost, because the
ftplugins map both keys again.

```noise
errmsg: E31: No such mapping
```

## Fixed by this set (none of these is on the list; they must never come back)

| Section | Was | Fix |
|---|---|---|
| `vim.deprecated` | `vim.highlight` and `vim.validate{<table>}` from git-conflict.nvim; blink v0.14's `client.request` | phase 3: `stryukovsky/git-conflict.nvim@63c5b42`, blink.cmp v1.10.2 |
| `go` | ❌ `Failed to run healthcheck` (golangci-lint ENOENT) + 19 `Missing tool` | phase 1: go.nvim's tool dir on `run_path` (affected runs only; the owner's nvim always had the tools) |
| `fidget` | `nvim-tree.lua integration is implicitly enabled` | phase 2: `config/fidget-nvim.lua` (`notification.window.avoid = { "NvimTree" }` in `setup`, then the `fidget.integration.nvim-tree` module's `options.enable = false` after setup; passing the integration option to `setup` re-warns as deprecated) |
| `vim.health / tmux` | `True color support could not be detected` | phase 4: `tmux_conf_24b_colour=true` in `.tmux.conf.local` (tmux-bindings.md) |
| `render-markdown` | `latex`/`yaml` parser not installed, `ABI: unknown` ×2, no latex converter (5 warnings, once a markdown file loaded it) | phase 4: `opts = { latex = { enabled = false }, yaml = { enabled = false } }` (neither ever rendered: no parser, no converter) |
| `blink.cmp` | v0.14's version of the informational line (`i.e.` instead of `e.g.`) | phase 3: v1.10.2 |

## Gotchas

- `:checkhealth` lists only the plugins whose `health.lua` is on the runtimepath, i.e. the loaded
  ones. `render-markdown` and `telescope` appear only after a markdown file or `load_all.lua`, so
  run the comparison in both states.
- `load_all.lua` in a fresh run prints `clipboard: error: no buffers` (WarningMsg):
  1. yanky.nvim reads the `+` register on setup (`clipboard=unnamedplus`).
  2. The run's fresh tmux server has no paste buffer, and nvim's tmux clipboard provider fails on
     the read.

  The owner's long-lived tmux server has buffers. Yank a line first with `y y`.
- A full `:checkhealth` runs blink's source health, which sends an LSP request. Before blink v1
  that printed `client.request is deprecated`.
- A new WARNING/ERROR after a change is a finding. Fix it when the config causes it. Otherwise add
  it to the right group above, with its origin and reason, in the same change.
- Never allow a whole section (`snacks*`): each entry names one line.
~~~~

**The go.nvim entries are provisional (reconciled).** The ten `go / …` entries in health.md's go `allow` block were written from reading go.nvim
`4755def`'s `lua/go/health.lua`, **not measured**: on the base the go check crashed before it
printed them. After phase 1 lands (Go tools on `run_path`), the first `health-lsp` run of Step 2
shows the real lines. Correct each entry's text (section, subsection, message, trailing `*`) to
the measured report, in both modes, before recording Step 2. Such a correction is **not a fix
and not a finding**: it makes the recorded line match what go.nvim prints. A measured go line
outside these four groups (optional parsers, the `Some binaries` summary, `main module loaded,
WIP`, `GOBIN is not in PATH`), or any go `ERROR`, is a finding under Step 6's rules. Write the
correction in evidence-phase-4.md § Findings as "allow-list text corrected (not a finding)".

**File:** `.workflows/plan/nvim-0-12-clean/phase-4-health.sh` (new, `chmod +x`)
**Code:**
```bash
#!/usr/bin/env bash
# Phase 4 lever (nvim-0-12-clean). In one run of the given mode it checks:
#   - doctor, startup :messages, v:errmsg and noise;
#   - tmux true colour;
#   - :checkhealth against features/health.md, with gopls attached and again once every lazy
#     plugin is loaded;
#   - that every plugin loads.
# Run it from a repo root (a worktree or ~/.config/nvim). It prints one "check <name> PASS|FAIL
# <detail>" line per check, then RUN= and EVIDENCE=, and exits 1 on any FAIL. KEEP=1 leaves the
# run up; by default it is taken down.
#   .workflows/plan/nvim-0-12-clean/phase-4-health.sh seeded|live
set -uo pipefail
case "${1:-}" in
  seeded) up_args=() ;;
  live) up_args=(--live) ;;
  *) echo "usage: $0 seeded|live" >&2; exit 2 ;;
esac
V=.claude/skills/verify-nvim-config/scripts/verify.sh
P=$PWD/.claude/skills/verify-nvim-config/features/lua
VH=$HOME/.local/state/nvim-config-verify
[ -x "$V" ] && [ -f "$P/health_diff.lua" ] || { echo "run from the repo root (needs $V and $P)" >&2; exit 2; }

fail=0
check() { if [ "$2" = 1 ]; then echo "check $1 PASS $3"; else echo "check $1 FAIL $3"; fail=1; fi; }
yes_if() { if "$@"; then echo 1; else echo 0; fi; }
val() { "$V" lua "$RUN" "$1" 2>/dev/null | tail -n +2; }   # result lines, without the "> lua:" echo
first() { val "$1" | sed -n 1p; }

health() {   # $1 = check name, $2 = minimum number of sections
  local res head n min=$2   # $2 must not be read inside yes_if's eval (that would be yes_if's own $2)
  "$V" keys "$RUN" : checkhealth Enter >/dev/null 2>&1
  if ! "$V" wait "$RUN" 'vim.bo.filetype' checkhealth 120 >/dev/null 2>&1; then
    check "$1" 0 "no complete checkhealth report after 120 s"
    return
  fi
  res=$(val "@$P/health_diff.lua")
  head=$(sed -n 1p <<<"$res")
  n=${head#sections=}; n=${n%% *}
  check "$1" "$(yes_if eval '[ "${n:-0}" -ge "$min" ] && [[ $head == *" unexpected=0 "* ]]')" "$head"
  grep '^UNEXPECTED' <<<"$res" | sed 's/^/    /'
  "$V" keys "$RUN" : tabclose Enter >/dev/null 2>&1
}

out=$("$V" up "${up_args[@]}") || { echo "$out"; echo "up failed" >&2; exit 1; }
echo "$out"
RUN=$(sed -n 's/^RUN=//p' <<<"$out")
E=$VH/$RUN/evidence
grep -E '^(filled|replaced)_from_seed=' "$VH/$RUN/meta" || true

"$V" doctor "$RUN" >"$E/phase4-doctor.txt" 2>&1; rc=$?
check doctor "$(yes_if [ "$rc" = 0 ])" "exit $rc ($E/phase4-doctor.txt)"
check startup-messages "$(yes_if [ -z "$(tr -d '[:space:]' <"$E/00-up-messages.txt")" ])" "$E/00-up-messages.txt"
r=$(first 'vim.v.errmsg == ""')
check errmsg "$(yes_if [ "$r" = true ])" "vim.v.errmsg empty: $r"
r=$(first "@$P/noise.lua")
check noise-startup "$(yes_if eval '[[ $r == noise=0* ]]')" "$r"

r=$(first 'vim.trim(vim.fn.system({ "tmux", "show-options", "-gv", "terminal-overrides" }))')
check tc-override "$(yes_if eval '[[ $r == *"*256col*:Tc"* ]]')" "terminal-overrides: ${r:-<empty>}"
r=$(first '#vim.tbl_filter(function(l) return l:find(" setrgb[bf]: %(string%)") ~= nil end, vim.split(vim.fn.system({ "tmux", "show-messages", "-T" }), "\n"))')
check tc-rgb "$(yes_if [ "${r:-0}" -ge 2 ] 2>/dev/null)" "setrgbb/setrgbf lines in show-messages -T: ${r:-0}"

"$V" keys "$RUN" : e Space main.go Enter >/dev/null 2>&1
"$V" wait "$RUN" '#vim.lsp.get_clients({bufnr=0, name="gopls"})' 1 90 >/dev/null 2>&1; rc=$?
check gopls "$(yes_if [ "$rc" = 0 ])" "gopls attached to main.go"
health health-lsp 20
r=$(first "@$P/noise.lua")
check noise-health "$(yes_if eval '[[ $r == noise=0* ]]')" "$r"

"$V" keys "$RUN" : e Space notes.md Enter >/dev/null 2>&1
"$V" keys "$RUN" y y >/dev/null 2>&1
r=$(val "@$P/load_all.lua"); h=$(sed -n 1p <<<"$r")
check load-all "$(yes_if eval '[[ $h == *" failed=0 unloaded=0" ]]')" "$h"
"$V" wait "$RUN" '#require("lazy").plugins() == require("lazy").stats().loaded' true 30 >/dev/null 2>&1 || true
r=$(val "@$P/noise.lua")
check noise-load-all "$(yes_if eval '[[ $(sed -n 1p <<<"$r") == noise=0* ]]')" "$(tr '\n' ' ' <<<"$r")"
health health-all-loaded 22
r=$(first "@$PWD/.claude/skills/verify-nvim-config/features/lua/deprecations.lua")   # phase 3's probe, cumulative
check deprecations "$(yes_if [ "$r" = 0 ])" "deprecation/blink-fallback notices so far: $r"

echo "RUN=$RUN"
echo "EVIDENCE=$E"
[ "${KEEP:-0}" = 1 ] || "$V" down "$RUN" >/dev/null 2>&1
exit "$fail"
```
`yes_if` runs one command and prints 1/0. `[[ … ]]` is syntax, not a command, so those tests go
through `eval` with the pattern in single quotes; `[ … ]` is the `test` builtin and needs no
`eval`. The `wait` after `load_all` is only a settle point (`|| true`): lazy's `stats().loaded` can
differ from the plugin count when a spec is `enabled = false`, so it is not an assertion.

**Verify Step 1:** `bash -n .workflows/plan/nvim-0-12-clean/phase-4-health.sh` exits 0, and
`grep -c '^```allow' $F/health.md` prints `6`.
**Impact:** no config change. The probes are read-only, apart from `noise.lua`'s `_G.__verify_noise`
cursor and `load_all.lua`'s plugin loads.

### Step 2: Before (must fail): the lever on the phase-3 tip, both modes
**Change:** none. This step records evidence.
**Code:**
```bash
cd /home/miftah/.worktrees/nvim/nvim-0-12-clean
.workflows/plan/nvim-0-12-clean/phase-4-health.sh seeded | tee /tmp/claude-phase4-before-seeded.txt
.workflows/plan/nvim-0-12-clean/phase-4-health.sh live   | tee /tmp/claude-phase4-before-live.txt
```
(Use the session scratchpad dir instead of `/tmp` when the runner has one.) Expected, both modes:
- FAIL: `tc-override` (`<empty>`), `tc-rgb` (`0`), `health-lsp` (`unexpected=1`: `vim.health / tmux:
  WARNING True color support could not be detected…`), and `health-all-loaded` (`unexpected=6`:
  vim.health tmux + the 5 render-markdown keys).
- PASS: every other check (phases 1-3 fixed go, fidget, vim.deprecated, E216 and blink).

An `UNEXPECTED go / …` key that is one of the four go.nvim groups with different wording is the
allow-list text correction described after the health.md block in Step 1 (correct the entry,
re-run; not a finding). Any other FAIL is a regression from phases 1-3 or a new finding. Treat it
as in Step 6, rule (b), before continuing. Copy both outputs, with their `RUN=`, into evidence-phase-4.md § Before.

### Step 3: tmux true colour
**File:** `.tmux.conf.local:18`
**Change:** `auto` → `true`. oh-my-tmux's `_apply_24b` then appends `,*256col*:Tc` to
`terminal-overrides` at server start (the client terminal is `xterm-256color`).
**Code:** line 18 becomes exactly:
```
tmux_conf_24b_colour=true
```
**Impact:** every tmux server started with this file advertises RGB for `*256col*` clients. In the
verify runs this applies from the next `up` (never `sync`). For the owner it applies from the next
server start after Deploy D4. The running server is never contacted. Colour themes in nvim render
in 24-bit instead of being downsampled to 256 colours.

### Step 4: render-markdown latex/yaml off (sweep finding, config-side)
**File:** `lua/plugin_specs.lua:129-136` as it stands after phase 3 (base `:128-135`; phase 3's
blink.cmp hunk above it adds one line). Anchor on the text: the `MeanderingProgrammer/markdown.nvim`
spec, which phase 3 does not touch.
**Change:** set the two features that cannot work here to disabled. Nothing visible changes: there
is no `latex`/`yaml` parser and no latex converter, live or seeded. This removes 5 health warnings
that show as soon as a markdown buffer loads the plugin.
**Old** (post-phase-3 `:129-136`, identical to `9cea538`'s `:128-135`):
```lua
  -- Simplified markdown rendering
  {
    "MeanderingProgrammer/markdown.nvim",
    main = "render-markdown",
    name = "render-markdown", -- let's use the same name as the main file for clarity
    ft = "markdown",
    opts = {}, -- The defaults are sane. Stop over-configuring.
  },
```
**New:**
```lua
  -- Simplified markdown rendering
  {
    "MeanderingProgrammer/markdown.nvim",
    main = "render-markdown",
    name = "render-markdown", -- let's use the same name as the main file for clarity
    ft = "markdown",
    -- latex/yaml need parsers config/treesitter.lua does not install (and latex a converter):
    -- they never rendered, only warned in :checkhealth. Re-enable together with those parsers.
    opts = { latex = { enabled = false }, yaml = { enabled = false } },
  },
```
**Impact:** `:checkhealth render-markdown` has no warnings. Markdown rendering itself (headings,
code blocks, lists via the `markdown`/`markdown_inline`/`html` parsers) is unchanged; the sweep's
treesitter.md/notes.md journeys prove it.

### Step 5: After: the lever, both modes (must pass)
**Code:**
```bash
cd /home/miftah/.worktrees/nvim/nvim-0-12-clean
.workflows/plan/nvim-0-12-clean/phase-4-health.sh seeded
.workflows/plan/nvim-0-12-clean/phase-4-health.sh live
```
**Pass:** every `check` line says PASS and both exit 0. `tc-override` shows `*256col*:Tc`,
`tc-rgb` shows `2`, `health-lsp` shows `sections=20 … unexpected=0`, and `health-all-loaded` shows
`sections=22 … unexpected=0`. Record both outputs and RUN ids in evidence-phase-4.md § After.

### Step 6: The full sweep, both modes
**Change:** re-drive every journey; fix new config-side findings.

**Procedure.** For each mode (`up --live`, then `up`), do the following:
1. `up`, then run `doctor` and `lua RUN @$F/lua/noise.lua`. The first call is the baseline and
   must say `noise=0`.
2. Drive **every** fenced journey block in each file below, exactly as the file stands after
   phases 1-3. Where a block starts with its own `$V up`, use that new run and repeat the step-1
   baseline in it.
3. Compare each block's end state with the file's "End state seen".
4. After each block, run `$V lua RUN @$F/lua/noise.lua` and phase 3's
   `$V lua RUN @$F/lua/deprecations.lua`. The latter is cumulative and must stay `0`: it also
   catches blink's "Lua implementation" / "pre-built binary" fallback notices, which are INFO level
   and so pass `noise.lua`.
5. `down` every run.
6. Record one row per block × mode in evidence-phase-4.md § Sweep: file, block, end state
   matched (yes / no + what differed), the noise line, and the evidence path.

| File | Blocks | Modes | Expected noise (not a finding) |
|---|---|---|---|
| `startup.md` | `up`+doctor+stats; Mason offline; gofumpt-missing fault injection (`--live` only); `--bare`; broken lazy dir; deleted working directory (`9cea538`); phase 1's PATH/sync/doctor subsection (incl. its fault injection); phase 2's `v:errmsg` + directory hijack subsection | both (`--bare`/broken-lazy once: they ignore the mode) | gofumpt fault injection: `notify …: gofumpt: failed to install` (its asserted end state); deleted working directory: `NOISE notify WARN: working directory <WORK>/gone was deleted, now in <WORK>` (its asserted end state); phase 1's PATH fault injection: doctor `path FAIL`, exit 1 (asserted; run it last in its run, or `down` after it) |
| `dashboard.md` | start screen; behind nvim-tree; leaving/split | both | none (`Switched to:` is INFO) |
| `format-on-save.md` | valid lua; syntax error line 1; syntax error further down; cursor clamp; Go; Python | both | the two syntax-error blocks: `NOISE notify WARN: stylua failed, buffer left unformatted: …` (their asserted end state) |
| `lsp.md` | attach lua/go/py + pyright diagnostic; phase 2's CursorHold float (incl. `:2vsplit`); phase 2's fidget health; phase 3's completion | both | none |
| `treesitter.md` | highlight/indent/vaf/gnn-grn-grm/`==`/vac-vic (cls.py) | both | `KNOWN errmsg: E31` once a markdown buffer is opened |
| `editing-mappings.md` | `V H` jq; `C-o` paths; hop `f`/`F`/Escape | both | none |
| `fzf-lua.md` | `,ff` → guide | both | none |
| `git.md` | `,ga`/`,gc`/`,gp` to the run's bare remote; phase 3's conflict journey (`co`/`ct`/`]x`, qf refresh), last in its run or in its own run (it leaves WORK mid-merge, git.md Gotchas) | both | `KNOWN errmsg: E31` (notes.md) |
| `tmux-bindings.md` | `C-b -`, `C-b @`, `C-b -`, `C-b !`, doctor; true colour (Step 7) | both | none |
| `img2braille.md` | script → `,bv` → `,b` | both | none |
| `live-environment.md` | `live`, `up --live`, doctor | live | none |
| `health.md` | the whole "Driving" block (the lever already ran it; drive it by hand once per mode) | both | `KNOWN errmsg: E31` |

**Finding rules** (any `NOISE` line not in the "Expected" column, any end state that differs, any
`UNEXPECTED` key):
- **(a) Config-side** (the cause is a line in `init.lua`, `lua/`, `after/`, `plugin/`,
  `viml_conf/` or `.tmux.conf.local`): fix it with the smallest config change. That change must
  not move a plugin (no url/branch/version/commit/build edit) and must not change a mapping. Then:
  1. Record the repro and the cause line first (failure-first).
  2. Show before/after on both modes (the `git stash` → `sync` recipe in SKILL.md).
  3. Update the matching `features/*.md` end state in the same commit.
  4. Record it in evidence-phase-4.md § Findings.
  Step 4 is the one case measured while planning.
- **(b) Upstream-only or environment-only:**
  1. Trace it to the plugin/runtime line or the environment cause.
  2. Add it to `health.md`, under an existing or new group in an ```` ```allow ```` block (health
     lines) or a ```` ```noise ```` block (messages/notify/errmsg). State its origin and why it
     stays.
  3. Record it in evidence-phase-4.md § Findings.

  Never allow a whole section or a bare `*`.
- **(c) A plugin move would fix it:** out of scope (index: "no plugin moves"). Record it as (b),
  with the upstream fix named, and list it in evidence-phase-4.md § Handoffs for a future set.
- **(d) A verify.sh bug:** fix it in `verify.sh` only if the sweep cannot be driven otherwise.
  Record it in evidence-phase-4.md, and mention it in the return summary for the reconciler
  (phase 1 owns verify.sh).

Already classified while planning:
- `clipboard: error: no buffers` (b, run-only, avoided by `y y`; health.md Gotchas).
- `E31` on markdown (b, ```` ```noise ````).
- render-markdown (a, Step 4).
- blink `client.request` after checkhealth (R2, phase 3; must be gone).

**Exit for this step:** every row "matched yes" with `noise=0` or only its Expected noise, in both
modes; § Findings lists every finding with its class and disposition.

### Step 7: `features/tmux-bindings.md` (rewrite)
**File:** `.claude/skills/verify-nvim-config/features/tmux-bindings.md` (whole file, 38 lines today)
**Before/after evidence:** drive the true-colour block below once on a run started **before** Step 3
(or take Step 2's `tc-*` lines) and once after. Both go into evidence-phase-4.md § True colour.
**Code:**
~~~~markdown
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

End states seen (seeded and `--live`, 2026-11-04): `*256col*:Tc`, `2`, `0`. On the base
(`tmux_conf_24b_colour=auto`) they were empty, `0`, and the line number of the warning.

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
~~~~
**Impact:** doc only. If a measured value differs, write the measured one and note it in
evidence-phase-4.md.

### Step 8: `features/README.md` (rewrite)
**File:** `.claude/skills/verify-nvim-config/features/README.md` (whole file)
**Code** (replace `{{LIVE_HEAD}}` with `git -C ~/.config/nvim rev-parse --short HEAD` at sweep time):
~~~~markdown
# Feature map: verify-nvim-config

One file per feature the owner touches. Each file holds proven recipes and the end states they
produced on 2026-11-04, on Neovim 0.12.6 (checkout `feature/nvim-0-12-clean` after phases 1-4 of
nvim-0-12-clean; live `{{LIVE_HEAD}}`), in both `up` and `up --live`. No drive costs money and none
goes online. After every journey the sweep read `lua/noise.lua` (`noise=0`), and full
`:checkhealth` minus the allow-list in [health.md](health.md) was empty, both with gopls attached
and with every plugin loaded.

| Feature | File | Surfaces | Known on the base (`8bcb55c`) |
|---|---|---|---|
| Startup and run modes | [startup.md](startup.md) | `up`, `sync`, `doctor`, `lua`, `headless` | fixed: `sync` respawned nvim with the caller's PATH (R1; doctor now has a `path` line); `v:errmsg` held `E216: No such group or event: FileExplorer *` after startup (R5) |
| Dashboard / ASCII art | [dashboard.md](dashboard.md) | `keys`, `lua @dashboard_art.lua` | none |
| Format and check on save | [format-on-save.md](format-on-save.md) | `keys`, `cli git diff`, `lua` | none |
| LSP | [lsp.md](lsp.md) | `keys`, `wait`, `lsp.log`, `lua @deprecations.lua` | fixed: `client.request is deprecated` on completion (R2, blink.cmp v1.10.2); CursorHold float "Invalid 'width'" in a 2-column window (R3); fidget's implicit nvim-tree integration |
| Treesitter | [treesitter.md](treesitter.md) | `keys`, `lua` | none |
| Editing mappings (incl. hop `f`/`F`) | [editing-mappings.md](editing-mappings.md) | `keys`, `lua`, `screen` | none |
| fzf-lua pickers | [fzf-lua.md](fzf-lua.md) | `keys`, `wait` | none |
| Git mappings (incl. git-conflict) | [git.md](git.md) | `keys`, `cli git`, `lua @deprecations.lua` | fixed: git-conflict.nvim's `vim.highlight` / `vim.validate{}` deprecations (R4, `stryukovsky` fork `63c5b42`) |
| tmux bindings (incl. true colour) | [tmux-bindings.md](tmux-bindings.md) | `tmux`, `panes`, `lua` | fixed: no true colour in tmux (`tmux_conf_24b_colour=auto`, no `COLORTERM`) |
| img2braille | [img2braille.md](img2braille.md) | `cli`, `keys`, `lua` | none |
| Health and the sweep | [health.md](health.md) | `keys`, `lua @health_diff.lua`, `@noise.lua`, `@load_all.lua` | fixed: render-markdown `latex`/`yaml` warnings; recorded: the allow-list, `E31` in `v:errmsg` on markdown buffers (upstream) |
| Live environment | [live-environment.md](live-environment.md) | `up --live`, `live`, `doctor` | live lags this set until Deploy (`blink.cmp`, `git-conflict.nvim` replaced from seed; `~/.tmux.conf.local` differs) |

A change to what a feature does updates its file in the same change. A new `:checkhealth`
WARNING/ERROR, or a new line from `noise.lua`, is either fixed or recorded in health.md with its
reason.
~~~~

### Step 9: `features/live-environment.md` (rewrite)
**File:** `.claude/skills/verify-nvim-config/features/live-environment.md` (whole file)
**Code** (replace `{{LIVE_HEAD}}` as in Step 8; write any differing measured value instead of the
expected one):
~~~~markdown
# Live environment

## Sub-features

- `up --live`: the checkout's config on a **copy** of the owner's live plugins
  (`~/.local/share/nvim/lazy`), Mason tools, lock (`~/.config/nvim/lazy-lock.json`), cached
  dashboard art and oh-my-tmux, in the same fenced run.
- `live [RUN]`: read-only drift report between `~/.config/nvim` and this checkout, and the deploy
  command the owner would run.

## How to get to it (user POV)

The owner deploys with `git -C ~/.config/nvim fetch origin &&
git -C ~/.config/nvim merge --ff-only origin/main` (plain `git pull` fails in that checkout:
"Cannot fast-forward to multiple branches") and restarts nvim. These two commands answer "what
will that change, and will it work on my machine?" first.

## Driving it with verify.sh

```sh
$V live                      # or: $V live RUN (saved into that run's evidence)
$V up --live                 # MODE=live, ~7 s
$V doctor RUN                # live ok ... unchanged since up; live info live checkout @ {{LIVE_HEAD}}, ... replaced from seed (spec moved): blink.cmp git-conflict.nvim
$V lua RUN @.claude/skills/verify-nvim-config/features/lua/noise.lua   # noise=0 known=0
```

End state seen with `live` (2026-11-04, before Deploy):
- Live `{{LIVE_HEAD}}`; the checkout is `feature/nvim-0-12-clean` with this set's commits, which
  the live checkout lacks.
- The files that differ are the set's: `lua/plugin_specs.lua`, `lua/config/blink-cmp.lua`,
  `lua/config/nvim-tree.lua`, `lua/config/fidget-nvim.lua`, `lua/diagnostic-conf.lua`,
  `.tmux.conf.local`, plus `.workflows/`.
- `~/.tmux.conf.local DIFFERS from checkout's`: the checkout sets `tmux_conf_24b_colour=true`.
- The last line is the deploy command.

Before Deploy, `replaced_from_seed` is exactly `blink.cmp git-conflict.nvim`:
- blink.cmp because the seed lock pins `78336bc` (v1.10.2), which is not live HEAD (`485c034`,
  v0.14.2) or an ancestor of it.
- git-conflict.nvim because the seed dir's `origin` is
  `https://github.com/stryukovsky/git-conflict.nvim.git` and the live dir's is `akinsho`'s.

`evidence/00-up-replaced.txt` shows live's and the seed's branch, commit and url for both. It has
no `+ site/...` line, because `PLUGIN_EXTRA_DATA` names nothing for them. blink's prebuilt fuzzy
library (`target/release/libblink_cmp_fuzzy.so`, its `.sha256` and `version`) comes with the
seed's plugin dir. `filled_from_seed` is empty.

After Deploy (the runbook in `.workflows/plan/nvim-0-12-clean/phase-4.md`):
- `replaced_from_seed` and `filled_from_seed` are empty, and there is no `00-up-replaced.txt`.
- `live` reports `commits in the checkout that live lacks (0)` and
  `~/.tmux.conf.local == checkout's`.

On `--live`, every journey in this directory gave the same end state as seeded, and `noise.lua`
printed `noise=0` after each (health.md). The full `:checkhealth` minus the allow-list was empty,
both with gopls attached and with every plugin loaded. No file in the run's Mason copy still named
`~/.local/share/nvim` (`grep -rIlF "$HOME/.local/share/nvim" <run>/xdg/data/nvim/mason` printed 0).

## Gotchas

- Always read-only:
  - `--live` copies with `cp -a`, never hard links, because the owner's files are writable.
  - `live` uses `git --no-optional-locks` so `git status` cannot refresh the live index.
  - `doctor`/`down` compare a fingerprint of the live config, plugin and Mason dirs and the tmux
    files; `down` writes `live-at-down.txt`.
- Only `lazy/`, `mason/`, `site/` (treesitter parsers and query links) and `rplugin.vim` are
  copied. `avante/`, `backup/` and `telescope_history` in `~/.local/share/nvim` are private state
  and stay where they are.
- A live plugin is replaced from the seed (`replaced_from_seed`, details in
  `evidence/00-up-replaced.txt`) when the seed moved it in one of these ways:
  - another branch or remote than the live lock/dir;
  - a seed lock commit that the live checkout does not contain, neither as HEAD nor as an ancestor
    (a bump written into the seed lock). This is `live_lacks_seed_commit` in `verify.sh`. A live
    clone that merely has the object, as blink.cmp's had, still counts as moved.

  A replaced plugin brings its seed lock entry and whatever `PLUGIN_EXTRA_DATA` in `verify.sh`
  names for it (nvim-treesitter: `site/parser`, `site/parser-info`, `site/queries`).
- A plugin the checkout adds is not in the live dirs: it comes from the seed and is listed in
  `filled_from_seed` (run `seed` first). Live nvim would fetch it online on its next start.
- `--live` uses the owner's oh-my-tmux (`~/.tmux.conf` → `~/.tmux/.tmux.conf`) with the
  **checkout's** `.tmux.conf.local`, so a run already has true colour before Deploy. The owner's own
  tmux gets it after Deploy D4 copies the file and the owner starts a new server.
- Deploying (fetch + `merge --ff-only origin/main` in `~/.config/nvim`) is the owner's step, or
  the Deploy runbook's. verify never runs it.
~~~~

### Step 10: Evidence: `evidence-phase-4.md` and the set's `evidence.md`
**File:** `.workflows/plan/nvim-0-12-clean/evidence-phase-4.md` (new)
**Code** (fill each `{{…}}` from Steps 2, 5, 6 and 7; the check in Step 11 refuses a leftover `{{`):
~~~~markdown
# Evidence: phase 4 (sweep, tmux true colour, health allow-list)

`E=~/.local/state/nvim-config-verify`. Neovim 0.12.6. Probes: `.claude/skills/verify-nvim-config/features/lua/{health_diff,noise,load_all}.lua`;
lever: `.workflows/plan/nvim-0-12-clean/phase-4-health.sh`.

## Base (planning, base `9cea538`, probes run from the planner's scratch copy)

| What | Seeded | Live |
|---|---|---|
| checkhealth vs allow-list, gopls attached | `$E/1104-123911-2920493/evidence/03-lua-…` (`sections=20 … unexpected=25`) | `$E/1104-123923-2924758/evidence/03-lua-…` (`unexpected=25`) |
| noise after checkhealth + notes.md | `$E/1104-123911-2920493/evidence/07-lua-…` (`client.request`, `E31`) | `$E/1104-123923-2924758/evidence/07-lua-…` |
| load_all | `…/08-lua-…` (`tried=18 failed=0 unloaded=0`) | `…/08-lua-…` |
| checkhealth vs allow-list, all loaded | `…/11-lua-…` (`sections=22 … unexpected=31`, incl. render-markdown ×5) | `…/11-lua-…` |
| yanky `clipboard: error: no buffers` | `$E/1104-123349-2896788/evidence/01-lua-…`; gone after `y y`: `$E/1104-123424-2900903/evidence/04-lua-…` | — |
| blink `client.request` triggered by `:checkhealth` | `$E/1104-123952-2930953/evidence/08-lua-…`, stack `13-lua-…` | — |
| `E31` on markdown (FileType fired twice) | `$E/1104-124053-2938291/evidence/03-lua-…`; probe KNOWN `$E/1104-124133-2941539/evidence/03-lua-…` | — |
| full checkhealth (analysis) | — | `$E/1104-121901-2809686/evidence/03-lua-return_table.concat_vim.api.nvim_buf_get.txt` |

## Before (phase-3 tip, Step 2)

{{paste both lever outputs: seeded RUN=…, live RUN=…; FAIL tc-override, tc-rgb, health-lsp, health-all-loaded}}

## After (Step 5)

{{paste both lever outputs: every check PASS; seeded RUN=…, live RUN=…}}

## True colour (Step 7)

| | Seeded | Live |
|---|---|---|
| before (`auto`) | {{RUN + values: empty, 0, line N}} | {{…}} |
| after (`true`) | {{RUN + values: *256col*:Tc, 2, 0}} | {{…}} |

## Sweep (Step 6): every journey, both modes

| File | Block | Mode | End state matched | noise.lua | Evidence |
|---|---|---|---|---|---|
{{one row per block × mode}}

## Findings

| # | Finding | Class (a/b/c/d) | Cause (file:line) | Disposition | Before / after |
|---|---|---|---|---|---|
| 1 | render-markdown `latex`/`yaml` health warnings (5) | a | `lua/plugin_specs.lua` render-markdown `opts = {}` (defaults enable both) | Step 4: both disabled | base `…/11-lua-…` above / {{Step 5 RUNs}} |
| 2 | `clipboard: error: no buffers` after loading yanky in a fresh run | b (run-only) | nvim `autoload/provider/clipboard.vim:43` on an empty tmux buffer list | health.md Gotchas; sweep yanks first | base rows above |
| 3 | `E31: No such mapping` in `v:errmsg` on markdown | b (upstream) | runtime `ftplugin/markdown.vim:35` + `ftplugin/markdown.lua` undo, FileType fired twice by lazy's `ft` handler | health.md ```` ```noise ```` | base rows above |
{{further findings from Step 6, one row each}}

## Handoffs

{{plugin-move fixes found (class c), or "none"}}
~~~~

**File:** `.workflows/plan/nvim-0-12-clean/evidence.md` (new)
**Code** (fill each `{{…}}` from `evidence-phase-1.md` … `-3.md`, the cell the phase recorded):
~~~~markdown
# Evidence: nvim-0-12-clean

Per-phase detail: `evidence-phase-1.md` ... `evidence-phase-4.md` in this directory. Run evidence
lives under `~/.local/state/nvim-config-verify/<RUN>/evidence/`, outside the repo, and is kept
after `down`. `E=~/.local/state/nvim-config-verify` below. Every run used Neovim 0.12.6
(`/opt/nvim-linux-x86_64`). Base: `origin/main` @ `8bcb55c` (then `9cea538`, whose only change is
an unrelated startup fix).

## Before/after per requirement and known leftover

| Item | Leftover | What | Before (live / seeded) | After (live / seeded) | Phase | Detail |
|---|---|---|---|---|---|---|
| R1 | 1 | `sync` respawns nvim with `run_path`; doctor `path` | `$E/1104-112534-2226714` (repro); `$E/1104-121901-2809686/evidence/16-lua-vim.env.PATH.txt` vs `17-lua-vim.env.PATH.txt` (caller's PATH after sync) / {{seeded before, evidence-phase-1.md}} | {{live after}} / {{seeded after}} | 1 | `evidence-phase-1.md` |
| R2 | 2 | no `client.request is deprecated` (blink.cmp v1.10.2) | `$E/1104-121455-2789754/evidence/15-screen-screen.txt` / `$E/1104-123952-2930953/evidence/08-lua-vim.fn.execute__messages__.txt` + stack `13-lua-…` | {{live after}} / {{seeded after}} | 3 | `evidence-phase-3.md` |
| R3 | 3 | CursorHold `open_float` "Invalid 'width'" in a 2-column window | `$E/1104-121901-2809686/evidence/14-screen-screen.txt` / {{seeded before}} | {{live after}} / {{seeded after}} | 2 | `evidence-phase-2.md` |
| R4 | 4 | no git-conflict `vim.highlight` / `vim.validate{}` | `$E/1104-121901-2809686/evidence/03-lua-return_table.concat_vim.api.nvim_buf_get.txt` (vim.deprecated) / `$E/1104-123911-2920493/evidence/03-lua-…` | {{live after}} / {{seeded after}} | 3 | `evidence-phase-3.md` |
| R5 | 5 | `v:errmsg` empty after startup (no E216) | `$E/1104-121455-2789754/evidence/01-lua-vim.v.errmsg.txt` / `$E/1104-123952-2930953/evidence/03-lua-vim.v.errmsg.txt` | {{live after}} / {{seeded after}} | 2 | `evidence-phase-2.md` |
| R6a | 6 | go.nvim health: no ❌, no `Missing tool` (Go tools on run PATH) | `$E/1104-121901-2809686/evidence/03-lua-…` (go) / `$E/1104-123911-2920493/evidence/03-lua-…` | {{live after}} / {{seeded after}} | 1 | `evidence-phase-1.md` |
| R6b | 6 | fidget health: no implicit-integration warning | same base files (fidget) | {{live after}} / {{seeded after}} | 2 | `evidence-phase-2.md` |
| R6c | 6 | tmux true colour | same base files (vim.health tmux) | {{phase 4 Step 7 live}} / {{seeded}} | 4 | `evidence-phase-4.md` § True colour |
| R6d | 6 | render-markdown latex/yaml warnings | `$E/1104-123923-2924758/evidence/11-lua-…` / `$E/1104-123911-2920493/evidence/11-lua-…` | {{Step 5 live RUN}} / {{seeded RUN}} | 4 | `evidence-phase-4.md` § Findings 1 |
| R6e | 6 | checkhealth minus allow-list empty (gopls attached; all loaded) | `$E/1104-123923-2924758/evidence/03-lua-…`, `11-lua-…` / `$E/1104-123911-2920493/evidence/03-lua-…`, `11-lua-…` | {{Step 5 live RUN}} / {{seeded RUN}} | 4 | `evidence-phase-4.md` § After |
| R6f | 6 | every plugin loads, no noise | `$E/1104-123923-2924758/evidence/08-lua-…` / `$E/1104-123911-2920493/evidence/08-lua-…` | {{Step 5 live}} / {{seeded}} | 4 | `evidence-phase-4.md` § After |
| R6g | 6 | `:messages`/notify clean after every `features/*.md` journey | — (not swept on the base) | {{Step 6 live RUNs}} / {{seeded RUNs}} | 4 | `evidence-phase-4.md` § Sweep |
| R7 | — | land, Deploy, final `up --live` + doctor from `~/.config/nvim` | — | the Deploy report `~/.local/state/nvim-config-verify/deploy-<DATE>.md` (written by runbook D6; never into the repo, so `~/.config/nvim` stays clean) | Deploy | `phase-4.md` § Deploy runbook |

## Recorded, not fixed (upstream- or environment-only)

The allow-list and known noise in `.claude/skills/verify-nvim-config/features/health.md` hold each
line's origin and reason. In short:
- optional tools not installed (snacks, fzf-lua, telescope, diffview, Mason languages);
- the run's fence (`cargo` outside `run_path`, PyPI offline);
- nvim-lspconfig's compound default filetypes;
- the owner's deliberate mappings (targets, which-key);
- blink v1's always-printed providers line;
- `E31` on markdown buffers (Neovim runtime ftplugins + lazy's `ft` re-fire).
~~~~

### Step 11: Static checks (doc completeness, runbook syntax)
**Code:**
```bash
cd /home/miftah/.worktrees/nvim/nvim-0-12-clean
F=.claude/skills/verify-nvim-config/features
# no unfilled template token anywhere this phase wrote
! grep -n '{{' $F/README.md $F/live-environment.md $F/tmux-bindings.md $F/health.md \
  .workflows/plan/nvim-0-12-clean/evidence.md .workflows/plan/nvim-0-12-clean/evidence-phase-4.md
# the Deploy runbook parses: every ```bash block after "## Deploy runbook", in order, as one script
awk '/^## Deploy runbook/{on=1} on && /^```bash$/{b=1; next} on && b && /^```$/{b=0; next} on && b' \
  .workflows/plan/nvim-0-12-clean/phase-4.md >/tmp/claude-deploy-runbook.sh
bash -n /tmp/claude-deploy-runbook.sh && grep -c 'set -euo pipefail' /tmp/claude-deploy-runbook.sh
bash -n .workflows/plan/nvim-0-12-clean/phase-4-health.sh
git status --porcelain     # only this phase's files (and nothing under lazy-lock.json)
```
**Pass:** the `grep '{{'` prints nothing, both `bash -n` exit 0, the runbook has `set -euo
pipefail` (count ≥ 1), and `git status` lists only the 12 files in **Files**.
(Use the session scratchpad instead of `/tmp` when the runner has one.)

### Step 12: Commits (on `feature/nvim-0-12-clean`; never push, never `main`)
**Code:**
```bash
cd /home/miftah/.worktrees/nvim/nvim-0-12-clean
F=.claude/skills/verify-nvim-config/features
git add $F/health.md $F/lua/health_diff.lua $F/lua/noise.lua $F/lua/load_all.lua .workflows/plan/nvim-0-12-clean/phase-4-health.sh
git commit -m "test(verify): checkhealth allow-list, noise and load-all probes

health.md records every remaining :checkhealth WARNING/ERROR with its origin and reason;
health_diff.lua fails on anything else, noise.lua on new messages/notify/errmsg per journey.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git add .tmux.conf.local $F/tmux-bindings.md
git commit -m "fix(tmux): true colour for nvim (tmux_conf_24b_colour=true)

auto only applied Tc with COLORTERM set; the owner's terminal does not set it, so tmux
downsampled termguicolors and :checkhealth vim.health warned.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git add lua/plugin_specs.lua
git commit -m "fix(markdown): disable render-markdown latex/yaml (no parser, never rendered)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git add $F/README.md $F/live-environment.md .workflows/plan/nvim-0-12-clean/evidence-phase-4.md .workflows/plan/nvim-0-12-clean/evidence.md
git commit -m "docs(verify): feature map, live environment, phase 4 evidence and the set's index

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
Any Step 6 class-(a) fix gets its own commit, with its doc edit, before the docs commit.

## Principles applied

- Build the lever: the sweep and the "checkhealth clean" claim are repetitive and hard to check by
  eye (3589-line report, two modes, two load states), so the plan adds `health_diff.lua`,
  `noise.lua`, `load_all.lua` and `phase-4-health.sh`. A reviewer reruns one command per mode
  instead of reading reports. I did one unit by hand first: the probe was run on the base report
  and on live/seeded runs, and its 25/31 unexpected keys are exactly the known findings.
- Encode lessons in structure: the allow-list is data the probe enforces, not prose. A new
  WARNING/ERROR fails the lever; entries name one line each, and `UNUSED` reports stale ones. The
  Deploy runbook is also syntax-checked (`bash -n`) as part of the phase.
- Fix root causes: each of the three run-only findings was traced to a line before it was
  dispositioned, not suppressed:
  - render-markdown: its health checks `latex.enabled`/`yaml.enabled` → a config fix.
  - E31: the duplicate undo in the runtime ftplugins + lazy's FileType re-fire → recorded.
  - clipboard: the provider on an empty tmux buffer list → avoided by yanking first, since the
    owner's tmux has buffers.
- Prove it works: failure first for each fix:
  - true colour: `tc-*` FAIL → PASS;
  - render-markdown: `health-all-loaded` `unexpected=6` → 0;
  both on the real runs in both modes, and Deploy D5 re-proves on the owner's environment.
- Laziness protocol: render-markdown is fixed with two `enabled = false` options, not by
  installing parsers, which would need a Deploy-time parser install and a `treesitter.lua` change.
  True colour is the one oh-my-tmux knob that exists for it, not hand-written
  `terminal-features`.

## Verification

**Build:** none (Lua/shell config). Syntax: `bash -n .workflows/plan/nvim-0-12-clean/phase-4-health.sh`;
`/opt/nvim-linux-x86_64/bin/nvim --headless -u NONE -c 'luafile .claude/skills/verify-nvim-config/features/lua/load_all.lua' -c 'qa!'`
is **not** a valid test (needs lazy). The probes are exercised by the lever instead.
**Tests:** the lever, both modes (Step 5), and Step 11's static checks.
**Proof:**
- Harness: `.claude/skills/verify-nvim-config` (`scripts/verify.sh`, `features/`).
- Feature-map entries: `features/health.md` (new), `features/tmux-bindings.md`,
  `features/README.md`, `features/live-environment.md`. All journeys in every `features/*.md` are
  re-driven (Step 6).
- Journeys (from the worktree root, bash):
  1. **J1 true colour, failure first.** Before Step 3:
     `.workflows/plan/nvim-0-12-clean/phase-4-health.sh seeded` prints
     `check tc-override FAIL terminal-overrides: <empty>`, `check tc-rgb FAIL … 0` and
     `check health-lsp FAIL … unexpected=1`, followed by
     `UNEXPECTED vim.health / tmux: WARNING True color support could not be detected…`.
     After Step 3, the same command, and `… live`, print `check tc-override PASS terminal-overrides:
     *256col*:Tc`, `check tc-rgb PASS … 2` and `check health-lsp PASS sections=20 … unexpected=0 …`.
  2. **J2 render-markdown, failure first.** Before Step 4, `check health-all-loaded FAIL
     sections=22 … unexpected=6` lists 5 `UNEXPECTED render-markdown / …` keys. After Step 4, both
     modes print `check health-all-loaded PASS sections=22 … unexpected=0 …`.
  3. **J3 the lever, both modes.** `phase-4-health.sh seeded` and `phase-4-health.sh live` both
     exit 0, with every `check … PASS`:
     - `errmsg PASS vim.v.errmsg empty: true`;
     - `noise-startup PASS noise=0 known=0`;
     - `load-all PASS tried=N failed=0 unloaded=0`;
     - `noise-load-all PASS noise=0 known=1 KNOWN errmsg: E31: No such mapping`.
  4. **J4 the sweep.** Every journey block in every `features/*.md` (Step 6 table), on `up --live`
     and `up`: each end state equals the file's "End state seen", and `lua RUN @$F/lua/noise.lua`
     prints `noise=0` (or only the Expected noise in that table). evidence-phase-4.md § Sweep has
     one row per block × mode.
  5. **J5 index and runbook.** Step 11 prints nothing for `{{`, and both `bash -n` exit 0.
- Neighbor check:
  - tmux-bindings.md's `C-b -` / `C-b @` / `C-b -` / `C-b !` block on a run started after Step 3:
    the same pane/session end states as documented, and doctor `tmuxconf ok`.
  - treesitter.md's highlight check on `notes.md` (`vim.treesitter.highlighter.active[...] ~=
    nil` → `true`, `vim.b.current_syntax` → `markdown`) after Step 4.
- Cost: none (no paid or online drive; the seed is not rebuilt).

**Exit criteria:**
- `phase-4-health.sh seeded` and `… live` both exit 0, so:
  - the `:checkhealth vim.health` true-colour warning is gone in both modes;
  - checkhealth minus the allow-list is empty with gopls attached and with every plugin loaded.
- Every sweep row matches, with `noise=0` or only its Expected noise.
- `evidence.md` has a path in every cell except R7's live/seeded, which point to the Deploy
  report.
- The Deploy runbook below parses.

## Handoffs

- **Reconciled:** Step 4 stays in this phase (index Decisions: render-markdown latex/yaml). The
  edit is one `opts` line of the render-markdown spec, after phase 3's hunks, and moves no plugin.
- **To a future set (not this one):**
  - an upstream go.nvim issue: `health.lua:58` calls `vim.system` without an `executable()`
    guard and crashes the whole go check when a tool is missing;
  - nvim-lspconfig compound filetypes;
  - Neovim's duplicate markdown `b:undo_ftplugin`.

  All three are recorded in health.md. None is a plugin move in this set.
- **None to phases 1-3:** they land before this phase; findings in their files go through Step 6's
  rules.

## Rollback

Before land: `git revert` this phase's commits on `feature/nvim-0-12-clean`, or `git reset --keep`
to phase 3's tip. Nothing outside the worktree was written except run evidence under
`~/.local/state/nvim-config-verify/`, which stays. After land and before Deploy: the index's
`git revert -m 1 <merge>`. After Deploy: the runbook's full rollback below.

---

## Deploy runbook

The **coordinator** runs this **after** land: the set is merged and pushed to `origin/main` (D0
asserts it from `origin/main`'s content). Run it in one **bash** session (the variables carry from
step to step; in a zsh tool shell, put all of it in a file and run `bash FILE`). Never run it from
the deleted worktree.
- Order: D0 checks, D1 backup, then **D2 `git -C ~/.config/nvim fetch origin && git -C
  ~/.config/nvim merge --ff-only origin/main`**. Everything that depends on the landed config (D3
  plugins, D4 tmux file, D5 proof, D6 report) runs strictly after D2.
- Every step asserts (`set -euo pipefail`: a failed assertion stops the script).
- On a failed assertion in D2-D5, run the **Full rollback** at the end, then stop and report.
- Nothing here writes inside `~/.config/nvim` except D2's fast-forward and D3's gitignored
  `lazy-lock.json`.
- The report goes to `$VH/deploy-$DATE.md`, outside the repo.
- Backups go to `~/.local/opt/deploy-backup-$DATE`.
- The owner's tmux server is never contacted: no `tmux` command without `-S`, no `source-file`.

### D0: Variables and preconditions (writes only `git fetch`'s remote refs and the report header)
```bash
set -euo pipefail
DATE=$(date +%Y%m%d-%H%M%S)
VH=$HOME/.local/state/nvim-config-verify
REPORT=$VH/deploy-$DATE.md
BK=$HOME/.local/opt/deploy-backup-$DATE
LIVE=$HOME/.config/nvim
DATA=$HOME/.local/share/nvim
SEED=$VH/.seed
SEED_LOCK=$SEED/lazy-lock.json
SEED_BLINK_LIB=$SEED/data/nvim/lazy/blink.cmp/target/release
PLUGINS="blink.cmp git-conflict.nvim"
BLINK_TAG=v1.10.2
BASE=8bcb55c
TMUX_LOCAL=$HOME/.tmux.conf.local
NVIM=/opt/nvim-linux-x86_64/bin/nvim
origin_raw() { git -C "$1" config --get remote.origin.url; }   # never `remote get-url`: it applies insteadOf

mkdir -p "$VH"
printf '# Deploy nvim-0-12-clean %s\n\n' "$DATE" >"$REPORT"
[ "$("$NVIM" --version | sed -n 1p)" = 'NVIM v0.12.6' ]
[ -z "$(git -C "$LIVE" status --porcelain)" ]
git -C "$LIVE" fetch origin
git -C "$LIVE" merge-base --is-ancestor HEAD origin/main          # a fast-forward is possible
# The set has landed: origin/main carries its config (never deploy a half-landed main).
SPECS=$(git -C "$LIVE" show origin/main:lua/plugin_specs.lua)
grep -q '"stryukovsky/git-conflict.nvim"' <<<"$SPECS"
grep -q 'version = "1\.\*"' <<<"$SPECS"
grep -q 'latex = { enabled = false }' <<<"$SPECS"
grep -qx 'tmux_conf_24b_colour=true' <<<"$(git -C "$LIVE" show origin/main:.tmux.conf.local)"
git -C "$LIVE" cat-file -e origin/main:.claude/skills/verify-nvim-config/features/health.md
git -C "$LIVE" cat-file -e origin/main:.claude/skills/verify-nvim-config/features/lua/health_diff.lua
git -C "$LIVE" cat-file -e origin/main:.workflows/plan/nvim-0-12-clean/evidence.md
# The seed lock holds phase 3's targets, with branch and url, and the seed dirs are checked out there.
[ "$(jq -r '."blink.cmp".commit' "$SEED_LOCK")" = 78336bc89ee5365633bcf754d93df01678b5c08f ]
[ "$(jq -r '."git-conflict.nvim".commit' "$SEED_LOCK")" = 63c5b427038d85b20c32a25c7f3bd502241ce869 ]
[[ $(jq -r '."git-conflict.nvim".url' "$SEED_LOCK") == https://github.com/stryukovsky/git-conflict.nvim* ]]
for p in $PLUGINS; do
  [ -n "$(jq -r --arg p "$p" '.[$p].url // empty' "$SEED_LOCK")" ]
  [ -n "$(jq -r --arg p "$p" '.[$p].branch // empty' "$SEED_LOCK")" ]
  [ "$(git -C "$SEED/data/nvim/lazy/$p" rev-parse HEAD)" = "$(jq -r --arg p "$p" '.[$p].commit' "$SEED_LOCK")" ]
  [ -d "$DATA/lazy/$p/.git" ]; [ ! -e "$DATA/lazy/$p.cloning" ]
done
# blink v1 loads its prebuilt lib only when all three files are there and `version` names the tag.
for f in libblink_cmp_fuzzy.so libblink_cmp_fuzzy.so.sha256 version; do [ -s "$SEED_BLINK_LIB/$f" ]; done
[ "$(cat "$SEED_BLINK_LIB/version")" = "$BLINK_TAG" ]
[ "$(git -C "$SEED/data/nvim/lazy/blink.cmp" describe --tags --exact-match HEAD)" = "$BLINK_TAG" ]
# ~/.tmux.conf.local is copied only if the owner never changed it: else stop now, before any write.
[ -f "$TMUX_LOCAL" ] && [ ! -L "$TMUX_LOCAL" ]
if ! cmp -s <(git -C "$LIVE" show "$BASE:.tmux.conf.local") "$TMUX_LOCAL"; then
  echo "- STOP D0: ~/.tmux.conf.local differs from $BASE's .tmux.conf.local; nothing deployed. The owner merges tmux_conf_24b_colour=true by hand, then re-run." | tee -a "$REPORT"
  exit 1
fi
pgrep -a -x nvim || true     # informational: running nvim sessions keep the old plugin code until restarted
{ echo "- origin/main: $(git -C "$LIVE" rev-parse --short origin/main)"; echo "- live HEAD before: $(git -C "$LIVE" rev-parse --short HEAD)"; } >>"$REPORT"
```
Rollback D0: nothing to undo. Only remote-tracking refs were fetched and the report header was
written.

### D1: Backup
```bash
mkdir -p "$BK/lazy"
cp -a "$LIVE/lazy-lock.json" "$BK/lazy-lock.json"
for p in $PLUGINS; do cp -a "$DATA/lazy/$p" "$BK/lazy/"; done
cp -a "$TMUX_LOCAL" "$BK/tmux.conf.local"
git -C "$LIVE" rev-parse HEAD >"$BK/config-head.txt"
cmp "$LIVE/lazy-lock.json" "$BK/lazy-lock.json"
cmp "$TMUX_LOCAL" "$BK/tmux.conf.local"
for p in $PLUGINS; do
  [ "$(git -C "$BK/lazy/$p" rev-parse HEAD)" = "$(git -C "$DATA/lazy/$p" rev-parse HEAD)" ]
  [ "$(origin_raw "$BK/lazy/$p")" = "$(origin_raw "$DATA/lazy/$p")" ]
done
echo "- D1 backup: $BK (config head $(cat "$BK/config-head.txt"))" >>"$REPORT"
```
Rollback D1: none needed. `$BK` only holds copies; keep it.

### D2: Fast-forward the live config (the user's exact command)
```bash
git -C "$LIVE" fetch origin && git -C "$LIVE" merge --ff-only origin/main
[ "$(git -C "$LIVE" rev-parse HEAD)" = "$(git -C "$LIVE" rev-parse origin/main)" ]
[ -z "$(git -C "$LIVE" status --porcelain)" ]
grep -q '"stryukovsky/git-conflict.nvim"' "$LIVE/lua/plugin_specs.lua"
grep -qx 'tmux_conf_24b_colour=true' "$LIVE/.tmux.conf.local"
echo "- D2 config: $(git -C "$LIVE" log --oneline -1)" >>"$REPORT"
```
Rollback D2:
```bash
git -C "$LIVE" reset --keep "$(cat "$BK/config-head.txt")"
[ "$(git -C "$LIVE" rev-parse HEAD)" = "$(cat "$BK/config-head.txt")" ]
```
(The fast-forward is D2's only write. `--keep` refuses rather than discard anything.)

### D3: Move blink.cmp and git-conflict.nvim to the seed lock's entries, record them in the live lock
Use plain git, not `Lazy! restore`. This step needs neither network beyond GitHub fetches nor
cargo, and runs no `build`.
- The url comes from the seed lock's `url` (the raw `.git/config` value), so git-conflict's live
  clone is re-pointed from `akinsho` to `stryukovsky` with `remote set-url`. Never use `git
  remote get-url`: it stores the owner's `insteadOf` rewrite, and every later `--live` run would
  then see the plugin as moved.
- `--tags` brings blink's `v1.10.2` tag. Phase 3 measured that the live clone already has object
  `78336bc` but **not** the tag, and blink v1 checks `git describe --tags --exact-match` against
  `target/release/version`.
- blink's v0.14 cargo output in `target/` is replaced by the seed's three prebuilt files.

```bash
for p in $PLUGINS; do
  url=$(jq -r --arg p "$p" '.[$p].url' "$SEED_LOCK")
  branch=$(jq -r --arg p "$p" '.[$p].branch' "$SEED_LOCK")
  commit=$(jq -r --arg p "$p" '.[$p].commit' "$SEED_LOCK")
  git -C "$DATA/lazy/$p" remote set-url origin "$url"
  git -C "$DATA/lazy/$p" fetch -q --tags origin "+refs/heads/$branch:refs/remotes/origin/$branch"
  git -C "$DATA/lazy/$p" checkout -q "$commit"
  [ "$(git -C "$DATA/lazy/$p" rev-parse HEAD)" = "$commit" ]
  [ "$(origin_raw "$DATA/lazy/$p")" = "$url" ]
  [ -z "$(git -C "$DATA/lazy/$p" status --porcelain --untracked-files=no)" ]
  echo "- D3 $p $branch $commit $url" >>"$REPORT"
done
B=$DATA/lazy/blink.cmp
[ "$(git -C "$B" describe --tags --exact-match HEAD)" = "$BLINK_TAG" ]
rm -rf "$B/target"
mkdir -p "$B/target/release"
for f in libblink_cmp_fuzzy.so libblink_cmp_fuzzy.so.sha256 version; do
  install -D -m 0644 "$SEED_BLINK_LIB/$f" "$B/target/release/$f"   # 0644: the seed's files are read-only; a later bump rewrites `version`
  cmp "$SEED_BLINK_LIB/$f" "$B/target/release/$f"
done
[ "$(cat "$B/target/release/version")" = "$BLINK_TAG" ]
[ "$(sha256sum "$B/target/release/libblink_cmp_fuzzy.so" | cut -d' ' -f1)" = "$(cut -d' ' -f1 "$B/target/release/libblink_cmp_fuzzy.so.sha256")" ]
echo "- D3 blink.cmp prebuilt lib: $(cat "$B/target/release/version") $(cut -c1-16 "$B/target/release/libblink_cmp_fuzzy.so.sha256")" >>"$REPORT"
# v0's LMDB frecency store is owner data: left in place, unused by v1 (which writes ~/.local/state/nvim/blink/cmp/frecency.dat)
if [ -e "$DATA/blink/cmp/fuzzy.db" ]; then echo "- D3 left untouched: $DATA/blink/cmp/fuzzy.db (blink v0 frecency; v1 does not read it; the owner may delete it)" >>"$REPORT"; fi
tmp=$(mktemp)
jq --slurpfile seed "$SEED_LOCK" '. + ($seed[0] | {"blink.cmp", "git-conflict.nvim"})' "$LIVE/lazy-lock.json" >"$tmp"
cp "$tmp" "$LIVE/lazy-lock.json" && rm -f "$tmp"
for p in $PLUGINS; do
  [ "$(jq -r --arg p "$p" '.[$p].commit' "$LIVE/lazy-lock.json")" = "$(git -C "$DATA/lazy/$p" rev-parse HEAD)" ]
  [ "$(jq -r --arg p "$p" '.[$p].branch' "$LIVE/lazy-lock.json")" = "$(jq -r --arg p "$p" '.[$p].branch' "$SEED_LOCK")" ]
done
[ -z "$(git -C "$LIVE" status --porcelain)" ]       # lazy-lock.json is gitignored
```
(The live lock entries gain the seed's `url` key. lazy ignores it and drops it on its next
rewrite.) If the `sha256sum` assertion fails, the seed's checksum file has another format. Read
`lua/blink/cmp/fuzzy/download/files.lua` `get_checksum` in the checked-out v1.10.2 and adapt the
comparison, never the files.
Rollback D3:
```bash
for p in $PLUGINS; do rm -rf "${DATA:?}/lazy/$p" && cp -a "$BK/lazy/$p" "$DATA/lazy/"; done
cp -a "$BK/lazy-lock.json" "$LIVE/lazy-lock.json"
for p in $PLUGINS; do
  [ "$(git -C "$DATA/lazy/$p" rev-parse HEAD)" = "$(git -C "$BK/lazy/$p" rev-parse HEAD)" ]
  [ "$(origin_raw "$DATA/lazy/$p")" = "$(origin_raw "$BK/lazy/$p")" ]
done
cmp "$LIVE/lazy-lock.json" "$BK/lazy-lock.json"
```

### D4: `~/.tmux.conf.local` ← the repo's (only if still the base's; never touches the running server)
```bash
cmp -s <(git -C "$LIVE" show "$BASE:.tmux.conf.local") "$TMUX_LOCAL"   # still unchanged since D0
cp "$LIVE/.tmux.conf.local" "$TMUX_LOCAL"
cmp "$LIVE/.tmux.conf.local" "$TMUX_LOCAL"
grep -qx 'tmux_conf_24b_colour=true' "$TMUX_LOCAL"
[ -f "$TMUX_LOCAL" ] && [ ! -L "$TMUX_LOCAL" ]
echo "- D4 ~/.tmux.conf.local == repo (tmux_conf_24b_colour=true); applies when the owner next starts a tmux server (the running one was not contacted)" >>"$REPORT"
```
Rollback D4:
```bash
cp "$BK/tmux.conf.local" "$TMUX_LOCAL"
cmp "$BK/tmux.conf.local" "$TMUX_LOCAL"
```

### D5: Final proof from `~/.config/nvim` (R7)
Expected end states are the ones the phases recorded: lsp.md (completion, CursorHold), git.md,
health.md and tmux-bindings.md. The R2 and R3 blocks below are lsp.md's `### Completion (blink.cmp v1)`
(lua part) and `### CursorHold diagnostic float` journeys with the same keys, waits and probes, turned
into assertions (reconciled). If phase 2 or 3 recorded a different measured end state in lsp.md, the
assertion takes lsp.md's value.
```bash
cd "$LIVE"
unset VERIFY_NVIM
V=.claude/skills/verify-nvim-config/scripts/verify.sh
P=$LIVE/.claude/skills/verify-nvim-config/features/lua
lua1() { "$V" lua "$RUN" "$1" 2>/dev/null | sed -n 2p; }    # first line of the result
deps_other() {   # deprecations.lua's lines minus health.md's two "fixed upstream, not moved here" (coordinator decision after phase 3)
  "$V" lua "$RUN" "@$P/deprecations.lua" 2>/dev/null | tail -n +3 \
    | grep -vF -e 'vim.lsp.codelens.refresh({ bufnr = bufnr}) is deprecated.' -e 'vim.validate{<table>} is deprecated.' | grep -c . || true
}
health_ok() {   # $1 = minimum sections; full :checkhealth minus the allow-list must be empty
  "$V" keys "$RUN" : checkhealth Enter
  "$V" wait "$RUN" 'vim.bo.filetype' checkhealth 120
  local res; res=$("$V" lua "$RUN" "@$P/health_diff.lua" 2>/dev/null | tail -n +2)
  echo "$res" >>"$BK/health-$1.txt"
  local head; head=$(sed -n 1p <<<"$res"); echo "$head"
  [[ $head == *' unexpected=0 '* ]]
  local n=${head#sections=}; n=${n%% *}; [ "$n" -ge "$1" ]
  "$V" keys "$RUN" : tabclose Enter
}
"$V" live >"$BK/live.txt"; cat "$BK/live.txt"
grep -q '^commits in the checkout that live lacks (0)' "$BK/live.txt"
grep -qF "~/.tmux.conf.local == checkout's" "$BK/live.txt"
out=$("$V" up --live); echo "$out"; RUN=$(sed -n 's/^RUN=//p' <<<"$out"); E=$VH/$RUN/evidence
[ -n "$RUN" ]
[ -z "$(sed -n 's/^replaced_from_seed=//p' "$VH/$RUN/meta" | tail -1)" ]   # live now has what the seed has
[ -z "$(sed -n 's/^filled_from_seed=//p' "$VH/$RUN/meta" | tail -1)" ]
[ ! -e "$E/00-up-replaced.txt" ]
[ -z "$(tr -d '[:space:]' <"$E/00-up-messages.txt")" ]                     # :messages empty at startup
"$V" doctor "$RUN" | tee "$BK/doctor.txt"                                  # exit 0 (pipefail)
[ "$(lua1 'tostring(vim.version())')" = 0.12.6 ]
[ "$(lua1 'vim.v.errmsg == ""')" = true ]                                  # R5
[[ $(lua1 "@$P/noise.lua") == noise=0* ]]
[[ $(lua1 'vim.trim(vim.fn.system({ "tmux", "show-options", "-gv", "terminal-overrides" }))') == *'*256col*:Tc'* ]]   # the run's tmux, deployed .tmux.conf.local
# R2: lsp.md "### Completion (blink.cmp v1)", its lua part with the same keys, waits and probes (phase 3)
"$V" keys "$RUN" : e Space sample.lua Enter
"$V" wait "$RUN" 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="lua_ls"})), ",")' lua_ls 60
"$V" keys "$RUN" G o
"$V" keys "$RUN" vim.
"$V" wait "$RUN" 'tostring(require("blink.cmp").is_menu_visible())' true 30
"$V" screen "$RUN" completion-lua
"$V" keys "$RUN" Escape
[ "$(lua1 'tostring(require("blink.cmp").is_menu_visible()) .. " " .. vim.fn.mode()')" = "false i" ]
"$V" keys "$RUN" ap
"$V" wait "$RUN" 'tostring(require("blink.cmp").is_menu_visible())' true 30
"$V" keys "$RUN" Tab
"$V" keys "$RUN" Enter
[ "$(lua1 'tostring(vim.api.nvim_get_current_line():match("^vim%.[%w_]+") ~= nil)')" = true ]
"$V" keys "$RUN" Escape Escape
[ "$(deps_other)" = 0 ]                                                     # no client.request, no fuzzy notice (go.nvim codelens / glance vim.validate{} excepted)
[ "$(lua1 'require("blink.cmp.fuzzy").implementation_type')" = rust ]
[ "$(lua1 '(function() local d = vim.fn.stdpath("data") .. "/lazy/blink.cmp" return vim.fn.readfile(d .. "/target/release/version")[1] .. " " .. vim.trim(vim.fn.system({ "git", "-C", d, "describe", "--tags", "--exact-match" })) end)()')" = "v1.10.2 v1.10.2" ]
[[ $(lua1 "@$P/noise.lua") == noise=0* ]]
# R3: lsp.md "### CursorHold diagnostic float", the same keys, waits and probe (phase 2)
"$V" keys "$RUN" G o
"$V" keys "$RUN" --paste 'x = undefined_thing'
"$V" keys "$RUN" Escape Escape
"$V" wait "$RUN" '#vim.diagnostic.get(0, {lnum = vim.fn.line(".") - 1}) > 0' true 60
"$V" keys "$RUN" k
"$V" wait "$RUN" 'vim.deep_equal(vim.b.diagnostics_pos, vim.api.nvim_win_get_cursor(0))' true 10   # the hold ran on the line above (lsp.md: k and j in separate sends)
"$V" keys "$RUN" j
"$V" wait "$RUN" '(function() for _, w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(w).relative ~= "" and vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, 1, false)[1] == "Diagnostics:" then return vim.api.nvim_win_get_width(w) end end return 0 end)()' 100 15   # full-width float still opens at 100
"$V" keys "$RUN" : 2 v s p l i t Enter
"$V" keys "$RUN" k j
"$V" keys "$RUN" h
"$V" screen "$RUN" narrow
"$V" wait "$RUN" 'vim.deep_equal(vim.b.diagnostics_pos, vim.api.nvim_win_get_cursor(0))' true 10   # CursorHold ran; no hit-enter prompt blocks RPC
[ "$(lua1 'vim.api.nvim_win_get_width(0) .. " " .. #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative ~= "" and vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, 1, false)[1] == "Diagnostics:" end, vim.api.nvim_list_wins())')" = "2 0" ]   # lsp.md probe: width 2, floats 0 (its messages = "" is covered by noise.lua, since this session already printed earlier lines)
[[ $(lua1 "@$P/noise.lua") == noise=0* ]]
"$V" keys "$RUN" : o n l y Enter
# R4/R6: full :checkhealth minus the allow-list, gopls attached, then with every plugin loaded
"$V" keys "$RUN" : e Space main.go Enter
"$V" wait "$RUN" '#vim.lsp.get_clients({bufnr=0, name="gopls"})' 1 90
health_ok 20
[[ $(lua1 "@$P/noise.lua") == noise=0* ]]
"$V" keys "$RUN" : e Space notes.md Enter
"$V" keys "$RUN" y y
[[ $(lua1 "@$P/load_all.lua") == *' failed=0 unloaded=0' ]]
[[ $(lua1 "@$P/noise.lua") == noise=0* ]]
health_ok 22
[ "$(deps_other)" = 0 ]                                                     # no other deprecation / blink fallback notice in the whole session
"$V" doctor "$RUN"                                                          # exit 0
"$V" down "$RUN"
[ -z "$(git -C "$LIVE" status --porcelain)" ]                               # verify wrote nothing into the checkout
echo "- D5 run $RUN (live): evidence $E; doctor $BK/doctor.txt; checkhealth vs allow-list $BK/health-20.txt, $BK/health-22.txt; live drift $BK/live.txt" >>"$REPORT"
```
Every `wait`, `[ ]`, `[[ ]]` and `grep` above is an assertion. If the CursorHold `wait` times out,
a "Press ENTER" prompt is blocking RPC: R3 regressed, so run the full rollback.
Rollback D5: `"$V" down "$RUN"` if it is still up. The run is read-only. A failed D5 assertion
triggers the full rollback: the owner must not be left on an unproven deploy.

### D6: Final assertions and the report
```bash
git -C "$LIVE" fetch origin
[ "$(git -C "$LIVE" rev-parse HEAD)" = "$(git -C "$LIVE" rev-parse origin/main)" ]
[ -z "$(git -C "$LIVE" status --porcelain)" ]
for p in $PLUGINS; do echo "- D6 $p $(git -C "$DATA/lazy/$p" rev-parse --short HEAD) $(origin_raw "$DATA/lazy/$p")"; done >>"$REPORT"
cmp "$LIVE/.tmux.conf.local" "$TMUX_LOCAL" && echo "- D6 ~/.tmux.conf.local == repo" >>"$REPORT"
{
  echo "- evidence index (before/after per R1-R7 and leftovers 1-6): $LIVE/.workflows/plan/nvim-0-12-clean/evidence.md"
  echo "- restart running nvim sessions to load blink.cmp v1.10.2 and the git-conflict fork; start a new tmux server for true colour"
  echo "- deploy ok; backup kept at $BK"
} >>"$REPORT"
cat "$REPORT"
```
Rollback D6: none (read-only). The coordinator's final report quotes `$REPORT`, and the
before/after paths from `.workflows/plan/nvim-0-12-clean/evidence.md` on `origin/main`.

### Full rollback (any assertion in D2-D5 failed)
Run the D4, D3 and D2 rollbacks, each only if its step had started, in that order:
```bash
set -euo pipefail
cp "$BK/tmux.conf.local" "$TMUX_LOCAL"                                     # D4 (harmless if D4 never ran: same bytes)
for p in $PLUGINS; do rm -rf "${DATA:?}/lazy/$p" && cp -a "$BK/lazy/$p" "$DATA/lazy/"; done   # D3
cp -a "$BK/lazy-lock.json" "$LIVE/lazy-lock.json"
git -C "$LIVE" reset --keep "$(cat "$BK/config-head.txt")"                 # D2
[ "$(git -C "$LIVE" rev-parse HEAD)" = "$(cat "$BK/config-head.txt")" ]
for p in $PLUGINS; do
  [ "$(git -C "$DATA/lazy/$p" rev-parse HEAD)" = "$(git -C "$BK/lazy/$p" rev-parse HEAD)" ]
  [ "$(origin_raw "$DATA/lazy/$p")" = "$(origin_raw "$BK/lazy/$p")" ]
done
cmp "$BK/lazy-lock.json" "$LIVE/lazy-lock.json"
cmp "$BK/tmux.conf.local" "$TMUX_LOCAL"
[ -z "$(git -C "$LIVE" status --porcelain)" ]
echo "- ROLLED BACK: the failed assertion and its output are above; ~/.config/nvim is back on $(cat "$BK/config-head.txt"), plugins, lock and ~/.tmux.conf.local restored from $BK" >>"$REPORT"
```
Append the failing step, command and output to `$REPORT` before the rollback. `origin/main` keeps
the landed set; the report says the owner's checkout is back on the pre-deploy commit, and why.
