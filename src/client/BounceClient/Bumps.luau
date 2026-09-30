-- Ball-vs-ball bumps. Balls never physically collide (the "Balls" collision group), because two
-- client-owned balls jitter against each other over the network. Instead, every client checks for
-- overlaps; the ball closing faster is the attacker, reports the hit, and the server relays the
-- shove to the victim. Bots have no client, so their hits on us are resolved locally.
local CollectionService = game:GetService("CollectionService")

local Bumps = {}
Bumps.__index = Bumps

function Bumps.new(ball, controller, config, remotes)
	local self = setmetatable({}, Bumps)
	self.ball = ball
	self.controller = controller
	self.config = config.Bump
	self.remotes = remotes
	self.lastHitAt = setmetatable({}, { __mode = "k" })
	self.onBump = function() end
	self.connection = remotes.BumpApply.OnClientEvent:Connect(function(velocityChange, attacker, kind)
		if typeof(velocityChange) ~= "Vector3" then
			return
		end
		controller:ApplyVelocityChange(velocityChange)
		self.onBump(kind == "boost" and "boosted" or "bumped", ball.Position, attacker)
	end)
	return self
end

function Bumps:Destroy()
	self.connection:Disconnect()
end

function Bumps:Step(dt)
	local cfg = self.config
	local ball = self.ball
	local controller = self.controller
	local myPosition = ball.Position
	local myVelocity = ball.AssemblyLinearVelocity
	local now = os.clock()

	for _, other in CollectionService:GetTagged("RollBall") do
		if other == ball or not other:IsDescendantOf(workspace) then
			continue
		end
		local offset = other.Position - myPosition
		local distance = offset.Magnitude
		local reach = (ball.Size.X + other.Size.X) / 2
		if distance >= reach or distance < 1e-3 then
			continue
		end

		local normal = offset / distance
		local flatNormal = Vector3.new(normal.X, 0, normal.Z)
		if flatNormal.Magnitude < 0.1 then
			local flatVelocity = Vector3.new(myVelocity.X, 0, myVelocity.Z)
			flatNormal = flatVelocity.Magnitude > 0.1 and flatVelocity or Vector3.xAxis
		end
		flatNormal = flatNormal.Unit

		-- Gently push apart so balls don't sit inside each other.
		controller:ApplyVelocityChange(-flatNormal * (reach - distance) * cfg.Separation * dt)

		local myApproach = myVelocity:Dot(normal)
		local theirApproach = -other.AssemblyLinearVelocity:Dot(normal)
		local closing = myApproach + theirApproach
		local last = self.lastHitAt[other]
		if closing < cfg.MinClosingSpeed or (last and now - last < cfg.PairCooldown) then
			continue
		end
		self.lastHitAt[other] = now

		local contact = myPosition + normal * (ball.Size.X / 2)
		local power = cfg.Base + closing * cfg.PerClosingSpeed
		if myApproach >= theirApproach then
			if controller:IsDashing() then
				power *= cfg.DashMultiplier
			end
			power = math.min(power, cfg.Max)
			self.remotes.BumpRequest:FireServer(other, flatNormal * power + Vector3.new(0, cfg.Lift, 0))
			controller:ApplyVelocityChange(-flatNormal * power * cfg.Recoil + Vector3.new(0, cfg.Lift * 0.3, 0))
			self.onBump("hit", contact, other)
		elseif other:GetAttribute("OwnerUserId") == nil then
			power = math.min(power, cfg.Max)
			controller:ApplyVelocityChange(-flatNormal * power + Vector3.new(0, cfg.Lift, 0))
			self.onBump("bumped", contact, other)
		end
	end
end

return Bumps
