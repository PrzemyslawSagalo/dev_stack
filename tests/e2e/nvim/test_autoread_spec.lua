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
			vim.fs.rm(filepath, { force = true })
			vim.fs.rm(vim.fn.undofile(filepath), { force = true })
		end
	end)

	it(
		"given a saved file with undo history and an external edit, when FocusGained fires, then it reloads and undo works",
		function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "function v1" })
			vim.cmd("silent! write!")
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "function v2" })
			vim.cmd("silent! write!")

			vim.uv.sleep(50)
			local f = assert(io.open(filepath, "w"))
			f:write("function v3 - from AI agent\n")
			f:close()

			vim.api.nvim_exec_autocmds("FocusGained", {})
			vim.wait(100)

			local lines_after_reload = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.are.same({ "function v3 - from AI agent" }, lines_after_reload)

			vim.cmd("silent! undo")
			local lines_after_undo = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.are.same({ "function v2" }, lines_after_undo)
		end
	)

	it(
		"given unsaved changes and an external edit, when FocusGained fires, then unsaved changes are preserved",
		function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "baseline state" })
			vim.cmd("silent! write!")

			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "my critically important unsaved changes" })
			assert.is_true(vim.bo[buf].modified)

			vim.uv.sleep(50)
			local f = assert(io.open(filepath, "w"))
			f:write("agent code attempting to overwrite user work\n")
			f:close()

			vim.api.nvim_exec_autocmds("FocusGained", {})
			vim.wait(100)

			local protected_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.are.same({ "my critically important unsaved changes" }, protected_lines)
			assert.is_true(vim.bo[buf].modified)
		end
	)

	it(
		"given an unmodified buffer changed on disk, when executing :write, then buffer and disk have the external edit",
		function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "initial version" })
			vim.cmd("silent! write!")
			assert.is_false(vim.bo[buf].modified)

			local f = assert(io.open(filepath, "w"))
			f:write("external edit before write\n")
			f:close()
			local future_mtime = os.time() + 2
			assert.is_true(vim.uv.fs_utime(filepath, future_mtime, future_mtime))

			vim.cmd("write")

			assert.are.same({ "external edit before write" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
			assert.are.same({ "external edit before write" }, vim.fn.readfile(filepath))
		end
	)

	it(
		"given a background file buffer and a terminal, when TermClose fires, then the file buffer reloads unfocused",
		function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "before terminal command" })
			vim.cmd("silent! write!")

			vim.cmd("split")
			local term_buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(term_buf)
			local job_id = vim.fn.jobstart({ "cat" }, { term = true })
			vim.wait(50)

			local f = assert(io.open(filepath, "w"))
			f:write("modified by CLI inside terminal\n")
			f:close()
			local future_mtime = os.time() + 2
			assert.is_true(vim.uv.fs_utime(filepath, future_mtime, future_mtime))

			vim.wait(50)
			assert.are.same({ "before terminal command" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))

			vim.fn.jobstop(job_id)
			vim.wait(150, function()
				return vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == "modified by CLI inside terminal"
			end, 10)

			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			vim.cmd("only")
			vim.api.nvim_buf_delete(term_buf, { force = true })
			assert.are.same({ "modified by CLI inside terminal" }, lines)
		end
	)
end)
