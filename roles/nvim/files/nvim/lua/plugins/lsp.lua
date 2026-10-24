return {
    {
        "williamboman/mason.nvim",
        config = function() require("mason").setup() end
    },
    { 'williamboman/mason-lspconfig.nvim' },
    {
        'neovim/nvim-lspconfig',
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "ray-x/lsp_signature.nvim"
        },
        keys = {
            { "<leader>gl", function() vim.diagnostic.open_float() end, desc = "Show diagnostic details" },
            { "<leader>ca", function() vim.lsp.buf.code_action() end, desc = "LSP Code Action" },
        },
        config = function()
local lspconfig = require("lspconfig")

local mason_lspconfig = require("mason-lspconfig")

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

-- Ensure capabilities and on_attach apply regardless of mason-lspconfig version
lspconfig.util.default_config = vim.tbl_deep_extend("force", lspconfig.util.default_config, default_server_config)

if vim.lsp and vim.lsp.config then
    pcall(vim.lsp.config, "*", default_server_config)
end

mason_lspconfig.setup({
    ensure_installed = {
        "marksman",
        "bashls",
        "clangd",
        "lua_ls",
        "ruff",
    },
    handlers = {
        function(server_name)
            lspconfig[server_name].setup(default_server_config)
        end,
    },
})

for _, server in ipairs({ "marksman", "bashls", "clangd", "lua_ls", "ruff" }) do
    lspconfig[server].setup(default_server_config)
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
    }
}
