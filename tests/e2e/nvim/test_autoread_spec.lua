describe("AI agent external modification - FileChangedShell autocmds", function()
	local filepath
	local buf

	before_each(function()
		-- Place test file in cache directory (rather than /tmp) to verify persistent undo behavior
		-- without hitting ephemeral UndoFilter
		filepath = vim.fn.stdpath("cache")
			.. "/test_autoread_"
			.. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
			.. "_"
			.. tostring(vim.uv.hrtime())
			.. ".txt"
		buf = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_set_current_buf(buf)
		vim.cmd("silent! edit! " .. vim.fn.fnameescape(filepath))
	end)

	after_each(function()
		if buf and vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		if filepath then
			pcall(os.remove, filepath)
			local undo_pattern = vim.fn.stdpath("state") .. "/undo/*" .. vim.fn.fnamemodify(filepath, ":t") .. "*"
			local undofiles = vim.fn.glob(undo_pattern, false, true)
			for _, undo_path in ipairs(undofiles) do
				pcall(os.remove, undo_path)
			end
		end
	end)

	it("Scenario A: reloads file after external AI agent modification and preserves undo history", function()
		-- Step 1: Initial version written to disk
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "function v1" })
		vim.cmd("silent! write!")

		-- Step 2: User edit building undo history
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "function v2" })
		vim.cmd("silent! write!")

		-- Step 3: External modification by AI agent (bypassing Neovim buffer)
		-- Slight sleep ensures filesystem mtime delta
		vim.uv.sleep(50)
		local f = assert(io.open(filepath, "w"))
		f:write("function v3 - from AI agent\n")
		f:close()

		-- Step 4: Event trigger (simulating returning to terminal or cursor idle)
		vim.api.nvim_exec_autocmds("FocusGained", {})
		vim.cmd("checktime")

		-- Step 5: Reload assertion (buffer automatically updated to AI version without prompting)
		local lines_after_reload = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		assert.are.same({ "function v3 - from AI agent" }, lines_after_reload)

		-- Step 6: Undo history assertion (user rejects AI changes)
		vim.cmd("silent! undo")
		local lines_after_undo = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		assert.are.same({ "function v2" }, lines_after_undo)
	end)

	it("Scenario B: data loss protection (blocks reload when buffer has unsaved user changes)", function()
		-- Initialize file on disk
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "baseline state" })
		vim.cmd("silent! write!")

		-- Step 1: User introduces unsaved modifications into buffer
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "my critically important unsaved changes" })
		assert.is_true(vim.bo[buf].modified)

		-- Step 2: AI agent modifies file on disk concurrently
		vim.uv.sleep(50)
		local f = assert(io.open(filepath, "w"))
		f:write("agent code attempting to overwrite user work\n")
		f:close()

		-- Step 3: Trigger checktime check
		-- Use pcall because in headless environment, "ask" prompt would raise prompt error
		pcall(function()
			vim.cmd("checktime")
		end)

		-- Step 4: Protection assertion
		-- Buffer MUST NOT be reloaded; it must preserve user's unsaved changes
		local protected_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		assert.are.same({ "my critically important unsaved changes" }, protected_lines)

		-- Verify modified flag still protects buffer
		assert.is_true(vim.bo[buf].modified)
	end)
end)
