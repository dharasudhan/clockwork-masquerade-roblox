-- Opens the built .rbxl with Lune's roblox library and checks the expected tree exists.
-- Usage: lune run scripts/verify_place.luau [build/ClockworkMasquerade.rbxl]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local path = process.args[1] or "build/ClockworkMasquerade.rbxl"
local game = roblox.deserializePlace(fs.readFile(path))

local expected = {
	{ "ReplicatedStorage.Remotes.Action", "RemoteEvent" },
	{ "ReplicatedStorage.Remotes.Aim", "RemoteEvent" },
	{ "ReplicatedStorage.Remotes.Notify", "RemoteEvent" },
	{ "ReplicatedStorage.Shared.Billboard", "ModuleScript" },
	{ "ServerScriptService.Server", "Script" },
	{ "ServerScriptService.Packages.ProfileStore", "ModuleScript" },
	{ "ServerStorage.Tests.framework.TestRunner", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Client", "LocalScript" },
}
for _, n in { "Match", "Nights", "Gadgets", "Manor", "Style", "Lighting", "Audio", "Bots", "Billboards", "DataTemplate", "Items" } do
	table.insert(expected, { "ReplicatedStorage.Shared.Config." .. n, "ModuleScript" })
end
for _, n in { "Roles", "Lantern", "Grid", "Outcome", "Loot", "Cooldown", "Channel", "Rewards", "SaveData", "ManorLayout", "BotBrain", "HudLayout", "RateLimiter", "Coplanar" } do
	table.insert(expected, { "ReplicatedStorage.Shared.Logic." .. n, "ModuleScript" })
end
for _, n in { "Build", "Clock", "Net", "Participants", "ManorBuilder", "LightingService", "ChestService", "GridService", "LanternService", "ChaseService", "BotService", "DataService", "MatchService", "ItemService", "LiftService" } do
	table.insert(expected, { "ServerScriptService.Server." .. n, "ModuleScript" })
end
for _, n in { "State", "Hud", "PromptFilter", "SoundManager", "Minimap" } do
	table.insert(expected, { "StarterPlayer.StarterPlayerScripts.Client." .. n, "ModuleScript" })
end

local failures = 0
for _, e in expected do
	local node: any = nil
	for i, part in string.split(e[1], ".") do
		node = if i == 1 then game:GetService(part) else node and node:FindFirstChild(part)
	end
	if node == nil or node.ClassName ~= e[2] then
		failures += 1
		print("[MISSING] " .. e[1] .. " (" .. e[2] .. ")" .. (if node then " got " .. node.ClassName else ""))
	end
end
local specs = game:GetService("ServerStorage").Tests.specs:GetChildren()
print(string.format("Specs in place: %d", #specs))
if #specs == 0 then
	failures += 1
end
local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
if server and server.Disabled then
	failures += 1
	print("[ERROR] Server script is disabled")
end
print(string.format("Place verification: %d checks, %d failure(s)", #expected + 2, failures))
process.exit(if failures == 0 then 0 else 1)
