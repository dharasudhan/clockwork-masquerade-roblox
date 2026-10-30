-- Manor events (server): watches the phase attributes and fires one event per Day and one per
-- Night at a random moment (Config/Events + Logic/Events). Timed modifiers are workspace
-- attributes the per-tick services already read (LanternService: CM_EventDrain; ChaseService:
-- CM_EventSpeed), so the chase itself is untouched - events only turn dials that exist.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EvCfg = require(Shared.Config.Events)
local Events = require(Shared.Logic.Events)
local Items = require(Shared.Config.Items)
local Loot = require(Shared.Logic.Loot)
local Participants = require(script.Parent.Participants)
local GridService = require(script.Parent.GridService)
local ExposeService = require(script.Parent.ExposeService)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local EventService = {}

local rng = Random.new()
local watchedPhase: string? = nil
local fireAt: number? = nil
local pendingId: string? = nil
local drainUntil: number? = nil
local speedUntil: number? = nil

local function clearMods()
	workspace:SetAttribute("CM_EventDrain", nil)
	workspace:SetAttribute("CM_EventSpeed", nil)
	drainUntil, speedUntil = nil, nil
end

local function fire(id: string)
	-- v1.2 fix: Power Surge needs a live grid (nights 1-2). On the finale night there is no
	-- reboot meter, so the night's other event fires instead of a toast that does nothing.
	if id == "PowerSurge" and (workspace:GetAttribute("CM_NightKind") ~= "grid" or GridService.state() == nil) then
		id = "DeepDark"
	end
	local def = EvCfg.Defs[id]
	if not def then
		return
	end
	if def.toast then
		Net.toast("all", "🕰 " .. def.toast, "Amber")
		Net.sfx("all", "NightStart")
	end
	if id == "PowerSurge" then
		GridService.boostReboot(def.amount or 0.08)
	elseif id == "DeepDark" then
		workspace:SetAttribute("CM_EventDrain", def.drainFactor or 1.5)
		drainUntil = Clock.now() + (def.seconds or 25)
	elseif id == "ClockworkRush" then
		workspace:SetAttribute("CM_EventSpeed", def.speedFactor or 1.15)
		speedUntil = Clock.now() + (def.seconds or 20)
	elseif id == "LooseGears" then
		for _, p in Participants.all() do
			if p.role == "Guest" and p.state == "Guest" and p.inv then
				if Loot.add(p.inv, "DryCell", Items.caps()) then
					Participants.set(p, "DryCell", p.inv.DryCell)
				end
			end
		end
	elseif id == "RumorMill" then
		if not ExposeService.revealOne() then
			-- nothing tampered yet today: the rumor is a warning instead of a clue
			Net.toast("all", "Rumor: the servants saw nothing yet... watch the breakers!", "Cream")
		end
	end
	workspace:SetAttribute("CM_Event", id)
	workspace:SetAttribute("CM_EventAt", Clock.now())
end

-- Called every MatchService tick while Day/Night runs. Also clears expired timed modifiers in
-- every phase, so an event never outlives its moment.
function EventService.step(dt: number)
	local now = Clock.now()
	if drainUntil and now >= drainUntil then
		workspace:SetAttribute("CM_EventDrain", nil)
		drainUntil = nil
	end
	if speedUntil and now >= speedUntil then
		workspace:SetAttribute("CM_EventSpeed", nil)
		speedUntil = nil
	end
	local phase = workspace:GetAttribute("CM_Phase")
	if phase ~= "Day" and phase ~= "Night" then
		watchedPhase = nil
		fireAt, pendingId = nil, nil
		clearMods()
		return
	end
	if phase ~= watchedPhase then
		-- new phase instance: schedule one event inside the window
		watchedPhase = phase
		local endsAt = workspace:GetAttribute("CM_PhaseEndsAt") or now
		local length = math.max(5, endsAt - now)
		local id = Events.pick(EvCfg, phase, rng:NextNumber())
		if id then
			pendingId = id
			fireAt = now + Events.scheduleAt(EvCfg, rng:NextNumber()) * length
		else
			fireAt, pendingId = nil, nil
		end
	end
	if pendingId and fireAt and now >= fireAt then
		local id = pendingId
		fireAt, pendingId = nil, nil
		fire(id)
	end
end

function EventService.init()
	clearMods()
end

-- test hooks
EventService._fire = fire
EventService._clearMods = clearMods

return EventService
