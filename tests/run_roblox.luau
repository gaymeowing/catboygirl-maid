
--[[
	run roblox
	runs the roblox test in roblox
]]

local codegen = require("../codegen")
local serde = require("@lune/serde")
local net = require("@lune/net")
local fs = require("@lune/fs")

local TEST_SRC = fs.readFile("./tests/roblox.luau")

TEST_SRC = string.gsub(TEST_SRC, "duster%.Cleanable", "Cleanable")
TEST_SRC = string.gsub(TEST_SRC, "local duster = require%(\"%.%./duster\"%)", "")
codegen = string.gsub(codegen, "return table%.freeze%(export%) :: Export", "local duster = table.freeze(export)")




-- https://github.com/Quenty/NevermoreEngine/blob/4b477e889bc4aa7cf4c2179cdd6bf93b872a3e21/tests/cloud/publish-test-place.luau
-- https://github.com/JohnnyMorganz/luau-lsp/blob/main/plugin/cloud/execute_task.luau

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local task = require("@lune/task")

local ROBLOX_API_KEY = assert(process.env.ROBLOX_UNIT_TEST_API_KEY, "Missing ENV variable: ROBLOX_UNIT_TEST_API_KEY")
local UNIVERSE_ID = 7432926990
local PLACE_ID = 99773575985051

assert(#process.args == 2, "Usage: lune run publish_plugin.luau PLACE_FILE CLOUD_TASK_FILE")
local PLACE_FILE = process.args[1]
local CLOUD_TASK_FILE = process.args[2]

print(`Attempting to execute {CLOUD_TASK_FILE}`)

local SCRIPT_CONTENTS = fs.readFile(CLOUD_TASK_FILE)

print("=== SCRIPT CONTENTS ===")
print(SCRIPT_CONTENTS)
print("=== END ===")

type LuauTask = {
	path: string,
	createTime: string,
	updateTime: string,
	user: string,
	state: "STATE_UNSPECIFIED" | "QUEUED" | "PROCESSING" | "CANCELLED" | "COMPLETE" | "FAILED",
	script: string,
}

local function createTask(universeId: number, placeId: number, placeVersion: number, scriptContents: string): LuauTask
	local response = net.request({
		method = "POST",
		url = `https://apis.roblox.com/cloud/v2/universes/{universeId}/places/{placeId}/versions/{placeVersion}/luau-execution-session-tasks`,
		headers = {
			["Content-Type"] = "application/json",
			["X-API-Key"] = ROBLOX_API_KEY,
		},
		body = net.jsonEncode({
			script = scriptContents,
		}),
	})

	if not response.ok then
		error(`Create task request failed: {response.body}`)
	end

	return net.jsonDecode(response.body)
end

local function pollForTaskCompletion(taskPath: string)
	print("Polling for task status...")

	while true do
		local response = net.request({
			method = "GET",
			url = `https://apis.roblox.com/cloud/v2/{taskPath}`,
			headers = {
				["X-API-Key"] = ROBLOX_API_KEY,
			},
		})

		if not response.ok then
			error(`Poll task completion failed: {response.body}`)
		end

		local cloudTask = net.jsonDecode(response.body)
		if cloudTask.state ~= "PROCESSING" then
			return cloudTask
		else
			print(".")
			task.wait(3)
		end
	end
end

local function getTaskLogs(taskPath: string)
	local response = net.request({
		method = "GET",
		url = `https://apis.roblox.com/cloud/v2/{taskPath}/logs`,
		headers = {
			["X-API-Key"] = ROBLOX_API_KEY,
		},
	})

	if not response.ok then
		error(`Get task logs failed: {response.body}`)
	end

	local testsSuccessful = true
	local decoded
	for _, message in serde.decode("json", response.body).luauExecutionSessionTaskLogs[1].messages do
		local cleanMessage = message:gsub("\27%[[%d;]*%a", "")
		local failedSuites = string.match(cleanMessage, "Test Suites:%s*(%d+)%s+failed")
		local failedTests = string.match(cleanMessage, "Tests:%s*(%d+)%s+failed")

		if (failedSuites and tonumber(failedSuites) > 0) or (failedTests and tonumber(failedTests) > 0) then
			testsSuccessful = false
			break
		end
	end

	return testsSuccessful, table.concat(serde.decode("json", response.body).luauExecutionSessionTaskLogs[1].messages, "\n")
end

local function runLuauTask(universeId: number, placeId: number, placeVersion: number, scriptContents: string)
	print("Executing Luau task...")

	local cloudTask = createTask(universeId, placeId, placeVersion, scriptContents)
	cloudTask = pollForTaskCompletion(cloudTask.path)
	local testsSuccessful, taskLogs = getTaskLogs(cloudTask.path)

	print(taskLogs)

	if cloudTask.state == "COMPLETE" then
		if testsSuccessful then
			print("Tests passed!")
		else
			error("Tests failed! See output above for more information.")
		end
	else
		print(cloudTask)
		error("Luau task failed")
	end
end

local placeVersion = uploadPlaceFile(UNIVERSE_ID, PLACE_ID, PLACE_FILE)
runLuauTask(UNIVERSE_ID, PLACE_ID, placeVersion, SCRIPT_CONTENTS)
