local python_utils = require("utils.python_utils")

return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-neotest/neotest-python",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      local neotest = require("neotest")

      neotest.setup({
        status = { virtual_text = true },
        output = { open_on_run = true },
        adapters = {
          require("neotest-python")({
            runner = "pytest",
            python = python_utils.python_interpreter_path(),
            dap = { justMyCode = false },
          }),
        },
      })
    end,
    keys = {
      {
        "<leader>tc",
        function()
          require("neotest").run.run()
        end,
        desc = "Run Nearest",
      },
      {
        "<leader>tf",
        function()
          require("neotest").run.run(vim.fn.expand("%"))
        end,
        desc = "Run File",
      },
      {
        "<leader>ta",
        function()
          require("neotest").run.run(vim.fn.expand("."))
        end,
        desc = "Run All Test Files",
      },
      {
        "<leader>td",
        function()
          require("neotest").run.run({ strategy = "dap" })
        end,
        desc = "Debug Nearest",
      },
      {
        "<leader>ts",
        function()
          require("neotest").run.stop()
        end,
        desc = "Stop",
      },
      {
        "<leader>tm",
        function()
          require("neotest").summary.toggle()
          require("neotest").output_panel.toggle()
        end,
        desc = "Toggle Summary & Output Panel",
      },
    },
  },
}
