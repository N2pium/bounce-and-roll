-- SWEEPER: a spinning bar speeds up over time; a second arm appears halfway through.
local BotBrain = require(script.Parent.Parent:WaitForChild("BotBrain"))
local Survival = require(script.Parent:WaitForChild("Survival"))

local BASE_SPIN = 1
local SPIN_RAMP = 0.03 -- rad/s gained per second
local MAX_SPIN = 2.6
local SECOND_ARM_AT = 30

local Sweeper = {}

function Sweeper.Run(show, map, alive, entry)
	local course = map.Course
	local bar, arm = course.SweeperBar, course.SweeperBar2
	local motor = bar:FindFirstChild("Motor")
	local platform = course.Platform
	local center = platform.Position + Vector3.new(0, platform.Size.X / 2, 0) -- upright cylinder: local X is height
	pcall(bar.SetNetworkOwner, bar, nil)

	local secondArm = false
	local context = {
		center = center,
		spin = function()
			return bar.AssemblyAngularVelocity.Y
		end,
		bars = function()
			local arms = { bar.CFrame.RightVector, -bar.CFrame.RightVector }
			if secondArm then
				table.insert(arms, bar.CFrame.LookVector)
				table.insert(arms, -bar.CFrame.LookVector)
			end
			return arms
		end,
	}
	for _, p in alive do
		p:SetBehavior(BotBrain.Behaviors.Sweeper, context)
	end

	local keep = Survival.KeepCount(show, alive, entry)
	return Survival.Run(show, map, alive, keep, show.config.SweeperTimeLimit, function(_, elapsed)
		motor.AngularVelocity = math.min(BASE_SPIN + elapsed * SPIN_RAMP, MAX_SPIN)
		if not secondArm and elapsed > SECOND_ARM_AT then
			secondArm = true
			arm.Transparency = 0
			arm.CanCollide = true
			show:Feed("A second arm appears!")
		end
	end)
end

return Sweeper
