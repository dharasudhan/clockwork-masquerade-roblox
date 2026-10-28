-- Local unit-test entry for Lune:  lune run tests/run.lune.luau  (from the game/ folder)
-- Runs every tests/specs/*.spec.luau except *.engine.spec.luau (those need Roblox).
local fs = require("@lune/fs")
local process = require("@lune/process")

local TestRunner = require("./framework/TestRunner")

local SHARED = "../src/shared/"

local cache = {}
local function load(path: string)
	if cache[path] == nil then
		cache[path] = (require :: any)(SHARED .. path)
	end
	return cache[path]
end

local specs = {}
local names = fs.readDir("tests/specs")
table.sort(names)
for _, file in names do
	if string.match(file, "%.spec%.luau$") and not string.match(file, "%.engine%.spec%.luau$") then
		local modName = string.gsub(file, "%.luau$", "")
		table.insert(specs, { name = modName, fn = (require :: any)("./specs/" .. modName) })
	end
end

local result = TestRunner.run(specs, load)
process.exit(if result.failed == 0 then 0 else 1)
