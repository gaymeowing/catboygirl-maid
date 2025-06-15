--!native

--[[
	duster
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

type function Negate(t)
	return types.negationof(t)
end

type RBXScriptConnection = RBXScriptConnection

type Instance = Instance

export type Cleanable = IfAndUnion<
	| { [keyof<typeof(cleanup_method_names)>]: TableCleanupMethod }
	| () -> ()
	| thread,
	RBXScriptConnection, Instance
>

type DusterImpl<D> = {
	--[[
		Inserts a value to the `duster`, with the option of providing a `cleaner` to use to clean the value.
		This function is eqvilent to `table.insert`, except for the fact it allows for a `cleaner` function. 
		It is reccomended to use `table.insert` instead if possible, as it will be much more faster as it is [fast-called](https://luau.org/performance#optimized-libraries).
	]]
	insert: <V>(duster: D, value: V & Cleanable, cleaner: Cleaner<V>) -> (),
	--[[
		Cleans up and removes a `value` from the `duster` provided.
	]]
	remove: (duster: D, value: Cleanable) -> (),
	--[[
		Cleans up and removes every value in the `duster` provided.
	]]
	clear: (duster: D) -> (),
}

type DusterPrototype =  DusterImpl<Duster> & {
	__index: DusterPrototype,
}

export type Duster = typeof(setmetatable({} :: {
	values: { Cleanable }
}, {} :: DusterPrototype))

type Export = DusterImpl<{ Cleanable }> & {
	--[[
		Creates a new `duster` object.
	]]
	create: () -> Duster,
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

local function SET_REMOVE(t: { unknown }, index: number)
	t[index] = nil
end

local function insert<V>(duster: { Cleanable }, value: V & Cleanable, cleaner: Cleaner<V>)
	if cleaner then
		INSERT(duster, function()
			(cleaner :: any)(value)
		end)
	else
		INSERT(duster, value :: any)
	end
	return value
end

local function remove(duster: { Cleanable }, value: Cleanable)
	local index = FIND(duster, value)
	
	if index then
		CLEANUP(SWAP_REMOVE)
	end
end

local function clear(duster: { Cleanable })
	for index, value in duster do
		CLEANUP(nil, "continue")
	end
end

local duster = {} :: DusterPrototype

function duster.insert(duster, value, cleaner)
	insert(duster.values, value, cleaner)
end

function duster.remove(duster, value)
	remove(duster.values, value)
end

function duster.clear(duster)
	clear(duster.values)
end

local export = {
	insert = insert,
	remove = remove,
	clear = clear,
} :: Export

function export.create()
	return table.freeze(setmetatable({
		values = {}
	}, duster))
end

do

	-- checking if duster is running in roblox
	if game and script and elapsedTime and Vector3int16 then
		local connection = script.Changed:Connect(function() end)
		DISCONNECT = connection.Disconnect :: any
		DESTROY = game.Destroy :: any
		DISCONNECT(connection)
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
	
	duster.__index = duster
	table.freeze(duster)
end
	
return table.freeze(export) :: Export
