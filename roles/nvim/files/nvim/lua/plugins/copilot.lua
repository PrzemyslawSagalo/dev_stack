return {
    "github/copilot.vim",
    event = "InsertEnter",
    keys = {
        { "<C-c>", 'copilot#Accept("\\<CR>")', mode = "i", expr = true, replace_keycodes = false, desc = "Copilot Accept" },
        { "<C-k>", "<Plug>(copilot-next)", mode = "i", desc = "Copilot Next" },
        { "<C-j>", "<Plug>(copilot-previous)", mode = "i", desc = "Copilot Previous" },
        { "<C-w>", "<Plug>(copilot-accept-word)", mode = "i", desc = "Copilot Accept Word" },
        { "<C-]>", "<Plug>(copilot-dismiss)", mode = "i", desc = "Copilot Dismiss" },
    },
    config = function()
-- Configuration for github/copilot.vim
-- Replicating keybindings from previous copilot.lua setup

-- Disable default <Tab> mapping
vim.g.copilot_no_tab_map = true
vim.g.copilot_assume_mapped = true

-- Filetype Allowlist
vim.g.copilot_filetypes = {
  ["*"] = false,
  bash = true,
  c = true,
  cpp = true,
  go = true,
  groovy = true,
  html = true,
  json = true,
  kotlin = true,
  lua = true,
  markdown = true,
  python = true,
  rst = true,
  rust = true,
  sh = true,
  sql = true,
  toml = true,
  vim = true,
  yaml = true,
  zsh = true,
}

    end
}
