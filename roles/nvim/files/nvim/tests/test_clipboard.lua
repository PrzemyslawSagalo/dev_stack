local M = {}

function M.run()
	-- 1. Assert Clipboard Configuration
	assert(vim.g.clipboard ~= nil, "Expected vim.g.clipboard to be defined")
	assert(vim.g.clipboard.name == "OSC 52", "Expected clipboard provider name to be 'OSC 52'")
	assert(vim.opt.clipboard:get()[1] == "unnamedplus", "Expected vim.opt.clipboard to contain 'unnamedplus'")

	-- 2. Assert Provider Functions Exist
	local copy_plus = vim.g.clipboard.copy["+"]
	local copy_star = vim.g.clipboard.copy["*"]
	local paste_plus = vim.g.clipboard.paste["+"]
	local paste_star = vim.g.clipboard.paste["*"]

	assert(type(copy_plus) == "function", "Expected copy['+'] to be a function")
	assert(type(copy_star) == "function", "Expected copy['*'] to be a function")
	assert(type(paste_plus) == "function", "Expected paste['+'] to be a function")
	assert(type(paste_star) == "function", "Expected paste['*'] to be a function")

	-- 3. Assert Copy Function Executes Cleanly (emits OSC 52 sequence without throwing)
	local test_token = "OSC52_TEST_TOKEN_" .. tostring(os.time())
	local ok, err = pcall(copy_plus, { test_token })
	assert(ok, "copy['+'] failed to execute: " .. tostring(err))

	local ok_star, err_star = pcall(copy_star, { test_token })
	assert(ok_star, "copy['*'] failed to execute: " .. tostring(err_star))
end

return M
