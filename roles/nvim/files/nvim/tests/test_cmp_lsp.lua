local function assert_test(cond, msg)
    if not cond then
        print("FAIL: " .. msg)
        os.exit(1)
    end
end

-- Force load lspconfig which triggers lazy to run its config block
local lspconfig_ok, lspconfig = pcall(require, "lspconfig")
assert_test(lspconfig_ok, "lspconfig plugin could not be required")

-- Now test cmp
local cmp_ok, cmp = pcall(require, "cmp")
assert_test(cmp_ok, "cmp plugin could not be required")
assert_test(package.loaded["cmp"], "cmp was not loaded into package.loaded")

-- Verify cmp has the correct sources configured
local config = cmp.get_config()
assert_test(config ~= nil, "cmp config should not be nil")
local has_nvim_lsp = false
local has_vsnip = false
local has_buffer = false

for _, source in ipairs(config.sources) do
    if source.name == "nvim_lsp" then has_nvim_lsp = true end
    if source.name == "vsnip" then has_vsnip = true end
    if source.name == "buffer" then has_buffer = true end
end

assert_test(has_nvim_lsp, "cmp missing nvim_lsp source")
assert_test(has_vsnip, "cmp missing vsnip source")
assert_test(has_buffer, "cmp missing buffer source")

-- Test 3: Require mason-lspconfig
local mason_lsp_ok, mason_lsp = pcall(require, "mason-lspconfig")
assert_test(mason_lsp_ok, "mason-lspconfig could not be required")

print("All CMP/LSP tests passed.")
