# Phase 8: hop.nvim -> smoka7 fork, verify learns moved plugins

**Plan set:** `FIX_BUGS_NVIM_0_12_PLAN.md`
**Analysis:** `docs/analyzer/20261104-102452-MRDD_code_analyzer.md`
**Satisfies:** R4 — hop.nvim comes from the maintained fork `smoka7/hop.nvim`; `f`/`F` keep working
**Depends on:** Phase 7 (and through it 4, 5, 6)
**Difficulty:** HARD
**Package:** `lua/plugin_specs.lua` + `.claude/skills/verify-nvim-config/`

---

> **Set-wide execution rules** (plan index § Execution rules; they override any command below that disagrees):
> 1. `$WT` is **this phase's own worktree root** (`WT=$(git rev-parse --show-toplevel)`). Wave-1 phases run
>    concurrently in separate worktrees, so never `cd` into another phase's tree.
> 2. **No `git stash`** (the stash stack is shared by every worktree of the repo). Swap base and fix per file:
>    `SW=$(mktemp -d)`; BASE = `cp <path> "$SW/" && git show "$PHASE_BASE:<path>" ><path>`; FIX = `cp "$SW/<file>" <path>`,
>    where `PHASE_BASE=$(git rev-parse HEAD)` is recorded before this phase's first edit. A new file's BASE is `mv <path> "$SW/"`.
> 3. Commit with an explicit pathspec: `git add -- <new files>` then `git commit -m "..." -- <every path>`.
> 4. Evidence goes to `.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-8.md`, this phase's own file (never a shared one),
>    written only **after every run of the phase is down** (the file is inside the snapshotted tree; a mid-run write makes
>    `doctor` print `code WARN`). It is committed as the phase's last commit:
>    `git add -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-8.md && git commit -m "docs(evidence): phase 8 before/after evidence" -- .workflows/plan/fix-bugs-nvim-0-12/evidence-phase-8.md`.
>    `.workflows/` is tracked (the orchestrator commits the plan set); commit nothing else under it unless this plan says so.
> 5. Never `git push`. Never write `~/.config/nvim`, `~/.local/share/nvim` or `/opt/nvim-linux-x86_64`.

## Goal

The hop spec points at `smoka7/hop.nvim`, so a fresh install or `:Lazy update` can fetch it
again (`phaazon/hop.nvim` answers `Repository not found`). The verify harness learns about a
**moved** plugin, meaning a spec whose url or branch no longer matches the lock entry. The seed
follows the spec for such a plugin instead of pinning it back to the old commit, and it writes its
lock from what is actually checked out, including each dir's origin url. `up --live` replaces a
moved plugin from the seed, says so (`replaced_from_seed`), and can carry data the plugin keeps
outside `lazy/`. Phase 9 reuses all of this for nvim-treesitter's branch move (`master` -> `main`)
and its parsers in `site/`.

## Interface Contract

**Deletes:**
- `verify.sh` `cmd_seed`: the copy of `lock.orig.json` back as the seed lock, and the fallback
  copy of lazy's rewritten `config/nvim/lazy-lock.json` (base `:192-194`).
- `SKILL.md` Gotchas bullets "**lazy ignores a lock entry whose branch differs from the spec's.**"
  and "**`phaazon/hop.nvim` is gone from GitHub.**" (base `:156-161`), replaced by the two
  bullets in Step 7.

**Renames:** `"phaazon/hop.nvim"` -> `"smoka7/hop.nvim"` (lazy name and lock key stay `hop.nvim`).

**Creates:**
- `verify.sh` global `declare -A PLUGIN_EXTRA_DATA=()`: **the hook phase 9 uses.** It maps a lazy
  plugin name to space-separated paths relative to the data dir's `nvim/` (for example
  `[nvim-treesitter]="site/parser site/queries"`). When `up --live` replaces that plugin from the
  seed, each listed path that exists in `$SEED/data/nvim/` replaces the run's copy.
- `verify.sh` `origin_url DIR`: the dir's `remote.origin.url` as stored in `.git/config`, with any
  trailing `/` and `.git` stripped. It never goes through `remote get-url`, which would apply the
  owner's `url.git@github.com:.insteadof` rewrite.
- `verify.sh` run meta key `replaced_from_seed=<names>` (live runs), the evidence file
  `<run>/evidence/00-up-replaced.txt`, one stderr line from `up`, and doctor's `live info` line
  gains `, replaced from seed (spec moved): <names>`.
- `seed.lua` env inputs/outputs: reads `SEED_LOCK_OUT` (written by `verify.sh` as
  `$SEED/lock.new.json`) and writes the seed lock there. It also gets a log line kind
  `MOVED plugin <name>: <why>; not pinned to the lock's <branch>@<sha7>, follows the spec: <branch>@<sha7>`
  and a new step line `ok   seed lock`.
- Seed lock entry format: `{ "branch": B, "commit": C, "url": U }`. lazy reads `branch`/`commit`
  and ignores `url`, and its own rewrite drops `url` again.
- `features/editing-mappings.md`: a hop sub-feature and its journey.

**The moved-plugin rule (exact):**
- *Seed* (`seed.lua`, skipped under `seed --update`): plugin `p` with lock entry `want` is MOVED
  when `p.branch` is set **and** differs from `want.branch`, **or** `norm(p.url)` differs from
  `norm(ref)`. Here `ref = want.url` when the lock records one; otherwise (a lock taken from live,
  or written before this phase) it is the raw origin of `$LIVE_LAZY/<name>`, and when that does
  not exist either there is no url check. `norm` strips trailing `/` and `.git`. An unpinned spec
  is never moved by its branch alone, so it stays pinned to the lock as before. A moved plugin is
  fetched when its dir already tracks `p.url` (lazy's `restore` re-clones on a url change), and
  re-cloned the way lazy clones otherwise. It is then checked out at
  `require("lazy.manage.git").get_target(p).commit` (branch tip, or the spec's tag/version/commit).
  A failure logs `FAIL plugin <name>: the spec moved (...)`, and `cmd_seed` dies on it.
- *Live run* (`verify.sh cmd_up --live`): a seed plugin dir that also exists in the live copy is
  REPLACED when the seed lock has an entry for it **and** (the seed lock's `branch` differs from the
  live lock's, where a missing live entry counts as equal, **or**
  `origin_url(seed dir) != origin_url(run's live copy)`). On replacement the run's dir comes from
  the seed, the run's lock takes the seed lock's entry, and `PLUGIN_EXTRA_DATA[name]` paths come
  from the seed. A plugin missing from live is still filled as before (`filled_from_seed`).

**Signature changes:** none (`cmd_seed`, `cmd_up` keep their flags).

**Requires (from earlier phases):**
- Phase 4: `cmd_up`'s mkdir line no longer lists `bin,sink`, the `write_fake_opencode` call is
  gone, and the doctor `opencode` lines are gone. This phase anchors its `verify.sh` hunks on
  text, not line numbers.
- Phase 5: `cmd_live`'s deploy line is changed. Untouched here.
- Phase 6: `plugin_specs.lua` lines 1-18 (bootstrap) are rewritten, so the hop line moves.
  Anchor: the line `"phaazon/hop.nvim",`.
- Phase 7: the mason spec right below hop and `seed.lua`'s mason step have no gofumpt special
  case. This phase does not touch either.

**Leaves alone (owned by others):** treesitter/textobjects specs and `lua/config/treesitter*.lua`,
`seed.lua`'s `treesitter parsers` step (Phase 9); mason / mason-tool-installer specs and
`seed.lua`'s `mason packages` step (Phase 7); bootstrap (Phase 6); `features/README.md`,
`features/live-environment.md` (Phase 9, Phase 5's one line); `cmd_live` (Phase 5); the opencode
lines (Phase 4); `lua/config/hop.lua` (unchanged: smoka7 keeps `setup`, `hint_words`,
`hint_char1`, `hop.hint.HintDirection`, and the options `keys`, `case_insensitive`,
`jump_on_sole_occurrence`, `multi_windows`, checked in the scratch clone at `6e83486`).

## Files

| File | Action | What changes |
|---|---|---|
| `lua/plugin_specs.lua` | modify (base `:513`) | `"phaazon/hop.nvim"` -> `"smoka7/hop.nvim"` |
| `.claude/skills/verify-nvim-config/scripts/seed.lua` | modify (base `:18-73`, insert after `:73`) | moved-plugin detection + follow-the-spec, pin loop keeps the rest, new `seed lock` step |
| `.claude/skills/verify-nvim-config/scripts/verify.sh` | modify (base `:47`, after `:250`, `:158-210`, `:286`, `:298-322`, `:344-349`, `:373`, `:446`) | `PLUGIN_EXTRA_DATA`, `origin_url`, `cmd_seed` lock handling, `cmd_up` live replace, meta, stderr, doctor |
| `.claude/skills/verify-nvim-config/SKILL.md` | modify (base `:41-51`, `:156-161`) | seed + live bullets, two Gotchas rewritten |
| `.claude/skills/verify-nvim-config/features/editing-mappings.md` | modify | hop `f`/`F` sub-feature, journey, gotchas |

## Implementation Steps

Commit order: Steps 2-6 first as `feat(verify): handle plugins whose spec moved (url or branch)`.
They are a no-op on the base spec, since nothing has moved yet. Steps 1, 7 and 8 (spec + docs)
follow as `fix(hop): use the maintained smoka7/hop.nvim fork`. Each commit builds and loads on its own. The
seed is re-seeded only after both are in the working tree (see Proof).

### Step 1: hop spec -> smoka7
**File:** `lua/plugin_specs.lua:513` (base numbering; after phase 6 the line moves, so anchor on the text)
**Change:** replace the spec's repo string. Leave everything else alone: no `version` (the lock pins the
commit, like every other unpinned spec), and keep `event` and `config`.
**Code:** the block after the change:
```lua
  -- Fast navigation (hop replaces built-in f)
  {
    "smoka7/hop.nvim",
    event = "VeryLazy",
    config = function()
      require("config.hop")
    end,
  },
```
**Impact:** lazy's url for `hop.nvim` becomes `https://github.com/smoka7/hop.nvim.git`. An
installed live dir keeps its phaazon origin until `:Lazy update hop.nvim`, because lazy never
re-targets at startup. That is why `up --live` needs Step 4.

### Step 2: seed.lua: moved detection, follow-the-spec, pin loop
**File:** `.claude/skills/verify-nvim-config/scripts/seed.lua:18-73` (from `local lazy = require("lazy")` through the end of
the `.cloning` cleanup loop; phases 7 and 9 do not touch this range)
**Change:** replace the whole range with the code below. The `lazy restore/install` step is
unchanged except that it is now preceded by two requires. The old pin loop becomes the `elseif want`
branch, with the same behaviour and log texts, and it now also records the branch for the lock.
**Code:**
```lua
local lazy = require("lazy")
local Config = require("lazy.core.config")
local Git = require("lazy.manage.git")
local lock = vim.fn.stdpath("config") .. "/lazy-lock.json"
step(update and "lazy update" or "lazy restore/install", function()
  if update then
    lazy.update { wait = true, show = false }
  elseif vim.uv.fs_stat(lock) then
    lazy.restore { wait = true, show = false }
  else
    lazy.install { wait = true, show = false }
  end
end)

-- Mirror the lock, except where the spec moved. lazy re-targets an installed plugin only on
-- install/update/restore, and an unpinned spec follows GitHub's default branch, so the seed pins
-- every plugin to its lock commit itself. A plugin whose spec MOVED (it names a branch other than
-- the lock entry's, or a url other than the one the entry was written from) follows the spec
-- instead: pinning it back to the old commit would hide the very change under test. A plugin that
-- did not move but whose clone failed (gone from its remote) is copied from the owner's live dir
-- (read only). Every exception is logged.
local live_lazy = os.getenv("LIVE_LAZY")
-- lazy rewrites lazy-lock.json during its startup install, so read the copy taken before nvim ran.
local lock_orig = os.getenv("SEED_LOCK_ORIG") or lock
local ok_lock, lockdata = pcall(function()
  return vim.json.decode(table.concat(vim.fn.readfile(lock_orig), "\n"))
end)
if not ok_lock or type(lockdata) ~= "table" then
  lockdata = {}
end

local function git(dir, ...)
  local out = vim.fn.system { "git", "-C", dir, ... }
  return vim.trim(out), vim.v.shell_error == 0
end

-- The origin url as stored in .git/config (never insteadOf-rewritten), or nil.
local function origin_of(dir)
  if not (dir and vim.uv.fs_stat(dir .. "/.git")) then
    return nil
  end
  local url, ok = git(dir, "config", "--get", "remote.origin.url")
  return ok and url ~= "" and url or nil
end

local function norm(url)
  return url and (url:gsub("/+$", ""):gsub("%.git$", "")) or nil
end

-- The url a lock entry was written from: the seed lock records it; a lock taken from live (the
-- first seed, or a seed lock older than the url field) came from the owner's live dir.
local function lock_url(name, want)
  if want.url then
    return want.url
  end
  return live_lazy and origin_of(live_lazy .. "/" .. name) or nil
end

-- nil while the spec still describes the lock entry, else what moved.
local function moved_reason(p, want)
  if p.branch and want.branch and p.branch ~= want.branch then
    return ("branch %s -> %s"):format(want.branch, p.branch)
  end
  local from = lock_url(p.name, want)
  if p.url and from and norm(from) ~= norm(p.url) then
    return ("url %s -> %s"):format(from, p.url)
  end
  return nil
end

-- Put a moved plugin where its spec points: fetch when the dir already tracks the spec's url
-- (lazy's restore re-clones a plugin whose url changed), else a fresh clone made the way lazy
-- makes one; then check out lazy's own target for the spec (branch tip, tag, version or commit).
-- Returns the branch for the lock.
local function follow_spec(p)
  if origin_of(p.dir) and norm(origin_of(p.dir)) == norm(p.url) then
    if p.branch then
      git(p.dir, "remote", "set-branches", "--add", "origin", p.branch)
    end
    local out, ok = git(p.dir, "fetch", "--tags", "--force", "origin")
    if not ok then
      error("fetch from " .. p.url .. " failed: " .. out, 0)
    end
  else
    vim.fn.delete(p.dir, "rf")
    local args = { "git", "clone", "--filter=blob:none", "--origin=origin", "-c", "core.autocrlf=false" }
    if p.submodules ~= false then
      table.insert(args, "--recurse-submodules")
    end
    if p.branch then
      vim.list_extend(args, { "-b", p.branch })
    end
    vim.list_extend(args, { p.url, p.dir })
    local out = vim.fn.system(args)
    if vim.v.shell_error ~= 0 then
      error("clone of " .. p.url .. " failed: " .. vim.trim(out), 0)
    end
  end
  os.remove(p.dir .. ".cloning")
  local target = Git.get_target(p)
  if not (target and target.commit) then
    error("no commit for the spec's target on " .. tostring(target and target.branch), 0)
  end
  local out, ok = git(p.dir, "checkout", "-q", target.commit)
  if not ok then
    error("checkout " .. target.commit .. " failed: " .. out, 0)
  end
  return target.branch
end

-- The branch each plugin is on, for the seed lock: HEAD is detached after a pin or a follow, and
-- lazy's own lock rewrite would record GitHub's default branch for it.
local branch_of = {}
if not update then
  for _, p in pairs(Config.plugins) do
    local want = lockdata[p.name]
    local why = want and not p._.is_local and moved_reason(p, want)
    if why then
      local ok, res = pcall(follow_spec, p)
      if ok then
        branch_of[p.name] = res
        log(
          "MOVED plugin %s: %s; not pinned to the lock's %s@%s, follows the spec: %s@%s",
          p.name,
          why,
          want.branch,
          want.commit:sub(1, 7),
          res,
          (git(p.dir, "rev-parse", "HEAD")):sub(1, 7)
        )
      else
        log("FAIL plugin %s: the spec moved (%s): %s", p.name, why, tostring(res))
      end
    elseif want then
      if not vim.uv.fs_stat(p.dir) and live_lazy and vim.uv.fs_stat(live_lazy .. "/" .. p.name) then
        vim.fn.system { "cp", "-a", live_lazy .. "/" .. p.name, p.dir }
        -- lazy leaves <name>.cloning after the failed clone and treats it as an interrupted install
        -- (deletes the dir and re-clones on every start). Drop it with the copy in place.
        os.remove(p.dir .. ".cloning")
        log("WARN plugin %s: clone failed (gone from its remote?); copied from the live dir", p.name)
      end
      if vim.uv.fs_stat(p.dir) then
        local head = git(p.dir, "rev-parse", "HEAD")
        if head ~= want.commit then
          local branch = git(p.dir, "rev-parse", "--abbrev-ref", "HEAD")
          local _, pinned = git(p.dir, "checkout", "-q", want.commit)
          log(
            "WARN plugin %s: lazy left it on %s@%s, lock says %s@%s; pinned to the lock%s",
            p.name,
            branch,
            head:sub(1, 7),
            want.branch,
            want.commit:sub(1, 7),
            pinned and "" or " (CHECKOUT FAILED)"
          )
          head = git(p.dir, "rev-parse", "HEAD")
        end
        if head == want.commit then
          branch_of[p.name] = want.branch
        end
      end
    end
  end
end
for _, p in pairs(Config.plugins) do
  if vim.uv.fs_stat(p.dir .. ".cloning") and vim.uv.fs_stat(p.dir .. "/.git") then
    os.remove(p.dir .. ".cloning")
  end
  if not vim.uv.fs_stat(p.dir) and p.enabled ~= false then
    log("WARN plugin %s not installed", p.name)
  end
end
```
**Impact:** on the base spec nothing is moved: every lock entry's url (from the live dirs, all
`https://github.com/<owner>/<repo>.git`) equals its spec url, and no spec sets a branch that
differs from the lock. Behaviour is then identical to today. With Step 1 applied, `hop.nvim` is
moved: `url https://github.com/phaazon/hop.nvim.git -> https://github.com/smoka7/hop.nvim.git`.
lazy's `restore` has already re-cloned it from smoka7 (its `git.origin` task cleans and clones on
a url mismatch, then checks out the lock commit `1a1ecea`, which smoka7 contains), so
`follow_spec` fetches and checks out `origin/master`'s tip (`6e83486` at plan time).

### Step 3: seed.lua: write the seed lock from what is checked out
**File:** `.claude/skills/verify-nvim-config/scripts/seed.lua`, inserted immediately after the `.cloning` loop that ends Step 2's
block, and before `step("treesitter parsers", ...)`.
**Change:** a new step. It writes `$SEED_LOCK_OUT` in lazy's one-line-per-plugin format, adding `url`.
It runs in every mode, including `seed --update`.
**Code:**
```lua
-- The seed lock: what is checked out now, for every plugin lazy knows, with each dir's origin url
-- so the next seed can tell whether a spec moved since. Not lazy's rewrite (it records GitHub's
-- default branch for a detached HEAD) and not the old lock (it would undo a moved plugin).
-- Disabled plugins keep their old entry, as lazy keeps them.
step("seed lock", function()
  local out = assert(os.getenv("SEED_LOCK_OUT"), "SEED_LOCK_OUT unset")
  local entries = {}
  for name, e in pairs(lockdata) do
    if Config.spec.disabled[name] then
      entries[name] = e
    end
  end
  for _, p in pairs(Config.plugins) do
    if not p._.is_local and vim.uv.fs_stat(p.dir .. "/.git") then
      local head, ok = git(p.dir, "rev-parse", "HEAD")
      if ok then
        local info = Git.info(p.dir)
        entries[p.name] = {
          branch = branch_of[p.name] or (info and info.branch) or Git.get_branch(p),
          commit = head,
          url = origin_of(p.dir),
        }
      end
    end
  end
  local names = vim.tbl_keys(entries)
  table.sort(names)
  local lines = { "{" }
  for i, name in ipairs(names) do
    local e = entries[name]
    local fields = { ('"branch": %q'):format(e.branch), ('"commit": %q'):format(e.commit) }
    if e.url then
      table.insert(fields, ('"url": %q'):format(e.url))
    end
    table.insert(lines, ("  %q: { %s }%s"):format(name, table.concat(fields, ", "), i < #names and "," or ""))
  end
  table.insert(lines, "}")
  assert(vim.fn.writefile(lines, out) == 0, "cannot write " .. out)
  log("info seed lock: %d plugins", #names)
end)
```
**Impact:** the seed lock now matches the dirs, so a moved plugin is pinned at its new commit by
the next seed. Plugins removed from the spec drop out of the lock, as they do with lazy.

### Step 4: verify.sh: `PLUGIN_EXTRA_DATA` and `origin_url`
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:47`. Insert right after the line
`LIVE_TMUX_CONF="$(readlink -f "$HOME/.tmux.conf" 2>/dev/null || echo "$HOME/.tmux.conf")"`.
**Code:**
```bash

# Data a plugin keeps outside lazy/<name>, relative to the data dir's nvim/ (e.g. parsers it installs
# under site/), space-separated per lazy plugin name. When `up --live` replaces that plugin from the
# seed because its spec moved, each listed path that exists in the seed replaces the run's copy.
declare -A PLUGIN_EXTRA_DATA=()
```
**File:** same, insert right after the closing `}` of `repoint_data()` (base `:250`).
**Code:**
```bash

# A plugin dir's origin url as stored in its .git/config, without a trailing / or .git. Never
# `remote get-url`: that applies the caller's insteadOf rewrites (the owner's turn https into git@).
origin_url() { git -C "$1" config --get remote.origin.url 2>/dev/null | sed 's#/*$##; s#\.git$##'; }
```
**Impact:** none on their own.

### Step 5: verify.sh `cmd_seed`: the seed lock comes from seed.lua
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:158-210` (`cmd_seed`; no other phase edits it)
**Change:** three lines change. `lock.new.json` is cleared before the run, `SEED_LOCK_OUT` goes
into the env, and the copy-back of `lock.orig.json` and of lazy's rewrite is replaced with
"take `lock.new.json`, else keep the previous lock". The full function after the change:
**Code:**
```bash
cmd_seed() {
  local update=0
  [ "${1:-}" = --update ] && update=1
  local root; root="$(repo_root)"
  seed_lock -x
  mkdir -p "$SEED"/{config/nvim,data,state,cache,home,tmp,runtime}
  chmod 700 "$SEED/runtime"
  snapshot "$root" "$SEED/config/nvim" >/dev/null
  # The lock: the seed's own once it has one; the first seed starts from the owner's LIVE lock (read
  # only), so seeded runs install the plugin commits the owner actually runs. --update = latest.
  local lock_from=seed
  if [ -f "$SEED/lazy-lock.json" ]; then cp "$SEED/lazy-lock.json" "$SEED/config/nvim/lazy-lock.json"
  elif [ -f "$LIVE_CONFIG/lazy-lock.json" ]; then cp "$LIVE_CONFIG/lazy-lock.json" "$SEED/config/nvim/lazy-lock.json"; lock_from="live@$(git -C "$LIVE_CONFIG" --no-optional-locks rev-parse --short HEAD)"
  else rm -f "$SEED/config/nvim/lazy-lock.json"; lock_from=none; fi
  [ "$update" = 1 ] && { rm -f "$SEED/config/nvim/lazy-lock.json"; lock_from=latest; }
  rm -f "$SEED/lock.orig.json" "$SEED/lock.new.json"; [ -f "$SEED/config/nvim/lazy-lock.json" ] && cp "$SEED/config/nvim/lazy-lock.json" "$SEED/lock.orig.json"
  [ -d "$SEED/data" ] && chmod -R u+w "$SEED/data"
  : >"$SEED/seed.log"
  local path="$(dirname "$NVIM_BIN")"
  for t in "$PY" "$NODE" "$GO"; do [ -n "$t" ] && path="$path:$(dirname "$t")"; done
  # cargo is deliberately NOT on PATH: blink.cmp's `cargo build --release` would make rustup install
  # a nightly toolchain into the owner's ~/.rustup. blink downloads its prebuilt fuzzy library instead.
  echo "verify: seeding $SEED/data from $root (online: GitHub, npm, PyPI, Go proxy; this takes minutes)" >&2
  local rc=0
  env -i PATH="$path:/usr/bin:/bin" HOME="$SEED/home" USER="$(id -un)" SHELL=/bin/bash TERM=xterm-256color \
    LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    XDG_CONFIG_HOME="$SEED/config" XDG_DATA_HOME="$SEED/data" XDG_STATE_HOME="$SEED/state" \
    XDG_CACHE_HOME="$SEED/cache" XDG_RUNTIME_DIR="$SEED/runtime" TMPDIR="$SEED/tmp" \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/false \
    SSH_ASKPASS=/bin/false GIT_SSH_COMMAND=/bin/false \
    GOPATH="$SEED/tmp/go" GOMODCACHE="$SEED/tmp/go/mod" GOCACHE="$SEED/tmp/go/cache" GOTOOLCHAIN=auto \
    npm_config_cache="$SEED/tmp/npm" LIVE_LAZY="$LIVE_DATA/lazy" SEED_LOCK_ORIG="$SEED/lock.orig.json" \
    SEED_LOCK_OUT="$SEED/lock.new.json" SEED_LOG="$SEED/seed.log" SEED_UPDATE=$update \
    timeout 1800 "$NVIM_BIN" --headless -c "luafile $HERE/seed.lua" </dev/null >"$SEED/nvim.out" 2>&1 || rc=$?
  cat "$SEED/seed.log"
  # The seed's lock = what seed.lua found checked out (branch, commit and origin url per plugin).
  # Not lazy's rewrite (default branch for every pin) and not the old lock copied back (it would
  # undo a plugin whose spec moved). No new lock (seed.lua died first) keeps the previous one.
  if [ -s "$SEED/lock.new.json" ]; then cp "$SEED/lock.new.json" "$SEED/lazy-lock.json"
  else echo "verify: seed.lua wrote no lock; $SEED/lazy-lock.json left as it was" >&2; fi
  # Files in the seed are read-only so a run's hard-linked copy can never write through into it
  # (an in-place write fails with EACCES in the run instead). Directories stay writable.
  find "$SEED/data" -type f -perm /222 -exec chmod a-w {} +
  {
    echo "repo=$root"
    echo "head=$(git -C "$root" rev-parse --short HEAD)"
    echo "seeded=$(date -Iseconds)"
    echo "lock_from=$lock_from"
    echo "plugins=$(find "$SEED/data/nvim/lazy" -mindepth 1 -maxdepth 1 -type d | wc -l)"
    echo "mason=$(find "$SEED/data/nvim/mason/packages" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
    echo "manifest=$(seed_manifest)"
  } >"$SEED/meta"
  cat "$SEED/meta"
  grep -q '^done' "$SEED/seed.log" || die "seed did not finish (exit $rc; see $SEED/nvim.out)"
  ! grep -q '^FAIL' "$SEED/seed.log" || die "seed finished with failures (above)"
}
```
**Impact:** `$SEED/lazy-lock.json` gains a `url` per entry after the next seed. Seeded runs copy it
as their lock, and lazy ignores the extra key.

### Step 6: verify.sh `cmd_up`: replace a moved plugin on `--live`; meta, stderr, doctor
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh`, four hunks inside `cmd_up` and one in `cmd_doctor`, anchored on text
(phase 4 has removed `bin,sink` from the mkdir line and the `write_fake_opencode` call, so the line
numbers shift).

**6a.** The line `  local filled=""` (base `:286`) becomes:
```bash
  local filled="" replaced=""
```

**6b.** The whole `live)` arm of `case "$mode" in` (base `:298-322`, from `    live)` to its `      ;;`)
becomes:
```bash
    live)
      # The checkout's update on top of the owner's live environment: the live lock, the live
      # plugins and Mason tools, the live oh-my-tmux. Full copies (never hard links: the owner's
      # files are writable, so a link would let the run write into them). Only lazy/, mason/ and
      # rplugin.vim: the rest of ~/.local/share/nvim (avante/, backup/, telescope_history) is
      # private state a verify run has no use for.
      echo "live_fp=$(live_fingerprint)" >"$dir/live.before"
      cp "$LIVE_CONFIG/lazy-lock.json" "$dir/xdg/config/nvim/lazy-lock.json"
      cp -a "$LIVE_DATA/lazy" "$LIVE_DATA/mason" "$dir/xdg/data/nvim/"
      [ -f "$LIVE_DATA/rplugin.vim" ] && cp -a "$LIVE_DATA/rplugin.vim" "$dir/xdg/data/nvim/"
      repoint_data "$dir" "$(dirname "$LIVE_DATA")"
      # Two kinds of plugin come from the verify seed instead, and are said so:
      # - filled: one the update adds is not in the live dirs yet (live nvim would fetch it online
      #   on its next start).
      # - replaced: one whose spec MOVED. The seed follows the spec (seed.lua); live keeps the old
      #   one, because lazy never re-targets an installed plugin at startup. Moved = the seed lock's
      #   branch differs from the live lock's, or the two dirs' origin urls differ. The run's lock
      #   takes the seed's entry, and PLUGIN_EXTRA_DATA[name] comes from the seed too.
      if [ -d "$SEED/data/nvim/lazy" ]; then
        command -v jq >/dev/null || die "--live needs jq (to compare the seed lock with the live lock)"
        seed_lock -s
        local p x sb lb su lu lock="$dir/xdg/config/nvim/lazy-lock.json"
        for p in "$SEED/data/nvim/lazy"/*/; do
          p="$(basename "$p")"
          grep -q "\"$p\"" "$dir/xdg/config/nvim/lua/plugin_specs.lua" "$SEED/lazy-lock.json" 2>/dev/null || continue
          if [ ! -e "$dir/xdg/data/nvim/lazy/$p" ]; then
            cp -a "$SEED/data/nvim/lazy/$p" "$dir/xdg/data/nvim/lazy/" && chmod -R u+w "$dir/xdg/data/nvim/lazy/$p"
            filled="$filled $p"
            continue
          fi
          sb="$(jq -r --arg n "$p" '.[$n].branch // empty' "$SEED/lazy-lock.json" 2>/dev/null || true)"
          [ -n "$sb" ] || continue
          lb="$(jq -r --arg n "$p" '.[$n].branch // empty' "$lock" 2>/dev/null || true)"
          su="$(origin_url "$SEED/data/nvim/lazy/$p")"
          lu="$(origin_url "$dir/xdg/data/nvim/lazy/$p")"
          [ "$sb" != "${lb:-$sb}" ] || [ "$su" != "$lu" ] || continue
          echo "$p: live ${lb:-?}@$(git -C "$dir/xdg/data/nvim/lazy/$p" rev-parse --short HEAD 2>/dev/null) ${lu:-?} -> seed $sb@$(git -C "$SEED/data/nvim/lazy/$p" rev-parse --short HEAD 2>/dev/null) ${su:-?}" \
            >>"$dir/evidence/00-up-replaced.txt"
          rm -rf "$dir/xdg/data/nvim/lazy/$p"
          cp -a "$SEED/data/nvim/lazy/$p" "$dir/xdg/data/nvim/lazy/" && chmod -R u+w "$dir/xdg/data/nvim/lazy/$p"
          jq --arg n "$p" --slurpfile s "$SEED/lazy-lock.json" '.[$n] = $s[0][$n]' "$lock" >"$lock.tmp" && mv -f "$lock.tmp" "$lock"
          for x in ${PLUGIN_EXTRA_DATA[$p]:-}; do
            [ -e "$SEED/data/nvim/$x" ] || continue
            rm -rf "$dir/xdg/data/nvim/$x"
            mkdir -p "$(dirname "$dir/xdg/data/nvim/$x")"
            cp -a "$SEED/data/nvim/$x" "$dir/xdg/data/nvim/$x" && chmod -R u+w "$dir/xdg/data/nvim/$x"
            echo "  + $x from the seed" >>"$dir/evidence/00-up-replaced.txt"
          done
          replaced="$replaced $p"
        done
        flock -u 9
      fi
      [ -f "$REAL_HOME/.cache/nvim/dashboard_ascii_art.txt" ] && cp "$REAL_HOME/.cache/nvim/dashboard_ascii_art.txt" "$dir/xdg/cache/nvim/"
      ;;
```

**6c.** In the meta block, the `if [ "$mode" = live ]; then ... fi` (base `:344-349`) becomes:
```bash
    if [ "$mode" = live ]; then
      echo "live_head=$(git -C "$LIVE_CONFIG" --no-optional-locks rev-parse --short HEAD)"
      echo "live_dirty=$(git -C "$LIVE_CONFIG" --no-optional-locks status --porcelain | wc -l)"
      echo "filled_from_seed=${filled# }"
      echo "replaced_from_seed=${replaced# }"
      sed -n 's/^live_fp=/live_fp=/p' "$dir/live.before"
    fi
```

**6d.** Right after the line
`  [ -n "$filled" ] && echo "verify: --live: not in the live dirs, taken from the seed:$filled (live nvim would fetch these online on its next start)" >&2`
(base `:373`), insert:
```bash
  [ -n "$replaced" ] && echo "verify: --live: spec moved (seed lock branch or origin url differs from live), replaced from the seed:$replaced (evidence/00-up-replaced.txt; live keeps the old ones until the owner runs :Lazy update on them)" >&2
```

**6e.** `cmd_doctor`: the line (base `:446`)
`    echo "live     info live checkout @ $(meta "$dir" live_head) (dirty $(meta "$dir" live_dirty)), filled from seed: $(meta "$dir" filled_from_seed)"`
becomes:
```bash
    echo "live     info live checkout @ $(meta "$dir" live_head) (dirty $(meta "$dir" live_dirty)), filled from seed: $(meta "$dir" filled_from_seed), replaced from seed (spec moved): $(meta "$dir" replaced_from_seed)"
```
**Impact:** under the old seed lock (no `url`), the seed's `hop.nvim` dir was copied from live, so
its origin is phaazon in both places. The branches are equal too, so nothing is replaced and the
change is safe to commit before the re-seed. After the re-seed `hop.nvim` is replaced, while
`nvim-treesitter` (seed lock `master` = live `master`, same url) is not. `seed_lock -s` keeps a
concurrent `seed` from rewriting the seed mid-copy, as seeded mode already does. `set -e` safety:
every new `[ ... ] && ...` is either a non-final list or inside an `if`, and the command
substitutions carry `|| true` or end in `sed`.

### Step 7: SKILL.md: seed and live bullets, Gotchas
**File:** `.claude/skills/verify-nvim-config/SKILL.md:41-51` (Launch: the `- **seed**` and `- **live**` bullets; the
earlier phases do not touch them)
**Change:** replace both bullets with:
```markdown
- **seed** (`$VERIFY_HOME/.seed`, 93 plugins + 13 treesitter parsers + 9 Mason packages, ~570 MB)
  is the only step that goes online: GitHub (lazy clones), the Mason registry, npm, PyPI and the Go
  proxy (Go may fetch a newer toolchain into the seed). The first seed starts from the owner's
  **live** `lazy-lock.json` and pins every plugin to it, even where lazy will not, except a plugin
  whose spec moved, which follows the spec (see Gotchas). The seed's lock (`.seed/lazy-lock.json`)
  is written from what is checked out: branch, commit and origin `url` per plugin. A plugin GitHub
  no longer serves is copied from the live dir. `seed --update` takes the latest of everything
  instead (what `:Lazy update` / a fresh install would get). Seed files are read-only. Runs
  hard-link them, and `doctor` fails if anything wrote through.
- **live** copies (never links) `~/.local/share/nvim/{lazy,mason,rplugin.vim}`, the live
  `lazy-lock.json`, the dashboard's cached art and the oh-my-tmux behind `~/.tmux.conf`. Two kinds
  of plugin come from the seed instead (so `seed` after changing a spec): one the change adds (not
  in the live dirs yet; live nvim would fetch it online on its next start), listed as
  `filled_from_seed`; and one whose spec **moved** (the seed lock's branch differs from the live
  lock's, or the seed dir's `origin` url differs from the live dir's), listed as
  `replaced_from_seed`. A replaced plugin also brings its seed lock entry into the run's lock, and
  whatever `PLUGIN_EXTRA_DATA` in `verify.sh` names for it outside `lazy/` (e.g. parsers under
  `site/`). `evidence/00-up-replaced.txt` shows live's and the seed's branch, commit and url.
```
**File:** `.claude/skills/verify-nvim-config/SKILL.md:156-161` (base numbering; the two bullets that start
`- **lazy ignores a lock entry whose branch differs from the spec's.**` and
`- **\`phaazon/hop.nvim\` is gone from GitHub.**`; phases 4 and 5 shift them up)
**Change:** replace both bullets with:
```markdown
- **lazy never re-targets an installed plugin at startup.** A spec's url or branch change reaches
  a plugin dir only through `:Lazy update`/`restore` (a url change deletes and re-clones) or a
  fresh install, and an unpinned spec follows GitHub's default branch on install. So the seed pins
  every plugin to its lock commit itself (`WARN ... pinned to the lock` when lazy left it
  elsewhere; at this commit that is `nvim-treesitter`, unpinned, default branch `main`, lock
  `master`), **unless the spec moved**: it names a `branch` other than the lock entry's, or a url
  other than the one the entry was written from (the seed lock's `url`; for a lock taken from
  live, the live dir's `origin`). A moved plugin follows the spec (fetch, or a fresh clone when
  the url changed, then lazy's own target: branch tip, tag or version), the log says
  `MOVED plugin <name>: ...`, and the new seed lock records it, so the next seed pins it there.
  An unpinned spec is never moved by its branch alone. `up --live` replaces a moved plugin from
  the seed (see Launch). Treat `seed --update` as "what a fresh install gets".
- **`phaazon/hop.nvim` is gone from GitHub** (`git ls-remote` says `Repository not found`). The
  spec uses the maintained fork `smoka7/hop.nvim` (same API, same lock key `hop.nvim`). The
  owner's live dir keeps the phaazon origin until the Deploy runbook re-points it (or `:Lazy update
  hop.nvim`); until then `up --live` lists it in `replaced_from_seed`. The generic fallback stays: a plugin that did
  not move but whose clone fails is copied from the live dir, and lazy's `<name>.cloning` marker
  is removed (a leftover marker makes lazy delete and re-clone on every start).
```
**Impact:** docs only. The nvim-treesitter clause is true until phase 9 pins `branch = "main"`,
and phase 9 rewrites it (Handoffs).

### Step 8: features/editing-mappings.md: hop journey
**File:** `.claude/skills/verify-nvim-config/features/editing-mappings.md` (`f`/`F` are editing/navigation mappings, so the
feature already has its README row and no new file is needed)
**Change:** three edits.

(a) In `## Sub-features`, append after the `- \`jk\` save, ...` bullet:
```markdown
- `f` (normal, visual): hop.nvim (`smoka7/hop.nvim`) draws a one- or two-letter label over the
  first letter of every word in the visible windows; typing a label jumps there, `Escape`
  cancels. `F`: type a character, then a label for its occurrences before the cursor (a single
  occurrence jumps straight there). Replaces the built-in `f{char}`/`F{char}` motions.
```
(b) In `## How to get to it (user POV)`, append the sentence:
```markdown
Press `f`, read the label drawn over the word you want, type it.
```
(c) At the end of `## Driving it with verify.sh` (after the `C-o` block), append the block below.
The implementer replaces the two "End state seen" lines with the values from the Proof run
(`smoka7`, seeded and live), and keeps the base line as written.
````markdown
hop (`f` labels, jump, cancel; `F` with a unique character). `go.mod` has 7 words, so every label
is one letter (`sample.lua` has as many words as hop has label keys, so some labels get two
letters there):

```sh
$V keys RUN : e Space go.mod Enter
$V lua RUN 'vim.api.nvim_win_get_cursor(0)'      # { 1, 0 }
$V keys RUN f                                    # labels over every word
$V screen RUN f-hints
S=$(ls -t "$EVIDENCE"/*-screen-f-hints.txt | head -1)
L=$(awk '$(NF-1) ~ /^[a-z]o$/ && $NF ~ /2$/ {print substr($(NF-1),1,1)}' "$S")   # the label over `go` (line 3)
$V keys RUN "$L"
$V lua RUN 'vim.api.nvim_win_get_cursor(0)'      # { 3, 0 }
$V keys RUN F /                                  # `/` occurs once before the cursor: no label, jumps
$V lua RUN 'vim.api.nvim_win_get_cursor(0)'      # { 1, 18 }
$V keys RUN f Escape                             # cancelled: the cursor stays at { 1, 18 }
```

End state seen on the base (`phaazon/hop.nvim@1a1ecea`, seeded, 2026-11-04): after `f` the
screen shows `eodule xxample.qom/pork` and `to o.v2` (label `t` over `go`); `t` -> `{ 3, 0 }`;
`F /` -> `{ 1, 18 }`; `f Escape` leaves `{ 1, 18 }`.
End state seen (`smoka7/hop.nvim@<sha7>`, seeded and `--live`): <fill from the Proof run>.
````
(d) In `## Gotchas`, append:
```markdown
- hop maps `f`/`F` on `VeryLazy`; `up` returns after VeryLazy, so they exist by then. Labels depend
  on hop's ordering and the words on screen: read the label from the screen, never hard-code it.
  An extracted label of `g` means no labels were drawn (`go` unchanged). RPC (`lua`, `wait`) while
  hop waits for a label: not tried; press the label or `Escape` first.
- On `--live` before the owner deploys, hop comes from the seed (`replaced_from_seed: hop.nvim`):
  the live dir still tracks the deleted `phaazon/hop.nvim`.
```
**Impact:** docs only. No `features/README.md` row is needed, because the feature file is already
indexed.

## Principles applied

- Subtract before you add: `cmd_seed`'s copy-back of `lock.orig.json` and its lazy-rewrite fallback are deleted, not worked around. The seed lock now has one source (seed.lua's writer), so no third lock path sits on top of two.
- Laziness protocol: url and branch moves share one rule and one code path (`follow_spec`: fetch when the dir already tracks the spec url, else clone). Target selection reuses lazy's own `Git.get_target` instead of re-implementing tip/tag/version. The hop spec is a plain string, and `config/hop.lua` is untouched because the API matches.
- Boundary discipline: url comparison always goes through one normaliser per side (`norm` in seed.lua, `origin_url` in verify.sh), and both read the raw `remote.origin.url`. The owner's `insteadOf` rewrite (https -> git@, measured) can therefore never fake a "moved" plugin.
- Encode lessons in structure: the seed lock records each plugin's `url`. "Which repo was this commit taken from" becomes data the next seed and `up --live` compare, instead of a hand-maintained Gotcha per plugin, so hop's special case turns into the generic rule.
- Fix root causes: the reproduction is `git ls-remote https://github.com/phaazon/hop.nvim` -> `Repository not found`, and the cause is the spec string at `plugin_specs.lua:513`. The harness change exists because `seed.lua:48-62` would have pinned the fork back to `1a1ecea` and `verify.sh:304-314` would have kept live's phaazon dir. Both are traced to those lines.
- Prove it works: every claim below is a `verify.sh` drive or a file read back, on seeded and `--live`. The base is captured first.

## Verification

**Build:**
```sh
cd "$WT"   # this phase's own worktree root (index § Execution rules)
bash -n .claude/skills/verify-nvim-config/scripts/verify.sh; echo "bash-n=$?"          # bash-n=0
/opt/nvim-linux-x86_64/bin/nvim --clean --headless \
  -c 'lua local f, e = loadfile(".claude/skills/verify-nvim-config/scripts/seed.lua"); if not f then io.stderr:write(e .. "\n"); vim.cmd("cquit 1") end' \
  -c 'qa!'; echo "loadfile=$?"                                                            # loadfile=0
```
**Tests:** no unit tests in this repo. The journeys below are the tests.

**Proof:**
- Harness: `.claude/skills/verify-nvim-config` (`scripts/verify.sh`), on the installed nvim 0.11.5
  (default `NVIM_BIN`; do not set `VERIFY_NVIM`).
- Feature-map entries: `features/editing-mappings.md` (hop journey, Step 8).
- Setup for every journey (zsh-safe):
  ```sh
  cd "$WT"   # this phase's own worktree root (index § Execution rules)
  V=.claude/skills/verify-nvim-config/scripts/verify.sh
  VH=$HOME/.local/state/nvim-config-verify; S=$VH/.seed
  P8=$VH/phase8-evidence; mkdir -p "$P8"      # not a run dir (`ls` only lists [0-9]* dirs)
  ```
  `up` prints `RUN=`/`EVIDENCE=`. Set `RUN=<that>`, `R=$VH/$RUN`, `EVIDENCE=$R/evidence` after each `up`.
- The hop journey `HOP(RUN)` used below. Run it exactly as in features/editing-mappings.md (Step 8c), plus:
  ```sh
  $V keys $RUN : e Space sample.lua Enter
  $V screen $RUN sample-before;  grep -c 'local M = {}' "$(ls -t $EVIDENCE/*-screen-sample-before.txt | head -1)"   # >= 1
  $V keys $RUN f
  $V screen $RUN sample-hints;   grep -c 'local M = {}' "$(ls -t $EVIDENCE/*-screen-sample-hints.txt | head -1)"    # 0 (labels overlay the line)
  $V keys $RUN Escape
  ```
  Then the go.mod block from Step 8c. **Passes when:** the label over `go` is one lowercase letter
  other than `g`, the jump gives `{ 3, 0 }`, `F /` gives `{ 1, 18 }`, `f Escape` leaves `{ 1, 18 }`,
  and `$V lua $RUN 'vim.fn.execute("messages")'` has no `E[0-9]+:`/`Error` line.

**Journeys** (in order; J0 runs on the tree as it is after phase 7, before any edit of this phase):

- **J0 Base: the hop remote is gone (must show the failure).**
  ```sh
  cp "$S/seed.log" "$P8/base-seed.log"; cp "$S/lazy-lock.json" "$P8/base-seed-lock.json"
  { GIT_CONFIG_GLOBAL=/dev/null git ls-remote https://github.com/phaazon/hop.nvim; echo "exit=$?"; } >"$P8/base-ls-remote-phaazon.txt" 2>&1
  { GIT_CONFIG_GLOBAL=/dev/null git ls-remote https://github.com/smoka7/hop.nvim HEAD; echo "exit=$?"; } >"$P8/base-ls-remote-smoka7.txt" 2>&1
  git -C "$S/data/nvim/lazy/hop.nvim" config --get remote.origin.url >"$P8/base-seed-hop-origin.txt"
  grep -n 'hop.nvim' "$P8/base-seed.log" >"$P8/base-seed-log-hop.txt" || true
  ```
  Passes when `base-ls-remote-phaazon.txt` contains `Repository not found` and `exit=128`,
  `base-ls-remote-smoka7.txt` shows a sha with `exit=0`, and `base-seed-hop-origin.txt` =
  `https://github.com/phaazon/hop.nvim.git`. Note: at plan time `seed.log` (seeded 10:15) has **no**
  `WARN plugin hop.nvim: clone failed` line, because that seed found hop.nvim already present and
  never cloned it. Record whatever `base-seed-log-hop.txt` holds. The WARN appears only in a seed
  that had to clone hop, and the phaazon origin of the seed's copy is the evidence of that copy.
  Then `$V up --live` on the base and record
  `meta` (`grep -E 'filled_from_seed|replaced_from_seed' $R/meta` shows no `replaced_from_seed` key),
  `git -C $R/xdg/data/nvim/lazy/hop.nvim config --get remote.origin.url` = phaazon, and
  `$V lua $RUN 'require("lazy.core.config").plugins["hop.nvim"].url'` =
  `https://github.com/phaazon/hop.nvim.git`, the url a fresh install would clone, and it is gone.
  `$V down $RUN`.

- **J1 Machinery is a no-op on the old seed (neighbor check, before re-seeding).** Apply Steps 1-8
  and run Build (the old seed is still in place). `$V up --live` must print no `replaced from the seed` line. `grep replaced_from_seed $R/meta`
  prints `replaced_from_seed=`, which is empty: the old seed's hop dir has a phaazon origin like live's.
  `test ! -e $EVIDENCE/00-up-replaced.txt`. `$V doctor $RUN; echo "doctor=$?"`: `doctor=0`.
  `$V down $RUN`.

- **J2 Re-seed follows the moved spec.** Online, about 2+ minutes. Never pipe it into `head`/`sed`.
  **Seed guard (invariant 5):** a seed rewrites the shared seed under any seeded run that is still up
  (phases 1-3 may still be running in their own worktrees), and that run's `doctor` would then FAIL its
  `seed` line. So first wait until no run is up: `until [ -z "$($V ls | awk '$2 == "up"')" ]; do sleep 30; done`
  (use the Monitor tool with this until-loop; never a foreground sleep), and only then seed. The same
  guard precedes J3's seed.
  ```sh
  $V seed >"$P8/seed-after.out" 2>&1; echo "seed=$?"                     # seed=0
  cp "$S/seed.log" "$P8/seed-after.log"; cp "$S/lazy-lock.json" "$P8/seed-after-lock.json"
  grep -c '^MOVED' "$S/seed.log"                                          # 1
  grep '^MOVED' "$S/seed.log"   # MOVED plugin hop.nvim: url https://github.com/phaazon/hop.nvim.git -> https://github.com/smoka7/hop.nvim.git; not pinned to the lock's master@1a1ecea, follows the spec: master@6e83486
  grep 'hop.nvim' "$S/seed.log" | grep -c '^WARN'                          # 0
  grep -c '^FAIL' "$S/seed.log"                                           # 0
  grep '^ok   seed lock' "$S/seed.log"; grep '^info seed lock' "$S/seed.log"   # info seed lock: 93 plugins
  jq -r '."hop.nvim" | .branch + " " + .commit + " " + .url' "$S/lazy-lock.json"
  GIT_CONFIG_GLOBAL=/dev/null git ls-remote https://github.com/smoka7/hop.nvim HEAD | cut -f1
  git -C "$S/data/nvim/lazy/hop.nvim" config --get remote.origin.url
  jq -r '."nvim-treesitter" | .branch + " " + .commit' "$S/lazy-lock.json"
  jq length "$S/lazy-lock.json"; grep '^plugins=' "$S/meta"
  ```
  Passes when the lock's hop.nvim is `master <sha> https://github.com/smoka7/hop.nvim.git` with
  `<sha>` equal to the smoka7 `ls-remote HEAD` (`6e83486f…` at plan time), the seed dir's origin
  is the smoka7 url, `nvim-treesitter` is still `master 42fc28ba918343ebfd5565147a42a26580579482`
  (non-moved pin preserved), the lock length is 93, and `plugins=93`.

- **J3 The next seed pins the moved plugin at its new commit (the lock round trip).**
  (Seed guard first, as in J2.) `$V seed >"$P8/seed-again.out" 2>&1; echo "seed=$?"`. Passes when it prints `seed=0`,
  `grep -c '^MOVED' $S/seed.log` = `0`, and `jq -r '."hop.nvim".commit' $S/lazy-lock.json` equals the J2 commit.
  `cp $S/seed.log $P8/seed-again.log`.

- **J4 `up --live` replaces hop from the seed; hop works.**
  ```sh
  $V up --live 2>"$P8/up-live.stderr"; cat "$P8/up-live.stderr"
  grep -E '^(filled|replaced)_from_seed=' $R/meta                # replaced_from_seed=hop.nvim
  cat $EVIDENCE/00-up-replaced.txt   # hop.nvim: live master@1a1ecea https://github.com/phaazon/hop.nvim -> seed master@6e83486 https://github.com/smoka7/hop.nvim
  git -C $R/xdg/data/nvim/lazy/hop.nvim config --get remote.origin.url          # https://github.com/smoka7/hop.nvim.git
  git -C $R/xdg/data/nvim/lazy/hop.nvim rev-parse HEAD                          # = seed lock commit
  jq -c '."hop.nvim"' $R/xdg/config/nvim/lazy-lock.json                         # = jq -c '."hop.nvim"' $S/lazy-lock.json
  $V lua $RUN 'require("lazy.core.config").plugins["hop.nvim"].url'             # https://github.com/smoka7/hop.nvim.git
  ```
  `up-live.stderr` contains `replaced from the seed: hop.nvim`, and `replaced_from_seed` lists
  **only** `hop.nvim` (`nvim-treesitter` is absent). Then HOP($RUN) passes, and
  `$V doctor $RUN; echo "doctor=$?"` prints `doctor=0`, a `live     ok` line, and a `live     info`
  line ending in `replaced from seed (spec moved): hop.nvim`. `$V down $RUN`. Owner untouched:
  `git -C ~/.local/share/nvim/lazy/hop.nvim config --get remote.origin.url` is still the phaazon url, and
  `jq -c '."hop.nvim"' ~/.config/nvim/lazy-lock.json` is still `1a1ecea…`.

- **J5 Seeded `up`: hop from smoka7 works.** `$V up`, then
  `git -C $R/xdg/data/nvim/lazy/hop.nvim config --get remote.origin.url` = smoka7 url and
  `grep replaced_from_seed $R/meta` prints nothing (seeded meta has no live keys). HOP($RUN)
  passes, and `$V doctor $RUN; echo "doctor=$?"` gives `doctor=0` with
  `seed     ok   shared seed unchanged since it was built`. `$V down $RUN`.

- **Neighbor check:** the existing feature most likely to break is the seed itself
  (non-moved pins, treesitter step, Mason step) and `--live` for other plugins. Covered by J2's
  `FAIL`=0, nvim-treesitter's unchanged pin and the `ok   treesitter parsers`/`ok   mason packages`
  lines (`grep -E '^ok   (treesitter parsers|mason packages)' $S/seed.log` prints 2 lines), J1's
  empty `replaced_from_seed`, and J4's "only hop.nvim". Also re-run `features/startup.md`'s first
  journey on J5's run (`count = 93`).

- **Evidence index:** after the last `down`, write `$WT/.workflows/plan/fix-bugs-nvim-0-12/evidence-phase-8.md`
  (this phase's own file, committed on its own per execution rule 4; phase 9 indexes it):
  ```markdown
  ## Phase 8
  - base: $P8/base-ls-remote-phaazon.txt, base-ls-remote-smoka7.txt, base-seed-hop-origin.txt, base-seed.log, base-seed-lock.json; base --live run <RUN>/evidence
  - no-op on old seed: <J1 RUN>/evidence (+ doctor)
  - re-seed: $P8/seed-after.out, seed-after.log, seed-after-lock.json; second seed: $P8/seed-again.log
  - --live after: <J4 RUN>/evidence (00-up-replaced.txt, hop screens/lua, doctor), $P8/up-live.stderr
  - seeded after: <J5 RUN>/evidence (hop screens/lua, doctor)
  ```
  with real run ids and absolute paths.
- Cost: no paid drives. Two online seeds (~2-4 min each), on GitHub and the Mason registry only.

**Exit criteria:** `phaazon/hop.nvim` appears nowhere in `lua/`. After `verify.sh seed` the seed log
has exactly one `MOVED plugin hop.nvim` line and no hop WARN, and the seed lock's `hop.nvim` is
smoka7's HEAD with the smoka7 `url`. A second seed pins it there without a MOVED line. `up --live`
lists `replaced_from_seed=hop.nvim` (only), and its hop dir tracks smoka7. On both `--live` and
seeded runs, `f` draws labels, a label jumps to `{ 3, 0 }`, `F /` jumps to `{ 1, 18 }`, and
`doctor` exits 0. Two commits plus the `docs(evidence): phase 8 ...` commit, not pushed.

## Handoffs

- **Phase 9 (nvim-treesitter `main`)**:
  - Set `branch = "main"` in the specs; the seed then logs
    `MOVED plugin nvim-treesitter: branch master -> main ...` (and the same for textobjects), and
    `up --live` replaces both until Deploy.
  - Wire parsers through the hook:
    `PLUGIN_EXTRA_DATA[nvim-treesitter]="site/parser site/queries"` (or whatever main writes under
    `stdpath('data')/site`), declared next to the `declare -A` line in `verify.sh`.
  - Note that `--live` copies only `lazy/ mason/ rplugin.vim`, never `site/`. After Deploy, when
    nothing is "moved" any more, a `--live` run would lack the live parsers, so phase 9 must add
    `site/` (or `site/parser`) to the live copy in `cmd_up`.
  - go.nvim's commit bump is not a move, because its url and branch are the same. Phase 9 bumps it via
    the seed lock (edits `$SEED/lazy-lock.json`'s `go.nvim.commit` with `jq`, keeping `branch` and `url`,
    before `seed`), and extends the live replacement test inside this phase's loop with one more
    clause, `|| seed_commit_unknown_to_live "$p" "$dir/xdg/data/nvim/lazy/$p"` (the seed lock pins a
    commit the live clone never fetched). The replacement body, `00-up-replaced.txt`, the lock
    entry copy and `PLUGIN_EXTRA_DATA` stay this phase's code, unchanged.
  - Rewrite the SKILL.md Gotcha clause "at this commit that is `nvim-treesitter`, unpinned, default
    branch `main`, lock `master`".
- **Phase 9 (feature map)**: add a `replaced_from_seed` gotcha to `features/live-environment.md`
  (next to the `filled_from_seed` one) and update its journey summary. In `features/README.md`, the
  Editing mappings row now also covers hop's `f`/`F`, and the "Known on the base" column can note
  "hop.nvim's remote is gone (phaazon)". This phase did not touch either file (invariant 6).
- **Deploy**: the seed lock entries now carry `url`. Copying them into the live
  `lazy-lock.json` is harmless, since lazy ignores the key and drops it on its next rewrite. The
  Deploy runbook (phase-9.md D4) moves `hop.nvim` with plain git, not `Lazy! restore`: `remote set-url
  origin <seed lock url>`, fetch the lock branch, check out the lock commit (no build hooks run; see
  the index Decisions). The url comes from the seed lock's `url` field (raw `.git/config` value), never
  from `git remote get-url`, which applies the owner's `insteadOf` rewrite.
- Not done here: `lua/config/hop.lua` options (`multi_windows`, `keys`) are unchanged by
  design. smoka7's newer options (e.g. `hint_type`) are not adopted.

## Rollback

`git revert <fix(hop) commit> <feat(verify) commit>` (newest first). Then put the seed back:
`cp "$HOME/.local/state/nvim-config-verify/phase8-evidence/base-seed-lock.json" "$HOME/.local/state/nvim-config-verify/.seed/lazy-lock.json"`
followed by `$V seed`. The pre-phase seed.lua would otherwise pin the reverted phaazon spec to
smoka7's commit, which the copied phaazon dir lacks. Nothing in `~/.config/nvim` or
`~/.local/share/nvim` was written.

## Risks

- `seed --update`, or any seed whose lock records a different branch than live's for an
  **unpinned** plugin (for example a repo that renamed its default branch), makes `up --live` replace
  that plugin from the seed. It is listed in `replaced_from_seed` and in `00-up-replaced.txt`, so it
  stays visible.
- After this phase's seed, a seed built from a checkout that still says `phaazon/hop.nvim` (for
  example `~/nvim-config`) sees hop as moved and fails cloning phaazon (`FAIL plugin hop.nvim`). That is
  correct, because that config cannot install hop, but it is louder than before.
- hop's label order may differ between phaazon `1a1ecea` and smoka7 tip, so the journey reads the
  label from the screen and never hard-codes it.
