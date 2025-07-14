-- /home/devmiftahul/.config/nvim/lua/colorscheme_picker.lua

local M = {}

--- Opens a popup window to select a colorscheme.
function M.open()
  -- Get all available colorschemes
  local colorschemes = vim.fn.getcompletion("", "color") -- [2]

  -- Get the current colorscheme
  local current_colorscheme = vim.g.colors_name or "default" -- [3]

  -- Create a prompt for the popup window
  local prompt = "Current: " .. current_colorscheme

  vim.ui.select(colorschemes, {
    prompt = prompt,
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if not choice then
      return
    end

    -- The user's `colorschemes.lua` file handles the specific setup for each theme.
    -- We'll try to call the corresponding function from there.
    local colorscheme_conf = require("colorschemes").colorscheme_conf
    local colorscheme_name = choice:gsub("%-", "_") -- Normalize names like gruvbox-material

    if colorscheme_conf[colorscheme_name] then
      colorscheme_conf[colorscheme_name]()
    else
      -- Fallback for themes not in the custom config
      vim.cmd("colorscheme " .. choice)
    end
  end)
end

return M
