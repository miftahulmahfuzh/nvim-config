-- /home/devmiftahul/.config/nvim/lua/config/dap.lua

-- local dap = require("dap")

-- -- Tell nvim-dap where to find the delve debugger installed by Mason
-- local dap_delve_path = require("mason-registry").get_package("delve"):get_install_path() .. "/dlv"

-- dap.adapters.go = {
--   type = "executable",
--   command = dap_delve_path,
--   args = { "dap" },
-- }

-- -- This is the crucial part that tells nvim-dap how to configure the debug session for Go
-- dap.configurations.go = {
--   {
--     type = "go",
--     name = "Debug (Test file)",
--     request = "launch",
--     -- This allows you to debug the current test function
--     mode = "test",
--     program = "${fileDirname}",
--   },
--   {
--     type = "go",
--     name = "Debug (Main file)",
--     request = "launch",
--     mode = "debug",
--     program = "${fileDirname}",
--   },
-- }

-- print("nvim-dap for Go configured successfully.")
