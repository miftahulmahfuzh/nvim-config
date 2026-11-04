-- seed.lua: the one online phase. Runs inside `nvim --headless` AFTER the config's init.lua, with
-- XDG_DATA_HOME pointing at the shared verify seed, never at the owner's ~/.local/share/nvim.
-- Installs/restores every lazy plugin, installs every Mason package the config names, then
-- compiles the treesitter parsers the config installs (they need Mason's tree-sitter CLI).
-- Writes one line per step to $SEED_LOG.
local log_path = assert(os.getenv("SEED_LOG"), "SEED_LOG unset")
local update = os.getenv("SEED_UPDATE") == "1"
local function log(fmt, ...)
  local f = assert(io.open(log_path, "a"))
  f:write(string.format(fmt, ...) .. "\n")
  f:close()
end
local function step(name, fn)
  local ok, err = pcall(fn)
  log("%s %s%s", ok and "ok  " or "FAIL", name, ok and "" or (": " .. tostring(err)))
  return ok
end

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

-- Mason: the tools mason-tool-installer and mason-lspconfig ensure, installed synchronously.
-- Nothing else is installing here: this file runs from `-c` before VimEnter (mason-tool-installer's
-- run_on_start), mason-lspconfig skips ensure_installed in a headless nvim, and the config's own
-- Mason spec installs nothing.
step("mason packages", function()
  local registry = require("mason-registry")
  local done = false
  registry.refresh(function()
    done = true
  end)
  vim.wait(120000, function()
    return done
  end, 200)
  local names = { "gofumpt", "stylua", "tree-sitter-cli" }
  local ok_map, mapping = pcall(function()
    return require("mason-lspconfig").get_mappings().lspconfig_to_package
  end)
  if not ok_map then
    ok_map, mapping = pcall(function()
      return require("mason-lspconfig.mappings.server").lspconfig_to_package
    end)
  end
  for _, server in ipairs { "lua_ls", "yamlls", "bashls", "pyright", "gopls", "html", "cssls" } do
    table.insert(names, ok_map and mapping[server] or server)
  end
  local pending = {}
  for _, name in ipairs(names) do
    local pkg = registry.get_package(name)
    if pkg:is_installed() and not update then
      log("ok   mason %s already installed", name)
    else
      pending[name] = true
      pkg:install({}, function(success, err)
        log("%s mason %s%s", success and "ok  " or "FAIL", name, success and "" or (": " .. tostring(err)))
        pending[name] = nil
      end)
    end
  end
  vim.wait(900000, function()
    return next(pending) == nil
  end, 500)
  for name in pairs(pending) do
    log("FAIL mason %s: timed out", name)
  end
end)

-- After the Mason step: nvim-treesitter `main` compiles parsers with the `tree-sitter` CLI, which
-- Mason just installed (tree-sitter-cli). Parsers and queries go into stdpath("data")/site.
step("treesitter parsers", function()
  -- The parsers config/treesitter.lua installs.
  local langs = {
    "python",
    "http",
    "cpp",
    "lua",
    "vim",
    "json",
    "toml",
    "markdown",
    "markdown_inline",
    "html",
    "css",
    "javascript",
    "go",
  }
  -- Modules required from the checkout this seed just moved away from (`master`) are still
  -- cached; drop them so the `main` ones load.
  for name in pairs(package.loaded) do
    if name == "nvim-treesitter" or name:find("^nvim%-treesitter%.") then
      package.loaded[name] = nil
    end
  end
  lazy.load { plugins = { "nvim-treesitter" } }
  assert(pcall(require, "nvim-treesitter.config"), "nvim-treesitter is not on its `main` branch")
  -- A plugin dir that was on `master` keeps master's untracked build output after the checkout
  -- to `main`. It is on the runtimepath, so nvim would load those stale parsers.
  local plugin_dir = require("lazy.core.config").plugins["nvim-treesitter"].dir
  for _, sub in ipairs { "parser", "parser-info" } do
    if vim.uv.fs_stat(plugin_dir .. "/" .. sub) then
      vim.fn.delete(plugin_dir .. "/" .. sub, "rf")
      log("WARN plugin nvim-treesitter: removed %s/ left over from master", sub)
    end
  end
  assert(vim.fn.executable("tree-sitter") == 1, "no tree-sitter CLI on PATH (Mason tree-sitter-cli)")
  local ts = require("nvim-treesitter")
  local function missing()
    local installed = ts.get_installed("parsers")
    return vim.tbl_filter(function(l)
      return not vim.list_contains(installed, l)
    end, langs)
  end
  local todo = missing()
  if #todo > 0 then
    ts.install(todo, { summary = true }):wait(600000)
  end
  for _, f in ipairs(vim.fn.glob(vim.fn.stdpath("data") .. "/tree-sitter-*", false, true)) do
    vim.fn.delete(f, "rf")
  end
  assert(#missing() == 0, "parsers missing after install: " .. table.concat(missing(), ","))
end)
log("done")
vim.cmd("qa!")
