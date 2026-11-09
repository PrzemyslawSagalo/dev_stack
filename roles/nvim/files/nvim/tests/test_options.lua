local M = {}

function M.run()
	-- 1. Core Options Verification
	assert(vim.opt.undofile:get() == true, "Expected vim.opt.undofile to be true")
	assert(vim.opt.swapfile:get() == false, "Expected vim.opt.swapfile to be false")
	assert(vim.opt.signcolumn:get() == "yes", "Expected vim.opt.signcolumn to be 'yes'")
	assert(vim.opt.termguicolors:get() == true, "Expected vim.opt.termguicolors to be true")

	-- 2. Behavioral Test: Persistent Undo across Buffer Reloads (undofile)
	local tmp = vim.fn.tempname()
	local ok, err = pcall(function()
		-- Step A: Create initial file content
		local buf1 = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_set_current_buf(buf1)
		vim.cmd("silent! edit! " .. vim.fn.fnameescape(tmp))
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "initial version line 1", "initial version line 2" })
		vim.cmd("silent! write!")

		-- Step B: Modify file in second revision
		vim.api.nvim_buf_set_lines(0, -1, -1, false, { "appended modification" })
		vim.cmd("silent! write!")

		-- Step C: Wipe buffer to simulate session exit
		vim.cmd("silent! bdelete!")

		-- Step D: Open file again and invoke undo
		local buf2 = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_set_current_buf(buf2)
		vim.cmd("silent! edit! " .. vim.fn.fnameescape(tmp))

		local lines_before_undo = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		assert(#lines_before_undo == 3, "Expected 3 lines before undo")

		-- Execute undo
		vim.cmd("silent! undo")

		local lines_after_undo = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		assert(#lines_after_undo == 2, "Expected 2 lines after undoing modification across sessions")
		assert(lines_after_undo[1] == "initial version line 1", "Undo failed to restore initial line 1")
		assert(lines_after_undo[2] == "initial version line 2", "Undo failed to restore initial line 2")

		-- Clean up buffer
		vim.cmd("silent! bdelete!")
	end)

	-- Always remove temp file
	if vim.fn.filereadable(tmp) == 1 then
		vim.fn.delete(tmp)
	end

	-- Also clean up associated undo file if created in undodir
	local undofiles = vim.fn.glob(vim.fn.stdpath("state") .. "/undo/*" .. vim.fn.fnamemodify(tmp, ":t") .. "*", false, true)
	for _, uf in ipairs(undofiles) do
		vim.fn.delete(uf)
	end

	if not ok then
		error("undofile behavioral test failed: " .. tostring(err))
	end

	-- 3. Behavioral Test: Treesitter / :help Command Execution
	local help_ok, help_err = pcall(function()
		vim.cmd("silent! help autoread")
		assert(vim.bo.buftype == "help", "Expected buftype to be 'help'")
		local line_count = vim.api.nvim_buf_line_count(0)
		assert(line_count > 0, "Expected help buffer to contain lines")
		vim.cmd("silent! helpclose")
	end)

	if not help_ok then
		error("Treesitter help buffer validation failed: " .. tostring(help_err))
	end
end

return M
