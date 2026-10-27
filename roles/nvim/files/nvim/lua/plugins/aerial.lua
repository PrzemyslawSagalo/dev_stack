return {
    'stevearc/aerial.nvim',
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-tree/nvim-web-devicons"
    },
    keys = {
        { "<leader>a", "<cmd>AerialToggle!<CR>", desc = "Toggle Aerial" },
    },
    config = function()
local aerial = require("aerial")

aerial.setup({
  -- Priority of backends. If one fails or isn't available, it moves to the next.
  -- Treesitter is currently having issues on Nvim 0.12 dev.
  backends = { "lsp", "treesitter", "markdown", "man" },
  on_attach = function(bufnr)
    vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
    vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
  end,
})

    end
}
