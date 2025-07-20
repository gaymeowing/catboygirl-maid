
--[[
	codegen
	replaces placeholders in catboygirl maid for testing & release
]]

local cleanup_method_names = require("../../cleanup_method_names")
local process = require("@lune/process")
local license = require("../license")
local fs = require("@lune/fs")

local function REMOVE_FROM_END(s: string, remove: string): string
	return if string.sub(s, #s - #remove, #s) == remove then
			string.sub(s, 1, #s - #remove)
		else
			s
end

local NEW_LINE_CHAR = if process.os == "windows" then "\r\n" else "\n"
local METHOD_CLEAN = REMOVE_FROM_END(fs.readFile("scripts/codegen/method_clean.luau"), NEW_LINE_CHAR)
local CLEANUP_SRC = REMOVE_FROM_END(fs.readFile("scripts/codegen/cleanup.luau"), NEW_LINE_CHAR)
local HOT_COMMENT_PATTERN = `%-%-![^%[%]]+{NEW_LINE_CHAR}`
local LICENSE = string.sub(license, 5, #license - 2)
local METHOD_NAMES_ARRAY = {} :: { string }
local SRC = fs.readFile("maid.luau")

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
			cleaner = string.gsub(cleaner, NEW_LINE_CHAR, "\n\t")
			method_cleaners[index] = cleaner
		end

		return `\t{table.concat(method_cleaners, "\n\t")}`
	end)

	CLEANUP_SRC = string.gsub(CLEANUP_SRC, "\n", "\n\t\t")
end

SRC = string.gsub(SRC, `local cleanup_method_names = require%("%./cleanup_method_names"%){NEW_LINE_CHAR}{NEW_LINE_CHAR}`, "")

SRC = string.gsub(SRC, "| { %[keyof<typeof%(cleanup_method_names%)>%]: TableCleanupMethod }", function()
	local type_union = table.create(#METHOD_NAMES_ARRAY) :: { string }

	for index, name in METHOD_NAMES_ARRAY do
		type_union[index] = `| \{ {name}: TableCleanupMethod }`
	end

	table.sort(type_union, function(a, b)
		return #a > #b
	end)

	return table.concat(type_union, "\n\t")
end)

SRC = string.gsub(SRC, "CLEANUP%((.-)%)", function(args)
	local setter, keyword = string.match(args, "([%w_]-), \"(.-)\"")
	local inner = CLEANUP_SRC

	if keyword then
		--keyword = string.sub(keyword, 2, #keyword - 1)
		inner = string.gsub(inner, "return", keyword)
	end

	if not setter then
		setter = args
	end

	return if setter ~= "nil" then
			string.gsub(inner, "REMOVE%(%)", `{setter}(maid :: any, index)`)
		else
			string.gsub(inner, "%s-REMOVE%(%)", "")
end)

do -- appending license to top of file
	local hot_comments = {}

	SRC = string.gsub(SRC, HOT_COMMENT_PATTERN, function(hot_comment)
		table.insert(hot_comments, hot_comment)
		return ""
	end)

	local header_start = string.find(SRC, "--[[", 1, true)
	local header_end = string.find(SRC, "]]", 1, true)

	if header_start and header_end then
		SRC = ((#hot_comments ~= 0 and table.concat(hot_comments)) or NEW_LINE_CHAR)
			.. string.sub(SRC, header_start, header_end - 1)
			.. LICENSE
			.. string.sub(SRC, header_end, #SRC)
	else
		error("maid.luau doesn't have a header comment")
	end
end

if string.sub(process.args[1], 1, 1) == "w" then
	fs.writeFile("maid.luau", SRC)
end

print(SRC)
return SRC
