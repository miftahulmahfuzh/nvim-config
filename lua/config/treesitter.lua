-- nvim-treesitter `main` (Neovim 0.12+). The plugin only installs parsers and queries, into
-- stdpath("data")/site. Highlighting, indentation and incremental selection are Neovim's own,
-- switched on here per buffer.

local parsers = {
	"python",
	"http",
	"cpp",
	"lua",
	"vim",
	"json",
	"toml",
	"markdown",
	"markdown_inline",
	"html",
	"css",
	"javascript",
	"go",
}

-- Install the parsers that are missing (asynchronous; nothing to do once all are installed).
-- Compiling needs the `tree-sitter` CLI, which Mason installs (tree-sitter-cli in
-- mason-tool-installer, plugin_specs.lua). On a first start Mason installs it after VimEnter.
local function install_missing()
	if vim.fn.executable("tree-sitter") ~= 1 then
		return false
	end
	local ts = require("nvim-treesitter")
	local installed = ts.get_installed("parsers")
	local missing = vim.tbl_filter(function(lang)
		return not vim.list_contains(installed, lang)
	end, parsers)
	if #missing > 0 then
		ts.install(missing)
	end
	return true
end

if not install_missing() then
	vim.api.nvim_create_autocmd("User", {
		pattern = "MasonToolsUpdateCompleted",
		once = true,
		callback = function()
			install_missing()
		end,
		desc = "Install treesitter parsers once Mason has the tree-sitter CLI",
	})
end

-- Filetypes that keep Vim's regex syntax on top of treesitter highlighting.
local keep_regex_syntax = { markdown = true }
-- Filetypes whose treesitter indentation is worse than Vim's own.
local no_treesitter_indent = { yaml = true }

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("config_treesitter", { clear = true }),
	callback = function(args)
		local buf, ft = args.buf, args.match
		if ft == "help" then
			return
		end
		local lang = vim.treesitter.language.get_lang(ft)
		if not lang then
			return
		end
		local ok_add, added = pcall(vim.treesitter.language.add, lang)
		if not (ok_add and added) then
			return
		end
		if not pcall(vim.treesitter.start, buf, lang) then
			return
		end
		local indent = not no_treesitter_indent[ft] and vim.treesitter.query.get(lang, "indents") ~= nil
		-- Neovim registers the ftplugin and indent FileType handlers after init.lua, so they run
		-- after this one: ftplugin/markdown.lua restarts treesitter (which clears 'syntax') and
		-- indent scripts set 'indentexpr'. Apply these two after them.
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			if keep_regex_syntax[ft] then
				vim.bo[buf].syntax = "ON"
			end
			if indent then
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end
		end)
	end,
	desc = "Treesitter highlighting and indentation where a parser is installed",
})

-- Incremental selection. nvim-treesitter `main` dropped its module; Neovim 0.12 has it built in
-- (Visual `an`/`in`). The old keys stay: `gnn` starts, `grn` grows, `grm` shrinks. `grc`
-- (scope_incremental) has no built-in equivalent and is gone. Normal-mode `grn` stays Neovim's
-- LSP rename. Like the built-in `an`/`in`, fall back to LSP selection ranges without a parser.
local function select_node(target, lsp_direction)
	return function()
		if vim.treesitter.get_parser(nil, nil, { error = false }) then
			vim.treesitter.select(target, vim.v.count1)
		else
			vim.lsp.buf.selection_range(lsp_direction * vim.v.count1)
		end
	end
end

vim.keymap.set("n", "gnn", select_node("parent", 1), { desc = "Start treesitter node selection" })
vim.keymap.set("x", "grn", select_node("parent", 1), { desc = "Grow selection to the parent node" })
vim.keymap.set("x", "grm", select_node("child", -1), { desc = "Shrink selection to the child node" })
