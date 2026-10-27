return {
    {
        "williamboman/mason.nvim",
        lazy = false,
        config = function() require("mason").setup() end
    },
    {
        'neovim/nvim-lspconfig',
        dependencies = {
            "ray-x/lsp_signature.nvim"
        },
        keys = {
            { "<leader>gl", function() vim.diagnostic.open_float() end, desc = "Show diagnostic details" },
            { "<leader>ca", function() vim.lsp.buf.code_action() end, desc = "LSP Code Action" },
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

            local servers = { "marksman", "bashls", "clangd", "lua_ls", "ruff" }

            -- Configure and enable servers using modern Neovim 0.11+ / 0.12+ API
            if vim.lsp and vim.lsp.enable and vim.lsp.config then
                vim.lsp.config("*", default_server_config)
                for _, server in ipairs(servers) do
                    vim.lsp.config(server, default_server_config)
                    vim.lsp.enable(server)
                end
            else
                local lspconfig = require("lspconfig")
                lspconfig.util.default_config = vim.tbl_deep_extend("force", lspconfig.util.default_config, default_server_config)
                for _, server in ipairs(servers) do
                    lspconfig[server].setup(default_server_config)
                end
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
        end
    },
    {
        'williamboman/mason-lspconfig.nvim',
        lazy = false,
        dependencies = {
            "williamboman/mason.nvim",
            "neovim/nvim-lspconfig",
        },
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = { "marksman", "bashls", "clangd", "lua_ls", "ruff" },
                automatic_installation = true,
            })
        end
    },
}
