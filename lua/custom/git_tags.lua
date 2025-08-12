-- /home/devmiftahul/.config/nvim/lua/custom/git_tags.lua

local M = {}

-- Function to get git tags sorted by version
function M.get_tags()
	local tags = vim.fn.systemlist("git tag --sort=-version:refname")
	if vim.v.shell_error ~= 0 then
		return {}
	end
	return tags
end

-- Show tag in a new buffer
function M.show_tag(tag)
	if not tag or tag == "" then
		vim.notify("No tag specified", vim.log.levels.WARN)
		return
	end

	local output = vim.fn.system("git show " .. tag)
	if vim.v.shell_error ~= 0 then
		vim.notify("Failed to show tag: " .. tag, vim.log.levels.ERROR)
		return
	end

	-- Create a new scratch buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "filetype", "git")

	-- Split the output into lines and set buffer content
	local lines = vim.split(output, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)

	-- Open in a new split
	vim.cmd("split")
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_buf_set_name(buf, "git-show-" .. tag)
end

-- Interactive tag selector
function M.select_and_show_tag()
	local tags = M.get_tags()
	if #tags == 0 then
		vim.notify("No tags found in this repository", vim.log.levels.WARN)
		return
	end

	vim.ui.select(tags, {
		prompt = "Select a tag to show:",
		format_item = function(item)
			return item
		end,
	}, function(choice)
		if choice then
			M.show_tag(choice)
		end
	end)
end

-- Compare two tags
function M.compare_tags()
	local tags = M.get_tags()
	if #tags < 2 then
		vim.notify("Need at least 2 tags to compare", vim.log.levels.WARN)
		return
	end

	vim.ui.select(tags, {
		prompt = "Select first tag:",
	}, function(first_tag)
		if not first_tag then
			return
		end

		vim.ui.select(tags, {
			prompt = "Select second tag:",
		}, function(second_tag)
			if not second_tag then
				return
			end

			local cmd = string.format("git diff %s..%s", first_tag, second_tag)
			vim.cmd("Git " .. cmd:sub(5)) -- Remove 'git ' prefix since we're using :Git
		end)
	end)
end

-- List tags with their dates and messages
function M.list_tags_detailed()
	local cmd =
		"git for-each-ref --sort=-creatordate --format='%(refname:short)%09%(creatordate:short)%09%(subject)' refs/tags"
	local output = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("Failed to get tag details", vim.log.levels.ERROR)
		return
	end

	-- Create a new scratch buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "filetype", "gitrebase") -- For basic syntax highlighting

	local lines = vim.split(output, "\n")
	-- Add header
	table.insert(lines, 1, "Tag\t\t\tDate\t\tMessage")
	table.insert(lines, 2, string.rep("=", 80))

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)

	-- Open in a new split
	vim.cmd("split")
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_buf_set_name(buf, "git-tags-list")

	-- Add keymap to show tag under cursor
	vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
		callback = function()
			local line = vim.api.nvim_get_current_line()
			local tag = line:match("^(%S+)")
			if tag and tag ~= "Tag" and tag ~= "=" then
				M.show_tag(tag)
			end
		end,
		desc = "Show tag under cursor",
	})
end

return M
