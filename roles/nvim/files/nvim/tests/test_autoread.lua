-- Test HyperFastAutoread autocommand registration and behavior
dofile("init.lua")

local autocmds = vim.api.nvim_get_autocmds({ group = "HyperFastAutoread" })
assert(#autocmds > 0, "HyperFastAutoread augroup has no autocommands registered")

local events = {}
for _, ac in ipairs(autocmds) do
    events[ac.event] = true
end

assert(events["FocusGained"] == true, "Missing FocusGained autocommand in HyperFastAutoread")
assert(events["BufEnter"] == true, "Missing BufEnter autocommand in HyperFastAutoread")

print("All autoread tests passed successfully.")
