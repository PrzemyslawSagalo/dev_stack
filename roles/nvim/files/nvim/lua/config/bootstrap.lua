local M = {}

local targets = {
	mason = function()
		local languages = require("config.languages")
		return {
			cmd = "MasonToolsInstallSync",
			items = languages.linters.mason_tools,
			is_installed = require("mason-registry").is_installed,
			label = "Mason tool",
		}
	end,
	treesitter = function()
		local items = require("config.languages").treesitter
		return {
			cmd = "TSUpdateSync " .. table.concat(items, " "),
			items = items,
			is_installed = require("nvim-treesitter.parsers").has_parser,
			label = "Treesitter parser",
		}
	end,
}

function M.sync(name)
	local spec = assert(targets[name], "Unknown bootstrap target: " .. tostring(name))()
	vim.cmd(spec.cmd)
	for _, item in ipairs(spec.items) do
		if not spec.is_installed(item) then
			io.stderr:write("Missing " .. spec.label .. ": " .. item .. "\n")
			os.exit(1)
		end
	end
end

return M
