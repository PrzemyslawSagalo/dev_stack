local M = {}

function M.run()
	-- 1. Core Options
	assert(vim.opt.autoread:get() == true, "Expected vim.opt.autoread to be true")
	assert(vim.opt.undofile:get() == true, "Expected vim.opt.undofile to be true")
	assert(vim.opt.swapfile:get() == false, "Expected vim.opt.swapfile to be false")
	assert(vim.opt.signcolumn:get() == "yes", "Expected vim.opt.signcolumn to be 'yes'")
	assert(vim.opt.termguicolors:get() == true, "Expected vim.opt.termguicolors to be true")
	assert(vim.tbl_contains(vim.opt.clipboard:get(), "unnamedplus"), "Expected clipboard to contain 'unnamedplus'")

	-- 2. Autocmd Groups
	local autocmds = vim.api.nvim_get_autocmds({ group = "HyperFastAutoread" })
	assert(#autocmds > 0, "Expected 'HyperFastAutoread' augroup to contain registered autocmds")

	local events_found = {}
	for _, cmd in ipairs(autocmds) do
		events_found[cmd.event] = true
	end
	assert(events_found["FocusGained"], "Expected FocusGained in HyperFastAutoread")
	assert(events_found["BufEnter"], "Expected BufEnter in HyperFastAutoread")
	assert(events_found["CursorHold"], "Expected CursorHold in HyperFastAutoread")
	assert(events_found["FileChangedShell"], "Expected FileChangedShell in HyperFastAutoread")
	assert(events_found["FileChangedShellPost"], "Expected FileChangedShellPost in HyperFastAutoread")

	-- 3. Custom User Commands
	local commands = vim.api.nvim_get_commands({})
	assert(commands["DiffOrig"] ~= nil, "Expected ':DiffOrig' user command to be registered")
end

return M
