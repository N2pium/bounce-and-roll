-- Rolls the local player's ball: momentum-based acceleration, jumps (coyote time, buffering,
-- one air jump), hold-to-float, dash, and bounce pads / pinball bumpers.
local CollectionService = game:GetService("CollectionService")

local BallController = {}
BallController.__index = BallController

local function alpha(rate, dt)
	return 1 - math.exp(-rate * dt)
end

function BallController.new(ball, root, config)
	local self = setmetatable({}, BallController)
	self.ball = ball
	self.root = root
	self.config = config
	self.radius = ball.Size.X / 2

	self.groundParams = RaycastParams.new()
	self.groundParams.FilterType = Enum.RaycastFilterType.Exclude
	self.groundParams.FilterDescendantsInstances = { ball.Parent }
	self.groundParams.RespectCanCollide = true
	self.groundParams.CollisionGroup = "Balls" -- only things a ball can actually land on

	self.grounded = false
	self.lastGroundedAt = -math.huge
	self.groundLockUntil = 0
	self.minAirVelocityY = 0
	self.airJumpsLeft = config.Jump.AirJumps
	self.jumpRequestedAt = nil
	self.jumpFresh = false
	self.lastDashAt = -math.huge
	self.touchCooldowns = setmetatable({}, { __mode = "k" })
	self.onEvent = function() end
	return self
end

function BallController:_probeGround()
	local r = self.radius
	local result = workspace:Spherecast(self.ball.Position, r * 0.9, Vector3.new(0, -(r * 0.1 + 0.9), 0), self.groundParams)
	return result ~= nil and result.Normal.Y > 0.5
end

function BallController:Step(dt, moveDirection, jumpHeld)
	local cfg = self.config
	local ball = self.ball
	local now = os.clock()
	local velocity = ball.AssemblyLinearVelocity

	-- Ground state (locked off briefly after a jump so we can't re-ground on the same frame)
	local wasGrounded = self.grounded
	self.grounded = now >= self.groundLockUntil and self:_probeGround()
	if self.grounded then
		self.lastGroundedAt = now
		self.airJumpsLeft = cfg.Jump.AirJumps
		if not wasGrounded then
			self.onEvent("land", -self.minAirVelocityY)
		end
		self.minAirVelocityY = 0
	else
		self.minAirVelocityY = math.min(self.minAirVelocityY, velocity.Y)
	end

	-- Horizontal: accelerate toward the input, but never brake a launch or a bump
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local change = Vector3.zero
	if moveDirection.Magnitude > 0.02 then
		local accel = self.grounded and cfg.Move.GroundAccel or cfg.Move.AirAccel
		change = moveDirection * cfg.Move.MaxSpeed - flat
		local maxStep = accel * dt
		if change.Magnitude > maxStep then
			change = change.Unit * maxStep
		end
		local speed = flat.Magnitude
		if speed > cfg.Move.MaxSpeed then
			local along = change:Dot(flat / speed)
			if along < 0 then
				change -= (flat / speed) * along
			end
		end
	elseif self.grounded then
		change = -flat * alpha(cfg.Move.GroundCoastDrag, dt)
	end

	local newVelocity = velocity + change

	-- Hold jump while falling to float down
	if jumpHeld and not self.grounded and newVelocity.Y < 0 then
		newVelocity += Vector3.new(0, workspace.Gravity * cfg.Jump.FloatAssist * dt, 0)
	end

	-- Jumps
	if self.jumpRequestedAt then
		if now - self.lastGroundedAt <= cfg.Jump.CoyoteTime then
			newVelocity = Vector3.new(newVelocity.X, math.max(newVelocity.Y, cfg.Jump.Velocity), newVelocity.Z)
			self:_leaveGround(now)
			self.jumpRequestedAt = nil
			self.onEvent("jump")
		elseif self.jumpFresh and self.airJumpsLeft > 0 then
			self.airJumpsLeft -= 1
			newVelocity = Vector3.new(newVelocity.X, math.max(newVelocity.Y, cfg.Jump.AirJumpVelocity), newVelocity.Z)
			self.jumpRequestedAt = nil
			self.onEvent("airjump")
		elseif now - self.jumpRequestedAt > cfg.Jump.BufferTime then
			self.jumpRequestedAt = nil
		end
		self.jumpFresh = false
	end

	if newVelocity ~= velocity then
		ball.AssemblyLinearVelocity = newVelocity
	end
end

function BallController:_leaveGround(now)
	self.grounded = false
	self.lastGroundedAt = -math.huge
	self.groundLockUntil = now + 0.2
end

function BallController:RequestJump()
	self.jumpRequestedAt = os.clock()
	self.jumpFresh = true
end

function BallController:RequestDash(direction)
	local cfg = self.config.Dash
	local now = os.clock()
	if now - self.lastDashAt < cfg.Cooldown then
		return false
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.05 then
		return false
	end
	direction = direction.Unit

	local velocity = self.ball.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local along = math.max(flat:Dot(direction), 0)
	self.ball.AssemblyLinearVelocity = direction * math.max(cfg.Speed, along) + Vector3.new(0, math.max(velocity.Y, 0) + cfg.Lift, 0)
	self.lastDashAt = now
	self:_leaveGround(now)
	self.onEvent("dash")
	return true
end

function BallController:IsDashing()
	return os.clock() - self.lastDashAt < self.config.Dash.ActiveTime
end

function BallController:DashReadiness()
	return math.clamp((os.clock() - self.lastDashAt) / self.config.Dash.Cooldown, 0, 1)
end

function BallController:ApplyVelocityChange(change)
	self.ball.AssemblyLinearVelocity += change
end

function BallController:HandleTouch(part)
	local isPad = CollectionService:HasTag(part, "BouncePad")
	local isBumper = not isPad and CollectionService:HasTag(part, "Bumper")
	if not isPad and not isBumper then
		return
	end
	local cfg = self.config.Pads
	local now = os.clock()
	local last = self.touchCooldowns[part]
	if last and now - last < cfg.Cooldown then
		return
	end
	self.touchCooldowns[part] = now

	local ball = self.ball
	local velocity = ball.AssemblyLinearVelocity
	if isPad then
		local power = part:GetAttribute("Power") or cfg.BouncePower
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		-- Optional "Push" attribute: guaranteed minimum horizontal speed toward the next platform.
		local push = part:GetAttribute("Push")
		if typeof(push) == "Vector3" and push.Magnitude > 0 then
			local direction = push.Unit
			local along = flat:Dot(direction)
			if along < push.Magnitude then
				flat += direction * (push.Magnitude - along)
			end
		end
		ball.AssemblyLinearVelocity = flat + Vector3.new(0, power, 0)
		self.airJumpsLeft = self.config.Jump.AirJumps
		self:_leaveGround(now)
		self.onEvent("pad", part)
	else
		local away = ball.Position - part.Position
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude < 0.01 then
			away = Vector3.new(-velocity.X, 0, -velocity.Z)
		end
		if away.Magnitude < 0.01 then
			away = Vector3.xAxis
		end
		local power = part:GetAttribute("Power") or cfg.BumperPower
		ball.AssemblyLinearVelocity = away.Unit * power + Vector3.new(0, math.max(velocity.Y, 0) + cfg.BumperLift, 0)
		self.onEvent("bumper", part)
	end
end

function BallController:Teleport(position)
	local ball, root = self.ball, self.root
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	ball.CFrame = CFrame.new(position)
	root.CFrame = CFrame.new(position - Vector3.new(0, self.config.Ball.AvatarLift, 0)) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
	self.grounded = false
	self.minAirVelocityY = 0
	self.jumpRequestedAt = nil
end

return BallController
