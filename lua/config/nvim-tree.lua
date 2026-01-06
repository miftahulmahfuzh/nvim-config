local keymap = vim.keymap
local nvim_tree = require("nvim-tree")

nvim_tree.setup {
  on_attach = function(bufnr)
    local api = require("nvim-tree.api")

    -- Include default keymaps
    api.config.mappings.default_on_attach(bufnr)

    local function insert_filepath()
      local node = api.tree.get_node_under_cursor()

      if node.type ~= "file" then
        return
      end

      local filepath = node.absolute_path

      -- Find a valid window that's not the nvim-tree window
      local current_win = vim.api.nvim_get_current_win()
      local target_win = nil

      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if win ~= current_win then
          -- Check if this window has a valid buffer
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
            target_win = win
            break
          end
        end
      end

      if not target_win then
        vim.notify("No valid window found to insert filepath", vim.log.levels.WARN)
        return
      end

      vim.api.nvim_win_call(target_win, function()
        vim.api.nvim_put({ " @" .. filepath .. " ." }, "c", true, true)
      end)
    end

    vim.keymap.set("n", "<C-k>", insert_filepath, {
      buffer = bufnr,
      desc = "Insert @filepath . into previous window",
    })
  end,
  auto_reload_on_write = true,
  disable_netrw = false,
  hijack_netrw = true,
  hijack_cursor = false,
  hijack_unnamed_buffer_when_opening = false,
  open_on_tab = false,
  sort_by = "name",
  update_cwd = false,
  view = {
    width = 30,
    side = "left",
    preserve_window_proportions = false,
    number = false,
    relativenumber = false,
    signcolumn = "yes",
  },
  renderer = {
    indent_markers = {
      enable = false,
      icons = {
        corner = "└ ",
        edge = "│ ",
        none = "  ",
      },
    },
    icons = {
      webdev_colors = true,
    },
  },
  hijack_directories = {
    enable = true,
    auto_open = true,
  },
  update_focused_file = {
    enable = false,
    update_cwd = false,
    ignore_list = {},
  },
  system_open = {
    cmd = "",
    args = {},
  },
  diagnostics = {
    enable = false,
    show_on_dirs = false,
    icons = {
      hint = "",
      info = "",
      warning = "",
      error = "",
    },
  },
  filters = {
    dotfiles = false,
    custom = {},
    exclude = {},
  },
  git = {
    enable = true,
    ignore = true,
    timeout = 400,
  },
  actions = {
    use_system_clipboard = true,
    change_dir = {
      enable = true,
      global = false,
      restrict_above_cwd = false,
    },
    open_file = {
      quit_on_open = false,
      resize_window = false,
      window_picker = {
        enable = true,
        chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
        exclude = {
          filetype = { "notify", "qf", "diff", "fugitive", "fugitiveblame" },
          buftype = { "nofile", "terminal", "help" },
        },
      },
    },
  },
  trash = {
    cmd = "trash",
    require_confirm = true,
  },
  log = {
    enable = false,
    truncate = false,
    types = {
      all = false,
      config = false,
      copy_paste = false,
      diagnostics = false,
      git = false,
      profile = false,
    },
  },
}

keymap.set("n", "<space>s", require("nvim-tree.api").tree.toggle, {
  silent = true,
  desc = "toggle nvim-tree",
})
