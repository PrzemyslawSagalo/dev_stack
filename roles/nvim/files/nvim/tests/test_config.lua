package.path = package.path .. ";./lua/?/init.lua;./lua/?.lua"
local function assert_test(cond, msg)
    if not cond then
        print("FAIL: " .. msg)
        os.exit(1)
    end
end

-- Load the main init.lua
local ok, err = pcall(function()
    dofile("init.lua")
end)
assert_test(ok, "Failed to load init.lua: " .. tostring(err))

-- Test 1: mapleader
assert_test(vim.g.mapleader == " ", "mapleader is not space")

-- Test 2: maplocalleader
assert_test(vim.g.maplocalleader == " ", "maplocalleader is not space")

-- Test 3: autoread autocmd
local ok, autocmds = pcall(vim.api.nvim_get_autocmds, {group = "HyperFastAutoread"})
assert_test(ok and #autocmds > 0, "HyperFastAutoread autocmds not found")

-- Test 4: dependencies structure
assert_test(package.loaded["core.globals"], "core.globals not loaded")
assert_test(package.loaded["core.autocmds"], "core.autocmds not loaded")
assert_test(package.loaded["core.vim_options"], "core.vim_options not loaded")
assert_test(package.loaded["core.general_keymaps"], "core.general_keymaps not loaded")

print("All config refactoring tests passed.")
