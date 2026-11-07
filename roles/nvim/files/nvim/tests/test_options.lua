local M = {}

function M.run()
	-- 1. Core Options
	assert(vim.opt.autoread:get() == true, "Expected vim.opt.autoread to be true")
	local ut = vim.opt.updatetime:get()
	assert(ut == 200 or ut == 1, "Expected vim.opt.updatetime to be 200 (or 1 in -l runner), got: " .. tostring(ut))
	assert(vim.opt.undofile:get() == true, "Expected vim.opt.undofile to be true")
	assert(vim.opt.swapfile:get() == false, "Expected vim.opt.swapfile to be false")
	assert(vim.opt.signcolumn:get() == "yes", "Expected vim.opt.signcolumn to be 'yes'")
	assert(vim.opt.termguicolors:get() == true, "Expected vim.opt.termguicolors to be true")
	assert(vim.opt.clipboard:get()[1] == "unnamedplus", "Expected vim.opt.clipboard to contain 'unnamedplus'")

	-- 2. Clipboard Configuration
	assert(vim.g.clipboard ~= nil, "Expected vim.g.clipboard to be defined")
	assert(vim.g.clipboard.name == "OSC 52", "Expected vim.g.clipboard.name to be 'OSC 52'")
	assert(type(vim.g.clipboard.copy["+"]) == "function", "Expected copy['+'] provider to be a function")
	assert(type(vim.g.clipboard.paste["+"]) == "function", "Expected paste['+'] provider to be a function")

	-- 3. Autocmd Groups
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

	-- 4. Custom User Commands
	local commands = vim.api.nvim_get_commands({})
	assert(commands["DiffOrig"] ~= nil, "Expected ':DiffOrig' user command to be registered")
end

return M
