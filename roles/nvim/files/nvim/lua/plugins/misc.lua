return {
    {"Pocco81/auto-save.nvim"},
    {"moll/vim-bbye"},
    {
        "folke/todo-comments.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function() require("todo-comments").setup() end
    },
    {
        'cameron-wags/rainbow_csv.nvim',
        config = true,
        ft = {
            'csv', 'tsv', 'csv_semicolon', 'csv_whitespace',
            'csv_pipe', 'rfc_csv', 'rfc_semicolon'
        },
        cmd = {
            'RainbowDelim', 'RainbowDelimSimple',
            'RainbowDelimQuoted', 'RainbowMultiDelim'
        }
    }
}
