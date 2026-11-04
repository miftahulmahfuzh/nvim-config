local M = {}

function M.greet(name)
      local   msg = "hello, " .. name
  return msg
end

function M.sum(a,b) return a+b end

return M
