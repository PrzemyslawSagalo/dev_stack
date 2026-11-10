-- luacheck: std +busted
local source = debug.getinfo(1, "S").source
local current_file = source:sub(1, 1) == "@" and source:sub(2) or source
local repo_root = vim.fs.normalize(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(current_file)))))
local nvim_root = repo_root .. "/roles/nvim/files/nvim"
if vim.fn.isdirectory(nvim_root) == 1 then
	vim.opt.rtp:prepend(nvim_root)
end

describe("copilot keymaps", function()
	local copilot_spec

	before_each(function()
		package.loaded["plugins.copilot"] = nil
		copilot_spec = require("plugins.copilot")
	end)

	after_each(function()
		package.loaded["plugins.copilot"] = nil
	end)

	it("strictly protects <C-j>, <C-k>, <C-c> from Copilot hijacking in insert mode", function()
		local forbidden = {
			["<C-j>"] = true,
			["<C-k>"] = true,
			["<C-c>"] = true,
		}
		for _, key_def in ipairs(copilot_spec.keys) do
			if key_def.mode == "i" then
				assert.is_nil(forbidden[key_def[1]], "Forbidden Copilot keymap found: " .. tostring(key_def[1]))
			end
		end
	end)
end)

describe("dap float dimension calculation", function()
	local dap_spec = require("plugins.dap")

	it("calculates 90% screen dimensions accurately as a pure function", function()
		local dims = dap_spec.get_float_dimensions(100, 50)
		assert.are.same({ width = 90, height = 45 }, dims)

		local dims_odd = dap_spec.get_float_dimensions(105, 53)
		assert.are.same({ width = 94, height = 47 }, dims_odd)
	end)
end)
