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
