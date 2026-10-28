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
		-- climbs/descends with the target's y (stairs) at the same rate it closes the distance
		local to
		if d <= stepLen or d < 1e-3 then
			to = Vector3.new(point.X, point.Y, point.Z)
		else
			local f = stepLen / d
			to = Vector3.new(from.X + flat.X * f, from.Y + (point.Y - from.Y) * f, from.Z + flat.Z * f)
		end
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
local ManorLayout = requireModule(Shared.Logic.ManorLayout)
local Coplanar = requireModule(Shared.Logic.Coplanar)
local Items = requireModule(Shared.Config.Items)
local Gadgets = requireModule(Shared.Config.Gadgets)
local Nights = requireModule(Shared.Config.Nights)
local HudLayout = requireModule(Shared.Logic.HudLayout)
local DEBUG_BAL = process.env.DEBUG_BAL == "1"

local ManorBuilder, LightingService, MatchService, BotService, GridService, ChaseService
local LanternService, ChestService, Participants, Clock, DataService, Net, ItemService, LiftService
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
	ItemService = requireModule(Server.ItemService)
	LiftService = requireModule(Server.LiftService)
	Net = requireModule(Server.Net)
end)

local built
step("ManorBuilder: 3-floor manor (35+ rooms), 5 breakers on all floors, lights, lift, lobby", function()
	built = ManorBuilder.build()
	local map = workspace:FindFirstChild("Map")
	assert(map and map:FindFirstChild("Manor") and map:FindFirstChild("Lobby"), "map missing")
	local rooms = map.Manor.Rooms:GetChildren()
	assert(#rooms == #Manor.Rooms, "rooms " .. #rooms)
	for _, r in Manor.Rooms do
		assert(built.roomLights[r.id] and #built.roomLights[r.id] >= 1, "no lights in " .. r.id)
	end
	local floors = {}
	for _, id in { "A", "B", "C", "D", "E" } do
		local b = built.breakers[id]
		assert(b and b.model.Parent, "breaker " .. id)
		floors[b.level] = true
	end
	assert(floors[-1] and floors[0] and floors[1], "breakers not on all 3 floors")
	local lifts = 0
	for _ in built.lifts do
		lifts += 1
	end
	assert(lifts == 3, "lift stops " .. lifts)
	local plates = 0
	for _, d in map:GetDescendants() do
		if d:IsA("SurfaceGui") and d.Parent and d.Parent.Name == "NamePlate" then
			plates += 1
		end
	end
	assert(plates == 2 * #Manor.Doors, "room name plates " .. plates)
	assert(map.Lobby:FindFirstChild("LobbySpawn"), "no lobby spawn")
	local parts = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print("       map parts: " .. parts .. " (" .. #Manor.Rooms .. " rooms, " .. #Manor.Doors .. " doors, " .. #ManorLayout.chestSpots(Manor) .. " chest spots)")
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

-- Collect every anchored, visible block (and cylinder caps) in a folder as axis-aligned boxes.
local function boxesOf(root)
	local boxes, guis, skipped = {}, {}, 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored and d.Transparency < 0.99 then
			local cf = d.CFrame
			local R = { cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z }
			local U = { cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z }
			local B = { -cf.LookVector.X, -cf.LookVector.Y, -cf.LookVector.Z }
			local shape = if d:IsA("Part") then d.Shape else roblox.Enum.PartType.Block
			local sz = d.Size
			local b = nil
			if shape == roblox.Enum.PartType.Block then
				b = Coplanar.alignedBox(d:GetFullName(), cf.Position.X, cf.Position.Y, cf.Position.Z, sz.X, sz.Y, sz.Z, R, U, B)
			elseif shape == roblox.Enum.PartType.Cylinder then
				-- caps as their inscribed squares (axis = local X)
				local side = math.min(sz.Y, sz.Z) * 0.7071
				b = Coplanar.alignedBox(d:GetFullName(), cf.Position.X, cf.Position.Y, cf.Position.Z, sz.X, side, side, R, U, B)
			end
			if b then
				table.insert(boxes, b)
				local faces = {}
				for _, g in d:GetChildren() do
					if g:IsA("SurfaceGui") or g:IsA("Decal") then
						local wf = Coplanar.worldFace(g.Face.Name, R, U, B)
						if wf then
							table.insert(faces, wf)
						end
					end
				end
				if #faces > 0 then
					guis[#boxes] = faces
				end
			else
				skipped += 1
			end
		end
	end
	return boxes, guis, skipped
end

step("no z-fighting: no coplanar overlapping faces between anchored parts (incl. SurfaceGui faces)", function()
	local boxes, guis, skipped = boxesOf(workspace.Map)
	local probs = Coplanar.find(boxes, 0.01, 0.02, guis)
	local nGui = 0
	for _ in guis do
		nGui += 1
	end
	print(string.format("       %d boxes checked (%d rotated parts skipped, %d with GUI faces): %d problems", #boxes, skipped, nGui, #probs))
	if #probs > 0 then
		local lines = {}
		for i = 1, math.min(6, #probs) do
			local p = probs[i]
			table.insert(lines, string.format("%s vs %s (axis %d @ %.2f%s)", boxes[p.a].name, boxes[p.b].name, p.axis, p.plane, if p.gui then ", GUI face" else ""))
		end
		error(#probs .. " coplanar faces:\n         " .. table.concat(lines, "\n         "))
	end
	assert(#boxes > 1000, "too few boxes " .. #boxes)
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

step("full round, 1 human + 5 bots: Lobby -> Day (150 s) -> Night (240 s) -> Results -> Lobby", function()
	MatchService.setDurations({ lobby = 1, results = 2 }) -- real Day 150 s / Night 240 s
	MatchService.init()
	assert(phase() == "Lobby", "starts in lobby")
	MatchService.state().lastPhantoms = { P4242 = true } -- the human is a guest this round
	assert(run(2, function()
		return phase() == "Day"
	end), "no day")
	local dayLeft = workspace:GetAttribute("CM_PhaseEndsAt") - Clock.now()
	assert(dayLeft > 140 and dayLeft <= 150.1, "day length " .. dayLeft)
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
	assert(#ChestService.unopened() == Nights[1].chestCount, "chests stocked " .. #ChestService.unopened())
	local ok = run(151, function()
		return phase() == "Night"
	end)
	assert(ok, "no night")
	local chests = 0
	for _, p in Participants.all() do
		chests += p.stats.chests
	end
	print("       day: chests opened " .. chests .. ", tampers " .. GridService.state().tampers)
	assert(chests >= 6, "bots did not scavenge")
	assert(GridService.state().tampers >= 1, "phantom bot did not tamper")
	assert(workspace:GetAttribute("CM_Tripped") ~= "", "no breaker tripped at night")
	assert(game:GetService("Lighting"):GetAttribute("Preset") == "Night", "night lighting")
	local nightLeft = workspace:GetAttribute("CM_PhaseEndsAt") - Clock.now()
	assert(nightLeft > 230 and nightLeft <= 240.1, "night length " .. nightLeft)
	local ph = Participants.phantoms()[1]
	assert(ph.model:FindFirstChild("PhantomMask"), "no neon mask")
	assert(ph.model:GetAttribute("PState") == "Phantom", "phantom not revealed at night")
	ok = run(242, function()
		return phase() == "Results"
	end)
	assert(ok, "no results")
	local res = lastNote("results")
	assert(res and res.winner and res.tokens >= Gadgets.Rewards.played, "results not sent")
	print("       result: " .. res.winner .. " - " .. res.reason .. " (+" .. res.tokens .. " tokens)")
	local data = DataService.get(human)
	assert(data.Played == 1 and data.GearTokens == res.tokens, "save not updated")
	ok = run(3, function()
		return phase() == "Lobby"
	end)
	assert(ok, "no return to lobby")
	assert(BotService.count() == 0 and #Participants.all() == 0, "round not cleaned up")
	assert(human:GetAttribute("InMatch") == nil, "player still marked in match")
	assert(human:GetAttribute("SmokePellet") == nil and human:GetAttribute("ReadyAt_PocketWatch") == nil, "item attributes not cleared")
	local h = MatchService.history()
	assert(table.concat(h, ",") == "Lobby,Day,Night,Results,Lobby", table.concat(h, ","))
end)

-- ---- staged rules ----------------------------------------------------------
local RH = ManorLayout.RootHeight
local function at(p, x, z, y)
	p.model:PivotTo(CFrame.new(x, y or 3, z))
end
local specs = {}
for _, s in ManorLayout.breakers(Manor) do
	specs[s.id] = s
end
-- stand point in front of a breaker: x, z, y (root height on its floor)
local function bp(id)
	local s = specs[id]
	return s.standX, s.standZ, s.y + RH
end
local function give(p, item, n)
	p.inv[item] = n
	Participants.set(p, item, n)
end
local G, P, W = nil, nil, nil
step("staged day: chest open, tamper channel (moving cancels, 2 per night, floors matter)", function()
	run(400, function()
		return phase() == "Lobby"
	end)
	MatchService.setDurations({ lobby = 0.5, day = 30, night = 240, results = 1 })
	MatchService.state().lastPhantoms = { P4242 = true }
	assert(run(1.5, function()
		return phase() == "Day"
	end), "no day")
	BotService.setPaused(true)
	P = Participants.phantoms()[1]
	G = Participants.ofPlayer(human)
	assert(G.role == "Guest" and P, "roles")
	-- chest (on its own floor only)
	local c = ChestService.unopened()[1]
	at(G, c.x + 1, c.z, c.y + 3 + Manor.LevelHeight)
	assert(ChestService.open(G, c.id) == nil, "opened a chest one floor away")
	at(G, c.x + 1, c.z, c.y + 3)
	local item = ChestService.open(G, c.id)
	assert(item, "chest refused")
	assert(ChestService.open(G, c.id) == nil, "chest opened twice")
	-- tamper: guest cannot, phantom can; moving cancels; the wrong floor is out of range
	local x, z, y = bp("A")
	at(G, x, z, y)
	assert(GridService.beginTamper(G, "A") == false, "guest tampered")
	at(P, x, z, y + Manor.LevelHeight)
	assert(GridService.beginTamper(P, "A") == false, "tampered from the floor above")
	at(P, x, z, y)
	assert(GridService.beginTamper(P, "A"), "phantom tamper refused")
	run(1)
	at(P, x + 3, z, y)
	run(0.2)
	assert(GridService.channelling(P) == nil, "moving did not cancel")
	at(P, x, z, y)
	assert(GridService.beginTamper(P, "A"))
	run(4.2)
	assert(GridService.state().tampers == 1 and GridService.state().breakers.A.tampered, "tamper not done")
	local bx, bz, by = bp("B")
	at(P, bx, bz, by)
	assert(GridService.beginTamper(P, "B"), "second tamper refused (2 per night)")
	run(4.2)
	assert(GridService.state().tampers == 2, "second tamper not done")
	local cx, cz, cy = bp("C")
	at(P, cx, cz, cy)
	assert(GridService.beginTamper(P, "C") == false, "third tamper allowed")
	assert(workspace:GetAttribute("CM_Tripped") == "", "tamper visible by day")
	assert(built.breakers.A.model:GetAttribute("Tripped") == false, "breaker shows tripped by day")
end)

step("items by day: boots (anyone who looks like a guest), pocket watch, bell; night-only refused", function()
	at(G, 0, 10, 3)
	give(G, "SpringBoots", 2)
	assert(ItemService.use(G, "SpringBoots"), "boots refused")
	MatchService.step(0.1)
	assert(Participants.humanoid(G).WalkSpeed > Gadgets.Guest.walkSpeed * 1.4, "no boots burst " .. Participants.humanoid(G).WalkSpeed)
	assert(G.inv.SpringBoots == 1 and human:GetAttribute("SpringBoots") == 1, "boots not consumed")
	assert(ItemService.use(G, "SpringBoots") == false, "boots cooldown ignored")
	-- a disguised Phantom can use day items too (items never reveal the role)
	give(P, "SpringBoots", 1)
	assert(ItemService.use(P, "SpringBoots"), "disguised phantom could not use boots by day")
	give(G, "PocketWatch", 1)
	local before = #sentToClient
	assert(ItemService.use(G, "PocketWatch"), "watch refused")
	local saw = false
	for i = before + 1, #sentToClient do
		local pl = sentToClient[i].args[1]
		if sentToClient[i].player == human and type(pl) == "table" and pl.kind == "watch" then
			saw = pl.tampered == 2
		end
	end
	assert(saw, "watch did not report 2 tampers")
	assert(G.inv.PocketWatch == 1, "watch should not be used up")
	assert(ItemService.use(G, "PocketWatch") == false, "watch cooldown ignored")
	give(G, "SmokePellet", 1)
	assert(ItemService.use(G, "SmokePellet") == false, "smoke used by day")
	give(G, "TripwireBell", 2)
	local bx, bz, by = bp("D")
	at(G, bx, bz, by)
	assert(ItemService.use(G, "TripwireBell"), "bell refused")
	assert(#ItemService.bells() == 1 and G.inv.TripwireBell == 1, "bell not placed")
	assert(ItemService.use(G, "Nope") == false and ItemService.use(G, 42) == false, "bad item id accepted")
	-- everyone loots the same table: a Phantom's counters look like a guest's
	assert(P.model:GetAttribute("SpringBoots") == 0, "phantom item counter missing")
end)

step("staged night: transform, lantern beams slow (stacking, capped), repair (wire, wrench, coop)", function()
	assert(run(31, function()
		return phase() == "Night"
	end), "no night")
	local gs = GridService.state()
	assert(built.breakers.A.model:GetAttribute("Tripped") == true and built.breakers.B.model:GetAttribute("Tripped") == true, "breakers A+B did not trip: tampered " .. tostring(gs.breakers.A.tampered))
	run(Gadgets.Phantom.transformSeconds + 0.2)
	assert(P.transformed, "not transformed")
	give(P, "SpringBoots", 1)
	assert(ItemService.use(P, "SpringBoots") == false, "unmasked phantom used guest items")
	-- lantern: human guest 15 studs in front of the Phantom
	at(P, 0, -10, 3)
	at(G, 0, 5, 3)
	assert(LanternService.setOn(G, true), "lantern refused")
	LanternService.setAim(G, 0, 0, -1)
	run(0.2)
	assert(LanternService.beamsOn(P.id) == 1, "beam not on phantom: " .. LanternService.beamsOn(P.id))
	local hum = Participants.humanoid(P)
	assert(math.abs(hum.WalkSpeed - Gadgets.Phantom.nightSpeed * (1 - Gadgets.Lantern.slowPerBeam)) < 0.1, "slow " .. hum.WalkSpeed)
	-- a Phantom one floor up is not in the beam
	at(P, 0, -10, 3 + Manor.LevelHeight)
	run(0.2)
	assert(LanternService.beamsOn(P.id) == 0, "beam went through the floor")
	at(P, 0, -10, 3)
	local n = 0
	for _, g in Participants.guests(true) do
		if g ~= G and n < 3 then
			n += 1
			at(g, n * 2, 5, 3)
			LanternService.setOn(g, true)
			LanternService.setAim(g, -n * 2, 0, -15)
		end
	end
	run(0.2)
	assert(LanternService.beamsOn(P.id) >= 3, "beams " .. LanternService.beamsOn(P.id))
	assert(math.abs(hum.WalkSpeed - Gadgets.Phantom.nightSpeed * (1 - Gadgets.Lantern.slowCap)) < 0.1, "cap " .. hum.WalkSpeed)
	LanternService.setAim(G, 0 / 0, 0, 1)
	assert(G.aim.Z < 0, "NaN aim accepted")
	for _, g in Participants.guests(true) do
		LanternService.setOn(g, false)
	end
	-- dry-cell through the item system
	G.battery = 10
	give(G, "DryCell", 1)
	assert(ItemService.use(G, "DryCell"), "cell refused")
	assert(math.abs(G.battery - (10 + Gadgets.Lantern.dryCellCharge)) < 0.01 and G.inv.DryCell == 0, "cell")
	-- repair times: alone 8 s, wire 4 s, wrench x0.6
	local N1 = Nights[1]
	assert(GridService.repairTime(G) == N1.repairSeconds, "base repair time")
	give(G, "BrassWrench", 1)
	assert(math.abs(GridService.repairTime(G) - N1.repairSeconds * Items.Wrench.repairFactor) < 1e-6, "wrench")
	give(G, "CopperWire", 1)
	assert(math.abs(GridService.repairTime(G) - N1.repairSecondsWithWire * Items.Wrench.repairFactor) < 1e-6, "wire + wrench")
	give(G, "CopperWire", 0)
	give(G, "BrassWrench", 0)
	-- cooperative repair of A (basement)
	local x, z, y = bp("A")
	at(G, x, z, y)
	assert(GridService.beginRepair(G, "A"), "repair refused")
	run(4)
	assert(GridService.state().breakers.A.tampered, "repaired too early")
	local mate
	for _, g in Participants.guests(true) do
		if g ~= G then
			mate = g
			break
		end
	end
	at(mate, x + 0.5, z, y)
	assert(GridService.beginRepair(mate, "A"))
	run(2.2)
	assert(not GridService.state().breakers.A.tampered, "coop repair did not finish")
	assert(G.stats.repairs == 1, "repair stat")
	assert(GridService.state().reboot > 0, "reboot not ticking")
end)

step("items by night: smoke blink + immunity, decoy takes a tag, bell rings, glow-stick", function()
	-- glow-stick
	BotService.setPaused(true)
	at(G, 0, 10, 3)
	give(G, "GlowStick", 1)
	assert(ItemService.use(G, "GlowStick"), "glow refused")
	-- smoke: blink forward (no walls in the smoke shim's raycast) + tag immunity
	at(P, 0, 0, 3)
	at(G, 3, 0, 3)
	give(G, "SmokePellet", 1)
	local before = Participants.pos(G)
	assert(ItemService.use(G, "SmokePellet", { dir = Vector3.new(1, 0, 0) }), "smoke refused")
	local after = Participants.pos(G)
	assert((after - before).Magnitude > 10, "no blink")
	for _, q in Participants.guests(true) do
		if q ~= G then
			at(q, -75, 15, 3) -- everyone else out of the way (billiard room)
		end
	end
	at(G, 3, 0, 3) -- even back in range ...
	P.lastTag = nil
	assert(ChaseService.tryTag(P, nil) == false, "tagged during smoke immunity")
	Clock.advance(Items.Smoke.immuneSeconds + 0.1)
	-- decoy: closer than the guest, it takes the tag
	at(G, 5, 0, 3)
	G.model:PivotTo(CFrame.lookAt(Vector3.new(5, 3, 0), Vector3.new(0, 3, 0)))
	give(G, "ClockworkDecoy", 1)
	assert(ItemService.use(G, "ClockworkDecoy"), "decoy refused")
	assert(#ItemService.decoys() == 1, "no decoy")
	local dc = ItemService.decoys()[1]
	at(P, dc.x - 1, dc.z, 3)
	at(G, dc.x - 6, dc.z, 3)
	assert(ChaseService.tryTag(P, nil), "decoy not tagged")
	assert(G.state == "Guest" and #ItemService.decoys() == 0, "decoy did not take the tag")
	-- tripwire bell (set by day at breaker D) rings when the unmasked Phantom passes
	local bell = ItemService.bells()[1]
	assert(bell, "bell gone")
	local toasts = #sentToClient
	at(P, bell.x + 2, bell.z, bell.y)
	MatchService.step(0.1)
	local rang = false
	for i = toasts + 1, #sentToClient do
		local pl = sentToClient[i].args[1]
		if type(pl) == "table" and pl.kind == "toast" and string.find(pl.text, "tripwire bell") then
			rang = true
		end
	end
	assert(rang and (bell.rings or 0) >= 1, "bell did not ring")
	assert(workspace:GetAttribute("CM_BellAt") ~= nil, "bell not on the minimap")
end)

step("service lift: one floor at a time, only from a stop, cooldown; bots ride it on routes", function()
	local liftG = ManorLayout.ids(Manor).liftG
	local lx, lz = ManorLayout.centre(liftG)
	at(G, lx, lz, 3)
	assert(LiftService.ride(G, 1), "lift up refused")
	assert(math.abs(Participants.pos(G).Y - (3 + Manor.LevelHeight)) < 0.01, "lift did not go up")
	assert(LiftService.ride(G, 0) == false, "lift cooldown ignored")
	Clock.advance(LiftService.Cooldown + 0.1)
	assert(LiftService.ride(G, -1) == false, "skipped a floor")
	assert(LiftService.ride(G, 0) and LiftService.ride(G, -1) == false, "lift down")
	Clock.advance(LiftService.Cooldown + 0.1)
	at(G, 0, 0, 3)
	assert(LiftService.ride(G, 1) == false, "rode the lift from the ballroom")
	assert(#built.lifts.liftG.prompt:GetChildren() >= 2, "lift prompts")
end)

step("staged tag -> Energy Bubble -> Electro-Wisp; flicker cd; slick cap; wisps cannot tag", function()
	Clock.advance(Gadgets.Phantom.tagCooldown + 0.1)
	at(P, 0, 0, 3)
	at(G, 3, 0, 3)
	assert(ChaseService.tryTag(P, nil), "tag refused in range")
	assert(G.state == "Bubble" and human:GetAttribute("PState") == "Bubble", "no bubble")
	assert(ChaseService.tryTag(P, nil) == false, "tag cooldown ignored")
	local far
	for _, g in Participants.guests(true) do
		far = g
	end
	at(far, 40, 0, 3)
	run(Gadgets.Phantom.tagCooldown + 0.1)
	assert(ChaseService.tryTag(P, far.id) == false, "tagged from 37 studs")
	at(far, 3, 0, 3 + Manor.LevelHeight)
	assert(ChaseService.tryTag(P, far.id) == false, "tagged through the ceiling")
	run(Gadgets.Bubble.seconds)
	assert(G.state == "Wisp", "no wisp: " .. tostring(G.state))
	assert(G.model:FindFirstChild("WispOrb"), "no wisp orb")
	assert(ChaseService.tryTag(G, nil) == false, "wisp tagged")
	assert(ItemService.use(G, "SpringBoots") == false, "wisp used an item")
	at(G, 0, 0, 3)
	assert(ChaseService.flicker(G), "flicker refused")
	assert(ChaseService.flicker(G) == false, "flicker cooldown ignored")
	assert(ChaseService.slick(G), "slick refused")
	assert(ChaseService.slick(G) == false, "slick cooldown ignored")
	BotService.setPaused(true)
	local g2
	for _, g in Participants.guests(true) do
		g2 = g
	end
	for _, q in Participants.all() do
		if q ~= G then
			at(q, -75, 15, 3)
		end
	end
	local grid = GridService.state()
	grid.reboot = 0
	Clock.advance(Gadgets.Wisp.slickCooldown + 0.1)
	at(G, 10, 0, 3)
	assert(ChaseService.slick(G), "second slick refused")
	Clock.advance(Gadgets.Wisp.slickCooldown + 0.1)
	at(G, 20, 0, 3)
	assert(ChaseService.slick(G) == false, "third slick while 2 alive")
	local s1 = ChaseService.slicks()[#ChaseService.slicks()]
	at(g2, s1.x, s1.z, 3)
	MatchService.step(0.1)
	assert(Participants.humanoid(g2).WalkSpeed < Gadgets.Guest.walkSpeed, "slick did not slow guest")
	at(P, s1.x, s1.z, 3)
	MatchService.step(0.1)
	assert(Participants.humanoid(P).WalkSpeed >= Gadgets.Phantom.nightSpeed * 0.99, "slick slowed the phantom")
end)

step("remotes: server validates intent + rate limits", function()
	local remote = game:GetService("ReplicatedStorage").Remotes.Action
	local sig = fakeSignal(remote, "OnServerEvent")
	sig:Fire(human, "lantern", true)
	assert(G.lanternOn ~= true, "wisp lantern")
	sig:Fire(human, 42, {})
	sig:Fire(human, "explode")
	sig:Fire(human, "use", { evil = true })
	sig:Fire(human, "use", "ClockworkDecoy")
	sig:Fire(human, "lift", 0 / 0)
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
	MatchService.setDurations({ lobby = 0.5, day = 1, night = 240, results = 1 })
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
		at(ph, 0, 0, 3)
		at(g, 2, 0, 3)
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

-- Bot-only rounds at the real 150 s / 240 s timings (speed-true walking, routes through doors,
-- stairs and the lift; no wall collision). BAL_ROUNDS=n runs a longer balance sim.
local BAL_ROUNDS = tonumber(process.env.BAL_ROUNDS or "") or 6
local balance = { Guests = 0, Phantoms = 0, reasons = {}, levels = {}, items = {}, lifts = 0, tampers = 0, repairs = 0, tags = 0, rebootSum = 0 }
step(string.format("bot-only rounds (no humans), %d full-length rounds, all floors, items used", BAL_ROUNDS), function()
	local hi = table.find(fakePlayers, human)
	if hi then
		table.remove(fakePlayers, hi)
	end
	local results = {}
	local nightLeft
	for round = 1, BAL_ROUNDS do
		MatchService.setDurations({ lobby = 0.5, results = 1 })
		assert(run(1.5, function()
			return phase() == "Day"
		end))
		assert(BotService.count() == 6, "bots " .. BotService.count())
		nightLeft = nil
		assert(run(400, function()
			if phase() == "Night" then
				nightLeft = workspace:GetAttribute("CM_PhaseEndsAt") - Clock.now()
			end
			return phase() == "Results"
		end), "round " .. round .. " did not finish")
		local gs = GridService.state()
		local tags, reps = 0, 0
		for _, q in Participants.all() do
			tags += q.stats.tags
			reps += q.stats.repairs
			balance.lifts += q.stats.lifts or 0
		end
		for _, b in BotService.list() do
			for lvl in b.levels or {} do
				balance.levels[lvl] = (balance.levels[lvl] or 0) + 1
			end
			for id, k in b.itemsUsed or {} do
				balance.items[id] = (balance.items[id] or 0) + k
			end
		end
		local winner = workspace:GetAttribute("CM_Winner")
		balance[winner] += 1
		local reason = workspace:GetAttribute("CM_Reason")
		balance.reasons[reason] = (balance.reasons[reason] or 0) + 1
		balance.tampers += gs.tampers
		balance.repairs += reps
		balance.tags += tags
		balance.rebootSum += gs.reboot
		table.insert(results, string.format("%s (%s) - tampers %d, reboot %d%%, repairs %d, tags %d, night left %.0f s",
			winner, reason, gs.tampers, gs.reboot, reps, tags, nightLeft or -1))
		assert(run(2, function()
			return phase() == "Lobby"
		end))
	end
	if BAL_ROUNDS <= 12 then
		print("       bot rounds:\n         " .. table.concat(results, "\n         "))
	end
	local itemList = {}
	for id, k in balance.items do
		table.insert(itemList, id .. " " .. k)
	end
	table.sort(itemList)
	print(string.format("       guest wins %d/%d (%.0f%%), avg tampers %.1f, avg repairs %.1f, avg tags %.1f, avg reboot %.0f%%, lift rides %d",
		balance.Guests, BAL_ROUNDS, 100 * balance.Guests / BAL_ROUNDS, balance.tampers / BAL_ROUNDS, balance.repairs / BAL_ROUNDS,
		balance.tags / BAL_ROUNDS, balance.rebootSum / BAL_ROUNDS, balance.lifts))
	print(string.format("       floors visited (bot-rounds): basement %d, ground %d, upper %d", balance.levels[-1] or 0, balance.levels[0] or 0, balance.levels[1] or 0))
	print("       items used by bots: " .. table.concat(itemList, ", "))
	assert((balance.levels[-1] or 0) > 0 and (balance.levels[0] or 0) > 0 and (balance.levels[1] or 0) > 0, "bots did not traverse all floors")
	assert(#itemList >= 4, "bots used too few item kinds")
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
	assert(not el.Button3.Visible, "NEXT shown with one usable item")
	-- more items: USE shows the selection, NEXT cycles it, chips mark it
	localPlayer:SetAttribute("Battery", 80)
	localPlayer:SetAttribute("SmokePellet", 1)
	localPlayer:SetAttribute("BrassWrench", 1)
	Hud.update()
	assert(el.Button3.Visible and el.Button3.Text == "NEXT", "next button")
	local first = el.Button2.Text
	State.cycle(Hud.usableItems("Night", localPlayer:GetAttributes()))
	Hud.update()
	assert(el.Button2.Text ~= first, "NEXT did not cycle: " .. first)
	assert(el.Inventory.BrassWrench.Visible and el.Inventory.SmokePellet.Visible and not el.Inventory.ClockworkDecoy.Visible, "item chips")
	assert(el.Inventory[State.selected].Selected.Enabled, "selected chip not outlined")
	assert(not table.find(Hud.usableItems("Night", localPlayer:GetAttributes()), "BrassWrench"), "passive wrench is usable")
	-- day: a disguised Phantom gets the same item buttons as a guest
	workspace:SetAttribute("CM_Phase", "Day")
	State.role = "Phantom"
	localPlayer:SetAttribute("PState", "Guest")
	localPlayer:SetAttribute("SpringBoots", 1)
	Hud.update()
	assert(el.Button1.Visible and string.find(el.Button1.Text, "BOOT"), "disguised phantom day item button: " .. el.Button1.Text)
	assert(el.RoleChip.Text.Text == "PHANTOM (secret)", "secret chip")
	-- minimap + compass: in the Library (ground), breaker A (basement) tripped at night
	State.role = "Guest"
	workspace:SetAttribute("CM_Phase", "Night")
	local char = makeCharacter("Phone")
	char:PivotTo(CFrame.new(-66, 3, -24))
	localPlayer.Parent = Players -- (Lune keeps Character refs only on parented players)
	localPlayer.Character = char
	assert(localPlayer.Character == char, "fake character")
	built.breakers.A.model:SetAttribute("Tripped", true)
	Hud.update()
	local Minimap = requireModule(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Minimap)
	local ms = Minimap.state()
	assert(el.Minimap.Visible and el.Compass.Visible, "minimap hidden")
	assert(string.find(ms.floorLabel.Text, "GROUND FLOOR"), "floor label " .. ms.floorLabel.Text)
	assert(ms.frames.library.Visible and not ms.frames.generator.Visible, "minimap shows the wrong floor")
	assert(ms.frames.library.BackgroundColor3.G > 0.9, "current room not lit up on the minimap")
	assert(ms.compassText.Text == "BREAKER A" and string.find(ms.compassSub.Text, "GO DOWN"), "compass " .. ms.compassText.Text .. " / " .. ms.compassSub.Text)
	assert(ms.nextPt and ms.routeLen > 50, "compass route")
	print("       compass from the Library: " .. ms.compassText.Text .. " / " .. ms.compassSub.Text)
	char:PivotTo(CFrame.new(0, 23, -60)) -- observatory, upper floor
	Hud.update()
	assert(string.find(Minimap.state().floorLabel.Text, "UPPER FLOOR"), "upper floor label")
	assert(Minimap.state().frames.observatory.Visible and not Minimap.state().frames.library.Visible, "upper floor rooms")
	built.breakers.A.model:SetAttribute("Tripped", false)
	char:PivotTo(CFrame.new(0, 3, 132)) -- back to the terrace
	for _, id in { "SmokePellet", "BrassWrench", "SpringBoots" } do
		localPlayer:SetAttribute(id, nil)
	end
	workspace:SetAttribute("CM_Phase", "Night")
	State.role = "Guest"
	localPlayer:SetAttribute("PState", "Guest")
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
