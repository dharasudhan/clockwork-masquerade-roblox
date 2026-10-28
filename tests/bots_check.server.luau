-- Open Cloud Luau Execution entry: a FULL bot-only round in the REAL engine (real rigs from
-- HumanoidDescription, real lighting, raycasts against real walls, ProximityPrompts, the
-- 10 Hz loop on Heartbeat) on a short clock: Lobby 2 s, Day 25 s, Night 40 s, Results 3 s.
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
MatchService.setDurations({ lobby = 2, day = 25, night = 40, results = 3 })
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
assert(waitFor("Results", 45), "no Results")
local winner, reason = workspace:GetAttribute("CM_Winner"), workspace:GetAttribute("CM_Reason")
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
	"BOTS OK: rig %s, chests %d, tampers %d, tags %d, wisps %d, result %s (%s)",
	rigKind, chests, tampers, tags, wisps, tostring(winner), tostring(reason)
)
print(summary)
return summary
