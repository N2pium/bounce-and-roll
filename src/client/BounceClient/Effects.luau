-- Client-only juice: particle bursts, pop-up text, colour flashes and sounds.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local SOUNDS = {
	jump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.6, pitch = 1.1 },
	land = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.7, pitch = 0.9 },
	boing = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.9, pitch = 0.6 },
	bump = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 0.7 },
	chime = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 1.4 },
}

local INK = Color3.fromRGB(45, 30, 80)

local Effects = {}
Effects.__index = Effects

local function emitter(parent, props)
	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 0
	for key, value in props do
		particles[key] = value
	end
	particles.Parent = parent
	return particles
end

local function ghostPart(name, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Parent = parent
	return part
end

function Effects.new()
	local self = setmetatable({}, Effects)
	local folder = Instance.new("Folder")
	folder.Name = "BounceRollFX"
	folder.Parent = workspace
	self.folder = folder
	self.anchor = ghostPart("FXAnchor", folder)

	self.emitters = {
		puff = emitter(self.anchor, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Size = NumberSequence.new(1.5, 5),
			Transparency = NumberSequence.new(0.2, 1),
			Lifetime = NumberRange.new(0.35, 0.6),
			Speed = NumberRange.new(10, 18),
			SpreadAngle = Vector2.new(90, 90),
			Drag = 6,
		}),
		spark = emitter(self.anchor, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 120, 200)),
			LightEmission = 1,
			Size = NumberSequence.new(1.6, 0),
			Lifetime = NumberRange.new(0.25, 0.45),
			Speed = NumberRange.new(20, 38),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 4,
		}),
		confetti = emitter(self.anchor, {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 180)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 225, 110)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(120, 230, 190)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 190, 255)),
			}),
			Size = NumberSequence.new(0.9),
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(45, 75),
			SpreadAngle = Vector2.new(35, 35),
			Acceleration = Vector3.new(0, -45, 0),
			Drag = 1,
			RotSpeed = NumberRange.new(-200, 200),
		}),
	}

	self.sounds = {}
	for name, info in SOUNDS do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = info.id
		sound.Volume = info.volume
		sound.Parent = folder
		self.sounds[name] = { sound = sound, pitch = info.pitch }
	end
	return self
end

function Effects:Play(name, pitchScale)
	local entry = self.sounds[name]
	if not entry then
		return
	end
	entry.sound.PlaybackSpeed = entry.pitch * (pitchScale or 1) * (0.95 + math.random() * 0.1)
	entry.sound.TimePosition = 0
	entry.sound:Play()
end

function Effects:Burst(kind, position, count)
	self.anchor.CFrame = CFrame.new(position)
	self.emitters[kind]:Emit(count)
end

function Effects:Flash(part)
	local base = part:GetAttribute("FxBaseColor")
	if base == nil then
		base = part.Color
		part:SetAttribute("FxBaseColor", base)
	end
	part.Color = Color3.new(1, 1, 1)
	TweenService:Create(part, TweenInfo.new(0.3), { Color = base }):Play()
end

function Effects:PopText(text, position, color)
	local holder = ghostPart("PopText", self.folder)
	holder.CFrame = CFrame.new(position)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 70)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Rotation = math.random(-12, 12)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = INK
	stroke.Parent = label

	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 10, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	Debris:AddItem(holder, 0.9)
end

return Effects
