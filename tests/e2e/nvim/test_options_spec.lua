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

	local function remove_if_exists(path)
		if vim.uv.fs_stat(path) then
			local ok, err = os.remove(path)
			if not ok then
				vim.api.nvim_err_writeln(
					"Warning: failed to remove test file " .. path .. ": " .. (err or "unknown error")
				)
			end
		end
	end

	after_each(function()
		for _, buf in ipairs(tracked_bufs) do
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
		tracked_bufs = {}

		for _, file_path in ipairs(tracked_files) do
			remove_if_exists(file_path)
			local undo_pattern = vim.fn.stdpath("state") .. "/undo/*" .. vim.fn.fnamemodify(file_path, ":t") .. "*"
			local undofiles = vim.fn.glob(undo_pattern, false, true)
			for _, undo_path in ipairs(undofiles) do
				remove_if_exists(undo_path)
			end
		end
		tracked_files = {}
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
			local persistent_file = track_file(
				vim.fn.stdpath("cache") .. "/test_persistent_" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t") .. ".txt"
			)

			-- Step A: Create initial file content
			local buf1 = create_test_buf()
			vim.api.nvim_set_current_buf(buf1)
			vim.cmd("silent! edit! " .. vim.fn.fnameescape(persistent_file))
			vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "initial version line 1", "initial version line 2" })
			vim.cmd("silent! write!")

			-- Step B: Modify file in second revision
			vim.api.nvim_buf_set_lines(buf1, -1, -1, false, { "appended modification" })
			vim.cmd("silent! write!")

			-- Step C: Wipe buffer using native API to simulate session close
			vim.api.nvim_buf_delete(buf1, { force = true })

			-- Step D: Open file again and invoke undo
			local buf2 = create_test_buf()
			vim.api.nvim_set_current_buf(buf2)
			vim.cmd("silent! edit! " .. vim.fn.fnameescape(persistent_file))

			local lines_before_undo = vim.api.nvim_buf_get_lines(buf2, 0, -1, false)
			assert.are.same(3, #lines_before_undo)

			-- Execute undo
			vim.cmd("silent! undo")

			local lines_after_undo = vim.api.nvim_buf_get_lines(buf2, 0, -1, false)
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
			assert.is_true(vim.bo[buf].undofile)

			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ephemeral content" })
			vim.cmd("silent! write!")
			assert.is_false(vim.bo[buf].undofile)

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
			local tmp_path = track_file("/tmp/test_ephemeral_" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t") .. ".txt")
			assert_ephemeral_write_disables_undo(tmp_path)
		end)

		it("disables undofile on BufWritePre for *.tmp files", function()
			local tmp_file = track_file(
				vim.fn.stdpath("cache") .. "/test_ephemeral_" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t") .. ".tmp"
			)
			assert_ephemeral_write_disables_undo(tmp_file)
		end)
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

		it("opens :help autoread with buftype=help without error", function()
			vim.cmd("silent! help autoread")
			help_buf = vim.api.nvim_get_current_buf()
			assert.are.same("help", vim.bo[help_buf].buftype)
			assert.is_true(vim.api.nvim_buf_line_count(help_buf) > 0)
		end)
	end)

	describe("treesitter configuration and git filetypes", function()
		it("configures treesitter with auto_install disabled", function()
			local has_auto_install = vim.iter(vim.api.nvim_get_autocmds({ event = "FileType" })):any(function(ac)
				return ac.group_name and ac.group_name:find("NvimTreesitter.*auto_install") ~= nil
			end)
			assert.is_false(has_auto_install, "Treesitter auto_install autocmd should not be registered")
		end)

		local ts_configs = require("nvim-treesitter.configs")
		local ts_parsers = require("nvim-treesitter.parsers")
		local ensure_installed = ts_configs.get_ensure_installed_parsers()
		local installed_map = {}
		for _, parser in ipairs(ensure_installed) do
			installed_map[parser] = true
		end

		for _, lang in ipairs(languages.treesitter) do
			it("configures and installs parser for " .. lang, function()
				assert.is_true(installed_map[lang], "Parser " .. lang .. " is missing from ensure_installed")
				assert.is_true(ts_parsers.has_parser(lang), "Compiled parser for " .. lang .. " is missing on disk")
			end)
		end

		it("registers treesitter language aliases from languages.treesitter_filetypes", function()
			for parser, fts in pairs(languages.treesitter_filetypes) do
				for _, ft in ipairs(fts) do
					assert.are.same(parser, vim.treesitter.language.get_lang(ft))
				end
			end
		end)

		it("opens gitcommit file without treesitter auto-install errors", function()
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
			pcall(vim.fn.delete, test_dir, "rf")
		end)
	end)

	describe("lsp and mason configuration", function()
		it("ensures mason-lspconfig ensure_installed matches vim.lsp servers 1:1", function()
			local mlsp_settings = require("mason-lspconfig.settings")
			assert.are.same(languages.lsp, mlsp_settings.current.ensure_installed)
		end)

		for _, server in ipairs(languages.lsp) do
			it("configures and enables lsp server " .. server, function()
				assert.is_true(vim.lsp.is_enabled(server))
				assert.is_not_nil(vim.lsp.config[server])
			end)
		end

		it("configures yamlls filetypes including yaml.ghaction and yaml.ansible", function()
			local expected_filetypes = languages.lsp_configs.yamlls.filetypes
			assert.are.same(expected_filetypes, vim.lsp.config["yamlls"].filetypes)
		end)
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

		it("configures nvim-lint linters_by_ft matching configuration", function()
			local lint = require("lint")
			assert.are.same(languages.linters.by_ft, lint.linters_by_ft)
		end)

		for _, linter in ipairs(unique_linters) do
			it("registers nvim-lint linter " .. linter, function()
				local lint = require("lint")
				assert.is_not_nil(lint.linters[linter], "Linter " .. linter .. " is not registered in nvim-lint")
			end)
		end

		for _, tool in ipairs(languages.linters.mason_tools) do
			it("registers mason tool " .. tool, function()
				local mr = require("mason-registry")
				assert.is_true(mr.has_package(tool), "Mason package " .. tool .. " does not exist in registry")
			end)
		end

		it("verifies actionlint is installed and executable", function()
			assert.are.same(1, vim.fn.executable("actionlint"))
		end)

		it("registers autocmd events for nvim_lint_auto group", function()
			local autocmds = vim.api.nvim_get_autocmds({ group = "nvim_lint_auto" })
			assert.is_true(#autocmds >= 3)

			local events = {}
			for _, ac in ipairs(autocmds) do
				events[ac.event] = true
			end
			assert.is_true(events["BufEnter"])
			assert.is_true(events["BufWritePost"])
			assert.is_true(events["InsertLeave"])
		end)

		describe("workflow lint autocmd and filetype detection", function()
			local lint = require("lint")
			local test_dir

			before_each(function()
				test_dir = vim.fn.stdpath("cache") .. "/test_lint_" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
				vim.fn.mkdir(test_dir, "p")
			end)

			after_each(function()
				if test_dir then
					pcall(vim.fn.delete, test_dir, "rf")
				end
			end)

			it("maps yaml.ghaction linters to actionlint in linters_by_ft", function()
				assert.are.same({ "actionlint" }, lint.linters_by_ft["yaml.ghaction"])
			end)

			it("maps yaml.ansible linters to ansible_lint in linters_by_ft", function()
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
				it("detects yaml.ansible filetype for " .. case.name, function()
					local full_path = track_file(test_dir .. "/" .. case.rel_path)
					vim.fn.mkdir(vim.fn.fnamemodify(full_path, ":h"), "p")
					local buf = create_test_buf()
					vim.api.nvim_set_current_buf(buf)
					vim.cmd("edit! " .. vim.fn.fnameescape(full_path))
					assert.are.same("yaml.ansible", vim.bo[buf].filetype)
					local resolved_linters = lint._resolve_linter_by_ft(vim.bo[buf].filetype)
					assert.are.same({ "ansible_lint" }, resolved_linters)
				end)
			end

			it("triggers real actionlint diagnostics on invalid GitHub workflow", function()
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

				local found_actionlint = false
				for _, d in ipairs(diags) do
					if d.source and string.find(d.source, "actionlint") then
						found_actionlint = true
						break
					end
				end
				assert.is_true(found_actionlint, "Expected diagnostic produced by actionlint")
			end)

			it("produces zero actionlint diagnostics for non-workflow yaml files", function()
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
			end)
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
				pcall(vim.fn.delete, test_dir, "rf")
			end
		end)

		it("detects helm filetype for templates inside a chart", function()
			local chart_dir = test_dir .. "/mychart"
			local tmpl_dir = chart_dir .. "/templates"
			vim.fn.mkdir(tmpl_dir, "p")
			track_file(chart_dir .. "/Chart.yaml")
			vim.fn.writefile({ "apiVersion: v2", "name: mychart" }, chart_dir .. "/Chart.yaml")

			local deploy_file = track_file(tmpl_dir .. "/deployment.yaml")
			vim.fn.writefile({ "apiVersion: apps/v1" }, deploy_file)
			local buf1 = create_test_buf()
			vim.api.nvim_set_current_buf(buf1)
			vim.cmd("edit! " .. vim.fn.fnameescape(deploy_file))
			assert.are.same("helm", vim.bo[buf1].filetype)

			local tpl_file = track_file(tmpl_dir .. "/_helpers.tpl")
			vim.fn.writefile({ '{{- define "mychart.name" -}}' }, tpl_file)
			local buf2 = create_test_buf()
			vim.api.nvim_set_current_buf(buf2)
			vim.cmd("edit! " .. vim.fn.fnameescape(tpl_file))
			assert.are.same("helm", vim.bo[buf2].filetype)
		end)

		it("detects yaml.helm-values filetype for values files inside a chart", function()
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
		end)

		it("falls back to yaml for values and templates outside a chart", function()
			local plain_dir = test_dir .. "/plain"
			local plain_tmpl = plain_dir .. "/templates"
			vim.fn.mkdir(plain_tmpl, "p")

			local values_file = track_file(plain_dir .. "/values.yaml")
			vim.fn.writefile({ "replicaCount: 1" }, values_file)
			local buf1 = create_test_buf()
			vim.api.nvim_set_current_buf(buf1)
			vim.cmd("edit! " .. vim.fn.fnameescape(values_file))
			assert.are.same("yaml", vim.bo[buf1].filetype)

			local deploy_file = track_file(plain_tmpl .. "/deployment.yaml")
			vim.fn.writefile({ "apiVersion: apps/v1" }, deploy_file)
			local buf2 = create_test_buf()
			vim.api.nvim_set_current_buf(buf2)
			vim.cmd("edit! " .. vim.fn.fnameescape(deploy_file))
			assert.are.same("yaml", vim.bo[buf2].filetype)
		end)
	end)
end)
