-- /home/devmiftahul/.config/nvim/lua/config/nvim_ufo.lua

local handler = function(virtText, lnum, endLnum, width, truncate)
	local newVirtText = {}
	local foldedLines = endLnum - lnum
	local suffix = (" 󰁂  %d"):format(foldedLines)
	local sufWidth = vim.fn.strdisplaywidth(suffix)
	local targetWidth = width - sufWidth
	local curWidth = 0

	for _, chunk in ipairs(virtText) do
		local chunkText = chunk[1]
		local chunkWidth = vim.fn.strdisplaywidth(chunkText)
		if targetWidth > curWidth + chunkWidth then
			table.insert(newVirtText, chunk)
		else
			chunkText = truncate(chunkText, targetWidth - curWidth)
			local hlGroup = chunk[2]
			table.insert(newVirtText, { chunkText, hlGroup })
			chunkWidth = vim.fn.strdisplaywidth(chunkText)
			-- str width returned from truncate() may less than 2nd argument, need padding
			if curWidth + chunkWidth < targetWidth then
				suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
			end
			break
		end
		curWidth = curWidth + chunkWidth
	end
	local rAlignAppndx = math.max(math.min(vim.opt.textwidth["_value"], width - 1) - curWidth - sufWidth, 0)
	suffix = (" "):rep(rAlignAppndx) .. suffix
	table.insert(newVirtText, { suffix, "MoreMsg" })
	return newVirtText
end

require("ufo").setup({
	fold_virt_text_handler = handler,
})

vim.keymap.set("n", "zR", require("ufo").openAllFolds)
vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
vim.keymap.set("n", "zr", require("ufo").openFoldsExceptKinds)

-- This section adds keymaps like `z1`, `z2` to directly control the fold level,
-- making the visual information from statuscol actionable.

-- Helper function to set the exact visible fold level.
-- It works by closing all folds, then opening them level by level.
local function set_fold_level(level)
	-- First, close every fold in the buffer.
	vim.cmd("normal! zM")

	-- If the desired level is > 0, open folds one level at a time.
	if level > 0 then
		for _ = 1, level do
			vim.cmd("normal! zr")
		end
	end

	-- Move cursor to the top of the window to provide a consistent view.
	vim.cmd("normal! H")
	-- Optional: Clear the command line from messages like "X folds closed".
	vim.notify("Folds set to level " .. level, vim.log.levels.INFO, {
		title = "Folding",
		timeout = 1000,
	})
end

-- Keymap `z0` to close all folds (an alias for `zM`).
vim.keymap.set("n", "z0", function()
	set_fold_level(0)
end, { desc = "Folds: Close All" })

-- Keymaps to set the fold level directly.
-- These now correspond to the numbers you see in the status column!
vim.keymap.set("n", "z1", function()
	set_fold_level(1)
end, { desc = "Folds: Show Level 1" })
vim.keymap.set("n", "z2", function()
	set_fold_level(2)
end, { desc = "Folds: Show Level 2" })
vim.keymap.set("n", "z3", function()
	set_fold_level(3)
end, { desc = "Folds: Show Level 3" })
-- You can add z4, z5, etc. if you work with deeper nesting.

-- Keymap `z9` as an intuitive alias for "open all folds" (`zR`).
vim.keymap.set("n", "z9", function()
	vim.cmd("normal! zR")
end, { desc = "Folds: Open All" })
