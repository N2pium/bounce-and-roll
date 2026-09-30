-- Chase camera built for tilt controls.
--
-- The problem: input is camera-relative, so if the camera spins to follow the ball, "tilt right"
-- keeps changing meaning and players circle forever. The fix:
--   * Inside CameraZones the yaw is authored per section (the way the course runs), so "forward"
--     always means "along the course" and never drifts while you steer.
--   * Outside zones it only slowly swings behind the ball, and ignores headings behind it
--     (bumps, rebounds), so a knockback never whips the view around.
--   * Manual turning (Q/E, right-drag, swipe, right stick) wins for a few seconds, then eases back.
--   * Vertical follow is lazy so floaty bounces don't shake the view; it catches up on big drops/launches.
local ChaseCamera = {}
ChaseCamera.__index = ChaseCamera

local TAU = math.pi * 2

local function angleDelta(from, to)
	return (to - from + math.pi) % TAU - math.pi
end

local function alpha(rate, dt)
	return 1 - math.exp(-rate * dt)
end

function ChaseCamera.new(config)
	local self = setmetatable({}, ChaseCamera)
	self.config = config
	self.yaw = math.pi
	self.manualOffset = 0
	self.lastManualAt = -math.huge
	self.zoneYaw = nil
	self.focus = nil
	self.distance = config.Distance
	self.fov = config.BaseFov

	self.params = RaycastParams.new()
	self.params.RespectCanCollide = true
	self.params.CollisionGroup = "Balls" -- sees the level, ignores balls and avatars
	return self
end

function ChaseCamera:GetYaw()
	return self.yaw
end

function ChaseCamera:AddManualYaw(delta)
	self.yaw += delta
	self.manualOffset += delta
	self.lastManualAt = os.clock()
end

function ChaseCamera:Snap(position, yaw)
	self.yaw = yaw
	self.manualOffset = 0
	self.focus = position
	self.distance = self.config.Distance
end

function ChaseCamera:Update(dt, position, velocity, zoneYaw)
	local cfg = self.config
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	local now = os.clock()
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flatVelocity.Magnitude
	local manualRecently = now - self.lastManualAt < cfg.ManualHoldTime

	if zoneYaw ~= self.zoneYaw then
		self.zoneYaw = zoneYaw
		self.manualOffset = 0
	end

	-- 1. Yaw
	if zoneYaw then
		if not manualRecently then
			self.manualOffset *= math.exp(-cfg.ManualReturnRate * dt)
		end
		self.yaw += angleDelta(self.yaw, zoneYaw + self.manualOffset) * alpha(cfg.ZoneTurnRate, dt)
	elseif not manualRecently and speed > cfg.FollowMinSpeed then
		local heading = math.atan2(-flatVelocity.X, -flatVelocity.Z)
		local diff = angleDelta(self.yaw, heading)
		if math.abs(diff) < math.rad(cfg.FollowMaxAngle) then
			local rate = cfg.FollowRate * math.clamp(speed / cfg.FollowFullSpeed, 0, 1)
			self.yaw += diff * alpha(rate, dt)
		end
	end

	-- 2. Focus: snappy horizontally, lazy vertically
	local lookAhead = flatVelocity * cfg.LookAhead
	if lookAhead.Magnitude > cfg.MaxLookAhead then
		lookAhead = lookAhead.Unit * cfg.MaxLookAhead
	end
	local desired = position + lookAhead
	local focus = self.focus or desired
	local dy = desired.Y - focus.Y
	local verticalRate = math.abs(dy) > cfg.VerticalCatchup and cfg.FocusRateVFast or cfg.FocusRateV
	local h = alpha(cfg.FocusRateH, dt)
	focus = Vector3.new(
		focus.X + (desired.X - focus.X) * h,
		focus.Y + dy * alpha(verticalRate, dt),
		focus.Z + (desired.Z - focus.Z) * h
	)
	self.focus = focus

	-- 3. Place the camera behind and above; pull in instantly when the level blocks it, ease back out
	local pivot = focus + Vector3.new(0, cfg.PivotHeight, 0)
	local rotation = CFrame.Angles(0, self.yaw, 0) * CFrame.Angles(-math.rad(cfg.Pitch), 0, 0)
	local back = rotation.LookVector * -1
	local hit = workspace:Spherecast(pivot, cfg.CollisionRadius, back * cfg.Distance, self.params)
	local allowed = hit and math.max(hit.Distance - 0.5, cfg.MinDistance) or cfg.Distance
	if allowed < self.distance then
		self.distance = allowed
	else
		self.distance += (allowed - self.distance) * alpha(4, dt)
	end
	camera.CFrame = CFrame.new(pivot + back * self.distance) * rotation
	camera.Focus = CFrame.new(pivot)

	-- 4. Speed kick
	local targetFov = cfg.BaseFov + math.clamp((velocity.Magnitude - cfg.FovSpeedStart) * cfg.FovPerSpeed, 0, cfg.FovMaxBoost)
	self.fov += (targetFov - self.fov) * alpha(5, dt)
	camera.FieldOfView = self.fov
end

return ChaseCamera
