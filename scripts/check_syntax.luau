-- Compiles every .luau file under src/, tests/ and vendor/ with Lune's Luau compiler
-- to catch syntax errors without Roblox Studio.  Usage: lune run scripts/check_syntax.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failures, count = 0, 0
local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.match(name, "%.luau$") then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				failures += 1
				print("[SYNTAX] " .. path .. ": " .. tostring(err))
			end
		end
	end
end
for _, d in { "src", "tests", "vendor", "scripts" } do
	if fs.isDir(d) then
		walk(d)
	end
end
print(string.format("Syntax check: %d files, %d error(s)", count, failures))
process.exit(if failures == 0 then 0 else 1)
