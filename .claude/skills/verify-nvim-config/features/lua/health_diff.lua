-- Compares the newest :checkhealth report with the allow-list in features/health.md. Read-only.
--   verify.sh lua RUN @.claude/skills/verify-nvim-config/features/lua/health_diff.lua
-- Every WARNING/ERROR line becomes a key "<section>[ / <subsection>]: <LEVEL> <message>"; a
-- message ending in ":" takes its first indented continuation line. A key is allowed when it
-- equals an entry of health.md's ```allow blocks, or starts with an entry's text before its
-- trailing "*". A vim.deprecated key's subsection is the plugin of its first stack frame. First line: "sections=N findings=N allowed=N unexpected=N unused=N" (pass:
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
      local sub = subsection
      if section == "vim.deprecated" then
        -- the message never names its caller: take the plugin of the first stack frame under lazy/
        -- as the subsection, so an entry allows one plugin's deprecation and not another's
        for j = i + 1, #lines do
          if lines[j]:match("^%- ") or lines[j]:match("^=+$") then
            break
          end
          local plugin = lines[j]:match("/lazy/([^/]+)/")
          if plugin then
            sub = plugin
            break
          end
        end
      end
      table.insert(keys, ("%s%s: %s %s"):format(section, sub and (" / " .. sub) or "", level, message))
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
