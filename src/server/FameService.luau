-- v1.6.1 Hall of Fame service: paints the lobby FameBoard from an OrderedDataStore of
-- all-time match WINS per player. ProfileStore (DataService) stays the authority for a
-- player's own record; the OrderedDataStore only exists so the TOP 10 can be listed
-- (ProfileStore cannot enumerate). A separate plain DataStore remembers the last display
-- name per user id (OrderedDataStore values are just numbers).
-- Every DataStore call is pcall'd: in Studio / offline / over budget the board simply keeps
-- its last paint (or the empty-state line), never an error.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fame = require(Shared.Logic.Fame)
local Clock = require(script.Parent.Clock)
local DataService = require(script.Parent.DataService)

local FameService = {}

local WINS_STORE = "CM_FameWins_v1"
local NAMES_STORE = "CM_FameNames_v1"
local REFRESH_FIRST = 8 -- s after boot (let the map build + first players settle)
local REFRESH_EVERY = 120 -- s
local NAME_WRITE_EVERY = 600 -- s per player: names barely change, don't burn the budget

local winsStore: any = nil
local namesStore: any = nil
local board: any = nil
local nameCache: { [number]: number } = {} -- userId -> last wall-clock name write

local function stores(): boolean
	if winsStore then
		return true
	end
	local ok = pcall(function()
		winsStore = DataStoreService:GetOrderedDataStore(WINS_STORE)
		namesStore = DataStoreService:GetDataStore(NAMES_STORE)
	end)
	if not ok then
		winsStore, namesStore = nil, nil
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
	pcall(function()
		winsStore:SetAsync("u" .. uid, totalWins(data))
	end)
	local now = Clock.wall()
	if (nameCache[uid] or 0) + NAME_WRITE_EVERY < now then
		nameCache[uid] = now
		pcall(function()
			namesStore:SetAsync("u" .. uid, player.DisplayName)
		end)
	end
end

local function paint(entries: { Fame.Entry })
	for i = 1, Fame.MaxRows do
		local row = board and board:FindFirstChild("Row" .. i, true)
		if row and row:IsA("TextLabel") then
			row.Text = if entries[i] then Fame.line(i, entries[i].name, entries[i].wins) else ""
		end
	end
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
	local entries = {}
	for _, e in list do
		local name = nil
		pcall(function()
			name = namesStore:GetAsync(e.key)
		end)
		table.insert(entries, { name = if type(name) == "string" then name else "?", wins = tonumber(e.value) or 0 })
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