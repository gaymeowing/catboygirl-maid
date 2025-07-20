
--[[
	luau
	generic luau catboygirl maid test
]]

local cleanup_method_names = require("../cleanup_method_names")
local maid = require("@catboygirl-maid")

local function TEST(cleanup: { maid.Cleanable }, call: (key: string, ...unknown) -> ())
	local thread = coroutine.create(function() end)
	local cleaner_given_cleaner_table = false
	local function_has_ran = false
	local cleaner_has_ran = false
	local cleaner_table = {}

	local function cleanup_function()
		function_has_ran = true
	end

	local function cleaner(t)
		if t == cleaner_table then
			cleaner_given_cleaner_table = true
		end
		cleaner_has_ran = true
	end

	call("insert", thread)

	assert(cleanup[1] == thread, "cleanup array index 1 is not the thread")

	call("insert", cleanup_function)

	assert(cleanup[2] == cleanup_function, "cleanup array index 2 is not 'cleanup_function'")

	call("remove", thread)

	assert(cleanup[1] == cleanup_function, "cleanup array index 1 is not 'cleanup_function'")
	assert(coroutine.status(thread) == "dead", "thread didn't die")

	call("insert", cleaner_table, cleaner)

	assert(type(cleanup[2]) == "function", "cleanup array index 2 is not a function wrapping 'cleaner'")

	call("clear")

	assert(cleaner_given_cleaner_table, "'cleaner' wasn't given 'cleaner_table'")
	assert(function_has_ran, "'cleanup_function' didn't run")
	assert(#cleanup == 0, "cleanup array wasn't cleared")
	assert(cleaner_has_ran, "'cleaner' didn't run")
	
	local function class_cleanup_test(method_name: string, maid_method: string)
		local has_cleanup_been_called = false
		local maid_method = "clear"
		local class

		class = {
			[method_name] = function(provided_class)
				if not provided_class == class then
					error(`cleanup method '{method_name}' wasn't given the correct class table by {maid_method}`)
				end
				has_cleanup_been_called = true
			end
		}

		call("insert", class)
		call(maid_method, class)

		if not has_cleanup_been_called then
			error( `cleanup method '{method_name}' was not called by {maid_method}`)
		end	
	end

	for method_name in cleanup_method_names do
		class_cleanup_test(method_name, "remove")
		class_cleanup_test(method_name, "clear")
	end
end

local maid_class = maid.create()

assert(getmetatable(maid_class) ~= nil, "maid.create() doesn't set metatable")
assert(type(maid_class.values) == "table", "type of maid.values isn't table")

TEST(maid_class.values, function(method, ...)
	return maid_class[method](maid_class, ...)
end)

local cleanup = {}

TEST(cleanup, function(method, ...)
	return maid[method](cleanup, ...)
end)
