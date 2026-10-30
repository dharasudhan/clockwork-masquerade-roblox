-- v1.6.1 Hall of Fame service: paints the lobby FameBoard from an OrderedDataStore of
-- all-time match WINS per player. ProfileStore (DataService) stays the authority for a
-- player's own record; the OrderedDataStore only exists so the TOP 10 can be listed
-- (ProfileStore cannot enumerate). Pattern: Roblox creator-docs "Create a leaderboard"
-- tutorial + arxkdev/Leaderboard (MIT) - server-authoritative SetAsync of the total,
-- GetSortedAsync(false, 10) on a timer, cached display names (see CREDITS.md).
-- v1.6 review (Hark): display names come from ONE batched UserService:GetUserInfosByUserIdsAsync
-- call per refresh (cached for 10 min) instead of a second "names" DataStore - fewer DataStore
-- requests and the name is always the player's current display name. An empty board shows an
-- invitation line instead of ten blank rows.
-- Every DataStore / web call is pcall'd: in Studio / offline / over budget the board simply
-- keeps its last paint (or the empty-state line), never an error.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local UserService = game:GetService("UserService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fame = require(Shared.Logic.Fame)
local Clock = require(script.Parent.Clock)
local DataService = require(script.Parent.DataService)

local FameService = {}

local WINS_STORE = "CM_FameWins_v1"
local REFRESH_FIRST = 8 -- s after boot (let the map build + first players settle)
local REFRESH_EVERY = 120 -- s
local NAME_TTL = 600 -- s: display names barely change
FameService.EmptyText = "No champions yet - win a match to be the first!"

local winsStore: any = nil
local board: any = nil
local nameCache: { [number]: { name: string, at: number } } = {} -- userId -> display name
local lastWritten: { [number]: number } = {} -- userId -> last total written (skip no-ops)

local function stores(): boolean
	if winsStore then
		return true
	end
	local ok = pcall(function()
		winsStore = DataStoreService:GetOrderedDataStore(WINS_STORE)
	end)
	if not ok then
		winsStore = nil
	end
	return winsStore ~= nil
end

local function totalWins(data: any): number
	local w = data and data.Wins
	return (if w and w.Guest then w.Guest else 0) + (if w and w.Phantom then w.Phantom else 0)
end

-- Record a player's all-time total (called at every match end; cheap and idempotent).
function FameService.record(player: Player)
	local data = DataService.get(player)
	if not data or not stores() then
		return
	end
	local uid = player.UserId
	if uid <= 0 then
		return -- Studio test players / guests never enter the all-time board
	end
	local total = math.floor(totalWins(data))
	if lastWritten[uid] == total then
		return
	end
	local ok = pcall(function()
		winsStore:SetAsync("u" .. uid, total)
	end)
	if ok then
		lastWritten[uid] = total
		nameCache[uid] = { name = player.DisplayName, at = Clock.wall() }
	end
end

-- Display names for user ids, one batched web call for the ones not cached (pcall'd).
local function names(ids: { number }): { [number]: string }
	local now = Clock.wall()
	local missing = {}
	for _, id in ids do
		local c = nameCache[id]
		if not c or now - c.at > NAME_TTL then
			table.insert(missing, id)
		end
	end
	if #missing > 0 then
		pcall(function()
			for _, info in UserService:GetUserInfosByUserIdsAsync(missing) do
				nameCache[info.Id] = { name = info.DisplayName, at = now }
			end
		end)
	end
	local out = {}
	for _, id in ids do
		out[id] = nameCache[id] and nameCache[id].name or "?"
	end
	return out
end

local function paint(entries: { Fame.Entry })
	local lines = Fame.lines(entries, Fame.MaxRows)
	for i = 1, Fame.MaxRows do
		local row = board and board:FindFirstChild("Row" .. i, true)
		if row and row:IsA("TextLabel") then
			row.Text = lines[i] or (if i == 1 and #lines == 0 then FameService.EmptyText else "")
		end
	end
end
FameService._paint = function(entries, b)
	board = b or board
	paint(entries)
end

-- Pull the top 10 and repaint the board. Offline: keep whatever is painted.
function FameService.refresh()
	if not board or not stores() then
		return
	end
	local ok, pages = pcall(function()
		return winsStore:GetSortedAsync(false, Fame.MaxRows)
	end)
	if not ok or not pages then
		return
	end
	local ok2, list = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not ok2 or type(list) ~= "table" then
		return
	end
	local ids, wins = {}, {}
	for _, e in list do
		local id = tonumber(string.match(tostring(e.key), "^u(%d+)$"))
		local w = tonumber(e.value) or 0
		if id and w > 0 then
			table.insert(ids, id)
			wins[id] = w
		end
	end
	local nm = names(ids)
	local entries = {}
	for _, id in ids do
		table.insert(entries, { name = nm[id], wins = wins[id] })
	end
	paint(entries)
end

function FameService.init()
	-- the board is part of the lobby build (ManorBuilder.buildLobby)
	local function findBoard()
		local map = workspace:FindFirstChild("Map")
		local lobby = map and map:FindFirstChild("Lobby")
		board = lobby and lobby:FindFirstChild("FameBoard")
	end
	pcall(findBoard)
	-- cover for players already online when the server boots (e.g. Studio solo test)
	for _, player in Players:GetPlayers() do
		task.spawn(FameService.record, player)
	end
	task.delay(REFRESH_FIRST, function()
		pcall(findBoard) -- retry in case the lobby finished building after init
		FameService.refresh()
		while true do
			task.wait(REFRESH_EVERY)
			FameService.refresh()
		end
	end)
end

return FameService
