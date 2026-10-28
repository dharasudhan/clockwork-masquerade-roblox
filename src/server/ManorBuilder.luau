-- Builds Sterling Manor (one floor greybox with a steampunk dressing) and the lobby terrace
-- from Config/Manor + Logic/ManorLayout. Returns handles other services use:
--   roomLights[roomId] = { PointLight }, breakers[id] = { model, base, light, label, ... }
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Manor = require(Shared.Config.Manor)
local Style = require(Shared.Config.Style)
local ManorLayout = require(Shared.Logic.ManorLayout)
local Billboard = require(Shared.Billboard)
local Build = require(script.Parent.Build)

local ManorBuilder = {}

local H = Style.WallHeight
local T = Style.WallThickness
local DOOR_H = 12

local built: any = nil

local FloorMat = {
	Parquet = { Enum.Material.WoodPlanks, "Parquet" },
	Walnut = { Enum.Material.WoodPlanks, "Walnut" },
	Iron = { Enum.Material.DiamondPlate, "Iron" },
}

local function wallStack(parent: Instance, cx: number, cz: number, sx: number, sz: number, y0: number, y1: number)
	-- wainscot (walnut) to 4 studs, teal upper wall, brass rail at 4, brass crown at the top
	local function slab(name, a, b, color, mat)
		if b - a <= 0.01 then
			return
		end
		Build.part({ name = name, parent = parent, size = Vector3.new(sx, b - a, sz), pos = Vector3.new(cx, (a + b) / 2, cz), color = color, material = mat })
	end
	slab("Wainscot", y0, math.min(4, y1), "WalnutDark", Enum.Material.Wood)
	slab("Wall", math.max(4, y0), y1, "Teal", Enum.Material.SmoothPlastic)
	if y0 < 4 and y1 > 4 then
		local tx = if sx > sz then sx else sx + 0.2
		local tz = if sz > sx then sz else sz + 0.2
		Build.part({ name = "BrassRail", parent = parent, size = Vector3.new(tx, 0.35, tz), pos = Vector3.new(cx, 4, cz), color = "Brass", material = Enum.Material.Metal, collide = false, shadow = false })
	end
end

local function chandelier(parent: Instance, x: number, z: number, roomId: string, lights)
	local m = Instance.new("Model")
	m.Name = "Chandelier"
	m:SetAttribute("Room", roomId)
	Build.part({ name = "Chain", parent = m, size = Vector3.new(0.2, 2.4, 0.2), pos = Vector3.new(x, H - 1.2, z), color = "Brass", material = Enum.Material.Metal, collide = false, shadow = false })
	Build.part({ name = "Ring", parent = m, shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, 4.2, 4.2), cf = CFrame.new(x, H - 2.6, z) * CFrame.Angles(0, 0, math.rad(90)), color = "Brass", material = Enum.Material.Metal, collide = false, shadow = false })
	for i = 0, 3 do
		local a = i * math.pi / 2
		Build.part({ name = "Bulb", parent = m, shape = Enum.PartType.Ball, size = Vector3.new(0.7, 0.7, 0.7), pos = Vector3.new(x + math.cos(a) * 1.8, H - 2.2, z + math.sin(a) * 1.8), color = "Warm", material = Enum.Material.Neon, collide = false, shadow = false })
	end
	local core = Build.part({ name = "Core", parent = m, shape = Enum.PartType.Ball, size = Vector3.new(1.1, 1.1, 1.1), pos = Vector3.new(x, H - 3.1, z), color = "Warm", material = Enum.Material.Neon, collide = false, shadow = false })
	local light = Build.light(core, "PointLight", Build.color("Warm"), 1.8, 30, true)
	light:SetAttribute("Room", roomId)
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
		Build.part({ name = "Tooth", parent = g, size = Vector3.new(0.4, 0.8, 0.9), cf = cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, radius + 0.3, 0), color = "BrassDark", material = Enum.Material.Metal, collide = false, shadow = false })
	end
	Build.part({ name = "Hub", parent = g, shape = Enum.PartType.Cylinder, size = Vector3.new(0.6, radius * 0.7, radius * 0.7), cf = cf, color = "TealNeon", material = Enum.Material.Neon, collide = false, shadow = false })
	g.Parent = parent
end

local FaceDir = { E = Vector3.new(1, 0, 0), W = Vector3.new(-1, 0, 0), S = Vector3.new(0, 0, 1), N = Vector3.new(0, 0, -1) }

local function breakerModel(parent: Instance, spec)
	local m = Instance.new("Model")
	m.Name = "Breaker_" .. spec.id
	m:SetAttribute("BreakerId", spec.id)
	local dir = FaceDir[spec.face]
	local origin = Vector3.new(spec.x, 0, spec.z)
	local cf = CFrame.lookAt(origin, origin + dir) -- -Z (front) faces the room
	local base = Build.part({ name = "Cabinet", parent = m, size = Vector3.new(4.5, 6.5, 2), cf = cf * CFrame.new(0, 3.25, 0), color = "Copper", material = Enum.Material.Metal })
	Build.part({ name = "Panel", parent = m, size = Vector3.new(3.6, 4.6, 0.2), cf = cf * CFrame.new(0, 3.6, -1.05), color = "Iron", material = Enum.Material.Metal })
	Build.part({ name = "Gauge", parent = m, shape = Enum.PartType.Cylinder, size = Vector3.new(0.2, 1.4, 1.4), cf = cf * CFrame.new(-0.8, 4.8, -1.2) * CFrame.Angles(0, math.rad(90), 0), color = "TealNeon", material = Enum.Material.Neon, collide = false })
	Build.part({ name = "Lever", parent = m, size = Vector3.new(0.35, 1.8, 0.35), cf = cf * CFrame.new(0.9, 3.4, -1.4) * CFrame.Angles(math.rad(-25), 0, 0), color = "Brass", material = Enum.Material.Metal, collide = false })
	local status = Build.part({ name = "Status", parent = m, shape = Enum.PartType.Ball, size = Vector3.new(0.8, 0.8, 0.8), cf = cf * CFrame.new(0.9, 5.5, -1.2), color = "BreakerOk", material = Enum.Material.Neon, collide = false })
	local light = Build.light(status, "PointLight", Build.color("BreakerOk"), 1.5, 12)
	for i = -1, 1, 2 do
		Build.part({ name = "Pipe", parent = m, shape = Enum.PartType.Cylinder, size = Vector3.new(H - 6.5, 0.6, 0.6), cf = cf * CFrame.new(i * 1.6, 6.5 + (H - 6.5) / 2, 0.3) * CFrame.Angles(0, 0, math.rad(90)), color = "Copper", material = Enum.Material.Metal, collide = false })
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
	return { model = m, base = base, status = status, light = light, sparks = sparks, label = text, prompt = att, x = spec.x, z = spec.z, room = spec.room }
end

local function buildLobby(map: Instance)
	local L = Manor.Lobby
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local w, d = L.x1 - L.x0, L.z1 - L.z0
	local cx, cz = (L.x0 + L.x1) / 2, (L.z0 + L.z1) / 2
	-- checkered marble terrace
	local tile = 8
	local i = 0
	for x = L.x0, L.x1 - tile, tile do
		for z = L.z0, L.z1 - tile, tile do
			i += 1
			Build.part({ name = "Tile", parent = lobby, size = Vector3.new(tile, 1, tile), pos = Vector3.new(x + tile / 2, -0.1, z + tile / 2), color = if (math.floor(x / tile) + math.floor(z / tile)) % 2 == 0 then "Cream" else "TealDeep", material = Enum.Material.Marble })
		end
	end
	-- brass railing + invisible boundary so nobody walks off the terrace
	for _, side in { { cx, L.z0, w, 0.3 }, { cx, L.z1, w, 0.3 }, { L.x0, cz, 0.3, d }, { L.x1, cz, 0.3, d } } do
		Build.part({ name = "Rail", parent = lobby, size = Vector3.new(side[3] + 0.3, 0.4, side[4] + 0.3), pos = Vector3.new(side[1], 3.4, side[2]), color = "Brass", material = Enum.Material.Metal })
		Build.part({ name = "Boundary", parent = lobby, size = Vector3.new(side[3] + 0.3, 30, side[4] + 0.3), pos = Vector3.new(side[1], 15, side[2]), transparency = 1, shadow = false })
	end
	for x = L.x0, L.x1, 6.5 do
		for _, z in { L.z0, L.z1 } do
			Build.part({ name = "Baluster", parent = lobby, size = Vector3.new(0.5, 3.4, 0.5), pos = Vector3.new(x, 1.7, z), color = "BrassDark", material = Enum.Material.Metal, collide = false })
		end
	end
	-- spawn medallion
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
	-- phonograph (lobby music source, decorative)
	local ph = Instance.new("Model")
	ph.Name = "Phonograph"
	local px, pz = L.x1 - 8, L.z0 + 8
	Build.part({ name = "Table", parent = ph, size = Vector3.new(4, 3, 4), pos = Vector3.new(px, 1.5, pz), color = "Walnut", material = Enum.Material.Wood })
	Build.part({ name = "Box", parent = ph, size = Vector3.new(3, 1.2, 3), pos = Vector3.new(px, 3.6, pz), color = "WalnutDark", material = Enum.Material.Wood })
	Build.part({ name = "Record", parent = ph, shape = Enum.PartType.Cylinder, size = Vector3.new(0.15, 2.6, 2.6), cf = CFrame.new(px, 4.3, pz) * CFrame.Angles(0, 0, math.rad(90)), color = "Iron", material = Enum.Material.SmoothPlastic })
	for k = 0, 3 do
		Build.part({ name = "Horn", parent = ph, shape = Enum.PartType.Cylinder, size = Vector3.new(1.2, 0.8 + k * 0.9, 0.8 + k * 0.9), cf = CFrame.new(px - 0.8 - k * 0.9, 5 + k * 0.7, pz) * CFrame.Angles(0, 0, math.rad(35)), color = "Brass", material = Enum.Material.Metal, collide = false })
	end
	ph.Parent = lobby
	-- title board
	local board = Build.part({ name = "TitleBoard", parent = lobby, size = Vector3.new(26, 7, 0.6), pos = Vector3.new(cx, 9, L.z0 + 1), color = "WalnutDark", material = Enum.Material.Wood })
	for _, sx in { -13.4, 13.4 } do
		Build.part({ name = "Post", parent = lobby, size = Vector3.new(0.8, 12.5, 0.8), pos = Vector3.new(cx + sx, 6.25, L.z0 + 1), color = "Brass", material = Enum.Material.Metal })
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
	t2.Text = "Mystery at Sterling Manor"
	t2.Parent = sg
	-- lamps
	for _, p in { { L.x0 + 3, L.z1 - 3 }, { L.x1 - 3, L.z1 - 3 }, { L.x0 + 3, L.z0 + 3 } } do
		Build.part({ name = "LampPost", parent = lobby, size = Vector3.new(0.6, 9, 0.6), pos = Vector3.new(p[1], 4.5, p[2]), color = "Iron", material = Enum.Material.Metal })
		local glass = Build.part({ name = "LampGlass", parent = lobby, shape = Enum.PartType.Ball, size = Vector3.new(1.6, 1.6, 1.6), pos = Vector3.new(p[1], 9.6, p[2]), color = "Warm", material = Enum.Material.Neon, collide = false })
		Build.light(glass, "PointLight", Build.color("Warm"), 1.4, 22)
	end
	-- lawn path to the (closed) front doors
	Build.part({ name = "Path", parent = lobby, size = Vector3.new(10, 1, 36), pos = Vector3.new(0, -0.3, 78), color = "Cream", material = Enum.Material.Cobblestone })
	lobby.Parent = map
	return lobby
end

local function buildFacade(map: Instance)
	local f = Instance.new("Model")
	f.Name = "Facade"
	-- front doors (closed) + columns + clock on the foyer's south wall
	Build.part({ name = "FrontDoor", parent = f, size = Vector3.new(10, 12, 0.6), pos = Vector3.new(0, 6, 60.4), color = "Velvet", material = Enum.Material.Wood })
	for _, x in { -6.5, 6.5, -20, 20 } do
		Build.part({ name = "Column", parent = f, shape = Enum.PartType.Cylinder, size = Vector3.new(H + 2, 2, 2), cf = CFrame.new(x, (H + 2) / 2, 61.4) * CFrame.Angles(0, 0, math.rad(90)), color = "Cream", material = Enum.Material.Marble })
	end
	Build.part({ name = "ClockFace", parent = f, shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, 6, 6), cf = CFrame.new(0, H + 3, 60.6) * CFrame.Angles(0, math.rad(90), 0), color = "Cream", material = Enum.Material.SmoothPlastic })
	Build.part({ name = "ClockRim", parent = f, shape = Enum.PartType.Cylinder, size = Vector3.new(0.3, 6.8, 6.8), cf = CFrame.new(0, H + 3, 60.45) * CFrame.Angles(0, math.rad(90), 0), color = "Brass", material = Enum.Material.Metal })
	Build.part({ name = "Pediment", parent = f, size = Vector3.new(30, 4, 2), pos = Vector3.new(0, H + 1.5, 60.8), color = "BrassDark", material = Enum.Material.Metal })
	f.Parent = map
end

function ManorBuilder.build()
	if built then
		return built
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	Build.part({ name = "Grounds", parent = map, size = Vector3.new(420, 1, 420), pos = Vector3.new(0, -1.6, 30), color = Color3.fromRGB(56, 74, 44), material = Enum.Material.Grass })

	local manor = Instance.new("Model")
	manor.Name = "Manor"
	manor.Parent = map
	local roomsFolder = Build.folder("Rooms", manor)
	local roomLights: { [string]: { PointLight } } = {}

	for _, r in Manor.Rooms do
		local rm = Instance.new("Model")
		rm.Name = r.id
		rm:SetAttribute("RoomName", r.name)
		local w, d = r.x1 - r.x0, r.z1 - r.z0
		local cx, cz = ManorLayout.centre(r)
		local fm = FloorMat[r.floor] or FloorMat.Walnut
		Build.part({ name = "Floor", parent = rm, size = Vector3.new(w, 1, d), pos = Vector3.new(cx, -0.5, cz), color = fm[2], material = fm[1] })
		Build.part({ name = "Ceiling", parent = rm, size = Vector3.new(w, 1, d), pos = Vector3.new(cx, Style.CeilingHeight + 0.5, cz), color = "Ceiling", material = Enum.Material.Wood })
		-- crown moulding (brass) just under the ceiling
		Build.part({ name = "Crown", parent = rm, size = Vector3.new(w - 2 * T, 0.4, 0.4), pos = Vector3.new(cx, H - 0.2, r.z0 + T + 0.2), color = "Brass", material = Enum.Material.Metal, collide = false, shadow = false })
		Build.part({ name = "Crown", parent = rm, size = Vector3.new(w - 2 * T, 0.4, 0.4), pos = Vector3.new(cx, H - 0.2, r.z1 - T - 0.2), color = "Brass", material = Enum.Material.Metal, collide = false, shadow = false })
		local lights = {}
		roomLights[r.id] = lights
		local n = r.lights or 1
		local long = w >= d
		for k = 1, n do
			local f = (k - 0.5) / n
			local lx = if long then r.x0 + w * f else cx
			local lz = if long then cz else r.z0 + d * f
			if r.id == "ballroom" then
				local a = (k - 1) * math.pi / 2 + math.pi / 4
				lx, lz = cx + math.cos(a) * 15, cz + math.sin(a) * 15
			end
			chandelier(rm, lx, lz, r.id, lights)
		end
		rm.Parent = roomsFolder
	end

	-- walls with door gaps, door lintels + brass frames
	local wallsFolder = Build.folder("Walls", manor)
	for _, seg in ManorLayout.walls(Manor.Rooms, Manor.Doors, T) do
		wallStack(wallsFolder, seg.cx, seg.cz, seg.sx, seg.sz, 0, H)
	end
	local doorsFolder = Build.folder("Doors", manor)
	for _, d in Manor.Doors do
		local info = ManorLayout.doorInfo(Manor.Rooms, d)
		local alongX = info.axis == "z" -- the opening runs along x when the wall is at z = pos
		local sx = if alongX then d.width else 2 * T
		local sz = if alongX then 2 * T else d.width
		wallStack(doorsFolder, info.x, info.z, sx, sz, DOOR_H, H)
		for _, s in { -1, 1 } do
			local ox = if alongX then s * (d.width / 2 + 0.3) else 0
			local oz = if alongX then 0 else s * (d.width / 2 + 0.3)
			Build.part({ name = "DoorPost", parent = doorsFolder, size = Vector3.new(if alongX then 0.6 else 2.4, DOOR_H, if alongX then 2.4 else 0.6), pos = Vector3.new(info.x + ox, DOOR_H / 2, info.z + oz), color = "Brass", material = Enum.Material.Metal })
		end
		Build.part({ name = "Lintel", parent = doorsFolder, size = Vector3.new(if alongX then d.width + 1.2 else 2.4, 0.6, if alongX then 2.4 else d.width + 1.2), pos = Vector3.new(info.x, DOOR_H, info.z), color = "Brass", material = Enum.Material.Metal })
	end

	-- dressing: copper pipes along the corridors, gears + a clock in the ballroom, trunks
	local decor = Build.folder("Decor", manor)
	local m = ManorLayout.byId(Manor.Rooms)
	for _, id in { "westHall", "eastHall" } do
		local r = m[id]
		for _, side in { r.x0 + T + 0.4, r.x1 - T - 0.4 } do
			Build.part({ name = "Pipe", parent = decor, shape = Enum.PartType.Cylinder, size = Vector3.new(0.7, r.z1 - r.z0 - 2, 0.7), cf = CFrame.new(side, H - 1.6, (r.z0 + r.z1) / 2) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, math.rad(90)), color = "Copper", material = Enum.Material.Metal, collide = false })
		end
	end
	local nh = m.northHall
	Build.part({ name = "Pipe", parent = decor, shape = Enum.PartType.Cylinder, size = Vector3.new(nh.x1 - nh.x0 - 2, 0.7, 0.7), cf = CFrame.new(0, H - 1.6, nh.z0 + T + 0.4), color = "Copper", material = Enum.Material.Metal, collide = false })
	local b = m.ballroom
	for _, x in { -18, 18 } do
		gear(decor, CFrame.new(x, 9, b.z0 + T + 0.3) * CFrame.Angles(0, math.rad(90), 0), 3.2)
	end
	for _, z in { -14, 14 } do
		gear(decor, CFrame.new(b.x0 + T + 0.3, 9, z), 2.6)
		gear(decor, CFrame.new(b.x1 - T - 0.3, 9, z), 2.6)
	end
	Build.part({ name = "Dais", parent = decor, shape = Enum.PartType.Cylinder, size = Vector3.new(0.6, 10, 10), cf = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), color = "BrassDark", material = Enum.Material.Metal })
	Build.part({ name = "DaisInlay", parent = decor, shape = Enum.PartType.Cylinder, size = Vector3.new(0.65, 6, 6), cf = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), color = "TealNeon", material = Enum.Material.Neon, collide = false })
	gear(decor, CFrame.new(0, 4.5, 0) * CFrame.Angles(0, math.rad(90), 0), 2.2)
	Build.part({ name = "GearAxle", parent = decor, size = Vector3.new(0.6, 4, 0.6), pos = Vector3.new(0, 2.3, 0), color = "Copper", material = Enum.Material.Metal })
	local lr = m.luggage
	for k = 1, 6 do
		local x = lr.x0 + 4 + ((k * 7) % 16)
		local z = lr.z0 + 6 + ((k * 11) % 18)
		Build.part({ name = "Trunk", parent = decor, size = Vector3.new(3.4, 2 + (k % 2), 2.2), cf = CFrame.new(x, 1.1, z) * CFrame.Angles(0, math.rad(k * 23), 0), color = if k % 2 == 0 then "Velvet" else "Walnut", material = Enum.Material.Wood })
	end
	local pr = m.parlour
	for k = 0, 1 do
		local x, z = pr.x0 + 8 + k * 9, pr.z0 + 12
		Build.part({ name = "TeaTable", parent = decor, shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, 4, 4), cf = CFrame.new(x, 2.6, z) * CFrame.Angles(0, 0, math.rad(90)), color = "Walnut", material = Enum.Material.Wood })
		Build.part({ name = "TeaLeg", parent = decor, size = Vector3.new(0.5, 2.4, 0.5), pos = Vector3.new(x, 1.2, z), color = "Brass", material = Enum.Material.Metal })
	end

	-- breaker terminals
	local breakersFolder = Build.folder("Breakers", manor)
	local breakers = {}
	for _, spec in Manor.Breakers do
		breakers[spec.id] = breakerModel(breakersFolder, spec)
	end
	Build.folder("Chests", manor)
	buildFacade(map)
	buildLobby(map)
	Build.folder("Effects", workspace)

	built = { map = map, manor = manor, roomLights = roomLights, breakers = breakers }
	return built
end

function ManorBuilder.get()
	return built
end

return ManorBuilder
