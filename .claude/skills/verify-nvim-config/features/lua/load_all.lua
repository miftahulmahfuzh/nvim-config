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
