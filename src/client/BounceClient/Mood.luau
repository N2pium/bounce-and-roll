-- Crossfades Lighting to the server's mood: drift into a soft haze, swap the skybox while it's
-- hidden, then settle into the new light, colour grade and cloud / sea tints.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local HAZE_SHARE = 0.35 -- fraction of the transition spent fading into haze before the sky swaps
local WHITE = Color3.new(1, 1, 1)

local Mood = {}
Mood.__index = Mood

local function ensureEffect(className, name)
	local effect = Lighting:FindFirstChild(name)
	if not effect then
		effect = Instance.new(className)
		effect.Name = name
		effect.Parent = Lighting
	end
	return effect
end

function Mood.new(shared, moods, onChanged)
	local self = setmetatable({}, Mood)
	self.shared = shared
	self.moods = moods
	self.skies = shared:WaitForChild("Skies")
	self.onChanged = onChanged or function() end
	self.current = nil
	self.token = 0

	self.atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or ensureEffect("Atmosphere", "Atmosphere")
	self.grade = ensureEffect("ColorCorrectionEffect", "DreamGrade")
	self.bloom = Lighting:FindFirstChildOfClass("BloomEffect") or ensureEffect("BloomEffect", "Bloom")
	self.sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect") or ensureEffect("SunRaysEffect", "SunRays")

	shared:GetAttributeChangedSignal("Mood"):Connect(function()
		self:Apply(shared:GetAttribute("Mood"), false)
	end)
	self:Apply(shared:GetAttribute("Mood") or moods.Default, true)
	return self
end

function Mood:_setSky(skyName)
	local template = self.skies:FindFirstChild(skyName)
	if not template then
		return
	end
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
	template:Clone().Parent = Lighting
end

function Mood:_targets(def)
	return {
		{ Lighting, def.Lighting },
		{ self.atmosphere, def.Atmosphere },
		{ self.grade, def.Grade },
		{ self.bloom, def.Bloom },
		{ self.sunRays, def.SunRays },
	}
end

function Mood:_tintParts(def, info)
	for tag, color in { MoodSea = def.Sea, MoodCloud = def.Cloud } do
		for _, part in CollectionService:GetTagged(tag) do
			if info then
				TweenService:Create(part, info, { Color = color }):Play()
			else
				part.Color = color
			end
		end
	end
end

-- Parts that stream in later pick up the current tint.
function Mood:TintNew(part)
	local def = self.current and self.moods.List[self.current]
	if not def then
		return
	end
	if CollectionService:HasTag(part, "MoodSea") then
		part.Color = def.Sea
	elseif CollectionService:HasTag(part, "MoodCloud") then
		part.Color = def.Cloud
	end
end

function Mood:Apply(name, instant)
	local def = self.moods.List[name]
	if not def or name == self.current then
		return
	end
	self.current = name
	self.token += 1
	local token = self.token
	self.onChanged(name, def, instant)

	if instant then
		self:_setSky(def.Sky)
		for _, pair in self:_targets(def) do
			for property, value in pair[2] do
				pair[1][property] = value
			end
		end
		self:_tintParts(def, nil)
		return
	end

	local total = self.moods.TransitionSeconds
	local hazeTime = total * HAZE_SHARE
	local hazeInfo = TweenInfo.new(hazeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(self.atmosphere, hazeInfo, { Density = 0.6, Haze = 3, Color = def.Atmosphere.Color:Lerp(WHITE, 0.4) }):Play()
	TweenService:Create(self.grade, hazeInfo, { Brightness = 0.08, Saturation = -0.1 }):Play()

	task.delay(hazeTime, function()
		if self.token ~= token then
			return
		end
		self:_setSky(def.Sky)
		local settle = TweenInfo.new(total - hazeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		for _, pair in self:_targets(def) do
			TweenService:Create(pair[1], settle, pair[2]):Play()
		end
		self:_tintParts(def, settle)
	end)
end

return Mood
