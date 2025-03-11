# duster

The fastest, and simplest maid out there for luau.

```luau
local RunService = game:GetService("RunService")
local duster = require("@duster")

local garbage = {}

duster.insert(garbage, RunService.PostSimulation:Connect(function()
	print("meow :3")
end))

print(typeof(duster[1])) -- "RBXScriptConnection"
task.wait(30)

duster.clear(garbage)
print(duster[1]) -- nil
```
