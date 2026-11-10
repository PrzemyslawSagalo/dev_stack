local M = {
	"rcarriga/nvim-dap-ui",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"mfussenegger/nvim-dap",
		"mfussenegger/nvim-dap-python",
		"jay-babu/mason-nvim-dap.nvim",
		"theHamsta/nvim-dap-virtual-text",
	},
}

function M.get_float_dimensions(columns, lines)
	return {
		width = math.floor(columns * 0.9),
		height = math.floor(lines * 0.9),
	}
end

function M.config()
	local dap = require("dap")
	local dapui = require("dapui")
	local dap_python = require("dap-python")

	require("mason-nvim-dap").setup({
		ensure_installed = { "python", "kotlin", "codelldb" },
		automatic_installation = true,
		handlers = {},
	})

	require("nvim-dap-virtual-text").setup({})
	dap_python.setup("python3")

	local keymap = vim.keymap.set

	keymap("n", "<leader>dc", dap.continue, { desc = "Debug: Continue", silent = true })
	keymap("n", "<leader>do", dap.step_over, { desc = "Debug: Step Over", silent = true })
	keymap("n", "<leader>di", dap.step_into, { desc = "Debug: Step Into", silent = true })
	keymap("n", "<leader>du", dap.step_out, { desc = "Debug: Step Out", silent = true })
	keymap("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint", silent = true })
	keymap("n", "<leader>dt", dap.terminate, { desc = "Debug: Terminate", silent = true })
	keymap("n", "<leader>dk", function()
		dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
	end, { desc = "Debug: Conditional Breakpoint", silent = true })
	keymap("n", "<leader>dr", dap.clear_breakpoints, { desc = "Debug: Clear Breakpoints", silent = true })
	keymap("n", "<leader>dm", dapui.toggle, { desc = "Debug: Toggle UI", silent = true })
	keymap("n", "<leader>dx", dap_python.test_method, { desc = "Debug: Test Method", silent = true })

	keymap("n", "<leader>df", function()
		local dims = M.get_float_dimensions(vim.o.columns, vim.o.lines)
		dapui.float_element(nil, { width = dims.width, height = dims.height, enter = true, position = "center" })
	end, { desc = "Debug: Float Element", silent = true })

	dapui.setup({
		controls = {
			element = "repl",
			enabled = true,
		},
		element_mappings = {},
		expand_lines = true,
		floating = { border = "single", mappings = { close = { "q", "<Esc>" } } },
		force_buffers = true,
		icons = { collapsed = "", current_frame = "", expanded = "" },
		layouts = {
			{
				elements = {
					{ id = "scopes", size = 0.4 },
					{ id = "watches", size = 0.3 },
					{ id = "stacks", size = 0.3 },
				},
				position = "left",
				size = 40,
			},
			{ elements = { { id = "repl", size = 1 } }, position = "bottom", size = 10 },
		},
		mappings = {
			edit = "e",
			expand = { "<CR>", "<2-LeftMouse>" },
			open = "o",
			remove = "d",
			repl = "r",
			toggle = "t",
		},
		render = { indent = 1, max_value_lines = 100 },
	})

	dap.listeners.after.event_initialized["dapui_config"] = function()
		dapui.open()
	end
	dap.listeners.before.event_terminated["dapui_config"] = function()
		dapui.close()
	end
	dap.listeners.before.event_exited["dapui_config"] = function()
		dapui.close()
	end
end

return M
