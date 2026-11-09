describe("neovim core options", function()
	describe("standard options", function()
		it("sets swapfile to false", function()
			assert.is_false(vim.opt.swapfile:get())
		end)

		it("sets undofile to true", function()
			assert.is_true(vim.opt.undofile:get())
		end)

		it("sets signcolumn to yes", function()
			assert.are.same("yes", vim.opt.signcolumn:get())
		end)

		it("sets termguicolors to true", function()
			assert.is_true(vim.opt.termguicolors:get())
		end)
	end)

	describe("undofile persistence", function()
		local persistent_file

		before_each(function()
			persistent_file = vim.fn.stdpath("cache")
				.. "/test_persistent_"
				.. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
				.. ".txt"
		end)

		after_each(function()
			vim.cmd("silent! %bdelete!")
			if vim.fn.filereadable(persistent_file) == 1 then
				vim.fn.delete(persistent_file)
			end
			local undofiles = vim.fn.glob(
				vim.fn.stdpath("state") .. "/undo/*" .. vim.fn.fnamemodify(persistent_file, ":t") .. "*",
				false,
				true
			)
			for _, uf in ipairs(undofiles) do
				vim.fn.delete(uf)
			end
		end)

		it("persists undo history across buffer reloads for persistent files", function()
			-- Step A: Create initial file content
			local buf1 = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(buf1)
			vim.cmd("silent! edit! " .. vim.fn.fnameescape(persistent_file))
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
			vim.cmd("silent! edit! " .. vim.fn.fnameescape(persistent_file))

			local lines_before_undo = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.are.same(3, #lines_before_undo)

			-- Execute undo
			vim.cmd("silent! undo")

			local lines_after_undo = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.are.same(2, #lines_after_undo)
			assert.are.same("initial version line 1", lines_after_undo[1])
			assert.are.same("initial version line 2", lines_after_undo[2])
		end)
	end)

	describe("undofile ephemeral filter", function()
		after_each(function()
			vim.cmd("silent! %bdelete!")
		end)

		it("disables undofile for gitcommit filetype", function()
			local buf = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(buf)
			vim.bo.filetype = "gitcommit"
			assert.is_false(vim.bo.undofile)
		end)

		it("disables undofile for gitrebase filetype", function()
			local buf = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(buf)
			vim.bo.filetype = "gitrebase"
			assert.is_false(vim.bo.undofile)
		end)

		it("disables undofile on BufWritePre for /tmp/* files", function()
			local tmp_path = "/tmp/test_ephemeral_" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t") .. ".txt"
			local buf = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(buf)
			vim.cmd("silent! edit! " .. vim.fn.fnameescape(tmp_path))
			assert.is_true(vim.bo.undofile)
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "ephemeral content" })
			vim.cmd("silent! write!")
			assert.is_false(vim.bo.undofile)
			vim.cmd("silent! bdelete!")
			if vim.fn.filereadable(tmp_path) == 1 then
				vim.fn.delete(tmp_path)
			end
		end)

		it("disables undofile on BufWritePre for *.tmp files", function()
			local tmp_file = vim.fn.stdpath("cache")
				.. "/test_ephemeral_"
				.. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
				.. ".tmp"
			local buf = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(buf)
			vim.cmd("silent! edit! " .. vim.fn.fnameescape(tmp_file))
			assert.is_true(vim.bo.undofile)
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "ephemeral content" })
			vim.cmd("silent! write!")
			assert.is_false(vim.bo.undofile)
			vim.cmd("silent! bdelete!")
			if vim.fn.filereadable(tmp_file) == 1 then
				vim.fn.delete(tmp_file)
			end
		end)
	end)

	describe("help command", function()
		after_each(function()
			vim.cmd("silent! helpclose")
			vim.cmd("silent! %bdelete!")
		end)

		it("opens :help autoread with buftype=help without error", function()
			vim.cmd("silent! help autoread")
			assert.are.same("help", vim.bo.buftype)
			assert.is_true(vim.api.nvim_buf_line_count(0) > 0)
		end)
	end)
end)
