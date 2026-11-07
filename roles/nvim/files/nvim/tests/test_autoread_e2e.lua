local M = {}

function M.run()
	-- Create isolated temporary file for E2E testing
	local tmpfile = vim.fn.tempname() .. "_autoread_test.txt"
	local f = io.open(tmpfile, "w")
	assert(f, "Failed to create temporary test file")
	f:write("Initial line 1\nInitial line 2\n")
	f:close()

	-- Scenario A: Unmodified buffer auto-reload
	-- 1. Open the temporary file in Neovim
	vim.cmd("edit " .. vim.fn.fnameescape(tmpfile))
	local bufnr = vim.api.nvim_get_current_buf()
	local initial_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	assert(initial_lines[1] == "Initial line 1", "Initial buffer line mismatch")
	assert(not vim.api.nvim_get_option_value("modified", { buf = bufnr }), "Fresh buffer should not be modified")

	-- 2. Simulate external modification on disk
	local f_ext = io.open(tmpfile, "w")
	assert(f_ext, "Failed to reopen temporary test file")
	f_ext:write("Externally modified line 1\nExternally modified line 2\n")
	f_ext:close()

	-- 3. Trigger checktime (as HyperFastAutoread does on FocusGained / CursorHold)
	vim.cmd("checktime")

	-- 4. Assert buffer reloaded external changes automatically without dirtying modified flag
	local reloaded_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	assert(
		reloaded_lines[1] == "Externally modified line 1",
		"Buffer failed to auto-reload on external file modification: " .. vim.inspect(reloaded_lines)
	)
	assert(
		not vim.api.nvim_get_option_value("modified", { buf = bufnr }),
		"Reloaded buffer should retain modified == false"
	)

	-- Scenario B: Modified buffer conflict protection & :DiffOrig
	-- 1. Modify buffer in-memory without saving
	vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "In-memory unsaved edit line 1" })
	assert(vim.api.nvim_get_option_value("modified", { buf = bufnr }), "Buffer must be marked modified")

	-- 2. Modify file again on disk externally
	local f_ext2 = io.open(tmpfile, "w")
	assert(f_ext2, "Failed to reopen temporary test file")
	f_ext2:write("Third disk change line 1\n")
	f_ext2:close()

	-- 3. Trigger checktime
	vim.cmd("checktime")

	-- 4. Assert in-memory unsaved changes are preserved (no silent overwrite!)
	local protected_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	assert(
		protected_lines[1] == "In-memory unsaved edit line 1",
		"Modified buffer was overwritten by external change!"
	)
	assert(vim.api.nvim_get_option_value("modified", { buf = bufnr }), "Buffer must remain modified")

	-- 5. Execute :DiffOrig command to compare unsaved buffer against on-disk state
	vim.cmd("DiffOrig")

	-- Assert diff split opened
	local cur_win = vim.api.nvim_get_current_win()
	assert(vim.wo[cur_win].diff == true, "Expected :DiffOrig to enable diff mode on window")

	-- Close diff scratch window and clean up
	vim.cmd("close")
	vim.cmd("bdelete! " .. bufnr)
	os.remove(tmpfile)
end

return M
