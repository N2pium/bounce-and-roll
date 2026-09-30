-- Builds "Bounce Park" (the week-1 test map), the shared remotes, lighting and StarterPlayer settings.
-- Paste into the Studio command bar (Edit mode) and run. Safe to re-run: it replaces the old map.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Shared folder + remotes (Rojo also declares these; this is for places without Rojo)
local shared = ReplicatedStorage:FindFirstChild("BounceRoll") or Instance.new("Folder")
shared.Name = "BounceRoll"
shared.Parent = ReplicatedStorage
local remotes = shared:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = shared
for _, name in { "BumpRequest", "BumpApply" } do
	if not remotes:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
end

-- The ball does all the moving; default character controls are turned off.
StarterPlayer.EnableMouseLockOption = false -- Shift is dash
StarterPlayer.CameraMode = Enum.CameraMode.Classic
StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
StarterPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
workspace.FallenPartsDestroyHeight = -500 -- only settable in Edit mode

-- Lighting: bright pastel afternoon
Lighting.ClockTime = 14.5
Lighting.Brightness = 2.5
Lighting.OutdoorAmbient = Color3.fromRGB(175, 165, 205)
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Density = 0.28
atmosphere.Offset = 0.1
atmosphere.Glare = 0.2
atmosphere.Haze = 1.2
atmosphere.Color = Color3.fromRGB(225, 210, 255)
atmosphere.Decay = Color3.fromRGB(170, 200, 255)
atmosphere.Parent = Lighting

-- Map ------------------------------------------------------------------------------
local old = workspace:FindFirstChild("BounceParkMap")
if old then
	old:Destroy()
end
if workspace:FindFirstChild("Baseplate") then
	workspace.Baseplate:Destroy()
end

local map = Instance.new("Folder")
map.Name = "BounceParkMap"
map.Parent = workspace
local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = map
	return f
end
local course, zones, signs, decor = folder("Course"), folder("CameraZones"), folder("Signs"), folder("Decor")

local C = {
	lavender = Color3.fromRGB(186, 160, 255),
	pink = Color3.fromRGB(255, 140, 190),
	mint = Color3.fromRGB(120, 230, 190),
	sky = Color3.fromRGB(120, 190, 255),
	lemon = Color3.fromRGB(255, 225, 110),
	peach = Color3.fromRGB(255, 170, 120),
	lime = Color3.fromRGB(150, 255, 90),
	hot = Color3.fromRGB(255, 80, 140),
	white = Color3.fromRGB(250, 248, 255),
}

-- Note: always position with CFrame, never Position — the Position setter pushes parts up out of overlaps.
local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent or course
	for k, v in props do
		if k ~= "Tags" and k ~= "Attributes" and k ~= "Parent" then
			p[k] = v
		end
	end
	for _, t in props.Tags or {} do
		CollectionService:AddTag(p, t)
	end
	for k, v in props.Attributes or {} do
		p:SetAttribute(k, v)
	end
	p.Parent = parent
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis vertical

-- Flat slab given its top-surface height
local function slab(name, x, z, top, sx, sz, color)
	return part({ Name = name, Size = Vector3.new(sx, 2, sz), CFrame = CFrame.new(x, top - 1, z), Color = color })
end
local function disc(name, x, z, top, d, h, color)
	return part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = CFrame.new(x, top - h / 2, z) * UPRIGHT, Color = color })
end
local checkpoints = 0
local function checkpoint(x, z, top)
	checkpoints += 1
	return part({
		Name = "Checkpoint" .. checkpoints,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 16, 16),
		CFrame = CFrame.new(x, top + 0.2, z) * UPRIGHT,
		Color = C.lemon,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		Tags = { "Checkpoint" },
		Attributes = { Order = checkpoints },
	})
end
local function bumper(x, z, top)
	return part({
		Name = "Bumper",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5, 6, 6),
		CFrame = CFrame.new(x, top + 2.5, z) * UPRIGHT,
		Color = C.hot,
		Material = Enum.Material.Neon,
		Tags = { "Bumper" },
	})
end
-- Pads sit flush with the floor (a raised lip eats the ball's forward speed).
-- "Push" guarantees a minimum horizontal speed toward the next platform.
local function pad(name, x, z, top, sx, sz, power, push)
	return part({
		Name = name,
		Size = Vector3.new(sx, 1, sz),
		CFrame = CFrame.new(x, top - 0.4, z),
		Color = C.lime,
		Material = Enum.Material.Neon,
		Tags = { "BouncePad" },
		Attributes = { Power = power, Push = push },
	})
end
local function sign(text, position, color)
	local anchor = part({ Name = "Sign", Size = Vector3.one, CFrame = CFrame.new(position), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = signs })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(30, 6)
	gui.MaxDistance = 300
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or C.white
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(45, 30, 80)
	stroke.Parent = label
end
-- Camera zones: inside each box the camera faces Yaw degrees (180 = +Z, -90 = +X).
local function zone(name, min, max, yawDeg, priority)
	part({
		Name = name,
		Size = max - min,
		CFrame = CFrame.new((min + max) / 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = zones,
		Tags = { "CameraZone" },
		Attributes = { Yaw = yawDeg, Priority = priority },
	})
end

-- 0. Spawn island
disc("SpawnIsland", 0, 0, 60, 60, 4, C.lavender)
disc("SpawnRim", 0, 0, 58.5, 64, 4, C.pink)
checkpoint(0, 0, 60)
local spawn = workspace:FindFirstChildOfClass("SpawnLocation") or Instance.new("SpawnLocation")
spawn.Size = Vector3.new(6, 1, 6)
spawn.CFrame = CFrame.new(0, 60.5, 0)
spawn.Anchored = true
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Duration = 0
spawn.Neutral = true
spawn.Parent = workspace
sign("ROLL!", Vector3.new(0, 76, 30), C.lemon)

-- 1. Welcome slope with pinball bumpers (z 30 -> 130, drops 60 -> 45)
local slopeLength = math.sqrt(100 ^ 2 + 15 ^ 2)
local slopeTop = CFrame.new(0, 52.5, 80) * CFrame.Angles(math.atan(15 / 100), 0, 0) -- centre of the top surface
part({ Name = "WelcomeSlope", Size = Vector3.new(36, 2, slopeLength), CFrame = slopeTop * CFrame.new(0, -1, 0), Color = C.mint })
for _, side in { -1, 1 } do
	part({ Name = "SlopeRail", Size = Vector3.new(1.5, 3, slopeLength), CFrame = slopeTop * CFrame.new(side * 18.75, 1.5, 0), Color = C.pink })
end
local function slopeY(z)
	return 60 - (z - 30) * 0.15
end
for _, p in { { -8, 62 }, { 9, 84 }, { -3, 108 } } do
	bumper(p[1], p[2], slopeY(p[2]))
end

-- 2. Landing + hops
slab("Landing1", 0, 150, 45, 40, 40, C.peach)
checkpoint(0, 150, 45)
sign("HOP!", Vector3.new(0, 62, 175), C.white)
slab("Hop1", 0, 190, 45, 18, 18, C.sky)
slab("Hop2", 0, 218, 47.5, 18, 18, C.lemon)
slab("Hop3", 0, 246, 50, 18, 18, C.lavender)

-- 3. Landing 2 + bounce pad up to the upper deck
slab("Landing2", 0, 285, 51, 40, 40, C.mint)
checkpoint(0, 275, 51)
pad("BouncePad", 0, 298, 51, 16, 10, 95, Vector3.new(0, 0, 25))
sign("BOING!", Vector3.new(0, 66, 298), C.lime)
slab("UpperDeck", 0, 345, 85, 40, 50, C.pink)
checkpoint(0, 355, 85)

-- 4. Balance beams around a sweeper
slab("Beam1", 0, 381.5, 85, 14, 23, C.lemon)
disc("SweeperDisc", 0, 410, 85, 34, 2, C.sky)
slab("Beam2", 0, 438.5, 85, 14, 23, C.lemon)
local post = part({ Name = "SweeperPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 4, 4), CFrame = CFrame.new(0, 90, 410) * UPRIGHT, Color = C.hot })
local bar = part({
	Name = "SweeperBar",
	Size = Vector3.new(34, 2.5, 2.5),
	CFrame = CFrame.new(0, 87.5, 410),
	Color = C.hot,
	Anchored = false,
	Tags = { "Spinner" },
	CustomPhysicalProperties = PhysicalProperties.new(20, 0.3, 0.8, 1, 50),
})
local postAttachment = Instance.new("Attachment")
postAttachment.Name = "Hinge"
postAttachment.CFrame = CFrame.new(-2.5, 0, 0) -- the post's local X is world up
postAttachment.Parent = post
local barAttachment = Instance.new("Attachment")
barAttachment.Name = "Hinge"
barAttachment.CFrame = CFrame.Angles(0, 0, math.rad(90))
barAttachment.Parent = bar
local hinge = Instance.new("HingeConstraint")
hinge.Attachment0 = postAttachment
hinge.Attachment1 = barAttachment
hinge.ActuatorType = Enum.ActuatorType.Motor
hinge.AngularVelocity = 1.4
hinge.MotorMaxTorque = 1e9
hinge.MotorMaxAcceleration = math.huge
hinge.Parent = bar
local noCollide = Instance.new("NoCollisionConstraint")
noCollide.Part0 = post
noCollide.Part1 = bar
noCollide.Parent = bar
sign("JUMP THE SWEEPER", Vector3.new(0, 104, 390), C.white)

-- 5. Turn platform + bumper arena (course turns toward +X)
slab("TurnPlatform", 0, 470, 85, 40, 40, C.sky)
checkpoint(0, 470, 85)
slab("Arena", 65, 470, 85, 90, 90, C.lavender)
for _, p in { { 45, 450 }, { 45, 490 }, { 70, 470 }, { 92, 445 }, { 92, 495 } } do
	bumper(p[1], p[2], 85)
end
sign("BUMP THE BOTS!", Vector3.new(50, 102, 470), C.lemon)

-- 6. Final launch to the finish island
pad("FinalPad", 104, 470, 85, 10, 16, 85, Vector3.new(30, 0, 0))
sign("GO FAST!", Vector3.new(104, 100, 470), C.lime)
disc("FinishIsland", 160, 470, 100, 60, 6, C.mint)
disc("FinishRim", 160, 470, 98.5, 64, 6, C.peach)
part({
	Name = "Backstop",
	Size = Vector3.new(2, 18, 60),
	CFrame = CFrame.new(193, 109, 470),
	Material = Enum.Material.Glass,
	Transparency = 0.6,
	Color = C.sky,
	CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0.9, 1, 50),
})
part({
	Name = "Finish",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.4, 18, 18),
	CFrame = CFrame.new(160, 100.2, 470) * UPRIGHT,
	Color = C.lemon,
	Material = Enum.Material.Neon,
	Transparency = 0.2,
	CanCollide = false,
	CanQuery = false,
	Tags = { "Finish" },
})
sign("FINISH", Vector3.new(160, 116, 470), C.lemon)

-- Kill sea far below
part({
	Name = "CandySea",
	Size = Vector3.new(2048, 4, 2048),
	CFrame = CFrame.new(0, 0, 300),
	Color = Color3.fromRGB(125, 205, 255),
	Transparency = 0.15,
	CanCollide = false,
	CanQuery = false,
	Tags = { "KillPart" },
	Parent = decor,
})

zone("Zone_Straight", Vector3.new(-32, 20, -40), Vector3.new(32, 220, 452), 180, 1)
zone("Zone_Turn", Vector3.new(-32, 20, 452), Vector3.new(20, 220, 500), -90, 2)
zone("Zone_Arena", Vector3.new(20, 20, 410), Vector3.new(220, 220, 540), -90, 2)

-- Decor: floating cloud puffs, kept below the course
local rng = Random.new(7)
for _ = 1, 22 do
	local d = rng:NextNumber(14, 34)
	part({
		Name = "Cloud",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * d,
		Color = C.white,
		Transparency = 0.1,
		CFrame = CFrame.new(rng:NextNumber(-160, 280), rng:NextNumber(8, 30), rng:NextNumber(-80, 600)),
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = decor,
	})
end

print("Bounce Park built")
