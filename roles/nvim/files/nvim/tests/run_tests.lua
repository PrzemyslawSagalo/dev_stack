-- Headless Neovim Test Runner for dev_stack
local test_modules = {
	"roles.nvim.files.nvim.tests.test_options",
	"roles.nvim.files.nvim.tests.test_keymaps",
	"roles.nvim.files.nvim.tests.test_autoread_e2e",
	"roles.nvim.files.nvim.tests.test_clipboard",
}

-- Also support local require relative to tests directory
package.path = package.path .. ";roles/nvim/files/nvim/tests/?.lua;tests/?.lua"

print("==================================================")
print("Running Neovim Headless Behavioral Test Suite")
print("==================================================")

local passed = 0
local failed = 0
local errors = {}

for _, mod_name in ipairs(test_modules) do
	local short_name = mod_name:match("[^.]+$")
	io.write(string.format("  -> Running %-30s ... ", short_name))
	io.flush()

	local ok, mod_or_err = pcall(require, mod_name)
	if not ok then
		-- Fallback to short name if package path differs
		ok, mod_or_err = pcall(require, short_name)
	end

	if not ok then
		io.write("FAIL (load error)\n")
		failed = failed + 1
		table.insert(errors, { name = short_name, err = mod_or_err })
	else
		local run_ok, run_err = pcall(mod_or_err.run)
		if run_ok then
			io.write("PASS\n")
			passed = passed + 1
		else
			io.write("FAIL\n")
			failed = failed + 1
			table.insert(errors, { name = short_name, err = run_err })
		end
	end
end

print("--------------------------------------------------")
print(string.format("Results: %d passed, %d failed", passed, failed))
print("==================================================")

if failed > 0 then
	print("\nFailures:")
	for _, f in ipairs(errors) do
		print(string.format("\n[%s]:\n%s", f.name, tostring(f.err)))
	end
	os.exit(1)
else
	print("All tests passed successfully.")
	os.exit(0)
end
