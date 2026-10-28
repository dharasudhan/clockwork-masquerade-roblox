-- Player saves via ProfileStore (session-locked DataStore, Apache-2.0, MadStudioRoblox).
-- Data: GearTokens, Wins per side, Played (Config/DataTemplate), sanitised on load
-- (Logic/SaveData) so a corrupt or old save falls back to safe defaults. Bots never touch it.
-- In Studio without API access ProfileStore falls back to its mock store automatically.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ProfileStore = require(ServerScriptService:WaitForChild("Packages"):WaitForChild("ProfileStore")) :: any
local Template = require(Shared.Config.DataTemplate)
local SaveData = require(Shared.Logic.SaveData)

local DataService = {}

DataService.StoreName = "ClockworkMasquerade_PlayerData_v1"

local store: any = nil
local profiles: { [Player]: any } = {}

function DataService.get(player: Player): any?
	local p = profiles[player]
	return if p then p.Data else nil
end

local function publish(player: Player, data)
	player:SetAttribute("GearTokens", data.GearTokens)
	player:SetAttribute("WinsGuest", data.Wins.Guest)
	player:SetAttribute("WinsPhantom", data.Wins.Phantom)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		(ls :: any)["Gear Tokens"].Value = data.GearTokens;
		(ls :: any).Wins.Value = data.Wins.Guest + data.Wins.Phantom
	end
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("Your save could not be loaded. Please rejoin!")
		end
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	local fixes = SaveData.sanitize(profile.Data, Template)
	if fixes > 0 then
		warn(string.format("[DataService] repaired %d save field(s) for %d", fixes, player.UserId))
	end
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your session was opened on another server. Please rejoin.")
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local tokens = Instance.new("IntValue")
	tokens.Name = "Gear Tokens"
	tokens.Parent = ls
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = ls
	ls.Parent = player
	profiles[player] = profile
	publish(player, profile.Data)
end

-- End of a match: +1 Played, +1 Wins[side] when won, + Gear Tokens.
function DataService.award(player: Player, side: string, won: boolean, tokens: number): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	data.Played += 1
	if won and data.Wins[side] ~= nil then
		data.Wins[side] += 1
	end
	data.GearTokens += math.max(0, math.floor(tokens))
	publish(player, data)
	return true
end

function DataService.init()
	store = ProfileStore.New(DataService.StoreName, Template)
	ProfileStore.OnError:Connect(function(message, storeName, key)
		warn("[ProfileStore]", storeName, key, message)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
