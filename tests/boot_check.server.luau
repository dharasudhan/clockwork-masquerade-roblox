-- Open Cloud Luau Execution entry: the real server boots the whole game in the engine.
--   python3 scripts/luau_exec.py build/ClockworkMasquerade.rbxl tests/boot_check.server.luau
-- Luau Execution sessions do not auto-run the place's Scripts, so this replays
-- src/server/init.server.luau (same modules, same order) when the game is not up yet.
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local function m(name)
	return require(Server:WaitForChild(name))
end
if workspace:GetAttribute("CM_Phase") == nil then
	m("ManorBuilder").build()
	m("LightingService").apply("Lobby")
	m("DataService").init()
	local MatchService = m("MatchService")
	MatchService.init()
	MatchService.start()
	task.wait(1)
end
local map = workspace:FindFirstChild("Map")
assert(map and map:FindFirstChild("Manor") and map:FindFirstChild("Lobby"), "map not built")
local Manor = require(game:GetService("ReplicatedStorage").Shared.Config.Manor)
assert(#map.Manor.Rooms:GetChildren() == #Manor.Rooms, "rooms")
local parts = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
assert(#map.Manor.Breakers:GetChildren() == 3, "breakers")
for _, b in map.Manor.Breakers:GetChildren() do
	local pp = b.Cabinet.PromptPoint
	assert(pp:FindFirstChild("Tamper") and pp:FindFirstChild("Repair"), "breaker prompts " .. b.Name)
end
local phase = workspace:GetAttribute("CM_Phase")
assert(phase == "Lobby" or phase == "Day", "phase " .. tostring(phase))
local left = workspace:GetAttribute("CM_PhaseEndsAt") - workspace:GetServerTimeNow()
assert(left > 0 and left <= 61, "countdown " .. left)
local Lighting = game:GetService("Lighting")
assert(Lighting:FindFirstChildOfClass("Atmosphere"), "no atmosphere")
assert(Lighting:GetAttribute("Preset") ~= nil, "no lighting preset")
-- the spawn location is on the terrace (players arrive in the lobby)
local spawn = map.Lobby:FindFirstChild("LobbySpawn")
assert(spawn and spawn:IsA("SpawnLocation"), "no lobby spawn")
-- collision groups for Wisps registered and non-colliding with characters
local PhysicsService = game:GetService("PhysicsService")
local ChaseService = m("ChaseService")
ChaseService.prepare({ model = nil })
assert(PhysicsService:IsCollisionGroupRegistered("CMWisps"), "Wisp collision group")
assert(PhysicsService:CollisionGroupsAreCollidable("CMWisps", "CMChars") == false, "wisps collide with characters")
print(string.format("BOOT OK: phase %s (%.0f s left), %d map parts, preset %s", phase, left, parts, tostring(Lighting:GetAttribute("Preset"))))
return phase, parts
