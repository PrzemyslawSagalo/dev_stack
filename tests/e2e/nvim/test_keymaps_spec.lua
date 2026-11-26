-- luacheck: std +busted

describe("safe buffer close keymap (:Bdelete via vim-bbye)", function()
	after_each(function()
		vim.cmd("silent! only!")
	end)

	it("given normal mode, when inspecting the <leader>q mapping, then it maps to :Bdelete<CR>", function()
		local map_info = vim.fn.maparg("<leader>q", "n", false, true)
		assert.is_not_nil(map_info)
		assert.are.same(":Bdelete<CR>", map_info.rhs)
	end)

	it(
		"given two buffers in a vertical split, when executing :Bdelete, then layout is kept and buffer is unlisted",
		function()
			local buf1 = vim.api.nvim_create_buf(true, false)
			local buf2 = vim.api.nvim_create_buf(true, false)
			assert.is_true(vim.api.nvim_buf_is_valid(buf1))
			assert.is_true(vim.api.nvim_buf_is_valid(buf2))

			local win1 = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(win1, buf1)
			vim.cmd("vsplit")
			local win2 = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(win2, buf2)
			assert.are.same(2, #vim.api.nvim_tabpage_list_wins(0))

			vim.api.nvim_set_current_win(win1)
			assert.are.same(buf1, vim.api.nvim_get_current_buf())

			vim.cmd("Bdelete")

			assert.are.same(2, #vim.api.nvim_tabpage_list_wins(0))
			assert.is_false(vim.api.nvim_buf_is_loaded(buf1))
			assert.are.same(0, vim.fn.buflisted(buf1))

			vim.cmd("silent! only!")
			pcall(vim.api.nvim_buf_delete, buf1, { force = true })
			pcall(vim.api.nvim_buf_delete, buf2, { force = true })
		end
	)

	it("given two buffers in a vertical split, when executing native :bdelete, then the split window closes", function()
		local cbuf1 = vim.api.nvim_create_buf(true, false)
		local cbuf2 = vim.api.nvim_create_buf(true, false)
		local cwin1 = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(cwin1, cbuf1)
		vim.cmd("vsplit")
		local cwin2 = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(cwin2, cbuf2)
		assert.are.same(2, #vim.api.nvim_tabpage_list_wins(0))

		vim.api.nvim_set_current_win(cwin1)
		vim.cmd("bdelete")

		assert.are.same(1, #vim.api.nvim_tabpage_list_wins(0))
		pcall(vim.api.nvim_buf_delete, cbuf1, { force = true })
		pcall(vim.api.nvim_buf_delete, cbuf2, { force = true })
	end)
end)

describe("copilot keymaps and collision protection", function()
	before_each(function()
		vim.api.nvim_exec_autocmds("InsertEnter", {})
	end)

	it(
		"given InsertEnter fired, when inspecting insert mode mappings, then Copilot Meta shortcuts are registered",
		function()
			local map_accept = vim.fn.maparg("<M-\\>", "i", false, true)
			assert.is_not_nil(map_accept)
			assert.are.same(1, map_accept.expr)
			assert.matches("copilot#Accept", map_accept.rhs, 1, true)

			local map_next = vim.fn.maparg("<M-]>", "i", false, true)
			assert.is_not_nil(map_next)
			assert.are.same("<Plug>(copilot-next)", map_next.rhs)

			local map_prev = vim.fn.maparg("<M-[>", "i", false, true)
			assert.is_not_nil(map_prev)
			assert.are.same("<Plug>(copilot-previous)", map_prev.rhs)

			local map_dismiss = vim.fn.maparg("<M-w>", "i", false, true)
			assert.is_not_nil(map_dismiss)
			assert.are.same("<Plug>(copilot-dismiss)", map_dismiss.rhs)
		end
	)

	it(
		"given InsertEnter fired, when inspecting <C-c>, <C-j>, and <C-k>, then they are not hijacked by Copilot",
		function()
			local protected_keys = { "<C-c>", "<C-j>", "<C-k>" }
			for _, key in ipairs(protected_keys) do
				local map_info = vim.fn.maparg(key, "i", false, true)
				local rhs = map_info and map_info.rhs or ""
				local desc = map_info and map_info.desc or ""
				assert.has_no.match("copilot", rhs, 1, true, "Key " .. key .. " is mapped to Copilot rhs: " .. rhs)
				assert.falsy(string.find(desc, "Copilot", 1, true), "Key " .. key .. " has Copilot desc: " .. desc)
			end
		end
	)
end)

describe("dap runtime keymaps & lifecycle (zero-mock real plugins)", function()
	after_each(function()
		require("dapui").close()
		vim.cmd("silent! only!")
	end)

	it(
		"given Neovim with DAP loaded, when inspecting normal mode mappings, then all DAP keymaps are registered",
		function()
			local dap = require("dap")
			local dapui = require("dapui")
			local dap_python = require("dap-python")

			local direct_mappings = {
				{ lhs = "<leader>dc", expected_fn = dap.continue, desc = "Debug: Continue" },
				{ lhs = "<leader>do", expected_fn = dap.step_over, desc = "Debug: Step Over" },
				{ lhs = "<leader>di", expected_fn = dap.step_into, desc = "Debug: Step Into" },
				{ lhs = "<leader>du", expected_fn = dap.step_out, desc = "Debug: Step Out" },
				{ lhs = "<leader>db", expected_fn = dap.toggle_breakpoint, desc = "Debug: Toggle Breakpoint" },
				{ lhs = "<leader>dt", expected_fn = dap.terminate, desc = "Debug: Terminate" },
				{ lhs = "<leader>dr", expected_fn = dap.clear_breakpoints, desc = "Debug: Clear Breakpoints" },
				{ lhs = "<leader>dm", expected_fn = dapui.toggle, desc = "Debug: Toggle UI" },
				{ lhs = "<leader>dx", expected_fn = dap_python.test_method, desc = "Debug: Test Method" },
			}

			for _, mapping in ipairs(direct_mappings) do
				local map_info = vim.fn.maparg(mapping.lhs, "n", false, true)
				assert.is_not_nil(map_info, "Mapping not found for " .. mapping.lhs)
				assert.are.equal(
					mapping.expected_fn,
					map_info.callback,
					"Expected direct function reference equality for " .. mapping.lhs
				)
				assert.are.equal(mapping.desc, map_info.desc, "Expected matching desc for " .. mapping.lhs)
			end

			local closure_mappings = {
				{ lhs = "<leader>dk", desc = "Debug: Conditional Breakpoint" },
				{ lhs = "<leader>df", desc = "Debug: Float Element" },
			}

			for _, mapping in ipairs(closure_mappings) do
				local map_info = vim.fn.maparg(mapping.lhs, "n", false, true)
				assert.is_not_nil(map_info, "Mapping not found for " .. mapping.lhs)
				assert.are.equal("function", type(map_info.callback), "Expected callback function for " .. mapping.lhs)
				assert.are.equal(mapping.desc, map_info.desc, "Expected matching desc for " .. mapping.lhs)
			end
		end
	)

	it(
		"given a single-window layout with DAP listeners, when event_initialized fires, then dapui opens additional windows",
		function()
			local dap = require("dap")
			assert.are.same(1, #vim.api.nvim_tabpage_list_wins(0))

			dap.listeners.after.event_initialized["dapui_config"]()

			assert.is_true(#vim.api.nvim_tabpage_list_wins(0) > 1)
		end
	)

	it("given an open dapui layout, when event_terminated fires, then only one window remains", function()
		local dap = require("dap")
		require("dapui").open()
		assert.is_true(#vim.api.nvim_tabpage_list_wins(0) > 1)

		dap.listeners.before.event_terminated["dapui_config"]()

		assert.are.same(1, #vim.api.nvim_tabpage_list_wins(0))
	end)

	it("given an open dapui layout, when event_exited fires, then only one window remains", function()
		local dap = require("dap")
		require("dapui").open()
		assert.is_true(#vim.api.nvim_tabpage_list_wins(0) > 1)

		dap.listeners.before.event_exited["dapui_config"]()

		assert.are.same(1, #vim.api.nvim_tabpage_list_wins(0))
	end)

	it("given a 100x50 screen, when calculating float dimensions, then they are 90% of the screen", function()
		local dap = require("plugins.dap")
		assert.are.same({ width = 90, height = 45 }, dap.get_float_dimensions(100, 50))
	end)

	it("given a 105x53 screen, when calculating float dimensions, then odd 90% dimensions are floored", function()
		local dap = require("plugins.dap")
		assert.are.same({ width = 94, height = 47 }, dap.get_float_dimensions(105, 53))
	end)

	it("given a 10x10 screen, when calculating float dimensions, then they are 90% of the screen", function()
		local dap = require("plugins.dap")
		assert.are.same({ width = 9, height = 9 }, dap.get_float_dimensions(10, 10))
	end)
end)
