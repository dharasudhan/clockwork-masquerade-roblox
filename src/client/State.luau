-- Client-side view of the match: global attributes + what the server told only us (our
-- secret role, tamper channel, last results, item cards, banners, the tutorial step).
local Players = game:GetService("Players")

local State = {
	role = nil :: string?, -- "Guest" | "Phantom" (private, from Notify "role")
	mates = {} :: { string },
	channel = nil :: any, -- { channel, target, seconds, startedAt }
	results = nil :: any,
	toast = nil :: any, -- { text, color, at }
	roleShownAt = nil :: number?,
	selected = nil :: string?, -- item picked for the USE button (client-only; hotbar / Q / E / 1-9)
	picked = nil :: string?, -- last hotbar chip tapped (for the tooltip of passive items)
	itemCard = nil :: any,
	banner = nil :: any,
	inkUntil = nil :: number?,
	panel = nil :: string?, -- the open modal panel ("Shop", "Settings", "Class", "Vote", "Items")
	inIntro = false,
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

-- Next (dir = 1) / previous (dir = -1) usable item in Config/Items order (wraps).
function State.cycle(list: { string }, dir: number?)
	if #list == 0 then
		State.selected = nil
		return nil
	end
	local i = if State.selected then table.find(list, State.selected) else nil
	local step = dir or 1
	local j = if i then ((i - 1 + step) % #list) + 1 else (if step > 0 then 1 else #list)
	State.selected = list[j]
	return State.selected
end

return State
