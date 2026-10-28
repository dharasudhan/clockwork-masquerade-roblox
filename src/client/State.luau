-- Client-side view of the match: global attributes + what the server told only us (our
-- secret role, tamper channel, last results).
local Players = game:GetService("Players")

local State = {
	role = nil :: string?, -- "Guest" | "Phantom" (private, from Notify "role")
	mates = {} :: { string },
	channel = nil :: any, -- { channel, target, seconds, startedAt }
	results = nil :: any,
	toast = nil :: any, -- { text, color, at }
	roleShownAt = nil :: number?,
}

function State.me(): Player
	return Players.LocalPlayer
end

function State.attr(key: string): any
	local p = Players.LocalPlayer
	return p and p:GetAttribute(key)
end

function State.phase(): string
	return workspace:GetAttribute("CM_Phase") or "Lobby"
end

function State.timeLeft(): number
	local ends = workspace:GetAttribute("CM_PhaseEndsAt") or 0
	return math.max(0, ends - workspace:GetServerTimeNow())
end

function State.inMatch(): boolean
	return State.attr("InMatch") == true
end

function State.pstate(): string?
	return State.attr("PState")
end

-- "Guest" | "Phantom" | "Wisp" | "Bubble" | nil (lobby / spectating)
function State.who(): string?
	if not State.inMatch() then
		return nil
	end
	local ps = State.pstate()
	if ps == "Wisp" or ps == "Bubble" then
		return ps
	end
	return State.role or ps
end

return State
