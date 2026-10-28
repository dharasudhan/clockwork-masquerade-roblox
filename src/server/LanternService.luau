-- Guest lanterns (night only): battery, dry-cell recharge, aim from the client camera (rate
-- limited, sanitised, falls back to the body's facing when stale), the visible beam and the
-- server-side cone + line-of-sight test that slows Phantoms (Logic/Lantern; stacking, capped).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Gadgets = require(Shared.Config.Gadgets)
local Lantern = require(Shared.Logic.Lantern)
local Loot = require(Shared.Logic.Loot)
local Build = require(script.Parent.Build)
local Participants = require(script.Parent.Participants)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local LanternService = {}
local G = Gadgets.Lantern

local beams: { [string]: number } = {} -- phantom id -> beams on it this tick

local function rig(p)
	local root = Participants.root(p)
	if not root then
		return nil
	end
	local o = root:FindFirstChild("LanternOrigin") :: Attachment?
	if o == nil then
		local origin = Instance.new("Attachment")
		origin.Name = "LanternOrigin"
		origin.Position = Vector3.new(0.9, 0.8, -0.8)
		origin.Parent = root
		local tip = Instance.new("Attachment")
		tip.Name = "LanternTip"
		tip.Position = Vector3.new(0.9, 0.8, -G.range)
		tip.Parent = root
		local light = Build.light(origin, "SpotLight", Build.color("Warm"), 3, G.range, true) :: SpotLight
		light.Name = "Beam"
		light.Angle = G.halfAngle * 2
		light.Face = Enum.NormalId.Front
		light.Enabled = false
		local beam = Instance.new("Beam")
		beam.Name = "BeamFx"
		beam.Attachment0 = origin
		beam.Attachment1 = tip
		beam.Width0 = 0.6
		beam.Width1 = math.tan(math.rad(G.halfAngle)) * G.range * 1.2
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(Build.color("Warm"))
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		beam.Segments = 2
		beam.Enabled = false
		beam.Parent = origin
		local lamp = Build.part({ name = "LanternLamp", parent = p.model, size = Vector3.new(0.7, 0.9, 0.7), cf = root.CFrame * CFrame.new(0.9, 0.2, -0.6), color = "Brass", material = Enum.Material.Metal, anchored = false, collide = false, massless = true, query = false })
		Build.weld(root, lamp)
		o = origin
	end
	return o
end

function LanternService.equip(p)
	p.battery = G.startBattery
	p.lanternOn = false
	Participants.set(p, "Battery", p.battery)
	Participants.set(p, "LanternOn", false)
	rig(p)
end

local function show(p, on: boolean)
	local root = Participants.root(p)
	local o = root and root:FindFirstChild("LanternOrigin")
	if o then
		(o :: any).Beam.Enabled = on;
		(o :: any).BeamFx.Enabled = on
	end
end

function LanternService.setOn(p, on: boolean): boolean
	if on and (workspace:GetAttribute("CM_Phase") ~= "Night" or p.state ~= "Guest" or p.role ~= "Guest" or p.battery <= 0) then
		return false
	end
	if p.lanternOn == on then
		return true
	end
	p.lanternOn = on
	Participants.set(p, "LanternOn", on)
	rig(p)
	show(p, on)
	return true
end

function LanternService.setAim(p, x: any, y: any, z: any)
	local ax, ay, az = Lantern.cleanAim(x, y, z)
	if ax then
		p.aim = Vector3.new(ax, ay, az)
		p.aimAt = Clock.now()
	end
end

-- Bots aim at a point.
function LanternService.aimAtPoint(p, point: Vector3)
	local pos = Participants.pos(p)
	if pos then
		local d = point - pos
		LanternService.setAim(p, d.X, d.Y, d.Z)
	end
end

function LanternService.useCell(p): boolean
	if p.role ~= "Guest" or p.state ~= "Guest" or p.battery >= G.batteryMax - 0.5 then
		return false
	end
	if not Loot.take(p.inv, "DryCell") then
		return false
	end
	p.battery = Lantern.recharge(p.battery, G)
	Participants.set(p, "DryCell", p.inv.DryCell)
	Participants.set(p, "Battery", math.floor(p.battery * 10) / 10)
	if p.player then
		Net.toast(p.player, "Lantern recharged", "TealNeon")
	end
	return true
end

function LanternService.beamsOn(phantomId: string): number
	return beams[phantomId] or 0
end

local rayParams: RaycastParams? = nil
local function clearLine(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	if rayParams == nil then
		rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
	end
	local rp = rayParams :: RaycastParams
	rp.FilterDescendantsInstances = ignore
	local ok, hit = pcall(function()
		return workspace:Raycast(from, to - from, rp)
	end)
	return not ok or hit == nil
end

function LanternService.step(dt: number)
	table.clear(beams)
	local now = Clock.now()
	local night = workspace:GetAttribute("CM_Phase") == "Night"
	local phantoms = {}
	local ignore = {}
	for _, p in Participants.all() do
		if p.model then
			table.insert(ignore, p.model)
		end
		if p.role == "Phantom" and p.transformed then
			table.insert(phantoms, p)
		end
	end
	local fx = workspace:FindFirstChild("Effects")
	if fx then
		table.insert(ignore, fx)
	end
	for _, p in Participants.all() do
		if p.role ~= "Guest" then
			continue
		end
		if p.lanternOn and (not night or p.state ~= "Guest") then
			LanternService.setOn(p, false)
		end
		if not p.lanternOn then
			continue
		end
		local b, on = Lantern.drain(p.battery, dt, true, G)
		p.battery = b
		Participants.set(p, "Battery", math.floor(b * 10) / 10)
		if not on then
			LanternService.setOn(p, false)
			if p.player then
				Net.toast(p.player, "Lantern empty - use a dry-cell", "BreakerBad")
			end
			continue
		end
		local root = Participants.root(p)
		if not root then
			continue
		end
		local dir = if p.aim and p.aimAt and now - p.aimAt <= G.aimStaleSeconds then p.aim else root.CFrame.LookVector
		local origin = root.CFrame.Position + Vector3.new(0, 0.8, 0)
		-- visuals: point the beam + spotlight along the aim
		local o = root:FindFirstChild("LanternOrigin") :: Attachment?
		local tip = root:FindFirstChild("LanternTip") :: Attachment?
		if o and tip then
			local localDir = root.CFrame:VectorToObjectSpace(dir)
			o.CFrame = CFrame.lookAt(o.Position, o.Position + localDir)
			tip.Position = o.Position + localDir * G.range
		end
		for _, ph in phantoms do
			local pp = Participants.pos(ph)
			if pp then
				local inside = Lantern.inCone(origin, dir, pp, G.range, G.halfAngle)
				if inside and clearLine(origin, pp, ignore) then
					beams[ph.id] = (beams[ph.id] or 0) + 1
				end
			end
		end
	end
	for _, ph in phantoms do
		Participants.set(ph, "Beams", beams[ph.id] or 0)
	end
end

function LanternService.reset()
	table.clear(beams)
end

return LanternService
