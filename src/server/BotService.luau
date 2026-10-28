-- Bots: server NPC participants that fill a match to Config/Match.MinPlayers. They use the
-- SAME server entry points as players (ChestService.open, GridService.beginTamper/Repair,
-- LanternService, ChaseService.tryTag / flicker / slick), so every rule, range and cooldown
-- holds for them too. Brains are pure (Logic/BotBrain); movement walks room to room through
-- doors, up stair flights and by service lift (Logic/ManorLayout.route) with Humanoid:MoveTo and
-- hops to the next waypoint when stuck (Luau Execution sessions do not step physics). Bots never save anything.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cfg = require(Shared.Config.Bots)
local Gadgets = require(Shared.Config.Gadgets)
local Items = require(Shared.Config.Items)
local Manor = require(Shared.Config.Manor)
local BotBrain = require(Shared.Logic.BotBrain)
local ManorLayout = require(Shared.Logic.ManorLayout)
local Cooldown = require(Shared.Logic.Cooldown)
local Billboard = require(Shared.Billboard)
local Build = require(script.Parent.Build)
local Participants = require(script.Parent.Participants)
local ChestService = require(script.Parent.ChestService)
local GridService = require(script.Parent.GridService)
local LanternService = require(script.Parent.LanternService)
local ChaseService = require(script.Parent.ChaseService)
local ItemService = require(script.Parent.ItemService)
local LiftService = require(script.Parent.LiftService)
local Clock = require(script.Parent.Clock)

local BotService = {}

local bots: { any } = {}
local serial = 0
local accum = 0
local night: any = nil
local unstick = Cfg.UnstickSeconds

local paused = false

function BotService.setUnstickSeconds(s: number)
	unstick = s
end

-- Tests freeze the brains to stage exact situations.
function BotService.setPaused(on: boolean)
	paused = on
end

local function folder(): Instance
	return workspace:FindFirstChild("Bots") or Build.folder("Bots", workspace)
end

local function simpleRig(name: string, look): Model
	local model = Instance.new("Model")
	model.Name = name
	local function part(n: string, size: Vector3, offset: Vector3, color, collide: boolean): Part
		return Build.part({ name = n, parent = model, size = size, pos = offset, color = Build.rgb(color), material = Enum.Material.SmoothPlastic, anchored = false, collide = collide, massless = n ~= "HumanoidRootPart" })
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), { 255, 255, 255 }, true)
	root.Transparency = 1
	part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), look[2], false)
	part("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), look[1], false)
	part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), look[3], false)
	part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), look[3], false)
	part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), look[4], false)
	part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), look[4], false)
	-- a little top hat: everyone's dressed for the masquerade
	part("HatBrim", Vector3.new(1.6, 0.15, 1.6), Vector3.new(0, 5.25, 0), { 30, 26, 30 }, false)
	part("Hat", Vector3.new(1, 0.9, 1), Vector3.new(0, 5.75, 0), { 30, 26, 30 }, false)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			Build.weld(root, p)
		end
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = Gadgets.Guest.walkSpeed
	humanoid.Parent = model
	model.PrimaryPart = root
	local head = model:FindFirstChild("Head") :: BasePart
	local tag = Billboard.new("NameTag", "NameTag")
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.Parent = head
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = name .. " [BOT]"
	label.Parent = tag
	return model
end

local function buildRig(name: string, look): Model
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = Build.rgb(look[1])
		desc.TorsoColor = Build.rgb(look[2])
		desc.LeftArmColor = Build.rgb(look[3])
		desc.RightArmColor = Build.rgb(look[3])
		desc.LeftLegColor = Build.rgb(look[4])
		desc.RightLegColor = Build.rgb(look[4])
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and typeof(model) == "Instance" then
		local m = model :: Model
		m.Name = name
		local h = m:FindFirstChildOfClass("Humanoid") :: Humanoid
		h.DisplayName = name .. " [BOT]"
		h.WalkSpeed = Gadgets.Guest.walkSpeed
		return m
	end
	return simpleRig(name, look)
end

function BotService.spawn(count: number, usedNames: { [string]: boolean }?)
	local made = {}
	for _ = 1, count do
		serial += 1
		local name
		for k = 0, #Cfg.Names - 1 do
			local cand = Cfg.Names[((serial + k - 1) % #Cfg.Names) + 1]
			if not (usedNames and usedNames[cand]) then
				name = cand
				break
			end
		end
		name = name or ("Bot " .. serial)
		if usedNames then
			usedNames[name] = true
		end
		local model = buildRig(name, Cfg.Looks[((serial - 1) % #Cfg.Looks) + 1])
		model:SetAttribute("IsBot", true)
		model.Parent = folder()
		local a = serial * 2.39996 -- golden-angle spread: bots don't all stand on one spot
		local p = { id = "B" .. serial, name = name, isBot = true, model = model, path = {}, progressAt = 0, lastDist = math.huge, tickAt = 0, jx = math.cos(a) * 2.5, jz = math.sin(a) * 2.5 }
		table.insert(bots, p)
		table.insert(made, p)
	end
	return made
end

function BotService.despawnAll()
	for _, b in bots do
		if b.model then
			b.model:Destroy()
		end
	end
	table.clear(bots)
end

function BotService.count(): number
	return #bots
end

function BotService.list()
	return bots
end

function BotService.setNight(n)
	night = n
end

-- ---- movement ------------------------------------------------------------------------------
-- Routes come from Logic/ManorLayout.route (Dijkstra over doors, stair flights and the lift);
-- every waypoint carries a y (root height), and `lift = level` waypoints ride the service lift.
local function planTo(b, x: number, y: number?, z: number)
	local pos = Participants.pos(b)
	if not pos then
		return
	end
	local ty = y or pos.Y
	local goal = { x = x, y = ty, z = z }
	local to = ManorLayout.roomAt(Manor, x, ty, z)
	if to then
		local room = ManorLayout.ids(Manor)[to]
		goal.x, goal.z = ManorLayout.clampInto(room, x, z, 2)
	end
	local pts = ManorLayout.route(Manor, { x = pos.X, y = pos.Y, z = pos.Z }, goal) or {}
	table.insert(pts, goal)
	b.path = pts
	b.goal = goal
	b.progressAt = Clock.now()
	b.lastDist = math.huge
	b.plans = (b.plans or 0) + 1
end
BotService.planTo = planTo

local function stop(b)
	b.path = {}
	b.goal = nil
	local h = Participants.humanoid(b)
	local pos = Participants.pos(b)
	if h and pos then
		h:MoveTo(pos)
	end
end

local function note(b, pos: Vector3)
	local lvl = ManorLayout.levelAt(Manor, pos.Y)
	b.levels = b.levels or {}
	b.levels[lvl] = true
end

local function walk(b)
	local pt = b.path[1]
	if not pt then
		return
	end
	local root = Participants.root(b)
	local h = Participants.humanoid(b)
	if not root or not h then
		return
	end
	local pos = root.CFrame.Position
	note(b, pos)
	local function arrived(q)
		return Vector3.new(q.x - pos.X, 0, q.z - pos.Z).Magnitude <= Cfg.ArriveDistance and math.abs((q.y or pos.Y) - pos.Y) < 5
	end
	if arrived(pt) then
		if pt.lift then
			LiftService.ride(b, pt.lift)
		end
		table.remove(b.path, 1)
		b.progressAt = Clock.now()
		b.lastDist = math.huge
		pt = b.path[1]
		if not pt then
			return
		end
		pos = root.CFrame.Position
	end
	local d = Vector3.new(pt.x - pos.X, (pt.y or pos.Y) - pos.Y, pt.z - pos.Z).Magnitude
	if d < b.lastDist - 0.5 then
		b.lastDist = d
		b.progressAt = Clock.now()
	elseif Clock.now() - b.progressAt > unstick then
		-- stuck (or no physics): hop to the waypoint
		b.model:PivotTo(CFrame.new(pt.x, pt.y or pos.Y, pt.z) * (root.CFrame - root.CFrame.Position))
		b.hops = (b.hops or 0) + 1
		if pt.lift then
			LiftService.ride(b, pt.lift)
		end
		table.remove(b.path, 1)
		b.progressAt = Clock.now()
		b.lastDist = math.huge
		pt = b.path[1]
		if not pt then
			return
		end
		pos = root.CFrame.Position
	end
	h:MoveTo(Vector3.new(pt.x, pt.y or pos.Y, pt.z))
end

-- ---- world view --------------------------------------------------------------------------
local breakerSpecs = ManorLayout.breakers(Manor)
local function view(b)
	local RH = ManorLayout.RootHeight
	local w = { phase = workspace:GetAttribute("CM_Phase"), timeLeft = (workspace:GetAttribute("CM_PhaseEndsAt") or 0) - Clock.now(), guests = {}, phantoms = {}, decoys = {}, chests = {}, breakers = {}, fleeSpots = {} }
	for _, q in Participants.all() do
		local pos = Participants.pos(q)
		if pos then
			if q.role == "Guest" and q.state == "Guest" then
				table.insert(w.guests, { id = q.id, x = pos.X, y = pos.Y, z = pos.Z })
			elseif q.role == "Phantom" and q.state == "Phantom" then
				-- guests only "see" Phantoms once they have transformed (night)
				table.insert(w.phantoms, { id = q.id, x = pos.X, y = pos.Y, z = pos.Z })
			end
		end
	end
	for _, dc in ItemService.decoys() do
		table.insert(w.decoys, { id = dc.id, x = dc.x, y = dc.y, z = dc.z })
	end
	for _, c in ChestService.unopened() do
		table.insert(w.chests, { id = c.id, x = c.x, y = c.y + RH, z = c.z })
	end
	local grid = GridService.state()
	if grid then
		for _, spec in breakerSpecs do
			local br = grid.breakers[spec.id]
			if br then
				-- guests only learn a breaker is broken when it trips at night
				local tampered = br.tampered and (b.role == "Phantom" or w.phase == "Night")
				table.insert(w.breakers, { id = spec.id, x = spec.standX, y = spec.y + RH, z = spec.standZ, tampered = tampered })
			end
		end
		w.tampersLeft = (night and night.maxTampers or 1) - grid.tampers
	end
	local pos = Participants.pos(b)
	if pos then
		local here = ManorLayout.roomAt(Manor, pos.X, pos.Y, pos.Z)
		if here then
			local m = ManorLayout.ids(Manor)
			w.room = m[here]
			local cx, cz = ManorLayout.centre(m[here])
			table.insert(w.fleeSpots, { x = cx, y = pos.Y, z = cz })
			for _, d in Manor.Doors do
				if d.a == here or d.b == here then
					local other = m[if d.a == here then d.b else d.a]
					local info = ManorLayout.doorInfo(Manor, d)
					local ox, oz = ManorLayout.centre(other)
					local oy = if other.stair or (other.span or 1) > 1 then info.y + RH else ManorLayout.baseY(Manor, other) + RH
					table.insert(w.fleeSpots, { x = ox, y = oy, z = oz })
				end
			end
			local inRoom = 0
			for _, g in w.guests do
				if ManorLayout.roomAt(Manor, g.x, g.y, g.z) == here then
					inRoom += 1
				end
			end
			w.guestsInRoom = inRoom
		end
	end
	return w
end

local function think(b)
	local pos = Participants.pos(b)
	if not pos or night == nil then
		return
	end
	local now = Clock.now()
	local ready = {}
	for id, def in Items.Defs do
		ready[id] = b.itemAt == nil or b.itemAt[id] == nil or now - b.itemAt[id] >= (def.cooldown or 0)
	end
	local me = {
		id = b.id, x = pos.X, y = pos.Y, z = pos.Z, state = b.state, battery = b.battery or 0, inv = b.inv, itemReady = ready,
		slickReady = Cooldown.ready(b.lastSlick, Gadgets.Wisp.slickCooldown, now),
		flickerReady = Cooldown.ready(b.lastFlicker, Gadgets.Wisp.flickerCooldown, now),
	}
	local w = view(b)
	local d
	if b.state == "Bubble" then
		return
	elseif b.state == "Wisp" then
		d = BotBrain.wisp(me, w, Cfg, Gadgets)
	elseif b.role == "Phantom" then
		d = BotBrain.phantom(me, w, Cfg, Gadgets, night)
	else
		d = BotBrain.guest(me, w, Cfg, Gadgets, night)
	end
	b.lastDecision = d.action
	-- items (same server entry point as players)
	if d.item then
		local opts = if d.itemDir then { dir = Vector3.new(d.itemDir.x, 0, d.itemDir.z) } else nil
		if ItemService.use(b, d.item, opts) then
			b.itemsUsed = b.itemsUsed or {}
			b.itemsUsed[d.item] = (b.itemsUsed[d.item] or 0) + 1
		end
	end
	-- lantern
	if b.role == "Guest" and b.state == "Guest" then
		if d.lantern then
			LanternService.setOn(b, true)
			LanternService.aimAtPoint(b, Vector3.new(d.aimX, pos.Y, d.aimZ))
			-- a guest under threat drops a glow-stick to expose the Phantom
			if (b.inv.GlowStick or 0) > 0 and Cooldown.ready(b.lastGlow, 12, now) and ItemService.use(b, "GlowStick") then
				b.lastGlow = now
				b.itemsUsed = b.itemsUsed or {}
				b.itemsUsed.GlowStick = (b.itemsUsed.GlowStick or 0) + 1
			end
		elseif b.lanternOn then
			LanternService.setOn(b, false)
		end
	end
	local a = d.action
	if a == "move" then
		local g = b.goal
		local tx, tz = d.x + (b.jx or 0), d.z + (b.jz or 0)
		if d.exact or (b.role == "Phantom" and b.state == "Phantom") then
			tx, tz = d.x, d.z -- a hunter goes straight for its target
		end
		local ty = d.y or pos.Y
		if g == nil or math.abs(g.x - tx) + math.abs(g.z - tz) + math.abs((g.y or ty) - ty) > 4 or #b.path == 0 then
			planTo(b, tx, ty, tz)
		end
		GridService.cancel(b)
		b.dwell = nil
	elseif a == "open" then
		stop(b)
		if b.dwell == nil or b.dwell.id ~= d.id then
			b.dwell = { id = d.id, at = now }
		elseif now - b.dwell.at >= night.chestOpenSeconds then
			ChestService.open(b, d.id)
			b.dwell = nil
		end
	elseif a == "tamper" then
		stop(b)
		if GridService.channelling(b) ~= "Tamper" then
			GridService.beginTamper(b, d.id)
		end
	elseif a == "repair" then
		stop(b)
		if GridService.channelling(b) ~= "Repair" then
			GridService.beginRepair(b, d.id)
		end
	elseif a == "tag" then
		ChaseService.tryTag(b, d.id)
		local t = Participants.get(d.id)
		local tp = t and Participants.pos(t)
		if tp then
			planTo(b, tp.X, tp.Y, tp.Z)
		end
	elseif a == "slick" then
		ChaseService.slick(b)
	elseif a == "flicker" then
		ChaseService.flicker(b)
	end
end

function BotService.step(dt: number)
	if paused then
		return
	end
	accum += dt
	local doThink = accum >= Cfg.TickSeconds
	if doThink then
		accum = 0
	end
	for _, b in bots do
		if b.gone or b.role == nil then
			continue
		end
		if doThink then
			local ok, err = pcall(think, b)
			if not ok then
				warn("[BotService] " .. b.name .. ": " .. tostring(err))
			end
		end
		if b.state ~= "Bubble" then
			walk(b)
		end
	end
end

return BotService
