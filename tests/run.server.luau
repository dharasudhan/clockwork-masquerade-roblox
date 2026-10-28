-- Engine test entry. Sent as the script of an Open Cloud Luau Execution task
-- (scripts/luau_exec.py) against a test place built from this project; can also be pasted
-- into the Studio command bar. Runs every ModuleScript in ServerStorage.Tests.specs,
-- including *.engine.spec ones, prints a pass/fail summary and errors on failure so the
-- task ends in the FAILED state.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tests = ServerStorage:WaitForChild("Tests")
local TestRunner = require(Tests.framework.TestRunner)
local Shared = ReplicatedStorage:WaitForChild("Shared")

local function load(path: string)
	local node: Instance = Shared
	for _, part in string.split(path, "/") do
		node = node:WaitForChild(part, 5) or error("module not found: " .. path)
	end
	return require(node :: ModuleScript)
end

local modules = Tests.specs:GetChildren()
table.sort(modules, function(a, b)
	return a.Name < b.Name
end)
local specs = {}
for _, m in modules do
	if m:IsA("ModuleScript") then
		table.insert(specs, { name = m.Name, fn = require(m) })
	end
end

local result = TestRunner.run(specs, load, print)
if result.failed > 0 then
	error(string.format("%d test(s) failed", result.failed))
end
return result.passed, result.failed
