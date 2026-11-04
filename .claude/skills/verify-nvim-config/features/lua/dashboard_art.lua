-- Which ascii_art/*.txt each visible dashboard window shows (by exact content, padding stripped),
-- plus the art name the dashboard saved in its cache file. Read-only.
--   verify.sh lua RUN "return dofile('$SKILL/features/lua/dashboard_art.lua')"
local function norm(lines)
  local out = {}
  for _, l in ipairs(lines) do
    l = l:gsub("^%s+", ""):gsub("%s+$", "")
    if l ~= "" then
      table.insert(out, l)
    end
  end
  return table.concat(out, "\n")
end
local arts = {}
for _, f in ipairs(vim.fn.glob(vim.fn.stdpath("config") .. "/ascii_art/*.txt", false, true)) do
  arts[vim.fn.fnamemodify(f, ":t:r")] = norm(vim.fn.readfile(f))
end
local shown = {}
for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
  local b = vim.api.nvim_win_get_buf(w)
  if vim.bo[b].filetype == "dashboard" then
    local text, name = norm(vim.api.nvim_buf_get_lines(b, 0, -1, false)), "unknown"
    for n, a in pairs(arts) do
      if a == text then
        name = n
      end
    end
    table.insert(shown, name)
  end
end
local cache = vim.fn.stdpath("cache") .. "/dashboard_ascii_art.txt"
local saved = vim.fn.filereadable(cache) == 1 and vim.trim(table.concat(vim.fn.readfile(cache), "")) or "(none)"
return "shown=" .. (#shown > 0 and table.concat(shown, ",") or "(no dashboard window)") .. " saved=" .. saved
