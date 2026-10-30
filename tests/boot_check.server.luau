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
assert(phase == "Lobby" or phase == "Intro" or phase == "Day", "phase " .. tostring(phase))
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
-- v1.1/v1.2 modules load in the real engine (quests, season, manor events, escalation)
local QuestService = m("QuestService")
local EventService = m("EventService")
assert(type(QuestService.onMatchEnd) == "function" and type(QuestService.seasonXp) == "function", "QuestService")
local SharedR = game:GetService("ReplicatedStorage").Shared
local Esc = require(SharedR.Logic.Escalation)
local EscCfg = require(SharedR.Config.Escalation)
assert(Esc.forNight(EscCfg, 3).rebootBoost > 1, "escalation config")
assert(require(SharedR.Config.Season).StartsAt == 0, "season must stay unscheduled until Gate 4/5")
EventService._fire("ClockworkRush")
assert(workspace:GetAttribute("CM_EventSpeed") ~= nil, "manor event dial")
EventService._clearMods()
-- v1.4.1 night shroud on REAL engine rigs (R15 + R6 from HumanoidDescription), dressed like a
-- player avatar: shirt, pants, t-shirt, a hat accessory, body colours. On -> nothing identifying
-- left, one uniform cloak; off -> everything back exactly.
local ShroudService = m("ShroudService")
local ShroudL = require(SharedR.Logic.Shroud)
local shroudSig = nil
local shroudRigs = 0
for _, rigType in { Enum.HumanoidRigType.R15, Enum.HumanoidRigType.R6 } do
	local okRig, rig = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = Color3.fromRGB(200, 150, 100)
		desc.TorsoColor = Color3.fromRGB(10, 120, 200)
		return game:GetService("Players"):CreateHumanoidModelFromDescription(desc, rigType)
	end)
	if okRig and rig then
		shroudRigs += 1
		rig.Name = "ShroudProbe" .. rigType.Name
		rig.Parent = workspace
		rig:PivotTo(CFrame.new(0, 200, 0))
		for _, cls in { "Shirt", "Pants", "ShirtGraphic" } do
			Instance.new(cls).Parent = rig
		end
		local hum = rig:FindFirstChildOfClass("Humanoid")
		local acc = Instance.new("Accessory")
		acc.Name = "ProbeHat"
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(1, 1, 1)
		handle.CanCollide = false
		handle.Parent = acc
		local att = Instance.new("Attachment")
		att.Name = "HatAttachment"
		att.Parent = handle
		hum:AddAccessory(acc)
		local head = rig:FindFirstChild("Head")
		local headColor = head.Color
		local rootSize = rig.HumanoidRootPart.Size
		local before = #rig:GetChildren()
		assert(ShroudService.apply(rig), "shroud apply " .. rigType.Name)
		for _, c in rig:GetChildren() do
			assert(not (c:IsA("Accessory") or c:IsA("Clothing") or c:IsA("ShirtGraphic") or c:IsA("BodyColors")), "shroud left " .. c.ClassName .. " on " .. rigType.Name)
		end
		local cloak = rig:FindFirstChild(ShroudL.ModelName)
		assert(cloak and #cloak:GetChildren() >= 10 and #cloak:GetChildren() <= ShroudL.MaxParts, "cloak parts " .. rigType.Name)
		for _, p in cloak:GetChildren() do
			assert(p.CanCollide == false and p.CanQuery == false and p.CanTouch == false and p.Massless and not p.Anchored, "cloak part physics " .. p.Name)
		end
		assert(rig.HumanoidRootPart.Size == rootSize, "hitbox changed")
		local names = {}
		for _, p in cloak:GetChildren() do
			if p.Name ~= "SleeveL" and p.Name ~= "SleeveR" then
				table.insert(names, p.Name .. ":" .. p.Material.Name .. ":" .. p.Color:ToHex())
			end
		end
		table.sort(names)
		local sig = table.concat(names, "|")
		assert(shroudSig == nil or shroudSig == sig, "R15 and R6 shrouds differ")
		shroudSig = sig
		task.wait(0.2) -- let physics step with the welded cloak
		assert(cloak:FindFirstChild("Hood") and (cloak.Hood.Position - head.Position).Magnitude < 2, "hood not welded to the head")
		assert(ShroudService.remove(rig), "shroud remove " .. rigType.Name)
		task.wait(0.4) -- accessory re-attach settles
		assert(not rig:FindFirstChild(ShroudL.ModelName) and rig:FindFirstChild("ProbeHat") and rig:FindFirstChildOfClass("Shirt") and rig:FindFirstChildOfClass("BodyColors"), "not restored " .. rigType.Name)
		assert(head.Color == headColor and #rig:GetChildren() == before, "colours/children not restored " .. rigType.Name)
		local probeHat = rig:FindFirstChild("ProbeHat")
		assert(probeHat.Handle:FindFirstChildWhichIsA("JointInstance") or probeHat.Handle:FindFirstChildWhichIsA("Constraint"), "hat not re-attached " .. rigType.Name)
		rig:Destroy()
	end
end
assert(shroudRigs == 2 and ShroudService.count() == 0, "shroud probe rigs " .. shroudRigs)
-- v1.4.1 Dawn Scatter spots in the REAL map: a floor right below every spot and nothing solid
-- where a character would land (walls, props, cabinets, breakers, chests)
local ScatterL = require(SharedR.Logic.Scatter)
local LayoutR = require(SharedR.Logic.ManorLayout)
local rpDown = RaycastParams.new()
rpDown.FilterType = Enum.RaycastFilterType.Include
rpDown.FilterDescendantsInstances = { map }
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Include
op.FilterDescendantsInstances = { map }
local spots, badSpots = 0, {}
for _, c in ScatterL.candidates(Manor, LayoutR) do
	for _, sp in c.spots do
		spots += 1
		local hit = workspace:Raycast(Vector3.new(sp.x, c.y + 3, sp.z), Vector3.new(0, -6, 0), rpDown)
		local solid = {}
		for _, part in workspace:GetPartBoundsInBox(CFrame.new(sp.x, c.y + 3.2, sp.z), Vector3.new(2.2, 5, 2.2), op) do
			if part.CanCollide and part.Transparency < 1 then
				table.insert(solid, part.Name)
			end
		end
		if not hit or #solid > 0 then
			table.insert(badSpots, string.format("%s(%.0f,%.0f):%s%s", c.id, sp.x, sp.z, if hit then "" else "nofloor ", table.concat(solid, ",")))
		end
	end
end
assert(#badSpots == 0, "unsafe scatter spots: " .. table.concat(badSpots, "; "))
-- v1.6: Hall of Fame board, Castle Sterling gatehouse, Grotto Baths pool (no collision, real
-- floor under the water, scatter spots in the grotto clear of the basin)
local fame = map.Lobby:FindFirstChild("FameBoard")
assert(fame and fame:FindFirstChild("Row10", true), "FameBoard rows")
assert(map.Lobby:FindFirstChild("Gatehouse") and map:FindFirstChild("Facade"):FindFirstChild("Parapet"), "castle geometry")
local gd = map.Manor.Decor:FindFirstChild("Decor_grotto")
assert(gd and gd:FindFirstChild("PoolWater"), "grotto pool")
for _, d in gd:GetDescendants() do
	if d:IsA("BasePart") then
		assert(not d.CanCollide, "grotto decor collides " .. d.Name)
	end
end
local pool = Manor.Pools[1]
assert(workspace:Raycast(Vector3.new(pool.x, -16, pool.z), Vector3.new(0, -8, 0), rpDown), "no floor under the pool")
local grottoSpots = 0
for _, c in ScatterL.candidates(Manor, LayoutR) do
	if c.id == "grotto" then
		grottoSpots = #c.spots
	end
end
assert(grottoSpots > 0, "grotto has no scatter spot")
assert(type(require(SharedR.Logic.Score).encode) == "function", "Score logic")
local ver = workspace:GetAttribute("CM_Version")
assert(type(ver) == "string" and string.find(ver, "v1.6", 1, true) == 1, "version " .. tostring(ver))
print(string.format("BOOT OK: " .. tostring(ver) .. ", fame board + gatehouse + grotto pool OK (" .. grottoSpots .. " grotto scatter spots), shroud R15+R6 on/off OK, " .. spots .. " scatter spots safe, streaming %s, phase %s (%.0f s left), %d map parts, %d boxes z-fight free, preset %s", tostring(workspace.StreamingEnabled), phase, left, parts, #boxes, tostring(Lighting:GetAttribute("Preset"))))
return phase, parts
