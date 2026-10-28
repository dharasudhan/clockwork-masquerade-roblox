-- Everyone in the current match: real players and bots behind one record.
--   p = { id, name, isBot, player?, model, role ("Guest" | "Phantom"), state ("Guest" |
--         "Bubble" | "Wisp" | "Phantom"), inv, battery, lanternOn, stats, ... }
-- `role` is PRIVATE (only the owner is told, via Notify). Public attributes on the model (and
-- the Player for humans) carry what any client may see: PState is "Guest" for a Phantom by
-- day and "Phantom" once it transforms at night.
local Participants = {}

local list: { any } = {}
local byId: { [string]: any } = {}
local byPlayer: { [Player]: any } = {}

function Participants.add(p)
	table.insert(list, p)
	byId[p.id] = p
	if p.player then
		byPlayer[p.player] = p
	end
	return p
end

function Participants.remove(p)
	p.gone = true
	byId[p.id] = nil
	if p.player then
		byPlayer[p.player] = nil
	end
	local i = table.find(list, p)
	if i then
		table.remove(list, i)
	end
end

function Participants.clear()
	table.clear(list)
	table.clear(byId)
	table.clear(byPlayer)
end

function Participants.all()
	return list
end

function Participants.get(id: string)
	return byId[id]
end

function Participants.ofPlayer(player: Player)
	return byPlayer[player]
end

function Participants.root(p): BasePart?
	local m = p.model
	if m == nil or m.Parent == nil then
		return nil
	end
	return (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart) :: BasePart?
end

function Participants.humanoid(p): Humanoid?
	local m = p.model
	return if m then m:FindFirstChildOfClass("Humanoid") else nil
end

function Participants.pos(p): Vector3?
	local r = Participants.root(p)
	return if r then r.CFrame.Position else nil -- (CFrame: also readable under Lune)
end

-- Public attribute, mirrored on the model and the Player.
function Participants.set(p, key: string, value: any)
	if p.model then
		p.model:SetAttribute(key, value)
	end
	if p.player then
		p.player:SetAttribute(key, value)
	end
end

function Participants.guests(aliveOnly: boolean?)
	local out = {}
	for _, p in list do
		if p.role == "Guest" and (not aliveOnly or p.state == "Guest") then
			table.insert(out, p)
		end
	end
	return out
end

function Participants.phantoms()
	local out = {}
	for _, p in list do
		if p.role == "Phantom" then
			table.insert(out, p)
		end
	end
	return out
end

return Participants
