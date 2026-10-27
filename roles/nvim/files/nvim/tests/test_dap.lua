package.path = "./lua/?/init.lua;./lua/?.lua;" .. package.path
local function assert_test(cond, msg)
    if not cond then
        print("FAIL: " .. msg)
        os.exit(1)
    end
end

local ok, err = pcall(function()
    dofile("init.lua")
end)
assert_test(ok, "Failed to load init.lua: " .. tostring(err))

-- Test 1: Global _G.load_project_dap_config is removed
assert_test(_G.load_project_dap_config == nil, "_G.load_project_dap_config should be nil")

-- Test 2: DAP autocommands exist in the expected group
local group_ok, autocmds = pcall(vim.api.nvim_get_autocmds, {group = "DapProjectConfig"})
assert_test(group_ok and #autocmds >= 2, "DapProjectConfig autocmds not found or fewer than 2")

-- Force load the dap UI plugin to test keymaps
-- We mock require to avoid loading actual plugin modules that might not be available in headless test
local old_require = require
_G.require = function(mod)
    if mod == "mason-nvim-dap" then return { setup = function() end } end
    if mod == "dap" then
        return {
            listeners = { after = { event_initialized = {} }, before = { event_terminated = {}, event_exited = {} } },
            continue = function() end,
            step_over = function() end,
            step_into = function() end,
            step_out = function() end,
            toggle_breakpoint = function() end,
            terminate = function() end,
            set_breakpoint = function() end,
            clear_breakpoints = function() end,
        }
    end
    if mod == "dapui" or mod == "dap-python" then
        return setmetatable({}, { __index = function() return function() end end })
    end
    return old_require(mod)
end

local dap_spec = old_require("plugins.dap")
if dap_spec.config then
    dap_spec.config()
end
_G.require = old_require

-- Test 3: Keymap for <leader>dc is a function, not a string
local dc_map = vim.fn.maparg("<leader>dc", "n", false, true)
assert_test(type(dc_map.callback) == "function", "<leader>dc callback is not a function. rhs is: " .. tostring(dc_map.rhs))

-- Test 4: Keymap for <leader>df is a function
local df_map = vim.fn.maparg("<leader>df", "n", false, true)
assert_test(type(df_map.callback) == "function", "<leader>df callback is not a function. rhs is: " .. tostring(df_map.rhs))

print("All DAP refactoring tests passed.")
