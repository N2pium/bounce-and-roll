-- Calm ambient motion: clouds and dream orbs slowly bob and drift, and soft sparkles float
-- around the camera. Everything here is client-only and purely visual.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local FLOAT_TAGS = { "MoodCloud", "DreamFloat" }
local MOTE_VOLUME = Vector3.new(140, 70, 140)

local Ambience = {}
Ambience.__index = Ambience

function Ambience.new(onPartAdded)
	local self = setmetatable({}, Ambience)
	self.rng = Random.new()
	self.floating = setmetatable({}, { __mode = "k" })

	local folder = Instance.new("Folder")
	folder.Name = "BounceRollAmbience"
	folder.Parent = workspace

	-- An invisible box that follows the camera and fills itself with drifting sparkles.
	local volume = Instance.new("Part")
	volume.Name = "Motes"
	volume.Anchored = true
	volume.CanCollide = false
	volume.CanQuery = false
	volume.CanTouch = false
	volume.Transparency = 1
	volume.Size = MOTE_VOLUME
	volume.Parent = folder

	local motes = Instance.new("ParticleEmitter")
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.Rate = 16
	motes.Lifetime = NumberRange.new(5, 8)
	motes.Speed = NumberRange.new(0.5, 1.5)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Acceleration = Vector3.new(0, 0.4, 0)
	motes.Drag = 0.3
	motes.LightEmission = 1
	motes.RotSpeed = NumberRange.new(-30, 30)
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.15),
		NumberSequenceKeypoint.new(0.75, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Parent = volume
	self.motes = motes

	RunService.RenderStepped:Connect(function()
		volume.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position)
	end)

	for _, tag in FLOAT_TAGS do
		for _, part in CollectionService:GetTagged(tag) do
			self:_float(part)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			self:_float(part)
			if onPartAdded then
				onPartAdded(part)
			end
		end)
	end
	return self
end

-- Endless slow bob between the part's home position and a nearby offset.
function Ambience:_float(part)
	if self.floating[part] or not part:IsA("BasePart") then
		return
	end
	local rng = self.rng
	local amount = part:GetAttribute("FloatAmount") or 4
	local offset = Vector3.new(rng:NextNumber(-1, 1) * amount, rng:NextNumber(0.5, 1) * amount, rng:NextNumber(-1, 1) * amount)
	local info = TweenInfo.new(rng:NextNumber(7, 13), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, rng:NextNumber(0, 4))
	local tween = TweenService:Create(part, info, { CFrame = part.CFrame + offset })
	tween:Play()
	self.floating[part] = tween
end

function Ambience:SetMoteColor(color)
	self.motes.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
end

return Ambience
