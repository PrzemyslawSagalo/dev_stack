if os.getenv("NVIM_SMOKE_TEST") == "1" then
    -- Smoke-test mode: validate syntax and module returns of all plugin specs without cloning or installing
    local config_dir = vim.fn.stdpath("config")
    local plugin_dir = config_dir .. "/lua/plugins"
    if vim.fn.isdirectory(plugin_dir) == 1 then
        for _, file in ipairs(vim.fn.globpath(plugin_dir, "*.lua", false, true)) do
            local mod = "plugins." .. vim.fn.fnamemodify(file, ":t:r")
            local ok, err = pcall(require, mod)
            if not ok then
                error("Plugin spec failed syntax validation: " .. mod .. " -> " .. tostring(err))
            end
        end
    end
    return
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
if not uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")
