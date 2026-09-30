-- Server-simulated bot balls that fill out a show. Each round gives its bots a behavior:
--   Race     follow the map's waypoints, jump at Jump waypoints, respawn at Checkpoint ones
--   Hex      keep hopping onto live tiles
--   Sweeper  hold a spot and jump when a bar arm is about to arrive
-- Bots have a random skill so good players beat them.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BounceRoll"):WaitForChild("Config"))
local BallFactory = require(script.Parent.Parent:WaitForChild("BallFactory"))

local NAMES = { "Mochi", "Boba", "Pudding", "Sprinkle", "Marsh", "Nimbus", "Pebble", "Bubbles", "Taffy", "Dewdrop", "Gumdrop", "Sorbet", "Puff", "Biscuit", "Jellybean", "Wisp", "Cocoa", "Peaches", "Minty", "Button" }
local COLORS = {
	Color3.fromRGB(255, 200, 225),
	Color3.fromRGB(200, 240, 225),
	Color3.fromRGB(215, 205, 255),
	Color3.fromRGB(255, 240, 190),
	Color3.fromRGB(200, 225, 255),
}
local TAU = math.pi * 2

local BotBrain = {}

local Bot = {}
Bot.__index = Bot

local bots = {} -- every live bot
local folder = nil
local rng = Random.new()
local nameCursor = rng:NextInteger(1, #NAMES)

local groundParams = RaycastParams.new()
groundParams.RespectCanCollide = true
groundParams.CollisionGroup = "Balls"

function BotBrain.New()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "ShowBots"
		folder.Parent = workspace
	end
	nameCursor = nameCursor % #NAMES + 1
	local self = setmetatable({}, Bot)
	self.name = "Bot " .. NAMES[nameCursor]
	self.skill = rng:NextNumber(0.35, 0.9)
	self.speed = 30 + self.skill * 14
	self.ball = BallFactory.Make(COLORS[rng:NextInteger(1, #COLORS)], CFrame.new(0, -1000, 0))
	self.ball.Name = self.name
	self.ball.Anchored = true
	BallFactory.NameTag(self.ball, self.name)
	self.ball.Parent = folder
	self.behavior = nil
	self.lastPadAt = 0
	bots[self] = true
	return self
end

function Bot:Teleport(position)
	local ball = self.ball
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	ball.CFrame = CFrame.new(position)
end

function Bot:SetFrozen(frozen)
	self.ball.Anchored = frozen
	if not frozen then
		pcall(self.ball.SetNetworkOwner, self.ball, nil)
	end
end

function Bot:SetBehavior(behavior, context)
	self.behavior = behavior
	self.context = context
	self.state = {}
end

function Bot:Destroy()
	bots[self] = nil
	self.ball:Destroy()
end

function Bot:IsGrounded()
	groundParams.FilterDescendantsInstances = { self.ball }
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	local r = self.ball.Size.X / 2
	return workspace:Raycast(self.ball.Position, Vector3.new(0, -(r + 1.2), 0), groundParams)
end

-- Steer toward a point with limited acceleration, like a player holding the stick.
function Bot:MoveToward(target, speed, accel)
	local ball = self.ball
	local offset = Vector3.new(target.X - ball.Position.X, 0, target.Z - ball.Position.Z)
	if offset.Magnitude < 0.5 then
		return
	end
	local velocity = ball.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local change = offset.Unit * speed - flat
	local maxStep = (accel or 70) * self.dt
	if change.Magnitude > maxStep then
		change = change.Unit * maxStep
	end
	ball.AssemblyLinearVelocity = velocity + change
end

-- Bleed off horizontal speed (bots have no coasting drag of their own).
function Bot:Brake(rate)
	local v = self.ball.AssemblyLinearVelocity
	local keep = math.exp(-(rate or 4) * self.dt)
	self.ball.AssemblyLinearVelocity = Vector3.new(v.X * keep, v.Y, v.Z * keep)
end

function Bot:Jump(velocity)
	local v = self.ball.AssemblyLinearVelocity
	self.ball.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, velocity or Config.Jump.Velocity), v.Z)
end

-- Bounce pads are resolved on the owning client for players; bots need the same launch here.
function Bot:_checkPads(now)
	local hit = self:IsGrounded()
	if not hit or now - self.lastPadAt < Config.Pads.Cooldown or not CollectionService:HasTag(hit.Instance, "BouncePad") then
		return
	end
	self.lastPadAt = now
	local pad = hit.Instance
	local v = self.ball.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local push = pad:GetAttribute("Push")
	if typeof(push) == "Vector3" and push.Magnitude > 0 then
		local along = flat:Dot(push.Unit)
		if along < push.Magnitude then
			flat += push.Unit * (push.Magnitude - along)
		end
	end
	self.ball.AssemblyLinearVelocity = flat + Vector3.new(0, pad:GetAttribute("Power") or Config.Pads.BouncePower, 0)
end

-- Behaviors ----------------------------------------------------------------------------
BotBrain.Behaviors = {}

-- context: { waypoints = {BasePart}, killY = number }
function BotBrain.Behaviors.Race(bot, context)
	local state = bot.state
	local ball = bot.ball
	local waypoints = context.waypoints
	state.index = state.index or 1
	state.respawn = state.respawn or ball.Position

	if ball.Position.Y < context.killY then
		bot:Teleport(state.respawn + Vector3.new(0, 3, 0))
		return
	end
	local target = waypoints[state.index]
	if not target then
		bot:Brake() -- finished: stop instead of bouncing off the backstop
		return
	end
	local position = ball.Position
	local flatDistance = Vector3.new(target.Position.X - position.X, 0, target.Position.Z - position.Z).Magnitude
	local isJump = target:GetAttribute("Jump")
	if target:GetAttribute("Checkpoint") and flatDistance < 12 then
		state.respawn = target.Position
	end
	local nextPoint = waypoints[state.index + 1]
	-- Advance on arrival, or when we've already overshot toward the next waypoint.
	local overshot = nextPoint and (nextPoint.Position - position).Magnitude < (nextPoint.Position - target.Position).Magnitude
	if flatDistance < (isJump and 4 or 8) or overshot then
		if isJump and bot:IsGrounded() then
			bot:Jump()
		end
		state.index += 1
		target = nextPoint or target
	end
	-- Weaker bots wobble off the ideal line.
	state.wobble = state.wobble or rng:NextNumber(0, TAU)
	local wobble = Vector3.new(math.sin(os.clock() * 1.3 + state.wobble), 0, 0) * (1 - bot.skill) * 6
	bot:MoveToward(target.Position + wobble, bot.speed)
end

-- context: { liveTiles = function(): {Vector3} for tiles still standing, killY = number }
function BotBrain.Behaviors.Hex(bot, context)
	local state = bot.state
	local now = os.clock()
	local position = bot.ball.Position
	if not state.target or now > state.retargetAt or (state.target - position).Magnitude < 3 then
		local best, bestScore = nil, math.huge
		for _, center in context.liveTiles() do
			local dy = position.Y - center.Y
			if dy > 0 and dy < 12 then -- tiles on the layer we're standing on
				local flat = Vector3.new(center.X - position.X, 0, center.Z - position.Z).Magnitude
				local score = math.abs(flat - 14) + rng:NextNumber(0, 10) + (center - context.center).Magnitude * 0.15
				if score < bestScore then
					best, bestScore = center, score
				end
			end
		end
		state.target = best or context.center
		state.retargetAt = now + rng:NextNumber(0.6, 1.6) * (1.4 - bot.skill)
	end
	bot:MoveToward(state.target, 16 + bot.skill * 10, 60)
end

-- context: { center = Vector3, bars = function(): {Vector3 arm directions}, spin = function(): number rad/s }
function BotBrain.Behaviors.Sweeper(bot, context)
	local state = bot.state
	local position = bot.ball.Position
	if not state.spot then
		local angle = rng:NextNumber(0, TAU)
		state.spot = context.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(12, 30)
	end
	bot:MoveToward(state.spot, 12, 40)

	local spin = context.spin()
	if math.abs(spin) < 0.05 or not bot:IsGrounded() then
		return
	end
	local offset = position - context.center
	local myAngle = math.atan2(-offset.Z, offset.X) -- increases with positive spin about +Y
	local soonest = math.huge
	for _, arm in context.bars() do
		local armAngle = math.atan2(-arm.Z, arm.X)
		local gap = spin > 0 and (myAngle - armAngle) % TAU or (armAngle - myAngle) % TAU
		soonest = math.min(soonest, gap / math.abs(spin))
	end
	if soonest < 0.3 and not state.jumped then
		state.jumped = true
		-- Near-perfect while the bar is slow; misses creep in as it speeds up.
		local chance = math.clamp(0.99 - math.max(0, math.abs(spin) - 1.4) * 0.35 - (1 - bot.skill) * 0.08, 0.35, 0.99)
		if rng:NextNumber() < chance then
			bot:Jump()
		end
	elseif soonest > 0.6 then
		state.jumped = false
	end
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for bot in bots do
		if bot.behavior and not bot.ball.Anchored and bot.ball.Parent then
			bot.dt = dt
			bot:_checkPads(now)
			bot.behavior(bot, bot.context)
		end
	end
end)

return BotBrain
