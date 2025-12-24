local keymap = vim.keymap
local hop = require("hop")

hop.setup {
  keys = "etovxqpdygfblzhckisuran",
  -- Use case insensitive search by default
  case_insensitive = true,
  -- Jump options
  jump_on_sole_occurrence = true,
  -- Create hints in a multi-window context
  multi_windows = true,
}

-- Map 'f' in normal mode to hop words
keymap.set("n", "f", function()
  hop.hint_words()
end, { desc = "Hop to word" })

-- Optional: Map 'F' to hop to any character (1-key)
keymap.set("n", "F", function()
  hop.hint_char1({ direction = require("hop.hint").HintDirection.BEFORE_CURSOR })
end, { desc = "Hop to character (backward)" })

-- Optional: Visual mode mappings
keymap.set("x", "f", function()
  hop.hint_words()
end, { desc = "Hop to word (visual)" })
