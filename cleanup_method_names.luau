
--[[
	cleanup method names
	a map of names sorted by (what i think is) the most common to least common
]]

return table.freeze({ 
	clear = 1, -- this is here because the cleanup method for catboygirl maid is 'clear'
	Destroy = 2,
	Disconnect = 3,
	destroy = 4,
	disconnect = 5,
	cleanup = 6,
	delete = 7,
	Clear = 8,
	Cleanup = 9,
	Delete = 10,
})
