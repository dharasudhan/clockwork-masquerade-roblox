-- The Clockwork Masquerade: Mystery at Sterling Manor - server entry.
local Players = game:GetService("Players")
local Server = script
local function m(name)
	return require(Server:WaitForChild(name))
end

Players.CharacterAutoLoads = true
m("ManorBuilder").build()
m("LightingService").apply("Lobby")
m("DataService").init()
local MatchService = m("MatchService")
MatchService.init()
MatchService.start()
print("[Clockwork Masquerade] server ready")
