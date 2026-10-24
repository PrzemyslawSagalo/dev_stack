local function assert_nil(a, msg)
    if a ~= nil then
        error(msg .. ": expected nil, got " .. tostring(a))
    end
end

local function assert_eq(a, b, msg)
    if a ~= b then
        error(msg .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
    end
end

local function test_plugin(file, expected_keys)
    local spec = dofile(file)
    if spec[1] and type(spec[1]) == "table" then
        spec = spec[1]
    end
    
    -- Support either default lazy loading by keys (spec.lazy == nil) or explicit eager loading (spec.lazy == false)
    if spec.lazy ~= nil and spec.lazy ~= false then
        error(file .. " should not set lazy = true explicitly (should be lazy loaded by keys or eager)")
    end
    
    if expected_keys then
        if not spec.keys then
            error(file .. " must have a keys table")
        end
        local found = 0
        for _, k in ipairs(spec.keys) do
            found = found + 1
        end
        if found ~= expected_keys then
            error(file .. " expected " .. expected_keys .. " keys in table, found " .. found)
        end
    end
    print("PASS: " .. file)
end

local function run_tests()
    local success = true
    local function run(file, count)
        local status, err = pcall(test_plugin, file, count)
        if not status then
            print("FAIL: " .. file .. " - " .. tostring(err))
            success = false
        end
    end
    
    run("lua/plugins/telescope.lua", 3)
    run("lua/plugins/vim_tree.lua", 1)
    run("lua/plugins/aerial.lua", 1)
    run("lua/plugins/leap.lua", 3)
    run("lua/plugins/copilot.lua", 5)
    
    if not success then
        os.exit(1)
    end
    print("All tests passed!")
end

run_tests()
