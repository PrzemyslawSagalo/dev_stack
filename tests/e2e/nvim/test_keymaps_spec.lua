-- luacheck: std +busted
local source = debug.getinfo(1, "S").source
local current_file = source:sub(1, 1) == "@" and source:sub(2) or source
local repo_root = vim.fs.normalize(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(current_file)))))
local nvim_root = repo_root .. "/roles/nvim/files/nvim"
if vim.fn.isdirectory(nvim_root) == 1 then
	vim.opt.rtp:prepend(nvim_root)
end

local function find_keymap(mode, lhs)
	local keymaps = vim.api.nvim_get_keymap(mode)
	for _, map in ipairs(keymaps) do
		if map.lhs == lhs then
			return map
		end
	end
	return nil
end

describe("general_keymaps", function()
	before_each(function()
		require("core.globals")
		require("core.general_keymaps")
	end)

	it("maps normal mode <leader>q to :Bdelete", function()
		local map = find_keymap("n", " q")
		assert.is_not_nil(map)
		assert.are.same(":Bdelete<CR>", map.rhs)
	end)

	it("maps window navigation <leader>h/j/k/l to <C-w>h/j/k/l", function()
		local nav_keys = {
			[" h"] = "<C-w>h",
			[" j"] = "<C-w>j",
			[" k"] = "<C-w>k",
			[" l"] = "<C-w>l",
		}
		for lhs, expected_rhs in pairs(nav_keys) do
			local map = find_keymap("n", lhs)
			assert.is_not_nil(map, "Expected keymap for " .. lhs)
			assert.are.same(string.lower(expected_rhs), string.lower(map.rhs))
		end
	end)
end)

describe("copilot keymaps", function()
	local copilot_spec

	before_each(function()
		package.loaded["plugins.copilot"] = nil
		copilot_spec = require("plugins.copilot")
	end)

	after_each(function()
		package.loaded["plugins.copilot"] = nil
	end)

	it("has zero collisions on <C-j>, <C-k>, <C-c> in insert mode", function()
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

	it("rebinds copilot insert mode keys to meta keys", function()
		local keymap_by_desc = {}
		for _, key_def in ipairs(copilot_spec.keys) do
			if key_def.mode == "i" and key_def.desc then
				keymap_by_desc[key_def.desc] = key_def[1]
			end
		end

		assert.are.same("<M-\\>", keymap_by_desc["Copilot Accept"])
		assert.are.same("<M-]>", keymap_by_desc["Copilot Next"])
		assert.are.same("<M-[>", keymap_by_desc["Copilot Previous"])
		assert.are.same("<M-w>", keymap_by_desc["Copilot Dismiss"])
	end)
end)

describe("dap dynamic float sizing", function()
	local orig_columns
	local orig_lines

	before_each(function()
		orig_columns = vim.o.columns
		orig_lines = vim.o.lines
	end)

	after_each(function()
		vim.o.columns = orig_columns
		vim.o.lines = orig_lines
		package.loaded["dapui"] = nil
		package.loaded["dap"] = nil
		package.loaded["mason-nvim-dap"] = nil
		package.loaded["dap-python"] = nil
		package.loaded["plugins.dap"] = nil
	end)

	it("dynamically recalculates float size per invocation", function()
		local float_calls = {}
		package.loaded["dapui"] = {
			setup = function() end,
			float_element = function(element, opts)
				table.insert(float_calls, { element = element, opts = opts })
			end,
			toggle = function() end,
			open = function() end,
		}
		package.loaded["dap"] = {
			listeners = { after = { event_initialized = {} } },
			continue = function() end,
			step_over = function() end,
			step_into = function() end,
			step_out = function() end,
			toggle_breakpoint = function() end,
			terminate = function() end,
			set_breakpoint = function() end,
			clear_breakpoints = function() end,
		}
		package.loaded["mason-nvim-dap"] = {
			setup = function() end,
		}
		package.loaded["dap-python"] = {
			test_method = function() end,
		}

		package.loaded["plugins.dap"] = nil
		local dap_plugin = require("plugins.dap")
		dap_plugin.config()

		local df_map = find_keymap("n", " df")
		assert.is_not_nil(df_map)
		assert.is_not_nil(df_map.callback)

		vim.o.columns = 100
		vim.o.lines = 50
		df_map.callback()
		assert.are.same(1, #float_calls)
		assert.are.same(90, float_calls[1].opts.width)
		assert.are.same(45, float_calls[1].opts.height)

		vim.o.columns = 200
		vim.o.lines = 80
		df_map.callback()
		assert.are.same(2, #float_calls)
		assert.are.same(180, float_calls[2].opts.width)
		assert.are.same(72, float_calls[2].opts.height)
	end)
end)
