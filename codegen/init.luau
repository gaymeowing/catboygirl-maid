
--[[
	codegen
	replaces placeholders in duster for testing & release
]]

local cleanup_method_names = require("../cleanup_method_names")
local process = require("@lune/process")
local fs = require("@lune/fs")

local function REMOVE_FROM_END(s: string, remove: string): string
	return if string.sub(s, #s - #remove, #s) == remove then
			string.sub(s, 1, #s - #remove)
		else
			s
end

local NL_CHAR = if process.os == "windows" then "\r\n" else "\n"
local METHOD_CLEAN = REMOVE_FROM_END(fs.readFile("./codegen/method_clean.luau"), NL_CHAR)
local CLEANUP_SRC = REMOVE_FROM_END(fs.readFile("./codegen/cleanup.luau"), NL_CHAR)
local METHOD_NAMES_ARRAY = {} :: { string }
local SRC = fs.readFile("./duster.luau")

do -- populating METHOD_NAMES_ARRAY
	for name, order in cleanup_method_names do
		local current = METHOD_NAMES_ARRAY[order]

		if current then
			error(`cleanup method name '{name}' has the same order as '{current}'`)
		else
			METHOD_NAMES_ARRAY[order] = name
		end
	end

	table.freeze(METHOD_NAMES_ARRAY)
end

do -- formatting CLEANUP_SRC

	CLEANUP_SRC = string.gsub(CLEANUP_SRC, "\tMETHOD_CLEAN%(%)", function()
		local method_cleaners = table.create(#METHOD_NAMES_ARRAY)

		for index, method_name in METHOD_NAMES_ARRAY do
			local cleaner = string.gsub(METHOD_CLEAN, "KEY", method_name)
			local variable_name = string.lower(method_name)

			if variable_name ~= method_name then
				variable_name ..= "2"
			end

			cleaner = string.gsub(cleaner, "VARIABLE", variable_name)
			cleaner = string.gsub(cleaner, NL_CHAR, "\n\t")
			method_cleaners[index] = cleaner
		end

		return `\t{table.concat(method_cleaners, "\n\t")}`
	end)

	CLEANUP_SRC = string.gsub(CLEANUP_SRC, "\n", "\n\t\t")

end

SRC = string.gsub(SRC, `local cleanup_method_names = require%("%./cleanup_method_names"%){NL_CHAR}{NL_CHAR}`, "")

SRC = string.gsub(SRC, "| { %[keyof<typeof%(cleanup_method_names%)>%]: TableCleanupMethod }", function()
	local type_union = table.create(#METHOD_NAMES_ARRAY)

	for index, name in METHOD_NAMES_ARRAY do
		type_union[index] = `| \{ {name}: TableCleanupMethod }`
	end

	table.sort(type_union, function(a, b)
		return #a > #b
	end)

	return `{table.concat(type_union, "\n\t")}`
end)

SRC = string.gsub(SRC, "CLEANUP%((.-)%)", function(setter)
	return string.gsub(
		CLEANUP_SRC, "REMOVE%(%)", `{setter}(duster :: any, index)`
	) :: string
end)

fs.writeFile("duster.luau", SRC)