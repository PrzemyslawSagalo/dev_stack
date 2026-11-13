local M = {}

M.treesitter = {
	"bash",
	"c",
	"cpp",
	"diff",
	"dockerfile",
	"git_config",
	"git_rebase",
	"gitattributes",
	"gitcommit",
	"gitignore",
	"gotmpl",
	"groovy",
	"hcl",
	"helm",
	"json",
	"kotlin",
	"lua",
	"make",
	"markdown",
	"markdown_inline",
	"mermaid",
	"python",
	"query",
	"rst",
	"sql",
	"terraform",
	"toml",
	"vim",
	"vimdoc",
	"xml",
	"yaml",
}

local function helm_template_ft(path, bufnr)
	local source = (bufnr and bufnr > 0) and bufnr or path
	if vim.fs.root(source, { "Chart.yaml" }) then
		return "helm"
	end
end

local function helm_values_ft(path, bufnr)
	local source = (bufnr and bufnr > 0) and bufnr or path
	if vim.fs.root(source, { "Chart.yaml" }) then
		return "yaml.helm-values"
	end
end

M.filetypes = {
	pattern = {
		[".*/%.github/workflows/.*%.ya?ml"] = "yaml.ghaction",
		[".*/roles/.*/tasks/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/handlers/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/defaults/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/vars/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/meta/.*%.ya?ml"] = "yaml.ansible",
		[".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
		[".*/setup%.ya?ml"] = "yaml.ansible",
		[".*/site%.ya?ml"] = "yaml.ansible",
		[".*/templates/.*%.ya?ml"] = helm_template_ft,
		[".*/templates/.*%.tpl"] = helm_template_ft,
		[".*/values.*%.ya?ml"] = helm_values_ft,
	},
}

M.treesitter_filetypes = {
	yaml = { "yaml.ghaction", "yaml.ansible", "yaml.helm-values" },
}

M.lsp = {
	"ansiblels",
	"bashls",
	"clangd",
	"dockerls",
	"groovyls",
	"helm_ls",
	"jsonls",
	"kotlin_language_server",
	"lua_ls",
	"marksman",
	"ruff",
	"sqls",
	"terraformls",
	"yamlls",
}

M.lsp_configs = {
	yamlls = {
		filetypes = {
			"yaml",
			"yaml.docker-compose",
			"yaml.gitlab",
			"yaml.ghaction",
			"yaml.ansible",
		},
	},
}

M.linters = {
	mason_tools = {
		"actionlint",
		"ansible-lint",
		"hadolint",
		"ktlint",
		"sqlfluff",
		"tflint",
	},
	by_ft = {
		ansible = { "ansible_lint" },
		dockerfile = { "hadolint" },
		kotlin = { "ktlint" },
		sql = { "sqlfluff" },
		terraform = { "tflint" },
		["yaml.ansible"] = { "ansible_lint" },
		["yaml.ghaction"] = { "actionlint" },
	},
}

return M
