-- tests/test_comment.lua
-- Test harness validating ts-comments plugin spec and <leader>cc toggle keymaps

local function assert_test(cond, msg)
    if not cond then
        io.stderr:write("FAIL: " .. msg .. "\n")
        os.exit(1)
    end
end

-- 1. Validate plugin specification file
local ok, spec = pcall(dofile, "lua/plugins/comment.lua")
assert_test(ok, "Failed to load lua/plugins/comment.lua: " .. tostring(spec))
assert_test(type(spec) == "table", "Plugin spec must return a table")
assert_test(spec[1] == "folke/ts-comments.nvim", "Expected folke/ts-comments.nvim repository")
assert_test(type(spec.opts) == "table", "Plugin spec must define opts table")
assert_test(type(spec.keys) == "table", "Plugin spec must define keys table")
assert_test(#spec.keys == 2, "Expected 2 key definitions in keys table")
assert_test(spec.enabled == true or spec.enabled == 1, "Plugin should be enabled on Neovim 0.10+")

-- Validate keys table mappings
local has_n_cc = false
local has_x_cc = false
for _, k in ipairs(spec.keys) do
    if k[1] == "<leader>cc" and k[2] == "gcc" and (k.mode == "n" or (type(k.mode) == "table" and vim.tbl_contains(k.mode, "n"))) then
        has_n_cc = true
    end
    if k[1] == "<leader>cc" and k[2] == "gc" and (k.mode == "x" or (type(k.mode) == "table" and vim.tbl_contains(k.mode, "x"))) then
        has_x_cc = true
    end
    -- Register keymaps for testing
    vim.keymap.set(k.mode, k[1], k[2], { remap = k.remap == true, desc = k.desc })
end
assert_test(has_n_cc, "Normal mode <leader>cc -> gcc not found in spec.keys")
assert_test(has_x_cc, "Visual mode <leader>cc -> gc not found in spec.keys")

-- Helper to feed keys synchronously in tests
local function feed(keys)
    local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
    vim.api.nvim_feedkeys(termcodes, "mx", false)
end

-- 2. Functional test: Normal mode line toggle (<leader>cc -> gcc)
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)
vim.bo[bufnr].filetype = "lua"
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "local a = 1", "local b = 2" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })

-- Toggle comment ON
feed("<leader>cc")
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert_test(lines[1] == "-- local a = 1", "Line 1 failed to comment with <leader>cc: " .. tostring(lines[1]))
assert_test(lines[2] == "local b = 2", "Line 2 was touched unexpectedly: " .. tostring(lines[2]))

-- Toggle comment OFF
feed("<leader>cc")
lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert_test(lines[1] == "local a = 1", "Line 1 failed to uncomment with <leader>cc: " .. tostring(lines[1]))

-- 3. Functional test: Visual mode range toggle (Vj<leader>cc -> gc)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "local x = 1",
    "    local y = 2",
    "local z = 3",
})
vim.api.nvim_win_set_cursor(0, { 1, 0 })

-- Select lines 1-2 in visual line mode and toggle comment ON
feed("Vj<leader>cc")
lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert_test(lines[1] == "-- local x = 1", "Line 1 failed visual comment: " .. tostring(lines[1]))
assert_test(lines[2] == "--     local y = 2", "Line 2 block comment alignment failed: " .. tostring(lines[2]))
assert_test(lines[3] == "local z = 3", "Line 3 should remain untouched: " .. tostring(lines[3]))

-- Select lines 1-2 and toggle comment OFF
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed("Vj<leader>cc")
lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert_test(lines[1] == "local x = 1", "Line 1 failed visual uncomment: " .. tostring(lines[1]))
assert_test(lines[2] == "    local y = 2", "Line 2 failed visual uncomment: " .. tostring(lines[2]))
assert_test(lines[3] == "local z = 3", "Line 3 should remain untouched: " .. tostring(lines[3]))

-- 4. Functional test: Native Groovy / Jenkinsfile filetype comment toggle
vim.bo[bufnr].filetype = "groovy"
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "pipeline {" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed("<leader>cc")
lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert_test(lines[1] == "// pipeline {", "Groovy comment failed: " .. tostring(lines[1]))
feed("<leader>cc")
lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert_test(lines[1] == "pipeline {", "Groovy uncomment failed: " .. tostring(lines[1]))

-- 5. Functional test: Python filetype comment toggle
vim.bo[bufnr].filetype = "python"
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "def hello():" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed("<leader>cc")
lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert_test(lines[1] == "# def hello():", "Python comment failed: " .. tostring(lines[1]))
feed("<leader>cc")
lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert_test(lines[1] == "def hello():", "Python uncomment failed: " .. tostring(lines[1]))

-- 6. Functional test: User marks preservation across <leader>cc
local mark_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(mark_buf)
vim.bo[mark_buf].filetype = "lua"
vim.api.nvim_buf_set_lines(mark_buf, 0, -1, false, { "line 1", "line 2", "line 3" })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd("mark a")
local mark_pos = vim.api.nvim_buf_get_mark(mark_buf, "a")
assert_test(mark_pos[1] == 2, "Failed to set mark 'a' on line 2")

-- Toggle comment with <leader>cc
feed("<leader>cc")
local mark_pos_after = vim.api.nvim_buf_get_mark(mark_buf, "a")
assert_test(mark_pos_after[1] == 2, "Mark 'a' was invalidated by <leader>cc: " .. tostring(mark_pos_after[1]))

print("All comment tests passed successfully!")
