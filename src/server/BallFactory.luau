-- Creates hamster-ball parts for players and bots so they all share the same physics.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BounceRoll"):WaitForChild("Config"))

local BallFactory = {}

BallFactory.PlayerColors = {
	Color3.fromRGB(255, 140, 190),
	Color3.fromRGB(120, 190, 255),
	Color3.fromRGB(120, 230, 190),
	Color3.fromRGB(255, 225, 110),
	Color3.fromRGB(186, 160, 255),
	Color3.fromRGB(255, 170, 120),
}

function BallFactory.Make(color, cframe)
	local cfg = Config.Ball
	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * cfg.Radius * 2
	ball.Material = Enum.Material.Glass
	ball.Transparency = cfg.Transparency
	ball.Color = color
	ball.TopSurface = Enum.SurfaceType.Smooth
	ball.BottomSurface = Enum.SurfaceType.Smooth
	ball.CustomPhysicalProperties = PhysicalProperties.new(cfg.Density, cfg.Friction, cfg.Elasticity, cfg.FrictionWeight, cfg.ElasticityWeight)
	ball.CollisionGroup = "Balls"
	ball.CFrame = cframe
	CollectionService:AddTag(ball, "RollBall")
	return ball
end

-- Floating name tag used by bots.
function BallFactory.NameTag(ball, text)
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromScale(7, 1.4)
	tag.StudsOffset = Vector3.new(0, 5.5, 0)
	tag.MaxDistance = 120
	tag.Parent = ball
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = tag
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(45, 30, 80)
	stroke.Parent = label
	return tag
end

return BallFactory
