-- The night chase: Phantom transform (neon mask, faster), server-validated tags (range, LOS,
-- cooldown) -> Energy Bubble -> Electro-Wisp (floating drone; flicker room lights cd 20 s,
-- oil slick cd 30 s max 2 alive; cannot tag), glow-sticks that outline nearby Phantoms, and
-- every participant's walk speed (lantern slow on Phantoms, slick slow on guests).
-- v1.2 (engagement pass): Rising Storm Phantom speed bonus (CM_EscSpeed), Last Stand survivor
-- speed (Logic/Escalation), manor-event speed (CM_EventSpeed), and "grazed" near-miss feedback
-- when a swipe just misses a guest.
-- v1.4 (deduction fix): a transformed Phantom's nametag is HIDDEN - a name over the monster
-- named its account and made the next Expose vote trivial. Guests keep their names by day.
local PhysicsService = game:GetService("PhysicsService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Gadgets = require(Shared.Config.Gadgets)
local Manor = require(Shared.Config.Manor)
local EscCfg = require(Shared.Config.Escalation)
local Lantern = require(Shared.Logic.Lantern)
local Escalation = require(Shared.Logic.Escalation)
local Cooldown = require(Shared.Logic.Cooldown)
local Loot = require(Shared.Logic.Loot)
local ManorLayout = require(Shared.Logic.ManorLayout)
local Items = require(Shared.Config.Items)
local Match = require(Shared.Config.Match)
local Build = require(script.Parent.Build)
local Participants = require(script.Parent.Participants)
local LanternService = require(script.Parent.LanternService)
local LightingService = require(script.Parent.LightingService)
local GridService = require(script.Parent.GridService)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local ChaseService = {}

local P, W, B, GS = Gadgets.Phantom, Gadgets.Wisp, Gadgets.Bubble, Gadgets.GlowStick
local slicks: { any } = {}
local glows: { any } = {}
local hooks = { tagged = nil :: any, decoys = nil :: any, decoyTagged = nil :: any, phantomSpeed = nil :: any, carryFactor = nil :: any, barrier = nil :: any }

-- v1.0 modifiers: finale Phantom speed (Overdrive), key carrier slowdown, projector barrier
function ChaseService.setModifiers(phantomSpeed, carryFactor, barrier)
	hooks.phantomSpeed = phantomSpeed
	hooks.carryFactor = carryFactor
	hooks.barrier = barrier
end

local GROUP_CHARS, GROUP_WISPS = "CMChars", "CMWisps"
local groupsReady = false
local function setupGroups()
	if groupsReady then
		return
	end
	groupsReady = true
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP_CHARS)
		PhysicsService:RegisterCollisionGroup(GROUP_WISPS)
		PhysicsService:CollisionGroupSetCollidable(GROUP_WISPS, GROUP_CHARS, false)
		PhysicsService:CollisionGroupSetCollidable(GROUP_WISPS, GROUP_WISPS, false)
	end)
end

local function setGroup(model: Instance, group: string)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			pcall(function()
				(d :: BasePart).CollisionGroup = group
			end)
		end
	end
end

function ChaseService.onTagged(cb)
	hooks.tagged = cb
end

-- ItemService registers its clockwork decoys: provider() -> { {id, x, y, z} }, popped(decoy, by)
function ChaseService.setDecoys(provider, popped)
	hooks.decoys = provider
	hooks.decoyTagged = popped
end

-- floor height under a position (slicks, glow-sticks sit on it)
local function floorY(pos: Vector3): number
	return ManorLayout.levelAt(Manor, pos.Y) * Manor.LevelHeight
end
ChaseService.floorY = floorY

local function effects(): Instance
	return workspace:FindFirstChild("Effects") or Build.folder("Effects", workspace)
end

local function setState(p, s: string)
	p.state = s
	Participants.set(p, "PState", s)
end

-- Called when a participant joins the round (spawned into the manor).
function ChaseService.prepare(p)
	setupGroups()
	if p.model then
		setGroup(p.model, GROUP_CHARS)
	end
end

-- v1.4: show/hide a participant's in-world name. The night Phantom is anonymous (hide);
-- everyone else keeps their name - daytime accusations need referable identity. Covers both
-- nametag flavours: the Humanoid default tag (DisplayDistanceType) and the bot NameTag gui.
local function setNameShown(p, shown: boolean)
	local m = p.model
	if not m then
		return
	end
	local h = m:FindFirstChildOfClass("Humanoid")
	if h then
		h.DisplayDistanceType = if shown then Enum.HumanoidDisplayDistanceType.Viewer else Enum.HumanoidDisplayDistanceType.None
	end
	local head = m:FindFirstChild("Head")
	local tag = head and (head:FindFirstChild("NameTag") :: BillboardGui?)
	if tag then
		tag.Enabled = shown
	end
end

-- ---- Phantom transform ------------------------------------------------------------------
local function maskOn(p)
	local m = p.model
	local head = m and m:FindFirstChild("Head") :: BasePart?
	if not head or m:FindFirstChild("PhantomMask") then
		return
	end
	local mask = Build.part({ name = "PhantomMask", parent = m, size = Vector3.new(1.3, 0.55, 0.3), cf = head.CFrame * CFrame.new(0, 0.15, -0.62), color = "MaskNeon", material = Enum.Material.Neon, anchored = false, collide = false, massless = true, query = false })
	Build.weld(head, mask)
	for _, s in { -1, 1 } do
		local horn = Build.part({ name = "MaskWing", parent = mask, size = Vector3.new(0.5, 0.25, 0.2), cf = mask.CFrame * CFrame.new(s * 0.8, 0.25, 0) * CFrame.Angles(0, 0, math.rad(s * -30)), color = "VioletNeon", material = Enum.Material.Neon, anchored = false, collide = false, massless = true, query = false })
		Build.weld(mask, horn)
	end
	Build.light(mask, "PointLight", Build.color("MaskNeon"), 2, 12)
	local mq = m:FindFirstChild("MasqueradeMask") :: BasePart?
	if mq then
		mq.Transparency = 1
		for _, d in mq:GetChildren() do
			if d:IsA("BasePart") then
				d.Transparency = 1
			end
		end
	end
	local hl = Instance.new("Highlight")
	hl.Name = "PhantomGlow"
	hl.FillColor = Build.color("VioletNeon")
	hl.FillTransparency = 0.75
	hl.OutlineColor = Build.color("MaskNeon")
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = m
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Static"
	pe.Color = ColorSequence.new(Build.color("VioletNeon"))
	pe.LightEmission = 1
	pe.Rate = 12
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Speed = NumberRange.new(1, 3)
	pe.Size = NumberSequence.new(0.3, 0)
	pe.Parent = mask
end

function ChaseService.nightFalls()
	local now = Clock.now()
	for _, p in Participants.phantoms() do
		setState(p, "Phantom")
		p.transformed = false
		p.transformUntil = now + P.transformSeconds
		Participants.set(p, "Transforming", true)
		maskOn(p)
		setNameShown(p, false) -- v1.4: the monster is anonymous
		p.lastTag = nil
		Participants.set(p, "TagReadyAt", now + P.transformSeconds)
	end
end

-- ---- tagging ------------------------------------------------------------------------------
local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local rayParams: RaycastParams? = nil
-- true when no wall stands between two characters (characters + effects are ignored)
local function clearLine(from: Vector3, to: Vector3): boolean
	local ignore = { effects() }
	for _, q in Participants.all() do
		if q.model then
			table.insert(ignore, q.model)
		end
	end
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

local function bubble(p)
	setState(p, "Bubble")
	GridService.cancel(p)
	LanternService.setOn(p, false)
	p.bubbleUntil = Clock.now() + B.seconds
	local root = Participants.root(p)
	if root then
		root.Anchored = true
		local orb = Build.part({ name = "EnergyBubble_" .. p.id, parent = effects(), shape = Enum.PartType.Ball, size = Vector3.new(7, 7, 7), pos = root.CFrame.Position, color = "Bubble", material = Enum.Material.ForceField, collide = false, query = false, shadow = false, transparency = 0.1 })
		Build.light(orb, "PointLight", Build.color("Bubble"), 2, 14)
		p.bubblePart = orb
	end
end

-- Server-validated tag. target may be nil (nearest untagged guest in range).
function ChaseService.tryTag(p, targetId: string?): boolean
	if workspace:GetAttribute("CM_Phase") ~= "Night" or p.role ~= "Phantom" or not p.transformed then
		return false
	end
	local now = Clock.now()
	if now < (p.frozenUntil or 0) or now < (p.stunUntil or 0) then
		return false
	end
	if not Cooldown.ready(p.lastTag, P.tagCooldown, now) then
		return false
	end
	local pos = Participants.pos(p)
	if not pos then
		return false
	end
	local slack = if p.isBot then 0 else 1.5 -- network latency allowance for real players
	local best, bd = nil, P.tagRange + slack
	for _, g in Participants.guests(true) do
		if (targetId == nil or g.id == targetId) and now >= (g.immuneUntil or 0) then
			local gp = Participants.pos(g)
			if gp and math.abs(gp.Y - pos.Y) < 6 then
				local d = flatDist(gp, pos)
				if d <= bd and clearLine(pos, gp) then
					best, bd = g, d
				end
			end
		end
	end
	-- a clockwork decoy closer than any guest takes the tag (and the cooldown)
	local decoy = nil
	if hooks.decoys then
		for _, dc in hooks.decoys() do
			if targetId == nil or dc.id == targetId then
				local dp = Vector3.new(dc.x, dc.y, dc.z)
				if math.abs(dp.Y - pos.Y) < 6 then
					local d = flatDist(dp, pos)
					if d <= bd then
						decoy, bd, best = dc, d, nil
					end
				end
			end
		end
	end
	if decoy then
		p.lastTag = now
		Participants.set(p, "TagReadyAt", now + P.tagCooldown)
		if hooks.decoyTagged then
			hooks.decoyTagged(decoy, p)
		end
		return true
	end
	if not best then
		-- v1.2: near miss - a guest just outside swipe range gets a heartbeat moment
		-- (rate-limited so a camping Phantom cannot spam it).
		local near, nd = nil, math.huge
		for _, g in Participants.guests(true) do
			local gp = Participants.pos(g)
			if gp and math.abs(gp.Y - pos.Y) < 6 then
				local d = flatDist(gp, pos)
				if d < nd then
					near, nd = g, d
				end
			end
		end
		if near and nd <= P.tagRange + 3.5 and now - (p.lastGraze or 0) > 4 then
			p.lastGraze = now
			if near.player then
				Net.sfx(near.player, "Tag")
				Net.toast(near.player, "A Phantom's claws grazed you - RUN!", "MaskNeon")
			end
		end
		return false
	end
	p.lastTag = now
	Participants.set(p, "TagReadyAt", now + P.tagCooldown)
	p.stats.tags += 1
	bubble(best)
	Net.sfx("all", "Tag")
	Net.toast("all", best.name .. " was caught in an Energy Bubble!", "Bubble")
	if hooks.tagged then
		hooks.tagged(p, best)
	end
	return true
end

-- ---- Electro-Wisp -------------------------------------------------------------------------
local function becomeWisp(p)
	if p.bubblePart then
		p.bubblePart:Destroy()
		p.bubblePart = nil
	end
	local m = p.model
	local root = Participants.root(p)
	if not m or not root then
		setState(p, "Wisp")
		return
	end
	root.Anchored = false
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Transparency = 1
		elseif d:IsA("Decal") then
			d.Transparency = 1
		end
	end
	local orb = Build.part({ name = "WispOrb", parent = m, shape = Enum.PartType.Ball, size = Vector3.new(1.8, 1.8, 1.8), cf = root.CFrame * CFrame.new(0, W.hover, 0), color = "Wisp", material = Enum.Material.Neon, anchored = false, collide = false, massless = true, query = false })
	Build.weld(root, orb)
	local ring = Build.part({ name = "WispRing", parent = m, shape = Enum.PartType.Cylinder, size = Vector3.new(0.2, 3, 3), cf = orb.CFrame * CFrame.Angles(0, 0, math.rad(90)), color = "Copper", material = Enum.Material.Metal, anchored = false, collide = false, massless = true, query = false })
	Build.weld(orb, ring)
	Build.light(orb, "PointLight", Build.color("Wisp"), 1.6, 12)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkle"
	pe.Color = ColorSequence.new(Build.color("Wisp"))
	pe.LightEmission = 1
	pe.Rate = 10
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.Size = NumberSequence.new(0.25, 0)
	pe.Parent = orb
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA"
	a0.Position = Vector3.new(0, 0.6, 0)
	a0.Parent = orb
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailB"
	a1.Position = Vector3.new(0, -0.6, 0)
	a1.Parent = orb
	local trail = Instance.new("Trail")
	trail.Name = "WispTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Build.color(p.trailColor or "Wisp"))
	trail.LightEmission = 1
	trail.Lifetime = 0.6
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = orb
	setGroup(m, GROUP_WISPS)
	setState(p, "Wisp")
	Participants.set(p, "FlickerReadyAt", 0)
	Participants.set(p, "SlickReadyAt", 0)
	if p.player then
		Net.toast(p.player, "You're an Electro-Wisp! Flicker lights and drop oil slicks", "Wisp")
		Net.sfx(p.player, "Wisp")
	end
end

local function roomOf(p): string?
	local pos = Participants.pos(p)
	return pos and ManorLayout.roomAt(Manor, pos.X, pos.Y, pos.Z)
end
ChaseService.roomOf = roomOf

function ChaseService.flicker(p): boolean
	if p.state ~= "Wisp" or workspace:GetAttribute("CM_Phase") ~= "Night" then
		return false
	end
	local now = Clock.now()
	if not Cooldown.ready(p.lastFlicker, W.flickerCooldown, now) then
		return false
	end
	local room = roomOf(p)
	if not room or not LightingService.flicker(room, W.flickerSeconds) then
		return false
	end
	p.lastFlicker = now
	Participants.set(p, "FlickerReadyAt", now + W.flickerCooldown)
	return true
end

local function aliveSlicks(p): number
	local n = 0
	for _, s in slicks do
		if s.owner == p.id then
			n += 1
		end
	end
	return n
end

function ChaseService.slick(p): boolean
	if p.state ~= "Wisp" or workspace:GetAttribute("CM_Phase") ~= "Night" then
		return false
	end
	local now = Clock.now()
	if not Cooldown.canSlick(aliveSlicks(p), p.lastSlick, now, W) then
		return false
	end
	local pos = Participants.pos(p)
	if not pos or not roomOf(p) then
		return false
	end
	local fy = floorY(pos)
	local part = Build.part({ name = "OilSlick", parent = effects(), shape = Enum.PartType.Cylinder, size = Vector3.new(0.1, W.slickRadius * 2, W.slickRadius * 2), cf = CFrame.new(pos.X, fy + 0.06, pos.Z) * CFrame.Angles(0, 0, math.rad(90)), color = "Oil", material = Enum.Material.Glass, collide = false, query = false, shadow = false, transparency = 0.15 })
	part.Reflectance = 0.4
	table.insert(slicks, { owner = p.id, x = pos.X, y = pos.Y, z = pos.Z, untilT = now + W.slickLifetime, part = part })
	p.lastSlick = now
	Participants.set(p, "SlickReadyAt", now + W.slickCooldown)
	Participants.set(p, "SlicksAlive", aliveSlicks(p))
	return true
end

function ChaseService.dropGlow(p): boolean
	if p.state ~= "Guest" or p.role ~= "Guest" or workspace:GetAttribute("CM_Phase") ~= "Night" then
		return false
	end
	local mine = 0
	for _, g in glows do
		if g.owner == p.id then
			mine += 1
		end
	end
	if mine >= GS.maxAlive or not Loot.take(p.inv, "GlowStick") then
		return false
	end
	local pos = Participants.pos(p)
	if not pos then
		return false
	end
	local part = Build.part({ name = "GlowStick", parent = effects(), size = Vector3.new(0.3, 0.3, 1.4), cf = CFrame.new(pos.X, floorY(pos) + 0.2, pos.Z) * CFrame.Angles(0, math.random() * 6.28, 0), color = "Glow", material = Enum.Material.Neon, collide = false, query = false, shadow = false })
	Build.light(part, "PointLight", Build.color("Glow"), 2, GS.radius)
	table.insert(glows, { owner = p.id, x = pos.X, y = p.y, z = pos.Z, untilT = Clock.now() + GS.lifetime, part = part })
	Participants.set(p, "GlowStick", p.inv.GlowStick)
	return true
end

-- ---- per tick ----------------------------------------------------------------------------
local function setSpeed(p, speed: number)
	local h = Participants.humanoid(p)
	if h and math.abs(h.WalkSpeed - speed) > 0.05 then
		h.WalkSpeed = speed
	end
end

function ChaseService.step(dt: number)
	local now = Clock.now()
	local night = workspace:GetAttribute("CM_Phase") == "Night"
	-- v1.2: Rising Storm Phantom speed + Last Stand survivor count, read once per tick
	local escSpeed = workspace:GetAttribute("CM_EscSpeed") or 0
	local aliveGuests = workspace:GetAttribute("CM_GuestsAlive") or 99
	local lastStandSpeed = Escalation.lastStandSpeed(EscCfg, aliveGuests)
	local eventSpeed = workspace:GetAttribute("CM_EventSpeed") or 1
	-- expire slicks / glow-sticks
	for i = #slicks, 1, -1 do
		if now >= slicks[i].untilT then
			slicks[i].part:Destroy()
			local owner = Participants.get(slicks[i].owner)
			table.remove(slicks, i)
			if owner then
				Participants.set(owner, "SlicksAlive", aliveSlicks(owner))
			end
		end
	end
	for i = #glows, 1, -1 do
		if now >= glows[i].untilT then
			glows[i].part:Destroy()
			table.remove(glows, i)
		end
	end
	for _, p in Participants.all() do
		local pos = Participants.pos(p)
		if p.state == "Bubble" then
			setSpeed(p, 0)
			if now >= (p.bubbleUntil or 0) then
				becomeWisp(p)
			end
		elseif p.state == "Wisp" then
			setSpeed(p, W.walkSpeed)
		elseif p.role == "Phantom" then
			if night and not p.transformed and now >= (p.transformUntil or 0) then
				p.transformed = true
				Participants.set(p, "Transforming", false)
			end
			if night then
				local revealed = false
				if pos then
					for _, g in glows do
						if math.abs(g.y - pos.Y) < 8 and flatDist(pos, Vector3.new(g.x, pos.Y, g.z)) <= GS.radius then
							revealed = true
						end
					end
				end
				local hl = p.model and p.model:FindFirstChild("PhantomGlow") :: Highlight?
				if p.revealUntil and now < p.revealUntil then
					revealed = true -- exposed at the Evidence Board
				end
				if hl then
					hl.DepthMode = if revealed then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
				end
				Participants.set(p, "Revealed", revealed)
				local beams = LanternService.beamsOn(p.id)
				local recoil = if p.lastTag and now - p.lastTag < P.recoilSeconds then P.recoilFactor else 1
				local held = now < (p.frozenUntil or 0) or now < (p.stunUntil or 0)
				local mul = if hooks.phantomSpeed then hooks.phantomSpeed() else 1
				setSpeed(p, if p.transformed and not held then (P.nightSpeed + escSpeed) * mul * Lantern.speedFactor(beams, Gadgets.Lantern) * recoil else 0)
				-- the projector's light barrier (Night 2) pushes Phantoms out
				local bar = hooks.barrier and hooks.barrier()
				if bar and pos and math.abs(pos.Y - (bar.y + 3)) < 7 then
					local v = Vector3.new(pos.X - bar.x, 0, pos.Z - bar.z)
					if v.Magnitude < bar.radius then
						local away = if v.Magnitude > 0.1 then v.Unit else Vector3.new(1, 0, 0)
						local root = Participants.root(p)
						local to = Vector3.new(bar.x, pos.Y, bar.z) + away * (bar.radius + 0.5)
						if root and ManorLayout.roomAt(Manor, to.X, to.Y, to.Z) then
							p.model:PivotTo(CFrame.new(to) * (root.CFrame - root.CFrame.Position))
						end
					end
				end
			else
				local boost = if now < (p.boostUntil or 0) then Items.Boots.factor else 1
				setSpeed(p, P.daySpeed * boost)
			end
		elseif p.state == "Guest" then
			local slowed = false
			if pos and night then
				for _, s in slicks do
					if math.abs(s.y - pos.Y) < 6 and flatDist(pos, Vector3.new(s.x, pos.Y, s.z)) <= W.slickRadius then
						p.slickUntil = now + W.slickSlowSeconds
					end
				end
				slowed = now < (p.slickUntil or 0)
			end
			Participants.set(p, "Slowed", slowed)
			local boost = if now < (p.boostUntil or 0) then Items.Boots.factor else 1
			local shaken = if now < (p.shakenUntil or 0) then Match.Expose.shakenFactor else 1
			local carry = if hooks.carryFactor then hooks.carryFactor(p) else 1
			setSpeed(p, (Gadgets.Guest.walkSpeed + lastStandSpeed) * eventSpeed * (if slowed then W.slickSlow else 1) * boost * shaken * carry)
		end
	end
end

-- Finale: wake every Electro-Wisp (and bubbled guest) up as a guest where it is. Returns count.
function ChaseService.reviveWisps(): number
	local n = 0
	for _, p in Participants.all() do
		if p.role == "Guest" and (p.state == "Wisp" or p.state == "Bubble") then
			local m = p.model
			if p.bubblePart then
				p.bubblePart:Destroy()
				p.bubblePart = nil
			end
			local root = Participants.root(p)
			if root then
				root.Anchored = false
			end
			if m then
				local o = m:FindFirstChild("WispOrb")
				if o then
					o:Destroy()
				end
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") and d ~= root and d.Name ~= "LanternLamp" then
						d.Transparency = 0
					elseif d:IsA("Decal") then
						d.Transparency = 0
					end
				end
				setGroup(m, GROUP_CHARS)
			end
			setState(p, "Guest")
			p.immuneUntil = Clock.now() + 3
			Participants.set(p, "ImmuneUntil", p.immuneUntil)
			n += 1
		end
	end
	return n
end

-- Dawn between nights: tagged guests wake up as guests, Phantoms put their disguise back on.
function ChaseService.dawn()
	for _, p in Participants.all() do
		local m = p.model
		if p.bubblePart then
			p.bubblePart:Destroy()
			p.bubblePart = nil
		end
		local root = Participants.root(p)
		if root then
			root.Anchored = false
		end
		if p.role == "Guest" and (p.state == "Wisp" or p.state == "Bubble") then
			if m then
				for _, n in { "WispOrb" } do
					local o = m:FindFirstChild(n)
					if o then
						o:Destroy()
					end
				end
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") and d ~= root and d.Name ~= "WispRing" and d.Name ~= "LanternLamp" then
						d.Transparency = 0
					elseif d:IsA("Decal") then
						d.Transparency = 0
					end
				end
				setGroup(m, GROUP_CHARS)
			end
			setState(p, "Guest")
			p.revived = (p.revived or 0) + 1
		elseif p.role == "Phantom" then
			if m then
				for _, n in { "PhantomMask", "PhantomGlow" } do
					local o = m:FindFirstChild(n)
					if o then
						o:Destroy()
					end
				end
				local mq = m:FindFirstChild("MasqueradeMask") :: BasePart?
				if mq then
					mq.Transparency = 0
					for _, d in mq:GetChildren() do
						if d:IsA("BasePart") then
							d.Transparency = 0
						end
					end
				end
			end
			setNameShown(p, true) -- v1.4: disguise back on, name back on
			setState(p, "Guest") -- looks like a guest again by day
			p.state = "Guest"
			Participants.set(p, "PState", "Guest")
			p.transformed = false
			Participants.set(p, "Transforming", nil)
			Participants.set(p, "Revealed", nil)
			Participants.set(p, "Exposed", nil)
		end
		p.frozenUntil, p.stunUntil, p.shakenUntil, p.revealUntil = nil, nil, nil, nil
		Participants.set(p, "FrozenUntil", nil)
		Participants.set(p, "StunUntil", nil)
		Participants.set(p, "ShakenUntil", nil)
	end
	for _, sl in slicks do
		sl.part:Destroy()
	end
	for _, g in glows do
		g.part:Destroy()
	end
	table.clear(slicks)
	table.clear(glows)
	LightingService.stopFlicker()
end

-- A respawned character (fell, reset) gets its round look back.
function ChaseService.reapply(p)
	ChaseService.prepare(p)
	setNameShown(p, not (p.role == "Phantom" and p.state == "Phantom")) -- v1.4
	if p.state == "Wisp" or p.state == "Bubble" then
		becomeWisp(p)
	elseif p.role == "Phantom" and p.state == "Phantom" then
		maskOn(p)
	end
end

function ChaseService.slicks()
	return slicks
end

function ChaseService.reset()
	for _, s in slicks do
		s.part:Destroy()
	end
	for _, g in glows do
		g.part:Destroy()
	end
	table.clear(slicks)
	table.clear(glows)
	for _, p in Participants.all() do
		if p.bubblePart then
			p.bubblePart:Destroy()
			p.bubblePart = nil
		end
		setNameShown(p, true) -- v1.4: never leave a hidden name behind after a match
	end
	LightingService.stopFlicker()
end

return ChaseService
