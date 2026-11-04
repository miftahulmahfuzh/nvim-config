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
