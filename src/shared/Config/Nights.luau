-- Night n objectives (one entry per night index, up to Match.BotDays or Match.MaxNights)
local Objectives = {}

-- Night 1: find the manor's four cogs (page-shaped tokens); as each cog reaches the Projector in
-- the Library the phantom's exposure ticks up (Phantom.ExposurePerCog)
Objectives[1] = {
	name = "Find the Cogs",
	brief = "The Projector in the Library holds a trap for the phantom. Find the four cogs and bring them there.",
	roles = {
		Guest = "Find the 4 cogs, bring them to the Projector (Library)",
		Phantom = "Stop the guests delivering cogs to the Projector",
	},
}

-- Night 2: the generator vault is failing - the team keeps the lights burning by feeding
-- charge cells into the Generator; every cell burns the phantom (Phantom.CellBurn)
Objectives[2] = {
	name = "Feed the Generator",
	brief = "The Generator Vault is failing. Feed it charge cells to burn the phantom with every surge.",
	roles = {
		Guest = "Carry charge cells to the Generator Vault (B1) and slot them in",
		Phantom = "Interrupt the cell runs and punish anyone alone in the dark",
	},
}

-- Night 3: gather the tear jars the phantom leaves where it strikes; once enough jars are
-- banked in the Ballroom (threshold by player count) it can be banished (BanishService)
Objectives[3] = {
	name = "Gather the Tears",
	brief = "The phantom weeps where it strikes. Gather the tear jars and bank them in the Grand Ballroom to banish it.",
	roles = {
		Guest = "Bank tear jars in the Grand Ballroom until the banish threshold",
		Phantom = "Deny the Ballroom and pick off lone carriers",
	},
}

-- order matters: later overrides earlier (the last defined condition for the night wins)
-- p = players, d = days survived
local function pick(p, d)
	local t = Objectives[1].roles
	if d >= 3 then
		t = Objectives[3].roles
	elseif d >= 2 then
		t = Objectives[2].roles
	end
	local guest, phantom = t.Guest, t.Phantom
	if p >= 8 then
		if d == 1 then
			guest = "Split up: some find cogs, some escort (Projector, Library)"
			phantom = "Cut escorts off; strike the solo sweepers"
		elseif d == 2 then
			guest = "Split up: cells for the Generator (B1) + escorts"
			phantom = "Ambush the cell runners; drag them into shroud"
		else
			guest = "Bank in the Grand Ballroom + fix breakers at the fuse box (B1)"
			phantom = "Hold the Ballroom and the B1 fuse box"
		end
	elseif p >= 4 then
		if d == 1 then
			guest = "Pair up: one finds, one guards the Library projector route"
			phantom = "Pressure the Library corridor (West side)"
		elseif d == 2 then
			guest = "Pair up on the cells; keep one on Generator duty"
			phantom = "Haunt the Generator Vault approaches"
		else
			guest = "Bring pages to the Projector (Royal Library) + fix breakers"
			phantom = "Strike the Projector room; break B1 power"
		end
	end
	return { Guest = guest, Phantom = phantom }
end

return { Objectives = Objectives, pick = pick }
