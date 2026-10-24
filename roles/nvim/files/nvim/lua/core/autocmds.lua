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
-- Autocommand setup for DAP project config (secured via vim.secure.read)
---
local dap_project_group = vim.api.nvim_create_augroup('DapProjectConfig', { clear = true })

local function load_project_dap_config()
  -- Skip project configuration if the trust verification API is unavailable
  if not (vim.secure and type(vim.secure.read) == "function") then
    return
  end

  local dap_config_path = vim.fn.getcwd() .. '/dap_config.lua'
  if vim.fn.filereadable(dap_config_path) == 1 then
    local contents = vim.secure.read(dap_config_path)
    if contents and contents ~= "" then
      local chunk, err = load(contents, "@" .. dap_config_path)
      if chunk then
        local ok, run_err = pcall(chunk)
        if ok then
          vim.notify('Loaded project-specific DAP configuration', vim.log.levels.INFO, { title = 'DAP' })
        else
          vim.notify('Error executing DAP config: ' .. tostring(run_err), vim.log.levels.ERROR, { title = 'DAP' })
        end
      else
        vim.notify('Error parsing DAP config: ' .. tostring(err), vim.log.levels.ERROR, { title = 'DAP' })
      end
    end
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
