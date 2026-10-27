return {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
local colorscheme = "tokyonight"
local theme = "night"

local colorscheme_config = require("tokyonight")
colorscheme_config.setup({ style = "night" })
vim.cmd("colorscheme tokyonight")
    end,
}
