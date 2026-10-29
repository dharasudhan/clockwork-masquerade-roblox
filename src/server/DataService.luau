-- Player saves via ProfileStore (session-locked DataStore, Apache-2.0, MadStudioRoblox), v2:
-- Gear Tokens, XP/level, wins, settings (music/SFX/hints), intro + tutorial flags, class,
-- daily login streak, owned + equipped cosmetics, badges, lifetime stats, and the receipt log
-- that makes developer-product grants idempotent. Sanitised on load (Logic/SaveData) so a
-- corrupt or old (v1) save falls back to safe defaults. Bots never touch it.
-- In Studio without API access ProfileStore falls back to its mock store automatically.
-- Public mirror for the client = attributes on the Player (GearTokens, Level, XP, XPNext,
-- Owned "id,id", Equip_<Kind>, Class, Set_Music/Set_Sfx/Set_Hints, IntroSeen, TutorialDone,
-- DailyStreak, Passes "VIP,...").
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local BadgeService = game:GetService("BadgeService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ProfileStore = require(ServerScriptService:WaitForChild("Packages"):WaitForChild("ProfileStore")) :: any
local Template = require(Shared.Config.DataTemplate)
local ProgCfg = require(Shared.Config.Progression)
local Cosmetics = require(Shared.Config.Cosmetics)
local Gadgets = require(Shared.Config.Gadgets)
local SaveData = require(Shared.Logic.SaveData)
local Progression = require(Shared.Logic.Progression)
local Clock = require(script.Parent.Clock)
local Net = require(script.Parent.Net)

local DataService = {}

DataService.StoreName = "ClockworkMasquerade_PlayerData_v1"

local store: any = nil
local profiles: { [Player]: any } = {}
local passes: { [Player]: { [string]: boolean } } = {}
local loadedHooks: { (Player) -> () } = {}

function DataService.get(player: Player): any?
	local p = profiles[player]
	return if p then p.Data else nil
end

function DataService.passes(player: Player): { [string]: boolean }
	passes[player] = passes[player] or {}
	return passes[player]
end

function DataService.onLoaded(cb: (Player) -> ())
	table.insert(loadedHooks, cb)
end

local function ownedList(player: Player, data): string
	local out = {}
	for _, c in Cosmetics.Items do
		if Progression.owns(c, data, DataService.passes(player)) then
			table.insert(out, c.id)
		end
	end
	return table.concat(out, ",")
end

function DataService.publish(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local level, into, need = Progression.levelFor(data.XP, ProgCfg)
	data.Level = level
	player:SetAttribute("GearTokens", data.GearTokens)
	player:SetAttribute("WinsGuest", data.Wins.Guest)
	player:SetAttribute("WinsPhantom", data.Wins.Phantom)
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", into)
	player:SetAttribute("XPNext", need)
	player:SetAttribute("Owned", ownedList(player, data))
	for kind, id in data.Equipped do
		player:SetAttribute("Equip_" .. kind, id)
	end
	player:SetAttribute("Class", data.Class)
	player:SetAttribute("Set_Music", data.Settings.Music)
	player:SetAttribute("Set_Sfx", data.Settings.Sfx)
	player:SetAttribute("Set_Hints", data.Settings.Hints)
	player:SetAttribute("IntroSeen", data.IntroSeen)
	player:SetAttribute("TutorialDone", data.TutorialDone)
	player:SetAttribute("DailyStreak", data.Daily.Streak)
	player:SetAttribute("Played", data.Played)
	local pl = {}
	for k, v in DataService.passes(player) do
		if v then
			table.insert(pl, k)
		end
	end
	table.sort(pl)
	player:SetAttribute("Passes", table.concat(pl, ","))
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		(ls :: any)["Gear Tokens"].Value = data.GearTokens;
		(ls :: any).Wins.Value = data.Wins.Guest + data.Wins.Phantom;
		(ls :: any).Level.Value = level
	end
end

-- ---- badges --------------------------------------------------------------------------------
-- Records the badge in the save; awards it on Roblox once its id exists (Config/Progression).
function DataService.badge(player: Player, key: string): boolean
	local data = DataService.get(player)
	local def = ProgCfg.Badges[key]
	if not data or not def then
		return false
	end
	local first = not data.Badges[key]
	data.Badges[key] = true
	if def.id and def.id ~= 0 then
		task.spawn(function()
			pcall(function()
				if not BadgeService:UserHasBadgeAsync(player.UserId, def.id) then
					BadgeService:AwardBadge(player.UserId, def.id)
				end
			end)
		end)
	end
	if first then
		Net.send(player, { kind = "badge", key = key, name = def.name, desc = def.desc })
	end
	return first
end

-- ---- daily login -----------------------------------------------------------------------------
function DataService.today(): number
	return math.floor(Clock.wall() / 86400)
end

function DataService.claimDaily(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local streak, granted = Progression.daily(data.Daily.LastDay, data.Daily.Streak, DataService.today(), #ProgCfg.Daily)
	if not granted then
		return nil
	end
	data.Daily.LastDay = DataService.today()
	data.Daily.Streak = streak
	local reward = ProgCfg.Daily[streak]
	data.GearTokens += reward.tokens
	if reward.item then
		data.Owned[reward.item] = true
	end
	if streak == #ProgCfg.Daily then
		DataService.badge(player, "WeekStreak")
	end
	DataService.publish(player)
	Net.send(player, { kind = "daily", day = streak, tokens = reward.tokens, item = reward.item, days = #ProgCfg.Daily })
	return { day = streak, tokens = reward.tokens, item = reward.item }
end

-- ---- settings / flags / class --------------------------------------------------------------
function DataService.setSetting(player: Player, key: any, value: any): boolean
	local data = DataService.get(player)
	if not data or type(key) ~= "string" or type(value) ~= "boolean" or data.Settings[key] == nil then
		return false
	end
	data.Settings[key] = value
	DataService.publish(player)
	return true
end

function DataService.setFlag(player: Player, key: string): boolean
	local data = DataService.get(player)
	if not data or (key ~= "IntroSeen" and key ~= "TutorialDone") then
		return false
	end
	data[key] = true
	DataService.publish(player)
	return true
end

function DataService.setClass(player: Player, class: any): boolean
	local data = DataService.get(player)
	if not data or type(class) ~= "string" or not Gadgets.Classes[class] then
		return false
	end
	data.Class = class
	DataService.publish(player)
	return true
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
	profile.Data.Version = Template.Version
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
	for _, n in { "Gear Tokens", "Wins", "Level" } do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = ls
	end
	ls.Parent = player
	profiles[player] = profile
	DataService.publish(player)
	for _, cb in loadedHooks do
		task.spawn(cb, player)
	end
	-- re-award recorded badges whose ids were filled in after they were earned
	for key in profile.Data.Badges do
		local def = ProgCfg.Badges[key]
		if def and def.id ~= 0 then
			DataService.badge(player, key)
		end
	end
	DataService.badge(player, "Welcome")
	DataService.claimDaily(player)
end

-- End of a match: +1 Played, +1 Wins[side] when won, + Gear Tokens (+XP = base tokens),
-- lifetime stats, badges. Returns saved, newLevel?
function DataService.award(player: Player, side: string, won: boolean, tokens: number, xp: number?, stats: any?): (boolean, number?)
	local data = DataService.get(player)
	if not data then
		return false
	end
	local before = Progression.levelFor(data.XP, ProgCfg)
	data.Played += 1
	if won and data.Wins[side] ~= nil then
		data.Wins[side] += 1
	end
	data.GearTokens += math.max(0, math.floor(tokens))
	data.XP += math.max(0, math.floor(xp or tokens))
	if stats then
		data.Stats.Repairs += stats.repairs or 0
		data.Stats.Exposes += stats.exposes or 0
		data.Stats.Keys += stats.keys or 0
		data.Stats.Pages += stats.pages or 0
		data.Stats.Tags += stats.tags or 0
		if data.Stats.Repairs >= ProgCfg.ChiefEngineerRepairs then
			DataService.badge(player, "ChiefEngineer")
		end
		if (stats.exposes or 0) > 0 then
			DataService.badge(player, "Detective")
		end
		if (stats.keys or 0) > 0 then
			DataService.badge(player, "KeyKeeper")
		end
		if (stats.pages or 0) > 0 then
			DataService.badge(player, "Archivist")
		end
	end
	if won then
		DataService.badge(player, if side == "Guest" then "FirstDawn" else "PhantomWin")
	end
	DataService.publish(player)
	local after = Progression.levelFor(data.XP, ProgCfg)
	return true, if after > before then after else nil
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
		passes[player] = nil
	end)
end

return DataService
