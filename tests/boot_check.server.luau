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
assert(#map.Manor.Breakers:GetChildren() == #Manor.Breakers and #Manor.Breakers == 6, "breakers")
assert(parts < 6000, "part budget " .. parts)
-- StreamingEnabled in the real engine + Persistent key interactables (v1.0 RC)
assert(workspace.StreamingEnabled == true, "StreamingEnabled off")
-- (StreamingTargetRadius / MinRadius are not script-readable; scripts/verify_place.luau checks them in the file)
for _, n in { "Breakers", "Lifts", "Props" } do
	local g = map.Manor:FindFirstChild(n)
	assert(g and g:IsA("Model") and g.ModelStreamingMode == Enum.ModelStreamingMode.Persistent, n .. " not Persistent")
end
assert(map.Manor.Props:FindFirstChild("EvidenceBoard") and map.Manor.Props:FindFirstChild("ExitConsole"), "board/console under Props")
-- every lift stop has its prompts
for _, l in map.Manor.Lifts:GetChildren() do
	if l.Name == "LiftPanel" then
		assert(#l.LiftPoint:GetChildren() >= 1, "lift prompts")
	end
end
-- z-fighting check in the REAL engine (same detector as the local smoke)
local Coplanar = require(game:GetService("ReplicatedStorage").Shared.Logic.Coplanar)
local boxes, guis = {}, {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and d.Anchored and d.Transparency < 0.99 then
		local cf = d.CFrame
		local R = { cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z }
		local U = { cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z }
		local B = { -cf.LookVector.X, -cf.LookVector.Y, -cf.LookVector.Z }
		local shape = if d:IsA("Part") then d.Shape else Enum.PartType.Block
		local sz = d.Size
		local b
		if shape == Enum.PartType.Block then
			b = Coplanar.alignedBox(d:GetFullName(), cf.X, cf.Y, cf.Z, sz.X, sz.Y, sz.Z, R, U, B)
		elseif shape == Enum.PartType.Cylinder then
			local side = math.min(sz.Y, sz.Z) * 0.7071
			b = Coplanar.alignedBox(d:GetFullName(), cf.X, cf.Y, cf.Z, sz.X, side, side, R, U, B)
		end
		if b then
			table.insert(boxes, b)
			local faces = {}
			for _, g in d:GetChildren() do
				if g:IsA("SurfaceGui") or g:IsA("Decal") then
					local wf = Coplanar.worldFace(g.Face.Name, R, U, B)
					if wf then
						table.insert(faces, wf)
					end
				end
			end
			if #faces > 0 then
				guis[#boxes] = faces
			end
		end
	end
end
local zf = Coplanar.find(boxes, 0.01, 0.02, guis)
assert(#zf == 0, #zf .. " coplanar faces, e.g. " .. (zf[1] and (boxes[zf[1].a].name .. " vs " .. boxes[zf[1].b].name) or ""))
for _, b in map.Manor.Breakers:GetChildren() do
	local pp = b.Cabinet.PromptPoint
	assert(pp:FindFirstChild("Tamper") and pp:FindFirstChild("Repair"), "breaker prompts " .. b.Name)
end
local phase = workspace:GetAttribute("CM_Phase")
assert(phase == "Lobby" or phase == "Day", "phase " .. tostring(phase))
local left = workspace:GetAttribute("CM_PhaseEndsAt") - workspace:GetServerTimeNow()
assert(left > 0 and left <= 200, "countdown " .. left)
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
local ver = workspace:GetAttribute("CM_Version")
assert(type(ver) == "string" and string.find(ver, "v1.0", 1, true) == 1, "version " .. tostring(ver))
print(string.format("BOOT OK: " .. tostring(ver) .. ", streaming %s, phase %s (%.0f s left), %d map parts, %d boxes z-fight free, preset %s", tostring(workspace.StreamingEnabled), phase, left, parts, #boxes, tostring(Lighting:GetAttribute("Preset"))))
return phase, parts
