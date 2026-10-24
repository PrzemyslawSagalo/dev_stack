local function assert_nil(a, msg)
    if a ~= nil then error(msg .. ": expected nil, got " .. tostring(a)) end
end

local function assert_not_nil(a, msg)
    if a == nil then error(msg .. ": expected not nil") end
end

local function assert_eq(a, b, msg)
    if a ~= b then error(msg .. ": expected " .. tostring(b) .. ", got " .. tostring(a)) end
end

local function test_plugin(file, plugin_name, expected_keys)
    local specs = dofile(file)
    if specs.keys == nil and type(specs[1]) == "string" then
        -- It's a single plugin spec like leap.lua
        specs = {specs}
    elseif specs[1] and type(specs[1]) == "table" and type(specs[1][1]) == "string" then
        -- It's a list of plugin specs
    else
        -- Not sure
    end
    
    local target_spec = nil
    for _, spec in ipairs(specs) do
        if type(spec) == "table" and spec[1] == plugin_name then
            target_spec = spec
            break
        end
    end
    
    assert_not_nil(target_spec, "Could not find plugin " .. plugin_name .. " in " .. file)
    assert_nil(target_spec.lazy, plugin_name .. " should not have lazy explicitly set")
    
    if expected_keys then
        assert_not_nil(target_spec.keys, plugin_name .. " must have a keys table")
        local found = 0
        for _, k in ipairs(target_spec.keys) do found = found + 1 end
        assert_eq(found, expected_keys, plugin_name .. " keys count mismatch")
    end
    print("PASS: " .. plugin_name)
end

test_plugin("lua/plugins/lsp.lua", "neovim/nvim-lspconfig", 2)
test_plugin("lua/plugins/neotest.lua", "nvim-neotest/neotest", 6)
print("All extended lazy keys tests passed!")
