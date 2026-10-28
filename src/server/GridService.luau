-- Breakers: Phantom tamper by day (4 s stationary channel, max 1 per night), cooperative
-- guest repair at night (stationary; copper wire halves the time and is used up), the reboot
-- meter. A tamper stays hidden until night falls; then the breaker trips (red light, sparks).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Grid = require(Shared.Logic.Grid)
local Channel = require(Shared.Logic.Channel)
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
local hooks = { tampered = nil :: any, repaired = nil :: any }

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
		local showBad = br and br.tampered and isNight
		local color = Build.color(if showBad then "BreakerBad" else "BreakerOk")
		h.status.Color = color
		h.light.Color = color
		h.sparks.Enabled = showBad
		h.label.Text = if showBad
			then string.format("BREAKER %s - TRIPPED %d%%", id, math.floor((br.repair or 0) * 100))
			else "BREAKER " .. id .. " - ONLINE"
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
	return h.x, h.z
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
	local bx, bz = breakerPos(id)
	if Channel.check(Channel.new(p.id, id, pos.X, pos.Z, 0), pos.X, pos.Z, bx, bz, TOLERANCE, night.tamperRange) ~= "running" then
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
	local bx, bz = breakerPos(id)
	if Channel.check(Channel.new(p.id, id, pos.X, pos.Z, 0), pos.X, pos.Z, bx, bz, TOLERANCE, night.repairRange) ~= "running" then
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
				local secs = if (p.inv.CopperWire or 0) > 0 then night.repairSecondsWithWire else night.repairSeconds
				contributors[ch.target] = contributors[ch.target] or {}
				table.insert(contributors[ch.target], p)
				if Grid.addRepair(state, ch.target, dt / secs) then
					for _, q in contributors[ch.target] do
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
		Grid.stepReboot(state, dt, night.rebootFullSeconds)
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
