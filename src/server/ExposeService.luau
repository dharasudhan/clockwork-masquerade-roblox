-- Expose (GDD): by Day, guests vote at the Evidence Board in the Foyer for who they think is a
-- Phantom (one vote each, changeable until nightfall; Phantoms may vote too so voting never
-- reveals them). Clues make it informed: when a breaker is tampered, a guest who inspects it
-- by Day finds glitter in two ribbon colours - the tamperer's and one other (shuffled). Found
-- clues are public (workspace CM_Clues) and pinned on the board.
-- At nightfall: a clear majority (>= 2 votes, >= 40% of alive voters, more than the runner-up)
-- exposes the suspect. A Phantom is frozen 5 s at night start and outlined through walls for
-- 30 s; an innocent guest is cleared and every voter is "shaken" (x0.85 speed for 20 s).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Match = require(Shared.Config.Match)
local Vote = require(Shared.Logic.Vote)
local Participants = require(script.Parent.Participants)
local ManorBuilder = require(script.Parent.ManorBuilder)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local ExposeService = {}

local E = Match.Expose
local vote = Vote.new()
local clues: { any } = {} -- { breaker, colours = {..}, found = bool, room }
local rng = Random.new()
local hooks = { exposed = nil :: any }
local botVoted: { [string]: boolean } = {}

function ExposeService.onExposed(cb)
	hooks.exposed = cb
end

local function ribbonName(c: string): string
	return Match.RibbonNames[c] or c
end
ExposeService.ribbonName = ribbonName

local function publishClues()
	local parts = {}
	for _, c in clues do
		if c.found then
			local names = {}
			for _, col in c.colours do
				table.insert(names, ribbonName(col))
			end
			table.insert(parts, c.breaker .. ":" .. table.concat(names, "/"))
		end
	end
	workspace:SetAttribute("CM_Clues", table.concat(parts, ","))
end

local function publishVotes()
	local counts = Vote.tally(vote)
	local parts = {}
	for id, n in counts do
		table.insert(parts, id .. "=" .. n)
	end
	table.sort(parts)
	workspace:SetAttribute("CM_Votes", table.concat(parts, ","))
end

function ExposeService.beginDay()
	vote = Vote.new()
	table.clear(clues)
	table.clear(botVoted)
	workspace:SetAttribute("CM_Clues", "")
	workspace:SetAttribute("CM_Votes", "")
	for _, p in Participants.all() do
		Participants.set(p, "VotedFor", nil)
	end
end

-- GridService hook: a breaker was tampered by p
function ExposeService.tampered(p, breaker: string)
	local others = {}
	for _, q in Participants.all() do
		if q ~= p and q.ribbon then
			table.insert(others, q.ribbon)
		end
	end
	table.insert(clues, { breaker = breaker, colours = Vote.clue(p.ribbon or "Cream2", others, rng:NextNumber()), found = false })
end

-- A guest inspects breaker `id` (Day, within range). Returns the clue colours or nil.
function ExposeService.inspect(p, id: string)
	if workspace:GetAttribute("CM_Phase") ~= "Day" or p.state ~= "Guest" then
		return nil
	end
	local b = ManorBuilder.get().breakers[id]
	local pos = Participants.pos(p)
	if not b or not pos or (Vector3.new(b.x, b.y, b.z) - pos).Magnitude > E.inspectRange + 3 then
		return nil
	end
	for _, c in clues do
		if c.breaker == id then
			local first = not c.found
			c.found = true
			publishClues()
			if first then
				local names = {}
				for _, col in c.colours do
					table.insert(names, ribbonName(col))
				end
				Net.toast("all", string.format("Clue! %s or %s glitter on Breaker %s", names[1], names[2] or names[1], id), "Amber")
				Net.sfx("all", "Pickup")
			end
			return c.colours
		end
	end
	if p.player then
		Net.toast(p.player, "Breaker " .. id .. " looks fine. No clues here.", "Cream")
	end
	return nil
end

function ExposeService.clues()
	return clues
end

-- Cast a vote (players via Action "vote", bots directly).
function ExposeService.cast(p, targetId: any): (boolean, string?)
	if workspace:GetAttribute("CM_Phase") ~= "Day" then
		return false, "only by day"
	end
	if type(targetId) ~= "string" then
		return false, "bad target"
	end
	if p.state ~= "Guest" then -- Wisps can't vote; Phantoms show "Guest" by day and may vote
		return false, "can't vote"
	end
	local valid = {}
	for _, q in Participants.all() do
		if q.state == "Guest" or q.state == "Phantom" then
			valid[q.id] = true
		end
	end
	local ok, why = Vote.cast(vote, p.id, targetId, valid)
	if ok then
		Participants.set(p, "VotedFor", targetId)
		publishVotes()
		local t = Participants.get(targetId)
		if p.player and t then
			Net.toast(p.player, "You voted for " .. t.name .. ". You can change it until night.", "Amber")
		end
	end
	return ok, why
end

local function aliveVoters(): number
	local n = 0
	for _, q in Participants.all() do
		if q.state == "Guest" then
			n += 1
		end
	end
	return n
end

-- Bots: guest bots vote for someone whose ribbon matches a found clue; Phantom bots vote for a
-- random guest (never a fellow Phantom). Called each tick by MatchService during the Day.
function ExposeService.stepBots(dayFraction: number)
	-- guest bots that walk past a tampered breaker inspect it
	local built = ManorBuilder.get()
	for _, c in clues do
		if not c.found and built then
			local br = built.breakers[c.breaker]
			for _, b in Participants.all() do
				local pos = b.isBot and b.role == "Guest" and b.state == "Guest" and Participants.pos(b)
				if pos and br and (Vector3.new(br.x, br.y, br.z) - pos).Magnitude <= E.inspectRange then
					ExposeService.inspect(b, c.breaker)
					break
				end
			end
		end
	end
	if dayFraction < 0.65 then
		return
	end
	local found = {}
	for _, c in clues do
		if c.found then
			for _, col in c.colours do
				found[col] = true
			end
		end
	end
	for _, b in Participants.all() do
		if b.isBot and not botVoted[b.id] and b.state == "Guest" then
			botVoted[b.id] = true
			local pool = {}
			for _, q in Participants.all() do
				if q ~= b and (q.state == "Guest" or q.state == "Phantom") then
					if b.role == "Phantom" then
						if q.role ~= "Phantom" then
							table.insert(pool, q)
						end
					elseif next(found) == nil or found[q.ribbon or ""] then
						table.insert(pool, q)
					end
				end
			end
			-- without clues guest bots usually abstain (no wild guesses)
			if #pool > 0 and (next(found) ~= nil or b.role == "Phantom" or rng:NextNumber() < 0.25) then
				ExposeService.cast(b, pool[rng:NextInteger(1, #pool)].id)
			end
		end
	end
end

-- Nightfall: resolve the vote. Returns { target, phantom } or nil.
function ExposeService.resolve()
	local target = Vote.result(vote, aliveVoters(), E.minVotes, E.minShare)
	local now = Clock.now()
	workspace:SetAttribute("CM_Votes", "")
	if not target then
		local _, n = Vote.tally(vote)
		if n > 0 then
			Net.toast("all", "The guests couldn't agree. Nobody was exposed.", "Cream")
		end
		return nil
	end
	local t = Participants.get(target)
	if not t then
		return nil
	end
	local voters = Vote.votersFor(vote, target)
	if t.role == "Phantom" then
		t.stunUntil = now + E.stunSeconds
		t.revealUntil = now + E.revealSeconds
		Participants.set(t, "StunUntil", t.stunUntil)
		Participants.set(t, "Exposed", true)
		Net.toast("all", t.name .. " WAS A PHANTOM! Exposed and frozen!", "MaskNeon")
		Net.sfx("all", "Expose")
		for _, vid in voters do
			local v = Participants.get(vid)
			if v and v.role == "Guest" then
				v.stats.exposes = (v.stats.exposes or 0) + 1
			end
		end
	else
		for _, vid in voters do
			local v = Participants.get(vid)
			if v then
				v.shakenUntil = now + E.shakenSeconds
				Participants.set(v, "ShakenUntil", v.shakenUntil)
			end
		end
		Net.toast("all", t.name .. " was innocent! The voters are shaken.", "BreakerBad")
	end
	if hooks.exposed then
		hooks.exposed(t, t.role == "Phantom", voters)
	end
	return { target = target, phantom = t.role == "Phantom", voters = voters }
end

-- the board's "Vote" prompt (the client opens the vote panel; votes arrive as Action "vote")
function ExposeService.init()
	local built = ManorBuilder.get()
	if not built or not built.props.board then
		return
	end
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "Vote"
	pr.ActionText = "Vote: who is a Phantom?"
	pr.ObjectText = "Evidence Board"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr:SetAttribute("ForRole", "Any")
	pr:SetAttribute("ForPhase", "Day")
	pr.Parent = built.props.board.prompt
end

function ExposeService.votes()
	return vote
end

return ExposeService
