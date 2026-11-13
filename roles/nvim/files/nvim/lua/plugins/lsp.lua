local languages = require("config.languages")

return {
	{
		"williamboman/mason.nvim",
		lazy = false,
		config = function()
			require("mason").setup()
		end,
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"ray-x/lsp_signature.nvim",
		},
		keys = {
			{
				"<leader>gl",
				function()
					vim.diagnostic.open_float()
				end,
				desc = "Show diagnostic details",
			},
			{
				"<leader>ca",
				function()
					vim.lsp.buf.code_action()
				end,
				desc = "LSP Code Action",
			},
		},
		config = function()
			local cmp_nvim_lsp = require("cmp_nvim_lsp")

			local lsp_capabilities = cmp_nvim_lsp.default_capabilities()

			local on_attach = function(client, bufnr)
				local lsp_signature = require("lsp_signature")
				lsp_signature.on_attach()
			end

			local default_server_config = {
				capabilities = lsp_capabilities,
				on_attach = on_attach,
			}

			-- Configure and enable servers using modern Neovim 0.11+ / 0.12+ API
			vim.lsp.config("*", default_server_config)
			for _, server in ipairs(languages.lsp) do
				local server_config = vim.tbl_deep_extend(
					"force",
					default_server_config,
					(languages.lsp_configs and languages.lsp_configs[server]) or {}
				)
				vim.lsp.config(server, server_config)
				vim.lsp.enable(server)
			end

			vim.diagnostic.config({
				virtual_text = {
					severity = { min = vim.diagnostic.severity.HINT },
				},
				signs = {
					severity = { min = vim.diagnostic.severity.HINT },
				},
				underline = true,
				update_in_insert = false,
				severity_sort = true,
			})

			vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", { fg = "#808080", undercurl = true, default = true })
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		lazy = false,
		dependencies = {
			"williamboman/mason.nvim",
			"neovim/nvim-lspconfig",
		},
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = languages.lsp,
				automatic_installation = true,
			})
		end,
	},
}
