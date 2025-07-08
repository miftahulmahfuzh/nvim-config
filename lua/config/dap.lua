-- /home/devmiftahul/.config/nvim/lua/config/dap.lua

local dap = require("dap")

-- Check if delve is available
if vim.fn.executable("dlv") == 0 then
  vim.notify("'delve' (dlv) not found in PATH. Please run :MasonInstall delve", vim.log.levels.WARN, { title = "nvim-dap" })
  return
end

dap.adapters.go = {
  type = "server",
  port = 2345,
  executable = {
    command = vim.fn.stdpath("data") .. "/mason/bin/dlv",
    args = { "dap", "--listen=127.0.0.1:2345" },
  },
}

-- Configure Go debugging scenarios
dap.configurations.go = {
  {
    type = "go",
    name = "Debug Test (go.mod)",
    request = "launch",
    mode = "test",
    program = "./${relativeFileDirname}",
    showLog = false,
  },
  {
    type = "go",
    name = "Debug (go.mod)",
    request = "launch",
    program = "./${relativeFileDirname}",
    showLog = false,
  },
}

-- Optional: Add some helper functions for debugging
local function get_arguments()
  local args = {}
  local input = vim.fn.input("Arguments: ")
  if input ~= "" then
    for arg in string.gmatch(input, "%S+") do
      table.insert(args, arg)
    end
  end
  return args
end

-- Add a configuration with arguments
table.insert(dap.configurations.go, {
  type = "go",
  name = "Debug with Arguments",
  request = "launch",
  program = "${file}",
  args = get_arguments,
  showLog = false,
})

print("nvim-dap for Go configured successfully with Delve.")
