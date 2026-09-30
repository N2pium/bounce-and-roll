-- HEX-A-ROLL: three layers of hex tiles; a tile drops shortly after anyone rolls onto it.
local TweenService = game:GetService("TweenService")

local BotBrain = require(script.Parent.Parent:WaitForChild("BotBrain"))
local Survival = require(script.Parent:WaitForChild("Survival"))

local DROP_DELAY = 0.55
local WHITE = Color3.new(1, 1, 1)

local Hex = {}

function Hex.Run(show, map, alive, entry)
	local tileFolder = map.Course.Tiles
	local tiles = {}
	local centerSum, count, topY = Vector3.zero, 0, -math.huge
	for _, tile in tileFolder:GetChildren() do
		local first = tile:FindFirstChildWhichIsA("BasePart")
		local top = first.Position + Vector3.new(0, first.Size.Y / 2, 0)
		tiles[tile] = { center = top, live = true }
		centerSum += top
		count += 1
		topY = math.max(topY, top.Y)
	end
	local center = Vector3.new(centerSum.X / count, topY, centerSum.Z / count)

	local liveCenters = {}
	local context = {
		center = center,
		liveTiles = function()
			return liveCenters
		end,
	}
	for _, p in alive do
		p:SetBehavior(BotBrain.Behaviors.Hex, context)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { tileFolder }

	local function drop(tile)
		local info = tiles[tile]
		if not info or info.dropping then
			return
		end
		info.dropping = true
		for _, part in tile:GetChildren() do
			part.Color = part.Color:Lerp(WHITE, 0.55)
		end
		task.delay(DROP_DELAY, function()
			info.live = false
			for _, part in tile:GetChildren() do
				part.CanCollide = false
				TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
			task.delay(0.4, function()
				tile:Destroy()
			end)
		end)
	end

	local keep = Survival.KeepCount(show, alive, entry)
	return Survival.Run(show, map, alive, keep, show.config.HexTimeLimit, function(survivors)
		table.clear(liveCenters)
		for _, info in tiles do
			if info.live and not info.dropping then
				table.insert(liveCenters, info.center)
			end
		end
		for _, p in survivors do
			local ball = p:GetBall()
			if ball then
				local hit = workspace:Raycast(ball.Position, Vector3.new(0, -(ball.Size.Y / 2 + 1.5), 0), params)
				if hit then
					drop(hit.Instance.Parent)
				end
			end
		end
	end)
end

return Hex
