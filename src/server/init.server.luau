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
m("FameService").init() -- v1.6.1: Hall of Fame board (needs the lobby built, DataService up)
local MatchService = m("MatchService")
MatchService.init()
MatchService.start()
print("[Clockwork Masquerade] server ready")
