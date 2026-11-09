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
		local tmp

		before_each(function()
			tmp = vim.fn.tempname()
		end)

		after_each(function()
			vim.cmd("silent! %bdelete!")
			if vim.fn.filereadable(tmp) == 1 then
				vim.fn.delete(tmp)
			end
			local undofiles =
				vim.fn.glob(vim.fn.stdpath("state") .. "/undo/*" .. vim.fn.fnamemodify(tmp, ":t") .. "*", false, true)
			for _, uf in ipairs(undofiles) do
				vim.fn.delete(uf)
			end
		end)

		it("persists undo history across buffer reloads", function()
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
			assert.are.same(3, #lines_before_undo)

			-- Execute undo
			vim.cmd("silent! undo")

			local lines_after_undo = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert.are.same(2, #lines_after_undo)
			assert.are.same("initial version line 1", lines_after_undo[1])
			assert.are.same("initial version line 2", lines_after_undo[2])
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
