-- Headless engine smoke test (no Roblox Studio needed). Shims adapted from Ghost Mansion's.
-- Loads the built .rbxl with Lune's roblox library, shims the few engine APIs Lune lacks
-- (PivotTo, events, Random, TweenService, Raycast), builds the manor, then plays FULL
-- bot-only rounds on a fake clock, stages every rule (tamper, repair, lantern slow, tag ->
-- bubble -> wisp, flicker, slick cap, rate limits, saves) and lays the HUD out on phones.
-- Lune validates every property name and enum against Roblox's reflection database,
-- so typos in Instance construction fail here instead of in a live server.
-- Usage: lune run scripts/engine_smoke.luau [build/ClockworkMasquerade.rbxl]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local taskLib = require("@lune/task")

local Instance, CFrame, Vector3 = roblox.Instance, roblox.CFrame, roblox.Vector3
local game = roblox.deserializePlace(fs.readFile(process.args[1] or "build/ClockworkMasquerade.rbxl"))
local workspace = game:GetService("Workspace")

-- ---- shims ---------------------------------------------------------------
local signals = {}
local function fakeSignal(inst, name)
	signals[inst] = signals[inst] or {}
	if not signals[inst][name] then
		local s = { handlers = {} }
		function s:Connect(fn)
			table.insert(self.handlers, fn)
			return { Disconnect = function() end }
		end
		s.Once = s.Connect
		function s:Fire(...)
			for _, h in self.handlers do
				h(...)
			end
		end
		function s:Wait() end
		signals[inst][name] = s
	end
	return signals[inst][name]
end
local function eventsOn(className, names)
	for _, n in names do
		roblox.implementProperty(className, n, function(inst)
			return fakeSignal(inst, n)
		end)
	end
end
eventsOn("ProximityPrompt", { "Triggered", "PromptButtonHoldBegan", "PromptButtonHoldEnded" })
eventsOn("Players", { "PlayerAdded", "PlayerRemoving" })
eventsOn("RunService", { "Heartbeat", "RenderStepped" })
eventsOn("RemoteEvent", { "OnServerEvent", "OnClientEvent" })
eventsOn("Player", { "CharacterAdded" })
eventsOn("Humanoid", { "Died" })
eventsOn("GuiButton", { "Activated" })
eventsOn("GuiObject", { "InputBegan", "InputEnded" })
eventsOn("UserInputService", { "InputBegan", "InputEnded" })
eventsOn("BasePart", { "Touched" })
eventsOn("Tool", { "Activated", "Deactivated" })
eventsOn("Instance", { "ChildAdded" })
eventsOn("IntValue", { "Changed" })
eventsOn("NumberValue", { "Changed" })
eventsOn("UserInputService", { "TouchTapInWorld" })
eventsOn("Sound", { "Ended", "DidLoop" })
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(inst, name)
	return fakeSignal(inst, "Attr:" .. tostring(name))
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(inst, name)
	return fakeSignal(inst, "Prop:" .. tostring(name))
end)
roblox.implementMethod("Humanoid", "EquipTool", function(humanoid, tool)
	tool.Parent = humanoid.Parent
end)
local sentToServer = {}
roblox.implementMethod("RemoteEvent", "FireServer", function(remote, ...)
	table.insert(sentToServer, { remote = remote.Name, args = { ... } })
end)
local boundActions = {}
roblox.implementMethod("ContextActionService", "BindAction", function(_, name, fn, _touch, ...)
	boundActions[name] = { fn = fn, keys = { ... } }
end)
roblox.implementMethod("UserInputService", "GetMouseLocation", function()
	return roblox.Vector2.new(0, 0)
end)
roblox.implementMethod("GuiService", "GetGuiInset", function()
	return roblox.Vector2.new(0, 0), roblox.Vector2.new(0, 0)
end)
-- Lune cannot override real Camera properties, so the client sees a stand-in camera:
-- iPad-sized viewport, every point projects onto the screen centre in front of the camera.
local fakeCamera = {
	ViewportSize = roblox.Vector2.new(1024, 768),
	WorldToViewportPoint = function()
		return Vector3.new(512, 384, 10), true
	end,
	GetPropertyChangedSignal = function(self, name)
		return fakeSignal(self, name)
	end,
}
-- client modules get a workspace proxy whose CurrentCamera is the stand-in
local clientWorkspace = setmetatable({ CurrentCamera = fakeCamera }, {
	__index = function(_, k)
		local v = workspace[k]
		if type(v) == "function" then
			return function(_, ...)
				return v(workspace, ...)
			end
		end
		return v
	end,
})
local sentToClient = {}
roblox.implementMethod("RemoteEvent", "FireClient", function(remote, player, ...)
	table.insert(sentToClient, { remote = remote.Name, player = player, args = { ... } })
end)
roblox.implementMethod("RemoteEvent", "FireAllClients", function(remote, ...)
	table.insert(sentToClient, { remote = remote.Name, player = "all", args = { ... } })
end)
-- Fractional like the real one: Lune stores *integral* attribute numbers lossily (float32),
-- Roblox stores attribute numbers as doubles.
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return os.time() + 0.25 + (os.clock() % 0.5)
end)
roblox.implementMethod("Player", "Kick", function(_, msg)
	error("player kicked: " .. tostring(msg))
end)

local function pivot(inst, cf)
	if inst:IsA("BasePart") then
		inst.CFrame = cf
		return
	end
	local primary = inst.PrimaryPart
	local origin = if primary then primary.CFrame else CFrame.new()
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = cf * origin:Inverse() * d.CFrame
		end
	end
end
roblox.implementMethod("Model", "PivotTo", pivot)
roblox.implementMethod("BasePart", "PivotTo", pivot)
local fakePlayers = {}
roblox.implementMethod("Players", "GetPlayers", function()
	return fakePlayers
end)
roblox.implementMethod("HttpService", "GenerateGUID", function()
	return string.format("%08x-0000", math.random(0, 0x7fffffff))
end)
roblox.implementMethod("Instance", "WaitForChild", function(inst, name)
	return inst:FindFirstChild(name)
		or error("WaitForChild: missing " .. name .. " under " .. inst:GetFullName())
end)
roblox.implementMethod("TweenService", "Create", function()
	return { Play = function() end }
end)
roblox.implementMethod("Debris", "AddItem", function() end)
roblox.implementMethod("Workspace", "Raycast", function()
	return nil -- open line of sight everywhere (walls are tested in the cloud)
end)
local function makeCharacter(name)
	local character = Instance.new("Model")
	character.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, 3, 122)
	root.Parent = character
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.CFrame = CFrame.new(0, 4.5, 122)
	head.Parent = character
	character.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	character.Parent = workspace
	return character
end
roblox.implementMethod("Player", "LoadCharacter", function(player)
	local old = player.Character
	if old then
		old:Destroy()
	end
	player.Character = makeCharacter(player.Name)
	fakeSignal(player, "CharacterAdded"):Fire(player.Character)
end)

-- Sound playback model (Lune has no audio engine): Play = from 0, Resume = from where it
-- paused, Pause keeps the position, Stop rewinds. `soundLog` records every call (tests check
-- that music is never restarted).
local soundState = {} -- keyed by a per-Sound id attribute (Lune userdata are not stable table keys)
local soundIds = 0
local soundLog = {}
local function sstate(s)
	local id = s:GetAttribute("FakeSoundId")
	if not id then
		soundIds += 1
		id = soundIds
		s:SetAttribute("FakeSoundId", id)
	end
	soundState[id] = soundState[id] or { playing = false, pos = 0, t0 = os.clock() }
	return soundState[id]
end
local function spos(s)
	local st = sstate(s)
	return if st.playing then st.pos + (os.clock() - st.t0) else st.pos
end
for _, m in { "Play", "Resume", "Pause", "Stop" } do
	roblox.implementMethod("Sound", m, function(s)
		local st = sstate(s)
		table.insert(soundLog, { sound = s, call = m })
		local now = spos(s)
		if m == "Play" then
			st.playing, st.pos = true, 0
		elseif m == "Resume" then
			st.playing, st.pos = true, now
		elseif m == "Pause" then
			st.playing, st.pos = false, now
		else
			st.playing, st.pos = false, 0
		end
		st.t0 = os.clock()
	end)
end
-- (Lune cannot override the real read-only Sound properties: SoundManager reads them
-- through a probe and the smoke swaps in this model.)
local fakeSoundProbe = {
	playing = function(snd)
		return sstate(snd).playing
	end,
	loaded = function()
		return true
	end,
	position = spos,
	length = function(snd)
		return snd:GetAttribute("FakeLength") or 120
	end,
	setPosition = function(snd, v)
		local st = sstate(snd)
		st.pos, st.t0 = v, os.clock()
	end,
}

local Random = {}
function Random.new(seed)
	local s = seed or os.time()
	local rng = { _s = s }
	math.randomseed(s)
	function rng:NextNumber(a, b)
		local x = math.random()
		if a then
			return a + (b - a) * x
		end
		return x
	end
	function rng:NextInteger(a, b)
		return math.random(a, b)
	end
	return rng
end

-- Bots: Humanoid:MoveTo walks instantly (the whole rig is pivoted onto the point) and
-- PathfindingService returns a straight 3-waypoint path, or errors when pathMode == "error"
-- (exercises the waypoint fallback). CreateHumanoidModelFromDescription stays unimplemented
-- here, so bots use the built-in fallback rig.
local moveCalls = 0
roblox.implementMethod("Humanoid", "MoveTo", function(humanoid, point)
	-- walks at WalkSpeed: each call (one per 0.1 s server tick) moves WalkSpeed * 0.1 studs
	-- towards the point (no wall collision; bots route through door points)
	moveCalls += 1
	local model = humanoid.Parent
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if root then
		local from = root.CFrame.Position
		local flat = Vector3.new(point.X - from.X, 0, point.Z - from.Z)
		local d = flat.Magnitude
		local stepLen = humanoid.WalkSpeed * 0.1
		local to = if d <= stepLen or d < 1e-3 then Vector3.new(point.X, from.Y, point.Z) else from + flat.Unit * stepLen
		pivot(model, CFrame.new(to) * (root.CFrame - root.CFrame.Position))
	end
end)
local pathMode = "ok"
local pathComputes = 0
roblox.implementMethod("PathfindingService", "CreatePath", function()
	if pathMode == "error" then
		error("PathfindingService unavailable (smoke)")
	end
	local path = { Status = roblox.Enum.PathStatus.NoPath, _wps = {} }
	function path:ComputeAsync(from, to)
		pathComputes += 1
		self.Status = roblox.Enum.PathStatus.Success
		local mid = from:Lerp(to, 0.5)
		self._wps = {
			{ Position = from, Action = roblox.Enum.PathWaypointAction.Walk },
			{ Position = mid, Action = roblox.Enum.PathWaypointAction.Walk },
			{ Position = to, Action = roblox.Enum.PathWaypointAction.Walk },
		}
	end
	function path:GetWaypoints()
		return self._wps
	end
	return path
end)

-- ---- module loader -------------------------------------------------------
local cache = {}
-- ProfileStore needs live DataStore/MessagingService; replace it with an in-memory stand-in
-- exposing the subset of its API the game uses (New, StartSessionAsync, OnError, Profile.*).
local seededSaves: { [string]: any } = {} -- key -> an old save to load instead of the template
local MockProfileStore = {
	OnError = { Connect = function() end },
	seeded = seededSaves,
	New = function(_name, template)
		return {
			StartSessionAsync = function(_, key, _params)
				local function deepCopy(t)
					local c = {}
					for k, v in t do
						c[k] = if type(v) == "table" then deepCopy(v) else v
					end
					return c
				end
				local data = deepCopy(template)
				local seed = seededSaves[key]
				if seed then
					data = deepCopy(seed)
					for k, v in template do -- what Profile:Reconcile() does: fill missing keys
						if data[k] == nil then
							data[k] = if type(v) == "table" then deepCopy(v) else v
						end
					end
				end
				return {
					Data = data,
					AddUserId = function() end,
					Reconcile = function() end,
					EndSession = function() end,
					OnSessionEnd = { Connect = function() end },
				}
			end,
		}
	end,
}
local envOverrides: { [string]: any } = {}
local function requireModule(inst)
	if cache[inst] ~= nil then
		return cache[inst]
	end
	if inst.Name == "ProfileStore" then
		cache[inst] = MockProfileStore
		return MockProfileStore
	end
	local fn = luau.load(inst.Source, {
		debugName = inst:GetFullName(),
		environment = {
			script = inst,
			game = game,
			workspace = workspace,
			require = requireModule,
			Instance = Instance,
			Vector3 = Vector3,
			Vector2 = roblox.Vector2,
			CFrame = CFrame,
			Color3 = roblox.Color3,
			ColorSequence = roblox.ColorSequence,
			NumberSequence = roblox.NumberSequence,
			NumberRange = roblox.NumberRange,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			UDim2 = roblox.UDim2,
			UDim = roblox.UDim,
			Enum = roblox.Enum,
			TweenInfo = {
				new = function()
					return {}
				end,
			},
			Random = Random,
			RaycastParams = { new = function()
				return {}
			end },
			task = taskLib,
			typeof = typeof,
			warn = print,
			print = print,
		},
		injectGlobals = true,
	})
	for k, v in envOverrides do
		getfenv(fn)[k] = v
	end
	local result = fn()
	cache[inst] = result
	return result
end

-- ---- run -----------------------------------------------------------------
local failures = 0
local function step(name, fn)
	local ok, err = pcall(fn)
	print((if ok then "[OK]   " else "[FAIL] ") .. name .. (if ok then "" else "\n       " .. tostring(err)))
	if not ok then
		failures += 1
	end
end

local Server = game:GetService("ServerScriptService").Server
local Shared = game:GetService("ReplicatedStorage").Shared
local Players = game:GetService("Players")
local Manor = requireModule(Shared.Config.Manor)
local Gadgets = requireModule(Shared.Config.Gadgets)
local Nights = requireModule(Shared.Config.Nights)
local HudLayout = requireModule(Shared.Logic.HudLayout)
local DEBUG_BAL = process.env.DEBUG_BAL == "1"

local ManorBuilder, LightingService, MatchService, BotService, GridService, ChaseService
local LanternService, ChestService, Participants, Clock, DataService, Net
step("require server modules", function()
	Clock = requireModule(Server.Clock)
	ManorBuilder = requireModule(Server.ManorBuilder)
	LightingService = requireModule(Server.LightingService)
	Participants = requireModule(Server.Participants)
	GridService = requireModule(Server.GridService)
	ChestService = requireModule(Server.ChestService)
	LanternService = requireModule(Server.LanternService)
	ChaseService = requireModule(Server.ChaseService)
	BotService = requireModule(Server.BotService)
	DataService = requireModule(Server.DataService)
	MatchService = requireModule(Server.MatchService)
	Net = requireModule(Server.Net)
end)

local built
step("ManorBuilder: one-floor manor, 3 breakers, lights per room, lobby terrace", function()
	built = ManorBuilder.build()
	local map = workspace:FindFirstChild("Map")
	assert(map and map:FindFirstChild("Manor") and map:FindFirstChild("Lobby"), "map missing")
	local rooms = map.Manor.Rooms:GetChildren()
	assert(#rooms == #Manor.Rooms, "rooms " .. #rooms)
	for _, r in Manor.Rooms do
		assert(built.roomLights[r.id] and #built.roomLights[r.id] >= 1, "no lights in " .. r.id)
	end
	for _, id in { "A", "B", "C" } do
		local b = built.breakers[id]
		assert(b and b.model.Parent, "breaker " .. id)
	end
	assert(map.Lobby:FindFirstChild("LobbySpawn"), "no lobby spawn")
	local parts = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print("       map parts: " .. parts)
	assert(parts > 300 and parts < 3000, "part budget " .. parts)
	for _, d in map:GetDescendants() do
		assert(not string.find(string.lower(d.Name), "ghost"), "ghost-themed instance " .. d:GetFullName())
	end
end)

step("look: brass/teal manor, warm day, violet night (not Ghost Mansion's)", function()
	local Lighting = game:GetService("Lighting")
	LightingService.apply("Day")
	local l = built.roomLights.ballroom[1]
	assert(l.Color.R > l.Color.B, "day light not warm")
	LightingService.apply("Night")
	assert(l.Color.B > l.Color.R and l.Color.B > l.Color.G, "night light not violet")
	assert(Lighting.Ambient.B > Lighting.Ambient.R, "night ambient not violet")
	assert(Lighting:FindFirstChildOfClass("Atmosphere"), "no atmosphere")
	LightingService.apply("Lobby")
end)

step("billboards are stud-sized, short range, behind walls", function()
	local n = 0
	for _, d in workspace:GetDescendants() do
		if d:IsA("BillboardGui") then
			n += 1
			assert(d.Size.X.Offset == 0 and d.Size.Y.Offset == 0, "pixel-sized billboard " .. d:GetFullName())
			assert(d.MaxDistance > 0 and d.MaxDistance <= 150, "billboard range " .. d:GetFullName())
			assert(d.AlwaysOnTop == false, "on-top billboard " .. d:GetFullName())
		end
	end
	assert(n >= 3, "breaker labels missing")
end)

-- ---- a human player (mock ProfileStore) ------------------------------------
local human
step("DataService: profile loads with safe defaults + leaderstats", function()
	DataService.init()
	human = Instance.new("Player")
	human.Name = "Tester"
	human.UserId = 4242
	human.DisplayName = "Tester"
	human.Parent = Players
	human.Character = makeCharacter("Tester")
	table.insert(fakePlayers, human)
	fakeSignal(Players, "PlayerAdded"):Fire(human)
	taskLib.wait(0.1)
	local data = DataService.get(human)
	assert(data and data.GearTokens == 0 and data.Wins.Guest == 0, "bad defaults")
	assert(human.leaderstats["Gear Tokens"].Value == 0, "leaderstats")
end)

local T = 1000
Clock.setFake(T)
local function run(seconds, until_)
	local steps = math.floor(seconds * 10 + 0.5)
	for _ = 1, steps do
		Clock.advance(0.1)
		MatchService.step(0.1)
		if until_ and until_() then
			return true
		end
	end
	return false
end
local function phase()
	return workspace:GetAttribute("CM_Phase")
end
local function lastNote(kind)
	for i = #sentToClient, 1, -1 do
		local e = sentToClient[i]
		local payload = e.args[1]
		if e.player == human and type(payload) == "table" and payload.kind == kind then
			return payload
		end
	end
	return nil
end

step("full round, 1 human + 5 bots: Lobby -> Day -> Night -> Results -> Lobby", function()
	MatchService.setDurations({ lobby = 1, results = 2 }) -- real Day 60 s / Night 90 s
	MatchService.init()
	assert(phase() == "Lobby", "starts in lobby")
	MatchService.state().lastPhantoms = { P4242 = true } -- the human is a guest this round
	assert(run(2, function()
		return phase() == "Day"
	end), "no day")
	assert(BotService.count() == 5, "bots fill to 6: " .. BotService.count())
	assert(#Participants.all() == 6, "participants")
	assert(#Participants.phantoms() == 1, "1 Phantom at 6 players")
	local me = Participants.ofPlayer(human)
	assert(me and me.role == "Guest", "human not a guest")
	assert(human:GetAttribute("PState") == "Guest", "public PState")
	for _, p in Participants.phantoms() do
		assert(p.model:GetAttribute("PState") == "Guest", "Phantom identity leaked by day")
	end
	local role = lastNote("role")
	assert(role and role.role == "Guest", "role not told privately")
	assert(#ChestService.unopened() == Nights[1].chestCount, "chests stocked")
	local ok = run(61, function()
		if DEBUG_BAL then
			local ph = Participants.phantoms()[1]
			local pp = Participants.pos(ph)
			if math.floor((workspace:GetAttribute("CM_PhaseEndsAt") - Clock.now()) * 10 + 0.5) % 20 == 0 then
				print(string.format("day ph %.0f,%.0f dec %s path %d goal %s ch %s", pp.X, pp.Z, tostring(ph.lastDecision), #ph.path, ph.goal and string.format("%.0f,%.0f", ph.goal.x, ph.goal.z) or "-", tostring(GridService.channelling(ph))))
			end
		end
		return phase() == "Night"
	end)
	assert(ok, "no night")
	local chests = 0
	for _, p in Participants.all() do
		chests += p.stats.chests
	end
	print("       day: chests opened " .. chests .. ", tampers " .. GridService.state().tampers)
	assert(chests >= 3, "bots did not scavenge")
	assert(GridService.state().tampers == 1, "phantom bot did not tamper")
	assert(workspace:GetAttribute("CM_Tripped") ~= "", "no breaker tripped at night")
	assert(game:GetService("Lighting"):GetAttribute("Preset") == "Night", "night lighting")
	local ph = Participants.phantoms()[1]
	assert(ph.model:FindFirstChild("PhantomMask"), "no neon mask")
	assert(ph.model:GetAttribute("PState") == "Phantom", "phantom not revealed at night")
	ok = run(92, function()
		return phase() == "Results"
	end)
	assert(ok, "no results")
	local res = lastNote("results")
	assert(res and res.winner and res.tokens >= 5, "results not sent")
	print("       result: " .. res.winner .. " - " .. res.reason .. " (+" .. res.tokens .. " tokens)")
	local data = DataService.get(human)
	assert(data.Played == 1 and data.GearTokens == res.tokens, "save not updated")
	ok = run(3, function()
		return phase() == "Lobby"
	end)
	assert(ok, "no return to lobby")
	assert(BotService.count() == 0 and #Participants.all() == 0, "round not cleaned up")
	assert(human:GetAttribute("InMatch") == nil, "player still marked in match")
	local h = MatchService.history()
	assert(table.concat(h, ",") == "Lobby,Day,Night,Results,Lobby", table.concat(h, ","))
end)

-- ---- staged rules ----------------------------------------------------------
local function at(p, x, z)
	p.model:PivotTo(CFrame.new(x, 3, z))
end
local function bp(id)
	for _, s in Manor.Breakers do
		if s.id == id then
			local fx = if s.face == "E" then 3 elseif s.face == "W" then -3 else 0
			local fz = if s.face == "S" then 3 elseif s.face == "N" then -3 else 0
			return s.x + fx, s.z + fz
		end
	end
end
local G, P, W = nil, nil, nil
step("staged day: chest open, tamper channel (moving cancels, max 1 per night)", function()
	run(200, function()
		return phase() == "Lobby"
	end)
	MatchService.setDurations({ lobby = 0.5, day = 30, night = 90, results = 1 })
	MatchService.state().lastPhantoms = { P4242 = true }
	assert(run(1.5, function()
		return phase() == "Day"
	end), "no day")
	BotService.setPaused(true)
	P = Participants.phantoms()[1]
	G = Participants.ofPlayer(human)
	assert(G.role == "Guest" and P, "roles")
	-- chest
	local c = ChestService.unopened()[1]
	at(G, c.x + 1, c.z)
	local item = ChestService.open(G, c.id)
	assert(item, "chest refused")
	assert(ChestService.open(G, c.id) == nil, "chest opened twice")
	-- tamper: guest cannot, phantom can; moving cancels
	local x, z = bp("A")
	at(G, x, z)
	assert(GridService.beginTamper(G, "A") == false, "guest tampered")
	at(P, x, z)
	assert(GridService.beginTamper(P, "A"), "phantom tamper refused")
	run(1)
	at(P, x + 3, z)
	run(0.2)
	assert(GridService.channelling(P) == nil, "moving did not cancel")
	at(P, x, z)
	assert(GridService.beginTamper(P, "A"))
	run(4.2)
	assert(GridService.state().tampers == 1 and GridService.state().breakers.A.tampered, "tamper not done")
	local bx, bz = bp("B")
	at(P, bx, bz)
	assert(GridService.beginTamper(P, "B") == false, "second tamper allowed")
	assert(workspace:GetAttribute("CM_Tripped") == "", "tamper visible by day")
	assert(built.breakers.A.model:GetAttribute("Tripped") == false, "breaker shows tripped by day")
end)

step("staged night: transform, lantern beams slow (stacking, capped), cooperative repair", function()
	assert(run(31, function()
		return phase() == "Night"
	end), "no night")
	local gs = GridService.state()
	assert(built.breakers.A.model:GetAttribute("Tripped") == true, "breaker A did not trip: phase " .. tostring(phase()) .. " tampered " .. tostring(gs.breakers.A.tampered) .. " hist " .. table.concat(MatchService.history(), ","))
	run(Gadgets.Phantom.transformSeconds + 0.2)
	assert(P.transformed, "not transformed")
	-- lantern: human guest 15 studs in front of the Phantom
	at(P, 0, -10)
	at(G, 0, 5)
	assert(LanternService.setOn(G, true), "lantern refused")
	LanternService.setAim(G, 0, 0, -1)
	run(0.2)
	assert(LanternService.beamsOn(P.id) == 1, "beam not on phantom: " .. LanternService.beamsOn(P.id))
	local hum = Participants.humanoid(P)
	assert(math.abs(hum.WalkSpeed - Gadgets.Phantom.nightSpeed * (1 - Gadgets.Lantern.slowPerBeam)) < 0.1, "slow " .. hum.WalkSpeed)
	-- three more beams from bot guests: capped at -60%
	local n = 0
	for _, g in Participants.guests(true) do
		if g ~= G and n < 3 then
			n += 1
			at(g, n * 2, 5)
			LanternService.setOn(g, true)
			LanternService.setAim(g, -n * 2, 0, -15)
		end
	end
	run(0.2)
	assert(LanternService.beamsOn(P.id) >= 3, "beams " .. LanternService.beamsOn(P.id))
	assert(math.abs(hum.WalkSpeed - Gadgets.Phantom.nightSpeed * (1 - Gadgets.Lantern.slowCap)) < 0.1, "cap " .. hum.WalkSpeed)
	-- bad aim is ignored (keeps the last good one)
	LanternService.setAim(G, 0 / 0, 0, 1)
	assert(G.aim.Z < 0, "NaN aim accepted")
	for _, g in Participants.guests(true) do
		LanternService.setOn(g, false)
	end
	-- repair: alone 6 s; two guests together faster
	local x, z = bp("A")
	at(G, x, z)
	assert(GridService.beginRepair(G, "A"), "repair refused")
	run(3)
	assert(GridService.state().breakers.A.tampered, "repaired too early")
	local mate
	for _, g in Participants.guests(true) do
		if g ~= G then
			mate = g
			break
		end
	end
	at(mate, x + 0.5, z)
	assert(GridService.beginRepair(mate, "A"))
	run(1.6)
	assert(not GridService.state().breakers.A.tampered, "coop repair did not finish")
	assert(G.stats.repairs == 1, "repair stat")
	assert(GridService.state().reboot > 0, "reboot not ticking")
end)

step("staged tag -> Energy Bubble -> Electro-Wisp; flicker cd; slick cap; wisps cannot tag", function()
	at(P, 0, 0)
	at(G, 3, 0)
	assert(ChaseService.tryTag(P, nil), "tag refused in range")
	assert(G.state == "Bubble" and human:GetAttribute("PState") == "Bubble", "no bubble")
	assert(ChaseService.tryTag(P, nil) == false, "tag cooldown ignored")
	local far
	for _, g in Participants.guests(true) do
		far = g
	end
	at(far, 40, 0)
	run(Gadgets.Phantom.tagCooldown + 0.1)
	assert(ChaseService.tryTag(P, far.id) == false, "tagged from 37 studs")
	run(Gadgets.Bubble.seconds)
	assert(G.state == "Wisp", "no wisp: " .. tostring(G.state))
	assert(G.model:FindFirstChild("WispOrb"), "no wisp orb")
	assert(ChaseService.tryTag(G, nil) == false, "wisp tagged")
	-- flicker (cooldown 20 s)
	at(G, 0, 0)
	assert(ChaseService.flicker(G), "flicker refused")
	assert(ChaseService.flicker(G) == false, "flicker cooldown ignored")
	-- slicks: cooldown 30 s, max 2 alive
	assert(ChaseService.slick(G), "slick refused")
	assert(ChaseService.slick(G) == false, "slick cooldown ignored")
	BotService.setPaused(true)
	local g2
	for _, g in Participants.guests(true) do
		g2 = g
	end
	-- park everyone else far away so nothing else happens
	for _, q in Participants.all() do
		if q ~= G then
			at(q, -60, 30)
		end
	end
	-- keep the night going (reboot frozen) while we wait out the slick cooldowns
	local grid = GridService.state()
	grid.reboot = 0
	Clock.advance(Gadgets.Wisp.slickCooldown + 0.1)
	at(G, 10, 0)
	assert(ChaseService.slick(G), "second slick refused")
	Clock.advance(Gadgets.Wisp.slickCooldown + 0.1)
	at(G, 20, 0)
	local third = ChaseService.slick(G)
	if Gadgets.Wisp.slickLifetime > 2 * Gadgets.Wisp.slickCooldown then
		assert(third == false, "third slick while 2 alive")
	end
	-- guest crossing a slick is slowed; phantoms are not
	local s1 = ChaseService.slicks()[#ChaseService.slicks()]
	at(g2, s1.x, s1.z)
	MatchService.step(0.1)
	assert(Participants.humanoid(g2).WalkSpeed < Gadgets.Guest.walkSpeed, "slick did not slow guest")
	at(P, s1.x, s1.z)
	MatchService.step(0.1)
	assert(Participants.humanoid(P).WalkSpeed >= Gadgets.Phantom.nightSpeed * 0.99, "slick slowed the phantom")
end)

step("remotes: server validates intent + rate limits", function()
	local remote = game:GetService("ReplicatedStorage").Remotes.Action
	local sig = fakeSignal(remote, "OnServerEvent")
	-- a Wisp cannot light a lantern
	sig:Fire(human, "lantern", true)
	assert(G.lanternOn ~= true, "wisp lantern")
	-- junk is ignored
	sig:Fire(human, 42, {})
	sig:Fire(human, "explode")
	-- spam: at most the burst gets through
	local before = G.lastFlicker
	local okCount = 0
	for _ = 1, 30 do
		if Net.allowAction(human) then
			okCount += 1
		end
	end
	assert(okCount <= 8, "rate limit let " .. okCount .. " through")
	assert(G.lastFlicker == before, "flicker fired during cooldown")
end)

step("win: 100% reboot with a guest untagged -> Guests; all tagged -> Phantoms", function()
	local grid = GridService.state()
	grid.reboot = 99.99
	MatchService.step(0.1)
	assert(phase() == "Results", "no results at 100%")
	assert(workspace:GetAttribute("CM_Winner") == "Guests", "winner " .. tostring(workspace:GetAttribute("CM_Winner")))
	assert(run(2, function()
		return phase() == "Lobby"
	end))
	-- next round: tag everyone
	MatchService.setDurations({ lobby = 0.5, day = 1, night = 90, results = 1 })
	MatchService.state().lastPhantoms = {}
	assert(run(1.5, function()
		return phase() == "Day"
	end))
	BotService.setPaused(true)
	assert(run(2, function()
		return phase() == "Night"
	end))
	run(Gadgets.Phantom.transformSeconds + 0.2)
	local ph = Participants.phantoms()[1]
	for _, g in Participants.guests(true) do
		at(ph, 0, 0)
		at(g, 2, 0)
		Clock.advance(Gadgets.Phantom.tagCooldown + 0.05)
		assert(ChaseService.tryTag(ph, g.id), "tag " .. g.name)
		MatchService.step(0.1)
		if phase() == "Results" then
			break
		end
	end
	assert(workspace:GetAttribute("CM_Winner") == "Phantoms", "winner " .. tostring(workspace:GetAttribute("CM_Winner")))
	BotService.setPaused(false)
	assert(run(2, function()
		return phase() == "Lobby"
	end))
end)

step("bot-only rounds (no humans) play out with live brains, 6 rounds", function()
	table.remove(fakePlayers, table.find(fakePlayers, human))
	local results = {}
	local nightLeft
	for round = 1, 6 do
		MatchService.setDurations({ lobby = 0.5, results = 1 })
		assert(run(1.5, function()
			return phase() == "Day"
		end))
		assert(BotService.count() == 6, "bots " .. BotService.count())
		nightLeft = nil
		assert(run(155, function()
			if phase() == "Night" then
				nightLeft = workspace:GetAttribute("CM_PhaseEndsAt") - Clock.now()
				if DEBUG_BAL and round == 1 and math.floor(nightLeft * 10 + 0.5) % 10 == 0 then
					local ph = Participants.phantoms()[1]
					local pp = Participants.pos(ph)
					local parts = {}
					for _, g in Participants.guests(false) do
						local gp = Participants.pos(g)
						table.insert(parts, string.format("%s:%s (%.0f,%.0f) d%.0f b%.0f %s %s g%s", g.name:sub(1, 4), g.state:sub(1, 1), gp.X, gp.Z, (gp - pp).Magnitude, g.battery or 0, if g.lanternOn then "L" else "-", tostring(g.lastDecision), g.goal and string.format("%.0f,%.0f", g.goal.x, g.goal.z) or "-"))
					end
					print(string.format("t%.0f ph (%.0f,%.0f) spd %.1f beams %d dec %s | %s", nightLeft, pp.X, pp.Z, Participants.humanoid(ph).WalkSpeed, LanternService.beamsOn(ph.id), tostring(ph.lastDecision), table.concat(parts, " | ")))
				end
			end
			return phase() == "Results"
		end), "round " .. round .. " did not finish")
		local gs = GridService.state()
		local tags, reps = 0, 0
		for _, q in Participants.all() do
			tags += q.stats.tags
			reps += q.stats.repairs
		end
		table.insert(results, string.format("%s (%s) - reboot %d%%, repairs %d, tags %d, night left %.0f s",
			workspace:GetAttribute("CM_Winner"), workspace:GetAttribute("CM_Reason"), gs.reboot, reps, tags,
			nightLeft or -1))
		assert(run(2, function()
			return phase() == "Lobby"
		end))
	end
	print("       bot rounds (speed-true walking, no walls):\n         " .. table.concat(results, "\n         "))
end)

step("7+ participants -> 2 Phantoms", function()
	local Roles = requireModule(Shared.Logic.Roles)
	local Match = requireModule(Shared.Config.Match)
	assert(Roles.phantomCount(7, Match.PhantomTable) == 2 and Roles.phantomCount(10, Match.PhantomTable) == 2)
end)

-- ---- client --------------------------------------------------------------------------------
local Hud, localPlayer
step("client HUD builds and lays out on 780x360, 891x411, 2340x1080, tablet, desktop", function()
	localPlayer = Instance.new("Player")
	localPlayer.Name = "Phone"
	local playerGui = Instance.new("PlayerGui")
	playerGui.Parent = localPlayer
	local playersProxy = { LocalPlayer = localPlayer }
	envOverrides.game = {
		GetService = function(_, name)
			if name == "Players" then
				return playersProxy
			end
			return game:GetService(name)
		end,
	}
	envOverrides.workspace = clientWorkspace
	Hud = requireModule(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud)
	envOverrides.game = nil
	envOverrides.workspace = nil
	Hud.build(playerGui)
	local el = Hud.elements()
	for _, vp in HudLayout.TestViewports do
		local L = Hud.applyLayout(vp.w, vp.h, vp.touch)
		-- read the rects back off the built instances
		local read = { el = {}, modal = L.modal, touch = vp.touch }
		for name in L.el do
			local o = el[name]
			assert(o, "missing HUD element " .. name)
			read.el[name] = { x = o.Position.X.Offset, y = o.Position.Y.Offset, w = o.Size.X.Offset, h = o.Size.Y.Offset }
		end
		local problems = HudLayout.validate(read, vp.w, vp.h)
		assert(#problems == 0, vp.name .. ": " .. table.concat(problems, "; "))
		local t = read.el.Timer
		assert(math.abs(t.x + t.w / 2 - vp.w / 2) <= 1 and t.y <= 6, vp.name .. " timer not top centre")
	end
end)

step("client HUD states: lobby, guest day/night, phantom, wisp, results", function()
	local el, modal = Hud.elements()
	local State = requireModule(game:GetService("StarterPlayer").StarterPlayerScripts.Client.State)
	workspace:SetAttribute("CM_Phase", "Lobby")
	Hud.update()
	assert(el.RoleChip.Text.Text == "TERRACE", "lobby chip " .. el.RoleChip.Text.Text)
	assert(not el.Button1.Visible, "buttons in lobby")
	localPlayer:SetAttribute("InMatch", true)
	localPlayer:SetAttribute("PState", "Guest")
	State.role = "Guest"
	workspace:SetAttribute("CM_Phase", "Night")
	localPlayer:SetAttribute("DryCell", 2)
	localPlayer:SetAttribute("Battery", 12)
	Hud.update()
	assert(el.Button1.Visible and el.Button1.Text == "LAMP", "lantern button")
	assert(el.Button2.Text == "CELL 2", "cell button")
	assert(el.Reboot.Visible, "reboot meter hidden at night")
	assert(string.find(el.Battery.Text.Text, "12"), "battery text")
	State.role = "Phantom"
	localPlayer:SetAttribute("PState", "Phantom")
	Hud.update()
	assert(el.Button1.Text == "TAG" and not el.Button2.Visible, "phantom buttons")
	assert(el.RoleChip.Text.Text == "PHANTOM")
	localPlayer:SetAttribute("PState", "Wisp")
	Hud.update()
	assert(el.Button1.Text == "FLICKER" and el.Button2.Text == "SLICK", "wisp buttons")
	State.results = { winner = "Guests", reason = "Grid rebooted - dawn!", won = false, tokens = 7, roster = { { name = "Cogsworth", role = "Phantom" } } }
	workspace:SetAttribute("CM_Phase", "Results")
	Hud.update()
	assert(modal.Results.Visible and modal.Results.Title.Text == "GUESTS WIN", "results card")
	assert(string.find(modal.Results.Roster.Text, "Cogsworth"), "phantoms not revealed on results")
	Hud.showRole("Phantom", { "Ivy" })
	workspace:SetAttribute("CM_Phase", "Day")
	Hud.update()
	assert(modal.RoleCard.Visible and string.find(modal.RoleCard.Sub.Text, "Ivy"), "role card")
end)

step("prompt filter: tamper only for Phantoms by day, repair only on tripped breakers at night", function()
	local PF = requireModule(game:GetService("StarterPlayer").StarterPlayerScripts.Client.PromptFilter)
	local a = built.breakers.A.prompt
	local tamper, repair = a:FindFirstChild("Tamper"), a:FindFirstChild("Repair")
	assert(tamper and repair, "breaker prompts")
	assert(PF.allowed(tamper, "Day", "Phantom", "Guest"))
	assert(not PF.allowed(tamper, "Day", "Guest", "Guest"))
	assert(not PF.allowed(tamper, "Night", "Phantom", "Phantom"))
	built.breakers.A.model:SetAttribute("Tripped", false)
	assert(not PF.allowed(repair, "Night", "Guest", "Guest"))
	built.breakers.A.model:SetAttribute("Tripped", true)
	assert(PF.allowed(repair, "Night", "Guest", "Guest"))
	assert(not PF.allowed(repair, "Night", "Guest", "Wisp"))
	built.breakers.A.model:SetAttribute("Tripped", false)
end)

step("music: Lobby -> Day keeps the same track playing, Night switches, Results fades out", function()
	local SM = requireModule(game:GetService("StarterPlayer").StarterPlayerScripts.Client.SoundManager)
	SM.init()
	SM.setPhase("Lobby")
	local before = #soundLog
	SM.setPhase("Day")
	for i = before + 1, #soundLog do
		assert(soundLog[i].call ~= "Stop" and soundLog[i].call ~= "Play", "lobby track restarted on Day")
	end
	assert(SM.current() == "Day")
	SM.setPhase("Night")
	assert(SM.current() == "Night")
	SM.setPhase("Results")
	assert(SM.current() == nil)
	SM.sfx("Win")
end)

print(string.format("\nEngine smoke: %d failure(s)", failures))
process.exit(if failures == 0 then 0 else 1)
