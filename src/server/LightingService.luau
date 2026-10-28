-- Lighting presets (Config/Lighting) and per-room chandeliers: warm by day, deep violet
-- emergency light at night; Wisps can flicker one room's lights.
local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cfg = require(Shared.Config.Lighting)
local Build = require(script.Parent.Build)
local ManorBuilder = require(script.Parent.ManorBuilder)

local LightingService = {}

local current = "Lobby"
local flickering: { [string]: number } = {} -- roomId -> token
local atmosphere: Atmosphere? = nil

local function roomLights()
	local b = ManorBuilder.get()
	return if b then b.roomLights else {}
end

function LightingService.apply(name: string)
	local p = Cfg.Presets[name] or error("no lighting preset " .. name)
	current = name
	Lighting.ClockTime = p.ClockTime
	Lighting.Brightness = p.Brightness
	Lighting.Ambient = Build.rgb(p.Ambient)
	Lighting.OutdoorAmbient = Build.rgb(p.OutdoorAmbient)
	Lighting.FogColor = Build.rgb(p.FogColor)
	Lighting.FogEnd = p.FogEnd
	Lighting.ExposureCompensation = p.ExposureCompensation
	if atmosphere == nil then
		atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	local a = atmosphere :: Atmosphere
	a.Density = p.Atmosphere.density
	a.Color = Build.rgb(p.Atmosphere.color)
	a.Decay = Build.rgb(p.Atmosphere.decay)
	a.Haze = p.Atmosphere.haze
	local color = Build.rgb(p.room.color)
	for _, lights in roomLights() do
		for _, l in lights do
			l.Color = color
			l.Brightness = p.room.brightness
			l.Range = p.room.range
			l.Enabled = true
			-- the neon bulbs follow the light colour
			local m = l.Parent and l.Parent.Parent
			if m then
				for _, d in m:GetChildren() do
					if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
						d.Color = color
					end
				end
			end
		end
	end
	Lighting:SetAttribute("Preset", name)
end

function LightingService.current(): string
	return current
end

-- Flicker a room's lights for `seconds` (Electro-Wisp ability). Returns false for unknown rooms.
function LightingService.flicker(roomId: string, seconds: number): boolean
	local lights = roomLights()[roomId]
	if not lights then
		return false
	end
	local token = (flickering[roomId] or 0) + 1
	flickering[roomId] = token
	workspace:SetAttribute("Flicker_" .. roomId, true)
	task.spawn(function()
		local t0 = os.clock()
		local on = false
		while os.clock() - t0 < seconds and flickering[roomId] == token do
			for _, l in lights do
				l.Enabled = on
			end
			on = not on
			task.wait(if on then 0.12 else 0.35)
		end
		if flickering[roomId] == token then
			for _, l in lights do
				l.Enabled = true
			end
			workspace:SetAttribute("Flicker_" .. roomId, nil)
		end
	end)
	return true
end

function LightingService.stopFlicker()
	for roomId in flickering do
		flickering[roomId] = (flickering[roomId] or 0) + 1
		workspace:SetAttribute("Flicker_" .. roomId, nil)
	end
	for _, lights in roomLights() do
		for _, l in lights do
			l.Enabled = true
		end
	end
end

return LightingService
