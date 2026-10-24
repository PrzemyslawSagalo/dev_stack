-- tests/test_difftastic.lua
-- Headless test harness & specification validation contract for difftastic.nvim

local function assert_true(cond, msg)
    if not cond then
        error(msg)
    end
end

local function safe_inspect(val)
    if type(vim) == "table" and type(vim.inspect) == "function" then
        return vim.inspect(val)
    end
    return tostring(val)
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(msg .. ": expected " .. safe_inspect(expected) .. ", got " .. safe_inspect(actual))
    end
end

local function resolve_spec_path()
    local default_path = "lua/plugins/difftastic.lua"
    local f = io.open(default_path, "r")
    if f then
        f:close()
        return default_path
    end

    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local script_path = info.source:sub(2)
        local script_dir = script_path:match("(.*/)") or "./"
        local relative_path = script_dir .. "../lua/plugins/difftastic.lua"
        local rf = io.open(relative_path, "r")
        if rf then
            rf:close()
            return relative_path
        end
    end

    return default_path
end

local function test_difftastic_spec()
    local file = resolve_spec_path()

    -- Load specification
    local ok, spec = pcall(dofile, file)
    if not ok then
        error("Failed to load " .. file .. ": " .. tostring(spec))
    end

    if spec[1] and type(spec[1]) == "table" then
        spec = spec[1]
    end

    -- Test 1: Plugin spec returns a valid table specification
    assert_true(type(spec) == "table", "Test 1 Failed: Plugin specification must return a table")
    assert_true(spec[1] ~= nil and type(spec[1]) == "string", "Test 1 Failed: Plugin spec[1] must specify repository name")
    assert_eq(spec[1], "clabby/difftastic.nvim", "Test 1 Failed: Repository must be 'clabby/difftastic.nvim'")

    -- Test 2: Implicit lazy loading compliance (spec.lazy must not be false)
    assert_true(spec.lazy ~= false, "Test 2 Failed: spec.lazy must not be explicitly false")

    -- Test 3: Module name resolution (spec.main == 'difftastic-nvim' to fix lazy.nvim module lookup)
    assert_eq(spec.main, "difftastic-nvim", "Test 3 Failed: spec.main must be 'difftastic-nvim'")

    -- Test 4: Dependencies validation
    assert_true(type(spec.dependencies) == "table", "Test 4 Failed: spec.dependencies must be a table")
    local dep_set = {}
    for _, dep in ipairs(spec.dependencies) do
        dep_set[dep] = true
    end
    assert_true(dep_set["MunifTanjim/nui.nvim"] == true, "Test 4 Failed: Missing dependency MunifTanjim/nui.nvim")
    assert_true(dep_set["folke/snacks.nvim"] == true, "Test 4 Failed: Missing dependency folke/snacks.nvim")

    -- Test 5: Keys table validation
    assert_true(type(spec.keys) == "table", "Test 5 Failed: spec.keys must be a table")

    local expected_keys = {
        ["<leader>gd"] = { cmd = ":Difft<CR>", silent_check = false },
        ["<leader>gs"] = { cmd = ":Difft --staged<CR>", silent_check = false },
        ["<leader>gp"] = { cmd = ":DifftPick<CR>", silent_check = false },
        ["<leader>gb"] = { cmd = ":<C-u>Difft ", silent_check = true, silent_val = false },
        ["<leader>gq"] = { cmd = ":DifftClose<CR>", silent_check = false },
    }

    local found_keys = {}
    for _, k in ipairs(spec.keys) do
        local key = k[1]
        if key then
            found_keys[key] = k
            assert_true(type(k.desc) == "string" and k.desc ~= "",
                "Test 5 Failed: Keymap " .. key .. " must have a non-empty desc")
            if expected_keys[key] and expected_keys[key].cmd then
                assert_eq(k[2], expected_keys[key].cmd,
                    "Test 5 Failed: Keymap " .. key .. " command mismatch")
            end
        end
    end

    for req_key, opts in pairs(expected_keys) do
        assert_true(found_keys[req_key] ~= nil, "Test 5 Failed: Missing required keymap: " .. req_key)
        if opts.silent_check then
            assert_true(found_keys[req_key].silent == opts.silent_val,
                "Test 5 Failed: Keymap " .. req_key .. " must have silent = false")
        end
    end

    -- Test 6: Commands and options validation
    assert_true(type(spec.cmd) == "table", "Test 6 Failed: spec.cmd must be a table")
    local expected_cmds = { "Difft", "DifftClose", "DifftPick", "DifftPickRange", "DifftUpdate" }
    local cmd_set = {}
    for _, cmd in ipairs(spec.cmd) do
        cmd_set[cmd] = true
    end
    for _, req_cmd in ipairs(expected_cmds) do
        assert_true(cmd_set[req_cmd] == true, "Test 6 Failed: Missing required command in spec.cmd: " .. req_cmd)
    end

    assert_true(type(spec.opts) == "table", "Test 6 Failed: spec.opts must be a table")
    assert_eq(spec.opts.download, true, "Test 6 Failed: spec.opts.download must be true")
    assert_eq(spec.opts.vcs, "git", "Test 6 Failed: spec.opts.vcs must be 'git'")
    assert_true(type(spec.opts.snacks_picker) == "table", "Test 6 Failed: spec.opts.snacks_picker must be a table")
    assert_eq(spec.opts.snacks_picker.enabled, true, "Test 6 Failed: spec.opts.snacks_picker.enabled must be true")

    print("PASS: difftastic spec validation passed")
end

local function run_tests()
    local ok, err = pcall(test_difftastic_spec)
    if not ok then
        io.stderr:write("FAIL: tests/test_difftastic.lua - " .. tostring(err) .. "\n")
        os.exit(1)
    end
    print("All Difftastic specification tests passed!")
    os.exit(0)
end

run_tests()
