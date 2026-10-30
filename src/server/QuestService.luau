-- Quests + season XP (server). Awards Gear Tokens for daily/weekly quests after each match
-- and accrues season XP (see Config/Season, Logic/Season). Quest selection is deterministic
-- per day/week, so a player's three dailies are the same for everyone that day.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local QuestsCfg = require(Shared.Config.Quests)
local Quests = require(Shared.Logic.Quests)
local Season = require(Shared.Config.Season)
local SeasonLogic = require(Shared.Logic.Season)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)

local QuestService = {}

-- friendship lookups are web calls: cache the pair result for the rest of the day
local friendCache: { [string]: boolean } = {}
local cacheDay = 0

local function friendKey(a: number, b: number): string
	return (math.min(a, b)) .. ":" .. (math.max(a, b))
end

local function isFriendWithAny(player: Player, others: { Player }): boolean
	local today = DataService.today()
	if cacheDay ~= today then
		cacheDay = today
		friendCache = {}
	end
	for _, o in others do
		if o ~= player then
			local key = friendKey(player.UserId, o.UserId)
			local hit = friendCache[key]
			if hit == nil then
				local ok, isf = pcall(function()
					return player:IsFriendsWith(o.UserId)
				end)
				hit = ok and isf == true
				friendCache[key] = hit
			end
			if hit then
				return true
			end
		end
	end
	return false
end

-- Seed the save with today's dailies / this week's weeklies (called on load and before a
-- match end, so late-night matches still roll over correctly).
function QuestService.ensure(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local today = DataService.today()
	if data.Quests.Day ~= today then
		data.Quests.Day = today
		data.Quests.Daily = Quests.pick(QuestsCfg.DailyPool, QuestsCfg.DailyCount, today)
	end
	local week = Quests.weekOf(today)
	if data.Quests.Week ~= week then
		data.Quests.Week = week
		data.Quests.Weekly = Quests.pick(QuestsCfg.WeeklyPool, QuestsCfg.WeeklyCount, week)
	end
end

-- Season XP for a finished match (called by DataService.award).
function QuestService.seasonXp(data, xp: number)
	if not SeasonLogic.active(Season, DataService.today()) then
		return nil
	end
	if data.Season.Id ~= Season.Id then
		data.Season.Id = Season.Id
		data.Season.XP = 0
		data.Season.Tier = 1
	end
	data.Season.XP += math.max(0, math.floor(xp))
	local tier = SeasonLogic.tierFor(data.Season.XP, Season)
	if tier > (data.Season.Tier or 1) then
		data.Season.Tier = tier
		return tier
	end
	return nil
end

-- End of a match: progress quests, pay out, notify. `others` = human players in the match.
function QuestService.onMatchEnd(player: Player, stats, won: boolean, others: { Player })
	local data = DataService.get(player)
	if not data then
		return
	end
	QuestService.ensure(player)
	local withFriend = isFriendWithAny(player, others)
	local gains = Quests.gains(stats, won, withFriend)
	local earned = 0
	for _, events in { Quests.apply(data.Quests.Daily, gains), Quests.apply(data.Quests.Weekly, gains) } do
		for _, e in events do
			if e.completed then
				earned += e.tokens or 0
				Net.send(player, { kind = "quest", id = e.id, text = e.text, tokens = e.tokens })
			end
		end
	end
	if earned > 0 then
		data.GearTokens += earned
		DataService.publish(player)
		Net.sfx(player, "Tokens")
	end
end

function QuestService.init()
	DataService.onLoaded(function(player)
		QuestService.ensure(player)
		DataService.publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		friendCache = {} -- keep it small; entries are cheap to rebuild
	end)
end

return QuestService
