local languages = require("config.languages")

vim.filetype.add(languages.filetypes)

for parser, fts in pairs(languages.treesitter_filetypes) do
	vim.treesitter.language.register(parser, fts)
end

return {
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		lazy = false,
		dependencies = {
			"williamboman/mason.nvim",
		},
		config = function()
			require("mason-tool-installer").setup({
				ensure_installed = languages.linters.mason_tools,
			})
		end,
	},
	{
		"mfussenegger/nvim-lint",
		lazy = false,
		config = function()
			local lint = require("lint")

			lint.linters_by_ft = languages.linters.by_ft

			local lint_augroup = vim.api.nvim_create_augroup("nvim_lint_auto", { clear = true })
			vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
				group = lint_augroup,
				callback = function()
					local names = lint._resolve_linter_by_ft(vim.bo.filetype)
					local available = vim.tbl_filter(function(name)
						local linter = lint.linters[name]
						if not linter then
							return false
						end
						local linter_def = type(linter) == "function" and linter() or linter
						local cmd = type(linter_def.cmd) == "function" and linter_def.cmd() or linter_def.cmd
						return cmd and vim.fn.executable(cmd) == 1
					end, names)

					if #available > 0 then
						lint.try_lint(available)
					end
				end,
			})
		end,
	},
}
