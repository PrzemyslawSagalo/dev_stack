describe("neovim core options", function()
	local languages = require("config.languages")
	local tracked_bufs = {}
	local tracked_files = {}

	local function create_test_buf()
		local buf = vim.api.nvim_create_buf(true, false)
		table.insert(tracked_bufs, buf)
		return buf
	end

	local function track_file(path)
		table.insert(tracked_files, path)
		return path
	end

	after_each(function()
		for _, buf in ipairs(tracked_bufs) do
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
		tracked_bufs = {}

		for _, file_path in ipairs(tracked_files) do
			vim.fs.rm(file_path, { recursive = true, force = true })
			vim.fs.rm(vim.fn.undofile(file_path), { force = true })
		end
		tracked_files = {}
	end)

	describe("standard options", function()
		it("given the core options, when reading swapfile, then it is false", function()
			assert.is_false(vim.opt.swapfile:get())
		end)

		it("given the core options, when reading undofile, then it is true", function()
			assert.is_true(vim.opt.undofile:get())
		end)

		it("given the core options, when reading signcolumn, then it is yes", function()
			assert.are.same("yes", vim.opt.signcolumn:get())
		end)

		it("given the core options, when reading termguicolors, then it is true", function()
			assert.is_true(vim.opt.termguicolors:get())
		end)
	end)

	describe("clipboard configuration", function()
		local vim_options_path = vim.fn.stdpath("config") .. "/lua/core/vim_options.lua"
		if vim.fn.filereadable(vim_options_path) == 0 then
			vim_options_path = "roles/nvim/files/nvim/lua/core/vim_options.lua"
		end

		local orig_tmux = vim.env.TMUX
		local orig_ssh = vim.env.SSH_TTY

		after_each(function()
			vim.env.TMUX = orig_tmux
			vim.env.SSH_TTY = orig_ssh
			dofile(vim_options_path)
		end)

		it(
			"given the clipboard configuration, when inspecting it, then OSC 52 and unnamedplus are configured",
			function()
				assert.are.same("OSC 52", vim.g.clipboard.name)
				local clip_opts = vim.opt.clipboard:get()
				assert.is_true(vim.tbl_contains(clip_opts, "unnamedplus"))
				assert.is_function(vim.g.clipboard.copy["+"])
				assert.is_function(vim.g.clipboard.copy["*"])
				assert.is_function(vim.g.clipboard.paste["+"])
				assert.is_function(vim.g.clipboard.paste["*"])
			end
		)

		local remote_envs = {
			{ name = "TMUX", tmux = "/tmp/tmux-1000/default,999,0", ssh = nil },
			{ name = "SSH_TTY", tmux = nil, ssh = "/dev/pts/9" },
		}

		for _, env in ipairs(remote_envs) do
			it(
				"given "
					.. env.name
					.. " is set and no prior yank, when querying paste handlers, then empty characterwise registers are returned",
				function()
					vim.env.TMUX = env.tmux
					vim.env.SSH_TTY = env.ssh
					dofile(vim_options_path)

					local plus = vim.g.clipboard.paste["+"]()
					local star = vim.g.clipboard.paste["*"]()

					assert.are.same({ {}, "v" }, plus)
					assert.are.same({ {}, "v" }, star)
				end
			)
		end

		local clipboard_modes = {
			{
				mode = "linewise",
				src_lines = { "remote linewise line", "second line" },
				src_cursor = { 1, 0 },
				yank = function()
					vim.cmd('normal! "+yy')
				end,
				dst_lines = { "target line" },
				dst_cursor = { 1, 0 },
				paste_cmd = 'normal! "+p',
				expected = { "target line", "remote linewise line" },
			},
			{
				mode = "charwise",
				src_lines = { "alpha beta gamma" },
				src_cursor = { 1, 6 },
				yank = function()
					vim.cmd('normal! "+yiw')
				end,
				dst_lines = { "first second" },
				dst_cursor = { 1, 5 },
				paste_cmd = "normal! p",
				expected = { "first betasecond" },
			},
			{
				mode = "blockwise",
				src_lines = { "ABCDEF", "123456" },
				src_cursor = { 1, 1 },
				yank = function()
					local keys = vim.api.nvim_replace_termcodes('<C-v>jl"+y', true, false, true)
					vim.api.nvim_feedkeys(keys, "nx", false)
				end,
				dst_lines = { "XXXX", "YYYY" },
				dst_cursor = { 1, 1 },
				paste_cmd = 'normal! "+p',
				expected = { "XXBCXX", "YY23YY" },
			},
		}

		for _, env in ipairs(remote_envs) do
			for _, case in ipairs(clipboard_modes) do
				it(
					"given "
						.. env.name
						.. " is set and source and target buffers, when yanking and pasting in "
						.. case.mode
						.. " mode, then the pasted buffer matches the expected lines",
					function()
						vim.env.TMUX = env.tmux
						vim.env.SSH_TTY = env.ssh
						dofile(vim_options_path)

						local src_buf = create_test_buf()
						vim.api.nvim_set_current_buf(src_buf)
						vim.api.nvim_buf_set_lines(src_buf, 0, -1, false, case.src_lines)
						vim.api.nvim_win_set_cursor(0, case.src_cursor)

						local dst_buf = create_test_buf()
						vim.api.nvim_buf_set_lines(dst_buf, 0, -1, false, case.dst_lines)

						case.yank()
						vim.api.nvim_set_current_buf(dst_buf)
						vim.api.nvim_win_set_cursor(0, case.dst_cursor)
						vim.cmd(case.paste_cmd)

						assert.are.same(case.expected, vim.api.nvim_buf_get_lines(dst_buf, 0, -1, false))
					end
				)
			end
		end

		it(
			"given a child nvim yank and paste script, when running it with TMUX set, then it exits 0 without hanging",
			function()
				local lua_cmd = table.concat({
					"local ok, err = pcall(function()",
					"  local b1 = vim.api.nvim_create_buf(true, false)",
					"  vim.api.nvim_set_current_buf(b1)",
					'  vim.api.nvim_buf_set_lines(b1, 0, -1, false, { "child_tmux_payload", "second line" })',
					"  vim.api.nvim_win_set_cursor(0, { 1, 0 })",
					'  vim.cmd([[normal! "+yy]])',
					"  local b2 = vim.api.nvim_create_buf(true, false)",
					"  vim.api.nvim_set_current_buf(b2)",
					'  vim.api.nvim_buf_set_lines(b2, 0, -1, false, { "target" })',
					'  vim.cmd([[normal! "+p]])',
					"  local lines = vim.api.nvim_buf_get_lines(b2, 0, -1, false)",
					'  assert(lines[1] == "target", "Expected target on line 1")',
					'  assert(lines[2] == "child_tmux_payload", "Expected child_tmux_payload on line 2")',
					'  assert(#lines == 2, "Expected 2 lines, got " .. #lines)',
					"end)",
					"if not ok then",
					'  io.stderr:write("Child assertion failure: " .. tostring(err) .. "\\n")',
					'  vim.cmd("cquit 1")',
					"end",
					'vim.cmd("qall!")',
				}, "\n")

				local child = vim.system({
					"nvim",
					"--headless",
					"-u",
					vim.fn.stdpath("config") .. "/init.lua",
					"-c",
					"lua " .. lua_cmd,
				}, {
					env = {
						TMUX = "/tmp/tmux-1000/default,1,0",
						SSH_TTY = "",
						HOME = vim.env.HOME,
						PATH = vim.env.PATH,
					},
					text = true,
				}):wait(5000)

				assert.are.same(0, child.code, "Child process failed: " .. (child.stderr or ""))
			end
		)

		it(
			"given neither TMUX nor SSH_TTY is set, when reloading vim_options, then the OSC 52 paste handler is configured",
			function()
				vim.env.TMUX = nil
				vim.env.SSH_TTY = nil
				dofile(vim_options_path)

				assert.are.same("OSC 52", vim.g.clipboard.name)
				assert.is_function(vim.g.clipboard.paste["+"])
				assert.is_function(vim.g.clipboard.paste["*"])
			end
		)
	end)

	describe("undofile persistence", function()
		it(
			"given a file saved in two revisions and closed, when reopening and undoing, then the first revision is restored",
			function()
				local persistent_file = track_file(
					vim.fn.stdpath("cache")
						.. "/test_persistent_"
						.. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
						.. ".txt"
				)

				local buf1 = create_test_buf()
				vim.api.nvim_set_current_buf(buf1)
				vim.cmd("silent! edit! " .. vim.fn.fnameescape(persistent_file))
				vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "initial version line 1", "initial version line 2" })
				vim.cmd("silent! write!")

				vim.api.nvim_buf_set_lines(buf1, -1, -1, false, { "appended modification" })
				vim.cmd("silent! write!")
				vim.api.nvim_buf_delete(buf1, { force = true })

				local buf2 = create_test_buf()
				vim.api.nvim_set_current_buf(buf2)
				vim.cmd("silent! edit! " .. vim.fn.fnameescape(persistent_file))

				local lines_before_undo = vim.api.nvim_buf_get_lines(buf2, 0, -1, false)
				assert.are.same(3, #lines_before_undo)

				vim.cmd("silent! undo")

				local lines_after_undo = vim.api.nvim_buf_get_lines(buf2, 0, -1, false)
				assert.are.same(2, #lines_after_undo)
				assert.are.same("initial version line 1", lines_after_undo[1])
				assert.are.same("initial version line 2", lines_after_undo[2])

				vim.api.nvim_buf_delete(buf2, { force = true })
			end
		)
	end)

	describe("undofile ephemeral filter", function()
		it(
			"given a buffer with undofile enabled, when filetype is set to gitcommit, then undofile is disabled",
			function()
				local buf = create_test_buf()
				vim.api.nvim_set_current_buf(buf)
				vim.bo[buf].undofile = true
				assert.is_true(vim.bo[buf].undofile)

				vim.bo[buf].filetype = "gitcommit"

				assert.is_false(vim.bo[buf].undofile)
			end
		)

		it(
			"given a buffer with undofile enabled, when filetype is set to gitrebase, then undofile is disabled",
			function()
				local buf = create_test_buf()
				vim.api.nvim_set_current_buf(buf)
				vim.bo[buf].undofile = true
				assert.is_true(vim.bo[buf].undofile)

				vim.bo[buf].filetype = "gitrebase"

				assert.is_false(vim.bo[buf].undofile)
			end
		)

		local function assert_ephemeral_write_disables_undo(file_path)
			local buf = create_test_buf()
			vim.api.nvim_set_current_buf(buf)
			vim.cmd("silent! edit! " .. vim.fn.fnameescape(file_path))
			assert.is_true(vim.bo[buf].undofile)

			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ephemeral content" })
			vim.cmd("silent! write!")

			assert.is_false(vim.bo[buf].undofile)
			vim.api.nvim_buf_delete(buf, { force = true })
			assert.is_nil(vim.uv.fs_stat(vim.fn.undofile(file_path)))
		end

		it(
			"given a buffer editing a /tmp/* file, when writing it, then undofile is disabled and no undo file is written",
			function()
				local tmp_path =
					track_file("/tmp/test_ephemeral_" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t") .. ".txt")
				assert_ephemeral_write_disables_undo(tmp_path)
			end
		)

		it(
			"given a buffer editing a *.tmp file, when writing it, then undofile is disabled and no undo file is written",
			function()
				local tmp_file = track_file(
					vim.fn.stdpath("cache")
						.. "/test_ephemeral_"
						.. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
						.. ".tmp"
				)
				assert_ephemeral_write_disables_undo(tmp_file)
			end
		)
	end)

	describe("help command", function()
		local help_buf

		after_each(function()
			vim.cmd("silent! helpclose")
			if help_buf and vim.api.nvim_buf_is_valid(help_buf) then
				vim.api.nvim_buf_delete(help_buf, { force = true })
			end
			help_buf = nil
		end)

		it("given the help command, when opening :help autoread, then a help buffer opens without error", function()
			vim.cmd("silent! help autoread")
			help_buf = vim.api.nvim_get_current_buf()
			assert.are.same("help", vim.bo[help_buf].buftype)
			assert.is_true(vim.api.nvim_buf_line_count(help_buf) > 0)
		end)
	end)

	describe("treesitter configuration and git filetypes", function()
		it(
			"given the treesitter configuration, when inspecting FileType autocmds, then no auto_install autocmd is registered",
			function()
				local has_auto_install = vim.iter(vim.api.nvim_get_autocmds({ event = "FileType" })):any(function(ac)
					return ac.group_name and ac.group_name:find("NvimTreesitter.*auto_install") ~= nil
				end)
				assert.is_false(has_auto_install, "Treesitter auto_install autocmd should not be registered")
			end
		)

		local ts_configs = require("nvim-treesitter.configs")
		local ts_parsers = require("nvim-treesitter.parsers")
		local ensure_installed = ts_configs.get_ensure_installed_parsers()
		local installed_map = {}
		for _, parser in ipairs(ensure_installed) do
			installed_map[parser] = true
		end

		for _, lang in ipairs(languages.treesitter) do
			it(
				"given a scratch buffer for "
					.. lang
					.. ", when starting the highlighter, then parser, query, and highlighter are active",
				function()
					local buf = create_test_buf()

					local query = vim.treesitter.query.get(lang, "highlights")
					vim.treesitter.start(buf, lang)

					assert.is_true(installed_map[lang], "Parser " .. lang .. " is missing from ensure_installed")
					assert.is_true(ts_parsers.has_parser(lang), "Compiled parser for " .. lang .. " is missing on disk")
					assert.is_not_nil(query, "Highlights query for " .. lang .. " failed to load")
					assert.is_not_nil(vim.treesitter.highlighter.active[buf])
					vim.treesitter.stop(buf)
				end
			)
		end

		it(
			"given a Python buffer with except* syntax, when highlighting and parsing, then the tree has no errors",
			function()
				local buf = create_test_buf()
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
					"try:",
					"    pass",
					"except* ValueError as exc:",
					"    pass",
				})
				vim.bo[buf].filetype = "python"

				vim.treesitter.start(buf, "python")
				local trees = vim.treesitter.get_parser(buf, "python"):parse()

				assert.is_not_nil(vim.treesitter.highlighter.active[buf])
				assert.is_false(trees[1]:root():has_error())
				vim.treesitter.stop(buf)
			end
		)

		it(
			"given languages.treesitter_filetypes, when resolving filetype languages, then aliases map to their parsers",
			function()
				for parser, fts in pairs(languages.treesitter_filetypes) do
					for _, ft in ipairs(fts) do
						assert.are.same(parser, vim.treesitter.language.get_lang(ft))
					end
				end
			end
		)

		it(
			"given a COMMIT_EDITMSG buffer, when opening and writing it, then filetype is gitcommit and undofile is off",
			function()
				local test_dir = vim.fn.stdpath("cache") .. "/test_git_" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
				vim.fn.mkdir(test_dir, "p")
				local gitcommit_file = track_file(test_dir .. "/COMMIT_EDITMSG")
				local buf = create_test_buf()
				vim.api.nvim_set_current_buf(buf)

				vim.cmd("edit! " .. vim.fn.fnameescape(gitcommit_file))
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "feat(test): commit message line" })
				vim.cmd("write!")

				assert.are.same("gitcommit", vim.bo[buf].filetype)
				assert.is_false(vim.bo[buf].undofile)
				vim.api.nvim_buf_delete(buf, { force = true })
				vim.fs.rm(test_dir, { recursive = true, force = true })
			end
		)
	end)

	describe("lsp and mason configuration", function()
		it(
			"given the language config, when reading mason-lspconfig, then ensure_installed matches the lsp servers 1:1",
			function()
				local mlsp_settings = require("mason-lspconfig.settings")
				assert.are.same(languages.lsp, mlsp_settings.current.ensure_installed)
			end
		)

		for _, server in ipairs(languages.lsp) do
			it(
				"given lsp server " .. server .. ", when inspecting vim.lsp, then it is configured and enabled",
				function()
					assert.is_true(vim.lsp.is_enabled(server))
					assert.is_not_nil(vim.lsp.config[server])
				end
			)
		end

		it(
			"given the yamlls config, when reading its filetypes, then they include yaml.ghaction and yaml.ansible",
			function()
				local expected_filetypes = languages.lsp_configs.yamlls.filetypes
				assert.are.same(expected_filetypes, vim.lsp.config["yamlls"].filetypes)
			end
		)
	end)

	describe("nvim-lint and actionlint configuration", function()
		local unique_linters = {}
		local seen_linters = {}
		for _, linter_list in pairs(languages.linters.by_ft) do
			for _, linter in ipairs(linter_list) do
				if not seen_linters[linter] then
					seen_linters[linter] = true
					table.insert(unique_linters, linter)
				end
			end
		end
		table.sort(unique_linters)

		it("given the language config, when reading nvim-lint, then linters_by_ft matches it", function()
			local lint = require("lint")
			assert.are.same(languages.linters.by_ft, lint.linters_by_ft)
		end)

		for _, linter in ipairs(unique_linters) do
			it("given linter " .. linter .. ", when inspecting nvim-lint, then it is registered", function()
				local lint = require("lint")
				assert.is_not_nil(lint.linters[linter], "Linter " .. linter .. " is not registered in nvim-lint")
			end)
		end

		for _, tool in ipairs(languages.linters.mason_tools) do
			it("given mason tool " .. tool .. ", when inspecting mason-registry, then the package exists", function()
				local mr = require("mason-registry")
				assert.is_true(mr.has_package(tool), "Mason package " .. tool .. " does not exist in registry")
			end)
		end

		it("given the system, when checking actionlint, then it is installed and executable", function()
			assert.are.same(1, vim.fn.executable("actionlint"))
		end)

		it(
			"given the nvim_lint_auto group, when listing autocmds, then BufEnter, BufWritePost, and InsertLeave are registered",
			function()
				local autocmds = vim.api.nvim_get_autocmds({ group = "nvim_lint_auto" })
				assert.is_true(#autocmds >= 3)

				local events = {}
				for _, ac in ipairs(autocmds) do
					events[ac.event] = true
				end
				assert.is_true(events["BufEnter"])
				assert.is_true(events["BufWritePost"])
				assert.is_true(events["InsertLeave"])
			end
		)

		describe("workflow lint autocmd and filetype detection", function()
			local lint = require("lint")
			local test_dir

			before_each(function()
				test_dir = vim.fn.stdpath("cache") .. "/test_lint_" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
				vim.fn.mkdir(test_dir, "p")
			end)

			after_each(function()
				if test_dir then
					vim.fs.rm(test_dir, { recursive = true, force = true })
				end
			end)

			it("given linters_by_ft, when reading yaml.ghaction, then it maps to actionlint", function()
				assert.are.same({ "actionlint" }, lint.linters_by_ft["yaml.ghaction"])
			end)

			it("given linters_by_ft, when reading yaml.ansible, then it maps to ansible_lint", function()
				assert.are.same({ "ansible_lint" }, lint.linters_by_ft["yaml.ansible"])
			end)

			local ansible_cases = {
				{ name = "roles/system/tasks/main.yml", rel_path = "roles/system/tasks/main.yml" },
				{ name = "roles/system/handlers/main.yaml", rel_path = "roles/system/handlers/main.yaml" },
				{ name = "roles/system/defaults/main.yml", rel_path = "roles/system/defaults/main.yml" },
				{ name = "roles/system/vars/main.yml", rel_path = "roles/system/vars/main.yml" },
				{ name = "roles/system/meta/main.yml", rel_path = "roles/system/meta/main.yml" },
				{ name = "playbooks/site.yml", rel_path = "playbooks/site.yml" },
				{ name = "setup.yml", rel_path = "setup.yml" },
				{ name = "site.yaml", rel_path = "site.yaml" },
			}

			for _, case in ipairs(ansible_cases) do
				it(
					"given an Ansible YAML file "
						.. case.name
						.. ", when opening it, then yaml.ansible filetype and ansible_lint are resolved",
					function()
						local full_path = track_file(test_dir .. "/" .. case.rel_path)
						vim.fn.mkdir(vim.fn.fnamemodify(full_path, ":h"), "p")
						local buf = create_test_buf()
						vim.api.nvim_set_current_buf(buf)

						vim.cmd("edit! " .. vim.fn.fnameescape(full_path))

						assert.are.same("yaml.ansible", vim.bo[buf].filetype)
						local resolved_linters = lint._resolve_linter_by_ft(vim.bo[buf].filetype)
						assert.are.same({ "ansible_lint" }, resolved_linters)
					end
				)
			end

			it(
				"given an invalid GitHub workflow, when opening it and waiting for lint, then actionlint publishes diagnostics",
				function()
					local wf_path = track_file(test_dir .. "/.github/workflows/test_ci.yml")
					vim.fn.mkdir(vim.fn.fnamemodify(wf_path, ":h"), "p")
					vim.fn.writefile({
						"name: Test",
						"on: push",
						"jobs:",
						"  test:",
						"    runs-on: invalid-runner-os-name",
						"    steps:",
						"      - run: echo hello",
					}, wf_path)

					local buf = create_test_buf()
					vim.api.nvim_set_current_buf(buf)
					vim.cmd("edit! " .. vim.fn.fnameescape(wf_path))
					assert.are.same("yaml.ghaction", vim.bo[buf].filetype)

					local ns = lint.get_namespace("actionlint")
					local ok = vim.wait(10000, function()
						local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
						return #diagnostics > 0
					end, 100)

					assert.is_true(ok, "actionlint diagnostics were not published within 10s")
					local diags = vim.diagnostic.get(buf, { namespace = ns })
					assert.is_true(#diags > 0)

					assert.is_true(
						vim.iter(diags):any(function(d)
							return d.source and string.find(d.source, "actionlint", 1, true) ~= nil
						end),
						"Expected diagnostic produced by actionlint"
					)
				end
			)

			it(
				"given a non-workflow yaml file, when opening it and waiting for lint, then no actionlint diagnostics are emitted",
				function()
					local plain_yaml = track_file(test_dir .. "/foo.yml")
					vim.fn.writefile({
						"key: value",
						"items:",
						"  - name: test",
					}, plain_yaml)

					local buf = create_test_buf()
					vim.api.nvim_set_current_buf(buf)
					vim.cmd("edit! " .. vim.fn.fnameescape(plain_yaml))
					assert.are.same("yaml", vim.bo[buf].filetype)

					vim.wait(500, function()
						return #vim.diagnostic.get(buf) > 0
					end, 50)

					local diags = vim.diagnostic.get(buf)
					local actionlint_diags = vim.tbl_filter(function(d)
						return d.source and string.find(d.source, "actionlint") ~= nil
					end, diags)
					assert.are.same(0, #actionlint_diags, "actionlint diagnostics should not run on plain yaml")
				end
			)
		end)
	end)

	describe("helm chart-aware filetype detection", function()
		local test_dir

		before_each(function()
			test_dir = vim.fn.stdpath("cache") .. "/test_helm_" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
			vim.fn.mkdir(test_dir, "p")
		end)

		after_each(function()
			if test_dir then
				vim.fs.rm(test_dir, { recursive = true, force = true })
			end
		end)

		it(
			"given a Helm chart with templates, when opening the template files, then both detect the helm filetype",
			function()
				local chart_dir = test_dir .. "/mychart"
				local tmpl_dir = chart_dir .. "/templates"
				vim.fn.mkdir(tmpl_dir, "p")
				track_file(chart_dir .. "/Chart.yaml")
				vim.fn.writefile({ "apiVersion: v2", "name: mychart" }, chart_dir .. "/Chart.yaml")

				local deploy_file = track_file(tmpl_dir .. "/deployment.yaml")
				vim.fn.writefile({ "apiVersion: apps/v1" }, deploy_file)
				local tpl_file = track_file(tmpl_dir .. "/_helpers.tpl")
				vim.fn.writefile({ '{{- define "mychart.name" -}}' }, tpl_file)

				local buf1 = create_test_buf()
				vim.api.nvim_set_current_buf(buf1)
				vim.cmd("edit! " .. vim.fn.fnameescape(deploy_file))

				local buf2 = create_test_buf()
				vim.api.nvim_set_current_buf(buf2)
				vim.cmd("edit! " .. vim.fn.fnameescape(tpl_file))

				assert.are.same("helm", vim.bo[buf1].filetype)
				assert.are.same("helm", vim.bo[buf2].filetype)
			end
		)

		it(
			"given a Helm chart with values.yaml, when opening values.yaml, then yaml.helm-values is detected",
			function()
				local chart_dir = test_dir .. "/mychart"
				vim.fn.mkdir(chart_dir, "p")
				track_file(chart_dir .. "/Chart.yaml")
				vim.fn.writefile({ "apiVersion: v2", "name: mychart" }, chart_dir .. "/Chart.yaml")

				local values_file = track_file(chart_dir .. "/values.yaml")
				vim.fn.writefile({ "replicaCount: 1" }, values_file)

				local buf = create_test_buf()
				vim.api.nvim_set_current_buf(buf)
				vim.cmd("edit! " .. vim.fn.fnameescape(values_file))

				assert.are.same("yaml.helm-values", vim.bo[buf].filetype)
			end
		)

		it(
			"given values and templates without Chart.yaml, when opening both files, then both fall back to yaml filetype",
			function()
				local plain_dir = test_dir .. "/plain"
				local plain_tmpl = plain_dir .. "/templates"
				vim.fn.mkdir(plain_tmpl, "p")

				local values_file = track_file(plain_dir .. "/values.yaml")
				vim.fn.writefile({ "replicaCount: 1" }, values_file)
				local deploy_file = track_file(plain_tmpl .. "/deployment.yaml")
				vim.fn.writefile({ "apiVersion: apps/v1" }, deploy_file)

				local buf1 = create_test_buf()
				vim.api.nvim_set_current_buf(buf1)
				vim.cmd("edit! " .. vim.fn.fnameescape(values_file))

				local buf2 = create_test_buf()
				vim.api.nvim_set_current_buf(buf2)
				vim.cmd("edit! " .. vim.fn.fnameescape(deploy_file))

				assert.are.same("yaml", vim.bo[buf1].filetype)
				assert.are.same("yaml", vim.bo[buf2].filetype)
			end
		)
	end)
end)
