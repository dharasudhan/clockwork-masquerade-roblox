-- Builds Sterling Manor (3 levels, greybox with a steampunk dressing) and the lobby terrace from
-- Config/Manor + Logic/ManorLayout. All static geometry comes from ManorLayout.geometry: walls
-- butt-join at corners, slabs are inset to the walls' inner faces, trim sits ON wall faces and
-- stops short of door frames, so no two visible faces share a plane (no z-fighting; the engine
-- smoke + boot check run Logic/Coplanar over every part).
-- Returns handles other services use:
--   roomLights[roomId] = { PointLight }, breakers[id] = { model, base, light, label, x, y, z, ... },
--   lifts[roomId] = { panel, room }
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Manor = require(Shared.Config.Manor)
local Style = require(Shared.Config.Style)
local ManorLayout = require(Shared.Logic.ManorLayout)
local Billboard = require(Shared.Billboard)
local Build = require(script.Parent.Build)
local ManorDecor = require(script.Parent.ManorDecor)
local ArtGui = require(Shared.ArtGui)

local ManorBuilder = {}

local T = Style.WallThickness
local LH = Manor.LevelHeight

local built: any = nil
local buildFameBoard, buildGatehouse -- v1.6.1 / v1.5.1 (defined with the lobby)

local Mat = Enum.Material

-- per-kind defaults; walls, wainscot, floors, ceilings, trim and steps take the room's theme
local Look = {
	DoorPost = { "Brass", Mat.Metal, true },
	Lintel = { "Brass", Mat.Metal, false },
	NamePlate = { "WalnutDark", Mat.Wood, false },
	BalconyRail = { "Gold", Mat.Metal },
	Baluster = { "BrassDark", Mat.Metal, false },
}

local function mat(name: string?): Enum.Material
	local ok, m = pcall(function()
		return (Enum.Material :: any)[name or "SmoothPlastic"]
	end)
	return if ok and m then m else Mat.SmoothPlastic
end

local function themeOf(r)
	return ManorDecor.themeOf(r)
end

local function boxPart(parent: Instance, b, color, material, collide: boolean?)
	return Build.part({
		name = b.kind, parent = parent, size = Vector3.new(b.sx, b.sy, b.sz), pos = Vector3.new(b.cx, b.cy, b.cz),
		color = ArtGui.rgb(color), material = material, collide = if collide == nil then true else collide,
		shadow = b.kind ~= "Rail" and b.kind ~= "Crown" and b.kind ~= "Baluster",
	})
end

local function plateText(surface: Instance, face: Enum.NormalId, title: string, sub: string)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Sign" .. face.Name
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0.2
	sg.MaxDistance = 70
	sg.Parent = surface
	local t1 = Instance.new("TextLabel")
	t1.Name = "Room"
	t1.BackgroundTransparency = 1
	t1.Size = UDim2.fromScale(1, 0.62)
	t1.Font = Enum.Font.Sarpanch
	t1.TextScaled = true
	t1.TextColor3 = Build.color("Brass")
	t1.Text = string.upper(title)
	t1.Parent = sg
	local t2 = t1:Clone()
	t2.Name = "Floor"
	t2.Position = UDim2.fromScale(0, 0.62)
	t2.Size = UDim2.fromScale(1, 0.36)
	t2.Font = Enum.Font.GothamBold
	t2.TextColor3 = Build.color("TealNeon")
	t2.Text = sub
	t2.Parent = sg
	return sg
end

local function signFor(target, doorLevel: number): (string, string)
	if target.stair then
		local lo, hi = ManorLayout.span(target)
		local goUp = doorLevel == lo
		local dest = ManorLayout.levelName(Manor, if goUp then hi else lo)
		return target.name, (if goUp then "UP TO " else "DOWN TO ") .. string.upper(dest)
	elseif target.lift then
		return target.name, "ALL FLOORS"
	end
	return target.name, string.upper(ManorLayout.levelName(Manor, doorLevel))
end

local function chandelier(parent: Instance, x: number, z: number, top: number, roomId: string, lights, drop: number, shadows: boolean, dayColor: Color3?)
	local m = Instance.new("Model")
	m.Name = "Chandelier"
	m:SetAttribute("Room", roomId)
	local chain = drop
	Build.part({ name = "Chain", parent = m, size = Vector3.new(0.2, chain, 0.2), pos = Vector3.new(x, top - chain / 2, z), color = "Brass", material = Enum.Material.Metal, collide = false, shadow = false })
	Build.part({ name = "Ring", parent = m, shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, 4.2, 4.2), cf = CFrame.new(x, top - chain - 0.2, z) * CFrame.Angles(0, 0, math.rad(90)), color = "Brass", material = Enum.Material.Metal, collide = false, shadow = false })
	local core = Build.part({ name = "Core", parent = m, shape = Enum.PartType.Ball, size = Vector3.new(1.3, 1.3, 1.3), pos = Vector3.new(x, top - chain - 0.9, z), color = "Warm", material = Enum.Material.Neon, collide = false, shadow = false })
	local light = Build.light(core, "PointLight", Build.color("Warm"), 1.8, 30, shadows)
	light:SetAttribute("Room", roomId)
	if dayColor then
		light:SetAttribute("DayColor", dayColor)
		core.Color = dayColor
		light.Color = dayColor
	end
	m.Parent = parent
	table.insert(lights, light)
	return m
end

local function gear(parent: Instance, cf: CFrame, radius: number)
	local g = Instance.new("Model")
	g.Name = "Gear"
	Build.part({ name = "Disc", parent = g, shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, radius * 2, radius * 2), cf = cf, color = "Brass", material = Enum.Material.Metal, collide = false })
	for i = 0, 7 do
		local a = i * math.pi / 4
		-- teeth are thinner than the disc so their faces never share the disc's cap planes
		Build.part({ name = "Tooth", parent = g, size = Vector3.new(0.34, 0.8, 0.9), cf = cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, radius + 0.3, 0), color = "BrassDark", material = Enum.Material.Metal, collide = false, shadow = false })
	end
	Build.part({ name = "Hub", parent = g, shape = Enum.PartType.Cylinder, size = Vector3.new(0.6, radius * 0.7, radius * 0.7), cf = cf, color = "TealNeon", material = Enum.Material.Neon, collide = false, shadow = false })
	g.Parent = parent
end

local FaceDir = { E = Vector3.new(1, 0, 0), W = Vector3.new(-1, 0, 0), S = Vector3.new(0, 0, 1), N = Vector3.new(0, 0, -1) }

local function breakerModel(parent: Instance, spec, roomTop: number)
	local m = Instance.new("Model")
	m.Name = "Breaker_" .. spec.id
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	m:SetAttribute("BreakerId", spec.id)
	m:SetAttribute("Level", spec.level)
	local dir = FaceDir[spec.face]
	local origin = Vector3.new(spec.x, spec.y, spec.z)
	local cf = CFrame.lookAt(origin, origin + dir) -- -Z (front) faces the room
	local base = Build.part({ name = "Cabinet", parent = m, size = Vector3.new(4.5, 6.5, 2), cf = cf * CFrame.new(0, 3.25, 0), color = "Copper", material = Enum.Material.Metal })
	Build.part({ name = "Panel", parent = m, size = Vector3.new(3.6, 4.6, 0.2), cf = cf * CFrame.new(0, 3.6, -1.05), color = "Iron", material = Enum.Material.Metal })
	Build.part({ name = "Gauge", parent = m, shape = Enum.PartType.Cylinder, size = Vector3.new(0.2, 1.4, 1.4), cf = cf * CFrame.new(-0.8, 4.8, -1.2) * CFrame.Angles(0, math.rad(90), 0), color = "TealNeon", material = Enum.Material.Neon, collide = false })
	Build.part({ name = "Lever", parent = m, size = Vector3.new(0.35, 1.8, 0.35), cf = cf * CFrame.new(0.9, 3.4, -1.4) * CFrame.Angles(math.rad(-25), 0, 0), color = "Brass", material = Enum.Material.Metal, collide = false })
	local status = Build.part({ name = "Status", parent = m, shape = Enum.PartType.Ball, size = Vector3.new(0.8, 0.8, 0.8), cf = cf * CFrame.new(0.9, 5.5, -1.2), color = "BreakerOk", material = Enum.Material.Neon, collide = false })
	local light = Build.light(status, "PointLight", Build.color("BreakerOk"), 1.5, 12)
	local pipeLen = roomTop - spec.y - 6.5
	for i = -1, 1, 2 do
		Build.part({ name = "Pipe", parent = m, shape = Enum.PartType.Cylinder, size = Vector3.new(pipeLen, 0.6, 0.6), cf = cf * CFrame.new(i * 1.6, 6.5 + pipeLen / 2, 0.3) * CFrame.Angles(0, 0, math.rad(90)), color = "Copper", material = Enum.Material.Metal, collide = false })
	end
	local att = Instance.new("Attachment")
	att.Name = "PromptPoint"
	att.Position = Vector3.new(0, 0, -1.2)
	att.Parent = base
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Color = ColorSequence.new(Build.color("VioletNeon"))
	sparks.LightEmission = 1
	sparks.Rate = 25
	sparks.Lifetime = NumberRange.new(0.2, 0.5)
	sparks.Speed = NumberRange.new(6, 10)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Size = NumberSequence.new(0.25)
	sparks.Enabled = false
	sparks.Parent = att
	local label = Billboard.new("Breaker", "Label")
	label.StudsOffset = Vector3.new(0, 4.4, 0)
	label.Parent = base
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Sarpanch
	text.TextScaled = true
	text.TextColor3 = Build.color("Cream")
	text.TextStrokeTransparency = 0.4
	text.Text = "BREAKER " .. spec.id
	text.Parent = label
	m.PrimaryPart = base
	m.Parent = parent
	return { model = m, base = base, status = status, light = light, sparks = sparks, label = text, prompt = att, x = spec.x, y = spec.y, z = spec.z, room = spec.room, level = spec.level, standX = spec.standX, standZ = spec.standZ }
end

-- ---- lift ----------------------------------------------------------------------------------
local function liftPanel(parent: Instance, r)
	local b = ManorLayout.baseY(Manor, r)
	local cx = (r.x0 + r.x1) / 2
	local z = r.z1 - T
	local panel = Build.part({ name = "LiftPanel", parent = parent, size = Vector3.new(3, 4, 0.4), pos = Vector3.new(cx, b + 4, z - 0.25), color = "Brass", material = Enum.Material.Metal })
	local dial = Build.part({ name = "LiftDial", parent = parent, shape = Enum.PartType.Cylinder, size = Vector3.new(0.2, 1.6, 1.6), cf = CFrame.new(cx, b + 7.2, z - 0.3) * CFrame.Angles(0, math.rad(90), 0), color = "TealNeon", material = Enum.Material.Neon, collide = false })
	Build.light(dial, "PointLight", Build.color("TealNeon"), 0.8, 10)
	-- the cage: brass bars around the shaft (non-colliding)
	for _, dx in { -4, 4 } do
		Build.part({ name = "CageBar", parent = parent, shape = Enum.PartType.Cylinder, size = Vector3.new(ManorLayout.height(Manor, r) - 0.2, 0.3, 0.3), cf = CFrame.new(cx + dx, b + ManorLayout.height(Manor, r) / 2, (r.z0 + r.z1) / 2) * CFrame.Angles(0, 0, math.rad(90)), color = "BrassDark", material = Enum.Material.Metal, collide = false })
	end
	local att = Instance.new("Attachment")
	att.Name = "LiftPoint"
	att.Position = Vector3.new(0, 0, -0.4)
	att.Parent = panel
	return { panel = panel, prompt = att, room = r.id, level = r.level }
end

-- ---- lobby + facade + grounds --------------------------------------------------------------
-- A SurfaceGui text line (shared by the Hall of Fame board and the gatehouse sign).
local function gline(sg: Instance, name: string, text: string, y: number, h: number, color: string, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0.05, y)
	l.Size = UDim2.fromScale(0.9, h)
	l.Font = font or Enum.Font.GothamBold
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Build.color(color)
	l.Text = text
	l.Parent = sg
	return l
end

-- v1.6.1 Hall of Fame: a walnut board on the terrace's west rail, facing the spawn. FameService
-- paints Row1..Row10 (top 10 all-time match wins) from the OrderedDataStore.
buildFameBoard = function(lobby: Instance, L)
	local cz = (L.z0 + L.z1) / 2
	local x = L.x0 + 1.5
	local board = Build.part({ name = "FameBoard", parent = lobby, size = Vector3.new(0.6, 9, 12), pos = Vector3.new(x, 7.5, cz), color = "WalnutDark", material = Enum.Material.Wood })
	for _, dz in { -6.45, 6.45 } do
		Build.part({ name = "FamePost", parent = lobby, size = Vector3.new(0.8, 12.5, 0.8), pos = Vector3.new(x, 6.65, cz + dz), color = "Brass", material = Enum.Material.Metal })
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Fame"
	sg.Face = Enum.NormalId.Right -- +x: towards the spawn
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = board
	local h = gline(sg, "Header", "HALL OF FAME", 0.03, 0.14, "Brass", Enum.Font.Sarpanch)
	h.TextXAlignment = Enum.TextXAlignment.Center
	local sub = gline(sg, "Sub", "All-time match wins", 0.17, 0.07, "TealNeon")
	sub.TextXAlignment = Enum.TextXAlignment.Center
	for i = 1, 10 do
		gline(sg, "Row" .. i, if i == 1 then "No champions yet - win a match to be the first!" else "", 0.26 + (i - 1) * 0.071, 0.062, if i <= 3 then "Gold" else "Cream", Enum.Font.GothamBold)
	end
	return board
end

-- v1.5.1 Castle Sterling: gatehouse on the terrace's south edge, facing the spawn. The brass rail
-- and the invisible boundary pass straight through both towers (nobody leaves the terrace).
-- Kept low (arch top y ~17) so the intro's first camera pass flies over it.
buildGatehouse = function(lobby: Instance, L)
	local g = Instance.new("Model")
	g.Name = "Gatehouse"
	local z = L.z1
	for _, sx in { -1, 1 } do
		local x = sx * 10
		Build.part({ name = "GatePlinth", parent = g, size = Vector3.new(6, 3, 6), pos = Vector3.new(x, 0.15, z), color = "Walnut", material = Enum.Material.Wood })
		Build.part({ name = "GateTower", parent = g, size = Vector3.new(5, 16.7, 5), pos = Vector3.new(x, 1.35 + 16.7 / 2, z), color = "Cream", material = Enum.Material.Marble })
		Build.part({ name = "GateParapet", parent = g, size = Vector3.new(5.8, 1.5, 5.8), pos = Vector3.new(x, 18.65, z), color = "Walnut", material = Enum.Material.Wood })
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			Build.part({ name = "GateMerlon", parent = g, size = Vector3.new(1.2, 1.3, 1.2), pos = Vector3.new(x + c[1] * 2.15, 20.0, z + c[2] * 2.15), color = "Walnut", material = Enum.Material.Wood })
		end
	end
	local arch = Build.part({ name = "GateArch", parent = g, size = Vector3.new(15.2, 3, 1.6), pos = Vector3.new(0, 14.5, z), color = "Cream", material = Enum.Material.Marble })
	for k = 0, 8 do
		Build.part({ name = "ArchMerlon", parent = g, size = Vector3.new(0.9, 1.3, 1.0), pos = Vector3.new(-6.4 + k * 1.6, 16.6, z), color = "Walnut", material = Enum.Material.Wood })
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Sign"
	sg.Face = Enum.NormalId.Front -- -z: the north face, towards the spawn
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = arch
	local a = gline(sg, "Line1", "CASTLE STERLING", 0.06, 0.56, "Brass", Enum.Font.Sarpanch)
	a.TextXAlignment = Enum.TextXAlignment.Center
	local b = gline(sg, "Line2", "by invitation only", 0.62, 0.32, "TealNeon")
	b.TextXAlignment = Enum.TextXAlignment.Center
	g.Parent = lobby
end

local function buildLobby(map: Instance)
	local L = Manor.Lobby
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local w, d = L.x1 - L.x0, L.z1 - L.z0
	local cx, cz = (L.x0 + L.x1) / 2, (L.z0 + L.z1) / 2
	local tile = 8
	for x = L.x0, L.x1 - tile, tile do
		for z = L.z0, L.z1 - tile, tile do
			Build.part({ name = "Tile", parent = lobby, size = Vector3.new(tile, 1, tile), pos = Vector3.new(x + tile / 2, -0.1, z + tile / 2), color = if (math.floor(x / tile) + math.floor(z / tile)) % 2 == 0 then "Cream" else "TealDeep", material = Enum.Material.Marble })
		end
	end
	-- brass railing (N/S rails run the full width, W/E rails butt-join between them) +
	-- invisible boundary so nobody walks off the terrace
	local rw = 0.3
	for _, side in { { cx, L.z0, w + rw, rw }, { cx, L.z1, w + rw, rw }, { L.x0, cz, rw, d - rw }, { L.x1, cz, rw, d - rw } } do
		Build.part({ name = "Rail", parent = lobby, size = Vector3.new(side[3], 0.4, side[4]), pos = Vector3.new(side[1], 3.4, side[2]), color = "Brass", material = Enum.Material.Metal })
		Build.part({ name = "Boundary", parent = lobby, size = Vector3.new(side[3] + 0.2, 30, side[4] + 0.2), pos = Vector3.new(side[1], 15, side[2]), transparency = 1, shadow = false })
	end
	for x = L.x0 + 3, L.x1 - 3, 6.5 do
		for _, z in { L.z0, L.z1 } do
			Build.part({ name = "Baluster", parent = lobby, size = Vector3.new(0.5, 3.0, 0.5), pos = Vector3.new(x, 1.9, z), color = "BrassDark", material = Enum.Material.Metal, collide = false })
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.6, 10)
	spawn.CFrame = CFrame.new(L.spawn.x, 0.5, L.spawn.z)
	spawn.Color = Build.color("Brass")
	spawn.Material = Enum.Material.Metal
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	local ph = Instance.new("Model")
	ph.Name = "Phonograph"
	local px, pz = L.x1 - 8, L.z0 + 8
	Build.part({ name = "Table", parent = ph, size = Vector3.new(4, 3, 4), pos = Vector3.new(px, 1.9, pz), color = "Walnut", material = Enum.Material.Wood })
	Build.part({ name = "Box", parent = ph, size = Vector3.new(3, 1.2, 3), pos = Vector3.new(px, 4.0, pz), color = "WalnutDark", material = Enum.Material.Wood })
	Build.part({ name = "Record", parent = ph, shape = Enum.PartType.Cylinder, size = Vector3.new(0.15, 2.6, 2.6), cf = CFrame.new(px, 4.7, pz) * CFrame.Angles(0, 0, math.rad(90)), color = "Iron", material = Enum.Material.SmoothPlastic })
	for k = 0, 3 do
		Build.part({ name = "Horn", parent = ph, shape = Enum.PartType.Cylinder, size = Vector3.new(1.2, 0.8 + k * 0.9, 0.8 + k * 0.9), cf = CFrame.new(px - 0.8 - k * 0.9, 5.4 + k * 0.7, pz) * CFrame.Angles(0, 0, math.rad(35)), color = "Brass", material = Enum.Material.Metal, collide = false })
	end
	ph.Parent = lobby
	local board = Build.part({ name = "TitleBoard", parent = lobby, size = Vector3.new(26, 7, 0.6), pos = Vector3.new(cx, 9, L.z0 + 1), color = "WalnutDark", material = Enum.Material.Wood })
	for _, sx in { -13.45, 13.45 } do
		Build.part({ name = "Post", parent = lobby, size = Vector3.new(0.8, 12.5, 0.8), pos = Vector3.new(cx + sx, 6.65, L.z0 + 1), color = "Brass", material = Enum.Material.Metal })
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Title"
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = board
	local t1 = Instance.new("TextLabel")
	t1.Name = "Line1"
	t1.BackgroundTransparency = 1
	t1.Size = UDim2.fromScale(1, 0.62)
	t1.Font = Enum.Font.Sarpanch
	t1.TextScaled = true
	t1.TextColor3 = Build.color("Brass")
	t1.Text = "THE CLOCKWORK MASQUERADE"
	t1.Parent = sg
	local t2 = t1:Clone()
	t2.Name = "Line2"
	t2.Position = UDim2.fromScale(0, 0.62)
	t2.Size = UDim2.fromScale(1, 0.34)
	t2.TextColor3 = Build.color("TealNeon")
	t2.Text = "Mystery at Sterling Castle" -- v1.5.1 Castle Sterling
	t2.Parent = sg
	buildFameBoard(lobby, L)
	buildGatehouse(lobby, L)
	for _, p in { { L.x0 + 3, L.z1 - 3 }, { L.x1 - 3, L.z1 - 3 }, { L.x0 + 3, L.z0 + 3 } } do
		Build.part({ name = "LampPost", parent = lobby, size = Vector3.new(0.6, 9, 0.6), pos = Vector3.new(p[1], 4.9, p[2]), color = "Iron", material = Enum.Material.Metal })
		local glass = Build.part({ name = "LampGlass", parent = lobby, shape = Enum.PartType.Ball, size = Vector3.new(1.6, 1.6, 1.6), pos = Vector3.new(p[1], 10, p[2]), color = "Warm", material = Enum.Material.Neon, collide = false })
		Build.light(glass, "PointLight", Build.color("Warm"), 1.4, 22)
	end
	local fz = Manor.FrontDoorZ
	Build.part({ name = "Path", parent = lobby, size = Vector3.new(10, 1, L.z0 - fz - 2), pos = Vector3.new(0, -0.3, (fz + 2 + L.z0) / 2), color = "Cream", material = Enum.Material.Cobblestone })
	lobby.Parent = map
	return lobby
end

local function buildFacade(map: Instance)
	local f = Instance.new("Model")
	f.Name = "Facade"
	local z = Manor.FrontDoorZ
	Build.part({ name = "FrontDoor", parent = f, size = Vector3.new(10, 12, 0.6), pos = Vector3.new(0, 6, z + 0.4), color = "Velvet", material = Enum.Material.Wood })
	for _, x in { -6.5, 6.5, -20, 20 } do
		Build.part({ name = "Column", parent = f, shape = Enum.PartType.Cylinder, size = Vector3.new(LH + 15.5, 2, 2), cf = CFrame.new(x, (LH + 15.5) / 2, z + 1.6) * CFrame.Angles(0, 0, math.rad(90)), color = "Cream", material = Enum.Material.Marble })
	end
	-- band across the floor line (covers the gap between the storeys on the front)
	Build.part({ name = "Pediment", parent = f, size = Vector3.new(58, 4.6, 1.6), pos = Vector3.new(0, 17.6, z + 0.85), color = "BrassDark", material = Enum.Material.Metal })
	Build.part({ name = "ClockFace", parent = f, shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, 7, 7), cf = CFrame.new(0, 28, z + 0.7) * CFrame.Angles(0, math.rad(90), 0), color = "Cream", material = Enum.Material.SmoothPlastic })
	Build.part({ name = "ClockRim", parent = f, shape = Enum.PartType.Cylinder, size = Vector3.new(0.3, 7.8, 7.8), cf = CFrame.new(0, 28, z + 0.4) * CFrame.Angles(0, math.rad(90), 0), color = "Brass", material = Enum.Material.Metal })
	-- v1.5.1 Castle Sterling crown: a crenellated parapet seated 0.1 into the column tops
	-- (y = LH + 15.5), merlons seated 0.05 into it and thinner front-to-back, so no face shares
	-- a plane with another.
	local colTop = LH + 15.5
	Build.part({ name = "Parapet", parent = f, size = Vector3.new(58, 2, 1.7), pos = Vector3.new(0, colTop - 0.1 + 1, z + 1.85), color = "Walnut", material = Enum.Material.Wood })
	for k = 0, 12 do
		Build.part({ name = "Merlon", parent = f, size = Vector3.new(2.4, 2, 1.4), pos = Vector3.new(-27.6 + k * 4.6, colTop + 1.9 - 0.05 + 1, z + 1.85), color = "Walnut", material = Enum.Material.Wood })
	end
	-- velvet banners on brass poles between the outer and inner columns
	for _, x in { -13.25, 13.25 } do
		Build.part({ name = "Banner", parent = f, size = Vector3.new(3.4, 9, 0.15), pos = Vector3.new(x, 25.5, z + 2.975), color = "Velvet", material = Enum.Material.Fabric, collide = false })
		Build.part({ name = "BannerTrim", parent = f, size = Vector3.new(3.0, 0.5, 0.1), pos = Vector3.new(x, 22.2, z + 3.1), color = "Gold", material = Enum.Material.Metal, collide = false })
		Build.part({ name = "BannerPole", parent = f, shape = Enum.PartType.Cylinder, size = Vector3.new(4.2, 0.35, 0.35), cf = CFrame.new(x, 30.2, z + 2.975), color = "Brass", material = Enum.Material.Metal, collide = false })
	end
	-- flank towers in front of the 1st-floor corners (x = +-36), 40 studs tall
	for _, sx in { -1, 1 } do
		local x, tz = sx * 36, z + 9.5
		Build.part({ name = "TowerPlinth", parent = f, size = Vector3.new(7, 3, 7), pos = Vector3.new(x, -0.1, tz), color = "Walnut", material = Enum.Material.Wood })
		Build.part({ name = "TowerShaft", parent = f, size = Vector3.new(6, 38.7, 6), pos = Vector3.new(x, 1.3 + 38.7 / 2, tz), color = "Cream", material = Enum.Material.Marble })
		Build.part({ name = "TowerParapet", parent = f, size = Vector3.new(7.4, 2, 7.4), pos = Vector3.new(x, 40.9, tz), color = "Walnut", material = Enum.Material.Wood })
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, -1 }, { 0, 1 } } do
			Build.part({ name = "TowerMerlon", parent = f, size = Vector3.new(1.4, 1.6, 1.4), pos = Vector3.new(x + c[1] * 2.8, 42.65, tz + c[2] * 2.8), color = "Walnut", material = Enum.Material.Wood })
		end
		for _, y in { 13, 27 } do
			local slit = Build.part({ name = "ArrowSlit", parent = f, size = Vector3.new(0.8, 4, 0.2), pos = Vector3.new(x, y, tz + 3.05), color = "Warm", material = Enum.Material.Neon, collide = false })
			slit.CastShadow = false
		end
	end
	f.Parent = map
end

-- Grass outside the manor, cut around every stairwell that drops through the ground line.
local function subtractRect(rects, h)
	local out = {}
	for _, r in rects do
		local x0, x1, z0, z1 = r[1], r[2], r[3], r[4]
		if h[2] <= x0 or h[1] >= x1 or h[4] <= z0 or h[3] >= z1 then
			table.insert(out, r)
		else
			if h[3] > z0 then
				table.insert(out, { x0, x1, z0, h[3] })
			end
			if h[4] < z1 then
				table.insert(out, { x0, x1, h[4], z1 })
			end
			local zz0, zz1 = math.max(z0, h[3]), math.min(z1, h[4])
			if h[1] > x0 then
				table.insert(out, { x0, h[1], zz0, zz1 })
			end
			if h[2] < x1 then
				table.insert(out, { h[2], x1, zz0, zz1 })
			end
		end
	end
	return out
end
ManorBuilder.subtractRect = subtractRect

local function buildGrounds(map: Instance)
	local rects = { { -210, 210, -180, 240 } }
	for _, r in Manor.Rooms do
		local lo, hi = ManorLayout.span(r)
		if lo < 0 and hi >= 0 then
			-- the hole is 0.1 wider than the shaft so the lawn's cut faces sit inside the walls
			rects = subtractRect(rects, { r.x0 - 0.1, r.x1 + 0.1, r.z0 - 0.1, r.z1 + 0.1 })
		end
	end
	local y0, y1 = -2.1, -1.1
	for _, q in rects do
		local x0, x1, z0, z1 = q[1], q[2], q[3], q[4]
		if x1 - x0 > 0.1 and z1 - z0 > 0.1 then
			Build.part({ name = "Grounds", parent = map, size = Vector3.new(x1 - x0, y1 - y0, z1 - z0), pos = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color = Color3.fromRGB(56, 74, 44), material = Enum.Material.Grass })
		end
	end
end

-- A carpet runner on each step (themes with `runner`) and an invisible wedge ramp resting on the
-- step nosings, so walking up a flight is smooth on every device.
local function stairExtras(parent: Instance, r)
	local th = themeOf(r)
	local f = ManorLayout.stairFrame(r)
	local base = ManorLayout.baseY(Manor, r)
	local n = ManorLayout.StairSteps
	local u0 = ManorLayout.StairBottomLanding
	local run = (f.length - u0 - ManorLayout.StairTopLanding) / n
	local rise = LH / n
	local width = if f.runAxis == "z" then r.x1 - r.x0 - 2 * T else r.z1 - r.z0 - 2 * T
	if th.runner then
		local rw = width * 0.45 + 0.07
		for i = 1, n do
			local xa, za = f.at(u0 + (i - 1) * run + 0.05)
			local xb, zb = f.at(u0 + i * run - 0.05)
			local cx, cz = (xa + xb) / 2, (za + zb) / 2
			local y = base + rise * i
			if f.runAxis == "z" then
				Build.part({ name = "Runner", parent = parent, size = Vector3.new(rw, 0.06, math.abs(zb - za)), pos = Vector3.new(cx, y + 0.03, cz), color = ArtGui.rgb(th.runner), material = Mat.Fabric, collide = false, shadow = false })
			else
				Build.part({ name = "Runner", parent = parent, size = Vector3.new(math.abs(xb - xa), 0.06, rw), pos = Vector3.new(cx, y + 0.03, cz), color = ArtGui.rgb(th.runner), material = Mat.Fabric, collide = false, shadow = false })
			end
		end
	end
	-- ramp from (u0 - run, 0) to (u0 + (n-1) run, LH): lies on every step's front-top edge
	local ua, ub = u0 - run, u0 + (n - 1) * run
	local xa, za = f.at(ua)
	local xb, zb = f.at(ub)
	local mid = Vector3.new((xa + xb) / 2, base + LH / 2, (za + zb) / 2)
	local down = Vector3.new(xa - xb, 0, za - zb).Unit -- towards the low end
	local w = Instance.new("WedgePart")
	w.Name = "StairRamp"
	w.Anchored = true
	w.CanCollide = true
	w.CanQuery = false
	w.CanTouch = false
	w.CastShadow = false
	w.Transparency = 1
	w.Size = Vector3.new(width, LH, ub - ua)
	w.CFrame = CFrame.lookAt(mid, mid + down)
	w.Parent = parent
	return w
end

-- ---- static props for nights 2-3 and Expose ------------------------------------------------
local function promptPoint(part: BasePart, offset: Vector3): Attachment
	local att = Instance.new("Attachment")
	att.Name = "PromptPoint"
	att.Position = offset
	att.Parent = part
	return att
end

local function label(part: BasePart, face: Enum.NormalId, title: string, sub: string?, titleColor: string?)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Label"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0.2
	sg.MaxDistance = 80
	sg.Parent = part
	local t1 = Instance.new("TextLabel")
	t1.Name = "Title"
	t1.BackgroundTransparency = 1
	t1.Size = UDim2.fromScale(1, if sub then 0.45 else 1)
	t1.Font = Enum.Font.Sarpanch
	t1.TextScaled = true
	t1.TextColor3 = Build.color(titleColor or "Brass")
	t1.Text = title
	t1.Parent = sg
	if sub then
		local t2 = t1:Clone()
		t2.Name = "Sub"
		t2.Position = UDim2.fromScale(0, 0.47)
		t2.Size = UDim2.fromScale(1, 0.5)
		t2.Font = Enum.Font.GothamBold
		t2.TextColor3 = Build.color("Cream2")
		t2.Text = sub
		t2.Parent = sg
	end
	return sg
end

local function buildProps(manor: Instance)
	local folder = Build.persistent("Props", manor)
	local m = ManorLayout.ids(Manor)
	local out = { cabinets = {}, keys = {}, projector = nil :: any, board = nil :: any, console = nil :: any }
	-- blueprint cabinets (Night 2)
	for _, c in Manor.Cabinets do
		local r = m[c.room]
		local b = ManorLayout.baseY(Manor, r)
		local x0, x1, z0, z1 = ManorDecor.wallBox(r, c.side, c.at, 3.2, 0.1, 1.6)
		local model = Instance.new("Model")
		model.Name = "Cabinet_" .. c.id
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		local body = Build.part({ name = "Cabinet", parent = model, size = Vector3.new(x1 - x0, 6, z1 - z0), pos = Vector3.new((x0 + x1) / 2, b + 3, (z0 + z1) / 2), color = "Oak", material = Mat.Wood })
		local face = ManorDecor.IntoRoom[c.side]
		local into = ({ N = Vector3.new(0, 0, 1), S = Vector3.new(0, 0, -1), W = Vector3.new(1, 0, 0), E = Vector3.new(-1, 0, 0) })[c.side]
		local dx0, dx1, dz0, dz1 = ManorDecor.wallBox(r, c.side, c.at, 2.6, 1.75, 0.12)
		local drawers = Build.part({ name = "Drawers", parent = model, size = Vector3.new(dx1 - dx0, 5, dz1 - dz0), pos = Vector3.new((dx0 + dx1) / 2, b + 3.1, (dz0 + dz1) / 2), color = "Blueprint", material = Mat.SmoothPlastic, collide = false })
		label(drawers, face, "BLUEPRINTS", "cabinet", "Cream2")
		promptPoint(body, (into * 1.2) :: Vector3)
		model.PrimaryPart = body
		model:SetAttribute("CabinetId", c.id)
		model.Parent = folder
		local wx, wz = (x0 + x1) / 2 + into.X * 3, (z0 + z1) / 2 + into.Z * 3
		out.cabinets[c.id] = { model = model, body = body, prompt = body.PromptPoint, room = c.room, level = r.level, x = wx, y = b, z = wz }
	end
	-- the projector in the Library (Night 2)
	do
		local P = Manor.Projector
		local r = m[P.room]
		local b = ManorLayout.baseY(Manor, r)
		local model = Instance.new("Model")
		model.Name = "Projector"
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		local stand = Build.part({ name = "ProjectorStand", parent = model, size = Vector3.new(3, 3.4, 3), pos = Vector3.new(P.x, b + 1.7, P.z), color = "Mahogany", material = Mat.Wood })
		local box = Build.part({ name = "ProjectorBox", parent = model, size = Vector3.new(2.6, 1.8, 2.2), pos = Vector3.new(P.x, b + 4.3, P.z), color = "Brass", material = Mat.Metal, collide = false })
		local lens = Build.part({ name = "ProjectorLens", parent = model, shape = Enum.PartType.Cylinder, size = Vector3.new(0.8, 1.2, 1.2), cf = CFrame.new(P.x, b + 4.3, P.z - 1.5) * CFrame.Angles(0, math.rad(90), 0), color = "TealNeon", material = Mat.Neon, collide = false })
		local light = Build.light(lens, "SpotLight", Build.color("TealNeon"), 0, 30)
		local zone = Build.part({ name = "BarrierZone", parent = model, shape = Enum.PartType.Ball, size = Vector3.new(1, 1, 1), pos = Vector3.new(P.x, b + 3, P.z), color = "TealNeon", material = Mat.ForceField, collide = false, query = false, shadow = false, transparency = 1 })
		promptPoint(stand, Vector3.new(0, 0, 1.8))
		model.PrimaryPart = stand
		model.Parent = folder
		out.projector = { model = model, stand = stand, box = box, lens = lens, light = light, zone = zone, prompt = stand.PromptPoint, x = P.x, y = b, z = P.z, level = r.level }
	end
	-- Evidence Board (Expose voting)
	do
		local E = Manor.EvidenceBoard
		local r = m[E.room]
		local b = ManorLayout.baseY(Manor, r)
		local x0, x1, z0, z1 = ManorDecor.wallBox(r, E.side, E.at, 7, 0.05, 0.4)
		local board = Build.part({ name = "EvidenceBoard", parent = folder, size = Vector3.new(x1 - x0, 5, z1 - z0), pos = Vector3.new((x0 + x1) / 2, b + 6.5, (z0 + z1) / 2), color = "Oak", material = Mat.Wood })
		local face = ManorDecor.IntoRoom[E.side]
		local sg = label(board, face, "EVIDENCE BOARD", "Who is the Phantom? Vote here by day!", "Amber")
		sg.Name = "BoardText"
		local into = ({ N = Vector3.new(0, 0, 1), S = Vector3.new(0, 0, -1), W = Vector3.new(1, 0, 0), E = Vector3.new(-1, 0, 0) })[E.side]
		promptPoint(board, Vector3.new(0, -3.5, 0) + into * 1.5)
		out.board = { part = board, prompt = board.PromptPoint, x = (x0 + x1) / 2 + into.X * 3, y = b, z = (z0 + z1) / 2 + into.Z * 3, level = r.level }
	end
	-- Exit Console (Night 3) on the ballroom dais + its activation ring
	do
		local C = Manor.Console
		local r = m[C.room]
		local b = ManorLayout.baseY(Manor, r)
		local model = Instance.new("Model")
		model.Name = "ExitConsole"
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		local body = Build.part({ name = "ConsoleBody", parent = model, size = Vector3.new(4, 4.2, 2.4), pos = Vector3.new(C.x, b + 0.6 + 2.1, C.z), color = "Copper", material = Mat.Metal })
		local screen = Build.part({ name = "ConsoleScreen", parent = model, size = Vector3.new(3.2, 1.6, 0.2), pos = Vector3.new(C.x, b + 3.9, C.z + 1.3), color = "TealDeep", material = Mat.Neon, collide = false })
		label(screen, Enum.NormalId.Back, "EXIT CONSOLE", "insert 3 keys", "TealNeon")
		local sockets = {}
		for i = 1, 3 do
			local s = Build.part({ name = "KeySocket" .. i, parent = model, shape = Enum.PartType.Ball, size = Vector3.new(0.7, 0.7, 0.7), pos = Vector3.new(C.x - 1.2 + (i - 1) * 1.2, b + 5.05, C.z), color = "Iron", material = Mat.Metal, collide = false })
			table.insert(sockets, s)
		end
		local ring = Build.part({ name = "ActivationRing", parent = model, shape = Enum.PartType.Cylinder, size = Vector3.new(0.05, C.ringRadius * 2, C.ringRadius * 2), cf = CFrame.new(C.x, b + 0.085, C.z) * CFrame.Angles(0, 0, math.rad(90)), color = "TealNeon", material = Mat.Neon, collide = false, query = false, shadow = false, transparency = 0.85 })
		promptPoint(body, Vector3.new(0, -1, 1.8))
		model.PrimaryPart = body
		model.Parent = folder
		out.console = { model = model, body = body, screen = screen, sockets = sockets, ring = ring, prompt = body.PromptPoint, x = C.x, y = b, z = C.z, level = r.level, radius = C.ringRadius }
	end
	-- key pedestals (Night 3)
	for _, k in Manor.Keys do
		local r = m[k.room]
		local b = ManorLayout.baseY(Manor, r)
		local ped = Build.part({ name = "KeyPedestal_" .. k.id, parent = folder, shape = Enum.PartType.Cylinder, size = Vector3.new(3.2, 2.2, 2.2), cf = CFrame.new(k.x, b + 1.6, k.z) * CFrame.Angles(0, 0, math.rad(90)), color = "Ivory", material = Mat.Marble })
		promptPoint(ped, Vector3.new(1.8, 0, 0))
		out.keys[k.id] = { pedestal = ped, prompt = ped.PromptPoint, x = k.x, y = b, z = k.z, room = k.room, level = r.level, name = k.name }
	end
	return out
end

function ManorBuilder.build()
	if built then
		return built
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	buildGrounds(map)

	local manor = Instance.new("Model")
	manor.Name = "Manor"
	manor.Parent = map
	local roomsFolder = Build.folder("Rooms", manor)
	local roomModels = {}
	local roomLights: { [string]: { PointLight } } = {}
	local m = ManorLayout.byId(Manor.Rooms)
	for _, r in Manor.Rooms do
		local rm = Instance.new("Model")
		rm.Name = r.id
		rm:SetAttribute("RoomName", r.name)
		rm:SetAttribute("Level", r.level)
		rm.Parent = roomsFolder
		roomModels[r.id] = rm
		local lights = {}
		roomLights[r.id] = lights
		local n = r.lights or 0
		local w, d = r.x1 - r.x0, r.z1 - r.z0
		local cx, cz = ManorLayout.centre(r)
		local top = ManorLayout.topY(Manor, r)
		local long = w >= d
		local tall = (r.span or 1) > 1 and not r.stair
		for k = 1, n do
			local f = (k - 0.5) / n
			local lx = if long then r.x0 + w * f else cx
			local lz = if long then cz else r.z0 + d * f
			if r.id == "ballroom" then
				local a = (k - 1) * math.pi / 2 + math.pi / 4
				lx, lz = cx + math.cos(a) * 14, cz + 6 + math.sin(a) * 12
			end
			chandelier(rm, lx, lz, top, r.id, lights, if tall then 12 else 2.4, r.id == "ballroom", ArtGui.rgb(themeOf(r).light))
		end
	end
	-- the gallery balcony is lit by the ballroom's chandeliers
	for _, r in Manor.Rooms do
		if r.balconyOf and #roomLights[r.id] == 0 then
			roomLights[r.id] = roomLights[r.balconyOf]
		end
	end

	-- static geometry (walls, slabs, trim, door frames, plates, stairs, railings)
	local wallsFolder = Build.folder("Walls", manor)
	local doorsFolder = Build.folder("Doors", manor)
	for _, b in ManorLayout.geometry(Manor, T) do
		local rid = b.room
		local r = m[rid]
		local th = r and themeOf(r)
		if b.kind == "Floor" then
			local fp = boxPart(roomModels[rid], b, th.floor, mat(th.floorMat))
			if th.floorMat == "Glass" then
				fp.Transparency = 0
			end
		elseif b.kind == "Ceiling" then
			local cp = boxPart(roomModels[rid], b, th.ceil, mat(th.ceilMat))
			if th.glassRoof then
				cp.Transparency = 0.55
				cp.CastShadow = false
			end
		elseif b.kind == "Wall" then
			boxPart(wallsFolder, b, th.wall, mat(th.wallMat))
		elseif b.kind == "Wainscot" then
			boxPart(wallsFolder, b, th.wain, mat(th.wainMat))
		elseif b.kind == "Rail" or b.kind == "Crown" then
			boxPart(wallsFolder, b, th.trim, Mat.Metal, false)
		elseif b.kind == "Step" or b.kind == "Landing" then
			boxPart(roomModels[rid], b, th.step or th.floor, mat(th.stepMat or th.floorMat))
		elseif b.kind == "Guard" then
			Build.part({ name = "BalconyGuard", parent = roomModels[rid], size = Vector3.new(b.sx, b.sy, b.sz), pos = Vector3.new(b.cx, b.cy, b.cz), transparency = 1, shadow = false })
		elseif b.kind == "NamePlate" then
			local p = boxPart(doorsFolder, b, "WalnutDark", Enum.Material.Wood, false)
			local d = b.door
			local info = ManorLayout.doorInfo(Manor, d)
			local ra, rb = m[d.a], m[d.b]
			local acx, acz = ManorLayout.centre(ra)
			local aLow = if b.axis == "x" then acx < b.pos else acz < b.pos -- room a on the -axis side
			local faceToA = if b.axis == "x" then (if aLow then Enum.NormalId.Left else Enum.NormalId.Right) else (if aLow then Enum.NormalId.Front else Enum.NormalId.Back)
			local faceToB = if b.axis == "x" then (if aLow then Enum.NormalId.Right else Enum.NormalId.Left) else (if aLow then Enum.NormalId.Back else Enum.NormalId.Front)
			local tA, sA = signFor(rb, info.level)
			local tB, sB = signFor(ra, info.level)
			plateText(p, faceToA, tA, sA)
			plateText(p, faceToB, tB, sB)
		else
			local look = Look[b.kind] or { "Brass", Mat.Metal }
			local parent = if b.kind == "DoorPost" or b.kind == "Lintel" then doorsFolder else wallsFolder
			boxPart(parent, b, look[1], look[2], look[3])
		end
	end

	-- stair runners + invisible ramps (smooth walking up every flight)
	for _, r in Manor.Rooms do
		if r.stair then
			stairExtras(roomModels[r.id], r)
		end
	end

	-- dressing: each room's own furniture kit, wall art, rugs, plants, floor pattern
	local decor = Build.folder("Decor", manor)
	ManorDecor.resetReservations()
	local artCount = 0
	for _, r in Manor.Rooms do
		local res = ManorDecor.dress(decor, r)
		artCount += res.art
	end
	manor:SetAttribute("ArtPieces", artCount)

	-- breaker terminals
	local breakersFolder = Build.persistent("Breakers", manor)
	local breakers = {}
	for _, spec in ManorLayout.breakers(Manor) do
		breakers[spec.id] = breakerModel(breakersFolder, spec, ManorLayout.topY(Manor, m[spec.room]))
	end
	-- service lift panels
	local liftsFolder = Build.persistent("Lifts", manor)
	local lifts = {}
	for _, r in Manor.Rooms do
		if r.lift then
			lifts[r.id] = liftPanel(liftsFolder, r)
		end
	end
	Build.folder("Chests", manor)
	buildFacade(map)
	buildLobby(map)
	Build.folder("Effects", workspace)

	local props = buildProps(manor)
	built = { map = map, manor = manor, roomLights = roomLights, breakers = breakers, lifts = lifts, props = props }
	return built
end

function ManorBuilder.get()
	return built
end

return ManorBuilder
