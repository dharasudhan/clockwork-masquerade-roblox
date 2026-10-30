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
local boundActions = {}
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
eventsOn("UserInputService", { "LastInputTypeChanged" })
eventsOn("ProximityPromptService", { "PromptShown", "PromptHidden", "PromptTriggered" })
eventsOn("MarketplaceService", { "PromptGamePassPurchaseFinished" })
roblox.implementMethod("ContextActionService", "BindActionAtPriority", function(_, name, fn, _touch, priority, ...)
	boundActions[name] = { fn = fn, keys = { ... }, priority = priority }
end)
roblox.implementMethod("ContextActionService", "UnbindAction", function(_, name)
	boundActions[name] = nil
end)
roblox.implementMethod("GuiService", "IsTenFootInterface", function()
	return false
end)
roblox.implementMethod("UserInputService", "GetImageForKeyCode", function(_, kc)
	return "rbxasset://textures/ui/Controls/xbox" .. kc.Name .. ".png"
end)
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
roblox.implementMethod("Players", "GetPlayerByUserId", function(_, id)
	for _, pl in fakePlayers do
		if pl.UserId == id then
			return pl
		end
	end
	return nil
end)
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
	for _, spec in { { "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.3, 122) }, { "RightHand", Vector3.new(0.4, 0.4, 0.4), Vector3.new(1.5, 2.2, 122) } } do
		local part = Instance.new("Part")
		part.Name = spec[1]
		part.Size = spec[2]
		part.CFrame = CFrame.new(spec[3])
		part.Parent = character
	end
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
local Match = requireModule(Shared.Config.Match)
local Progression = requireModule(Shared.Config.Progression)
local Monetization = requireModule(Shared.Config.Monetization)
local Cosmetics = requireModule(Shared.Config.Cosmetics)
local DEBUG_BAL = process.env.DEBUG_BAL == "1"

local ManorBuilder, LightingService, MatchService, BotService, GridService, ChaseService
local LanternService, ChestService, Participants, Clock, DataService, Net, ItemService, LiftService
local ExposeService, ArchiveService, FinaleService, AbilityService, ShopService
local QuestService, EventService
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
	ExposeService = requireModule(Server.ExposeService)
	ArchiveService = requireModule(Server.ArchiveService)
	FinaleService = requireModule(Server.FinaleService)
	AbilityService = requireModule(Server.AbilityService)
	ShopService = requireModule(Server.ShopService)
	QuestService = requireModule(Server.QuestService)
	EventService = requireModule(Server.EventService)
end)

local built
step("ManorBuilder: 5-level manor (B1, G, 1F, 2F attic, tower), 50+ rooms with own themes, 6 breakers, 4-stop lift, props", function()
	built = ManorBuilder.build()
	local map = workspace:FindFirstChild("Map")
	assert(map and map:FindFirstChild("Manor") and map:FindFirstChild("Lobby"), "map missing")
	local rooms = map.Manor.Rooms:GetChildren()
	assert(#rooms == #Manor.Rooms, "rooms " .. #rooms)
	for _, r in Manor.Rooms do
		assert(built.roomLights[r.id] and #built.roomLights[r.id] >= 1, "no lights in " .. r.id)
	end
	local floors = {}
	for _, id in { "A", "B", "C", "D", "E", "F" } do
		local b = built.breakers[id]
		assert(b and b.model.Parent, "breaker " .. id)
		floors[b.level] = true
	end
	assert(floors[-1] and floors[0] and floors[1] and floors[2] and floors[3], "breakers not on all 5 levels")
	local lifts = 0
	for _ in built.lifts do
		lifts += 1
	end
	assert(lifts == 4, "lift stops " .. lifts)
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
	local art = map.Manor:GetAttribute("ArtPieces") or 0
	local guis = 0
	for _, d in map:GetDescendants() do
		if d:IsA("GuiObject") then
			guis += 1
		end
	end
	print("       wall art pieces: " .. art .. ", GUI objects in the map: " .. guis)
	assert(art >= 120, "wall art " .. art)
	assert(parts > 300 and parts < 6000, "part budget " .. parts)
	-- every room has its own theme; themes differ between neighbours
	local Decor = requireModule(Shared.Config.Decor)
	for _, r in Manor.Rooms do
		assert(r.theme and Decor.Themes[r.theme], "room without a theme " .. r.id)
	end
	local p = built.props
	assert(p and p.projector and p.board and p.console and p.keys.engine and p.keys.attic and p.keys.greenhouse, "night 2/3 props")
	local nCab = 0
	for _ in p.cabinets do
		nCab += 1
	end
	assert(nCab == #Manor.Cabinets, "cabinets " .. nCab)
	-- StreamingEnabled: key interactables never stream out on clients
	local Persistent = roblox.Enum.ModelStreamingMode.Persistent
	for _, n in { "Breakers", "Lifts", "Props" } do
		local g = map.Manor:FindFirstChild(n)
		assert(g and g:IsA("Model") and g.ModelStreamingMode == Persistent, n .. " not a Persistent model")
	end
	assert(p.console.model.ModelStreamingMode == Persistent and p.projector.model.ModelStreamingMode == Persistent, "console/projector persistent")
	for _, b in built.breakers do
		assert(b.model.ModelStreamingMode == Persistent, "breaker persistent")
	end
	assert(p.board.part:IsDescendantOf(map.Manor.Props), "evidence board under Props")
	print("       streaming: Breakers/Lifts/Props (board, console, projector, cabinets, key pedestals) Persistent")
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
		for i = 1, math.min(tonumber(process.env.ZF_SHOW) or 6, #probs) do
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
	local daily = Progression.Daily[1].tokens
	assert(data and data.Wins.Guest == 0 and data.Version == 3, "bad defaults")
	assert(data.GearTokens == daily and data.Daily.Streak == 1, "daily login day 1 not granted: " .. tostring(data.GearTokens))
	assert(human.leaderstats["Gear Tokens"].Value == daily, "leaderstats")
	assert(human:GetAttribute("IntroSeen") == false and human:GetAttribute("TutorialDone") == false, "intro/tutorial flags")
	assert(data.Badges.Welcome == true, "welcome badge not recorded")
	assert(DataService.claimDaily(human) == nil, "daily claimed twice in one day")
	Clock.shiftWall(86400)
	local d2 = DataService.claimDaily(human)
	assert(d2 and d2.day == 2 and data.GearTokens == daily + Progression.Daily[2].tokens, "day 2 streak")
	Clock.shiftWall(3 * 86400)
	local d3 = DataService.claimDaily(human)
	assert(d3 and d3.day == 1, "missed days restart the streak")
	data.GearTokens = 0 -- clean slate for the match test
	DataService.publish(human)
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

step("full 3-night match, 1 human + 5 bots: Night 1 Breaker -> Dawn -> Night 2 Archives -> Dawn -> Night 3 Dawn Reboot -> Results", function()
	MatchService.setDurations({ lobby = 1, results = 2 }) -- real night lengths
	MatchService.init()
	assert(phase() == "Lobby", "starts in lobby")
	MatchService.state().lastPhantoms = { P4242 = true } -- the human is a guest this match
	assert(run(2, function()
		return phase() == "Day"
	end), "no day")
	local me = Participants.ofPlayer(human)
	assert(me and me.role == "Guest", "human not a guest")
	me.immuneUntil = math.huge -- the human idles; keep it untagged so all 3 nights play out
	assert(BotService.count() == 5 and #Participants.all() == 6 and #Participants.phantoms() == 1, "6 participants, 1 Phantom")
	assert(human:GetAttribute("PState") == "Guest" and human:GetAttribute("Ribbon"), "public PState / ribbon")
	assert(me.model:FindFirstChild("MasqueradeMask") and me.model:FindFirstChild("Ribbon"), "mask + ribbon worn")
	for _, p in Participants.phantoms() do
		assert(p.model:GetAttribute("PState") == "Guest", "Phantom identity leaked by day")
	end
	local role = lastNote("role")
	assert(role and role.role == "Guest", "role not told privately")
	local seen = { nights = {}, floors = {}, overdrive = false, keysIn = 0, pages = 0, votes = 0, clues = 0, dawn = 0 }
	local function floorsTick()
		for _, p in Participants.all() do
			local pos = Participants.pos(p)
			if pos then
				seen.floors[ManorLayout.levelAt(Manor, pos.Y)] = true
			end
		end
		if workspace:GetAttribute("CM_Stage") == "Overdrive" then
			seen.overdrive = true
		end
		seen.keysIn = math.max(seen.keysIn, FinaleService.insertedCount())
		seen.pages = math.max(seen.pages, workspace:GetAttribute("CM_Pages") or 0)
		local v = workspace:GetAttribute("CM_Votes") or ""
		if v ~= "" then
			seen.votes += 1
		end
		if (workspace:GetAttribute("CM_Clues") or "") ~= "" then
			seen.clues += 1
		end
		return false
	end
	for no = 1, 3 do
		assert(workspace:GetAttribute("CM_NightNo") == no, "night number " .. tostring(workspace:GetAttribute("CM_NightNo")))
		local n = Nights[Match.NightOrder[no]]
		assert(workspace:GetAttribute("CM_NightName") == n.name, "night name")
		local dayLeft = workspace:GetAttribute("CM_PhaseEndsAt") - Clock.now()
		assert(dayLeft > n.daySeconds - 3 and dayLeft <= n.daySeconds + 0.1, "day length " .. dayLeft)
		assert(#ChestService.unopened() == n.chestCount, "chests stocked " .. #ChestService.unopened())
		if no == 2 then
			assert(ArchiveService.active() and #ArchiveService.openCabinets() == #Manor.Cabinets, "archive cabinets ready")
		end
		assert(run(n.daySeconds + 1, function()
			floorsTick()
			return phase() == "Night"
		end), "no night " .. no)
		local ph = Participants.phantoms()[1]
		assert(ph.model:FindFirstChild("PhantomMask") and ph.model:GetAttribute("PState") == "Phantom", "phantom unmasked at night")
		if no < 3 then
			assert(workspace:GetAttribute("CM_Tripped") ~= "" or GridService.state().tampers == 0, "tampered breaker did not trip")
			assert(run(Nights.nightLength(n) + 2, function()
				floorsTick()
				return phase() ~= "Night"
			end), "night " .. no .. " never ended")
			assert(phase() == "Dawn", "expected Dawn after night " .. no .. ", got " .. tostring(phase()))
			seen.nights[no] = workspace:GetAttribute("CM_LastNightWinner")
			print(string.format("       night %d (%s): %s", no, n.name, tostring(seen.nights[no])))
			assert(run(Match.DawnSeconds + 1, function()
				return phase() == "Day"
			end), "dawn did not lead to a day")
			for _, p in Participants.all() do
				assert(p.state == "Guest", "everyone looks like a guest at the next day: " .. p.name .. "=" .. p.state)
				assert(not (p.model and p.model:FindFirstChild("WispOrb")), "wisp orb left over")
			end
		else
			assert(workspace:GetAttribute("CM_Stage") == "Showdown", "finale showdown")
			assert(#FinaleService.freeKeys() == 3, "3 keys on pedestals")
			assert(run(Nights.nightLength(n) + 2, function()
				floorsTick()
				return phase() == "Results"
			end), "finale never ended")
		end
	end
	local res = lastNote("results")
	assert(res and res.winner and res.tokens >= Gadgets.Rewards.played, "results not sent")
	print(string.format("       finale: %s - %s (+%d tokens) | keys in %d, overdrive %s, pages %d, vote ticks %d, clue ticks %d",
		res.winner, res.reason, res.tokens, seen.keysIn, tostring(seen.overdrive), seen.pages, seen.votes, seen.clues))
	local floors = {}
	for l in seen.floors do
		table.insert(floors, l)
	end
	table.sort(floors)
	print("       floors visited: " .. table.concat(floors, ","))
	for _, l in { -1, 0, 1, 2 } do
		assert(seen.floors[l], "nobody reached level " .. l)
	end
	local data = DataService.get(human)
	-- v1.1: daily quests completed by this match pay on top of the match tokens
	assert(data.Played == 1 and data.GearTokens >= res.tokens and data.XP > 0, "save not updated")
	ok = run(3, function()
		return phase() == "Lobby"
	end)
	assert(ok, "no return to lobby")
	assert(BotService.count() == 0 and #Participants.all() == 0, "match not cleaned up")
	assert(human:GetAttribute("InMatch") == nil and human:GetAttribute("Ribbon") == nil, "player still marked in match")
	local h = table.concat(MatchService.history(), ",")
	assert(string.find(h, "Lobby,Day,Night,Dawn,Day,Night,Dawn,Day,Night", 1, true) and string.sub(h, -13) == "Results,Lobby", h)
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
	local cls = G.class
	G.class = "Illuminator" -- no repair bonus
	give(G, "BrassWrench", 0)
	give(G, "CopperWire", 0)
	assert(GridService.repairTime(G) == N1.repairSeconds, "base repair time")
	give(G, "BrassWrench", 1)
	assert(math.abs(GridService.repairTime(G) - N1.repairSeconds * Items.Wrench.repairFactor) < 1e-6, "wrench")
	give(G, "CopperWire", 1)
	assert(math.abs(GridService.repairTime(G) - N1.repairSecondsWithWire * Items.Wrench.repairFactor) < 1e-6, "wire + wrench")
	give(G, "CopperWire", 0)
	give(G, "BrassWrench", 0)
	G.class = "Mechanist"
	assert(math.abs(GridService.repairTime(G) - N1.repairSeconds / 1.5) < 1e-6, "Mechanist repairs 50% faster")
	G.class = cls
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

step("win: 100% reboot -> Guests win the NIGHT (dawn, match goes on); all tagged -> Phantoms win the match", function()
	local grid = GridService.state()
	grid.reboot = 99.99
	MatchService.step(0.1)
	assert(phase() == "Dawn", "night 1 win should lead to Dawn, got " .. tostring(phase()))
	assert(workspace:GetAttribute("CM_LastNightWinner") == "Guests" and workspace:GetAttribute("CM_NightsWon") == 1, "night winner")
	assert(run(Match.DawnSeconds + 1, function()
		return phase() == "Day"
	end), "no day 2")
	assert(workspace:GetAttribute("CM_NightNo") == 2 and workspace:GetAttribute("CM_Night") == 2, "night 2")
	for _, p in Participants.all() do
		assert(p.state == "Guest", "dawn revives / re-disguises everyone")
	end
	MatchService.state().endsAt = Clock.now() -- end the match quickly: go to lobby
	MatchService.setDurations({ lobby = 0.5, day = 1, night = 240, results = 1 })
	for _, p in Participants.all() do
		if p.role == "Phantom" then
			Participants.remove(p)
		end
	end
	assert(run(1, function()
		return phase() == "Results"
	end), "phantoms fled -> no results")
	assert(workspace:GetAttribute("CM_Winner") == "Guests", "phantoms fled -> guests win the match")
	assert(run(3, function()
		return phase() == "Lobby"
	end))
	MatchService.setDurations({ lobby = 0.5, day = 1, night = 240, results = 1 })
	MatchService.state().lastPhantoms = {}
	assert(run(1.5, function()
		return phase() == "Day"
	end))
	BotService.setPaused(true)
	for no = 1, 3 do
		assert(run(12, function()
			return phase() == "Night"
		end), "no night " .. no)
		run(Gadgets.Phantom.transformSeconds + 0.2)
		local ph = Participants.phantoms()[1]
		for _, g in Participants.guests(true) do
			at(ph, 0, 0, 3)
			at(g, 2, 0, 3)
			Clock.advance(Gadgets.Phantom.tagCooldown + 0.05)
			assert(ChaseService.tryTag(ph, g.id), "tag " .. g.name)
			MatchService.step(0.1)
			if phase() ~= "Night" then
				break
			end
		end
		if no < 3 then
			assert(phase() == "Dawn" and workspace:GetAttribute("CM_LastNightWinner") == "Phantoms", "a wipe on night " .. no .. " loses the night only: " .. tostring(phase()))
		else
			assert(phase() == "Results" and workspace:GetAttribute("CM_Winner") == "Phantoms", "a finale wipe ends the match: " .. tostring(workspace:GetAttribute("CM_Winner")))
		end
	end
	BotService.setPaused(false)
	assert(run(2, function()
		return phase() == "Lobby"
	end))
end)

step("v1.0 staged: Expose (clue + vote -> Phantom stunned), class gadgets, Night 2 pages/trap/projector/glide, finale keys -> Overdrive ring -> Guests", function()
	MatchService.setDurations({ lobby = 0.5, day = 60, night = 240, results = 1, dawn = 1, showdown = 300, overdrive = 300 })
	MatchService.state().lastPhantoms = { P4242 = true }
	assert(run(2, function()
		return phase() == "Day"
	end), "no day")
	BotService.setPaused(true)
	local me = Participants.ofPlayer(human)
	local ph = Participants.phantoms()[1]
	assert(me and me.role == "Guest" and ph, "roles")
	me.immuneUntil = math.huge
	local function now()
		return Clock.now()
	end
	local function toNight()
		MatchService.state().endsAt = now()
		run(0.3)
		assert(phase() == "Night", "expected night, got " .. tostring(phase()))
	end
	-- ribbon clue: a tamper leaves glitter in the tamperer's colour (+1 other); inspecting finds it
	ExposeService.tampered(ph, "B")
	local bx, bz, by = bp("B")
	at(me, bx, bz, by)
	local clue = ExposeService.inspect(me, "B")
	assert(clue and (clue[1] == ph.ribbon or clue[2] == ph.ribbon), "clue does not name the tamperer's ribbon")
	assert(string.find(workspace:GetAttribute("CM_Clues") or "", "B:"), "clue not published")
	-- everyone votes for the Phantom -> exposed + stunned at nightfall
	local voters = 0
	for _, p in Participants.all() do
		if p ~= ph and ExposeService.cast(p, ph.id) then
			voters += 1
		end
	end
	assert(voters >= 4 and not ExposeService.cast(me, me.id), "votes")
	toNight()
	assert(ph.stunUntil and ph.stunUntil > now() and ph.model:GetAttribute("Exposed"), "exposed Phantom not stunned")
	run(Gadgets.Phantom.transformSeconds + 0.2)
	at(ph, 15, 10, 3)
	at(me, 15, 12, 3)
	assert(not ChaseService.tryTag(ph, nil), "a stunned Phantom tagged")
	ph.stunUntil = nil
	ph.revealUntil = nil
	-- Illuminator Strobe Flash freezes Phantoms in front
	me.class = "Illuminator"
	me.abilityAt = {}
	me.aimAt = nil
	at(me, 15, 12, 3)
	at(ph, 15, 4, 3) -- 8 studs in front (-Z)
	assert(AbilityService.kind(me) == "strobe" and AbilityService.use(me), "strobe refused")
	assert(ph.frozenUntil and ph.frozenUntil > now(), "strobe did not freeze")
	assert(not ChaseService.tryTag(ph, nil), "a frozen Phantom tagged")
	assert(not AbilityService.use(me), "strobe ignored its cooldown")
	ph.frozenUntil = nil
	-- Mechanist Spring Barricade knocks the first Phantom back
	me.class = "Mechanist"
	at(me, 15, 0, 3)
	assert(AbilityService.kind(me) == "barricade" and AbilityService.use(me), "barricade refused")
	at(ph, 15, 3.2, 3) -- right on the gate (2.5 behind me)
	run(0.2)
	local pp = Participants.pos(ph)
	assert(ph.frozenUntil and pp.Z > 6, "barricade did not knock the Phantom back: z=" .. pp.Z)
	ph.frozenUntil = nil
	-- night 1 won -> dawn -> night 2 (Blueprint Archives)
	GridService.state().reboot = 100
	run(0.2)
	assert(phase() == "Dawn", "no dawn")
	assert(run(2, function()
		return phase() == "Day"
	end) and workspace:GetAttribute("CM_Night") == 2, "night 2 day")
	local st = ArchiveService.state()
	local pageCab, otherCab
	for id, c in st.cabinets do
		if c.page and not pageCab then
			pageCab = id
		elseif not c.page and not otherCab then
			otherCab = id
		end
	end
	local cabs = built.props.cabinets
	local function atCab(p, id)
		local h = cabs[id]
		at(p, h.x, h.z, ManorLayout.levelAt(Manor, h.y) * Manor.LevelHeight + RH)
	end
	atCab(ph, otherCab)
	assert(ArchiveService.trap(ph, otherCab), "phantom could not trap a cabinet")
	assert(not ArchiveService.trap(me, otherCab), "a guest trapped a cabinet")
	atCab(me, otherCab)
	local n0 = #sentToClient
	assert(ArchiveService.search(me, otherCab) == "trap", "trap did not fire")
	local inked = false
	for i = n0 + 1, #sentToClient do
		local e = sentToClient[i]
		if e.player == human and type(e.args[1]) == "table" and e.args[1].kind == "ink" then
			inked = true
		end
	end
	assert(inked, "no ink splash for the searcher")
	atCab(me, pageCab)
	assert(string.find(ArchiveService.search(me, pageCab) or "", "page"), "page not found")
	assert(me.pages == 1 and human:GetAttribute("Pages") == 1, "page not carried")
	toNight()
	local pr = built.props.projector
	at(me, pr.x, pr.z + 3, RH)
	local before = GridService.state().reboot
	assert(ArchiveService.slot(me), "slot refused")
	assert(GridService.state().reboot >= before + Nights[2].archives.rebootPerPage - 0.01, "page did not jump the reboot")
	local bar = ArchiveService.barrier()
	assert(bar and bar.radius == Nights[2].archives.barrierBase, "barrier radius")
	run(Gadgets.Phantom.transformSeconds + 0.2)
	at(ph, pr.x + 3, pr.z + 2, RH)
	run(0.2)
	local php = Participants.pos(ph)
	assert(Vector3.new(php.X - pr.x, 0, php.Z - pr.z).Magnitude >= bar.radius - 0.1, "Phantom not pushed out of the light barrier")
	-- Phase Glide: blink 10 studs through walls on the same floor
	at(ph, 15, 0, 3)
	assert(AbilityService.kind(ph) == "glide" and AbilityService.use(ph), "glide refused")
	local g = Participants.pos(ph)
	assert(math.abs(g.Z - -10) < 0.5, "glide distance: z=" .. g.Z)
	assert(not AbilityService.use(ph), "glide ignored its cooldown")
	-- night 2 won -> dawn -> night 3 finale
	GridService.state().reboot = 100
	run(0.2)
	assert(run(2, function()
		return phase() == "Day"
	end) and workspace:GetAttribute("CM_Night") == 3, "finale day")
	toNight()
	assert(workspace:GetAttribute("CM_Stage") == "Showdown" and #FinaleService.freeKeys() == 3, "showdown keys")
	local c = built.props.console
	for i, k in ipairs(FinaleService.freeKeys()) do
		local h = built.props.keys[k.id]
		at(me, h.x + 2, h.z, ManorLayout.levelAt(Manor, h.y) * Manor.LevelHeight + RH)
		assert(FinaleService.take(me, k.id), "take key " .. k.id)
		assert(me.carryKey == k.id and human:GetAttribute("CarryKey") == k.id, "carrying")
		assert(not FinaleService.take(me, k.id), "took a second key")
		at(me, c.x, c.z + 3, RH)
		if i == 1 then
			-- a tagged carrier's key flies back; inserting wakes wisps
			local other = nil
			for _, q in Participants.guests(true) do
				if q ~= me then
					other = q
					break
				end
			end
			other.state = "Wisp"
			Participants.set(other, "PState", "Wisp")
			assert(FinaleService.insert(me), "insert 1")
			assert(other.state == "Guest", "inserting a key did not wake the Wisp")
		else
			assert(FinaleService.insert(me), "insert " .. i)
		end
	end
	run(0.2)
	assert(workspace:GetAttribute("CM_Stage") == "Overdrive", "no overdrive after 3 keys")
	local left = workspace:GetAttribute("CM_PhaseEndsAt") - now()
	assert(left > 250, "overdrive timer did not restart: " .. left)
	-- Shockwave Dash (telegraphed windup)
	at(ph, 20, 25, 3)
	local okDash, whyDash = AbilityService.use(ph)
	assert(okDash, "dash refused: kind=" .. tostring(AbilityService.kind(ph)) .. " why=" .. tostring(whyDash) .. " state=" .. tostring(ph.state) .. " frozen=" .. tostring(ph.frozenUntil) .. " stun=" .. tostring(ph.stunUntil))
	run(Nights[3].finale.dash.windup + 0.2)
	local dz = Participants.pos(ph)
	assert(dz.Z < 25 - Nights[3].finale.dash.distance + 1, "dash did not move: z=" .. dz.Z)
	assert(FinaleService.phantomSpeed() > 1, "overdrive Phantom speed")
	-- every guest stands in the ring; the Phantom stays out -> Dawn Reboot
	at(ph, 25, -25, 3)
	ph.frozenUntil = math.huge
	local k = 0
	for _, q in Participants.guests(true) do
		k += 1
		at(q, c.x + 6 + (k % 2), c.z + 3 + k * 0.5, RH)
		q.immuneUntil = math.huge
	end
	assert(run(60, function()
		for _, q in Participants.guests(true) do
			local qp = Participants.pos(q)
			if qp and Vector3.new(qp.X - c.x, 0, qp.Z - c.z).Magnitude > c.radius - 1 then
				at(q, c.x + 6, c.z + 3, RH) -- the dynamo pulse pushed it: step back in
			end
		end
		return phase() == "Results"
	end), "ring never completed: " .. tostring(workspace:GetAttribute("CM_Ring")) .. "/" .. tostring(workspace:GetAttribute("CM_RingNeed")))
	assert(workspace:GetAttribute("CM_Winner") == "Guests", "winner " .. tostring(workspace:GetAttribute("CM_Winner")))
	local res = lastNote("results")
	assert(res and res.won and res.stats.keys == 3 and res.stats.pages == 1, "results stats")
	local data = DataService.get(human)
	assert(data.Badges.KeyKeeper and data.Badges.Archivist and data.Badges.FirstDawn, "badges recorded")
	BotService.setPaused(false)
	ph.frozenUntil = nil
	assert(run(3, function()
		return phase() == "Lobby"
	end))
end)

step("shop + mocked Robux purchases: buy with Gear Tokens, equip, ProcessReceipt grants once (idempotent), passes", function()
	local data = DataService.get(human)
	data.GearTokens = 400
	assert(ShopService.buy(human, "mask_rose"), "token purchase")
	assert(data.GearTokens == 400 - Cosmetics.byId("mask_rose").tokens and data.Owned.mask_rose, "tokens spent / owned")
	assert(not ShopService.buy(human, "mask_rose"), "bought twice")
	assert(not ShopService.buy(human, "mask_gold_vip"), "VIP mask sold for tokens")
	assert(not ShopService.equip(human, "mask_gold_vip"), "equipped a locked VIP mask")
	assert(ShopService.equip(human, "mask_rose") and data.Equipped.Mask == "mask_rose" and human:GetAttribute("Equip_Mask") == "mask_rose", "equip")
	-- developer products (ids are placeholders 0 in config; the test gives them fake ids)
	Monetization.Products.MaskPackNeon.id = 111
	Monetization.Products.TokenPouch.id = 222
	local Granted = roblox.Enum.ProductPurchaseDecision.PurchaseGranted
	assert(ShopService.processReceipt({ PlayerId = 4242, ProductId = 111, PurchaseId = "r-1" }) == Granted, "receipt 1")
	assert(data.Owned.mask_neon_pack, "pack not granted")
	local t0 = data.GearTokens
	assert(ShopService.processReceipt({ PlayerId = 4242, ProductId = 222, PurchaseId = "r-2" }) == Granted, "receipt 2")
	assert(ShopService.processReceipt({ PlayerId = 4242, ProductId = 222, PurchaseId = "r-2" }) == Granted, "retry")
	assert(data.GearTokens == t0 + Monetization.Products.TokenPouch.tokens, "receipt retry granted twice: " .. data.GearTokens)
	assert(ShopService.processReceipt({ PlayerId = 4242, ProductId = 999, PurchaseId = "r-3" }) ~= Granted, "unknown product granted")
	assert(ShopService.processReceipt({ PlayerId = 1, ProductId = 111, PurchaseId = "r-4" }) ~= Granted, "receipt for an absent player granted")
	Monetization.Products.MaskPackNeon.id = 0
	Monetization.Products.TokenPouch.id = 0
	-- passes: VIP cosmetics + 2x tokens
	ShopService.grantPass(human, "VIP")
	assert(string.find(human:GetAttribute("Owned"), "mask_gold_vip", 1, true) and ShopService.equip(human, "mask_gold_vip"), "VIP cosmetics")
	assert(ShopService.tokenMultiplier(human) == 1, "2x without the pass")
	ShopService.grantPass(human, "DoubleTokens")
	assert(ShopService.tokenMultiplier(human) == 2, "2x pass")
	DataService.passes(human).VIP = nil
	DataService.passes(human).DoubleTokens = nil
	-- settings / class / flags persist in the save
	assert(DataService.setSetting(human, "Music", false) and human:GetAttribute("Set_Music") == false, "music setting")
	assert(not DataService.setSetting(human, "Bogus", true), "unknown setting accepted")
	assert(DataService.setClass(human, "Illuminator") and data.Class == "Illuminator", "class")
	assert(not DataService.setClass(human, "Wizard"), "bad class")
	assert(DataService.setFlag(human, "IntroSeen") and human:GetAttribute("IntroSeen") == true, "intro flag")
	DataService.setSetting(human, "Music", true)
	DataService.setClass(human, "Mechanist")
end)


step("v1.1/v1.2: save v2->v3 migration, quests (corrupt list rerolls, payout once), season premium, starter flag, manor events", function()
	local data = DataService.get(human)
	local SaveData = requireModule(Shared.Logic.SaveData)
	local Template = requireModule(Shared.Config.DataTemplate)
	-- a v2 save (no Quests/Season/StarterPackBought) sanitises into a complete v3 save
	local v2 = { Version = 2, GearTokens = 50, XP = 10, Level = 1, Wins = { Guest = 1, Phantom = 0 }, Played = 3 }
	assert(SaveData.sanitize(v2, Template) > 0, "v2 save needed no fixes")
	assert(type(v2.Quests) == "table" and v2.Quests.Day == 0 and type(v2.Quests.Daily) == "table", "v2 quests")
	assert(v2.Season.Id == "" and v2.Season.Tier == 1 and v2.Season.Premium == false and v2.StarterPackBought == false, "v2 season")
	assert(v2.GearTokens == 50 and v2.Wins.Guest == 1, "v2 data lost")
	-- quests: a corrupt saved list rerolls; ensure is idempotent on the same day
	data.Quests.Daily = { { id = "nope" }, 5 }
	data.Quests.Day = DataService.today()
	QuestService.ensure(human)
	assert(#data.Quests.Daily == 3 and data.Quests.Daily[1].progress == 0, "corrupt daily list not rerolled")
	assert(#data.Quests.Weekly == 2, "weekly list")
	local before = data.Quests.Daily[1].id
	QuestService.ensure(human)
	assert(data.Quests.Daily[1].id == before, "ensure rerolled a valid list")
	-- a match completes every "matches" quest once and pays exactly its tokens
	for _, q in data.Quests.Daily do
		q.progress, q.done = 0, false
	end
	local expect = 0
	for _, q in data.Quests.Daily do
		if q.stat == "matches" and q.goal == 1 then
			expect += q.tokens
		end
	end
	local t0 = data.GearTokens
	QuestService.onMatchEnd(human, { chests = 0, repairs = 0, tags = 0, exposes = 0, nightsWon = 0 }, false, { human })
	assert(data.GearTokens - t0 >= expect, "quest payout " .. (data.GearTokens - t0) .. " < " .. expect)
	local t1 = data.GearTokens
	QuestService.onMatchEnd(human, { chests = 0, repairs = 0, tags = 0, exposes = 0, nightsWon = 0 }, false, { human })
	for _, q in data.Quests.Daily do
		if q.stat == "matches" and q.goal == 1 then
			assert(q.done, "matches quest not done")
		end
	end
	assert(string.find(human:GetAttribute("QuestDaily") or "", ":", 1, true), "QuestDaily mirror")
	-- season: inactive by default (no XP); a new season resets premium bought for an old one
	assert(QuestService.seasonXp(data, 500) == nil, "season XP accrued while unscheduled")
	local Season = requireModule(Shared.Config.Season)
	local s0, e0 = Season.StartsAt, Season.EndsAt
	Season.StartsAt, Season.EndsAt = DataService.today() - 1, 0
	data.Season = { Id = "old-season", XP = 900, Tier = 4, Premium = true }
	assert(QuestService.seasonXp(data, 260) == 2, "season tier-up")
	assert(data.Season.Id == Season.Id and data.Season.Premium == false, "old premium carried into a new season")
	data.Season = { Id = Season.Id, XP = 0, Tier = 1, Premium = true }
	QuestService.seasonXp(data, 10)
	assert(data.Season.Premium == true, "premium for this season lost")
	Season.StartsAt, Season.EndsAt = s0, e0
	data.Season = { Id = "", XP = 0, Tier = 1, Premium = false }
	-- starter trunk + season pass receipts set their flags
	local Granted = roblox.Enum.ProductPurchaseDecision.PurchaseGranted
	Monetization.Products.StarterPack.id = 333
	Monetization.Products.SeasonWinter.id = 444
	assert(ShopService.processReceipt({ PlayerId = 4242, ProductId = 333, PurchaseId = "r-s1" }) == Granted, "starter receipt")
	assert(data.StarterPackBought and data.Owned.mask_starter and human:GetAttribute("StarterPackBought") == true, "starter flag")
	assert(ShopService.processReceipt({ PlayerId = 4242, ProductId = 444, PurchaseId = "r-s2" }) == Granted, "season receipt")
	assert(data.Season.Premium and data.Season.Id == Season.Id, "season premium flag")
	Monetization.Products.StarterPack.id = 0
	Monetization.Products.SeasonWinter.id = 0
	data.StarterPackBought = false
	data.Season = { Id = "", XP = 0, Tier = 1, Premium = false }
	DataService.publish(human)
	-- manor events: timed dials set and expire; Power Surge outside a grid night falls back
	local nk = workspace:GetAttribute("CM_NightKind")
	workspace:SetAttribute("CM_NightKind", "finale")
	EventService._fire("PowerSurge")
	assert(workspace:GetAttribute("CM_Event") == "DeepDark" and workspace:GetAttribute("CM_EventDrain"), "power surge on the finale")
	EventService._fire("ClockworkRush")
	assert(workspace:GetAttribute("CM_EventSpeed") == 1.15, "clockwork rush speed")
	EventService._fire("RumorMill") -- no clue: warning toast, no error
	EventService._clearMods()
	assert(workspace:GetAttribute("CM_EventDrain") == nil and workspace:GetAttribute("CM_EventSpeed") == nil, "event dials not cleared")
	workspace:SetAttribute("CM_NightKind", nk)
end)

-- Bot-only 3-night matches at the real timings (speed-true walking, routes through doors,
-- stairs and the lift; no wall collision). BAL_ROUNDS=n runs a longer balance sim.
local BAL_ROUNDS = tonumber(process.env.BAL_ROUNDS or "") or 6
local balance = { Guests = 0, Phantoms = 0, reasons = {}, levels = {}, items = {}, lifts = 0, tampers = 0, repairs = 0, tags = 0,
	nightGuest = 0, nights = 0, keys = 0, overdrive = 0, pages = 0, gadgets = 0, exposed = 0 }
step(string.format("bot-only 3-night matches (no humans), %d matches, all floors, items + gadgets used", BAL_ROUNDS), function()
	local hi = table.find(fakePlayers, human)
	if hi then
		table.remove(fakePlayers, hi)
	end
	local results = {}
	ExposeService.onExposed(function(t, isPhantom)
		if isPhantom then
			balance.exposed += 1
		end
	end)
	for round = 1, BAL_ROUNDS do
		MatchService.setDurations({ lobby = 0.5, results = 1 })
		assert(run(1.5, function()
			return phase() == "Day"
		end))
		assert(BotService.count() == 6, "bots " .. BotService.count())
		local keys, od, pages, tampers = 0, false, 0, 0
		local lastTampers = 0
		assert(run(1200, function()
			keys = math.max(keys, FinaleService.insertedCount())
			od = od or workspace:GetAttribute("CM_Stage") == "Overdrive"
			pages = math.max(pages, workspace:GetAttribute("CM_Pages") or 0)
			local gs = GridService.state()
			if gs and gs.tampers ~= lastTampers then
				if gs.tampers > lastTampers then
					tampers += gs.tampers - lastTampers
				end
				lastTampers = gs.tampers
			end
			return phase() == "Results"
		end), "match " .. round .. " did not finish")
		local tags, reps, gadgets = 0, 0, 0
		for _, q in Participants.all() do
			tags += q.stats.tags
			reps += q.stats.repairs
			gadgets += q.stats.gadgets or 0
			balance.lifts += q.stats.lifts or 0
		end
		for _, bt in BotService.list() do
			for lvl in bt.levels or {} do
				balance.levels[lvl] = (balance.levels[lvl] or 0) + 1
			end
			for id, k in bt.itemsUsed or {} do
				balance.items[id] = (balance.items[id] or 0) + k
			end
		end
		local nights = string.split(workspace:GetAttribute("CM_NightResults") or "", ",")
		for _, w in nights do
			if w ~= "" then
				balance.nights += 1
				if w == "Guests" then
					balance.nightGuest += 1
				end
			end
		end
		local winner = workspace:GetAttribute("CM_Winner")
		balance[winner] += 1
		local reason = workspace:GetAttribute("CM_Reason")
		balance.reasons[reason] = (balance.reasons[reason] or 0) + 1
		balance.tampers += tampers
		balance.repairs += reps
		balance.tags += tags
		balance.keys += keys
		balance.pages += pages
		balance.gadgets += gadgets
		if od then
			balance.overdrive += 1
		end
		table.insert(results, string.format("%s (%s) - nights %s, keys %d, overdrive %s, pages %d, tampers %d, repairs %d, tags %d, gadgets %d",
			winner, reason, workspace:GetAttribute("CM_NightResults") or "", keys, tostring(od), pages, tampers, reps, tags, gadgets))
		assert(run(2, function()
			return phase() == "Lobby"
		end))
	end
	if BAL_ROUNDS <= 12 then
		print("       bot matches:\n         " .. table.concat(results, "\n         "))
	end
	local itemList = {}
	for id, k in balance.items do
		table.insert(itemList, id .. " " .. k)
	end
	table.sort(itemList)
	print(string.format("       guest match wins %d/%d (%.0f%%), guest night wins %d/%d, overdrive reached %d, avg keys %.1f, avg pages %.1f, Phantoms exposed %d",
		balance.Guests, BAL_ROUNDS, 100 * balance.Guests / BAL_ROUNDS, balance.nightGuest, balance.nights, balance.overdrive, balance.keys / BAL_ROUNDS, balance.pages / BAL_ROUNDS, balance.exposed))
	print(string.format("       avg tampers %.1f, repairs %.1f, tags %.1f, gadget uses %.1f, lift rides %d",
		balance.tampers / BAL_ROUNDS, balance.repairs / BAL_ROUNDS, balance.tags / BAL_ROUNDS, balance.gadgets / BAL_ROUNDS, balance.lifts))
	print(string.format("       floors visited (bot-matches): B1 %d, ground %d, 1st %d, 2nd/attic %d, tower %d", balance.levels[-1] or 0, balance.levels[0] or 0, balance.levels[1] or 0, balance.levels[2] or 0, balance.levels[3] or 0))
	print("       items used by bots: " .. table.concat(itemList, ", "))
	assert((balance.levels[-1] or 0) > 0 and (balance.levels[0] or 0) > 0 and (balance.levels[1] or 0) > 0 and (balance.levels[2] or 0) > 0, "bots did not traverse all floors")
	assert(#itemList >= 4, "bots used too few item kinds")
	assert(balance.gadgets > 0, "nobody used a class / Phantom gadget")
end)

step("7+ participants -> 2 Phantoms", function()
	local Roles = requireModule(Shared.Logic.Roles)
	local Match = requireModule(Shared.Config.Match)
	assert(Roles.phantomCount(7, Match.PhantomTable) == 2 and Roles.phantomCount(10, Match.PhantomTable) == 2)
end)

-- ---- client --------------------------------------------------------------------------------
local Hud, localPlayer, Input, Menus, Intro, Guide, ClientState
local Enum = roblox.Enum
local clientDir = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local function clientRequire(name)
	envOverrides.workspace = clientWorkspace
	local m = requireModule(clientDir[name])
	envOverrides.workspace = nil
	return m
end
step("client HUD builds and lays out on 780x360, 891x411, 2340x1080, 1024x768, desktop, console 1920x1080 safe area", function()
	localPlayer = Instance.new("Player")
	localPlayer.Name = "Phone"
	local playerGui = Instance.new("PlayerGui")
	playerGui.Parent = localPlayer
	local playersProxy = { LocalPlayer = localPlayer, GetPlayers = function()
		return { localPlayer }
	end }
	envOverrides.game = {
		GetService = function(_, name)
			if name == "Players" then
				return playersProxy
			end
			return game:GetService(name)
		end,
	}
	envOverrides.workspace = clientWorkspace
	Hud = requireModule(clientDir.Hud)
	Input = requireModule(clientDir.Input)
	ClientState = requireModule(clientDir.State)
	Menus = requireModule(clientDir.Menus)
	Intro = requireModule(clientDir.Intro)
	Guide = requireModule(clientDir.Guide)
	envOverrides.game = nil
	envOverrides.workspace = nil
	Hud.build(playerGui)
	local el = Hud.elements()
	for _, vp in HudLayout.TestViewports do
		local L = Hud.applyLayout(vp.w, vp.h, vp.touch, vp.console)
		-- read the rects back off the built instances
		local read = { el = {}, modal = L.modal, touch = vp.touch, console = vp.console, group = L.group }
		for name in L.el do
			local o = el[name]
			assert(o, "missing HUD element " .. name)
			read.el[name] = { x = o.Position.X.Offset, y = o.Position.Y.Offset, w = o.Size.X.Offset, h = o.Size.Y.Offset }
		end
		local problems = HudLayout.validate(read, vp.w, vp.h)
		assert(#problems == 0, vp.name .. ": " .. table.concat(problems, "; "))
		local t = read.el.Timer
		local safe = HudLayout.safeRect(vp.w, vp.h, vp.console)
		assert(math.abs(t.x + t.w / 2 - vp.w / 2) <= 1 and (vp.h > vp.w or t.y <= safe.y + 6), vp.name .. " timer not top centre")
		if vp.console then
			for name, r in read.el do
				assert(r.x >= vp.w * 0.05 - 1 and r.y >= vp.h * 0.05 - 1 and r.x + r.w <= vp.w * 0.95 + 1 and r.y + r.h <= vp.h * 0.95 + 1, "console: " .. name .. " outside the TV safe area")
			end
		end
	end
	Hud.applyLayout(1024, 768, true)
end)

step("client HUD states: lobby menu, guest day/night (hotbar, gadget), floor badge, phantom, wisp, finale meter, results", function()
	local el, modal = Hud.elements()
	local State = ClientState
	workspace:SetAttribute("CM_Phase", "Lobby")
	localPlayer:SetAttribute("Level", 3)
	localPlayer:SetAttribute("GearTokens", 120)
	Hud.update()
	assert(string.find(el.RoleChip.Text.Text, "LV 3"), "lobby chip " .. el.RoleChip.Text.Text)
	assert(el.MenuShop.Visible and el.MenuClass.Visible and el.MenuQuests.Visible and el.MenuSettings.Visible, "lobby menu")
	assert(not el.Button1.Visible, "buttons in lobby")
	localPlayer:SetAttribute("InMatch", true)
	localPlayer:SetAttribute("PState", "Guest")
	localPlayer:SetAttribute("PClass", "Mechanist")
	State.role = "Guest"
	workspace:SetAttribute("CM_Phase", "Night")
	workspace:SetAttribute("CM_Night", 1)
	localPlayer:SetAttribute("DryCell", 2)
	localPlayer:SetAttribute("Battery", 12)
	Hud.update()
	assert(not el.MenuShop.Visible and el.SettingsMini.Visible, "menu hidden in match, gear shown")
	assert(el.Button1.Visible and el.Button1.Text == "LAMP", "lantern button")
	assert(string.find(el.Button2.Text, "🔋") and string.find(el.Button2.Text, "2"), "cell button " .. el.Button2.Text)
	assert(el.Button3.Visible and el.Button3.Text == "GATE", "Mechanist gadget button: " .. el.Button3.Text)
	assert(el.Reboot.Visible and string.find(el.Reboot.Text.Text, "GRID REBOOT"), "reboot meter: " .. tostring(el.Reboot.Visible) .. " " .. el.Reboot.Text.Text)
	assert(string.find(el.Battery.Text.Text, "12"), "battery text")
	localPlayer:SetAttribute("PClass", "Illuminator")
	Hud.update()
	assert(el.Button3.Text == "FLASH", "Illuminator gadget")
	-- more items: hotbar slots, cycling, the selected chip + its one-line tip
	localPlayer:SetAttribute("Battery", 80)
	localPlayer:SetAttribute("SmokePellet", 1)
	localPlayer:SetAttribute("BrassWrench", 1)
	Input.setDevice("keyboard")
	Hud.update()
	local first = el.Button2.Text
	State.cycle(Hud.usableItems("Night", localPlayer:GetAttributes()), 1)
	Hud.update()
	assert(el.Button2.Text ~= first, "cycling did not change USE: " .. first)
	State.cycle(Hud.usableItems("Night", localPlayer:GetAttributes()), -1)
	Hud.update()
	assert(el.Button2.Text == first, "prev did not go back")
	assert(el.Inventory.BrassWrench.Visible and el.Inventory.SmokePellet.Visible and not el.Inventory.ClockworkDecoy.Visible, "item chips")
	assert(el.Inventory[State.selected].SelOutline.Enabled, "selected chip not outlined")
	assert(el.Inventory.DryCell.Slot.Text == "1" and el.Inventory.BrassWrench.Slot.Text == "3", "hotbar slot numbers (keyboard)")
	assert(Hud.slotItem(2) == "SmokePellet", "slot 2")
	assert(el.Inventory.Tip.Visible and string.find(el.Inventory.Tip.Text, Items.Defs[State.selected].kid, 1, true), "item tip")
	assert(not table.find(Hud.usableItems("Night", localPlayer:GetAttributes()), "BrassWrench"), "passive wrench is usable")
	assert(el.Button1.Glyph.Visible and el.Button1.Glyph.Text.Text == "F", "keyboard glyph F on LAMP")
	Input.setDevice("gamepad")
	Hud.update()
	assert(el.Button1.Glyph.Visible and el.Button1.Glyph.Image.Visible and string.find(el.Button1.Glyph.Image.Image, "ButtonR2"), "gamepad glyph image RT on LAMP")
	assert(el.Button2.Glyph.Image.Visible and string.find(el.Button2.Glyph.Image.Image, "ButtonY"), "gamepad glyph Y on USE")
	assert(el.Button3.Glyph.Image.Visible and string.find(el.Button3.Glyph.Image.Image, "ButtonB"), "gamepad glyph B on GADGET")
	Input.setDevice("touch")
	Hud.update()
	assert(not el.Button1.Glyph.Visible and el.Inventory.DryCell.Slot.Text == "", "touch: no glyphs / slot numbers")
	-- day: a disguised Phantom gets the same item buttons as a guest
	workspace:SetAttribute("CM_Phase", "Day")
	State.role = "Phantom"
	localPlayer:SetAttribute("PState", "Guest")
	localPlayer:SetAttribute("SpringBoots", 1)
	Hud.update()
	assert(el.Button1.Visible and string.find(el.Button1.Text, "👢"), "disguised phantom day item button: " .. el.Button1.Text)
	assert(el.RoleChip.Text.Text == "PHANTOM (secret)", "secret chip")
	-- floor badge + minimap + compass: in the Library (ground), breaker A (B1) tripped at night
	State.role = "Guest"
	workspace:SetAttribute("CM_Phase", "Night")
	local char = makeCharacter("Phone")
	char:PivotTo(CFrame.new(-66, 3, -24))
	localPlayer.Parent = Players -- (Lune keeps Character refs only on parented players)
	localPlayer.Character = char
	assert(localPlayer.Character == char, "fake character")
	built.breakers.A.model:SetAttribute("Tripped", true)
	Hud.update()
	local Minimap = requireModule(clientDir.Minimap)
	local ms = Minimap.state()
	assert(el.Minimap.Visible and el.Compass.Visible, "minimap hidden")
	assert(el.FloorBadge.Visible and el.FloorBadge.Text.Text == "GROUND FLOOR", "floor badge " .. el.FloorBadge.Text.Text)
	assert(string.find(ms.floorLabel.Text, "GROUND FLOOR"), "floor label " .. ms.floorLabel.Text)
	assert(ms.frames.library.Visible and not ms.frames.generator.Visible, "minimap shows the wrong floor")
	assert(ms.compassText.Text == "BREAKER A" and string.find(ms.compassSub.Text, "GO DOWN"), "compass " .. ms.compassText.Text .. " / " .. ms.compassSub.Text)
	print("       compass from the Library: " .. ms.compassText.Text .. " / " .. ms.compassSub.Text)
	local floorsSeen = {}
	for _, spot in { { 20, -17, 0 }, { 0, 3, 40 }, { -50, 23, 50 }, { -21, 43, -5 }, { 27, 63, -57 } } do
		char:PivotTo(CFrame.new(spot[1], spot[2], spot[3]))
		Hud.update()
		table.insert(floorsSeen, el.FloorBadge.Text.Text)
	end
	print("       floor badge: " .. table.concat(floorsSeen, " | "))
	assert(floorsSeen[1] == "B1  BOILER LEVEL" and floorsSeen[2] == "GROUND FLOOR" and floorsSeen[3] == "1ST FLOOR" and floorsSeen[4] == "2ND FLOOR  ATTIC" and floorsSeen[5] == "3RD FLOOR  TOWER", "floor badge names")
	built.breakers.A.model:SetAttribute("Tripped", false)
	-- finale meters
	workspace:SetAttribute("CM_Night", 3)
	workspace:SetAttribute("CM_Stage", "Showdown")
	workspace:SetAttribute("CM_Keys", "engine")
	Hud.update()
	assert(string.find(el.Reboot.Text.Text, "KEYS 1 / 3"), "keys meter " .. el.Reboot.Text.Text)
	workspace:SetAttribute("CM_Stage", "Overdrive")
	workspace:SetAttribute("CM_Ring", 12)
	workspace:SetAttribute("CM_RingNeed", 24)
	Hud.update()
	assert(string.find(el.Reboot.Text.Text, "DAWN RING 12 / 24"), "ring meter " .. el.Reboot.Text.Text)
	assert(string.find(el.Objective.Text.Text, "RING"), "overdrive objective " .. el.Objective.Text.Text)
	workspace:SetAttribute("CM_Stage", nil)
	workspace:SetAttribute("CM_Night", 1)
	char:PivotTo(CFrame.new(0, 3, 132)) -- back to the terrace
	for _, id in { "SmokePellet", "BrassWrench", "SpringBoots" } do
		localPlayer:SetAttribute(id, nil)
	end
	State.role = "Phantom"
	localPlayer:SetAttribute("PState", "Phantom")
	Hud.update()
	assert(el.Button1.Text == "TAG" and not el.Button2.Visible, "phantom buttons (night 1: no glide)")
	assert(el.RoleChip.Text.Text == "PHANTOM")
	workspace:SetAttribute("CM_Night", 2)
	Hud.update()
	assert(el.Button2.Visible and el.Button2.Text == "GLIDE", "night 2 phantom glide")
	workspace:SetAttribute("CM_Night", 1)
	localPlayer:SetAttribute("PState", "Wisp")
	Hud.update()
	assert(el.Button1.Text == "FLICKER" and el.Button2.Text == "SLICK", "wisp buttons")
	State.results = { winner = "Guests", reason = "Dawn Reboot complete - sunrise!", won = false, tokens = 7, nights = { "Guests", "Phantoms" }, roster = { { name = "Cogsworth", role = "Phantom" } } }
	workspace:SetAttribute("CM_Phase", "Results")
	Hud.update()
	assert(modal.Results.Visible and modal.Results.Title.Text == "GUESTS WIN", "results card")
	assert(string.find(modal.Results.Roster.Text, "Cogsworth") and string.find(modal.Results.Nights.Text, "Night 2"), "results details")
	Hud.showRole("Phantom", { "Ivy" })
	workspace:SetAttribute("CM_Phase", "Day")
	Hud.update()
	assert(modal.RoleCard.Visible and string.find(modal.RoleCard.Line3.Text, "Ivy"), "role card")
	Hud.showItem("🔧", "Brass wrench", Items.Defs.BrassWrench.kid)
	Hud.update()
	assert(modal.ItemCard.Visible and modal.ItemCard.Kid.Text == "Fix things faster!", "item pick-up card")
	State.roleShownAt = nil
	localPlayer:SetAttribute("PState", "Guest")
	State.role = "Guest"
end)

step("gamepad + keyboard input paths (ContextActionService): every action, LB/RB/D-pad cycling, 1-9, Q/E, glyphs", function()
	local fired = {}
	Input.bind(function(a, arg)
		table.insert(fired, { a = a, arg = arg })
	end)
	local Begin = Enum.UserInputState.Begin
	local K = Enum.KeyCode
	local expect = {
		{ K.ButtonR2, "primary" }, { K.ButtonY, "use" }, { K.ButtonB, "gadget" }, { K.ButtonL1, "prev" }, { K.ButtonR1, "next" },
		{ K.DPadLeft, "prev" }, { K.DPadRight, "next" }, { K.DPadUp, "info" }, { K.DPadDown, "menu" }, { K.ButtonL2, "lantern" },
		{ K.F, "primary" }, { K.V, "use" }, { K.G, "gadget" }, { K.Q, "prev" }, { K.E, "next" }, { K.I, "info" }, { K.M, "menu" },
	}
	for _, e in expect do
		local found = nil
		for name, b in boundActions do
			if string.sub(name, 1, 3) == "CM_" and table.find(b.keys, e[1]) then
				found = name
			end
		end
		assert(found, "no binding for " .. e[1].Name)
		local n = #fired
		boundActions[found].fn(found, Begin, { KeyCode = e[1] })
		assert(#fired == n + 1 and fired[#fired].a == e[2], e[1].Name .. " -> " .. tostring(fired[#fired] and fired[#fired].a) .. " (want " .. e[2] .. ")")
	end
	-- 1..9 select hotbar slots
	for i = 1, 9 do
		local b = boundActions["CM_slot" .. i]
		assert(b and b.keys[1] == ({ K.One, K.Two, K.Three, K.Four, K.Five, K.Six, K.Seven, K.Eight, K.Nine })[i], "slot key " .. i)
		b.fn("CM_slot" .. i, Begin, { KeyCode = b.keys[1] })
		assert(fired[#fired].a == "slot" and fired[#fired].arg == i, "slot " .. i)
	end
	-- E yields to a visible ProximityPrompt (chests, breakers, lift)
	Input.setPromptsShown(1)
	local n = #fired
	local res = boundActions.CM_next.fn("CM_next", Begin, { KeyCode = K.E })
	assert(#fired == n and res == Enum.ContextActionResult.Pass, "E stole a prompt's key")
	boundActions.CM_next.fn("CM_next", Begin, { KeyCode = K.ButtonR1 })
	assert(#fired == n + 1, "RB must still cycle while a prompt shows")
	Input.setPromptsShown(0)
	-- device detection from the last input
	Input.noteInputType(Enum.UserInputType.Gamepad1)
	assert(Input.device() == "gamepad")
	local t, img = Input.glyph("use")
	assert(t == "Y" and img and string.find(img, "ButtonY"), "gamepad glyph for use")
	Input.noteInputType(Enum.UserInputType.Keyboard)
	assert(Input.device() == "keyboard" and Input.glyph("primary") == "F")
	Input.noteInputType(Enum.UserInputType.Touch)
	assert(Input.device() == "touch" and Input.glyph("primary") == nil)
	print(string.format("       %d bindings checked (gamepad + keyboard) + 9 slot keys", #expect))
end)

step("menus with a gamepad: shop / class / settings / vote / items open, first button selected, B closes", function()
	local sent = {}
	local replay = {}
	Menus.init(function(k, a)
		table.insert(sent, { k = k, a = a })
	end, function(w)
		table.insert(replay, w)
	end)
	Input.setDevice("gamepad")
	localPlayer:SetAttribute("Owned", "mask_brass,lantern_brass,trail_spark,emote_wave")
	localPlayer:SetAttribute("Equip_Mask", "mask_brass")
	localPlayer:SetAttribute("Class", "Mechanist")
	local GuiService = game:GetService("GuiService")
	localPlayer:SetAttribute("DryCell", 1)
	localPlayer:SetAttribute("QuestDaily", "daily_play:1/1:1|daily_chests:2/4:0|daily_repair:0/2:0")
	localPlayer:SetAttribute("QuestWeekly", "weekly_matches:3/6:0|weekly_win:0/2:0")
	localPlayer:SetAttribute("Season", ":1:0")
	for _, kind in { "Shop", "Class", "Settings", "Items", "Quests" } do
		Menus.open(kind)
		local f = Menus.frame()
		assert(f.Visible and ClientState.panel == kind, kind .. " did not open")
		local fb = Menus.firstButton()
		assert(fb and fb.Selectable, kind .. ": no selectable first button")
		local okSel, sel = pcall(function()
			return GuiService.SelectedObject
		end)
		assert(not okSel or sel == nil or sel == fb, kind .. ": gamepad selection not on the first button")
		assert(boundActions.CM_closePanel and table.find(boundActions.CM_closePanel.keys, Enum.KeyCode.ButtonB), "B does not close " .. kind)
		local buttons = 0
		for _, d in f:GetDescendants() do
			if d:IsA("TextButton") then
				buttons += 1
				assert(d.Selectable, kind .. ": button " .. d.Name .. " not gamepad-selectable")
			end
		end
		assert(buttons >= 2, kind .. " has no buttons")
		boundActions.CM_closePanel.fn("CM_closePanel", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.ButtonB })
		assert(not f.Visible and ClientState.panel == nil, kind .. " did not close on B")
	end
	-- shop content: every cosmetic of the tab is listed; Robux tab shows placeholder items
	Menus.open("Shop")
	local f = Menus.frame()
	local count = 0
	for _, d in f:GetDescendants() do
		if d:IsA("TextButton") and string.sub(d.Name, 1, 5) == "Item_" then
			count += 1
		end
	end
	assert(count == #Cosmetics.ofKind("Mask"), "mask tab lists " .. count)
	Menus.close()
	-- v1.2: quests panel rows (5 quests) + live refresh on a mirror change; starter/season hidden
	Menus.open("Quests")
	local rowsN = 0
	for _, d in Menus.frame():GetDescendants() do
		if d:IsA("TextButton") and string.sub(d.Name, 1, 6) == "Quest_" then
			rowsN += 1
		end
	end
	assert(rowsN == 5, "quest rows " .. rowsN)
	localPlayer:SetAttribute("QuestDaily", "daily_play:1/1:1|daily_chests:4/4:1|daily_repair:0/2:0")
	Menus._refreshQuests()
	taskLib.wait(0.05)
	local doneRow = Menus.frame():FindFirstChild("Quest_daily_chests", true)
	assert(ClientState.panel == "Quests" and doneRow and string.find(doneRow.Text, "4/4", 1, true), "quest panel did not live-refresh")
	Menus.close()
	assert(Menus.robuxHidden("SeasonWinter"), "season pass offered while no season is scheduled")
	localPlayer:SetAttribute("StarterPackBought", false)
	assert(not Menus.robuxHidden("StarterPack"), "starter hidden before purchase")
	localPlayer:SetAttribute("StarterPackBought", true)
	assert(Menus.robuxHidden("StarterPack"), "starter offered after purchase")
	localPlayer:SetAttribute("StarterPackBought", false)
	-- vote panel lists everyone in the match (bots too), never yourself
	local botsFolder = workspace:FindFirstChild("Bots") or Instance.new("Folder")
	botsFolder.Name = "Bots"
	botsFolder.Parent = workspace
	botsFolder:ClearAllChildren()
	for i, nm in { "Ada", "Bram" } do
		local m = Instance.new("Model")
		m.Name = nm
		m:SetAttribute("InMatch", true)
		m:SetAttribute("PId", "B9" .. i)
		m:SetAttribute("PName", nm)
		m:SetAttribute("PState", "Guest")
		m:SetAttribute("Ribbon", "Crimson")
		m.Parent = botsFolder
	end
	Menus.open("Vote")
	local names = {}
	for _, d in Menus.frame():GetDescendants() do
		if d:IsA("TextButton") and string.sub(d.Name, 1, 5) == "Vote_" then
			table.insert(names, d.Name)
		end
	end
	table.sort(names)
	assert(table.concat(names, ",") == "Vote_B91,Vote_B92", "vote list " .. table.concat(names, ","))
	Menus.close()
	botsFolder:ClearAllChildren()
	Input.setDevice("touch")
end)

step("story intro: camera pans + dialogue (Bellows / Sterling), skippable, replayable; guided first match steps", function()
	local done = {}
	Intro.start(function(skipped)
		table.insert(done, skipped)
	end)
	assert(Intro.playing() and ClientState.inIntro, "intro not playing")
	local box = Intro.box()
	assert(box.Visible and box.Skip.Selectable, "dialogue box / skip button")
	local cf0 = clientWorkspace.CurrentCamera.CFrame
	local total = 0
	for _, s in Intro.Shots do
		total += s.seconds
	end
	Intro.step(2)
	assert(string.find(box.Speaker.Text, "Bellows") and #box.Line.Text > 5, "first line: " .. box.Speaker.Text .. " / " .. box.Line.Text)
	assert(clientWorkspace.CurrentCamera.CFrame ~= cf0, "camera did not move")
	local speakers = {}
	for _ = 1, math.ceil(total / 0.5) + 2 do
		if Intro.playing() then
			speakers[box.Speaker.Text] = true
			Intro.step(0.5)
		end
	end
	assert(not Intro.playing() and done[1] == false, "intro did not finish")
	assert(speakers["Bellows the Butler"] and speakers["Professor Sterling"], "both speakers talk")
	assert(not box.Visible and not ClientState.inIntro, "intro UI left on screen")
	Intro.start(function(skipped)
		table.insert(done, skipped)
	end)
	assert(boundActions.CM_skipIntro and table.find(boundActions.CM_skipIntro.keys, Enum.KeyCode.ButtonB), "gamepad skip")
	boundActions.CM_skipIntro.fn("CM_skipIntro", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.ButtonA })
	assert(not Intro.playing() and done[2] == true, "skip did not stop the intro")
	print(string.format("       intro: %d shots, %.0f s, skippable (button, A/B, Space)", #Intro.Shots, total))
	-- guided first match (pure step picker)
	local function pick(ctx)
		local s = Guide.pick(ctx)
		return s and s.text or "-"
	end
	assert(pick({ phase = "Day", who = "Guest", found = 0 }) == "Find a chest!", "step 1")
	assert(string.find(pick({ phase = "Day", who = "Guest", found = 1 }), "more chests"), "step 2")
	assert(pick({ phase = "Night", who = "Guest", found = 3, tripped = true }) == "Fix the RED breaker!", "night step")
	assert(string.find(pick({ phase = "Night", who = "Guest", found = 3, tripped = true, phantomNear = true }), "LAMP"), "lamp step")
	assert(string.find(pick({ phase = "Day", who = "Phantom", found = 0 }), "TAMPER"), "phantom step")
	assert(string.find(pick({ phase = "Night", who = "Guest", found = 3, stage = "Showdown" }), "golden key"), "finale key step")
	assert(string.find(pick({ phase = "Night", who = "Guest", found = 3, stage = "Showdown", carryKey = "engine" }), "Exit Console"), "carry step")
	assert(string.find(pick({ phase = "Night", who = "Guest", found = 3, stage = "Overdrive" }), "ring"), "ring step")
	assert(string.find(pick({ phase = "Night", who = "Wisp", found = 0 }), "Wisp"), "wisp step")
	local longest = 0
	for _, ctx in { { phase = "Day", who = "Guest", found = 0 }, { phase = "Night", who = "Guest", found = 3, tripped = true }, { phase = "Day", who = "Phantom", found = 0 } } do
		longest = math.max(longest, #string.split(Guide.pick(ctx).text, " "))
	end
	assert(longest <= 6, "guide steps must stay short (<= 6 words)")
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
