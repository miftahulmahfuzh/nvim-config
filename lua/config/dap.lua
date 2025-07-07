-- /home/devmiftahul/.config/nvim/lua/config/dap.lua

require("dap").set_log_level("DEBUG")
local dap = require("dap")

if vim.fn.executable("dlv") == 0 then
  vim.notify("'delve' (dlv) not found in PATH. Please run :MasonInstall delve", vim.log.levels.WARN, { title = "nvim-dap" })
  return
end

-- dap.adapters.go = {
--   type = "executable",
--   command = vim.fn.stdpath("data") .. "/mason/bin/dlv",
--   args = { "dap" },
-- }
dap.adapters.go = {
  type = "server",
  port = 2345,
  executable = {
    command = vim.fn.stdpath("data") .. "/mason/bin/dlv",
    args = { "dap", "--listen=127.0.0.1:2345" },
  },
}

dap.configurations.go = {
  {
    type = "go",
    name = "Debug (Test file)",
    request = "launch",
    mode = "test",
    program = "${file}",
    cwd = vim.fn.fnamemodify(vim.fn.findfile("go.mod", ".;"), ":h"),
    args = { "-test.run", "^${func}$" },
  },
  {
    type = "go",
    name = "Debug (Main file)",
    request = "launch",
    mode = "debug",
    program = vim.fn.expand("%:p:h"),
    cwd = vim.fn.fnamemodify(vim.fn.findfile("go.mod", ".;"), ":h"),
  },
}

print("nvim-dap for Go configured successfully.")
