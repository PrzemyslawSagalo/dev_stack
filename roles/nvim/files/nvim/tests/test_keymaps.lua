local M = {}

function M.run()
	local leader = vim.g.mapleader or " "
	local function normalize(lhs)
		return lhs:gsub("<[lL]eader>", leader):gsub("<Space>", " ")
	end

	local modes = { "n", "i", "v", "x", "t" }
	local keymaps_by_mode = {}

	for _, mode in ipairs(modes) do
		keymaps_by_mode[mode] = {}
		local maps = vim.api.nvim_get_keymap(mode)
		for _, map in ipairs(maps) do
			keymaps_by_mode[mode][map.lhs] = map
		end
	end

	-- 1. Assert Critical Normal Mode Keymaps Exist
	local normal_maps = keymaps_by_mode["n"]
	local required_normal = {
		"<leader>q",
		"<leader>y",
		"<leader>p",
		"<leader>h",
		"<leader>j",
		"<leader>k",
		"<leader>l",
	}

	for _, req in ipairs(required_normal) do
		local key = normalize(req)
		assert(normal_maps[key] ~= nil, "Expected mapping for " .. req .. " (key: '" .. key .. "')")
	end

	-- 2. Assert Critical Visual Mode Keymaps Exist
	local visual_maps = keymaps_by_mode["v"]
	local required_visual = {
		"<leader>y",
		"<leader>p",
	}
	for _, req in ipairs(required_visual) do
		local key = normalize(req)
		assert(visual_maps[key] ~= nil, "Expected visual mapping for " .. req .. " (key: '" .. key .. "')")
	end

	-- 3. Assert Zero Keymap Collisions in Insert Mode
	-- Verify <C-j> and <C-k> are NOT shadowed by Copilot (dedicated to cmp / text navigation)
	local insert_maps = keymaps_by_mode["i"]
	if insert_maps["<C-j>"] ~= nil then
		local desc = insert_maps["<C-j>"].desc or ""
		assert(not desc:find("Copilot"), "<C-j> in insert mode collided with Copilot")
	end
	if insert_maps["<C-k>"] ~= nil then
		local desc = insert_maps["<C-k>"].desc or ""
		assert(not desc:find("Copilot"), "<C-k> in insert mode collided with Copilot")
	end

	-- Verify Copilot mappings in insert mode do not collide with standard <C-c> exit
	if insert_maps["<C-c>"] ~= nil then
		local desc = insert_maps["<C-c>"].desc or ""
		assert(not desc:find("Copilot"), "<C-c> in insert mode should not be hijacked by Copilot")
	end
end

return M
