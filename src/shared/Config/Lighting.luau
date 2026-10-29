-- Lighting presets (pure data). Day = warm chandeliers; Night = deep violet emergency grid.
return {
	Presets = {
		Lobby = {
			ClockTime = 17.2, Brightness = 2.2, Ambient = { 70, 60, 54 }, OutdoorAmbient = { 120, 104, 90 },
			FogColor = { 200, 160, 120 }, FogEnd = 1200, ExposureCompensation = 0,
			Atmosphere = { density = 0.25, color = { 230, 190, 140 }, decay = { 140, 90, 60 }, haze = 1.2 },
			room = { color = { 255, 196, 128 }, brightness = 1.6, range = 26, roomColors = true },
		},
		Day = {
			ClockTime = 15, Brightness = 1.6, Ambient = { 62, 52, 44 }, OutdoorAmbient = { 96, 84, 72 },
			FogColor = { 180, 140, 100 }, FogEnd = 900, ExposureCompensation = 0.1,
			Atmosphere = { density = 0.28, color = { 230, 190, 140 }, decay = { 140, 90, 60 }, haze = 1.5 },
			room = { color = { 255, 196, 128 }, brightness = 1.8, range = 30, roomColors = true },
		},
		Night = {
			ClockTime = 0.5, Brightness = 0.3, Ambient = { 26, 12, 44 }, OutdoorAmbient = { 30, 16, 52 },
			FogColor = { 34, 14, 60 }, FogEnd = 260, ExposureCompensation = -0.2,
			Atmosphere = { density = 0.42, color = { 90, 40, 160 }, decay = { 40, 10, 80 }, haze = 2.2 },
			room = { color = { 150, 70, 255 }, brightness = 0.9, range = 22 },
		},
		Overdrive = {
			ClockTime = 5.6, Brightness = 0.8, Ambient = { 60, 26, 30 }, OutdoorAmbient = { 90, 50, 60 },
			FogColor = { 120, 50, 60 }, FogEnd = 320, ExposureCompensation = 0,
			Atmosphere = { density = 0.38, color = { 200, 90, 80 }, decay = { 120, 40, 60 }, haze = 1.8 },
			room = { color = { 255, 120, 70 }, brightness = 1.1, range = 24 },
		},
	},
}
