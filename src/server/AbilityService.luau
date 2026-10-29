-- Role abilities on the GADGET button (one server entry point, Action "gadget"; bots call it too):
--   Guests (night, by class): Mechanist -> Spring Barricade (a brass spring gate; the first
--     Phantom that touches it is knocked back and frozen 1.2 s), Illuminator -> Strobe Flash
--     (Phantoms in a 40-degree cone within 16 studs freeze 2 s).
--   Phantoms: Night 2 -> Phase Glide (blink 10 studs through a wall or door, landing inside a
--     room on the same floor), Night 3 Overdrive -> Shockwave Dash (0.8 s telegraphed windup,
--     then a 14-stud dash that knocks guests near the end point 10 studs back).
-- Every use is validated: phase, role/state, class, cooldown, and a landing spot.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Gadgets = require(Shared.Config.Gadgets)
local Manor = require(Shared.Config.Manor)
local ManorLayout = require(Shared.Logic.ManorLayout)
local Lantern = require(Shared.Logic.Lantern)
local Build = require(script.Parent.Build)
local Participants = require(script.Parent.Participants)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local AbilityService = {}

local barricades: { any } = {}
local dashes: { any } = {}
local night: any = nil
local stage: string? = nil

function AbilityService.setNight(n)
	night = n
end

function AbilityService.setStage(s: string?)
	stage = s
end

local function effects(): Instance
	return workspace:FindFirstChild("Effects") or Build.folder("Effects", workspace)
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

-- what the GADGET button does for p right now (nil = nothing); used by the HUD + bots too
function AbilityService.kind(p): string?
	local ph = workspace:GetAttribute("CM_Phase")
	if ph ~= "Night" or not night then
		return nil
	end
	if p.role == "Guest" and p.state == "Guest" then
		local c = Gadgets.Classes[p.class or "Mechanist"]
		return c and c.gadget
	elseif p.role == "Phantom" and p.state == "Phantom" then
		if night.phaseGlide then
			return "glide"
		elseif night.finale and stage == "Overdrive" then
			return "dash"
		end
	end
	return nil
end

function AbilityService.cooldownOf(kind: string): number
	if kind == "barricade" then
		return Gadgets.Classes.Mechanist.cooldown
	elseif kind == "strobe" then
		return Gadgets.Classes.Illuminator.cooldown
	elseif kind == "glide" then
		return night and night.phaseGlide and night.phaseGlide.cooldown or 25
	elseif kind == "dash" then
		return night and night.finale and night.finale.dash.cooldown or 12
	end
	return 10
end

local function inRoomOnLevel(pos: Vector3): boolean
	local room = ManorLayout.roomAt(Manor, pos.X, pos.Y, pos.Z)
	if not room then
		return false
	end
	local r = ManorLayout.ids(Manor)[room]
	return not r.stair or true
end

local function barricade(p, root: BasePart): boolean
	local B = Gadgets.Barricade
	local pos = root.CFrame.Position
	local dir = flat(root.CFrame.LookVector)
	-- the gate drops 2.5 studs BEHIND you (you are running away)
	local at = pos - dir * 2.5
	local fy = ManorLayout.levelAt(Manor, pos.Y) * Manor.LevelHeight
	local cf = CFrame.lookAt(Vector3.new(at.X, fy + 2.2, at.Z), Vector3.new(at.X, fy + 2.2, at.Z) + dir)
	local model = Instance.new("Model")
	model.Name = "SpringBarricade"
	local bar = Build.part({ name = "Gate", parent = model, size = Vector3.new(B.width, 0.4, 0.4), cf = cf * CFrame.new(0, 1.6, 0), color = "Brass", material = Enum.Material.Metal, collide = false, query = false })
	for _, x in { -B.width / 2 + 0.3, 0, B.width / 2 - 0.3 } do
		Build.part({ name = "Spring", parent = model, shape = Enum.PartType.Cylinder, size = Vector3.new(3.6, 0.5, 0.5), cf = cf * CFrame.new(x, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), color = "Copper", material = Enum.Material.Metal, collide = false, query = false })
	end
	Build.light(bar, "PointLight", Build.color("Amber"), 1, 10)
	model.Parent = effects()
	table.insert(barricades, { model = model, x = at.X, y = pos.Y, z = at.Z, untilT = Clock.now() + B.lifetime, owner = p.id })
	return true
end

local function strobe(p, root: BasePart): boolean
	local S = Gadgets.Strobe
	local pos = root.CFrame.Position
	local dir = if p.aim and p.aimAt and Clock.now() - p.aimAt < 1.5 then p.aim else root.CFrame.LookVector
	local hit = 0
	for _, q in Participants.phantoms() do
		local qp = Participants.pos(q)
		if qp and q.state == "Phantom" and math.abs(qp.Y - pos.Y) < 8 and Lantern.inCone(pos, dir, qp, S.range, S.halfAngle) then
			q.frozenUntil = Clock.now() + S.freezeSeconds
			Participants.set(q, "FrozenUntil", q.frozenUntil)
			hit += 1
		end
	end
	local flash = Build.part({ name = "StrobeFlash", parent = effects(), shape = Enum.PartType.Ball, size = Vector3.new(6, 6, 6), pos = pos + dir * 3, color = "Cream2", material = Enum.Material.Neon, collide = false, query = false, shadow = false, transparency = 0.3 })
	Build.light(flash, "PointLight", Build.color("Cream2"), 6, 24)
	table.insert(dashes, { kind = "fx", part = flash, untilT = Clock.now() + 0.4 })
	if p.player then
		Net.toast(p.player, if hit > 0 then "Flash! " .. hit .. " Phantom" .. (if hit > 1 then "s" else "") .. " frozen!" else "Flash! (no Phantom in front)", "Amber")
	end
	return true
end

local function glide(p, root: BasePart): boolean
	local dist = night.phaseGlide.distance
	local pos = root.CFrame.Position
	local dir = flat(root.CFrame.LookVector)
	for _, d in { dist, dist * 0.8, dist * 0.6 } do
		local to = pos + dir * d
		if inRoomOnLevel(to) and math.abs(ManorLayout.levelAt(Manor, to.Y) - ManorLayout.levelAt(Manor, pos.Y)) == 0 then
			local mark = Build.part({ name = "GlideTrail", parent = effects(), shape = Enum.PartType.Ball, size = Vector3.new(3, 3, 3), pos = pos, color = "VioletNeon", material = Enum.Material.Neon, collide = false, query = false, shadow = false, transparency = 0.4 })
			table.insert(dashes, { kind = "fx", part = mark, untilT = Clock.now() + 0.6 })
			p.model:PivotTo(CFrame.new(to) * (root.CFrame - root.CFrame.Position))
			return true
		end
	end
	return false
end

local function dash(p, root: BasePart): boolean
	local D = night.finale.dash
	local pos = root.CFrame.Position
	local dir = flat(root.CFrame.LookVector)
	local ring = Build.part({ name = "DashWarning", parent = effects(), shape = Enum.PartType.Cylinder, size = Vector3.new(0.1, D.hitRadius * 2, D.hitRadius * 2), cf = CFrame.new(pos + dir * D.distance - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = "BreakerBad", material = Enum.Material.Neon, collide = false, query = false, shadow = false, transparency = 0.35 })
	table.insert(dashes, { kind = "dash", p = p, dir = dir, from = pos, at = Clock.now() + D.windup, part = ring })
	p.frozenUntil = Clock.now() + D.windup -- planted while it winds up (telegraph)
	Participants.set(p, "FrozenUntil", p.frozenUntil)
	return true
end

-- Use p's ability. Returns ok, why.
function AbilityService.use(p): (boolean, string?)
	local kind = AbilityService.kind(p)
	if not kind then
		return false, "no ability"
	end
	local now = Clock.now()
	p.abilityAt = p.abilityAt or {}
	if p.abilityAt[kind] and now - p.abilityAt[kind] < AbilityService.cooldownOf(kind) then
		return false, "cooldown"
	end
	if now < (p.frozenUntil or 0) or now < (p.stunUntil or 0) then
		return false, "frozen"
	end
	local root = Participants.root(p)
	if not root then
		return false, "no body"
	end
	local ok = false
	if kind == "barricade" then
		ok = barricade(p, root)
	elseif kind == "strobe" then
		ok = strobe(p, root)
	elseif kind == "glide" then
		ok = glide(p, root)
	elseif kind == "dash" then
		ok = dash(p, root)
	end
	if ok then
		p.abilityAt[kind] = now
		Participants.set(p, "GadgetReadyAt", now + AbilityService.cooldownOf(kind))
		Net.sfx("all", if kind == "strobe" then "Glow" elseif kind == "barricade" then "Boing" else "Smoke")
		p.stats.gadgets = (p.stats.gadgets or 0) + 1
	end
	return ok, if ok then nil else "blocked"
end

function AbilityService.step(_dt: number)
	local now = Clock.now()
	local B = Gadgets.Barricade
	for i = #barricades, 1, -1 do
		local b = barricades[i]
		local hitOne = false
		for _, q in Participants.phantoms() do
			local qp = Participants.pos(q)
			if qp and q.state == "Phantom" and math.abs(qp.Y - b.y) < 6 then
				local d = Vector3.new(qp.X - b.x, 0, qp.Z - b.z)
				if d.Magnitude <= B.radius then
					local away = if d.Magnitude > 0.1 then d.Unit else Vector3.new(1, 0, 0)
					local root = Participants.root(q)
					if root then
						local to = qp + away * B.knockback
						if ManorLayout.roomAt(Manor, to.X, to.Y, to.Z) then
							q.model:PivotTo(CFrame.new(to) * (root.CFrame - root.CFrame.Position))
						end
					end
					q.frozenUntil = now + B.freezeSeconds
					Participants.set(q, "FrozenUntil", q.frozenUntil)
					hitOne = true
				end
			end
		end
		if hitOne or now >= b.untilT then
			if hitOne then
				Net.sfx("all", "Boing")
			end
			b.model:Destroy()
			table.remove(barricades, i)
		end
	end
	for i = #dashes, 1, -1 do
		local d = dashes[i]
		if d.kind == "fx" then
			if now >= d.untilT then
				d.part:Destroy()
				table.remove(dashes, i)
			end
		elseif now >= d.at then
			local D = night and night.finale and night.finale.dash
			local p = d.p
			local root = Participants.root(p)
			if D and root and p.state == "Phantom" then
				local pos = root.CFrame.Position
				local to = pos + d.dir * D.distance
				for _, f in { 1, 0.75, 0.5 } do
					local t = pos + d.dir * D.distance * f
					if ManorLayout.roomAt(Manor, t.X, t.Y, t.Z) then
						to = t
						break
					end
				end
				p.model:PivotTo(CFrame.new(to) * (root.CFrame - root.CFrame.Position))
				for _, g in Participants.guests(true) do
					local gp = Participants.pos(g)
					local gr = Participants.root(g)
					if gp and gr and math.abs(gp.Y - to.Y) < 6 then
						local v = Vector3.new(gp.X - to.X, 0, gp.Z - to.Z)
						if v.Magnitude <= D.hitRadius then
							local away = if v.Magnitude > 0.1 then v.Unit else d.dir
							local dest = gp + away * D.knockback
							if ManorLayout.roomAt(Manor, dest.X, dest.Y, dest.Z) then
								g.model:PivotTo(CFrame.new(dest) * (gr.CFrame - gr.CFrame.Position))
							end
							if g.player then
								Net.toast(g.player, "Shockwave! You were knocked back", "BreakerBad")
							end
						end
					end
				end
			end
			d.part:Destroy()
			table.remove(dashes, i)
		end
	end
end

function AbilityService.barricades()
	return barricades
end

function AbilityService.reset()
	for _, b in barricades do
		b.model:Destroy()
	end
	for _, d in dashes do
		d.part:Destroy()
	end
	table.clear(barricades)
	table.clear(dashes)
end

return AbilityService
