
--[[
	roblox
	roblox specific duster test
]]

local duster = require("../duster")

local function TEST(cleanup: { duster.Cleanable }, call: (method: string, ...unknown) -> ())
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

local duster_class = duster.create()
local cleanup = {}

TEST(duster_class, function(method, ...)
	return duster_class[method](duster_class, ...)
end)

TEST(cleanup, function(method, ...)
	return duster[method](...)
end)
