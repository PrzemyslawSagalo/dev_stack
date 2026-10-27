return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope-live-grep-args.nvim"
    },
    keys = {
        { '<leader>ff', function() require('telescope.builtin').find_files() end, desc = 'It searches for files in the current working directory' },
        { '<leader>fa', function()
            require('telescope.builtin').find_files({
                no_ignore = true, -- Don't respect .gitignore
                hidden = true,    -- Show hidden files (dotfiles)
            })
        end, desc = 'As same as ff but search also in .* files' },
        { '<leader>fg', function()
            require('telescope').extensions.live_grep_args.live_grep_args()
        end, desc = 'Project Search (Grep)' },
    },
    config = function()

-- Load extensions
require("telescope").load_extension("live_grep_args")

    end
}
