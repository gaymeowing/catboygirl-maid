
--[[
	roblox
	roblox specific catboygirl maid test
]]

local maid = require("../maid")

local function TEST(cleanup: { maid.Cleanable }, call: (method: string, ...unknown) -> ())
	local connection = game.Changed:Connect(function() end)
	local part = Instance.new("Part")
	local has_destroyed = false
	
	part.Destroying:Connect(function()
		has_destroyed = true
	end)

	call("insert", connection)

	assert(cleanup[1] == connection, "cleanup array index 1 is not the connection")

	call("insert", part)

	assert(cleanup[2] == part, "cleanup array index 2 is not the part")

	call("remove", connection)

	assert(cleanup[1] == part, "connection wasn't removed from cleanup array")
	assert(connection.Connected == false, "connection wasn't disconnected")

	call("clear")

	assert(cleanup[1] == nil, "part wasn't removed from cleanup array")
	task.wait() -- waiting because defferred signaling
	assert(has_destroyed, "part wasn't destroyed")
end

local maid_class = maid.create()
local cleanup = {}

TEST(maid_class, function(method, ...)
	return maid_class[method](maid_class, ...)
end)

TEST(cleanup, function(method, ...)
	return maid[method](...)
end)
