return {
    "rcarriga/nvim-dap-ui",
    dependencies = {
        "nvim-neotest/nvim-nio",
        "mfussenegger/nvim-dap",
        "mfussenegger/nvim-dap-python",
        "jay-babu/mason-nvim-dap.nvim",
        "theHamsta/nvim-dap-virtual-text"
    },
    config = function()
require("mason-nvim-dap").setup({
    ensure_installed = { "python", "kotlin" },
    automatic_installation = true,
})

local keymap = vim.keymap.set

local opts = {noremap = true, silent = true}

keymap('n', '<leader>dc', function() require('dap').continue() end, opts)
keymap('n', '<leader>do', function() require('dap').step_over() end, opts)
keymap('n', '<leader>di', function() require('dap').step_into() end, opts)
keymap('n', '<leader>du', function() require('dap').step_out() end, opts)
keymap('n', '<leader>db', function() require('dap').toggle_breakpoint() end, opts)
keymap('n', '<leader>dt', function() require('dap').terminate() end, opts)
keymap('n', '<leader>dk', function() require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, opts)
keymap('n', '<leader>dr', function() require('dap').clear_breakpoints() end, opts)
keymap('n', '<leader>dm', function() require('dapui').toggle() end, opts)
keymap('n', '<leader>dx', function() require('dap-python').test_method() end, opts)

-- Floating window
local screen_width = vim.o.columns
local screen_height = vim.o.lines
local floating_window_width = math.floor(screen_width * 0.9)
local floating_window_height = math.floor(screen_height * 0.9)
keymap('n', '<leader>df', function() require('dapui').float_element(nil, {width = floating_window_width, height = floating_window_height, enter = true, position = 'center'}) end, opts)

local dap, dapui = require("dap"), require("dapui")

dapui.setup({
    controls = {
        element = "repl",
        enabled = true
    },
    element_mappings = {},
    expand_lines = true,
    floating = {border = "single", mappings = {close = {"q", "<Esc>"}}},
    force_buffers = true,
    icons = {collapsed = "", current_frame = "", expanded = ""},
    layouts = {
        {
            elements = {
                {id = "watches", size = 0.5},
                {id = "scopes", size = 0.5}
            },
            position = "left",
            size = 40
        },
        {elements = {{id = "repl", size = 1}}, position = "bottom", size = 10}
    },
    mappings = {
        edit = "e",
        expand = {"<CR>", "<2-LeftMouse>"},
        open = "o",
        remove = "d",
        repl = "r",
        toggle = "t"
    },
    render = {indent = 1, max_value_lines = 100}
})

dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
end

    end
}
