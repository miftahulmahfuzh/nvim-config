> Adopted from `.workflows/orchestration/nvim-0-12-clean/PLAN.md` phase 3. Source: `.workflows/plan/nvim-0-12-clean/phase-3.md`.
> Written and reconciled by /analyze — edit the source, not this copy.

# Phase 3: Plugin moves: blink.cmp v1, git-conflict deprecation-free fork

**Plan set:** `NVIM_0_12_CLEAN_PLAN.md`
**Analysis:** `.workflows/analyze/20261104-121422-N12C_code_analyzer.md`
**Satisfies:** R2 (no `client.request is deprecated`), R4 (no git-conflict `vim.highlight` / `vim.validate{}` deprecations)
**Depends on:** Phase 2 (`features/lsp.md` already has phase 2's subsections; the before runs include phase 2's fixes) and Phase 1 (this phase edits `verify.sh` and `SKILL.md` on top of phase 1's hunks)
**Difficulty:** HARD
**Package:** `lua/` + the verify seed (`.claude/skills/verify-nvim-config/scripts/`)

---

## Goal

blink.cmp runs v1.10.2 (`78336bc`), which calls `client:request`, so LSP completion no longer prints
`client.request is deprecated`. Its Rust fuzzy matcher is the prebuilt library for that tag, and the seed
fetches it, because runs have no network. git-conflict.nvim comes from `stryukovsky/git-conflict.nvim@63c5b42`
(upstream `a1badcd` plus only the `vim.hl` / positional `vim.validate` swaps), so `:checkhealth vim.deprecated`
reports `No deprecated functions detected`. Completion keymaps, command-line completion, the git-conflict mappings,
`GitConflictListQf` and the `User GitConflictResolved` quickfix refresh behave as they did before. The seed carries
both moves, and `up --live` lists exactly `blink.cmp git-conflict.nvim` in `replaced_from_seed`.

## Facts measured while planning (they drive the steps)

These were checked against the real files on 2026-11-04. They correct three assumptions in the index and the analysis.

1. **The live blink.cmp clone already has `78336bc`.** `git -C ~/.local/share/nvim/lazy/blink.cmp cat-file -t 78336bc8…`
   → `commit`, because lazy's update checker fetched it. The clone has **no** `v1.10.*` tags, and HEAD is still
   `485c034` (v0.14.2). `verify.sh`'s current rule (`seed_commit_unknown_to_live`: "a commit the live clone has
   never fetched") therefore would **not** replace blink.cmp in `up --live`. The run would keep driving v0.14.2,
   and the exit criterion "`replaced_from_seed` = blink.cmp git-conflict.nvim" could not pass. Step 1 changes the
   rule to "the live **checkout** does not contain the seed's commit", which is `git merge-base --is-ancestor`.
   Today every one of the seed lock's 93 entries equals the live HEAD. This was checked with a loop over the seed
   lock, and no plugin is "seed commit known but not an ancestor". So the new rule adds only the plugins this
   phase bumps.
2. **The seed would end up with a stale fuzzy library.** blink downloads its library from `cmp.setup()`, for the
   tag it is checked out on. In `seed`, nvim's startup loads blink from the dir as it is **before**
   `lazy.restore` moves it, which is v0.14.2. The library on disk is v0.14.2's, and its version file says
   `v0.14.2`; `$SEED/data/nvim/lazy/blink.cmp/target/release/version` reads `v0.14.2` today. After the restore the
   code is v1.10.2, but nothing downloads again. Every offline run would then log "Downloading pre-built binary",
   fail with no network, and fall back to the Lua matcher with a warning (v1.10.2
   `lua/blink/cmp/fuzzy/download/init.lua`: tag mismatch → `download.download(tag)` → curl fails → `prefer_rust_with_warning`
   → "Falling back to Lua implementation"). Step 2 adds a seed step that fetches the library with the checked-out code.
3. **`cmdline.sources = { default = …, providers = … }` meant "no sources" under v0.14.2, and v1.10.2 reads it the
   same way.** Both versions resolve `config.cmdline.sources` and pass it to `utils.deduplicate`, which walks it
   with `ipairs`. A table with only string keys gives `{}`. The before checkhealth confirms it: run
   `1104-121901-2809686` `evidence/03-lua-…` shows `Default sources` and `Disabled sources … cmdline` but **no**
   `Cmdline sources` section. So the owner's command line has always used Neovim's own completion (blink's
   `<Tab>`/`<S-Tab>`/`<Enter>` cmdline maps find no menu and `fallback` to the native key). Step 4 writes that
   behaviour honestly as `sources = {}`. Turning on `{ "cmdline", "path" }` would be a user-visible change
   (invariant 5): the menu would auto-show, and `<Enter>` would accept the first item instead of running the
   command. On nvim 0.12.6, `vim.tbl_deep_extend` replaces the default list `{ 'buffer', 'cmdline' }` with an
   empty user table: `can_merge` is false for a non-empty list (`runtime/lua/vim/_core/shared.lua:578`).
4. **What makes a blink.cmp dir offline-complete** (v1.10.2 `fuzzy/download/{init,files,git}.lua`):
   - `target/release/libblink_cmp_fuzzy.so`;
   - `target/release/libblink_cmp_fuzzy.so.sha256`, which `files.verify_checksum()` compares with
     `sha256sum` of the `.so`. If it is missing, the read rejects, the code tries to re-download, and offline it
     notifies at ERROR level;
   - `target/release/version`, holding the tag string `v1.10.2` with no newline;
   - the **tag object `v1.10.2` in the clone**. `git describe --tags --exact-match` must name it; with no tag the
     plugin errors with "No fuzzy matching library found! … not on a git tag" and falls back to Lua.

   Files must be writable by the owner, so a later bump can rewrite `version`. The seed's copies are read-only.
5. git-conflict fork: `63c5b42` is on the fork's `main` (`git branch -a --contains` → `main`, `origin/main`). Its
   diff from `a1badcd` is exactly `vim.highlight`→`vim.hl`, the positional `vim.validate`, and
   `vim.diagnostic.enable(false, {bufnr})` on the `GitConflictDetected`/`Resolved` paths. The last only matters when
   `disable_diagnostics = true`, which this config does not set. `lua/config/git-conflict.lua` needs **no change**.
6. blink v1.10.2 config schema, checked key by key against `git show v1.10.2:lua/blink/cmp/config/*.lua`. Every
   key in the current config is valid in v1.10.2: `keymap` (preset `default` + 7 keys; every command name is in
   `keymap.lua`'s list), `appearance.nerd_font_variant`, `completion.documentation.{auto_show,auto_show_delay_ms}`,
   `completion.menu.{border,draw.treesitter}`, `completion.ghost_text.enabled`, `sources.{default,providers}`
   (`name`, `module`, `fallbacks`, `score_offset`, `opts`), the path opts (`trailing_slash`, `label_trailing_slash`,
   `get_cwd`, `show_hidden_files_by_default`), and `cmdline.{completion.menu.auto_show,keymap,sources}`. The only
   key whose meaning needs stating is `cmdline.sources` (fact 3). v1 rejects unknown keys at setup
   (`config/utils.lua` "unexpected field found in configuration").
7. Upstream-only differences that come with the bump, which this config does not set. They are recorded here, not
   undone:
   - the `cmdline` preset's `<C-y>`/`<C-e>` gain `fallback`, and `<End>` = hide. With no cmdline sources they only
     let those keys reach Neovim as typed;
   - the `default` preset's `<C-y>` gains `fallback`;
   - the LSP source no longer filters `Text` items;
   - the default snippets `score_offset` goes from -3 to -1;
   - frecency moves to `stdpath("state")/blink/cmp/frecency.dat`. The owner's old LMDB
     `~/.local/share/nvim/blink/cmp/fuzzy.db/` exists and becomes unused; Deploy leaves it.

## Interface Contract

**Deletes:** blink.cmp spec key `build = "cargo build --release"` (`lua/plugin_specs.lua:52`); git-conflict spec
key `version = "*"` (`lua/plugin_specs.lua:385`); the commented-out `fuzzy = { implementation = "lua" }` block in
`lua/config/blink-cmp.lua:81-84` (obsolete: v1 fetches the prebuilt matcher).
**Renames:** `verify.sh` `seed_commit_unknown_to_live` -> `live_lacks_seed_commit` (same arguments, same single
caller in `cmd_up`'s live block; the predicate becomes "not an ancestor of the live checkout's HEAD").
**Creates:**
- `seed.lua` step `blink.cmp fuzzy library` (log lines `ok   blink.cmp fuzzy library` / `info blink.cmp fuzzy library <tag> (<kept|downloaded>)`).
- `.claude/skills/verify-nvim-config/features/lua/deprecations.lua` (probe: deprecation and blink fallback notices in `:messages` + nvim-notify history).
- `.workflows/plan/nvim-0-12-clean/evidence-phase-3.md`.
**Signature changes:** none.
**Spec changes:** blink.cmp `version = "v0.*"` -> `version = "1.*"`; git-conflict url `akinsho/git-conflict.nvim` ->
`stryukovsky/git-conflict.nvim`, pinned with `commit = "63c5b427038d85b20c32a25c7f3bd502241ce869"` (lazy name stays
`git-conflict.nvim`).
**Config changes:** `lua/config/blink-cmp.lua` `cmdline.sources` `{ default = {…}, providers = {…} }` -> `{}`. Both
mean "no blink sources on the command line" (fact 3).
**External state (written by this phase, invariant 3):** `$VERIFY_HOME/.seed/lazy-lock.json` `."blink.cmp".commit`
`485c034…` -> `78336bc89ee5365633bcf754d93df01678b5c08f`, then `verify.sh seed`. After it, the seed lock has
`git-conflict.nvim` = `{branch main, commit 63c5b42…, url https://github.com/stryukovsky/git-conflict.nvim.git}`, and
the seed's `lazy/blink.cmp/target/release/{libblink_cmp_fuzzy.so,.sha256,version=v1.10.2}`.
**Requires (from earlier phases):** phase 1's `verify.sh`/`SKILL.md` edits already in the tree (this phase edits the
same two files on top of them; `cmd_seed` builds its own PATH, so the seed itself does not depend on `run_path`), and
phase 1's `sync`/doctor `path` line (the after-runs' doctor must exit 0); phase 2's Lua fixes (the before runs B1-B4
are taken on phases 1+2, so E216/CursorHold/fidget are already gone from them) and phase 2's `### CursorHold diagnostic float` and `### fidget health` subsections in `features/lsp.md`
(this phase inserts after them, before `## Gotchas`).
**Shares files with phase 1 (reconciled: phase 1 runs first; every quote below was checked against `9cea538` with
phase 1's edits applied, and none of these lines is in a phase-1 hunk, so the quoted text is unchanged and only the
line numbers moved):**
- `SKILL.md`: two sentences only. The Launch "live" bullet's "a commit the live clone has never fetched" and the
  Gotchas nvim-treesitter bullet's "(its commit is unknown to the live clone)" become false with the Step 1 rule.
  Phase 1 owns the sync/doctor/run-PATH paragraphs, which are not touched.
- `verify.sh`: `seed_commit_unknown_to_live` (`:270-281` after phase 1; `:254-265` on `9cea538`) and the comment + call
  in `cmd_up`'s live block (`:345-348` and `:366` after phase 1; `:329-332`, `:350` on `9cea538`). This does not touch `cmd_sync`, `run_path` or `cmd_doctor` (phase 1).
  `PLUGIN_EXTRA_DATA` is **not** changed: blink's library lives inside `lazy/blink.cmp/target/`, which `--live`
  already copies with the plugin dir.
**Leaves alone (owned by others):** `features/README.md`, `features/live-environment.md` (its `:56` sentence repeats the
old rule: handed to phase 4), `features/health.md`, `.tmux.conf.local`, `features/startup.md`, phase 2's
`lsp.md` subsections, `lua/config/git-conflict.lua` (no change needed), every other plugin spec (phase 4 Step 4 later
edits the render-markdown spec's `opts` line, post-phase-3 `:135`, outside this phase's two hunks).

## Files

| File | Action | What changes |
|---|---|---|
| `.claude/skills/verify-nvim-config/scripts/verify.sh:270-281` (after phase 1; find `seed_commit_unknown_to_live`) | modify | rename to `live_lacks_seed_commit`; `cat-file -e` → `merge-base --is-ancestor <seed commit> HEAD` |
| `.claude/skills/verify-nvim-config/scripts/verify.sh:345-348,366` (after phase 1) | modify | comment lists the third "moved" reason; caller uses the new name |
| `.claude/skills/verify-nvim-config/SKILL.md:63-64,198` (after phase 1) | modify | the two sentences that state the old rule |
| `.claude/skills/verify-nvim-config/scripts/seed.lua:190-191` | modify | new step `blink.cmp fuzzy library` between the plugin loop and `seed lock` |
| `lua/plugin_specs.lua:49-63` | modify | blink.cmp `version = "1.*"`, no `build` |
| `lua/plugin_specs.lua:383-390` | modify | git-conflict from the fork, pinned by commit |
| `lua/config/blink-cmp.lua` | rewrite | v1.10.2 schema; same keymaps; `cmdline.sources = {}` with the reason; obsolete fuzzy comment block dropped |
| `lua/config/git-conflict.lua` | none | the fork keeps the API (`setup`, `GitConflictListQf`, `User GitConflictResolved`) |
| `$VERIFY_HOME/.seed/lazy-lock.json` (outside the repo) | modify (jq) | blink.cmp commit → `78336bc…`, then `verify.sh seed` |
| `.claude/skills/verify-nvim-config/features/lua/deprecations.lua` | create | probe used by the lsp.md and git.md journeys |
| `.claude/skills/verify-nvim-config/features/lsp.md` (before `## Gotchas`) | modify | new `### Completion (blink.cmp v1)` subsection |
| `.claude/skills/verify-nvim-config/features/git.md` | rewrite | git-conflict sub-feature + `### Merge conflicts (git-conflict.nvim)` journey + gotchas |
| `.workflows/plan/nvim-0-12-clean/evidence-phase-3.md` | create | before/after evidence paths |

## Implementation Steps

`V=.claude/skills/verify-nvim-config/scripts/verify.sh`, run from the worktree root
`/home/miftah/.worktrees/nvim/nvim-0-12-clean`. The Bash tool's shell is zsh. Quote `?`/`*`, never pipe `seed`
into `head`/`sed`, and never write `$v:l…` (zsh history modifiers; use `${v}`).

### Step 0: Record the BEFORE state first (failure first, both modes)

**File:** none. Do this **before any edit and before touching the seed.** The SKILL's `git stash` + `sync` recipe
cannot reproduce a plugin-version "before": once the seed lock is bumped, the base needs the seed restored. So the
before journeys run on the untouched worktree (phases 1+2 landed) against today's seed (blink v0.14.2,
akinsho git-conflict v2.1.0) and today's live dirs.
**Change:** run Proof journeys **B1-B4** (see Verification) once with `$V up --live` and once with `$V up`, then
`$V down RUN` each. Write the run ids and evidence paths into `evidence-phase-3.md` (Step 9) as you go.
**Impact:** none on the tree.

### Step 1: `--live` replaces a plugin whose seed commit the live checkout does not contain

**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:270-281` after phase 1 (the comment block and function
that start `# True when the seed lock pins plugin $1 to a commit the clone $2`; find by name).
**Change:** replace the whole comment + function with:
**Code:**
```bash
# True when the seed lock pins plugin $1 to a commit the checkout $2 (the run's copy of the live
# plugin) does not contain: a plugin bumped on purpose in the seed lock (go.nvim's commit bump,
# blink.cmp v0.14.2 -> v1.10.2). "Contain" = the seed's commit is HEAD or an ancestor of HEAD, not
# merely an object in the clone: lazy's update checker fetches upstream commits into the live clone
# without checking them out (the live blink.cmp clone had v1.10.2's commit while on v0.14.2). A live
# checkout that is merely newer than the seed contains the seed's commit and is kept. After
# `seed --update`, every plugin newer upstream than live qualifies.
live_lacks_seed_commit() {
  local p=$1 clone=$2 commit
  commit="$(jq -r --arg p "$p" '.[$p].commit // empty' "$SEED/lazy-lock.json" 2>/dev/null || true)"
  [ -n "$commit" ] && [ -d "$clone/.git" ] || return 1
  # In an empty network namespace: lazy's clones are partial (blob:none) and git 2.43 would try to
  # fetch a missing object from the promisor remote. merge-base exits 1 when the commit is not an
  # ancestor and 128 when the clone has never fetched it: both mean "lacks".
  ! unshare --map-current-user -n git -C "$clone" merge-base --is-ancestor "$commit" HEAD 2>/dev/null
}
```
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:345-348` after phase 1 (comment inside `cmd_up`'s `live)` branch).
**Change:** old:
```bash
      # - replaced: one whose spec MOVED. The seed follows the spec (seed.lua); live keeps the old
      #   one, because lazy never re-targets an installed plugin at startup. Moved = the seed lock's
      #   branch differs from the live lock's, or the two dirs' origin urls differ. The run's lock
      #   takes the seed's entry, and PLUGIN_EXTRA_DATA[name] comes from the seed too.
```
new:
```bash
      # - replaced: one whose spec MOVED. The seed follows the spec (seed.lua); live keeps the old
      #   one, because lazy never re-targets an installed plugin at startup. Moved = the seed lock's
      #   branch differs from the live lock's, or the two dirs' origin urls differ, or the live
      #   checkout does not contain the seed lock's commit (live_lacks_seed_commit). The run's lock
      #   takes the seed's entry, and PLUGIN_EXTRA_DATA[name] comes from the seed too.
```
**File:** `.claude/skills/verify-nvim-config/scripts/verify.sh:366` after phase 1 (the only caller).
**Change:** old:
```bash
          [ "$sb" != "${lb:-$sb}" ] || [ "$su" != "$lu" ] || seed_commit_unknown_to_live "$p" "$dir/xdg/data/nvim/lazy/$p" || continue
```
new:
```bash
          [ "$sb" != "${lb:-$sb}" ] || [ "$su" != "$lu" ] || live_lacks_seed_commit "$p" "$dir/xdg/data/nvim/lazy/$p" || continue
```
**File:** `.claude/skills/verify-nvim-config/SKILL.md:63-64` after phase 1 (Launch, the **live** bullet; phase 1's
run-PATH paragraph sits above it, after the `00-up-screen.txt` paragraph, and is not touched).
**Change:** old:
```markdown
  lock's, or the seed dir's `origin` url differs from the live dir's, or the seed lock pins a commit
  the live clone has never fetched: a one-plugin bump written into the seed lock), listed as
```
new:
```markdown
  lock's, or the seed dir's `origin` url differs from the live dir's, or the live checkout does not
  contain the seed lock's commit (neither HEAD nor an ancestor of it: a one-plugin bump written into
  the seed lock, even when lazy's update checker already fetched that commit into the live clone), listed as
```
**File:** `.claude/skills/verify-nvim-config/SKILL.md:198` after phase 1 (Gotchas, nvim-treesitter `main` bullet).
**Change:** old:
```markdown
  `url`), `seed`, and `--live` replaces that plugin (its commit is unknown to the live clone). See
```
new:
```markdown
  `url`), `seed`, and `--live` replaces that plugin (the live checkout does not contain its commit). See
```
**Check (can fail):** `bash -n .claude/skills/verify-nvim-config/scripts/verify.sh` exits 0;
`grep -c seed_commit_unknown_to_live .claude/skills/verify-nvim-config/scripts/verify.sh` prints `0`. Run
`$V up --live`, then `$V doctor RUN`: the `live info` line ends `replaced from seed (spec moved): ` (empty, because
nothing is bumped yet and every seed commit equals live HEAD), and `$V down RUN`.
**Impact:** `up --live` now also replaces a plugin whose live dir has fetched, but not checked out, the seed's
commit. Plugins equal to or newer than the seed are unchanged.

### Step 2: the seed fetches blink.cmp's fuzzy library with the checked-out code

**File:** `.claude/skills/verify-nvim-config/scripts/seed.lua:190-191`. Insert between the `end` that closes the
`for _, p in pairs(Config.plugins)` cloning-marker loop (`:190`) and the comment `-- The seed lock: what is checked
out now` (`:192`).
**Change:** insert:
**Code:**
```lua

-- blink.cmp's fuzzy matcher is a prebuilt Rust library that blink downloads at setup for the release
-- tag it is checked out on: target/release/{libblink_cmp_fuzzy.so, its .sha256, version}. The setup
-- that ran at this nvim's startup was the code checked out BEFORE the restore above, so a bumped
-- blink.cmp would keep the old release's library, and every run (no network) would try to download
-- and fall back to the Lua matcher with a warning. Fetch the library for the checked-out tag here,
-- with the checked-out code: the seed is the one place with network.
step("blink.cmp fuzzy library", function()
  local p = Config.plugins["blink.cmp"]
  if not (p and vim.uv.fs_stat(p.dir .. "/.git")) then
    return
  end
  local tag, on_tag = git(p.dir, "describe", "--tags", "--exact-match", "HEAD")
  assert(on_tag, "blink.cmp is not on a release tag, so there is no prebuilt library to fetch: " .. tag)
  local lib_dir = p.dir .. "/target/release"
  local have = vim.uv.fs_stat(lib_dir .. "/version") and vim.fn.readfile(lib_dir .. "/version")[1] or nil
  if have ~= tag then
    -- New files, never in-place rewrites: the old ones are hard-linked into seeded runs.
    vim.fn.delete(lib_dir, "rf")
  end
  -- Forget the modules (and the Rust library) loaded from the old checkout at startup, so the
  -- downloader below is the checked-out version's and does not find the old library in memory.
  for name in pairs(package.loaded) do
    if name == "blink_cmp_fuzzy" or name == "blink.cmp" or name:find("^blink%.cmp%.") then
      package.loaded[name] = nil
    end
  end
  local done, result = false, nil
  require("blink.cmp.fuzzy.download").ensure_downloaded(function(err, implementation)
    done, result = true, err or implementation
  end)
  vim.wait(300000, function()
    return done
  end, 200)
  assert(done, "timed out waiting for blink.cmp's download")
  assert(result == "rust", "blink.cmp fell back to " .. tostring(result))
  local got = vim.uv.fs_stat(lib_dir .. "/version") and vim.fn.readfile(lib_dir .. "/version")[1] or nil
  assert(got == tag, ("version file says %s, the checkout is %s"):format(tostring(got), tag))
  assert(vim.uv.fs_stat(lib_dir .. "/libblink_cmp_fuzzy.so"), "no libblink_cmp_fuzzy.so after the download")
  assert(vim.uv.fs_stat(lib_dir .. "/libblink_cmp_fuzzy.so.sha256"), "no libblink_cmp_fuzzy.so.sha256 after the download")
  log("info blink.cmp fuzzy library %s (%s)", tag, have == tag and "kept" or "downloaded")
end)
```
**Impact:** `seed` now also downloads `https://github.com/saghen/blink.cmp/releases/download/<tag>/x86_64-unknown-linux-gnu.so`
(+ `.sha256`) whenever the seed's blink tag changed. It is a no-op (checksum check only) when the library already
matches. The API it calls (`blink.cmp.fuzzy.download.ensure_downloaded(callback)`) is identical in v0.14.2 and
v1.10.2, so the step also serves a rollback to v0.14.2. A failure is a `FAIL` line, and `verify.sh seed` exits non-zero.

### Step 3: blink.cmp spec on v1 release tags, no cargo build

**File:** `lua/plugin_specs.lua:49-53`
**Change:** old:
```lua
  {
    "saghen/blink.cmp",
    version = "v0.*",
    build = "cargo build --release",
    lazy = false,
```
new:
```lua
  {
    "saghen/blink.cmp",
    -- v1 release tags: blink downloads the prebuilt fuzzy library for the tag it is on (no cargo;
    -- v0.14 called the deprecated client.request on nvim 0.12).
    version = "1.*",
    lazy = false,
```
**Impact:** lazy targets the newest `v1.*` tag on install or update. Lazy never re-targets at startup, so the owner's
live dir moves only in Deploy. No build step runs. The rest of the spec (`priority = 100`, `dependencies`, `config`)
is unchanged.

### Step 4: git-conflict.nvim from the deprecation-free fork commit

**File:** `lua/plugin_specs.lua:383-390`
**Change:** old:
```lua
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    event = "VeryLazy",
    config = function()
      require("config.git-conflict")
    end,
  },
```
new:
```lua
  {
    -- akinsho/git-conflict.nvim's last commit (a1badcd) still calls vim.highlight and vim.validate{},
    -- both deprecated in nvim 0.12. 63c5b42 is that commit plus only the deprecation fixes; later fork
    -- commits change behaviour (notify messages, nested repos). A commit, not `version`: the fork
    -- carries upstream's tags, so `version = "*"` would resolve to the deprecated v2.1.0.
    "stryukovsky/git-conflict.nvim",
    commit = "63c5b427038d85b20c32a25c7f3bd502241ce869",
    event = "VeryLazy",
    config = function()
      require("config.git-conflict")
    end,
  },
```
**Impact:** the lazy name stays `git-conflict.nvim`, the last url segment, so the lock key and `lua/config/git-conflict.lua`
are unchanged. The url change makes it a MOVED plugin for the seed (fresh fetch from the fork) and for `up --live`
(the origins differ).

### Step 5: `lua/config/blink-cmp.lua` on v1.10.2's schema

**File:** `lua/config/blink-cmp.lua` (whole file; tabs for indentation, as today)
**Change:** replace the file with the code below. Differences from today: the path comment is fixed, and a schema
note is added at the top. `cmdline.sources` becomes `{}` with its reason (fact 3). The commented-out `fuzzy` block
is removed (obsolete with the prebuilt v1 matcher). So is the comment "Only show the documentation popup when
manually triggered", which contradicted `auto_show = true`. Every other key and value is byte-for-byte what it was.
**Code:**
```lua
-- /home/miftah/.config/nvim/lua/config/blink-cmp.lua
-- blink.cmp v1 (spec: version = "1.*"). Every key is checked against v1.10.2's option schema
-- (lua/blink/cmp/config/*.lua); blink rejects unknown keys at setup.

local lspkind = require("lspkind")

require("blink.cmp").setup({
	-- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
	-- 'super-tab' for mappings similar to vscode (tab to accept)
	-- 'enter' for enter to accept
	-- 'none' for no mappings
	keymap = {
		preset = "default",
		["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
		["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
		["<Enter>"] = { "select_and_accept", "fallback" },
		["<C-U>"] = { "scroll_documentation_up", "fallback" },
		["<C-D>"] = { "scroll_documentation_down", "fallback" },
		["<C-E>"] = { "cancel", "fallback" },
		["<Esc>"] = { "cancel", "fallback" },
	},

	appearance = {
		-- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
		-- Adjusts spacing to ensure icons are aligned
		nerd_font_variant = "mono",
	},

	completion = {
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 500,
		},
		menu = {
			border = "rounded",
			draw = {
				treesitter = { "lsp" },
			},
		},
		ghost_text = {
			enabled = true,
		},
	},

	-- Default list of enabled providers defined so that you can extend it
	-- elsewhere in your config, without redefining it, due to `opts_extend`
	sources = {
		default = { "lsp", "path", "buffer", "snippets" },
		providers = {
			lsp = {
				name = "LSP",
				module = "blink.cmp.sources.lsp",
				fallbacks = { "buffer" },
			},
			path = {
				name = "Path",
				module = "blink.cmp.sources.path",
				score_offset = 3, -- Boost priority so it appears above 'buffer' suggestions
				-- When typing a path, we usually want it to activate immediately
				opts = {
					trailing_slash = false,
					label_trailing_slash = true,
					get_cwd = function(context)
						return vim.fn.expand(("#%d:p:h"):format(context.bufnr))
					end,
					show_hidden_files_by_default = true,
				},
			},
			buffer = {
				name = "Buffer",
				module = "blink.cmp.sources.buffer",
				fallbacks = {},
			},
			snippets = {
				name = "Snippets",
				module = "blink.cmp.sources.snippets",
				fallbacks = {},
			},
		},
	},

	-- Command line
	cmdline = {
		completion = {
			menu = {
				auto_show = true,
			},
		},
		keymap = {
			["<Enter>"] = { "select_and_accept", "fallback" },
			["<Tab>"] = { "select_next", "fallback" },
			["<S-Tab>"] = { "select_prev", "fallback" },
		},
		-- No blink sources on the command line: it keeps Neovim's own completion (wildmenu), which
		-- <Tab>/<S-Tab>/<Enter> reach through "fallback". This is what the v0 config did too: it passed
		-- { default = {...}, providers = {...} } here, a shape blink reads as a list (ipairs), i.e. as
		-- no sources (`:checkhealth blink.cmp` listed no "Cmdline sources"). Adding "cmdline"/"path"
		-- would turn on blink's command-line menu, and <Enter> would accept its first item instead of
		-- running the command.
		sources = {},
	},
})
```
**Impact:** same keymaps, same sources, same command-line behaviour. `lspkind` stays required, as before: it is
unused here, but removing it is out of scope.

### Step 6: bump blink.cmp in the seed lock and re-seed (online, ~2-3 min)

**File:** `$HOME/.local/state/nvim-config-verify/.seed/lazy-lock.json` (outside the repo; invariant 3 allows phase 3
to write the seed). Steps 1-5 must be in the working tree first, because `seed` snapshots it.
**Change:** run these from the worktree root:
**Code:**
```sh
V=.claude/skills/verify-nvim-config/scripts/verify.sh
S=$HOME/.local/state/nvim-config-verify/.seed
$V ls                                   # down every run of this phase first: $V down RUN
cp "$S/lazy-lock.json" "$HOME/.local/state/nvim-config-verify/seed-lock.before-nvim-0-12-clean-phase-3.json"
jq '."blink.cmp".commit = "78336bc89ee5365633bcf754d93df01678b5c08f"' "$S/lazy-lock.json" >"$S/lazy-lock.json.tmp" \
  && mv -f "$S/lazy-lock.json.tmp" "$S/lazy-lock.json"
jq -c '."blink.cmp"' "$S/lazy-lock.json"
$V seed
```
The `jq -c` line must print
`{"branch":"main","commit":"78336bc89ee5365633bcf754d93df01678b5c08f","url":"https://github.com/saghen/blink.cmp.git"}`.
Do not edit `git-conflict.nvim`'s entry: its url change in the spec is what makes seed.lua treat it as MOVED.
**Check (can fail):** `seed` exits 0 and its printed `seed.log` contains all of:
- `MOVED plugin git-conflict.nvim: url https://github.com/akinsho/git-conflict.nvim.git -> https://github.com/stryukovsky/git-conflict.nvim.git; not pinned to the lock's main@4bbfdd9, follows the spec: main@63c5b42`
- `ok   blink.cmp fuzzy library` and `info blink.cmp fuzzy library v1.10.2 (downloaded)`
- `done`, and no line starting `FAIL`.

Then:
```sh
jq -c '."blink.cmp", ."git-conflict.nvim"' "$S/lazy-lock.json"
cat "$S/data/nvim/lazy/blink.cmp/target/release/version"; echo
git -C "$S/data/nvim/lazy/blink.cmp" describe --tags --exact-match
git -C "$S/data/nvim/lazy/git-conflict.nvim" rev-parse HEAD
```
Expected:
- the lock lines are `{"branch":"main","commit":"78336bc…","url":"https://github.com/saghen/blink.cmp.git"}` and
  `{"branch":"main","commit":"63c5b427038d85b20c32a25c7f3bd502241ce869","url":"https://github.com/stryukovsky/git-conflict.nvim.git"}`;
- `version` is `v1.10.2`, and `describe` prints `v1.10.2`;
- the HEAD is `63c5b427038d85b20c32a25c7f3bd502241ce869`.

If the MOVED line names a different `from` url (lazy's restore may already have `set-url` the dir), the check is the
lock line and the HEAD, not the wording.
**Impact:** every seeded run from now on gets blink v1.10.2 with its library, and the fork. `up --live` replaces both
plugins from the seed until Deploy.

### Step 7: probe for deprecation and fuzzy-fallback notices

**File:** `.claude/skills/verify-nvim-config/features/lua/deprecations.lua` (new)
**Code:**
```lua
-- Deprecation notices and blink.cmp fuzzy-library notices seen so far in this nvim: `:messages`
-- plus nvim-notify's history (vim.notify is nvim-notify in this config). Returns "0" when there
-- are none, else the count and each matching line.
-- Use: $V lua RUN @.claude/skills/verify-nvim-config/features/lua/deprecations.lua
local needles = { "deprecated", "Lua implementation", "fuzzy matching library", "pre-built binary" }
local hits = {}
local function scan(text)
  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    for _, needle in ipairs(needles) do
      if line:find(needle, 1, true) then
        table.insert(hits, line)
        break
      end
    end
  end
end
scan(vim.api.nvim_exec2("messages", { output = true }).output)
local ok, notify = pcall(require, "notify")
if ok and type(notify.history) == "function" then
  for _, record in ipairs(notify.history()) do
    scan(table.concat(record.message or {}, "\n"))
  end
end
if #hits == 0 then
  return "0"
end
return #hits .. "\n" .. table.concat(hits, "\n")
```
**Impact:** a reusable lever for this phase's journeys, and for phase 4's sweep.

### Step 8: feature map: `features/lsp.md` completion and `features/git.md` conflicts

**File:** `.claude/skills/verify-nvim-config/features/lsp.md`. Insert immediately **before** the `## Gotchas`
heading, after phase 2's `### fidget health` subsection (whose last line is ``End state seen (...): no WARNING line
(base:`` ... ``and avoid is `{ "NvimTree" }`, as on the base.``). Anchor on the heading plus its first bullet, which reads
``- Fixed 2026-11-04 (R2): `after/lsp/pyright.lua` used to set``. Do not edit phase 2's subsections. The block below
is followed by one blank line, then the unchanged `## Gotchas`.
**Change:** insert the block below. The end-state sentences state what the after runs must show. Replace `<run>`
with the observed run ids. If an observed value differs, the journey failed: do not rewrite it into a pass.
**Code:**
````markdown
### Completion (blink.cmp v1)

blink.cmp `1.*` (v1.10.2, `78336bc`) with its Rust fuzzy matcher: the prebuilt
`target/release/libblink_cmp_fuzzy.so` for the checked-out tag, fetched by `seed` (runs have no network).
Keymaps (`config/blink-cmp.lua`): `<Tab>`/`<S-Tab>` select next/previous (else snippet jump, else the key),
`<Enter>` selects and accepts, `<C-U>`/`<C-D>` scroll the documentation, and `<C-E>`/`<Esc>` cancel. The
command line keeps Neovim's own completion: blink has no command-line sources, so `<Tab>` there falls back to
the wildmenu.

```sh
DEPS=@.claude/skills/verify-nvim-config/features/lua/deprecations.lua
$V keys RUN : e Space sample.lua Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="lua_ls"})), ",")' lua_ls 60
$V keys RUN G o
$V keys RUN vim.
$V wait RUN 'tostring(require("blink.cmp").is_menu_visible())' true 30
$V screen RUN completion-lua
$V keys RUN Escape
$V lua RUN 'tostring(require("blink.cmp").is_menu_visible()) .. " " .. vim.fn.mode()'
$V keys RUN ap
$V wait RUN 'tostring(require("blink.cmp").is_menu_visible())' true 30
$V keys RUN Tab
$V keys RUN Enter
$V lua RUN 'tostring(vim.api.nvim_get_current_line():match("^vim%.[%w_]+") ~= nil)'
$V keys RUN Escape Escape
$V keys RUN : e Space main.go Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="gopls"})), ",")' gopls 90
$V keys RUN : 1 1 Enter
$V keys RUN o
$V keys RUN fmt.
$V wait RUN 'tostring(require("blink.cmp").is_menu_visible())' true 60
$V keys RUN Escape Escape
$V keys RUN : e Space app.py Enter
$V wait RUN 'table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr=0, name="pyright"})), ",")' pyright 90
$V keys RUN G o
$V keys RUN str.
$V wait RUN 'tostring(require("blink.cmp").is_menu_visible())' true 60
$V keys RUN Escape Escape
$V lua RUN "$DEPS"
$V lua RUN 'require("blink.cmp.fuzzy").implementation_type'
$V lua RUN '(function() local d = vim.fn.stdpath("data") .. "/lazy/blink.cmp" return vim.fn.readfile(d .. "/target/release/version")[1] .. " " .. vim.trim(vim.fn.system({ "git", "-C", d, "describe", "--tags", "--exact-match" })) end)()'
$V keys RUN : checkhealth Space blink.cmp Enter
$V lua RUN 'table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")'
$V keys RUN : q Enter
$V keys RUN : checkhealth Space vim.deprecated Enter
$V lua RUN 'table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")'
$V keys RUN : q Enter
$V keys RUN : e Space sam Tab
$V screen RUN cmdline-tab
$V lua RUN 'tostring(require("blink.cmp").is_menu_visible())'
$V keys RUN Escape
```

End states seen (seeded `<run>` and `--live` `<run>`, nvim 0.12.6, blink v1.10.2):
- typing `vim.` opens the menu. The first `Escape` closes it and stays in insert mode (`false i`). After `Tab`
  `Enter` the line matches `^vim%.[%w_]+` (`true`).
- the menu opens in Go (`fmt.`) and Python (`str.`).
- the probe prints `0`: no `client.request is deprecated`, no fuzzy notice.
- `implementation_type` is `rust`; the version line is `v1.10.2 v1.10.2`.
- `:checkhealth blink.cmp` has `OK blink_cmp_fuzzy lib is downloaded/built`, with `Default sources` path, lsp,
  buffer, snippets and no `Cmdline sources` section.
- `:checkhealth vim.deprecated` is `OK No deprecated functions detected`.
- `:e sam<Tab>` completes to `:e sample.lua` on the command line, and the blink menu is `false`.

Before (blink v0.14.2, seeded `<run>` and `--live` `<run>`): after typing `vim.` the screen's last line was
`client.request is deprecated. Run ":checkhealth vim.deprecated" for more information`, and
`:checkhealth vim.deprecated` listed `client.request` from `blink/cmp/sources/lsp/`. The keymap, `:e sam<Tab>` and
checkhealth-sources end states were identical.

Completion gotchas:
- The fuzzy library must match the checked-out tag: `target/release/{libblink_cmp_fuzzy.so,
  libblink_cmp_fuzzy.so.sha256, version}`, plus the tag in the clone (`git describe --tags --exact-match`). If they
  do not match, blink v1 tries to download in every run, fails (no network), and notifies "Falling back to Lua
  implementation". `seed` fetches the library (`seed.lua` step `blink.cmp fuzzy library`). A seed lock bump of
  blink.cmp needs nothing else.
- `:checkhealth blink.cmp`'s `WARNING Some providers may show up as "disabled"` is always printed (upstream's
  `health.lua`).
- Never drive completion with `--paste` (a paste opens no menu). Type with `keys`, and leave insert mode with
  `Escape Escape`.
````
**File:** `.claude/skills/verify-nvim-config/features/git.md` (whole file)
**Change:** replace the whole file with the content below. It keeps the fugitive recipe verbatim and adds the
git-conflict sub-feature, its journey and gotchas.
**Code:**
````markdown
# Git mappings

## Sub-features

- fugitive (loaded on `User InGitRepo`, fired at VimEnter/DirChanged inside a repo): `,gt` status,
  `,ga` `Git add .`, `,gc` commit (opens COMMIT_EDITMSG), `,gp` `Git push`, `,gf` Flog.
- gitsigns (`,gd` diffthis), gitlinker, git tag helpers (`,gts`, `,gtl`, `,gtc`, `,gtS`).
- lualine runs `git fetch origin` in the background for ahead/behind counts.
- git-conflict.nvim (`stryukovsky/git-conflict.nvim@63c5b42`: upstream `a1badcd` plus only the nvim 0.12
  deprecation fixes; loaded at VeryLazy): in a buffer with conflict markers, `co` ours, `ct` theirs, `cb` both,
  `c0` none, `]x`/`[x` next/previous conflict; `:GitConflictListQf` puts every conflict of the repo in the
  quickfix list. `config/git-conflict.lua` refreshes that list on `User GitConflictResolved` (a buffer's last
  conflict resolved).

## How to get to it (user POV)

In a repo: edit, `,ga`, `,gc`, write the message, `:wq`, `,gp`.

After a merge with conflicts: open the file, `co`/`ct` on each conflict (`]x` to the next), `:w`.

## Driving it with verify.sh

WORK's `origin` is a bare repo inside the run (tracked by `main`), so a push is real and lands
nowhere else:

```sh
$V keys RUN : e Space notes.md Enter
$V keys RUN G o; $V keys RUN --paste 'written in the run'; $V keys RUN Escape Escape; $V keys RUN , w
$V keys RUN , g a
$V keys RUN , g c
$V wait RUN 'vim.bo.filetype' gitcommit 15
$V keys RUN i; $V keys RUN --paste 'verify: commit through fugitive'; $V keys RUN Escape Escape
$V keys RUN : w q Enter
$V keys RUN , g p
git -C ~/.local/state/nvim-config-verify/RUN/remote.git log --oneline -1 main
```

End state seen: `remote main: <sha> verify: commit through fugitive` (same sha as WORK's HEAD).

### Merge conflicts (git-conflict.nvim)

A real merge conflict made with the CLI in WORK: `conflict_a.txt` with two conflicts (top and bottom line),
`conflict_b.txt` with one. The quickfix probe lists the file names in the quickfix list.

```sh
QF='table.concat(vim.fn.uniq(vim.fn.sort(vim.tbl_map(function(i) return vim.fn.fnamemodify(vim.fn.bufname(i.bufnr), ":t") end, vim.fn.getqflist()))), ",")'
$V cli RUN bash -c 'set -e; printf "top\nkeep 1\nkeep 2\nkeep 3\nkeep 4\nkeep 5\nkeep 6\nkeep 7\nkeep 8\nbottom\n" >conflict_a.txt; printf "only\n" >conflict_b.txt; git add conflict_a.txt conflict_b.txt; git commit -qm "conflict: base"; git checkout -qb theirs; sed -i "s/^top\$/top theirs/; s/^bottom\$/bottom theirs/" conflict_a.txt; printf "only theirs\n" >conflict_b.txt; git commit -qam "conflict: theirs"; git checkout -q main; sed -i "s/^top\$/top ours/; s/^bottom\$/bottom ours/" conflict_a.txt; printf "only ours\n" >conflict_b.txt; git commit -qam "conflict: ours"; git merge -q theirs >/dev/null 2>&1 || true; git diff --name-only --diff-filter=U'
$V keys RUN : e Space conflict_a.txt Enter
$V wait RUN 'require("git-conflict").conflict_count(0)' 2 30
$V lua RUN 'vim.fn.maparg("co", "n") .. " " .. vim.fn.maparg("ct", "n") .. " " .. vim.fn.maparg("]x", "n")'
$V keys RUN : GitConflictListQf Enter
$V wait RUN "$QF" conflict_a.txt,conflict_b.txt 15
$V keys RUN : cclose Enter
$V keys RUN g g c o
$V wait RUN 'require("git-conflict").conflict_count(0)' 1 15
$V keys RUN g g ] x
$V lua RUN 'tostring(vim.fn.line(".") >= 10)'
$V keys RUN c t
$V wait RUN "$QF" conflict_b.txt 15
$V keys RUN : cclose Enter
$V keys RUN : w Enter
$V cli RUN cat conflict_a.txt
$V lua RUN @.claude/skills/verify-nvim-config/features/lua/deprecations.lua
```

End states seen (seeded `<run>` and `--live` `<run>`, nvim 0.12.6, fork `63c5b42`):
- the CLI prints `conflict_a.txt` and `conflict_b.txt`; `conflict_count` is `2`;
- the mappings are `<Plug>(git-conflict-ours) <Plug>(git-conflict-theirs) <Plug>(git-conflict-next-conflict)`;
- `:GitConflictListQf` lists `conflict_a.txt,conflict_b.txt`;
- `co` leaves `1` conflict, `]x` lands on line `>= 10` (`true`), and `ct` resolves the last one;
- `GitConflictResolved` refreshes the quickfix list to `conflict_b.txt`;
- the file on disk is `top ours`, `keep 1`…`keep 8`, `bottom theirs`, with no markers;
- the probe prints `0`.

Before (akinsho `v2.1.0`, seeded `<run>` and `--live` `<run>`): the same end states, and
`:checkhealth vim.deprecated` listed `vim.highlight is deprecated` (`git-conflict.lua:109`) and
`vim.validate is deprecated` (`git-conflict/colors.lua:12`).

## Gotchas

- Never point WORK at a real remote. `GIT_SSH_COMMAND=/bin/false`, no credentials, and the
  namespace has no network, so a real push would fail anyway; the bare repo is what makes the
  success path provable.
- If the commit buffer stays in insert mode (a completion menu ate one Escape), `:wq` becomes
  message text. Always `Escape Escape`, then `wait` on the filetype going away if in doubt.
- Before `up` set the upstream (`push -u`), `,gp` ended in "The current branch main has no
  upstream branch." Fixtures now track `origin/main`.
- git-conflict finds conflicted files when a buffer is read (`BufRead` in a cwd with `.git`) and through a
  watcher on `.git`. Make the conflict **before** opening the file, then `wait` on `conflict_count`. The
  `co`/`ct`/`]x` mappings exist only in a buffer where conflicts were detected.
- `:GitConflictListQf` and the Resolved refresh run `copen`, which moves the cursor into the quickfix window.
  Use `:cclose` before pressing a mapping or `:w`.
- The conflict journey leaves WORK mid-merge (`conflict_b.txt` unresolved). Run it last, or in its own run.
- Do not use `version = "*"` on the fork: forks carry upstream's tags, so it would resolve to the deprecated
  `v2.1.0`. The spec pins `commit`.
````
**Impact:** feature map matches the new behaviour. `features/README.md`'s Git and LSP rows are phase 4's (Handoffs).

### Step 9: `evidence-phase-3.md`

**File:** `.workflows/plan/nvim-0-12-clean/evidence-phase-3.md` (new)
**Change:** create it with this skeleton, and fill every `<…>` with the run id or the evidence path under
`~/.local/state/nvim-config-verify/<run>/evidence/`. A journey that could not be driven gets `inconclusive: <reason>`,
never a blank or a pass.
**Code:**
```markdown
# Evidence: phase 3 (blink.cmp v1, git-conflict fork)

Worktree `feature/nvim-0-12-clean` @ `<sha>`; nvim 0.12.6; seed lock before: `~/.local/state/nvim-config-verify/seed-lock.before-nvim-0-12-clean-phase-3.json`.

| Journey | Mode | Before (run / evidence) | After (run / evidence) | Result |
|---|---|---|---|---|
| B1/A1 completion lua: deprecation on screen + probe | live | `<run>` `<NN-screen-completion-lua.txt>`, `<NN-lua-…deprecations…>` | `<run>` `<…>` | `<pass/fail>` |
| B1/A1 completion lua: deprecation on screen + probe | seeded | `<…>` | `<…>` | |
| A1 completion go/python, keymaps (Esc stays in insert, Tab+Enter accept) | live / seeded | `<…>` | `<…>` | |
| B2/A2 `:checkhealth vim.deprecated` | live | `<…>` (vim.highlight, vim.validate, client.request) | `<…>` (No deprecated functions detected) | |
| B2/A2 `:checkhealth vim.deprecated` | seeded | `<…>` | `<…>` | |
| A3 `:checkhealth blink.cmp` + `implementation_type` + version | live / seeded | `<…>` | `<…>` | |
| B3/A4 `:e sam<Tab>` command line | live / seeded | `<…>` | `<…>` | |
| B4/A5 git-conflict journey (co, ]x, ct, ListQf, Resolved refresh) | live / seeded | `<…>` | `<…>` | |
| A6 `replaced_from_seed` | live | `<run>` meta: `` (empty) | `<run>` meta + `00-up-replaced.txt` | |
| Seed | — | — | `seed.log` lines (MOVED git-conflict, blink.cmp fuzzy library v1.10.2) | |
| Neighbor: git.md fugitive commit + push | live / seeded | — | `<…>` | |
| Neighbor: startup `:messages` + doctor | live / seeded | `<…>` | `<…>` | |
```
**Impact:** the phase's proof index; phase 4 links it from `evidence.md`.

## Principles applied

- Fix root causes: the analysis assumed that `--live` would replace blink.cmp because "its commit is unknown to the
  live clone". Tested directly (`cat-file -t` → `commit`), that premise was false. So the plan changes the
  replacement rule (Step 1) instead of hoping the run drives v1.
- Fix root causes: the `cmdline.sources` "v0 shape" suspicion was traced to `utils.deduplicate`'s `ipairs`, in v0.14.2
  and in v1.10.2, and confirmed by the before checkhealth having no `Cmdline sources`. So the migration keeps the
  measured behaviour (`sources = {}`) instead of the shape's apparent intent (`{ "cmdline", "path" }`), which would
  change `<Enter>` on the command line.
- Encode lessons in structure: the stale-library trap (startup loads the old checkout's blink, which downloads the
  old tag's library) is fixed by a seed step that re-runs the download with the checked-out code (Step 2). The other
  option was a "run `seed` twice" sentence; any future blink bump would hit the trap again.
- Laziness protocol: `lua/config/git-conflict.lua` is untouched (the fork keeps the API). `PLUGIN_EXTRA_DATA` is
  untouched (the library lives inside the plugin dir). The blink config keeps every key and value except the one
  whose meaning had to be stated.
- Subtract before you add: the commented-out `fuzzy = { implementation = "lua" }` workaround and the `build` key go,
  because the v1 prebuilt matcher makes them obsolete.
- Build the lever: `features/lua/deprecations.lua` replaces hand-reading the screen for deprecation and fallback
  notices, and phase 4's sweep reuses it.
- Prove it works: the Proof drives completion, health and the conflict mappings in real nvim, in both modes, with
  the before recorded on the untouched tree first (Step 0).

## Verification

**Build:** from the worktree root (compiles only; never `luafile` seed.lua, which would run the seed):
```sh
bash -n .claude/skills/verify-nvim-config/scripts/verify.sh && \
/opt/nvim-linux-x86_64/bin/nvim --headless -u NONE -c 'lua for _, f in ipairs({ "lua/config/blink-cmp.lua", "lua/plugin_specs.lua", ".claude/skills/verify-nvim-config/scripts/seed.lua", ".claude/skills/verify-nvim-config/features/lua/deprecations.lua" }) do local fn, err = loadfile(f) if not fn then io.stderr:write(err .. "\n") vim.cmd("cq 1") end end' -c 'qa!' && echo build-ok
```
Pass: prints `build-ok` and nothing else.
**Tests:** no unit-test suite in this repo. The proof is the harness below.
**Proof:**
- Harness: `.claude/skills/verify-nvim-config` (`scripts/verify.sh`), SKILL.md read in full; the seed is re-made in
  Step 6.
- Feature-map entries: `features/lsp.md` (`### Completion (blink.cmp v1)`), `features/git.md` (`### Merge conflicts
  (git-conflict.nvim)`), probe `features/lua/deprecations.lua`.
- Journeys. Each is the exact command block in the named feature file, run in a fresh run per mode, `$V doctor RUN`
  first, `$V down RUN` after.
  - **B1 (before; must FAIL first).** Step 0, on the untouched tree and seed, `up --live` and `up`: the first part of
    lsp.md's completion block, up to and including `$V screen RUN completion-lua`, then `$V keys RUN Escape Escape`
    and `$V lua RUN @.claude/skills/verify-nvim-config/features/lua/deprecations.lua`. Failing end state: the screen
    file or the probe shows a line containing `client.request is deprecated` (probe count `>= 1`). Also record the
    `Escape` → `false i` and `Tab Enter` → `true` lines, which are the keymap baseline A1 must equal.
  - **B2 (before).** In the same runs, after B1: `$V keys RUN : checkhealth Space vim.deprecated Enter`, then the
    buffer probe. Failing end state: it contains `vim.highlight is deprecated` and `vim.validate is deprecated` (paths
    under `lazy/git-conflict.nvim/`) and `client.request is deprecated`.
  - **B3 (before).** `$V keys RUN : e Space sam Tab`, `$V screen RUN cmdline-tab`, `$V keys RUN Escape`. Baseline:
    the last screen line shows `:e sample.lua`.
  - **B4 (before).** The git.md conflict block, in a fresh run per mode (it leaves WORK mid-merge). Baseline end
    states as in git.md, on akinsho v2.1.0.
  - **A0 (rule).** After Step 1, before Step 6: `$V up --live`; `grep '^replaced_from_seed=' ~/.local/state/nvim-config-verify/RUN/meta`
    → `replaced_from_seed=` (empty); `$V down RUN`.
  - **A1-A4 (after, both modes).** After Step 6: lsp.md's whole completion block. Pass:
    - the probe prints `0`, after completion in lua, go and python;
    - `Escape` → `false i`, and `Tab Enter` → `true`, the same as B1;
    - `implementation_type` = `rust`, and the version line = `v1.10.2 v1.10.2`;
    - `:checkhealth blink.cmp` contains `OK blink_cmp_fuzzy lib is downloaded/built`, with no
      `blink_cmp_fuzzy lib is not` and no `Cmdline sources`;
    - `:checkhealth vim.deprecated` contains `No deprecated functions detected`;
    - the `cmdline-tab` screen's last line shows `:e sample.lua`, and the menu probe is `false`.
  - **A5 (after, both modes).** The git.md conflict block in a fresh run. Pass:
    - the mappings line is `<Plug>(git-conflict-ours) <Plug>(git-conflict-theirs) <Plug>(git-conflict-next-conflict)`;
    - the QF waits succeed: `conflict_a.txt,conflict_b.txt`, then `conflict_b.txt`;
    - `cat conflict_a.txt` prints exactly the 10 lines `top ours`, `keep 1`…`keep 8`, `bottom theirs`;
    - the probe is `0`.
  - **A6 (live replacement).** `$V up --live`, then `grep '^replaced_from_seed=' ~/.local/state/nvim-config-verify/RUN/meta`
    → `replaced_from_seed=blink.cmp git-conflict.nvim`. `cat ~/.local/state/nvim-config-verify/RUN/evidence/00-up-replaced.txt`
    shows two lines:
    - `blink.cmp: live main@485c034 https://github.com/saghen/blink.cmp -> seed main@78336bc https://github.com/saghen/blink.cmp`
    - `git-conflict.nvim: live main@4bbfdd9 https://github.com/akinsho/git-conflict.nvim -> seed main@63c5b42 https://github.com/stryukovsky/git-conflict.nvim`

    A1-A5 on `--live` run in such a run.
  - **Rule sanity (scripted, no run).** This proves the predicate's three cases on a throwaway repo:
    ```sh
    T=$(mktemp -d /tmp/claude-1000/-home-miftah--config-nvim/bcfe6938-f07b-47fb-8dea-f4d06c1251b6/scratchpad/rule.XXXX)
    git -C "$T" init -q && git -C "$T" -c user.name=t -c user.email=t@t commit -q --allow-empty -m a
    A=$(git -C "$T" rev-parse HEAD); git -C "$T" -c user.name=t -c user.email=t@t commit -q --allow-empty -m b; B=$(git -C "$T" rev-parse HEAD)
    unshare --map-current-user -n git -C "$T" merge-base --is-ancestor "$A" HEAD; echo "live newer: $?"     # 0 -> kept
    git -C "$T" checkout -q "$A"
    unshare --map-current-user -n git -C "$T" merge-base --is-ancestor "$B" HEAD; echo "fetched, not checked out: $?"   # 1 -> replaced
    unshare --map-current-user -n git -C "$T" merge-base --is-ancestor 0123456789012345678901234567890123456789 HEAD 2>/dev/null; echo "unknown: $?"   # 128 -> replaced
    ```
- Neighbor check: `features/git.md`'s fugitive commit + push block, in an after run of each mode. It is the journey
  most exposed to blink v1 (insert mode in a `gitcommit` buffer with the buffer source; one Escape eaten by the
  menu). Pass: `remote main: <sha> verify: commit through fugitive`. Also: `evidence/00-up-messages.txt` has no
  error, and `$V doctor RUN` exits 0, in every after run.
- Cost: no paid drives. `seed` (Step 6) is the only online step, about 2-3 min (GitHub: the fork clone and blink's
  release asset).

**Exit criteria:**
- In both modes, `client.request is deprecated` shows in B1 and the probe prints `0` in A1 (lua, go, python).
- `:checkhealth vim.deprecated` goes from three warnings (B2) to `No deprecated functions detected` (A2).
- `:checkhealth blink.cmp` reports the library and `implementation_type` is `rust`.
- The completion keymaps, `:e sam<Tab>` and the git-conflict journey give the same end states before and after.
- `up --live` has `replaced_from_seed=blink.cmp git-conflict.nvim`.
- `evidence-phase-3.md` has a path in every cell.

## Handoffs

- **Phase 4: Deploy runbook D3 (the facts it needs; the index's D3 summary is incomplete).**
  - blink.cmp, live dir `~/.local/share/nvim/lazy/blink.cmp`:
    1. backed up in D1;
    2. `git -C … fetch origin --tags`. The live clone has commit `78336bc` but **no `v1.10.2` tag**, and blink needs
       the tag (`git describe --tags --exact-match`);
    3. `git -C … checkout -q 78336bc89ee5365633bcf754d93df01678b5c08f`;
    4. assert `git -C … describe --tags --exact-match` = `v1.10.2`;
    5. replace the cargo build tree: `rm -rf …/target`, then
       `install -D -m 0644 "$SEED/data/nvim/lazy/blink.cmp/target/release/<f>" …/target/release/<f>` for each of
       **`libblink_cmp_fuzzy.so`, `libblink_cmp_fuzzy.so.sha256`, `version`**. All three are needed:
       - without `.sha256`, the checksum read fails, blink re-downloads, and offline it notifies at ERROR level;
       - without `version`, a matching tag is never recorded;
       - `-m 0644`, because the seed's files are read-only and a later bump must rewrite `version`.

       Live's current `target/release` is cargo's (`build/`, `deps/`, `.fingerprint/`, `incremental/`, `examples/`,
       `.cargo-lock`, `libblink_cmp_fuzzy.d`, a cargo-built `.so`, and a `version` holding the sha `485c034…`). It is
       dead with v1 and `target/` is gitignored upstream, so removing it keeps `git status` clean.
    6. assert `cat …/target/release/version` = `v1.10.2`, and that
       `cut -d' ' -f1 libblink_cmp_fuzzy.so.sha256` equals `sha256sum libblink_cmp_fuzzy.so | cut -d' ' -f1`.
  - git-conflict.nvim, live dir `~/.local/share/nvim/lazy/git-conflict.nvim`: `remote set-url origin
    https://github.com/stryukovsky/git-conflict.nvim.git`, `fetch origin`, `checkout -q
    63c5b427038d85b20c32a25c7f3bd502241ce869`, then assert HEAD and the raw `remote.origin.url`.
  - Merge both seed lock entries (`."blink.cmp"`, `."git-conflict.nvim"`) into `~/.config/nvim/lazy-lock.json`, as
    D4 did.
  - After Deploy, D5's `up --live` has an empty `replaced_from_seed` under the new rule, because both live HEADs equal
    the seed's.
  - Leave `~/.local/share/nvim/blink/cmp/fuzzy.db/` (v0's LMDB frecency, unused by v1, which writes
    `~/.local/state/nvim/blink/cmp/frecency.dat`). It is owner data; mention it in the deploy report.
  - Online `nvim` would also self-download the library on the owner's first start. The copy makes it work
    offline and with no "Downloading" notice.
- **Phase 4 (taken: phase 4 Step 9 rewrites the file with the new rule): `features/live-environment.md:56`** repeats the old rule ("a commit the live clone has never fetched").
  Reword it to "a commit the live checkout does not contain (neither HEAD nor an ancestor)". It is not edited here
  because phase 4 owns the file.
- **Phase 4: `features/README.md`.** Update the Git mappings row (surfaces add `lua @deprecations.lua`; "Known on the
  base": git-conflict deprecations fixed, fork `63c5b42`) and the LSP row (completion journey; `client.request`
  deprecation fixed via blink v1). The Live environment row ("live lags … plugins") now also includes blink.cmp and
  git-conflict.nvim until Deploy.
- **Phase 4: `features/health.md` allow-list.** blink.cmp's `WARNING Some providers may show up as "disabled" but
  are enabled dynamically` is printed unconditionally by v1.10.2 `health.lua` (`report_sources`); record it as
  upstream-informational.
- **Phase 4 sweep.** Reuse `features/lua/deprecations.lua` after every journey. If `:checkhealth vim.deprecated`
  shows a deprecation from another plugin once more paths are exercised (the analysis named version-guarded
  dot-callers in nvim-ufo, fzf-lua, snacks, nvim-colorizer, lazydev), that is the sweep's, not this phase's.
- **Not done, out of scope:** `lua/config/blink-cmp.lua`'s `local lspkind = require("lspkind")` is unused (it was
  before too). No phase owns removing it.

## Rollback

Before land, undo this phase alone:
1. Revert this phase's commits on `feature/nvim-0-12-clean` **except Step 2** (the seed.lua step is version-agnostic
   and is what refetches v0.14.2's library). If the whole phase must go, revert everything and then also
   `chmod -R u+w ~/.local/state/nvim-config-verify/.seed/data/nvim/lazy/blink.cmp/target && rm -rf
   ~/.local/state/nvim-config-verify/.seed/data/nvim/lazy/blink.cmp/target`, so the stale v1.10.2 library cannot
   shadow v0.14.2's.
2. Restore the seed lock:
   `cp ~/.local/state/nvim-config-verify/seed-lock.before-nvim-0-12-clean-phase-3.json ~/.local/state/nvim-config-verify/.seed/lazy-lock.json`.
   Its blink.cmp commit is `485c03400608cb6534bbf84da8c1c471fc4808c0`, and git-conflict.nvim is akinsho `4bbfdd9`.
3. Run `$V seed` from the reverted worktree (git-conflict MOVES back on the url change; blink is pinned back to
   `485c034`).
4. Check: `$V up --live` → `replaced_from_seed=` empty.

No owner file is written by this phase, so there is nothing to undo under `~/.config/nvim` or `~/.local/share/nvim`.
