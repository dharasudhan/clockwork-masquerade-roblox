-- Open Cloud Luau Execution entry: verifies every music/SFX id in Config/Audio loads in a real
-- server (ContentProvider:PreloadAsync -> Success and Sound.TimeLength > 0).
--   python3 scripts/luau_exec.py build/ClockworkMasquerade.rbxl tests/audio_check.server.luau
-- Prints AUDIO OK <key> <id> <len> / AUDIO FAIL <key> <id> <reason>; returns the failures.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Audio = require(ReplicatedStorage:WaitForChild("Shared").Config.Audio)

local folder = Instance.new("Folder")
folder.Name = "AudioCheck"
folder.Parent = workspace
local entries = {}
for group, cues in { Music = Audio.Music, Sfx = Audio.Sfx } do
	for key, c in cues do
		local s = Instance.new("Sound")
		s.Name = group .. "." .. key
		s.SoundId = "rbxassetid://" .. c.id
		s.Parent = folder
		table.insert(entries, { key = s.Name, id = c.id, sound = s, status = "?" })
	end
end
-- several cues share one verified id (Lobby + Day music): status per id
local byId = {}
for _, e in entries do
	byId[e.sound.SoundId] = byId[e.sound.SoundId] or {}
	table.insert(byId[e.sound.SoundId], e)
end
local list = {}
for _, e in entries do
	table.insert(list, e.sound)
end
ContentProvider:PreloadAsync(list, function(assetId, status)
	for _, e in byId[assetId] or {} do
		e.status = status.Name
	end
end)
local ok, failed = 0, {}
for _, e in entries do
	local t0 = os.clock()
	while e.sound.TimeLength <= 0 and os.clock() - t0 < 5 do
		task.wait(0.2)
	end
	local len = e.sound.TimeLength
	if e.status == "Success" and len > 0 then
		ok += 1
		print(string.format("AUDIO OK %s %d %.1fs", e.key, e.id, len))
	else
		table.insert(failed, e.key .. "=" .. e.id)
		print(string.format("AUDIO FAIL %s %d status=%s len=%.2f", e.key, e.id, e.status, len))
	end
end
folder:Destroy()
print(string.format("AUDIO: %d ok, %d failed", ok, #failed))
return ok, table.concat(failed, ",")
