-- seed.lua: the one online phase. Runs inside `nvim --headless` AFTER the config's init.lua, with
-- XDG_DATA_HOME pointing at the shared verify seed, never at the owner's ~/.local/share/nvim.
-- Installs/restores every lazy plugin, compiles the treesitter parsers the config ensures, and
-- installs every Mason package the config names. Writes one line per step to $SEED_LOG.
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
-- Mirror the lock exactly. lazy ignores a lock entry whose branch differs from the spec's (an
-- unpinned spec follows GitHub's default branch), and cannot clone a repo GitHub no longer serves.
-- The seed pins the first and copies the second from the owner's live dir (read only), and says so.
local live_lazy = os.getenv("LIVE_LAZY")
-- lazy rewrites lazy-lock.json during its startup install, so read the copy taken before nvim ran.
local lock_orig = os.getenv("SEED_LOCK_ORIG") or lock
local ok_lock, lockdata = pcall(function()
  return vim.json.decode(table.concat(vim.fn.readfile(lock_orig), "\n"))
end)
if not update and ok_lock then
  for _, p in pairs(require("lazy.core.config").plugins) do
    local want = lockdata[p.name]
    if want and not vim.uv.fs_stat(p.dir) and live_lazy and vim.uv.fs_stat(live_lazy .. "/" .. p.name) then
      vim.fn.system { "cp", "-a", live_lazy .. "/" .. p.name, p.dir }
      -- lazy leaves <name>.cloning after the failed clone and treats it as an interrupted install
      -- (deletes the dir and re-clones on every start). Drop it with the copy in place.
      os.remove(p.dir .. ".cloning")
      log("WARN plugin %s: clone failed (gone from its remote?); copied from the live dir", p.name)
    end
    if want and vim.uv.fs_stat(p.dir) then
      local head = vim.trim(vim.fn.system { "git", "-C", p.dir, "rev-parse", "HEAD" })
      if head ~= want.commit then
        local branch = vim.trim(vim.fn.system { "git", "-C", p.dir, "rev-parse", "--abbrev-ref", "HEAD" })
        vim.fn.system { "git", "-C", p.dir, "checkout", "-q", want.commit }
        log(
          "WARN plugin %s: lazy left it on %s@%s, lock says %s@%s; pinned to the lock%s",
          p.name,
          branch,
          head:sub(1, 7),
          want.branch,
          want.commit:sub(1, 7),
          vim.v.shell_error == 0 and "" or " (CHECKOUT FAILED)"
        )
      end
    end
  end
end
for _, p in pairs(require("lazy.core.config").plugins) do
  if vim.uv.fs_stat(p.dir .. ".cloning") and vim.uv.fs_stat(p.dir .. "/.git") then
    os.remove(p.dir .. ".cloning")
  end
  if not vim.uv.fs_stat(p.dir) and p.enabled ~= false then
    log("WARN plugin %s not installed", p.name)
  end
end

step("treesitter parsers", function()
  -- The parsers config/treesitter.lua ensures. TSUpdateSync only updates installed ones.
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
  lazy.load { plugins = { "nvim-treesitter" } }
  local function missing()
    local m = {}
    for _, l in ipairs(langs) do
      if #vim.api.nvim_get_runtime_file("parser/" .. l .. ".so", false) == 0 then
        table.insert(m, l)
      end
    end
    return m
  end
  -- Only the missing ones: TSInstallSync asks "reinstall? y/n" for an installed parser, and a
  -- headless nvim waits on that prompt forever.
  local todo = missing()
  if #todo > 0 then
    if vim.fn.exists(":TSInstallSync") == 2 then
      vim.cmd("TSInstallSync " .. table.concat(todo, " "))
    else
      require("nvim-treesitter").install(todo):wait(600000)
    end
  end
  for _, f in ipairs(vim.fn.glob(vim.fn.stdpath("data") .. "/tree-sitter-*", false, true)) do
    vim.fn.delete(f, "rf")
  end
  assert(#missing() == 0, "parsers missing after install: " .. table.concat(missing(), ","))
end)

-- Mason: the tools mason-tool-installer and mason-lspconfig ensure, installed synchronously.
step("mason packages", function()
  local registry = require("mason-registry")
  local done = false
  registry.refresh(function()
    done = true
  end)
  vim.wait(120000, function()
    return done
  end, 200)
  local names = { "gofumpt", "stylua" }
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
    if pkg:is_installing() then
      -- The config itself installs gofumpt on every start (plugin_specs.lua, mason's config).
      pending[name] = true
      vim.wait(600000, function()
        return not pkg:is_installing()
      end, 500)
      pending[name] = nil
      log("%s mason %s (installed by the config's own startup install)", pkg:is_installed() and "ok  " or "FAIL", name)
    elseif pkg:is_installed() and not update then
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
log("done")
vim.cmd("qa!")
