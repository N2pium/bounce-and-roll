-- Phone tilt -> analog stick. Whatever angle the player holds the phone at when they calibrate
-- becomes "level", so it works lying down, sitting up or with the phone flat on a table.
local UserInputService = game:GetService("UserInputService")

local TiltInput = {}
TiltInput.__index = TiltInput

local function readGravity()
	local ok, input = pcall(UserInputService.GetDeviceGravity, UserInputService)
	return ok and input and input.Position or nil
end

function TiltInput.new(config)
	local self = setmetatable({}, TiltInput)
	self.config = config
	self.supported = UserInputService.AccelerometerEnabled
	self.neutral = nil
	self.value = Vector2.zero
	return self
end

function TiltInput:Calibrate()
	self.neutral = readGravity()
	self.value = Vector2.zero
end

-- Returns Vector2(right, forward), each in -1..1.
function TiltInput:Read(dt)
	local cfg = self.config
	local gravity = self.neutral and readGravity()
	local target = Vector2.zero
	if gravity then
		local delta = gravity - self.neutral
		-- Gravity comes back in screen space: +X toward the right edge, +Z toward the bottom edge.
		target = Vector2.new(delta.X, -delta.Z) * cfg.Sensitivity
		if cfg.InvertX then
			target = Vector2.new(-target.X, target.Y)
		end
		if cfg.InvertY then
			target = Vector2.new(target.X, -target.Y)
		end
		local magnitude = target.Magnitude
		if magnitude < cfg.Deadzone then
			target = Vector2.zero
		else
			-- Rescale so movement ramps up from zero at the edge of the deadzone.
			target = target.Unit * math.min((magnitude - cfg.Deadzone) / (1 - cfg.Deadzone), 1)
		end
	end
	self.value = self.value:Lerp(target, 1 - math.exp(-cfg.SmoothingRate * dt))
	return self.value
end

return TiltInput
