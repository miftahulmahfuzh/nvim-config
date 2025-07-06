-- /home/devmiftahul/.config/nvim/lua/config/fzf-lua.lua

require("fzf-lua").setup {
  defaults = {
    file_icons = "mini",
  },
  winopts = {
    row = 0.5,
    height = 0.7,
  },
  files = {
    previewer = false,
  },
}

vim.keymap.set("n", "<leader>ff", "<cmd>FzfLua files<cr>", { desc = "Fuzzy find files" })
vim.keymap.set("n", "<leader>fg", "<cmd>FzfLua live_grep<cr>", { desc = "Fuzzy grep files" })
vim.keymap.set("n", "<leader>fh", "<cmd>FzfLua helptags<cr>", { desc = "Fuzzy grep tags in help files" })
vim.keymap.set("n", "<leader>ft", "<cmd>FzfLua btags<cr>", { desc = "Fuzzy search buffer tags" })
vim.keymap.set("n", "<leader>fb", "<cmd>FzfLua buffers<cr>", { desc = "Fuzzy search opened buffers" })

-- keymap for live_grep with word under cursor or visual selection
vim.keymap.set({ "n", "v" }, "<leader>m", function()
  local fzf_lua = require("fzf-lua")
  local search_term

  -- Check if we are in visual mode by checking the result of vim.fn.mode()
  if vim.fn.mode():find("[vV]") then
    -- This is a safe way to get the visual selection without clobbering any registers
    -- that the user might be actively using. We temporarily use register 'z'.
    local old_reg_z = vim.fn.getreg('z')
    local old_reg_z_type = vim.fn.getregtype('z')
    vim.cmd('noau normal! "zy"') -- yank current visual selection into register 'z'
    search_term = vim.fn.getreg('z')
    vim.fn.setreg('z', old_reg_z, old_reg_z_type) -- restore register 'z' to its previous state

    -- For multi-line selections, it's better to replace newlines with spaces
    search_term = search_term:gsub('\n', ' ')
  else
    -- In normal mode, get the word under the cursor
    search_term = vim.fn.expand("<cword>")
  end

  -- Trim leading/trailing whitespace to avoid issues
  search_term = vim.fn.trim(search_term)

  if search_term == "" then
    -- If no word is found (e.g., on a blank line), just open live_grep with an empty prompt
    fzf_lua.live_grep()
  else
    -- Call the live_grep Lua function with the 'search' option pre-filled
    fzf_lua.live_grep({
      search = search_term,
    })
  end
end, { desc = "Grep for word/selection" })
