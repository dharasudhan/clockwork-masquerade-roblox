-- Music per phase (Lobby / Day / Night) with a short cross-fade, and one-shot SFX cues the
-- server sends. Ids: Config/Audio (only ids verified in a real server).
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Audio = require(Shared.Config.Audio)

local SoundManager = {}

local byId: { [number]: Sound } = {} -- one Sound per unique id (Lobby + Day share a track)
local current: string? = nil
local currentSound: Sound? = nil
local folder: Folder? = nil
local musicOn, sfxOn = true, true

local function make(name: string, c, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. c.id
	s.Volume = c.volume
	s.Looped = looped
	s.Parent = folder
	return s
end

function SoundManager.init()
	folder = Instance.new("Folder")
	folder.Name = "ClockworkAudio"
	folder.Parent = SoundService
	for key, c in Audio.Music do
		if not byId[c.id] then
			byId[c.id] = make("Music_" .. key, c, true)
		end
	end
end

local function fade(s: Sound, to: number)
	if not musicOn then
		to = 0
	end
	local ok = pcall(function()
		TweenService:Create(s, TweenInfo.new(Audio.MusicFadeSeconds), { Volume = to }):Play()
	end)
	if not ok then
		s.Volume = to
	end
end

-- Lobby / Day / Night get their track; any other phase (Results) fades the music out.
function SoundManager.setPhase(phase: string)
	local c = Audio.Music[phase]
	local s = c and byId[c.id]
	current = if s then phase else nil
	if s == currentSound then
		if s then
			fade(s, c.volume) -- same track (Lobby -> Day): keep playing, no restart
		end
		return
	end
	local prev = currentSound
	currentSound = s
	if prev then
		fade(prev, 0)
		task.delay(Audio.MusicFadeSeconds, function()
			if currentSound ~= prev then
				prev:Stop()
			end
		end)
	end
	if s then
		s.Volume = 0
		s:Play()
		fade(s, c.volume)
	end
end

-- Settings: music / sound effects on or off (saved per player).
function SoundManager.setEnabled(music: boolean, sfx: boolean)
	local changed = music ~= musicOn
	musicOn, sfxOn = music, sfx
	if changed and currentSound and current then
		fade(currentSound, Audio.Music[current].volume)
	end
end

function SoundManager.enabled(): (boolean, boolean)
	return musicOn, sfxOn
end

function SoundManager.sfx(cue: string)
	local c = Audio.Sfx[cue]
	if not c or not folder or not sfxOn then
		return
	end
	local s = make("Sfx_" .. cue, c, false)
	s:Play()
	task.delay(c.maxSeconds or 10, function()
		s:Destroy()
	end)
end

function SoundManager.current(): string?
	return current
end

return SoundManager
