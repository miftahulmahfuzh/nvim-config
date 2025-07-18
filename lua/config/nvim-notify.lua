-- /home/miftah/.config/nvim/lua/config/nvim-notify.lua

local nvim_notify = require("notify")

nvim_notify.setup({
	-- To make notifications appear and disappear instantly with no animation.
	stages = "static",

	-- Set the default timeout to 2 seconds (2000 milliseconds).
	timeout = 1996,

	background_colour = "#2E3440",
})

vim.notify = nvim_notify
