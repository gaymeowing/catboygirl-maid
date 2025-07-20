
--[[
	release
	makes a release for catboygirl maid
]]

local process = require("@lune/process")
local codegen = require("./codegen")
local summon = require("./summon")
local fs = require("@lune/fs")

local before_codegen = fs.readFile("maid.luau")
local version = process.args[1]

if type(version) ~= "string" then
	error("first argument cannot be nil, must provide a version string for release")
end

fs.writeFile("maid.luau", codegen)
summon(`gh release create {version} maid.luau --generate-notes --draft`)
fs.writeFile("maid.luau", before_codegen)
print(string.match(summon(`gh release view {version} --json url`), ":\"(.*)\""))
