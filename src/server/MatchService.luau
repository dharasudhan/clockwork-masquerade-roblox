-- The match state machine (server-authoritative):
--   Lobby (30 s) -> [bots fill to 6, roles: 1 Phantom per 5] -> Night N: Day (60 s) -> Night
--   (90 s) -> Results (10 s) -> Lobby ...  M1 plays Night 1 only (Config/Match.NightOrder).
-- Ticks every Config/Match.TickSeconds; all services step from here. Global state is
-- published as workspace attributes (CM_Phase, CM_PhaseEndsAt, CM_Reboot, ...).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Match = require(Shared.Config.Match)
local Nights = require(Shared.Config.Nights)
local Manor = require(Shared.Config.Manor)
local Gadgets = require(Shared.Config.Gadgets)
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
local DataService = require(script.Parent.DataService)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local MatchService = {}

local override: { [string]: number } = {}
local state = { phase = "None", endsAt = 0, nightIdx = 0, night = nil :: any, lastPhantoms = {}, result = nil :: any, match = 0 }
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
	setPhase("Lobby", secs("lobby", Match.LobbySeconds))
end

local function spawnPoint(i: number, n: number): CFrame
	local a = (i / math.max(n, 1)) * math.pi * 2
	local s = Manor.Spawn
	local pos = Vector3.new(s.x + math.cos(a) * s.radius, 3, s.z + math.sin(a) * s.radius)
	return CFrame.lookAt(pos, Vector3.new(s.x, 3, s.z))
end

local function place(p, i: number, n: number)
	if p.model then
		p.model:PivotTo(spawnPoint(i, n))
	end
end

local PUBLIC_KEYS = { "PState", "InMatch", "Battery", "LanternOn", "DryCell", "CopperWire", "GlowStick", "TagReadyAt",
	"FlickerReadyAt", "SlickReadyAt", "SlicksAlive", "Transforming", "Beams", "Revealed", "Slowed", "Repairing" }

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

local function startRound()
	state.match += 1
	state.nightIdx = Match.NightOrder[1]
	state.night = Nights[state.nightIdx]
	local night = state.night
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
		p.inv = { DryCell = 0, CopperWire = 0, GlowStick = 0 }
		p.stats = { chests = 0, repairs = 0, tags = 0 }
		p.state = "Guest"
		p.transformed = false
		p.lastTag, p.lastFlicker, p.lastSlick, p.aim, p.aimAt = nil, nil, nil, nil, nil
		Participants.add(p)
		table.insert(ids, p.id)
	end
	local count = Roles.phantomCount(#entries, Match.PhantomTable)
	local roles = Roles.assign(ids, count, function()
		return rng:NextNumber()
	end, state.lastPhantoms)
	ChestService.stock(night)
	GridService.reset(night)
	BotService.setNight(night)
	for i, p in Participants.all() do
		p.role = roles[p.id]
		place(p, i, #entries)
		ChaseService.prepare(p)
		LanternService.equip(p)
		Participants.set(p, "PState", "Guest") -- a Phantom looks like a guest by day
		Participants.set(p, "InMatch", true)
		for item, n in p.inv do
			Participants.set(p, item, n)
		end
	end
	for _, p in Participants.all() do
		tellRole(p)
	end
	workspace:SetAttribute("CM_Night", state.nightIdx)
	workspace:SetAttribute("CM_NightName", night.name)
	workspace:SetAttribute("CM_Match", state.match)
	LightingService.apply(night.lighting.day)
	setPhase("Day", secs("day", night.daySeconds))
	Net.toast("all", "Night " .. state.nightIdx .. ": " .. night.name .. " - Day falls quiet...", "Brass")
end

local function startNight()
	setPhase("Night", secs("night", state.night.nightSeconds)) -- first: services read CM_Phase
	local tripped = GridService.nightFalls()
	ChaseService.nightFalls()
	LightingService.apply(state.night.lighting.night)
	Net.sfx("all", "NightStart")
	if #tripped > 0 then
		Net.toast("all", "The grid failed! Breaker " .. table.concat(tripped, ", ") .. " tripped - repair it!", "BreakerBad")
	else
		Net.toast("all", "Night falls - the Phantoms unmask!", "MaskNeon")
	end
end

local function roster()
	local out = {}
	for _, p in Participants.all() do
		table.insert(out, { name = p.name, role = p.role, state = p.state, bot = p.isBot == true, tags = p.stats.tags, repairs = p.stats.repairs })
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
			local tokens = Rewards.tokens(p.stats, won, Gadgets.Rewards)
			local saved = DataService.award(p.player, p.role, won, tokens)
			Net.send(p.player, { kind = "results", winner = result.winner, reason = result.reason, won = won, role = p.role, tokens = tokens, saved = saved, stats = p.stats, roster = list })
			Net.sfx(p.player, if won then "Win" else "Lose")
		end
	end
	setPhase("Results", secs("results", Match.ResultsSeconds))
end

local function cleanup()
	ChaseService.reset()
	LanternService.reset()
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
		local total, alive, phantoms = counts()
		workspace:SetAttribute("CM_GuestsTotal", total)
		workspace:SetAttribute("CM_GuestsAlive", alive)
		workspace:SetAttribute("CM_Phantoms", phantoms)
		local grid = GridService.state()
		local result = Outcome.evaluate({
			phase = state.phase, guestsTotal = total, guestsAlive = alive, phantoms = phantoms,
			reboot = grid and grid.reboot or 0, timeLeft = state.endsAt - now,
		})
		if result then
			endRound(result)
		elseif state.phase == "Day" and now >= state.endsAt then
			startNight()
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
	if not p then
		return
	end
	if kind == "lantern" then
		LanternService.setOn(p, if type(arg) == "boolean" then arg else not p.lanternOn)
	elseif kind == "cell" then
		LanternService.useCell(p)
	elseif kind == "glow" then
		ChaseService.dropGlow(p)
	elseif kind == "tag" then
		ChaseService.tryTag(p, nil)
	elseif kind == "flicker" then
		ChaseService.flicker(p)
	elseif kind == "slick" then
		ChaseService.slick(p)
	elseif kind == "cancel" then
		GridService.cancel(p)
	end
end

local function onCharacter(player: Player, char: Model)
	local p = Participants.ofPlayer(player)
	if not p or state.phase == "Results" or state.phase == "Lobby" then
		return
	end
	task.defer(function()
		p.model = char
		char:WaitForChild("HumanoidRootPart", 5)
		place(p, math.random(1, 10), 10)
		ChaseService.reapply(p)
		LanternService.equip(p)
	end)
end

local started = false
function MatchService.init()
	GridService.init()
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
