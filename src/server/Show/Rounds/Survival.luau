-- Shared rules for survival rounds: whoever drops below the map's KillY is out, and the round
-- ends once only `keep` remain (or time runs out).
local RunService = game:GetService("RunService")

-- Positions from clients take a moment to catch up after the countdown teleport.
local FALL_GRACE = 1.5

local Survival = {}

function Survival.KeepCount(show, alive, entry)
	if entry.final then
		return 1
	end
	return math.max(1, math.min(math.ceil(#alive * show.config.SurvivalKeepShare), #alive - 1))
end

local function height(p)
	local ball = p:IsValid() and p:GetBall()
	return ball and ball.Position.Y or -math.huge
end

-- Runs until `keep` survivors remain or the deadline passes. `onStep(survivors, elapsed)` runs
-- every frame for round-specific logic. Returns the survivors.
function Survival.Run(show, map, alive, keep, timeLimit, onStep)
	local killY = map:GetAttribute("KillY")
	local survivors = table.clone(alive)
	local started = os.clock()
	local deadline = show:StartTimer(timeLimit)
	local function info()
		show:SetInfo(("ALIVE %d  ·  %d SURVIVE"):format(#survivors, keep))
	end
	info()

	while #survivors > keep and os.clock() < deadline do
		RunService.Heartbeat:Wait()
		local fallen = {}
		if os.clock() - started > FALL_GRACE then
			for i = #survivors, 1, -1 do
				local p = survivors[i]
				if height(p) < killY then
					table.insert(fallen, table.remove(survivors, i))
				end
			end
		end
		if #fallen > 0 then
			-- If everyone left drops at once, the last one to fall (highest) survives.
			if #survivors == 0 then
				table.sort(fallen, function(a, b)
					return height(a) > height(b)
				end)
				table.insert(survivors, table.remove(fallen, 1))
			end
			for _, p in fallen do
				show:Eliminate(p)
			end
			info()
		end
		if onStep then
			onStep(survivors, os.clock() - started)
		end
	end
	return survivors
end

return Survival
