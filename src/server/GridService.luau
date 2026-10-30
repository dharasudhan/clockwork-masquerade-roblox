-- Breakers (5, on all 3 floors): Phantom tamper by day (4 s stationary channel, max 2 per night
-- across all Phantoms), cooperative guest repair at night (stationary; copper wire halves the time
-- and is used up, a brass wrench makes it 40% faster), the reboot meter. A tamper stays hidden
-- until night falls; then the breaker trips (red light, sparks).
-- v1.2 (engagement pass): the reboot rate carries night escalation (CM_RebootBoost) and the
-- Dawn Rush surge past 80% (Logic/Escalation); boostReboot() jumps the meter for events.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Grid = require(Shared.Logic.Grid)
local Channel = require(Shared.Logic.Channel)
local Items = require(Shared.Config.Items)
local Gadgets = require(Shared.Config.Gadgets)
local EscCfg = require(Shared.Config.Escalation)
local Escalation = require(Shared.Logic.Escalation)
local Build = require(script.Parent.Build)
local Participants = require(script.Parent.Participants)
local ManorBuilder = require(script.Parent.ManorBuilder)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local GridService = {}

local TOLERANCE = 2 -- studs a channeller may drift
local state: any = nil
local night: any = nil
local tamperCh: { [string]: any } = {} -- participant id -> channel
local repairCh: { [string]: any } = {}
local hooks = { tampered = nil :: any, repaired = nil :: any, inspect = nil :: any }

function GridService.onInspect(cb)
	hooks.inspect = cb
end

function GridService.onTampered(cb)
	hooks.tampered = cb
end
function GridService.onRepaired(cb)
	hooks.repaired = cb
end

local function phase()
	return workspace:GetAttribute("CM_Phase")
end

local function visuals()
	local b = ManorBuilder.get()
	if not b or not state then
		return
	end
	local isNight = phase() == "Night"
	for id, h in b.breakers do
		local br = state.breakers[id]
		local showBad = br ~= nil and br.tampered == true and isNight
		local color = Build.color(if showBad then "BreakerBad" else "BreakerOk")
		h.status.Color = color
		h.light.Color = color
		h.sparks.Enabled = showBad
		h.label.Text = if showBad
			then string.format("BREAKER %s - TRIPPED %d%%", id, math.floor((br.repair or 0) * 100))
			elseif br then "BREAKER " .. id .. " - ONLINE"
			else "BREAKER " .. id
		h.model:SetAttribute("Tripped", showBad)
		h.model:SetAttribute("RepairProgress", if showBad then br.repair else 0)
	end
end

local function ensurePrompts()
	local b = ManorBuilder.get()
	for id, h in b.breakers do
		if h.prompt:FindFirstChild("Tamper") then
			continue
		end
		local tp = Instance.new("ProximityPrompt")
		tp.Name = "Tamper"
		tp.ActionText = "Tamper (stand still 4 s)"
		tp.ObjectText = "Breaker " .. id
		tp.HoldDuration = 0
		tp.MaxActivationDistance = 7
		tp.RequiresLineOfSight = false
		tp:SetAttribute("ForRole", "Phantom")
		tp:SetAttribute("ForPhase", "Day")
		tp.Parent = h.prompt
		tp.Triggered:Connect(function(player)
			local p = Participants.ofPlayer(player)
			if p then
				GridService.beginTamper(p, id)
			end
		end)
		local rp = Instance.new("ProximityPrompt")
		rp.Name = "Repair"
		rp.ActionText = "Repair (stand still)"
		rp.ObjectText = "Breaker " .. id
		rp.HoldDuration = 0
		rp.MaxActivationDistance = 7
		rp.RequiresLineOfSight = false
		rp:SetAttribute("ForRole", "Guest")
		rp:SetAttribute("ForPhase", "Night")
		rp:SetAttribute("NeedsTripped", true)
		rp.Parent = h.prompt
		local ip = Instance.new("ProximityPrompt")
		ip.Name = "Inspect"
		ip.ActionText = "Look for clues"
		ip.ObjectText = "Breaker " .. id
		ip.HoldDuration = 1
		ip.MaxActivationDistance = 8
		ip.RequiresLineOfSight = false
		ip.UIOffset = Vector2.new(0, 60)
		ip.KeyboardKeyCode = Enum.KeyCode.R
		ip:SetAttribute("ForRole", "Any")
		ip:SetAttribute("ForPhase", "Day")
		ip.Parent = h.prompt
		ip.Triggered:Connect(function(player)
			local p = Participants.ofPlayer(player)
			if p and hooks.inspect then
				hooks.inspect(p, id)
			end
		end)
		rp.Triggered:Connect(function(player)
			local p = Participants.ofPlayer(player)
			if p then
				GridService.beginRepair(p, id)
			end
		end)
	end
end

function GridService.init()
	ensurePrompts()
end

function GridService.reset(nightCfg)
	night = nightCfg
	state = Grid.new(nightCfg.breakers)
	table.clear(tamperCh)
	table.clear(repairCh)
	workspace:SetAttribute("CM_Reboot", 0)
	workspace:SetAttribute("CM_Tripped", "")
	visuals()
end

function GridService.state()
	return state
end

local function breakerPos(id: string)
	local h = ManorBuilder.get().breakers[id]
	return h.x, h.z, h.y
end

-- same floor as the terminal (a breaker one storey up is not "in range")
local function sameFloor(pos: Vector3, by: number): boolean
	return math.abs(pos.Y - by) < 8
end
GridService.sameFloor = sameFloor

-- seconds one guest needs for a full repair with what it carries
function GridService.repairTime(p): number
	local secs = if (p.inv.CopperWire or 0) > 0 then night.repairSecondsWithWire else night.repairSeconds
	if (p.inv.BrassWrench or 0) > 0 then
		secs *= Items.Wrench.repairFactor
	end
	if p.class == "Mechanist" then
		secs *= Gadgets.Classes.Mechanist.repairFactor
	end
	return secs
end

-- A tamper channel must not give a Phantom away: only its owner is told (Notify). Repairs
-- are public (the breaker shows its progress anyway).
local function setChannel(p, kind: string?, id: string?)
	if p.player then
		Net.send(p.player, {
			kind = "channel",
			channel = kind,
			target = id,
			seconds = if kind == "Tamper" then night.tamperSeconds else nil,
			startedAt = Clock.now(),
		})
	end
	Participants.set(p, "Repairing", if kind == "Repair" then id else nil)
end

function GridService.beginTamper(p, id: string): boolean
	if phase() ~= "Day" or p.role ~= "Phantom" or state == nil then
		return false
	end
	if not Grid.canTamper(state, id, night.maxTampers) then
		if p.player then
			Net.toast(p.player, "That breaker can't be tampered with now", "BreakerBad")
		end
		return false
	end
	local pos = Participants.pos(p)
	if not pos then
		return false
	end
	local bx, bz, by = breakerPos(id)
	if not sameFloor(pos, by) or Channel.check(Channel.new(p.id, id, pos.X, pos.Z, 0), pos.X, pos.Z, bx, bz, TOLERANCE, night.tamperRange) ~= "running" then
		return false
	end
	tamperCh[p.id] = Channel.new(p.id, id, pos.X, pos.Z, Clock.now())
	setChannel(p, "Tamper", id)
	return true
end

function GridService.beginRepair(p, id: string): boolean
	if phase() ~= "Night" or p.role ~= "Guest" or p.state ~= "Guest" or state == nil then
		return false
	end
	local br = state.breakers[id]
	if not br or not br.tampered then
		return false
	end
	local pos = Participants.pos(p)
	if not pos then
		return false
	end
	local bx, bz, by = breakerPos(id)
	if not sameFloor(pos, by) or Channel.check(Channel.new(p.id, id, pos.X, pos.Z, 0), pos.X, pos.Z, bx, bz, TOLERANCE, night.repairRange) ~= "running" then
		return false
	end
	repairCh[p.id] = Channel.new(p.id, id, pos.X, pos.Z, Clock.now())
	setChannel(p, "Repair", id)
	return true
end

function GridService.cancel(p)
	if tamperCh[p.id] or repairCh[p.id] then
		tamperCh[p.id] = nil
		repairCh[p.id] = nil
		setChannel(p, nil, nil)
	end
end

function GridService.channelling(p): string?
	return if tamperCh[p.id] then "Tamper" elseif repairCh[p.id] then "Repair" else nil
end

-- Night falls: tampered breakers trip.
function GridService.nightFalls()
	for pid in tamperCh do
		local p = Participants.get(pid)
		if p then
			setChannel(p, nil, nil)
		end
	end
	table.clear(tamperCh)
	local tripped = {}
	for _, id in state.order do
		if state.breakers[id].tampered then
			table.insert(tripped, id)
		end
	end
	workspace:SetAttribute("CM_Tripped", table.concat(tripped, ","))
	visuals()
	return tripped
end

-- v1.2: jump the reboot meter (manor events). Server-authoritative, clamped to 100%.
function GridService.boostReboot(fraction: number)
	if state == nil then
		return
	end
	state.reboot = math.min(1, (state.reboot or 0) + math.max(0, fraction))
	workspace:SetAttribute("CM_Reboot", state.reboot)
	visuals()
end

function GridService.step(dt: number)
	if state == nil then
		return
	end
	local ph = phase()
	-- tamper channels (day)
	for pid, ch in tamperCh do
		local p = Participants.get(pid)
		local pos = p and Participants.pos(p)
		local bx, bz = breakerPos(ch.target)
		if ph ~= "Day" or not pos or Channel.check(ch, pos.X, pos.Z, bx, bz, TOLERANCE, night.tamperRange) ~= "running" then
			tamperCh[pid] = nil
			if p then
				setChannel(p, nil, nil)
			end
		elseif Channel.advance(ch, dt, night.tamperSeconds) then
			tamperCh[pid] = nil
			setChannel(p, nil, nil)
			if Grid.tamper(state, ch.target, night.maxTampers) then
				if p.player then
					Net.toast(p.player, "Breaker " .. ch.target .. " tampered - it trips at nightfall", "MaskNeon")
					Net.sfx(p.player, "Tamper")
				end
				if hooks.tampered then
					hooks.tampered(p, ch.target)
				end
			end
		end
	end
	-- repair channels (night): every repairer adds dt / repairTime to that breaker
	if ph == "Night" then
		local contributors: { [string]: { any } } = {}
		for pid, ch in repairCh do
			local p = Participants.get(pid)
			local pos = p and Participants.pos(p)
			local bx, bz = breakerPos(ch.target)
			local br = state.breakers[ch.target]
			if not p or p.state ~= "Guest" or not pos or not br.tampered or Channel.check(ch, pos.X, pos.Z, bx, bz, TOLERANCE, night.repairRange) ~= "running" then
				repairCh[pid] = nil
				if p then
					setChannel(p, nil, nil)
				end
			else
				local secs = GridService.repairTime(p)
				contributors[ch.target] = contributors[ch.target] or {}
				table.insert(contributors[ch.target], p)
				if Grid.addRepair(state, ch.target, dt / secs) then
					-- credit everyone channelling on this breaker (not just those iterated so far)
					local crew = {}
					for qid, qch in repairCh do
						local q = Participants.get(qid)
						if q and qch.target == ch.target then
							table.insert(crew, q)
						end
					end
					contributors[ch.target] = crew
					for _, q in crew do
						q.stats.repairs += 1
						if (q.inv.CopperWire or 0) > 0 then
							q.inv.CopperWire -= 1
							Participants.set(q, "CopperWire", q.inv.CopperWire)
						end
					end
					for qid, qch in repairCh do
						if qch.target == ch.target then
							repairCh[qid] = nil
							local q = Participants.get(qid)
							if q then
								setChannel(q, nil, nil)
							end
						end
					end
					Net.toast("all", "Breaker " .. ch.target .. " repaired!", "BreakerOk")
					Net.sfx("all", "Repair")
					if hooks.repaired then
						hooks.repaired(ch.target, contributors[ch.target])
					end
				end
			end
		end
		-- v1.2: reboot rate = base rate x night escalation x Dawn Rush (past Rush.rebootAt)
		local rateBoost = (workspace:GetAttribute("CM_RebootBoost") or 1) * Escalation.rushBoost(EscCfg, state.reboot)
		Grid.stepReboot(state, dt, night.rebootFullSeconds / rateBoost)
		workspace:SetAttribute("CM_Reboot", state.reboot)
		local still = {}
		for _, id in state.order do
			if state.breakers[id].tampered then
				table.insert(still, id)
			end
		end
		workspace:SetAttribute("CM_Tripped", table.concat(still, ","))
	end
	visuals()
end

return GridService
