-- fidget keeps its notification window off nvim-tree's window. That used to be an implicit
-- integration (`integration["nvim-tree"].enable`, default on), which :checkhealth fidget flags
-- because a future release removes it; its advice is to list the filetype in
-- notification.window.avoid instead, which keeps the same behaviour.
require("fidget").setup {
  notification = {
    window = {
      avoid = { "NvimTree" },
    },
  },
}

-- Passing `integration["nvim-tree"].enable` to setup() is itself reported as a deprecated option, so
-- the implicit integration is switched off on its module after setup; the avoid list above already
-- does what it did. Once fidget drops the module there is nothing to switch off.
local nvim_tree_integration = package.loaded["fidget.integration.nvim-tree"]
if nvim_tree_integration then
  nvim_tree_integration.options.enable = false
end
