return {
    'Wansmer/treesj',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
require('treesj').setup({
    -- It is turned off as I have a conflict with the navigation between windows
    use_default_keymaps = false 
})

    end
}
