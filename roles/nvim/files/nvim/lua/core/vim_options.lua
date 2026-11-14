vim.opt.guicursor = ""

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.errorbells = false

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.smartindent = true

vim.opt.wrap = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true

-- Hyper-fast autoread configuration
vim.opt.autoread = true
vim.opt.updatetime = 200

-- Synchronize clipboard with host system via native OSC 52
vim.opt.clipboard = "unnamedplus"
local osc52 = require("vim.ui.clipboard.osc52")
local osc52_cache = {}

local function copy_with_cache(reg)
	local copy_fn = osc52.copy(reg)
	return function(lines, regtype)
		osc52_cache[reg] = { vim.deepcopy(lines), regtype }
		copy_fn(lines, regtype)
	end
end

local function paste_cached(reg)
	return function()
		local cached = osc52_cache[reg]
		if cached then
			return { vim.deepcopy(cached[1]), cached[2] }
		end
		return { {}, "v" }
	end
end

local is_remote_or_tmux = (vim.env.SSH_TTY and vim.env.SSH_TTY ~= "") or (vim.env.TMUX and vim.env.TMUX ~= "")

vim.g.clipboard = {
	name = "OSC 52",
	copy = {
		["+"] = copy_with_cache("+"),
		["*"] = copy_with_cache("*"),
	},
	paste = {
		["+"] = is_remote_or_tmux and paste_cached("+") or osc52.paste("+"),
		["*"] = is_remote_or_tmux and paste_cached("*") or osc52.paste("*"),
	},
}
