-- The match state machine (server-authoritative), v1.0 three-night match:
--   Lobby (30 s) -> [bots fill to 6, roles: 1 Phantom per 5, ribbons, classes] ->
--   Night 1 Main Breaker Tripped: Day -> Night -> Dawn (8 s) ->
--   Night 2 Blueprint Archives:  Day -> Night -> Dawn ->
--   Night 3 Dawn Reboot:         Day -> Night (Showdown -> Overdrive) -> Results -> Lobby ...
-- Nights 1-2 are won or lost without ending the match (tagged guests wake up at the next Day);
-- the match ends early only when every guest is tagged or every Phantom leaves.
-- Ticks every Config/Match.TickSeconds; all services step from here. Global state is
-- published as workspace attributes (CM_Phase, CM_PhaseEndsAt, CM_Reboot, ...).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Match = require(Shared.Config.Match)
local Nights = require(Shared.Config.Nights)
local Manor = require(Shared.Config.Manor)
local Gadgets = require(Shared.Config.Gadgets)
local Items = require(Shared.Config.Items)
local ManorLayout = require(Shared.Logic.ManorLayout)
local Roles = require(Shared.Logic.Roles)
local Outcome = require(Shared.Logic.Outcome)
local Rewards = require(Shared.Logic.Rewards)
local Participants = require(script.Parent.Participants)
local ChestService = require(script.Parent.ChestService)
local GridService = require(script.Parent.GridService)
local LanternService = require(script.Parent.LanternService)
local ChaseService = require(script.Parent.ChaseService)
local LightingService = require(script.Parent.LightingService)
local BotService = require(script.Parent.BotService)
local ItemService = require(script.Parent.ItemService)
local LiftService = require(script.Parent.LiftService)
local DataService = require(script.Parent.DataService)
local ExposeService = require(script.Parent.ExposeService)
local ArchiveService = require(script.Parent.ArchiveService)
local FinaleService = require(script.Parent.FinaleService)
local AbilityService = require(script.Parent.AbilityService)
local ShopService = require(script.Parent.ShopService)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local MatchService = {}

local override: { [string]: number } = {}
local state = { phase = "None", endsAt = 0, nightIdx = 0, orderIdx = 0, night = nil :: any, lastPhantoms = {}, result = nil :: any, match = 0, nightResults = {} :: { string }, dayStart = 0 }
local history: { string } = {} -- phases entered (tests read it)
local rng = Random.new()

function MatchService.setDurations(o: { [string]: number })
	override = o
end

function MatchService.state()
	return state
end

function MatchService.history()
	return history
end

local function secs(key: string, default: number): number
	return override[key] or default
end

local function setPhase(phase: string, seconds: number)
	state.phase = phase
	state.endsAt = Clock.now() + seconds
	workspace:SetAttribute("CM_Phase", phase)
	workspace:SetAttribute("CM_PhaseEndsAt", state.endsAt)
	table.insert(history, phase)
end

local function startLobby()
	LightingService.apply("Lobby")
	workspace:SetAttribute("CM_Winner", nil)
	workspace:SetAttribute("CM_Reason", nil)
	workspace:SetAttribute("CM_Reboot", 0)
	workspace:SetAttribute("CM_Tripped", "")
	workspace:SetAttribute("CM_Stage", nil)
	workspace:SetAttribute("CM_NightsWon", 0)
	workspace:SetAttribute("CM_NightResults", "")
	setPhase("Lobby", secs("lobby", Match.LobbySeconds))
end

local function spawnPoint(i: number, n: number): CFrame
	local a = (i / math.max(n, 1)) * math.pi * 2
	local s = Manor.Spawn
	local y = (s.level or 0) * Manor.LevelHeight + ManorLayout.RootHeight
	local pos = Vector3.new(s.x + math.cos(a) * s.radius, y, s.z + math.sin(a) * s.radius)
	return CFrame.lookAt(pos, Vector3.new(s.x, y, s.z))
end

local function place(p, i: number, n: number)
	if p.model then
		local cf = spawnPoint(i, n)
		if p.player then
			-- StreamingEnabled: ask the client to load the ballroom before the teleport lands
			-- (the place uses PauseOutsideLoadedArea, so nobody falls through an unloaded floor)
			local plr, pos = p.player, cf.Position
			task.spawn(function()
				pcall(function()
					(plr :: any):RequestStreamAroundAsync(pos, 2)
				end)
			end)
		end
		p.model:PivotTo(cf)
	end
end

local PUBLIC_KEYS = { "PState", "InMatch", "Battery", "LanternOn", "TagReadyAt", "FlickerReadyAt", "SlickReadyAt",
	"SlicksAlive", "Transforming", "Beams", "Revealed", "Slowed", "Repairing", "ImmuneUntil", "BoostUntil",
	"Ribbon", "PClass", "Pages", "CarryKey", "VotedFor", "FrozenUntil", "StunUntil", "ShakenUntil", "Exposed",
	"GadgetReadyAt", "Held", "PId", "PName" }
for _, id in Items.Order do
	table.insert(PUBLIC_KEYS, id)
	table.insert(PUBLIC_KEYS, "ReadyAt_" .. id)
end

local function clearPublic(p)
	for _, k in PUBLIC_KEYS do
		Participants.set(p, k, nil)
	end
end

local function tellRole(p)
	if not p.player then
		return
	end
	local mates = {}
	if p.role == "Phantom" then
		for _, q in Participants.phantoms() do
			if q ~= p then
				table.insert(mates, q.name)
			end
		end
	end
	Net.send(p.player, { kind = "role", role = p.role, night = state.night and state.night.name, mates = mates })
end

local function nightsWon(): number
	local n = 0
	for _, r in state.nightResults do
		if r == "Guests" then
			n += 1
		end
	end
	return n
end

local function isLast(): boolean
	return state.orderIdx >= #Match.NightOrder
end

-- Day of night number `orderIdx` (1..#NightOrder)
local function beginDay(orderIdx: number)
	state.orderIdx = orderIdx
	state.nightIdx = Match.NightOrder[orderIdx]
	state.night = Nights[state.nightIdx]
	local night = state.night
	if orderIdx > 1 then
		ChaseService.dawn() -- Wisps wake up as guests, Phantoms re-disguise
		ItemService.reset()
		AbilityService.reset()
	end
	for _, p in Participants.all() do
		GridService.cancel(p)
		if p.lanternOn then
			LanternService.setOn(p, false)
		end
	end
	ChestService.stock(night)
	GridService.reset(night)
	ArchiveService.reset(night)
	FinaleService.reset(night, nightsWon(), #state.nightResults - nightsWon())
	ExposeService.beginDay()
	BotService.setNight(night)
	ItemService.setNight(night)
	AbilityService.setNight(night)
	AbilityService.setStage(nil)
	workspace:SetAttribute("CM_Night", state.nightIdx)
	workspace:SetAttribute("CM_NightNo", orderIdx)
	workspace:SetAttribute("CM_NightCount", #Match.NightOrder)
	workspace:SetAttribute("CM_NightName", night.name)
	workspace:SetAttribute("CM_NightKind", night.kind)
	workspace:SetAttribute("CM_Stage", nil)
	LightingService.apply(night.lighting.day)
	state.dayStart = Clock.now()
	state.overdrive = false
	setPhase("Day", secs("day", night.daySeconds))
	Net.toast("all", string.format("Night %d of %d: %s - the Day begins", orderIdx, #Match.NightOrder, night.name), "Brass")
	Net.sendAll({ kind = "night", no = orderIdx, count = #Match.NightOrder, name = night.name, nightKind = night.kind })
end

local function startRound()
	state.match += 1
	state.nightResults = {}
	Participants.clear()
	local humans = {}
	local used = {}
	for _, pl in Players:GetPlayers() do
		if #humans >= Match.MaxPlayers then
			break
		end
		local char = pl.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			table.insert(humans, pl)
			used[pl.DisplayName] = true
		end
	end
	local entries = {}
	for _, pl in humans do
		table.insert(entries, { id = "P" .. pl.UserId, name = pl.DisplayName, isBot = false, player = pl, model = pl.Character })
	end
	for _, b in BotService.spawn(Roles.botsNeeded(#humans, Match.MinPlayers, Match.MaxPlayers), used) do
		table.insert(entries, b)
	end
	local ids = {}
	for _, p in entries do
		p.inv = Items.emptyInventory()
		p.stats = { chests = 0, repairs = 0, tags = 0, items = 0, lifts = 0, nightsWon = 0, keys = 0, pages = 0, exposes = 0 }
		p.itemAt, p.immuneUntil, p.boostUntil, p.liftAt = {}, nil, nil, nil
		p.state = "Guest"
		p.transformed = false
		p.lastTag, p.lastFlicker, p.lastSlick, p.aim, p.aimAt = nil, nil, nil, nil, nil
		p.abilityAt, p.frozenUntil, p.stunUntil, p.shakenUntil, p.revealUntil = {}, nil, nil, nil, nil
		p.pages, p.carryKey = 0, nil
		local data = p.player and DataService.get(p.player)
		p.class = if data then data.Class elseif p.isBot then Gadgets.ClassOrder[rng:NextInteger(1, #Gadgets.ClassOrder)] else "Mechanist"
		Participants.add(p)
		table.insert(ids, p.id)
	end
	local count = Roles.phantomCount(#entries, Match.PhantomTable)
	local roles = Roles.assign(ids, count, function()
		return rng:NextNumber()
	end, state.lastPhantoms)
	ShopService.assignRibbons(Participants.all())
	for i, p in Participants.all() do
		p.role = roles[p.id]
		place(p, i, #entries)
		ShopService.dress(p)
		ChaseService.prepare(p)
		LanternService.equip(p)
		Participants.set(p, "PState", "Guest") -- a Phantom looks like a guest by day
		Participants.set(p, "InMatch", true)
		Participants.set(p, "PId", p.id)
		Participants.set(p, "PName", p.name)
		Participants.set(p, "PClass", if p.role == "Guest" then p.class else (if rng:NextNumber() < 0.5 then "Mechanist" else "Illuminator"))
		for item, n in p.inv do
			Participants.set(p, item, n)
		end
	end
	beginDay(1)
	for _, p in Participants.all() do
		tellRole(p)
	end
	workspace:SetAttribute("CM_Match", state.match)
end

local function startNight()
	local night = state.night
	local length = if night.kind == "finale" then secs("showdown", night.showdownSeconds) else secs("night", night.nightSeconds)
	setPhase("Night", length) -- first: services read CM_Phase
	ExposeService.resolve()
	local tripped = GridService.nightFalls()
	ChaseService.nightFalls()
	LightingService.apply(night.lighting.night)
	Net.sfx("all", "NightStart")
	if night.kind == "finale" then
		FinaleService.showdown()
		AbilityService.setStage("Showdown")
		workspace:SetAttribute("CM_Stage", "Showdown")
	elseif #tripped > 0 then
		Net.toast("all", "The grid failed! Breaker " .. table.concat(tripped, ", ") .. " tripped - repair it!", "BreakerBad")
	else
		Net.toast("all", "Night falls - the Phantoms unmask!", "MaskNeon")
	end
end

local function goOverdrive()
	local night = state.night
	state.endsAt = Clock.now() + secs("overdrive", night.overdriveSeconds)
	workspace:SetAttribute("CM_PhaseEndsAt", state.endsAt)
	workspace:SetAttribute("CM_Stage", "Overdrive")
	AbilityService.setStage("Overdrive")
	LightingService.apply("Overdrive")
	table.insert(history, "Overdrive")
end

-- a night (not the match) is over: record it, show the Dawn interlude, then the next Day
local function nightOver(result)
	table.insert(state.nightResults, result.winner)
	workspace:SetAttribute("CM_NightResults", table.concat(state.nightResults, ","))
	workspace:SetAttribute("CM_NightsWon", nightsWon())
	workspace:SetAttribute("CM_LastNightWinner", result.winner)
	for _, p in Participants.all() do
		if (result.winner == "Guests" and p.role == "Guest") or (result.winner == "Phantoms" and p.role == "Phantom") then
			p.stats.nightsWon += 1
		end
		if p.lanternOn then
			LanternService.setOn(p, false)
		end
		GridService.cancel(p)
	end
	if result.winner == "Guests" then
		LightingService.apply("Day")
		Net.sfx("all", "Dawn")
		Net.toast("all", "DAWN! The guests rebooted the grid. Everyone wakes up for the next night!", "TealNeon")
	else
		Net.toast("all", "The manor stayed dark... the Phantoms grow stronger. Tagged guests wake up.", "MaskNeon")
	end
	Net.sendAll({ kind = "dawn", winner = result.winner, reason = result.reason, no = state.orderIdx, nightsWon = nightsWon() })
	setPhase("Dawn", secs("dawn", Match.DawnSeconds))
end

local function roster()
	local out = {}
	for _, p in Participants.all() do
		table.insert(out, { name = p.name, role = p.role, state = p.state, bot = p.isBot == true, tags = p.stats.tags, repairs = p.stats.repairs, ribbon = p.ribbon })
	end
	return out
end

local function endRound(result)
	state.result = result
	workspace:SetAttribute("CM_Winner", result.winner)
	workspace:SetAttribute("CM_Reason", result.reason)
	for _, p in Participants.all() do
		if p.lanternOn then
			LanternService.setOn(p, false)
		end
		GridService.cancel(p)
	end
	local list = roster()
	state.lastPhantoms = {}
	for _, p in Participants.all() do
		if p.role == "Phantom" then
			state.lastPhantoms[p.id] = true
		end
		local won = (result.winner == "Guests" and p.role == "Guest") or (result.winner == "Phantoms" and p.role == "Phantom")
		p.won = won
		if p.player then
			local tokens, xp = Rewards.tokens(p.stats, won, Gadgets.Rewards, ShopService.tokenMultiplier(p.player))
			local saved, newLevel = DataService.award(p.player, p.role, won, tokens, xp, p.stats)
			if won and p.role == "Guest" and result.reason and FinaleService.active() and p.inRingAt and Clock.now() - p.inRingAt < 1.5 then
				DataService.badge(p.player, "OverdriveMaster")
			end
			Net.send(p.player, { kind = "results", winner = result.winner, reason = result.reason, won = won, role = p.role, tokens = tokens, xp = xp, level = newLevel, saved = saved, stats = p.stats, roster = list, nights = state.nightResults })
			Net.sfx(p.player, if won then "Win" else "Lose")
		end
	end
	setPhase("Results", secs("results", Match.ResultsSeconds))
end

local function cleanup()
	ChaseService.reset()
	AbilityService.reset()
	ArchiveService.clear()
	FinaleService.clear()
	LanternService.reset()
	ItemService.reset()
	ChestService.clear()
	for _, p in Participants.all() do
		GridService.cancel(p)
		clearPublic(p)
	end
	BotService.despawnAll()
	for _, p in Participants.all() do
		if p.player and p.player.Parent == Players then
			pcall(function()
				p.player:LoadCharacter() -- fresh character back on the lobby terrace
			end)
		end
	end
	Participants.clear()
	startLobby()
end

local function counts()
	local total, alive, phantoms = 0, 0, 0
	for _, p in Participants.all() do
		if p.role == "Guest" then
			total += 1
			if p.state == "Guest" then
				alive += 1
			end
		elseif p.role == "Phantom" then
			phantoms += 1
		end
	end
	return total, alive, phantoms
end

function MatchService.step(dt: number)
	local now = Clock.now()
	if state.phase == "Lobby" then
		if now >= state.endsAt then
			startRound()
		end
	elseif state.phase == "Day" or state.phase == "Night" then
		BotService.step(dt)
		GridService.step(dt)
		LanternService.step(dt)
		ChaseService.step(dt)
		ItemService.step(dt)
		AbilityService.step(dt)
		ArchiveService.step(dt)
		FinaleService.step(dt)
		local night = state.night
		if state.phase == "Day" then
			local len = math.max(1, state.endsAt - state.dayStart)
			ExposeService.stepBots((now - state.dayStart) / len)
		end
		-- finale: all 3 keys in -> Overdrive (the timer restarts)
		if night.kind == "finale" and state.phase == "Night" and FinaleService.stage() == "Overdrive" and not state.overdrive then
			state.overdrive = true
			goOverdrive()
		end
		local total, alive, phantoms = counts()
		workspace:SetAttribute("CM_GuestsTotal", total)
		workspace:SetAttribute("CM_GuestsAlive", alive)
		workspace:SetAttribute("CM_Phantoms", phantoms)
		local grid = GridService.state()
		local ring, need = FinaleService.ring()
		local result = Outcome.evaluate({
			phase = state.phase, kind = night.kind, stage = FinaleService.stage(), last = isLast(),
			guestsTotal = total, guestsAlive = alive, phantoms = phantoms,
			reboot = grid and grid.reboot or 0, ring = ring, ringNeed = need, timeLeft = state.endsAt - now,
		})
		if result then
			if result.final then
				endRound(result)
			else
				nightOver(result)
			end
		elseif state.phase == "Day" and now >= state.endsAt then
			startNight()
		end
	elseif state.phase == "Dawn" then
		if now >= state.endsAt then
			beginDay(state.orderIdx + 1)
		end
	elseif state.phase == "Results" then
		if now >= state.endsAt then
			cleanup()
		end
	end
end

-- ---- remotes --------------------------------------------------------------------------------
local function onAction(player: Player, kind: any, arg: any)
	if type(kind) ~= "string" or not Net.allowAction(player) then
		return
	end
	local p = Participants.ofPlayer(player)
	if kind == "whoami" then
		if p then
			tellRole(p)
		end
		return
	end
	-- profile actions (any time, in or out of a match)
	if kind == "buy" then
		local ok, why = ShopService.buy(player, arg)
		if not ok then
			Net.toast(player, if why == "tokens" then "Not enough Gear Tokens yet - play to earn more!" else "Can't buy that (" .. tostring(why) .. ")", "BreakerBad")
		end
		return
	elseif kind == "equip" then
		ShopService.equip(player, arg)
		return
	elseif kind == "emote" then
		ShopService.emote(player, p, arg)
		return
	elseif kind == "setting" then
		if type(arg) == "table" then
			DataService.setSetting(player, arg.key, arg.value)
		end
		return
	elseif kind == "class" then
		if DataService.setClass(player, arg) then
			Net.toast(player, "Class: " .. tostring(arg) .. (if p then " (from the next match)" else ""), "TealNeon")
		end
		return
	elseif kind == "introDone" then
		DataService.setFlag(player, "IntroSeen")
		return
	elseif kind == "tutorialDone" then
		DataService.setFlag(player, "TutorialDone")
		return
	end
	if not p then
		return
	end
	if kind == "lantern" then
		LanternService.setOn(p, if type(arg) == "boolean" then arg else not p.lanternOn)
	elseif kind == "use" then
		local ok, why = ItemService.use(p, arg)
		if not ok and p.player and why ~= "cooldown" and why ~= "bad id" then
			Net.toast(p.player, "Can't use that now (" .. tostring(why) .. ")", "BreakerBad")
		end
	elseif kind == "cell" then
		ItemService.use(p, "DryCell")
	elseif kind == "glow" then
		ItemService.use(p, "GlowStick")
	elseif kind == "lift" then
		LiftService.ride(p, arg)
	elseif kind == "tag" then
		ChaseService.tryTag(p, nil)
	elseif kind == "flicker" then
		ChaseService.flicker(p)
	elseif kind == "slick" then
		ChaseService.slick(p)
	elseif kind == "cancel" then
		GridService.cancel(p)
	elseif kind == "gadget" then
		AbilityService.use(p)
	elseif kind == "vote" then
		local ok, why = ExposeService.cast(p, arg)
		if not ok then
			Net.toast(player, "Can't vote (" .. tostring(why) .. ")", "BreakerBad")
		end
	elseif kind == "hold" then
		ItemService.hold(p, arg)
	end
end

local function onCharacter(player: Player, char: Model)
	local p = Participants.ofPlayer(player)
	if not p or state.phase == "Results" or state.phase == "Lobby" then
		-- lobby: wear your masquerade mask on the terrace too
		task.defer(function()
			char:WaitForChild("Head", 5)
			ShopService.dressModel(char, player, nil)
		end)
		return
	end
	task.defer(function()
		p.model = char
		char:WaitForChild("HumanoidRootPart", 5)
		place(p, math.random(1, 10), 10)
		ShopService.dress(p)
		ChaseService.reapply(p)
		LanternService.equip(p)
	end)
end

local started = false
function MatchService.init()
	workspace:SetAttribute("CM_Version", Match.Version)
	GridService.init()
	ItemService.init()
	LiftService.init()
	ShopService.init()
	ExposeService.init()
	GridService.onTampered(ExposeService.tampered)
	GridService.onInspect(ExposeService.inspect)
	ChaseService.setModifiers(FinaleService.phantomSpeed, FinaleService.carryFactor, ArchiveService.barrier)
	FinaleService.onRevive(ChaseService.reviveWisps)
	Net.Action.OnServerEvent:Connect(onAction)
	Net.Aim.OnServerEvent:Connect(function(player, x, y, z)
		if not Net.allowAim(player) then
			return
		end
		local p = Participants.ofPlayer(player)
		if p then
			LanternService.setAim(p, x, y, z)
		end
	end)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
	end
	for _, pl in Players:GetPlayers() do
		hook(pl)
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(player)
		local p = Participants.ofPlayer(player)
		if p then
			GridService.cancel(p)
			Participants.remove(p)
		end
		Net.forget(player)
	end)
	startLobby()
end

-- Starts the 10 Hz loop (real servers). Tests call MatchService.step directly instead.
function MatchService.start()
	if started then
		return
	end
	started = true
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		local n = 0
		while accum >= Match.TickSeconds and n < 3 do
			accum -= Match.TickSeconds
			n += 1
			local ok, err = pcall(MatchService.step, Match.TickSeconds)
			if not ok then
				warn("[MatchService] " .. tostring(err))
			end
		end
		if accum > 1 then
			accum = 0
		end
	end)
end

return MatchService
