-- Phone-readable minimap + objective compass for the 3-floor manor.
-- Minimap: north-up plan of the floor you are on (rooms from Config/Manor, built once as plain
-- Frames in scale units, so it is cheap on phones and resizes with the HUD), your room
-- highlighted, breakers (green / red when tripped), the objective and a heading needle for you.
-- Compass: a needle pointing (relative to your camera) at the NEXT waypoint of the route to your
-- objective (so it points at the right staircase), the objective name, distance and UP/DOWN.
-- Approach: 2D frames from data (no ViewportFrame clone of 2,000+ parts); see CREDITS research.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Manor = require(Shared.Config.Manor)
local Style = require(Shared.Config.Style)
local ManorLayout = require(Shared.Logic.ManorLayout)

local Minimap = {}

local function rgb(name: string): Color3
	local c = Style.Palette[name] or { 255, 255, 255 }
	return Color3.fromRGB(c[1], c[2], c[3])
end

local LABEL_H = 0.16 -- top strip of the minimap for the floor + room name
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for _, r in Manor.Rooms do
	minX, maxX = math.min(minX, r.x0), math.max(maxX, r.x1)
	minZ, maxZ = math.min(minZ, r.z0), math.max(maxZ, r.z1)
end
local W, H = maxX - minX, maxZ - minZ

-- world (x, z) -> minimap scale (u, v)
function Minimap.toMap(x: number, z: number): (number, number)
	return (x - minX) / W, LABEL_H + (z - minZ) / H * (1 - LABEL_H)
end

local frame: Frame = nil :: any
local compass: Frame = nil :: any
local roomFrames: { [string]: Frame } = {}
local breakerDots: { [string]: Frame } = {}
local me: Frame = nil :: any
local goalDot: Frame = nil :: any
local bellDot: Frame = nil :: any
local floorLabel: TextLabel = nil :: any
local needle: Frame = nil :: any
local compassText: TextLabel = nil :: any
local compassSub: TextLabel = nil :: any
local breakerSpecs = ManorLayout.breakers(Manor)
local lastGoalAt = -math.huge
local goal: any = nil
local nextPt: any = nil
local routeLen = 0

local function dot(name: string, color: string, size: number, z: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromScale(size, size)
	f.BackgroundColor3 = rgb(color)
	f.BorderSizePixel = 0
	f.ZIndex = z or 3
	f.Parent = frame
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	return f
end

function Minimap.build(mapFrame: Frame, compassFrame: Frame)
	frame = mapFrame
	compass = compassFrame
	for _, r in Manor.Rooms do
		local f = Instance.new("Frame")
		f.Name = "Room_" .. r.id
		local u0, v0 = Minimap.toMap(r.x0, r.z0)
		local u1, v1 = Minimap.toMap(r.x1, r.z1)
		f.Position = UDim2.fromScale(u0, v0)
		f.Size = UDim2.new(u1 - u0, -1, v1 - v0, -1)
		f.BackgroundColor3 = rgb(if r.stair then "Brass" elseif r.lift then "Copper" else "Teal")
		f.BackgroundTransparency = if r.balconyOf then 0.5 else 0.25
		f.BorderSizePixel = 0
		f.ZIndex = if r.balconyOf then 2 else 1
		f.Visible = false
		f.Parent = frame
		roomFrames[r.id] = f
	end
	for _, b in breakerSpecs do
		local d = dot("Breaker_" .. b.id, "BreakerOk", 0.07, 4)
		local u, v = Minimap.toMap(b.x, b.z)
		d.Position = UDim2.fromScale(u, v)
		d.Visible = false
		breakerDots[b.id] = d
	end
	goalDot = dot("Goal", "Bell", 0.08, 5)
	goalDot.Visible = false
	bellDot = dot("BellRang", "BreakerBad", 0.09, 5)
	bellDot.Visible = false
	me = dot("Me", "Cream", 0.08, 6)
	local head = Instance.new("Frame")
	head.Name = "Heading"
	head.AnchorPoint = Vector2.new(0.5, 1)
	head.Position = UDim2.fromScale(0.5, 0.5)
	head.Size = UDim2.fromScale(0.28, 1.1)
	head.BackgroundColor3 = rgb("TealNeon")
	head.BorderSizePixel = 0
	head.ZIndex = 7
	head.Parent = me
	floorLabel = Instance.new("TextLabel")
	floorLabel.Name = "Floor"
	floorLabel.BackgroundTransparency = 1
	floorLabel.Size = UDim2.fromScale(1, LABEL_H)
	floorLabel.Font = Enum.Font.GothamBold
	floorLabel.TextScaled = true
	floorLabel.TextColor3 = rgb("Brass")
	floorLabel.Text = ""
	floorLabel.ZIndex = 8
	floorLabel.Parent = frame
	-- compass: needle on the left, text on the right
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundColor3 = rgb("WalnutDark")
	ring.BorderSizePixel = 0
	ring.Size = UDim2.fromScale(0.2, 0.9)
	ring.Position = UDim2.fromScale(0.02, 0.05)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = ring
	ring.Parent = compass
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0.5, 0)
	rc.Parent = ring
	needle = Instance.new("Frame")
	needle.Name = "Needle"
	needle.AnchorPoint = Vector2.new(0.5, 0.5)
	needle.Position = UDim2.fromScale(0.5, 0.5)
	needle.Size = UDim2.fromScale(0.18, 0.86)
	needle.BackgroundColor3 = rgb("Bell")
	needle.BorderSizePixel = 0
	needle.Parent = ring
	local tip = Instance.new("Frame")
	tip.Name = "Tip"
	tip.Size = UDim2.fromScale(1, 0.4)
	tip.BackgroundColor3 = rgb("BreakerBad")
	tip.BorderSizePixel = 0
	tip.Parent = needle
	compassText = Instance.new("TextLabel")
	compassText.Name = "Text"
	compassText.BackgroundTransparency = 1
	compassText.Position = UDim2.fromScale(0.25, 0.04)
	compassText.Size = UDim2.fromScale(0.73, 0.5)
	compassText.Font = Enum.Font.GothamBold
	compassText.TextScaled = true
	compassText.TextColor3 = rgb("Cream")
	compassText.TextXAlignment = Enum.TextXAlignment.Left
	compassText.Text = ""
	compassText.Parent = compass
	compassSub = compassText:Clone()
	compassSub.Name = "Sub"
	compassSub.Position = UDim2.fromScale(0.25, 0.54)
	compassSub.Size = UDim2.fromScale(0.73, 0.42)
	compassSub.TextColor3 = rgb("TealNeon")
	compassSub.Parent = compass
end

local function myRoot(): BasePart?
	local p = Players.LocalPlayer
	local c = p and p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function closest(pos: Vector3, list)
	local best, bd = nil, math.huge
	for _, t in list do
		local d = (Vector3.new(t.x, t.y, t.z) - pos).Magnitude + math.abs(t.y - pos.Y) * 2
		if d < bd then
			best, bd = t, d
		end
	end
	return best
end

-- What the compass points at (pure-ish: reads the replicated world).
function Minimap.objective(who: string?, phase: string, pos: Vector3)
	local map = workspace:FindFirstChild("Map")
	local manor = map and map:FindFirstChild("Manor")
	if not manor or who == nil then
		return nil
	end
	local cands = {}
	local RH = ManorLayout.RootHeight
	local looksGuest = who == "Guest" or (who == "Phantom" and phase == "Day")
	if phase == "Night" and who == "Guest" then
		for _, b in breakerSpecs do
			local mdl = manor.Breakers:FindFirstChild("Breaker_" .. b.id)
			if mdl and mdl:GetAttribute("Tripped") then
				table.insert(cands, { x = b.standX, y = b.y + RH, z = b.standZ, label = "BREAKER " .. b.id })
			end
		end
	elseif phase == "Day" and who == "Phantom" then
		for _, b in breakerSpecs do
			table.insert(cands, { x = b.standX, y = b.y + RH, z = b.standZ, label = "BREAKER " .. b.id })
		end
	end
	if #cands == 0 and phase == "Day" and looksGuest then
		local chests = manor:FindFirstChild("Chests")
		for _, c in (if chests then chests:GetChildren() else {}) do
			local body = c:FindFirstChild("Body") :: BasePart?
			local prompt = body and body:FindFirstChild("Search")
			if body and prompt and not prompt:GetAttribute("Done") then
				local p = body.CFrame.Position
				table.insert(cands, { x = p.X, y = p.Y - 1 + RH, z = p.Z, label = "CHEST" })
			end
		end
	end
	if #cands == 0 and phase == "Night" and (who == "Phantom" or who == "Wisp") then
		for _, pl in Players:GetPlayers() do
			local c = pl ~= Players.LocalPlayer and pl.Character
			local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and pl:GetAttribute("PState") == "Guest" and pl:GetAttribute("InMatch") then
				local p = r.CFrame.Position
				table.insert(cands, { x = p.X, y = p.Y, z = p.Z, label = "GUEST" })
			end
		end
		local bots = workspace:FindFirstChild("Bots")
		for _, m in (if bots then bots:GetChildren() else {}) do
			local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and m:GetAttribute("PState") == "Guest" then
				local p = r.CFrame.Position
				table.insert(cands, { x = p.X, y = p.Y, z = p.Z, label = "GUEST" })
			end
		end
	end
	return closest(pos, cands)
end

local function facingAngle(look: Vector3): number
	-- clockwise degrees from north (-z) on the north-up map
	return math.deg(math.atan2(look.X, -look.Z))
end

function Minimap.update(who: string?, phase: string)
	if not frame then
		return
	end
	local root = myRoot()
	if not root then
		floorLabel.Text = ""
		compassText.Text = ""
		compassSub.Text = ""
		return
	end
	local pos = root.CFrame.Position
	local level = ManorLayout.levelAt(Manor, pos.Y)
	local here = ManorLayout.roomAt(Manor, pos.X, pos.Y, pos.Z)
	local m = ManorLayout.ids(Manor)
	for _, r in Manor.Rooms do
		local lo, hi = ManorLayout.span(r)
		local f = roomFrames[r.id]
		f.Visible = level >= lo and level <= hi
		local isHere = here == r.id
		f.BackgroundColor3 = if isHere then rgb("TealNeon") else rgb(if r.stair then "Brass" elseif r.lift then "Copper" else "Teal")
	end
	for _, b in breakerSpecs do
		local d = breakerDots[b.id]
		d.Visible = b.level == level
		local mdl = workspace:FindFirstChild("Map") and workspace.Map.Manor.Breakers:FindFirstChild("Breaker_" .. b.id)
		d.BackgroundColor3 = rgb(if mdl and mdl:GetAttribute("Tripped") then "BreakerBad" else "BreakerOk")
	end
	local floorName = ManorLayout.levelName(Manor, level)
	floorLabel.Text = string.upper(floorName) -- short: legible at phone size (your room is lit up)
	local u, v = Minimap.toMap(pos.X, pos.Z)
	me.Position = UDim2.fromScale(u, v)
	local look = root.CFrame.LookVector
	me.Rotation = facingAngle(look)
	-- the bell that rang lately
	local bellAt = workspace:GetAttribute("CM_BellAt")
	local bellT = workspace:GetAttribute("CM_BellTime")
	bellDot.Visible = false
	if type(bellAt) == "string" and type(bellT) == "number" and workspace:GetServerTimeNow() - bellT < 8 then
		local parts = string.split(bellAt, ",")
		local bx, by, bz = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
		if bx and by and bz and ManorLayout.levelAt(Manor, by) == level then
			local bu, bv = Minimap.toMap(bx, bz)
			bellDot.Position = UDim2.fromScale(bu, bv)
			bellDot.Visible = true
		end
	end
	-- objective + route (twice a second)
	local now = os.clock()
	if now - lastGoalAt > 0.5 then
		lastGoalAt = now
		goal = Minimap.objective(who, phase, pos)
		nextPt, routeLen = nil, 0
		if goal then
			local from = { x = pos.X, y = pos.Y, z = pos.Z }
			local pts = ManorLayout.route(Manor, from, goal)
			if pts then
				local prev = from
				for _, p in pts do
					routeLen += ManorLayout.dist3(prev, p)
					prev = p
					if nextPt == nil and (Vector3.new(p.x - pos.X, 0, p.z - pos.Z)).Magnitude > 4 then
						nextPt = p
					end
				end
				routeLen += ManorLayout.dist3(prev, goal)
			else
				routeLen = ManorLayout.dist3(from, goal)
			end
			nextPt = nextPt or goal
		end
	end
	goalDot.Visible = false
	if not goal then
		compassText.Text = if phase == "Night" and who == "Guest" then "GRID OK" else ""
		compassSub.Text = if phase == "Night" and who == "Guest" then "STAY TOGETHER" else ""
		needle.Visible = false
		return
	end
	local gl = ManorLayout.levelAt(Manor, goal.y)
	if gl == level then
		local gu, gv = Minimap.toMap(goal.x, goal.z)
		goalDot.Position = UDim2.fromScale(gu, gv)
		goalDot.Visible = true
	end
	-- needle relative to the camera's heading
	local cam = workspace.CurrentCamera
	local okCam, camLook = pcall(function()
		return cam.CFrame.LookVector
	end)
	local fwd = if okCam and typeof(camLook) == "Vector3" then camLook else look
	local fx, fz = fwd.X, fwd.Z
	local fl = math.sqrt(fx * fx + fz * fz)
	if fl < 1e-3 then
		fx, fz, fl = 0, -1, 1
	end
	fx, fz = fx / fl, fz / fl
	local dx, dz = nextPt.x - pos.X, nextPt.z - pos.Z
	local a = dx * fx + dz * fz -- along forward
	local b = dx * -fz + dz * fx -- along right
	needle.Rotation = math.deg(math.atan2(b, a))
	needle.Visible = true
	local hint = if gl > level then " - GO UP" elseif gl < level then " - GO DOWN" else ""
	compassText.Text = goal.label
	compassSub.Text = string.format("%d m%s", math.floor(routeLen), hint)
end

function Minimap.state()
	return { goal = goal, nextPt = nextPt, routeLen = routeLen, frames = roomFrames, compassText = compassText, compassSub = compassSub, floorLabel = floorLabel, here = nil }
end

return Minimap
