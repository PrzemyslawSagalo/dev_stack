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

	-- 1. Assert Critical Normal Mode Keymaps and RHS Destinations
	local normal_maps = keymaps_by_mode["n"]

	local bdelete_map = normal_maps[normalize("<leader>q")]
	assert(bdelete_map ~= nil, "Expected <leader>q mapping to exist")
	assert(bdelete_map.rhs == ":Bdelete<CR>", "Expected <leader>q to map to :Bdelete<CR>")

	local copy_map = normal_maps[normalize("<leader>y")]
	assert(copy_map ~= nil, "Expected <leader>y mapping to exist")
	assert(copy_map.rhs == '"+y', "Expected <leader>y to map to '+y")

	local paste_map = normal_maps[normalize("<leader>p")]
	assert(paste_map ~= nil, "Expected <leader>p mapping to exist")
	assert(paste_map.rhs == '"+p', "Expected <leader>p to map to '+p")

	-- Assert window navigation maps
	for _, dir in ipairs({ "h", "j", "k", "l" }) do
		local nav_map = normal_maps[normalize("<leader>" .. dir)]
		assert(nav_map ~= nil, "Expected window navigation mapping <leader>" .. dir)
		assert(nav_map.rhs:upper() == "<C-W>" .. dir:upper(), "Expected <leader>" .. dir .. " to map to <C-W>" .. dir)
	end

	-- 2. Assert Critical Visual Mode Keymaps Exist
	local visual_maps = keymaps_by_mode["v"]
	assert(visual_maps[normalize("<leader>y")] ~= nil, "Expected visual mode <leader>y mapping")
	assert(visual_maps[normalize("<leader>p")] ~= nil, "Expected visual mode <leader>p mapping")

	-- 3. Assert Zero Keymap Collisions in Insert Mode
	-- Verify <C-j> and <C-k> are NOT shadowed in insert mode
	local insert_maps = keymaps_by_mode["i"]
	if insert_maps["<C-j>"] ~= nil or insert_maps["<C-J>"] ~= nil then
		local map = insert_maps["<C-j>"] or insert_maps["<C-J>"]
		local desc = map.desc or ""
		assert(not desc:find("Copilot"), "<C-j> in insert mode collided with Copilot")
	end
	if insert_maps["<C-k>"] ~= nil or insert_maps["<C-K>"] ~= nil then
		local map = insert_maps["<C-k>"] or insert_maps["<C-K>"]
		local desc = map.desc or ""
		assert(not desc:find("Copilot"), "<C-k> in insert mode collided with Copilot")
	end

	-- Verify <C-c> is standard exit and not hijacked
	if insert_maps["<C-c>"] ~= nil or insert_maps["<C-C>"] ~= nil then
		local map = insert_maps["<C-c>"] or insert_maps["<C-C>"]
		local desc = map.desc or ""
		assert(not desc:find("Copilot"), "<C-c> in insert mode should not be hijacked by Copilot")
	end
end

return M
