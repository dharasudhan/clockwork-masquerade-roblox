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

local ManorBuilder = {}

local T = Style.WallThickness
local LH = Manor.LevelHeight

local built: any = nil

local FloorMat = {
	Parquet = { Enum.Material.WoodPlanks, "Parquet" },
	Walnut = { Enum.Material.WoodPlanks, "Walnut" },
	Iron = { Enum.Material.DiamondPlate, "Iron" },
	Marble = { Enum.Material.Marble, "Marble" },
	Tile = { Enum.Material.CeramicTiles, "Tile" },
	Stone = { Enum.Material.Slate, "Stone" },
}

local Look = {
	Wainscot = { "WalnutDark", Enum.Material.Wood },
	Wall = { "Teal", Enum.Material.SmoothPlastic },
	Ceiling = { "Ceiling", Enum.Material.Wood },
	Rail = { "Brass", Enum.Material.Metal, false },
	Crown = { "Brass", Enum.Material.Metal, false },
	DoorPost = { "Brass", Enum.Material.Metal, true },
	Lintel = { "Brass", Enum.Material.Metal, false },
	NamePlate = { "WalnutDark", Enum.Material.Wood, false },
	Step = { "Marble", Enum.Material.Marble },
	Landing = { "Marble", Enum.Material.Marble },
	BalconyRail = { "Brass", Enum.Material.Metal },
	Baluster = { "BrassDark", Enum.Material.Metal, false },
}

local function boxPart(parent: Instance, b, color, material, collide: boolean?)
	return Build.part({
		name = b.kind, parent = parent, size = Vector3.new(b.sx, b.sy, b.sz), pos = Vector3.new(b.cx, b.cy, b.cz),
		color = color, material = material, collide = if collide == nil then true else collide,
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

local function chandelier(parent: Instance, x: number, z: number, top: number, roomId: string, lights, drop: number, shadows: boolean)
	local m = Instance.new("Model")
	m.Name = "Chandelier"
	m:SetAttribute("Room", roomId)
	local chain = drop
	Build.part({ name = "Chain", parent = m, size = Vector3.new(0.2, chain, 0.2), pos = Vector3.new(x, top - chain / 2, z), color = "Brass", material = Enum.Material.Metal, collide = false, shadow = false })
	Build.part({ name = "Ring", parent = m, shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, 4.2, 4.2), cf = CFrame.new(x, top - chain - 0.2, z) * CFrame.Angles(0, 0, math.rad(90)), color = "Brass", material = Enum.Material.Metal, collide = false, shadow = false })
	local core = Build.part({ name = "Core", parent = m, shape = Enum.PartType.Ball, size = Vector3.new(1.3, 1.3, 1.3), pos = Vector3.new(x, top - chain - 0.9, z), color = "Warm", material = Enum.Material.Neon, collide = false, shadow = false })
	local light = Build.light(core, "PointLight", Build.color("Warm"), 1.8, 30, shadows)
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

-- ---- room dressing (non-colliding so walkers and bots never snag; one small kit per room) ------
local spanFree, wallPoint, wallSpot

local function deco(parent: Instance, name: string, x0, x1, y0, y1, z0, z1, color, material, opts)
	local o = opts or {}
	return Build.part({ name = name, parent = parent, size = Vector3.new(x1 - x0, y1 - y0, z1 - z0), pos = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color = color, material = material or Enum.Material.Wood, collide = false, shadow = o.shadow })
end

local function cyl(parent: Instance, name: string, x, y, z, h, d, color, material, vertical: boolean?)
	local cf = if vertical == false then CFrame.new(x, y, z) else CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
	return Build.part({ name = name, parent = parent, shape = Enum.PartType.Cylinder, size = Vector3.new(h, d, d), cf = cf, color = color, material = material or Enum.Material.Metal, collide = false })
end

-- door spans (+1 stud) on a room side, any level, plus a breaker on that side
local function blocked(r, side)
	local out = {}
	for _, d in Manor.Doors do
		local info = ManorLayout.doorInfo(Manor, d)
		if (d.a == r.id and info.sideA == side) or (d.b == r.id and info.sideB == side) then
			table.insert(out, { d.at - d.width / 2 - 1, d.at + d.width / 2 + 1 })
		end
	end
	for _, br in Manor.Breakers do
		if br.room == r.id and br.side == side then
			table.insert(out, { br.at - 4, br.at + 4 })
		end
	end
	return out
end

spanFree = function(r, side, a0, a1): boolean
	local alongX = side == "N" or side == "S"
	local lo, hi = if alongX then r.x0 + T + 0.5 else r.z0 + T + 0.5, if alongX then r.x1 - T - 0.5 else r.z1 - T - 0.5
	if a0 < lo or a1 > hi then
		return false
	end
	for _, g in blocked(r, side) do
		if a0 < g[2] and a1 > g[1] then
			return false
		end
	end
	return true
end

-- a point on a side's inner face pushed `off` studs into the room, with a rotation that turns a
-- cylinder's axis to face out of that wall
wallPoint = function(r, side, at, off)
	if side == "N" then
		return at, r.z0 + T + off, CFrame.Angles(0, math.rad(90), 0)
	elseif side == "S" then
		return at, r.z1 - T - off, CFrame.Angles(0, math.rad(90), 0)
	elseif side == "W" then
		return r.x0 + T + off, at, CFrame.new()
	end
	return r.x1 - T - off, at, CFrame.new()
end

-- first wall stretch of `len` studs free of doors and breakers (centred on the side's middle,
-- then sliding); returns side, centre-along of the stretch's left end + 4 (gear layout)
wallSpot = function(r, len)
	for _, side in { "S", "N", "W", "E" } do
		local alongX = side == "N" or side == "S"
		local a0, a1 = if alongX then r.x0 else r.z0, if alongX then r.x1 else r.z1
		local mid = (a0 + a1) / 2
		for _, shift in { 0, -8, 8, -16, 16 } do
			local s0 = mid + shift - 4
			if spanFree(r, side, s0 - 3.5, s0 + len - 3.5) then
				return side, s0
			end
		end
	end
	return nil, 0
end

local Kits = {}
function Kits.ballroom(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	cyl(f, "Dais", cx, b + 0.3, cz, 0.6, 10, "BrassDark")
	cyl(f, "DaisInlay", cx, b + 0.3, cz, 0.65, 6, "TealNeon", Enum.Material.Neon)
	gear(f, CFrame.new(cx, b + 4.5, cz) * CFrame.Angles(0, math.rad(90), 0), 2.2)
	deco(f, "GearAxle", cx - 0.25, cx + 0.25, b + 0.62, b + 4.3, cz - 0.25, cz + 0.25, "Copper", Enum.Material.Metal)
	for _, z in { -10, 10 } do
		gear(f, CFrame.new(r.x0 + T + 0.3, b + 9, cz + z), 2.6)
		gear(f, CFrame.new(r.x1 - T - 0.3, b + 9, cz + z), 2.6)
	end
	for _, x in { -18, 18 } do
		gear(f, CFrame.new(cx + x, b + 28, r.z1 - T - 0.3) * CFrame.Angles(0, math.rad(90), 0), 3.4)
	end
end
function Kits.foyer(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	deco(f, "Rug", cx - 8, cx + 8, b, b + 0.08, cz - 6, cz + 6, "Velvet", Enum.Material.Fabric)
	deco(f, "ClockCase", r.x1 - T - 2.6, r.x1 - T - 0.6, b, b + 9, cz - 1.2, cz + 1.2, "Walnut")
	cyl(f, "ClockDial", r.x1 - T - 2.7, b + 7.2, cz, 0.15, 1.8, "Cream", Enum.Material.SmoothPlastic, false)
end
function Kits.pipes(f, r, b)
	local long = (r.x1 - r.x0) >= (r.z1 - r.z0)
	local top = ManorLayout.topY(Manor, r)
	if long then
		cyl(f, "Pipe", (r.x0 + r.x1) / 2, top - 1.6, r.z0 + T + 0.45, r.x1 - r.x0 - 2 * T - 0.4, 0.7, "Copper", nil, false)
	else
		local part = cyl(f, "Pipe", r.x0 + T + 0.45, top - 1.6, (r.z0 + r.z1) / 2, r.z1 - r.z0 - 2 * T - 0.4, 0.7, "Copper", nil, false)
		part.CFrame = CFrame.new(part.CFrame.Position) * CFrame.Angles(0, math.rad(90), 0)
	end
end
local function shelvesAlong(f, r, b, side, color)
	-- tall shelving on the first wall of `side` without a door
	local cx, cz = ManorLayout.centre(r)
	if side == "W" then
		deco(f, "Shelf", r.x0 + T + 0.1, r.x0 + T + 1.3, b, b + 10, cz - 6, cz + 6, color or "WalnutDark")
		deco(f, "Books", r.x0 + T + 1.3, r.x0 + T + 1.5, b + 1.5, b + 8.5, cz - 5.5, cz + 5.5, "Velvet", Enum.Material.Fabric)
	else
		deco(f, "Shelf", r.x1 - T - 1.3, r.x1 - T - 0.1, b, b + 10, cz - 6, cz + 6, color or "WalnutDark")
		deco(f, "Books", r.x1 - T - 1.5, r.x1 - T - 1.3, b + 1.5, b + 8.5, cz - 5.5, cz + 5.5, "Velvet", Enum.Material.Fabric)
	end
end
function Kits.shelves(f, r, b)
	shelvesAlong(f, r, b, "W")
	local cx, cz = ManorLayout.centre(r)
	deco(f, "ReadingTable", cx - 4, cx + 4, b + 2.6, b + 3, cz - 2, cz + 2, "Walnut")
	deco(f, "TableBase", cx - 3.5, cx + 3.5, b, b + 2.6, cz - 1.5, cz + 1.5, "WalnutDark")
end
function Kits.billiard(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	deco(f, "TableBase", cx - 3, cx + 3, b, b + 2.6, cz - 5.5, cz + 5.5, "WalnutDark")
	deco(f, "Felt", cx - 3.5, cx + 3.5, b + 2.6, b + 3, cz - 6, cz + 6, "Felt", Enum.Material.Fabric)
end
function Kits.music(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	deco(f, "PianoBody", cx - 3, cx + 3, b + 2.4, b + 4, cz - 2, cz + 2.5, "WalnutDark")
	deco(f, "PianoKeys", cx - 2.6, cx + 2.6, b + 2.6, b + 3.8, cz + 2.5, cz + 3.2, "Cream", Enum.Material.SmoothPlastic)
	deco(f, "PianoLeg", cx - 0.3, cx + 0.3, b, b + 2.4, cz - 0.3, cz + 0.3, "Brass", Enum.Material.Metal)
	for k = 0, 2 do
		cyl(f, "Horn", cx + 8, b + 4 + k * 0.7, cz - 4 - k * 0.9, 1.1, 0.8 + k * 0.9, "Brass")
	end
end
function Kits.lab(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	deco(f, "Bench", cx - 6, cx + 6, b + 3, b + 3.4, cz - 2, cz + 2, "Iron", Enum.Material.Metal)
	deco(f, "BenchBase", cx - 5.5, cx + 5.5, b, b + 3, cz - 1.5, cz + 1.5, "WalnutDark")
	cyl(f, "CoilBase", cx - 12, b + 2, cz, 4, 3, "Copper")
	cyl(f, "Coil", cx - 12, b + 6, cz, 4.2, 1.4, "Brass")
	local top = Build.part({ name = "CoilTop", parent = f, shape = Enum.PartType.Ball, size = Vector3.new(2.4, 2.4, 2.4), pos = Vector3.new(cx - 12, b + 9, cz), color = "TealNeon", material = Enum.Material.Neon, collide = false })
	Build.light(top, "PointLight", Build.color("TealNeon"), 1, 14)
end
function Kits.dining(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	deco(f, "TableTop", cx - 3, cx + 3, b + 2.6, b + 3, cz - 11, cz + 11, "Walnut")
	deco(f, "TableBase", cx - 2, cx + 2, b, b + 2.6, cz - 10, cz + 10, "WalnutDark")
	for _, z in { -6, 0, 6 } do
		cyl(f, "Candle", cx, b + 3.6, cz + z, 1.2, 0.3, "Cream", Enum.Material.SmoothPlastic)
	end
end
function Kits.kitchen(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	deco(f, "Range", cx - 6, cx + 6, b, b + 3.4, cz - 2, cz + 2, "Iron", Enum.Material.Metal)
	deco(f, "RangeTop", cx - 6.4, cx + 6.4, b + 3.4, b + 3.7, cz - 2.4, cz + 2.4, "Copper", Enum.Material.Metal)
	for _, x in { -3, 3 } do
		cyl(f, "Pot", cx + x, b + 4.5, cz, 1.6, 2, "Copper")
	end
end
function Kits.maps(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	cyl(f, "GlobeStand", cx, b + 1.5, cz, 3, 1, "Brass")
	Build.part({ name = "Globe", parent = f, shape = Enum.PartType.Ball, size = Vector3.new(4, 4, 4), pos = Vector3.new(cx, b + 5, cz), color = "Teal", material = Enum.Material.SmoothPlastic, collide = false })
	deco(f, "MapTable", cx + 5, cx + 11, b + 2.8, b + 3.2, cz - 3, cz + 3, "Walnut")
	deco(f, "Map", cx + 5.5, cx + 10.5, b + 3.2, b + 3.26, cz - 2.5, cz + 2.5, "Cream", Enum.Material.Fabric)
	deco(f, "MapTableBase", cx + 7, cx + 9, b, b + 2.8, cz - 1, cz + 1, "WalnutDark")
end
function Kits.clocks(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	local top = ManorLayout.topY(Manor, r)
	local side, at = wallSpot(r, 14)
	if side then
		local px, pz, rot = wallPoint(r, side, at, 0.3)
		gear(f, CFrame.new(px, math.min(b + 10, top - 4), pz) * rot, 3)
		local qx, qz = wallPoint(r, side, at + 6.5, 0.5)
		gear(f, CFrame.new(qx, math.min(b + 8, top - 6), qz) * rot, 2)
	end
	deco(f, "Workbench", cx - 5, cx + 5, b + 2.8, b + 3.2, cz - 2, cz + 2, "Walnut")
	deco(f, "WorkbenchBase", cx - 4.5, cx + 4.5, b, b + 2.8, cz - 1.5, cz + 1.5, "Iron", Enum.Material.Metal)
end
function Kits.plants(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for k = -1, 1 do
		local x = cx + k * 10
		deco(f, "Planter", x - 2, x + 2, b, b + 1.6, cz - 2, cz + 2, "Stone", Enum.Material.Slate)
		Build.part({ name = "Shrub", parent = f, shape = Enum.PartType.Ball, size = Vector3.new(4.4, 4.4, 4.4), pos = Vector3.new(x, b + 3.4, cz), color = "Leaf", material = Enum.Material.Grass, collide = false })
	end
end
function Kits.portraits(f, r, b)
	-- frames on the inner face of door-free stretches (0.05 off the wall, canvas proud of the frame)
	local placed = 0
	for _, side in { "N", "S", "W", "E" } do
		local alongX = side == "N" or side == "S"
		local a0, a1 = if alongX then r.x0 else r.z0, if alongX then r.x1 else r.z1
		local n = math.floor((a1 - a0) / 12)
		for k = 1, n do
			local at = a0 + (a1 - a0) * k / (n + 1)
			if placed < 4 and spanFree(r, side, at - 2.5, at + 2.5) then
				placed += 1
				local px, pz = wallPoint(r, side, at, 0)
				local inX = if side == "W" then 1 elseif side == "E" then -1 else 0
				local inZ = if side == "N" then 1 elseif side == "S" then -1 else 0
				local function slab(name, half, d0, d1, y0, y1, color, mat)
					local ax0, ax1 = px - (if alongX then half else 0), px + (if alongX then half else 0)
					local az0, az1 = pz - (if alongX then 0 else half), pz + (if alongX then 0 else half)
					if not alongX then
						ax0, ax1 = math.min(px + inX * d0, px + inX * d1), math.max(px + inX * d0, px + inX * d1)
					else
						az0, az1 = math.min(pz + inZ * d0, pz + inZ * d1), math.max(pz + inZ * d0, pz + inZ * d1)
					end
					deco(f, name, ax0, ax1, y0, y1, az0, az1, color, mat)
				end
				slab("Frame", 2, 0.05, 0.25, b + 6, b + 11, "Brass", Enum.Material.Metal)
				slab("Canvas", 1.6, 0.1, 0.32, b + 6.4, b + 10.6, if placed % 2 == 0 then "Velvet" else "TealDeep", Enum.Material.Fabric)
			end
		end
	end
end
function Kits.telescope(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	local top = ManorLayout.topY(Manor, r)
	cyl(f, "Mount", cx, b + 2, cz + 4, 4, 2, "Iron")
	local tube = cyl(f, "Telescope", cx, b + 7, cz + 4, 12, 1.6, "Brass")
	tube.CFrame = CFrame.new(cx, b + 7, cz + 2) * CFrame.Angles(math.rad(50), math.rad(90), 0)
	for k = 1, 5 do
		local a = k * 1.3
		local star = Build.part({ name = "Star", parent = f, shape = Enum.PartType.Ball, size = Vector3.new(0.5, 0.5, 0.5), pos = Vector3.new(cx + math.cos(a) * 7, top - 0.6 - (k % 2) * 0.3, cz + math.sin(a) * 9), color = "Cream", material = Enum.Material.Neon, collide = false })
		star.CastShadow = false
	end
end
function Kits.telegraph(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	deco(f, "Desk", cx - 4, cx + 4, b + 2.8, b + 3.2, cz - 2, cz + 2, "Walnut")
	deco(f, "DeskBase", cx - 3.5, cx + 3.5, b, b + 2.8, cz - 1.5, cz + 1.5, "WalnutDark")
	cyl(f, "Sounder", cx - 1.5, b + 3.7, cz, 1, 1.2, "Brass")
	cyl(f, "Key", cx + 1.5, b + 3.45, cz, 0.5, 0.8, "Copper")
end
function Kits.beds(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, dx in { -9, 9 } do
		deco(f, "BedFrame", cx + dx - 3, cx + dx + 3, b, b + 1.6, cz - 4.5, cz + 4.5, "Walnut")
		deco(f, "Mattress", cx + dx - 2.7, cx + dx + 2.7, b + 1.6, b + 2.6, cz - 4.2, cz + 4.2, "Cream", Enum.Material.Fabric)
		deco(f, "Quilt", cx + dx - 2.8, cx + dx + 2.8, b + 2.6, b + 2.8, cz - 1, cz + 4.3, "Velvet", Enum.Material.Fabric)
	end
end
function Kits.drafting(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, dz in { -7, 7 } do
		local top = deco(f, "DraftBoard", cx - 3, cx + 3, b + 3.2, b + 3.5, cz + dz - 2, cz + dz + 2, "Cream", Enum.Material.SmoothPlastic)
		top.CFrame = top.CFrame * CFrame.Angles(math.rad(20), 0, 0)
		deco(f, "DraftLeg", cx - 0.3, cx + 0.3, b, b + 3.1, cz + dz - 0.3, cz + dz + 0.3, "Iron", Enum.Material.Metal)
	end
end
function Kits.trophies(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for k = -1, 1 do
		local z = cz + k * 8
		deco(f, "Pedestal", cx - 1.2, cx + 1.2, b, b + 3.5, z - 1.2, z + 1.2, "Marble", Enum.Material.Marble)
		Build.part({ name = "Trophy", parent = f, shape = Enum.PartType.Ball, size = Vector3.new(1.6, 1.6, 1.6), pos = Vector3.new(cx, b + 4.4, z), color = "Brass", material = Enum.Material.Metal, collide = false })
	end
end
function Kits.tea(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, dx in { -10, 0, 10 } do
		cyl(f, "TeaTable", cx + dx, b + 2.6, cz, 0.4, 4, "Walnut", Enum.Material.Wood)
		cyl(f, "TeaLeg", cx + dx, b + 1.2, cz, 2.4, 0.5, "Brass")
		cyl(f, "Teapot", cx + dx, b + 3.3, cz, 1, 1.1, "Cream", Enum.Material.SmoothPlastic)
	end
end
function Kits.linen(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	deco(f, "Press", cx - 5, cx + 5, b, b + 3, cz - 2, cz + 2, "Iron", Enum.Material.Metal)
	for k = 0, 2 do
		deco(f, "Linen", cx - 4 + k * 3, cx - 2 + k * 3, b + 3, b + 3.6 + k * 0.4, cz - 1.4, cz + 1.4, "Cream", Enum.Material.Fabric)
	end
end
function Kits.barrels(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for k = 0, 5 do
		local x = cx - 10 + (k % 3) * 10
		local z = cz - 4 + math.floor(k / 3) * 8
		cyl(f, "Barrel", x, b + 2, z, 4, 3.2, if k % 2 == 0 then "Walnut" else "WalnutDark", Enum.Material.Wood)
	end
end
function Kits.boiler(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	cyl(f, "Boiler", cx, b + 5, cz, 10, 7, "Copper")
	cyl(f, "Firebox", cx, b + 1, cz + 3.9, 2, 1.4, "BreakerBad", Enum.Material.Neon, false)
	for _, dx in { -5, 5 } do
		cyl(f, "Flue", cx + dx, b + 8, cz, 14, 1, "Iron")
	end
end
function Kits.generator(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, dz in { -8, 8 } do
		cyl(f, "Dynamo", cx - 4, b + 3, cz + dz, 6, 5, "Iron", nil, false)
		cyl(f, "Coil", cx - 4, b + 3, cz + dz, 6.3, 2.2, "TealNeon", Enum.Material.Neon, false)
	end
end

local function buildRoomDecor(decor: Instance, r)
	local kit = r.decor and Kits[r.decor]
	if kit then
		local f = Instance.new("Model")
		f.Name = "Decor_" .. r.id
		kit(f, r, ManorLayout.baseY(Manor, r))
		f.Parent = decor
	end
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
	t2.Text = "Mystery at Sterling Manor"
	t2.Parent = sg
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
	f.Parent = map
end

-- Grass outside the manor: four slabs around the service stairwell (it drops through the
-- ground line, so the lawn must not cut it).
local function buildGrounds(map: Instance)
	local hole
	for _, r in Manor.Rooms do
		if r.stair and r.level < 0 then
			hole = r
		end
	end
	local X0, X1, Z0, Z1 = -210, 210, -180, 240
	local y0, y1 = -2.1, -1.1
	local function slab(x0, x1, z0, z1)
		if x1 - x0 > 0.1 and z1 - z0 > 0.1 then
			Build.part({ name = "Grounds", parent = map, size = Vector3.new(x1 - x0, y1 - y0, z1 - z0), pos = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color = Color3.fromRGB(56, 74, 44), material = Enum.Material.Grass })
		end
	end
	if hole then
		-- the hole is 0.1 wider than the shaft so the lawn's cut faces sit inside the walls
		local hx0, hx1, hz0, hz1 = hole.x0 - 0.1, hole.x1 + 0.1, hole.z0 - 0.1, hole.z1 + 0.1
		slab(X0, X1, Z0, hz0)
		slab(X0, X1, hz1, Z1)
		slab(X0, hx0, hz0, hz1)
		slab(hx1, X1, hz0, hz1)
	else
		slab(X0, X1, Z0, Z1)
	end
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
			chandelier(rm, lx, lz, top, r.id, lights, if tall then 12 else 2.4, r.id == "ballroom")
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
		if b.kind == "Floor" then
			local fm = FloorMat[b.floor] or FloorMat.Walnut
			boxPart(roomModels[rid], b, fm[2], fm[1])
		elseif b.kind == "Ceiling" then
			local r = m[rid]
			boxPart(roomModels[rid], b, if r.decor == "telescope" then "Navy" else "Ceiling", Enum.Material.Wood)
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
			local look = Look[b.kind] or Look.Wall
			local parent = if b.kind == "DoorPost" or b.kind == "Lintel" then doorsFolder else wallsFolder
			boxPart(parent, b, look[1], look[2], look[3])
		end
	end

	-- dressing
	local decor = Build.folder("Decor", manor)
	for _, r in Manor.Rooms do
		buildRoomDecor(decor, r)
	end

	-- breaker terminals
	local breakersFolder = Build.folder("Breakers", manor)
	local breakers = {}
	for _, spec in ManorLayout.breakers(Manor) do
		breakers[spec.id] = breakerModel(breakersFolder, spec, ManorLayout.topY(Manor, m[spec.room]))
	end
	-- service lift panels
	local liftsFolder = Build.folder("Lifts", manor)
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

	built = { map = map, manor = manor, roomLights = roomLights, breakers = breakers, lifts = lifts }
	return built
end

function ManorBuilder.get()
	return built
end

return ManorBuilder
