return {
    "folke/ts-comments.nvim",
    opts = {},
    event = "VeryLazy",
    enabled = vim.fn.has("nvim-0.10.0") == 1,
    keys = {
        { "<leader>cc", "gcc", mode = "n", remap = true, desc = "Toggle comment line" },
        { "<leader>cc", "gc",  mode = "x", remap = true, desc = "Toggle comment selection" },
    },
}
