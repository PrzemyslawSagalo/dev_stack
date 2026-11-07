-- Headless Neovim Test Runner for dev_stack

-- Resolve directory containing run_tests.lua dynamically
local source_path = debug.getinfo(1, "S").source:sub(2)
local test_dir = vim.fn.fnamemodify(source_path, ":h")
package.path = test_dir .. "/?.lua;" .. package.path

local test_modules = {
	"test_options",
	"test_keymaps",
	"test_autoread_e2e",
	"test_clipboard",
}

io.stdout:write("==================================================\n")
io.stdout:write("Running Neovim Headless Behavioral Test Suite\n")
io.stdout:write("==================================================\n")

local passed = 0
local failed = 0
local errors = {}

for _, mod_name in ipairs(test_modules) do
	io.stdout:write(string.format("  -> Running %-30s ... ", mod_name))
	io.stdout:flush()

	local ok, mod_or_err = pcall(require, mod_name)
	if not ok then
		io.stdout:write("FAIL (load error)\n")
		failed = failed + 1
		table.insert(errors, { name = mod_name, err = mod_or_err })
	else
		-- Clean buffer state before each spec
		vim.cmd("silent! %bdelete!")

		local run_ok, run_err = pcall(mod_or_err.run)
		if run_ok then
			io.stdout:write("PASS\n")
			passed = passed + 1
		else
			io.stdout:write("FAIL\n")
			failed = failed + 1
			table.insert(errors, { name = mod_name, err = run_err })
		end
	end
end

io.stdout:write("--------------------------------------------------\n")
io.stdout:write(string.format("Results: %d passed, %d failed\n", passed, failed))
io.stdout:write("==================================================\n")

if failed > 0 then
	io.stdout:write("\nFailures:\n")
	for _, f in ipairs(errors) do
		io.stdout:write(string.format("\n[%s]:\n%s\n", f.name, tostring(f.err)))
	end
	os.exit(1)
else
	io.stdout:write("All tests passed successfully.\n")
	os.exit(0)
end
