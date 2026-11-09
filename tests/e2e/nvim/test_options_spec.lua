describe("neovim core options", function()
	local tracked_bufs = {}

	local function create_test_buf()
		local buf = vim.api.nvim_create_buf(true, false)
		table.insert(tracked_bufs, buf)
		return buf
	end

	after_each(function()
		for _, buf in ipairs(tracked_bufs) do
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
		tracked_bufs = {}
	end)

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
		it("persists undo history across buffer reloads for persistent files", function()
			local persistent_file = vim.fn.stdpath("cache")
				.. "/test_persistent_"
				.. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
				.. ".txt"

			-- Step A: Create initial file content
			local buf1 = create_test_buf()
			vim.api.nvim_set_current_buf(buf1)
			vim.cmd("silent! edit! " .. vim.fn.fnameescape(persistent_file))
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "initial version line 1", "initial version line 2" })
			vim.cmd("silent! write!")

			-- Step B: Modify file in second revision
			vim.api.nvim_buf_set_lines(0, -1, -1, false, { "appended modification" })
			vim.cmd("silent! write!")

			-- Step C: Wipe buffer using native API to simulate session close
			vim.api.nvim_buf_delete(buf1, { force = true })

			-- Step D: Open file again and invoke undo
			local buf2 = create_test_buf()
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

			vim.api.nvim_buf_delete(buf2, { force = true })
		end)
	end)

	describe("undofile ephemeral filter", function()
		it("disables undofile for gitcommit filetype", function()
			local buf = create_test_buf()
			vim.api.nvim_set_current_buf(buf)
			vim.bo[buf].undofile = true
			assert.is_true(vim.bo[buf].undofile)

			vim.bo[buf].filetype = "gitcommit"
			assert.is_false(vim.bo[buf].undofile)
		end)

		it("disables undofile for gitrebase filetype", function()
			local buf = create_test_buf()
			vim.api.nvim_set_current_buf(buf)
			vim.bo[buf].undofile = true
			assert.is_true(vim.bo[buf].undofile)

			vim.bo[buf].filetype = "gitrebase"
			assert.is_false(vim.bo[buf].undofile)
		end)

		local function assert_ephemeral_write_disables_undo(file_path)
			local buf = create_test_buf()
			vim.api.nvim_set_current_buf(buf)
			vim.cmd("silent! edit! " .. vim.fn.fnameescape(file_path))
			assert.is_true(vim.bo.undofile)

			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "ephemeral content" })
			vim.cmd("silent! write!")
			assert.is_false(vim.bo.undofile)

			-- Cleanly wipe buffer from memory
			vim.api.nvim_buf_delete(buf, { force = true })

			-- Verify no undo file was created on disk
			local undofiles = vim.fn.glob(
				vim.fn.stdpath("state") .. "/undo/*" .. vim.fn.fnamemodify(file_path, ":t") .. "*",
				false,
				true
			)
			assert.are.same(0, #undofiles)
		end

		it("disables undofile on BufWritePre for /tmp/* files", function()
			local tmp_path = "/tmp/test_ephemeral_" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t") .. ".txt"
			assert_ephemeral_write_disables_undo(tmp_path)
		end)

		it("disables undofile on BufWritePre for *.tmp files", function()
			local tmp_file = vim.fn.stdpath("cache")
				.. "/test_ephemeral_"
				.. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
				.. ".tmp"
			assert_ephemeral_write_disables_undo(tmp_file)
		end)
	end)

	describe("help command", function()
		after_each(function()
			vim.cmd("silent! helpclose")
		end)

		it("opens :help autoread with buftype=help without error", function()
			vim.cmd("silent! help autoread")
			assert.are.same("help", vim.bo.buftype)
			assert.is_true(vim.api.nvim_buf_line_count(0) > 0)
		end)
	end)
end)
