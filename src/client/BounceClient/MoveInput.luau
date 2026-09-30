-- Keyboard / gamepad / on-screen thumbstick -> Vector2(right, forward).
-- Default character controls are set to Scriptable in StarterPlayer, so this is the only move input.
local UserInputService = game:GetService("UserInputService")

local KEYS = {
	[Enum.KeyCode.W] = Vector2.new(0, 1),
	[Enum.KeyCode.Up] = Vector2.new(0, 1),
	[Enum.KeyCode.S] = Vector2.new(0, -1),
	[Enum.KeyCode.Down] = Vector2.new(0, -1),
	[Enum.KeyCode.A] = Vector2.new(-1, 0),
	[Enum.KeyCode.Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.D] = Vector2.new(1, 0),
	[Enum.KeyCode.Right] = Vector2.new(1, 0),
}

local STICK_RADIUS = 70
local STICK_ZONE = 0.4 -- touches starting in the left 40% of the screen drive the stick
local GAMEPAD_DEADZONE = 0.15

local MoveInput = {}
MoveInput.__index = MoveInput

local function circle(size, color, transparency, parent)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(45, 30, 80)
	stroke.Transparency = transparency
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

function MoveInput.new(gui)
	local self = setmetatable({}, MoveInput)
	self.touchEnabled = gui ~= nil
	self.stickInput = nil
	self.stickOrigin = Vector2.zero
	self.stickVector = Vector2.zero
	self.gamepadVector = Vector2.zero

	if gui then
		self.base = circle(STICK_RADIUS * 2, Color3.new(1, 1, 1), 0.7, gui)
		self.knob = circle(64, Color3.fromRGB(255, 120, 180), 0.1, self.base)
		self.knob.Position = UDim2.fromScale(0.5, 0.5)
		self:_rest()
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not self.touchEnabled or self.stickInput or input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local viewport = workspace.CurrentCamera.ViewportSize
		if input.Position.X > viewport.X * STICK_ZONE then
			return
		end
		self.stickInput = input
		self.stickOrigin = Vector2.new(input.Position.X, input.Position.Y)
		self.base.Position = UDim2.fromOffset(self.stickOrigin.X, self.stickOrigin.Y)
		self.base.BackgroundTransparency = 0.55
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == self.stickInput then
			local offset = Vector2.new(input.Position.X, input.Position.Y) - self.stickOrigin
			if offset.Magnitude > STICK_RADIUS then
				offset = offset.Unit * STICK_RADIUS
			end
			self.knob.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
			self.stickVector = Vector2.new(offset.X, -offset.Y) / STICK_RADIUS
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local stick = Vector2.new(input.Position.X, input.Position.Y)
			self.gamepadVector = stick.Magnitude > GAMEPAD_DEADZONE and stick or Vector2.zero
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input == self.stickInput then
			self:_rest()
		end
	end)
	return self
end

function MoveInput:_rest()
	self.stickInput = nil
	self.stickVector = Vector2.zero
	if self.base then
		self.base.Position = UDim2.new(0, 130, 1, -130)
		self.base.BackgroundTransparency = 0.7
		self.knob.Position = UDim2.fromScale(0.5, 0.5)
	end
end

-- Hidden in tilt mode.
function MoveInput:SetTouchEnabled(enabled)
	if not self.base then
		return
	end
	self.touchEnabled = enabled
	self.base.Visible = enabled
	if not enabled then
		self:_rest()
	end
end

function MoveInput:Read()
	local value = self.stickVector + self.gamepadVector
	if not UserInputService:GetFocusedTextBox() then
		for key, direction in KEYS do
			if UserInputService:IsKeyDown(key) then
				value += direction
			end
		end
	end
	if value.Magnitude > 1 then
		value = value.Unit
	end
	return value
end

return MoveInput
