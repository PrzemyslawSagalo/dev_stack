return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main", -- STRICTLY for Nvim v0.12+
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local install = require("nvim-treesitter.install")
      
      -- Force build using system tools
      install.prefer_git = true
      install.compilers = { "gcc" }

      require("nvim-treesitter").setup({
        ensure_installed = {
          "bash",
          "c",
          "cpp",
          "json",
          "lua",
          "make",
          "python",
          "rst",
          "yaml",
        },
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = {
          enable = true,
        },
      })
    end,
  },
}
