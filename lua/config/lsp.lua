-- /home/devmiftahul/.config/nvim/lua/config/lsp.lua

-- Enhanced LSP configuration to prevent attachment to fugitive buffers

local utils = require("utils")

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp_buf_conf", { clear = true }),
  callback = function(event_context)
    local bufnr = event_context.buf
    local client = vim.lsp.get_client_by_id(event_context.data.client_id)

    -- Get buffer URI and filetype
    local buf_uri = vim.uri_from_bufnr(bufnr)
    local filetype = vim.bo[bufnr].filetype

    -- Prevent LSP from attaching to fugitive buffers and other special buffers
    if
      filetype == "fugitive"
      or filetype == "git"
      or filetype == "gitcommit"
      or filetype == "gitrebase"
      or (buf_uri and not buf_uri:match("^file://"))
    then
      if client then
        -- Detach the client from this buffer to stop any further communication
        vim.lsp.buf_detach_client(bufnr, client.id)
        vim.notify(string.format("Detached %s from %s buffer", client.name, filetype), vim.log.levels.DEBUG)
      end
      return
    end

    if not client then
      return
    end

    -- Mappings.
    local map = function(mode, l, r, opts)
      opts = opts or {}
      opts.silent = true
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    map("n", "gd", function()
      vim.lsp.buf.definition {
        on_list = function(options)
          -- custom logic to avoid showing multiple definition when you use this style of code:
          -- `local M.my_fn_name = function() ... end`.
          -- See also post here: https://www.reddit.com/r/neovim/comments/19cvgtp/any_way_to_remove_redundant_definition_in_lua_file/

          -- vim.print(options.items)
          local unique_defs = {}
          local def_loc_hash = {}

          -- each item in options.items contain the location info for a definition provided by LSP server
          for _, def_location in pairs(options.items) do
            -- use filename and line number to uniquelly indentify a definition,
            -- we do not expect/want multiple definition in single line!
            local hash_key = def_location.filename .. def_location.lnum

            if not def_loc_hash[hash_key] then
              def_loc_hash[hash_key] = true
              table.insert(unique_defs, def_location)
            end
          end

          options.items = unique_defs

          -- set the location list
          ---@diagnostic disable-next-line: param-type-mismatch
          vim.fn.setloclist(0, {}, " ", options)

          -- open the location list when we have more than 1 definitions found,
          -- otherwise, jump directly to the definition
          if #options.items > 1 then
            vim.cmd.lopen()
          else
            vim.cmd([[silent! lfirst]])
          end
        end,
      }
    end, { desc = "go to definition" })
    map("n", "gr", function()
      vim.lsp.buf.references(nil, {
        on_list = function(options)
          if not options.items or vim.tbl_isempty(options.items) then
            vim.notify("No references found.", vim.log.levels.INFO, { title = "LSP" })
            return
          end
          -- Populate the quickfix list using the location items.
          -- The ' ' as the third argument uses the `title` field from the `options` table.
          vim.fn.setqflist({}, " ", options)
          -- Open the quickfix window.
          vim.cmd("copen")
        end,
      })
    end, { desc = "go to references (quickfix)" })
    map("n", "<C-]>", vim.lsp.buf.definition)
    map("n", "K", function()
      vim.lsp.buf.hover { border = "single", max_height = 25, max_width = 120 }
    end)
    map("n", "<C-k>", vim.lsp.buf.signature_help)
    map("n", "<space>rn", vim.lsp.buf.rename, { desc = "varialbe rename" })
    map("n", "<space>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
    map("n", "<space>wa", vim.lsp.buf.add_workspace_folder, { desc = "add workspace folder" })
    map("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, { desc = "remove workspace folder" })
    map("n", "<space>wl", function()
      vim.print(vim.lsp.buf.list_workspace_folders())
    end, { desc = "list workspace folder" })

    -- Set some key bindings conditional on server capabilities
    -- Disable ruff hover feature in favor of Pyright
    if client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end

    -- Uncomment code below to enable inlay hint from language server, some LSP server supports inlay hint,
    -- but disable this feature by default, so you may need to enable inlay hint in the LSP server config.
    -- vim.lsp.inlay_hint.enable(true, {buffer=bufnr})

    -- The blow command will highlight the current variable and its usages in the buffer.
    if client.server_capabilities.documentHighlightProvider then
      local gid = vim.api.nvim_create_augroup("lsp_document_highlight", { clear = true })
      vim.api.nvim_create_autocmd("CursorHold", {
        group = gid,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.document_highlight()
        end,
      })

      vim.api.nvim_create_autocmd("CursorMoved", {
        group = gid,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.clear_references()
        end,
      })
    end
  end,
  nested = true,
  desc = "Configure buffer keymap and behavior based on LSP",
})

-- Additional autocmd to prevent LSP from attaching to fugitive buffers in the first place
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "fugitive", "git", "gitcommit", "gitrebase" },
  callback = function(event)
    local bufnr = event.buf
    -- Get all attached clients and detach them
    local clients = vim.lsp.get_clients { bufnr = bufnr }
    for _, client in ipairs(clients) do
      vim.lsp.buf_detach_client(bufnr, client.id)
    end

    -- Disable LSP for this buffer
    vim.b[bufnr].lsp_enabled = false
  end,
  desc = "Disable LSP for git-related buffers",
})

-- Enable lsp servers when they are available

local capabilities = require("lsp_utils").get_default_capabilities()

vim.lsp.config("*", {
  capabilities = capabilities,
  flags = {
    debounce_text_changes = 500,
  },
})

-- A mapping from lsp server name to the executable name
local enabled_lsp_servers = {
  lua_ls = "lua-language-server",
  gopls = "gopls",
  pyright = "delance-langserver",
  ruff = "ruff",
  vimls = "vim-language-server",
}

for server_name, lsp_executable in pairs(enabled_lsp_servers) do
  if utils.executable(lsp_executable) then
    vim.lsp.enable(server_name)
  else
    local msg = string.format(
      "Executable '%s' for server '%s' not found! Server will not be enabled",
      lsp_executable,
      server_name
    )
    vim.notify(msg, vim.log.levels.WARN, { title = "Nvim-config" })
  end
end

vim.api.nvim_create_autocmd("ModeChanged", {
  group = vim.api.nvim_create_augroup("auto_save_on_normal", { clear = true }),
  pattern = "*:n", -- Trigger when switching to normal mode
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" then -- Only save if buffer is modified and is a normal file buffer
      vim.cmd("write")
    end
  end,
  desc = "Auto-save when entering normal mode",
})
