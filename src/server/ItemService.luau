-- Carried items (Config/Items, data-driven). One server entry point for players (Action "use")
-- and bots alike: ItemService.use(p, itemId, opts). Validates the id, phase, that the user still
-- LOOKS like a guest (a Phantom may use day items by day so items never reveal its role), the
-- count and a per-item cooldown; then applies the effect:
--   DryCell -> lantern +45 s, GlowStick -> drop, SmokePellet -> blink + smoke + brief tag immunity,
--   PocketWatch -> private status readout, TripwireBell -> a bell that rings for everyone when a
--   Phantom passes at night, SpringBoots -> short speed burst, ClockworkDecoy -> a ticking decoy
--   that takes a Phantom's tag and lures Phantom bots. BrassWrench + CopperWire are passive.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Manor = require(Shared.Config.Manor)
local Grid = require(Shared.Logic.Grid)
local Loot = require(Shared.Logic.Loot)
local ManorLayout = require(Shared.Logic.ManorLayout)
local ItemModels = require(Shared.ItemModels)
local Build = require(script.Parent.Build)
local Participants = require(script.Parent.Participants)
local LanternService = require(script.Parent.LanternService)
local ChaseService = require(script.Parent.ChaseService)
local GridService = require(script.Parent.GridService)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local ItemService = {}

local bells: { any } = {}
local decoys: { any } = {}
local serial = 0
local night: any = nil
local hooks = { used = nil :: any, rang = nil :: any }

function ItemService.onUsed(cb)
	hooks.used = cb
end
function ItemService.onBell(cb)
	hooks.rang = cb
end

local function effects(): Instance
	return workspace:FindFirstChild("Effects") or Build.folder("Effects", workspace)
end

function ItemService.setNight(n)
	night = n
end

local function phase(): string
	return workspace:GetAttribute("CM_Phase") or "Lobby"
end

local function tell(p, text: string, color: string?)
	if p.player then
		Net.toast(p.player, text, color or "TealNeon")
	end
end

-- ---- effects -------------------------------------------------------------------------------
local rayParams: RaycastParams? = nil
local function castFrom(from: Vector3, dir: Vector3, ignore: { Instance }): number?
	if rayParams == nil then
		rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
	end
	local rp = rayParams :: RaycastParams
	rp.FilterDescendantsInstances = ignore
	local ok, hit = pcall(function()
		return workspace:Raycast(from, dir, rp)
	end)
	if ok and hit then
		return (hit.Position - from).Magnitude
	end
	return nil
end

local function ignoreList(): { Instance }
	local out = { effects() }
	for _, q in Participants.all() do
		if q.model then
			table.insert(out, q.model)
		end
	end
	return out
end

local function smoke(p, opts): boolean
	local root = Participants.root(p)
	if not root then
		return false
	end
	local pos = root.CFrame.Position
	local dir = (opts and opts.dir) or root.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(0, 0, -1)
	end
	dir = dir.Unit
	local S = Items.Smoke
	local hit = castFrom(pos, dir * (S.blink + 1.5), ignoreList())
	local dist = if hit then math.max(0, hit - 1.5) else S.blink
	-- smoke cloud where you stood
	local cloud = Build.part({ name = "SmokeCloud", parent = effects(), shape = Enum.PartType.Ball, size = Vector3.new(S.cloudRadius * 2, S.cloudRadius * 1.2, S.cloudRadius * 2), pos = pos, color = "Smoke", material = Enum.Material.SmoothPlastic, collide = false, query = false, shadow = false, transparency = 0.55 })
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Smoke"
	pe.Color = ColorSequence.new(Build.color("Smoke"))
	pe.Rate = 40
	pe.Lifetime = NumberRange.new(1, 2)
	pe.Speed = NumberRange.new(1, 3)
	pe.Size = NumberSequence.new(2, 4)
	pe.Transparency = NumberSequence.new(0.3, 1)
	pe.Parent = cloud
	table.insert(decoys, { kind = "cloud", part = cloud, untilT = Clock.now() + S.cloudSeconds })
	if dist > 0.5 then
		p.model:PivotTo(CFrame.new(pos + dir * dist) * (root.CFrame - root.CFrame.Position))
	end
	p.immuneUntil = Clock.now() + S.immuneSeconds
	Participants.set(p, "ImmuneUntil", p.immuneUntil)
	return true
end

local function watch(p): boolean
	local grid = GridService.state()
	if not grid or not night then
		return false
	end
	local ph = phase()
	local payload = { kind = "watch", phase = ph, seconds = Items.Watch.showSeconds }
	local text
	if ph == "Day" then
		payload.tampered = grid.tampers
		text = string.format("Pocket watch: %d breaker%s tampered so far", grid.tampers, if grid.tampers == 1 then "" else "s")
	else
		local on, total = Grid.online(grid)
		local rate = Grid.rebootRate(on, total, night.rebootFullSeconds)
		local eta = if rate > 0 then (100 - grid.reboot) / rate else math.huge
		local down = {}
		for _, id in grid.order do
			local b = grid.breakers[id]
			if b.tampered then
				table.insert(down, string.format("%s %d%%", id, math.floor(b.repair * 100)))
			end
		end
		payload.eta = if eta == math.huge then -1 else math.floor(eta)
		payload.down = down
		text = if #down == 0
			then string.format("Pocket watch: dawn in %ds - all breakers online", math.floor(eta))
			else string.format("Pocket watch: dawn in %ss - down: %s", if eta == math.huge then "--" else tostring(math.floor(eta)), table.concat(down, ", "))
	end
	if p.player then
		Net.send(p.player, payload)
	end
	tell(p, text, "Cream")
	return true
end

local function placeBell(p): boolean
	local pos = Participants.pos(p)
	if not pos then
		return false
	end
	local mine = 0
	for _, b in bells do
		if b.owner == p.id then
			mine += 1
		end
	end
	if mine >= Items.Bell.maxAlive then
		tell(p, "You already have a bell set", "BreakerBad")
		return false
	end
	local fy = ChaseService.floorY(pos)
	local m = Instance.new("Model")
	m.Name = "TripwireBell"
	local post = Build.part({ name = "BellPost", parent = m, size = Vector3.new(0.3, 2.2, 0.3), pos = Vector3.new(pos.X, fy + 1.1, pos.Z), color = "Iron", material = Enum.Material.Metal, collide = false, query = false })
	local bell = Build.part({ name = "Bell", parent = m, shape = Enum.PartType.Ball, size = Vector3.new(0.9, 0.9, 0.9), pos = Vector3.new(pos.X, fy + 2.5, pos.Z), color = "Bell", material = Enum.Material.Neon, collide = false, query = false })
	Build.light(bell, "PointLight", Build.color("Bell"), 0.8, 8)
	Build.part({ name = "Wire", parent = m, size = Vector3.new(Items.Bell.radius * 2, 0.08, 0.08), pos = Vector3.new(pos.X, fy + 0.4, pos.Z + 0.05), color = "Copper", material = Enum.Material.Metal, collide = false, query = false, shadow = false })
	m.PrimaryPart = post
	m.Parent = effects()
	table.insert(bells, { owner = p.id, x = pos.X, y = pos.Y, z = pos.Z, untilT = Clock.now() + Items.Bell.lifetime, rearmAt = 0, model = m, bell = bell, room = ManorLayout.roomAt(Manor, pos.X, pos.Y, pos.Z) })
	return true
end

local function boots(p): boolean
	p.boostUntil = Clock.now() + Items.Boots.seconds
	Participants.set(p, "BoostUntil", p.boostUntil)
	return true
end

local function decoy(p): boolean
	local root = Participants.root(p)
	if not root then
		return false
	end
	local pos = root.CFrame.Position + root.CFrame.LookVector * 3
	local fy = ChaseService.floorY(root.CFrame.Position)
	serial += 1
	local m = Instance.new("Model")
	m.Name = "ClockworkDecoy"
	local body = Build.part({ name = "DecoyBody", parent = m, shape = Enum.PartType.Cylinder, size = Vector3.new(3.2, 1.6, 1.6), cf = CFrame.new(pos.X, fy + 1.6, pos.Z) * CFrame.Angles(0, 0, math.rad(90)), color = "Copper", material = Enum.Material.Metal, collide = false, query = false })
	Build.part({ name = "DecoyHead", parent = m, shape = Enum.PartType.Ball, size = Vector3.new(1.3, 1.3, 1.3), pos = Vector3.new(pos.X, fy + 3.9, pos.Z), color = "Decoy", material = Enum.Material.Neon, collide = false, query = false })
	Build.part({ name = "WindKey", parent = m, size = Vector3.new(0.2, 1, 1.4), pos = Vector3.new(pos.X + 1, fy + 2.4, pos.Z), color = "Brass", material = Enum.Material.Metal, collide = false, query = false })
	Build.light(body, "PointLight", Build.color("Decoy"), 1.5, 14)
	m.PrimaryPart = body
	m.Parent = effects()
	table.insert(decoys, { kind = "decoy", id = "D" .. serial, owner = p.id, x = pos.X, y = root.CFrame.Position.Y, z = pos.Z, untilT = Clock.now() + Items.Decoy.lifetime, model = m })
	return true
end

local Effects = {
	cell = function(p)
		return LanternService.useCell(p), true -- consumes itself
	end,
	glow = function(p)
		return ChaseService.dropGlow(p), true
	end,
	smoke = smoke,
	watch = watch,
	bell = placeBell,
	boots = boots,
	decoy = decoy,
}

-- Server-validated use. Returns (ok, reason).
function ItemService.use(p, id: any, opts: any?): (boolean, string?)
	if type(id) ~= "string" then
		return false, "bad id"
	end
	local def = Items.Defs[id]
	if not def or not def.use then
		return false, "not usable"
	end
	local ph = phase()
	if not Items.usableIn(id, ph) then
		return false, "wrong phase"
	end
	if p.state ~= "Guest" then
		return false, "only while you look like a guest"
	end
	if (p.inv[id] or 0) <= 0 then
		return false, "none left"
	end
	local now = Clock.now()
	p.itemAt = p.itemAt or {}
	if p.itemAt[id] and now - p.itemAt[id] < (def.cooldown or 0) then
		return false, "cooldown"
	end
	local fn = Effects[def.use]
	local ok, selfConsumed = fn(p, opts)
	if not ok then
		return false, "refused"
	end
	if def.consume and not selfConsumed then
		Loot.take(p.inv, id)
	end
	Participants.set(p, id, p.inv[id])
	p.itemAt[id] = now
	Participants.set(p, "ReadyAt_" .. id, now + (def.cooldown or 0))
	p.stats.items = (p.stats.items or 0) + 1
	ItemService.feedback(p, id)
	if hooks.used then
		hooks.used(p, id)
	end
	return true, nil
end

-- Visible + audible feedback for every use: a short particle burst on the user in the item's
-- colour, the item's use sound for the user, and an "item used" note for the HUD (icon pop).
function ItemService.feedback(p, id: string)
	local def = Items.Defs[id]
	local root = Participants.root(p)
	if root then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "ItemFx"
		pe.Color = ColorSequence.new(Build.color(def.color))
		pe.LightEmission = 0.9
		pe.Rate = 0
		pe.Lifetime = NumberRange.new(0.4, 0.9)
		pe.Speed = NumberRange.new(3, 7)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new(0.4, 0)
		pe.Parent = root
		pcall(function()
			pe:Emit(if id == "SpringBoots" then 40 else 24)
		end)
		task.delay(1.5, function()
			pe:Destroy()
		end)
		if id == "SpringBoots" then
			local sp = Instance.new("Sparkles")
			sp.Name = "BootSparkles"
			sp.SparkleColor = Build.color("Spring")
			sp.Parent = root
			task.delay(Items.Boots.seconds, function()
				sp:Destroy()
			end)
		end
	end
	if p.player then
		Net.send(p.player, { kind = "used", item = id })
		if def.sfx then
			Net.sfx(p.player, def.sfx)
		end
	end
end

-- The selected item is held in the right hand (everyone can see it; any guest-looking player
-- may hold any item, so it never reveals a Phantom). id = nil clears it.
function ItemService.hold(p, id: any): boolean
	local m = p.model
	if not m then
		return false
	end
	local old = m:FindFirstChild("HeldItem")
	if old then
		old:Destroy()
	end
	if type(id) ~= "string" or not Items.Defs[id] or (p.inv[id] or 0) <= 0 or p.state ~= "Guest" then
		p.held = nil
		Participants.set(p, "Held", nil)
		return false
	end
	local hand = (m:FindFirstChild("RightHand") or m:FindFirstChild("Right Arm")) :: BasePart?
	local model = ItemModels.build(Items.Defs[id].model or "cell")
	if not hand or not model then
		return false
	end
	model.Name = "HeldItem"
	local grip = if hand.Name == "RightHand" then CFrame.new(0, -0.35, -0.35) else CFrame.new(0, -1.1, -0.3)
	model:PivotTo(hand.CFrame * grip)
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = model.PrimaryPart
	w.Parent = model.PrimaryPart
	model.Parent = m
	p.held = id
	Participants.set(p, "Held", id)
	return true
end

function ItemService.decoys()
	local out = {}
	for _, d in decoys do
		if d.kind == "decoy" then
			table.insert(out, d)
		end
	end
	return out
end

function ItemService.bells()
	return bells
end

local function popDecoy(d, by)
	for i, e in decoys do
		if e == d then
			table.remove(decoys, i)
			break
		end
	end
	if d.model then
		d.model:Destroy()
	end
	if by and by.player then
		Net.toast(by.player, "Just a clockwork decoy!", "Decoy")
	end
	local owner = Participants.get(d.owner)
	if owner and owner.player then
		Net.toast(owner.player, "Your decoy fooled a Phantom!", "Decoy")
	end
end
ItemService.popDecoy = popDecoy

function ItemService.step(_dt: number)
	local now = Clock.now()
	for i = #decoys, 1, -1 do
		local d = decoys[i]
		if now >= d.untilT then
			table.remove(decoys, i)
			if d.model then
				d.model:Destroy()
			end
			if d.part then
				d.part:Destroy()
			end
		end
	end
	local isNight = phase() == "Night"
	for i = #bells, 1, -1 do
		local b = bells[i]
		if now >= b.untilT then
			b.model:Destroy()
			table.remove(bells, i)
		elseif isNight and now >= b.rearmAt then
			for _, ph in Participants.phantoms() do
				local pp = ph.transformed and Participants.pos(ph)
				if pp and math.abs(pp.Y - b.y) < 6 and (Vector3.new(pp.X - b.x, 0, pp.Z - b.z)).Magnitude <= Items.Bell.radius then
					b.rearmAt = now + Items.Bell.rearmSeconds
					b.rings = (b.rings or 0) + 1
					local room = b.room and ManorLayout.ids(Manor)[b.room]
					Net.toast("all", "A tripwire bell rang in the " .. (if room then room.name else "manor") .. "!", "Bell")
					Net.sfx("all", "Tamper")
					b.bell.Color = Build.color("BreakerBad")
					workspace:SetAttribute("CM_BellAt", string.format("%.1f,%.1f,%.1f", b.x, b.y, b.z))
					workspace:SetAttribute("CM_BellTime", now)
					if hooks.rang then
						hooks.rang(b, ph)
					end
					break
				end
			end
		end
	end
end

function ItemService.reset()
	for _, b in bells do
		b.model:Destroy()
	end
	for _, d in decoys do
		if d.model then
			d.model:Destroy()
		end
		if d.part then
			d.part:Destroy()
		end
	end
	table.clear(bells)
	table.clear(decoys)
	workspace:SetAttribute("CM_BellAt", nil)
end

function ItemService.init()
	ChaseService.setDecoys(ItemService.decoys, popDecoy)
end

return ItemService
