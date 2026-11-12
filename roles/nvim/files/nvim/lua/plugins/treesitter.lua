local languages = require("config.languages")

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "master",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			local install = require("nvim-treesitter.install")

			-- Force build using system tools
			install.prefer_git = true
			install.compilers = { "gcc" }

			require("nvim-treesitter.configs").setup({
				ensure_installed = languages.treesitter,
				sync_install = false,
				auto_install = false,
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
