-- /home/devmiftahul/.config/nvim/lua/colorscheme_picker.lua

local M = {}

--- Opens a popup window to select a colorscheme.
function M.open()
  -- Get all available colorschemes.
  -- This will now work correctly after the fix in lazy.nvim config.
  local colorschemes = vim.fn.getcompletion("", "color")

  -- Sort the list alphabetically for easier navigation
  table.sort(colorschemes)

  -- Get the current colorscheme to display it
  local current_colorscheme = vim.g.colors_name or "default"
  local prompt = "Current: " .. current_colorscheme

  vim.ui.select(colorschemes, {
    prompt = prompt,
    format_item = function(item)
      return item
    end,
  }, function(choice)
    -- If the user aborted (pressed <esc>), do nothing
    if not choice then
      print("Colorscheme selection canceled.")
      return
    end

    -- Use a protected call to catch errors if a colorscheme fails to load
    local success, err = pcall(vim.cmd, "colorscheme " .. choice)

    if not success then
      vim.notify("Error setting colorscheme: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("Colorscheme set to: " .. choice, vim.log.levels.INFO)
      -- Update the global variable so the prompt is correct next time
      vim.g.colors_name = choice
    end
  end)
end

return M
