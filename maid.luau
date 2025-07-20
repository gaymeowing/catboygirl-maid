--!native

--[[
	catboygirl maid
	fast and lightweight maid impl ( thats also better than janitor )
]]

local cleanup_method_names = require("./cleanup_method_names")

type TableCleanupMethod = <V>(self: (V & {})) -> ()
	
type Cleaner<V> = (((value: V) -> ()) | () -> ())?

--[[
	this exists because otherwise if the dev doesnt have roblox types in their lsp
	cleanable will become a type error
]]
type function IfAndUnion(a: type, b: type, c: type)
	return if b ~= types.any and c ~= types.any then 
			types.unionof(a, b, c) 
		else 
			a
end

type RobloxScriptConnection = RBXScriptConnection

type RobloxInstance = Instance

export type Cleanable = IfAndUnion<
	| { [keyof<typeof(cleanup_method_names)>]: TableCleanupMethod }
	| () -> ()
	| thread,
	RobloxScriptConnection, RobloxInstance
>

type MaidImpl<D> = {
	--[[
		Inserts a value to the `maid`, with the option of providing a `cleaner` to use to clean the value.
		This function is eqvilent to `table.insert`, except for the fact it allows for a `cleaner` function. 
		It is reccomended to use `table.insert` instead if possible, as it will be much more faster as it is [fast-called](https://luau.org/performance#optimized-libraries).
	]]
	insert: <V>(maid: D, value: V & Cleanable, cleaner: Cleaner<V>) -> V,
	--[[
		Cleans up and removes a `value` from the `maid` provided.
	]]
	remove: (maid: D, value: Cleanable) -> (),
	--[[
		Cleans up and removes every value in the `maid` provided.
	]]
	clear: (maid: D) -> (),
}

type MaidPrototype =  MaidImpl<Maid> & {
	__index: MaidPrototype,
}

export type Maid = typeof(setmetatable({} :: {
	values: { Cleanable }
}, {} :: MaidPrototype))

type Export = MaidImpl<{ Cleanable }> & {
	--[[
		Creates a new `maid` object.
	]]
	create: () -> Maid,
}

local DISCONNECT: (any) -> () = function() end
local CLOSE: (thread) -> () = coroutine.close
local DESTROY: (any) -> () = function() end
local INSERT = table.insert
local FIND = table.find
local TYPEOF = typeof

local function SWAP_REMOVE(t: { unknown }, index: number)
	if #t ~= 1 then
		local last = t[#t]
		t[index] = last
		t[#t] = nil
	else
		t[1] = nil
	end
end

local function insert<V>(maid: { Cleanable }, value: V & Cleanable, cleaner: Cleaner<V>): V
	if cleaner then
		INSERT(maid, function()
			(cleaner :: any)(value)
		end)
	else
		INSERT(maid, value :: any)
	end
	
	return value
end

local function remove(maid: { Cleanable }, value: Cleanable)
	local index = FIND(maid, value)
	
	if index then
		CLEANUP(SWAP_REMOVE)
	end
end

local function clear(maid: { Cleanable })
	for index, value in maid do
		CLEANUP(nil, "continue")
	end

	--[[
		using table.clear because im unsure if a gc pause can occur during iteration
		that will resize the cleanup array making it a hash mid iteration
	]]
	table.clear(maid)
end

local maid = {} :: MaidPrototype

function maid.insert(maid, value, cleaner)
	insert(maid.values, value, cleaner)
end

function maid.remove(maid, value)
	remove(maid.values, value)
end

function maid.clear(maid)
	clear(maid.values)
end

local export = {
	insert = insert,
	remove = remove,
	clear = clear,
} :: Export

function export.create()
	return table.freeze(setmetatable({
		values = {}
	}, maid))
end

do

	-- checking if catboygirl maid is running in roblox
	if game and script and elapsedTime and Vector3int16 then
		local connection = script.Changed:Connect(function() end)
		DISCONNECT = connection.Disconnect :: any
		DESTROY = game.Destroy :: any
		CLOSE = task.cancel :: any
	else
		local task_aliases = {
			"@std", "@lute", "@lune"
		}

		for _, path in task_aliases do
			local require_success, task = pcall(require, path .. "/task")

			if require_success then
				local index_success, cancel = pcall(function(task)
					return task.cancel
				end, task)

				if index_success then
					CLOSE = cancel :: any
					break
				end
			end
		end
	end
	
	maid.__index = maid
	table.freeze(maid)
end
	
return table.freeze(export) :: Export
