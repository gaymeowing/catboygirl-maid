# catboygirl maid
#### [![CI](https://github.com/gaymeowing/catboygirl-maid/actions/workflows/ci.yml/badge.svg)](https://github.com/gaymeowing/duster/actions/workflows/ci.yml)

The fastest, and simplest maid out there for luau & roblox. 

```luau
local RunService = game:GetService("RunService")
local maid = require("@maid")

local garbage = {}

maid.insert(garbage, RunService.PostSimulation:Connect(function()
	print("meow :3")
end))

print(typeof(maid[1])) --> "RBXScriptConnection"

maid.clear(garbage)
print(maid[1]) --> nil

local part_maid = maid.create()
local decal = Instance.new("Decal")
local part = Instance.new("Part")
local has_destroyed_part = false

part.Destroying:Connect(function()
	has_destroyed_part = true
end)

part_maid:insert(part)
part_maid:insert(decal)

print(part_maid.values[1]) --> Part
print(part_maid.values[2]) --> Decal

maid:remove(part)

print(part_maid.values[1]) --> Decal
print(part_maid.values[2]) --> nil
print(has_destroyed_part) --> true
```
