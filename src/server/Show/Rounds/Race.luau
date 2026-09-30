-- Races (Roll Race, Tube Town): the first racers across the finish qualify; everyone else is out.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local BotBrain = require(script.Parent.Parent:WaitForChild("BotBrain"))

local Race = {}

local function inside(part, position)
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

function Race.Run(show, map, alive)
	local cfg = show.config
	local finish = map.Course.RaceFinish
	local waypoints = map.Waypoints:GetChildren()
	table.sort(waypoints, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)
	local tubes = {}
	for _, part in map:GetDescendants() do
		if CollectionService:HasTag(part, "TubeMouth") then
			table.insert(tubes, { mouth = part, model = part.Parent })
		end
	end
	local context = { waypoints = waypoints, killY = map:GetAttribute("KillY"), tubes = tubes }
	for _, p in alive do
		p:SetBehavior(BotBrain.Behaviors.Race, context)
	end

	local quota = math.clamp(math.floor(#alive * cfg.RaceQualifyShare + 0.5), 1, #alive)
	local qualified, finished = {}, {}
	local deadline = show:StartTimer(cfg.RaceTimeLimit)
	show:SetInfo(("QUALIFIED 0 / %d"):format(quota))

	while #qualified < quota and os.clock() < deadline do
		RunService.Heartbeat:Wait()
		local racing = 0
		for _, p in alive do
			if not finished[p] and p:IsValid() then
				racing += 1
				local ball = p:GetBall()
				if ball and inside(finish, ball.Position) then
					finished[p] = true
					table.insert(qualified, p)
					show:Qualify(p, #qualified)
					show:SetInfo(("QUALIFIED %d / %d"):format(#qualified, quota))
					if #qualified >= quota then
						break
					end
				end
			end
		end
		if racing == 0 then
			break
		end
	end
	return qualified
end

return Race
