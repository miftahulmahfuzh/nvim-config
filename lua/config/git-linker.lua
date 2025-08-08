-- /home/devmiftahul/.config/nvim/lua/config/git-linker.lua

local keymap = vim.keymap
local gitlinker = require("gitlinker")

gitlinker.setup({
	callbacks = {
		["dev.azure.com"] = function(url_data)
			vim.print(url_data)
			local url = require("gitlinker.hosts").get_base_https_url(url_data)

			if url_data.lstart then
				if url_data.lend == nil then
					url_data.lend = url_data.lstart
				end
				url = url
					.. "?path=/"
					.. url_data.file
					.. "&version=GC"
					.. url_data.rev
					.. "&line="
					.. url_data.lstart
					.. "&lineEnd="
					.. url_data.lend
					.. "&lineStartColumn=1"
					.. "&lineEndColumn=120"
			end
			return url
		end,
		-- GitLab support
		["git.tuntun.co.id"] = function(url_data)
			vim.print(url_data)
			local url = require("gitlinker.hosts").get_base_https_url(url_data)

			-- GitLab uses /-/blob/ instead of /blob/
			url = url .. "/-/blob/" .. url_data.rev .. "/" .. url_data.file

			if url_data.lstart then
				if url_data.lend == nil then
					url_data.lend = url_data.lstart
				end
				-- GitLab uses #L for line numbers
				url = url .. "#L" .. url_data.lstart
				-- If there's a range, add the end line
				if url_data.lend ~= url_data.lstart then
					url = url .. "-" .. url_data.lend
				end
			end
			return url
		end,
		-- Generic GitLab support for other GitLab instances
		["gitlab.com"] = function(url_data)
			vim.print(url_data)
			local url = require("gitlinker.hosts").get_base_https_url(url_data)

			-- GitLab uses /-/blob/ instead of /blob/
			url = url .. "/-/blob/" .. url_data.rev .. "/" .. url_data.file

			if url_data.lstart then
				if url_data.lend == nil then
					url_data.lend = url_data.lstart
				end
				-- GitLab uses #L for line numbers
				url = url .. "#L" .. url_data.lstart
				-- If there's a range, add the end line
				if url_data.lend ~= url_data.lstart then
					url = url .. "-" .. url_data.lend
				end
			end
			return url
		end,
	},
	mappings = nil,
})

keymap.set({ "n", "v" }, "<leader>gl", function()
	local mode = string.lower(vim.fn.mode())
	gitlinker.get_buf_range_url(mode, {
		action_callback = gitlinker.actions.copy_to_clipboard,
	})
end, {
	silent = true,
	desc = "Git: get permlink",
})

keymap.set("n", "<leader>gbr", function()
	gitlinker.get_repo_url({
		action_callback = gitlinker.actions.open_in_browser,
	})
end, {
	silent = true,
	desc = "Git: browse repo in browser",
})
