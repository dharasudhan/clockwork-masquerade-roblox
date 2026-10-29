-- Night 3 "Dawn Reboot" finale (GDD). No more disguise at night:
--   Showdown: the 3 Master Override Keys glow on their pedestals (Generator Vault on B1, Attic
--     Storeroom on the 2nd floor, Greenhouse on the ground floor). A guest holds 2 s to lift one
--     (carriers walk x0.9 and glow), then holds 1 s at the Exit Console in the ballroom to insert
--     it. A tagged carrier's key flies back to its pedestal.
--   Overdrive (all 3 keys in): the Console Activation Ring lights up. Guests inside fill the
--     dawn meter (1 s/s, +0.25 per extra guest, max 1.75; halved while a Phantom stands in it)
--     until it reaches the target (40 s minus 8 per night the guests won). Phantoms run faster
--     (+15%, +5% per night the guests lost) and get the Shockwave Dash; the central dynamo pulses
--     every 15 s, pushing anyone off the dais.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Manor = require(Shared.Config.Manor)
local Progression = require(Shared.Logic.Progression)
local Participants = require(script.Parent.Participants)
local ManorBuilder = require(script.Parent.ManorBuilder)
local Build = require(script.Parent.Build)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local FinaleService = {}

local cfg: any = nil
local stage: string? = nil -- nil | "Showdown" | "Overdrive"
local keys: { [string]: any } = {} -- id -> { state = "pedestal" | "carried" | "inserted", by }
local ring, ringNeed = 0, 40
local nightsWon, nightsLost = 0, 0
local lastPulse = 0
local promptsReady = false
local hooks = { inserted = nil :: any, overdrive = nil :: any, revive = nil :: any }

function FinaleService.onRevive(cb)
	hooks.revive = cb
end

function FinaleService.onInserted(cb)
	hooks.inserted = cb
end
function FinaleService.onOverdrive(cb)
	hooks.overdrive = cb
end

function FinaleService.active(): boolean
	return cfg ~= nil
end

function FinaleService.stage(): string?
	return stage
end

local function keyOrder()
	local out = {}
	for _, k in Manor.Keys do
		table.insert(out, k.id)
	end
	return out
end

local function insertedCount(): number
	local n = 0
	for _, k in keys do
		if k.state == "inserted" then
			n += 1
		end
	end
	return n
end
FinaleService.insertedCount = insertedCount

local function visuals()
	local built = ManorBuilder.get()
	if not built then
		return
	end
	local props = built.props
	for i, id in keyOrder() do
		local k = keys[id]
		local h = props.keys[id]
		local glow = h.pedestal:FindFirstChild("KeyGlow") :: BasePart?
		local onPedestal = cfg ~= nil and stage ~= nil and k ~= nil and k.state == "pedestal"
		if onPedestal and not glow then
			local g = Build.part({ name = "KeyGlow", parent = h.pedestal, size = Vector3.new(0.5, 2.2, 1.2), pos = Vector3.new(h.x, h.y + 4.4, h.z), color = "Gold", material = Enum.Material.Neon, collide = false, query = false, shadow = false })
			Build.light(g, "PointLight", Build.color("Gold"), 2, 16)
		elseif not onPedestal and glow then
			glow:Destroy()
		end
		local s = props.console.sockets[i]
		s.Color = Build.color(if k and k.state == "inserted" then "Gold" else "Iron")
		s.Material = if k and k.state == "inserted" then Enum.Material.Neon else Enum.Material.Metal
	end
	local over = stage == "Overdrive"
	props.console.ring.Transparency = if over then 0.35 else 0.85
	props.console.ring.Color = Build.color(if over then "Amber" else "TealNeon")
	local carried, ins = {}, {}
	for id, k in keys do
		if k.state == "carried" then
			table.insert(carried, id)
		elseif k.state == "inserted" then
			table.insert(ins, id)
		end
	end
	table.sort(carried)
	table.sort(ins)
	workspace:SetAttribute("CM_Stage", stage)
	workspace:SetAttribute("CM_Keys", table.concat(ins, ","))
	workspace:SetAttribute("CM_KeysCarried", table.concat(carried, ","))
	workspace:SetAttribute("CM_Ring", math.floor(ring * 10) / 10)
	workspace:SetAttribute("CM_RingNeed", ringNeed)
end

local function setPromptState()
	local built = ManorBuilder.get()
	if not built then
		return
	end
	for id, h in built.props.keys do
		local pr = h.prompt:FindFirstChild("TakeKey")
		local k = keys[id]
		if pr then
			pr:SetAttribute("Done", not (cfg and stage == "Showdown" and k and k.state == "pedestal"))
		end
	end
	local ins = built.props.console.prompt:FindFirstChild("InsertKey")
	if ins then
		ins:SetAttribute("Done", not (cfg and stage == "Showdown"))
		ins:SetAttribute("NeedsAttr", "CarryKey")
	end
end

local function ensurePrompts()
	if promptsReady then
		return
	end
	local built = ManorBuilder.get()
	if not built then
		return
	end
	promptsReady = true
	for id, h in built.props.keys do
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "TakeKey"
		pr.ActionText = "Take the key"
		pr.ObjectText = h.name
		pr.HoldDuration = 2
		pr.MaxActivationDistance = 8
		pr.RequiresLineOfSight = false
		pr:SetAttribute("ForRole", "Guest")
		pr:SetAttribute("ForPhase", "Night")
		pr:SetAttribute("ForNight", 3)
		pr.Parent = h.prompt
		pr.Triggered:Connect(function(player)
			local p = Participants.ofPlayer(player)
			if p then
				FinaleService.take(p, id)
			end
		end)
	end
	local ins = Instance.new("ProximityPrompt")
	ins.Name = "InsertKey"
	ins.ActionText = "Insert the key"
	ins.ObjectText = "Exit Console"
	ins.HoldDuration = 1
	ins.MaxActivationDistance = 9
	ins.RequiresLineOfSight = false
	ins:SetAttribute("ForRole", "Guest")
	ins:SetAttribute("ForPhase", "Night")
	ins:SetAttribute("ForNight", 3)
	ins.Parent = built.props.console.prompt
	ins.Triggered:Connect(function(player)
		local p = Participants.ofPlayer(player)
		if p then
			FinaleService.insert(p)
		end
	end)
end

function FinaleService.reset(night, won: number, lost: number)
	ensurePrompts()
	cfg = night.finale
	nightsWon, nightsLost = won or 0, lost or 0
	stage = nil
	ring = 0
	table.clear(keys)
	if cfg then
		for _, id in keyOrder() do
			keys[id] = { state = "pedestal" }
		end
		ringNeed = Progression.ringNeed(cfg, nightsWon)
	end
	for _, p in Participants.all() do
		p.carryKey = nil
		Participants.set(p, "CarryKey", nil)
	end
	setPromptState()
	visuals()
end

function FinaleService.showdown()
	if not cfg then
		return
	end
	stage = "Showdown"
	Net.toast("all", "SHOWDOWN! Find the 3 golden keys: B1 Generator Vault, Attic Storeroom, Greenhouse!", "Gold")
	setPromptState()
	visuals()
end

-- Phantom speed multiplier in the finale (Overdrive only)
function FinaleService.phantomSpeed(): number
	if cfg and stage == "Overdrive" then
		return cfg.phantomSpeed + cfg.phantomSpeedPerNightLost * nightsLost
	end
	return 1
end

local function near(p, x: number, y: number, z: number, range: number): boolean
	local pos = Participants.pos(p)
	return pos ~= nil and math.abs(pos.Y - (y + 3)) < 7 and Vector3.new(pos.X - x, 0, pos.Z - z).Magnitude <= range
end

local function carrierGlow(p, on: boolean)
	local m = p.model
	if not m then
		return
	end
	local hl = m:FindFirstChild("KeyCarrier")
	if on and not hl then
		local h = Instance.new("Highlight")
		h.Name = "KeyCarrier"
		h.FillColor = Build.color("Gold")
		h.FillTransparency = 0.6
		h.OutlineColor = Build.color("Gold")
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = m
	elseif not on and hl then
		hl:Destroy()
	end
end

function FinaleService.take(p, id: string): boolean
	if not cfg or stage ~= "Showdown" or p.role ~= "Guest" or p.state ~= "Guest" or p.carryKey then
		return false
	end
	local k = keys[id]
	local h = ManorBuilder.get().props.keys[id]
	if not k or k.state ~= "pedestal" or not near(p, h.x, h.y, h.z, 9) then
		return false
	end
	k.state, k.by = "carried", p.id
	p.carryKey = id
	Participants.set(p, "CarryKey", id)
	carrierGlow(p, true)
	Net.toast("all", p.name .. " has the " .. h.name .. "! Bring it to the Exit Console!", "Gold")
	if p.player then
		Net.send(p.player, { kind = "item", item = "Key", icon = "🗝️", name = h.name, kid = "Run to the Exit Console in the Ballroom!" })
		Net.sfx(p.player, "Key")
	end
	setPromptState()
	visuals()
	return true
end

local function goOverdrive()
	stage = "Overdrive"
	ring = 0
	Net.toast("all", "OVERDRIVE! Stand in the glowing ring by the console!", "Amber")
	Net.sfx("all", "Overdrive")
	if hooks.overdrive then
		hooks.overdrive()
	end
	setPromptState()
	visuals()
end

function FinaleService.insert(p): boolean
	if not cfg or stage ~= "Showdown" or not p.carryKey then
		return false
	end
	local c = ManorBuilder.get().props.console
	if not near(p, c.x, c.y, c.z, 10) then
		return false
	end
	local id = p.carryKey
	keys[id].state, keys[id].by = "inserted", nil
	p.carryKey = nil
	Participants.set(p, "CarryKey", nil)
	carrierGlow(p, false)
	p.stats.keys = (p.stats.keys or 0) + 1
	local n = insertedCount()
	Net.toast("all", string.format("Key %d/3 inserted!", n), "Gold")
	Net.sfx("all", "Key")
	if hooks.inserted then
		hooks.inserted(p, id)
	end
	if cfg.reviveOnKey and hooks.revive then
		local n = hooks.revive()
		if n > 0 then
			Net.toast("all", string.format("The console hums... %d Wisp%s woke up!", n, if n > 1 then "s" else ""), "TealNeon")
		end
	end
	if n >= 3 then
		goOverdrive()
	end
	setPromptState()
	visuals()
	return true
end

-- per tick (Night). Returns true when the stage switched to Overdrive this tick.
function FinaleService.step(dt: number): boolean
	if not cfg or not stage then
		return false
	end
	-- carriers that got tagged drop their key back on its pedestal
	for id, k in keys do
		if k.state == "carried" then
			local p = Participants.get(k.by or "")
			if not p or p.state ~= "Guest" then
				k.state, k.by = "pedestal", nil
				if p then
					p.carryKey = nil
					Participants.set(p, "CarryKey", nil)
					carrierGlow(p, false)
				end
				Net.toast("all", "A key flew back to its pedestal!", "BreakerBad")
				setPromptState()
			end
		end
	end
	if stage == "Overdrive" then
		local c = ManorBuilder.get().props.console
		local gIn, pIn = 0, 0
		local inRing = {}
		for _, p in Participants.all() do
			local pos = Participants.pos(p)
			if pos and math.abs(pos.Y - (c.y + 3)) < 6 and Vector3.new(pos.X - c.x, 0, pos.Z - c.z).Magnitude <= c.radius then
				if p.role == "Guest" and p.state == "Guest" then
					gIn += 1
					table.insert(inRing, p)
				elseif p.role == "Phantom" and p.state == "Phantom" then
					pIn += 1
				end
			end
		end
		ring = math.min(ringNeed, ring + dt * Progression.ringRate(gIn, pIn, cfg))
		for _, p in inRing do
			p.inRingAt = Clock.now()
		end
		-- dynamo pulse: push everyone off the dais
		local now = Clock.now()
		if now - lastPulse >= cfg.dynamo.every then
			lastPulse = now
			for _, p in Participants.all() do
				local pos = Participants.pos(p)
				local root = Participants.root(p)
				if pos and root and math.abs(pos.Y - (c.y + 3)) < 6 then
					local v = Vector3.new(pos.X - c.x, 0, pos.Z - c.z)
					if v.Magnitude <= cfg.dynamo.radius then
						local away = if v.Magnitude > 0.1 then v.Unit else Vector3.new(0, 0, 1)
						p.model:PivotTo(CFrame.new(pos + away * cfg.dynamo.push) * (root.CFrame - root.CFrame.Position))
					end
				end
			end
			workspace:SetAttribute("CM_Pulse", now)
		end
		workspace:SetAttribute("CM_RingGuests", gIn)
	end
	visuals()
	return false
end

-- carry slowdown for p (1 when not carrying)
function FinaleService.carryFactor(p): number
	if cfg and p.carryKey then
		return cfg.carrySlow
	end
	return 1
end

function FinaleService.ring(): (number, number)
	return ring, ringNeed
end

function FinaleService.state()
	return { stage = stage, keys = keys, ring = ring, ringNeed = ringNeed, cfg = cfg }
end

-- bot/compass targets: keys on pedestals
function FinaleService.freeKeys()
	local out = {}
	local built = ManorBuilder.get()
	if not cfg or stage ~= "Showdown" or not built then
		return out
	end
	for _, id in keyOrder() do
		if keys[id].state == "pedestal" then
			local h = built.props.keys[id]
			table.insert(out, { id = id, x = h.x, y = h.y, z = h.z })
		end
	end
	return out
end

function FinaleService.clear()
	for _, p in Participants.all() do
		if p.carryKey then
			carrierGlow(p, false)
		end
	end
	cfg = nil
	stage = nil
	ring = 0
	table.clear(keys)
	setPromptState()
	visuals()
	workspace:SetAttribute("CM_Stage", nil)
end

return FinaleService
