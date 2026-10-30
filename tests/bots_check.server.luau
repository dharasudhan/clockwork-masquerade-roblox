-- Open Cloud Luau Execution entry: a FULL bot-only round in the REAL engine (real rigs from
-- HumanoidDescription, real lighting, raycasts against real walls, ProximityPrompts, the
-- 10 Hz loop on Heartbeat) on a short clock: Lobby 2 s, Day 25 s, Night 30 s, Dawn 2 s, Showdown 30 s,
-- Overdrive 10 s, Results 3 s: the whole v1.0 3-night match on the 5-level manor (bots route over
-- stairs and ride the service lift; items are used).
-- NOTE: Luau Execution sessions do not step physics (Humanoid:MoveTo cannot walk there), so
-- bots move through their stuck-hop fallback (shortened here); real servers walk normally.
--   python3 scripts/luau_exec.py build/ClockworkMasquerade.rbxl tests/bots_check.server.luau
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local function m(name)
	return require(Server:WaitForChild(name))
end
local MatchService = m("MatchService")
local BotService = m("BotService")
local Participants = m("Participants")
local GridService = m("GridService")
BotService.setUnstickSeconds(0.4)
MatchService.setDurations({ lobby = 2, day = 25, night = 30, dawn = 2, showdown = 30, overdrive = 10, results = 3 })
if workspace:GetAttribute("CM_Phase") == nil then
	m("ManorBuilder").build()
	m("LightingService").apply("Lobby")
	m("DataService").init()
	MatchService.init()
	MatchService.start()
end
local function waitFor(phase, timeout)
	local t0 = os.clock()
	while workspace:GetAttribute("CM_Phase") ~= phase and os.clock() - t0 < timeout do
		task.wait(0.2)
	end
	return workspace:GetAttribute("CM_Phase") == phase
end
assert(waitFor("Day", 10), "no Day")
assert(BotService.count() == 6, "bots " .. BotService.count())
assert(#Participants.phantoms() == 1, "phantoms")
local rigOk = 0
for _, b in BotService.list() do
	if b.model:FindFirstChildOfClass("Humanoid") and b.model:FindFirstChild("HumanoidRootPart") then
		rigOk += 1
	end
end
assert(rigOk == 6, "rigs")
local rigKind = if BotService.list()[1].model:FindFirstChild("UpperTorso") then "R15 HumanoidDescription" else "fallback block rig"
assert(waitFor("Night", 30), "no Night")
local chests, tampers = 0, GridService.state().tampers
for _, p in Participants.all() do
	chests += p.stats.chests
end
local ph = Participants.phantoms()[1]
assert(ph.model:FindFirstChild("PhantomMask"), "no mask")
assert(game:GetService("Lighting"):GetAttribute("Preset") == "Night", "night lighting")
-- v1.4.1 night shroud on real R15 rigs: the Phantom wears the uniform cloak, nothing of its own
task.wait(0.5)
local Shroud = require(game:GetService("ReplicatedStorage").Shared.Logic.Shroud)
local Manor = require(game:GetService("ReplicatedStorage").Shared.Config.Manor)
local ManorLayout = require(game:GetService("ReplicatedStorage").Shared.Logic.ManorLayout)
local cloak = ph.model:FindFirstChild(Shroud.ModelName)
assert(cloak and #cloak:GetChildren() >= 10 and ph.model:GetAttribute(Shroud.Attr), "night Phantom not shrouded")
for _, c in ph.model:GetChildren() do
	assert(not (c:IsA("Accessory") or c:IsA("Clothing") or c:IsA("BodyColors")), "night Phantom still wears " .. c.ClassName)
end
local shroudParts = #cloak:GetChildren()
-- v1.4.1 Dawn Scatter: remember where everyone stood when the night ended
local before = {}
while workspace:GetAttribute("CM_Phase") == "Night" do
	for _, p in Participants.all() do
		local pos = Participants.pos(p)
		if pos then
			before[p.id] = ManorLayout.roomAt(Manor, pos.X, pos.Y, pos.Z)
		end
	end
	task.wait(0.05)
end
local sawDawn = workspace:GetAttribute("CM_Phase") == "Dawn" or waitFor("Dawn", 40)
local scatterOk = "n/a"
if sawDawn then
	local t0 = os.clock()
	while workspace:GetAttribute("CM_ScatterAt") == nil and os.clock() - t0 < 5 do
		task.wait(0.05)
	end
	assert(workspace:GetAttribute("CM_ScatterAt"), "no dawn scatter")
	assert(workspace:GetAttribute("CM_BlackoutAt") and workspace:GetAttribute("CM_ScatterAt") >= workspace:GetAttribute("CM_BlackoutAt"), "scatter before the blackout")
	assert(workspace:GetAttribute("CM_ScatterMoved") == #Participants.all(), "not everyone scattered")
	local rooms, distinct = {}, 0
	for _, p in Participants.all() do
		local pos = Participants.pos(p)
		local room = pos and ManorLayout.roomAt(Manor, pos.X, pos.Y, pos.Z)
		assert(room and room ~= before[p.id], p.name .. " not moved to another room")
		if not rooms[room] then
			rooms[room] = true
			distinct += 1
		end
		assert(not p.model:GetAttribute(Shroud.Attr) and not p.model:FindFirstChild(Shroud.ModelName), "shroud left on " .. p.name)
	end
	assert(distinct == #Participants.all(), "two people scattered into one room")
	scatterOk = string.format("%d moved, %d rooms", #Participants.all(), distinct)
end
assert(waitFor("Results", 240), "no Results")
local winner, reason = workspace:GetAttribute("CM_Winner"), workspace:GetAttribute("CM_Reason")
local levels, items, lifts = {}, 0, 0
for _, b in BotService.list() do
	for lvl in b.levels or {} do
		levels[lvl] = true
	end
	for _, k in b.itemsUsed or {} do
		items += k
	end
	lifts += b.stats and b.stats.lifts or 0
end
local floors = 0
for lvl = -1, 3 do
	floors += if levels[lvl] then 1 else 0
end
assert(floors >= 2, "bots stayed on one floor")
local tags, wisps = 0, 0
for _, p in Participants.all() do
	tags += p.stats.tags
	if p.state == "Wisp" then
		wisps += 1
	end
end
assert(waitFor("Lobby", 8), "no return to Lobby")
assert(BotService.count() == 0, "bots not cleaned up")
local summary = string.format(
	"BOTS OK: rig %s, shroud %d parts, scatter %s, chests %d, tampers %d, tags %d, wisps %d, floors visited %d/5, items used %d, lift rides %d, dawn %s, result %s (%s)",
	rigKind, shroudParts, scatterOk, chests, tampers, tags, wisps, floors, items, lifts, tostring(sawDawn), tostring(winner), tostring(reason)
)
print(summary)
return summary
