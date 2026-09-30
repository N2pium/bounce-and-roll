-- Bounce & Roll server: puts every avatar inside a hamster ball, relays player-vs-player bumps,
-- keeps squad (friends-in-server) counts and runs the bump bots in the arena.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("BounceRoll")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")

workspace.Gravity = Config.World.Gravity
Players.RespawnTime = Config.World.RespawnTime

-- Balls never physically collide with each other: client-owned balls jitter against each other
-- over the network, so bumps are resolved by the custom system below instead.
local function ensureGroup(name)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end
ensureGroup("Balls")
ensureGroup("Avatars")
PhysicsService:CollisionGroupSetCollidable("Balls", "Balls", false)
for _, group in PhysicsService:GetRegisteredCollisionGroups() do
	PhysicsService:CollisionGroupSetCollidable("Avatars", group.name, false)
end

local BALL_COLORS = {
	Color3.fromRGB(255, 140, 190),
	Color3.fromRGB(120, 190, 255),
	Color3.fromRGB(120, 230, 190),
	Color3.fromRGB(255, 225, 110),
	Color3.fromRGB(186, 160, 255),
	Color3.fromRGB(255, 170, 120),
}

local function makeBall(color, cframe)
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

-- The avatar rides along inside the ball: no collisions, (almost) no mass.
local function prepareAvatarPart(part)
	if not part:IsA("BasePart") or part.Name == "Ball" then
		return
	end
	part.CollisionGroup = "Avatars"
	part.CanTouch = false
	part.CanQuery = false
	if part.Name == "HumanoidRootPart" then
		part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0)
	else
		part.Massless = true
	end
end

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")

	-- The ball does all the moving; stop the humanoid from fighting it.
	humanoid.WalkSpeed = 0
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.EvaluateStateMachine = false

	for _, descendant in character:GetDescendants() do
		prepareAvatarPart(descendant)
	end
	character.DescendantAdded:Connect(prepareAvatarPart)

	local lift = Config.Ball.AvatarLift
	local spawnRotation = root.CFrame.Rotation
	local ball = makeBall(BALL_COLORS[player.UserId % #BALL_COLORS + 1], CFrame.new(root.Position + Vector3.new(0, 2, 0)))
	ball:SetAttribute("OwnerUserId", player.UserId)
	root.CFrame = CFrame.new(ball.Position - Vector3.new(0, lift, 0)) * spawnRotation

	local ballCenter = Instance.new("Attachment")
	ballCenter.Name = "Center"
	ballCenter.Parent = ball

	local rootJoint = Instance.new("Attachment")
	rootJoint.Name = "BallJoint"
	rootJoint.Position = Vector3.new(0, lift, 0)
	rootJoint.Parent = root

	local socket = Instance.new("BallSocketConstraint")
	socket.Attachment0 = ballCenter
	socket.Attachment1 = rootJoint
	socket.Parent = ball

	-- Keeps the avatar upright while the shell rolls; the owning client steers its facing.
	local upright = Instance.new("AlignOrientation")
	upright.Name = "Upright"
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.Attachment0 = rootJoint
	upright.MaxTorque = math.huge
	upright.Responsiveness = 30
	upright.CFrame = spawnRotation
	upright.Parent = root

	local trailLeft = Instance.new("Attachment")
	trailLeft.Name = "TrailLeft"
	trailLeft.Position = Vector3.new(-2.5, lift, 0)
	trailLeft.Parent = root
	local trailRight = Instance.new("Attachment")
	trailRight.Name = "TrailRight"
	trailRight.Position = Vector3.new(2.5, lift, 0)
	trailRight.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = trailLeft
	trail.Attachment1 = trailRight
	trail.Lifetime = 0.3
	trail.MinLength = 0.2
	trail.LightEmission = 0.4
	trail.Color = ColorSequence.new(ball.Color, Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.4, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = root

	ball.Parent = character
	pcall(ball.SetNetworkOwner, ball, player)
end

-- Friends & squads ------------------------------------------------------------
local friendCache = {} -- friendCache[a][b] = true/false

local function cacheFriendship(a, b)
	local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
	local isFriend = ok and result == true
	friendCache[a] = friendCache[a] or {}
	friendCache[b] = friendCache[b] or {}
	friendCache[a][b] = isFriend
	friendCache[b][a] = isFriend
end

local function areFriends(a, b)
	return friendCache[a] ~= nil and friendCache[a][b] == true
end

local function refreshSquads()
	for _, player in Players:GetPlayers() do
		local count = 0
		for _, other in Players:GetPlayers() do
			if other ~= player and areFriends(player, other) then
				count += 1
			end
		end
		player:SetAttribute("SquadFriends", count)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	task.spawn(function()
		for _, other in Players:GetPlayers() do
			if other ~= player then
				cacheFriendship(player, other)
			end
		end
		refreshSquads()
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	friendCache[player] = nil
	for _, row in friendCache do
		row[player] = nil
	end
	refreshSquads()
end)

-- Bump relay ------------------------------------------------------------------
local bumpBudget = {}

Remotes.BumpRequest.OnServerEvent:Connect(function(attacker, target, velocityChange)
	if typeof(target) ~= "Instance" or typeof(velocityChange) ~= "Vector3" then
		return
	end
	local magnitude = velocityChange.Magnitude
	if magnitude ~= magnitude or magnitude == 0 then -- NaN / empty
		return
	end
	if not target:IsA("BasePart") or not CollectionService:HasTag(target, "RollBall") or not target:IsDescendantOf(workspace) then
		return
	end
	local character = attacker.Character
	local myBall = character and character:FindFirstChild("Ball")
	if not myBall or myBall == target then
		return
	end

	local cfg = Config.Bump
	local now = os.clock()
	local budget = bumpBudget[attacker]
	if not budget or now - budget.start > 1 then
		budget = { start = now, count = 0 }
		bumpBudget[attacker] = budget
	end
	budget.count += 1
	if budget.count > cfg.ServerMaxPerSecond then
		return
	end

	-- The server sees the attacker's ball a little late and the target a little early, so allow
	-- extra reach proportional to how fast both are moving.
	local lagSlack = (myBall.AssemblyLinearVelocity.Magnitude + target.AssemblyLinearVelocity.Magnitude) * cfg.ServerLagAllowance
	local reach = (myBall.Size.X + target.Size.X) / 2 + cfg.ServerReachTolerance + lagSlack
	if (myBall.Position - target.Position).Magnitude > reach then
		return
	end
	if magnitude > cfg.Max then
		velocityChange = velocityChange.Unit * cfg.Max
	end

	local victim = Players:GetPlayerByUserId(target:GetAttribute("OwnerUserId") or 0)
	if not victim then
		-- Server-owned bot ball.
		target:ApplyImpulse(velocityChange * target.AssemblyMass)
		return
	end

	if areFriends(attacker, victim) then
		-- Bumping a friend slingshots them forward instead of knocking them away.
		local flat = Vector3.new(velocityChange.X, 0, velocityChange.Z)
		local boost = flat.Magnitude > 0 and flat.Unit * cfg.FriendBoostSpeed or Vector3.zero
		Remotes.BumpApply:FireClient(victim, boost, attacker, "boost")
		return
	end

	local squad = math.min(victim:GetAttribute("SquadFriends") or 0, cfg.SquadMaxFriends)
	local resist = squad * cfg.SquadResistPerFriend
	Remotes.BumpApply:FireClient(victim, velocityChange * (1 - resist), attacker, "bump")
end)

Players.PlayerRemoving:Connect(function(player)
	bumpBudget[player] = nil
end)

-- Spinning obstacles stay server-simulated so everyone sees the same sweep.
for _, part in CollectionService:GetTagged("Spinner") do
	pcall(part.SetNetworkOwner, part, nil)
end

-- Bump bots -------------------------------------------------------------------
local BOT_COUNT = 4
local BOT_SPEED = 26
local BOT_ACCEL = 45

local function startBots()
	local map = workspace:FindFirstChild("BounceParkMap")
	local arena = map and map:FindFirstChild("Arena", true)
	if not arena then
		return
	end
	local rng = Random.new()
	local function randomPoint(spread, height)
		return arena.Position + Vector3.new(
			rng:NextNumber(-spread, spread) * arena.Size.X,
			arena.Size.Y / 2 + height,
			rng:NextNumber(-spread, spread) * arena.Size.Z
		)
	end

	local botFolder = Instance.new("Folder")
	botFolder.Name = "Bots"
	botFolder.Parent = map

	local bots = {}
	for i = 1, BOT_COUNT do
		local ball = makeBall(Color3.fromRGB(215, 215, 225), CFrame.new(randomPoint(0.3, 12)))
		ball.Name = "BumpBot" .. i
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromScale(8, 2)
		tag.StudsOffset = Vector3.new(0, 6, 0)
		tag.MaxDistance = 150
		tag.Parent = ball
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = "BOT"
		label.Parent = tag
		ball.Parent = botFolder
		pcall(ball.SetNetworkOwner, ball, nil)
		bots[i] = { ball = ball, target = randomPoint(0.35, 0), retargetAt = 0 }
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, bot in bots do
			local ball = bot.ball
			if ball.Position.Y < Config.World.KillY then
				ball.AssemblyLinearVelocity = Vector3.zero
				ball.AssemblyAngularVelocity = Vector3.zero
				ball.CFrame = CFrame.new(randomPoint(0.3, 25))
			end
			local toTarget = bot.target - ball.Position
			toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
			if now > bot.retargetAt or toTarget.Magnitude < 5 then
				bot.target = randomPoint(0.35, 0)
				bot.retargetAt = now + rng:NextNumber(2, 4)
			elseif toTarget.Magnitude > 0 then
				local velocity = ball.AssemblyLinearVelocity
				local flat = Vector3.new(velocity.X, 0, velocity.Z)
				local change = toTarget.Unit * BOT_SPEED - flat
				local maxStep = BOT_ACCEL * dt
				if change.Magnitude > maxStep then
					change = change.Unit * maxStep
				end
				ball:ApplyImpulse(change * ball.AssemblyMass)
			end
		end
	end)
end

startBots()
