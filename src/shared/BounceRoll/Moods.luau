-- Lighting "moods". Each pairs one skybox from BounceRoll.Skies with matching light, haze, colour
-- grading and cloud / sea / sparkle tints. The server picks the mood per level or round
-- (ServerScriptService.MoodDirector); clients crossfade into it (BounceClient.Mood).
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Moods = {}

Moods.Default = "Daydream"
Moods.TransitionSeconds = 4
Moods.LobbyRotateSeconds = 150

-- Which moods each kind of round draws from. The lobby cycles through its list between shows.
Moods.Rotation = {
	Lobby = { "Daydream", "Fair Weather", "Golden Hour", "Aurora Dusk", "Nebula Dream", "Dream Town", "Clear Blue" },
	Race = { "Daydream", "Fair Weather", "Clear Blue", "Golden Hour" },
	Survival = { "Aurora Dusk", "Nebula Dream", "Dream Town" },
	Final = { "Lucid Nightmare" },
}

Moods.List = {
	Daydream = {
		Sky = "Daydream",
		Caption = "daydream",
		Lighting = { ClockTime = 14, Brightness = 2.2, ExposureCompensation = -0.1, Ambient = rgb(145, 135, 170), OutdoorAmbient = rgb(170, 160, 205), ShadowSoftness = 0.55 },
		Atmosphere = { Density = 0.18, Offset = 0.15, Color = rgb(215, 205, 245), Decay = rgb(175, 205, 255), Glare = 0.1, Haze = 0.5 },
		Grade = { TintColor = rgb(255, 246, 255), Saturation = 0.22, Contrast = 0.04, Brightness = -0.03 },
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.9 },
		SunRays = { Intensity = 0.03, Spread = 0.15 },
		Sea = rgb(150, 205, 250),
		Cloud = rgb(240, 232, 250),
		Motes = rgb(255, 235, 255),
	},
	["Clear Blue"] = {
		Sky = "Clear Blue",
		Caption = "clear blue",
		Lighting = { ClockTime = 13, Brightness = 2.3, ExposureCompensation = -0.12, Ambient = rgb(135, 145, 170), OutdoorAmbient = rgb(165, 180, 212), ShadowSoftness = 0.5 },
		Atmosphere = { Density = 0.16, Offset = 0.1, Color = rgb(195, 218, 250), Decay = rgb(150, 195, 255), Glare = 0.08, Haze = 0.35 },
		Grade = { TintColor = rgb(245, 250, 255), Saturation = 0.16, Contrast = 0.05, Brightness = -0.03 },
		Bloom = { Intensity = 0.45, Size = 22, Threshold = 1.9 },
		SunRays = { Intensity = 0.03, Spread = 0.12 },
		Sea = rgb(140, 195, 250),
		Cloud = rgb(236, 242, 252),
		Motes = rgb(215, 235, 255),
	},
	["Fair Weather"] = {
		Sky = "Fair Weather",
		Caption = "fair weather",
		Lighting = { ClockTime = 12, Brightness = 2.5, ExposureCompensation = -0.15, Ambient = rgb(135, 140, 155), OutdoorAmbient = rgb(160, 170, 198), ShadowSoftness = 0.45 },
		Atmosphere = { Density = 0.15, Offset = 0.05, Color = rgb(205, 222, 250), Decay = rgb(170, 200, 240), Glare = 0.08, Haze = 0.25 },
		Grade = { TintColor = rgb(255, 252, 250), Saturation = 0.18, Contrast = 0.06, Brightness = -0.04 },
		Bloom = { Intensity = 0.4, Size = 20, Threshold = 2 },
		SunRays = { Intensity = 0.04, Spread = 0.15 },
		Sea = rgb(130, 188, 242),
		Cloud = rgb(242, 244, 250),
		Motes = rgb(255, 248, 230),
	},
	["Golden Hour"] = {
		Sky = "Golden Hour",
		Caption = "golden hour",
		Lighting = { ClockTime = 17.3, Brightness = 2, ExposureCompensation = -0.1, Ambient = rgb(165, 135, 125), OutdoorAmbient = rgb(215, 175, 150), ShadowSoftness = 0.6 },
		Atmosphere = { Density = 0.25, Offset = 0.2, Color = rgb(250, 215, 175), Decay = rgb(255, 170, 120), Glare = 0.35, Haze = 1 },
		Grade = { TintColor = rgb(255, 240, 225), Saturation = 0.22, Contrast = 0.04, Brightness = -0.03 },
		Bloom = { Intensity = 0.6, Size = 26, Threshold = 1.8 },
		SunRays = { Intensity = 0.08, Spread = 0.2 },
		Sea = rgb(250, 195, 155),
		Cloud = rgb(245, 215, 190),
		Motes = rgb(255, 220, 160),
	},
	["Aurora Dusk"] = {
		Sky = "Aurora Dusk",
		Caption = "aurora dusk",
		Lighting = { ClockTime = 18.4, Brightness = 1.7, ExposureCompensation = 0, Ambient = rgb(120, 110, 160), OutdoorAmbient = rgb(160, 145, 205), ShadowSoftness = 0.6 },
		Atmosphere = { Density = 0.26, Offset = 0.2, Color = rgb(190, 170, 250), Decay = rgb(255, 160, 130), Glare = 0.25, Haze = 0.8 },
		Grade = { TintColor = rgb(240, 232, 255), Saturation = 0.26, Contrast = 0.05, Brightness = -0.02 },
		Bloom = { Intensity = 0.7, Size = 26, Threshold = 1.6 },
		SunRays = { Intensity = 0.05, Spread = 0.2 },
		Sea = rgb(140, 140, 228),
		Cloud = rgb(210, 198, 245),
		Motes = rgb(175, 255, 235),
	},
	["Nebula Dream"] = {
		Sky = "Nebula Dream",
		Caption = "nebula dream",
		Lighting = { ClockTime = 20.5, Brightness = 1.2, ExposureCompensation = 0.15, Ambient = rgb(145, 125, 180), OutdoorAmbient = rgb(165, 145, 210), ShadowSoftness = 0.7 },
		Atmosphere = { Density = 0.24, Offset = 0.25, Color = rgb(170, 135, 225), Decay = rgb(90, 210, 215), Glare = 0.15, Haze = 0.55 },
		Grade = { TintColor = rgb(238, 228, 255), Saturation = 0.3, Contrast = 0.05, Brightness = -0.01 },
		Bloom = { Intensity = 0.8, Size = 28, Threshold = 1.5 },
		SunRays = { Intensity = 0, Spread = 0.1 },
		Sea = rgb(118, 108, 210),
		Cloud = rgb(220, 190, 235),
		Motes = rgb(145, 255, 230),
	},
	["Dream Town"] = {
		Sky = "Dream Town",
		Caption = "dream town",
		Lighting = { ClockTime = 21, Brightness = 1.2, ExposureCompensation = 0.15, Ambient = rgb(120, 140, 190), OutdoorAmbient = rgb(145, 170, 225), ShadowSoftness = 0.7 },
		Atmosphere = { Density = 0.22, Offset = 0.2, Color = rgb(145, 180, 250), Decay = rgb(70, 120, 255), Glare = 0.2, Haze = 0.5 },
		Grade = { TintColor = rgb(232, 242, 255), Saturation = 0.24, Contrast = 0.05, Brightness = -0.01 },
		Bloom = { Intensity = 0.75, Size = 26, Threshold = 1.5 },
		SunRays = { Intensity = 0, Spread = 0.1 },
		Sea = rgb(95, 145, 240),
		Cloud = rgb(200, 212, 245),
		Motes = rgb(195, 220, 255),
	},
	["Lucid Nightmare"] = {
		Sky = "Lucid Nightmare",
		Caption = "lucid nightmare",
		Lighting = { ClockTime = 19, Brightness = 1.4, ExposureCompensation = 0.05, Ambient = rgb(145, 100, 145), OutdoorAmbient = rgb(200, 120, 175), ShadowSoftness = 0.6 },
		Atmosphere = { Density = 0.3, Offset = 0.2, Color = rgb(250, 145, 195), Decay = rgb(110, 50, 160), Glare = 0.3, Haze = 1.1 },
		Grade = { TintColor = rgb(255, 228, 242), Saturation = 0.34, Contrast = 0.1, Brightness = -0.03 },
		Bloom = { Intensity = 0.8, Size = 28, Threshold = 1.5 },
		SunRays = { Intensity = 0.04, Spread = 0.2 },
		Sea = rgb(175, 85, 165),
		Cloud = rgb(240, 185, 215),
		Motes = rgb(255, 145, 205),
	},
}

return Moods
