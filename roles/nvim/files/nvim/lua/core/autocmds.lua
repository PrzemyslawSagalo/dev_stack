local autoread_group = vim.api.nvim_create_augroup("HyperFastAutoread", { clear = true })

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
	group = autoread_group,
	desc = "Synchronize file state with disk on focus and movement",
	callback = function()
		if vim.api.nvim_get_mode().mode ~= "c" then
			vim.cmd("checktime")
		end
	end,
})

---
-- Autocommand setup for DAP project config
---
local dap_project_group = vim.api.nvim_create_augroup('DapProjectConfig', { clear = true })

local function load_project_dap_config()
  local dap_config_path = vim.fn.getcwd() .. '/dap_config.lua'
  if vim.fn.filereadable(dap_config_path) == 1 then
    vim.cmd('luafile ' .. dap_config_path)
    vim.notify('Loaded project-specific DAP configuration', vim.log.levels.INFO, { title = 'DAP' })
  end
end

vim.api.nvim_create_autocmd('FileType', {
  group = dap_project_group,
  pattern = { 'python', 'cpp', 'kotlin' },
  desc = 'Load project DAP config on file open',
  callback = load_project_dap_config,
})

vim.api.nvim_create_autocmd('BufWritePost', {
  group = dap_project_group,
  pattern = '*/dap_config.lua',
  desc = 'Reload project-specific DAP config on save',
  callback = function()
    local ok, err = pcall(load_project_dap_config)
    if not ok then
      vim.notify('Failed to reload project DAP config: ' .. tostring(err), vim.log.levels.ERROR)
    end
  end,
})

