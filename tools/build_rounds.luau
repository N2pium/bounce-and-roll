-- Builds the round maps (Roll Race, Hex-a-Roll, Sweeper) as Models in ServerStorage.RoundMaps.
-- The show clones one into workspace.ActiveRound for each round. Each map carries:
--   attributes  Kind, DisplayName, Goal, KillY
--   Course/     the level (tags: Checkpoint, Bumper, BouncePad, Spinner, HexTile)
--   Spawns/     spawn points (one participant each)
--   Waypoints/  bot route for races (attributes: Jump, Checkpoint)
--   Decor/      clouds and orbs
-- Run in the Studio command bar (Edit mode) after build_map / dress_map. Safe to re-run.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local cloudTemplate = ReplicatedStorage.BounceRoll.Assets.CloudMesh

local CHECKER = "rbxassetid://10630078103"
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis vertical
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local C = {
	lavender = rgb(186, 160, 255),
	pink = rgb(255, 140, 190),
	mint = rgb(120, 230, 190),
	sky = rgb(120, 190, 255),
	lemon = rgb(255, 225, 110),
	peach = rgb(255, 170, 120),
	lime = rgb(150, 255, 90),
	hot = rgb(255, 80, 140),
	white = rgb(250, 248, 255),
}
local PASTELS = { rgb(255, 170, 205), rgb(150, 235, 205), rgb(195, 175, 255), rgb(255, 232, 150), rgb(160, 210, 255) }

local roundMaps = ServerStorage:FindFirstChild("RoundMaps") or Instance.new("Folder")
roundMaps.Name = "RoundMaps"
roundMaps.Parent = ServerStorage

local map, origin -- the map being built and its world origin
local rng = Random.new(9)

local function newMap(name, worldOrigin, attributes)
	local old = roundMaps:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	map = Instance.new("Model")
	map.Name = name
	origin = worldOrigin
	for key, value in attributes do
		map:SetAttribute(key, value)
	end
	for _, folderName in { "Course", "Spawns", "Waypoints", "Decor" } do
		local folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = map
	end
	map.Parent = roundMaps
end

-- Positions below are relative to the map origin. Always place with CFrame, never Position.
local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent or map.Course
	for key, value in props do
		if key ~= "Tags" and key ~= "Attributes" and key ~= "Parent" then
			p[key] = value
		end
	end
	for _, tag in props.Tags or {} do
		CollectionService:AddTag(p, tag)
	end
	for key, value in props.Attributes or {} do
		p:SetAttribute(key, value)
	end
	p.Parent = parent
	return p
end
local function at(x, y, z)
	return CFrame.new(origin + Vector3.new(x, y, z))
end
local function ghost(props)
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = props.CanTouch or false
	props.Transparency = props.Transparency or 1
	return part(props)
end
local function checker(p, face)
	local texture = Instance.new("Texture")
	texture.Texture = CHECKER
	texture.Face = face or Enum.NormalId.Top
	texture.StudsPerTileU = 8
	texture.StudsPerTileV = 8
	texture.Transparency = 0.7
	texture.Parent = p
end
-- Flat slab given the centre of its top surface.
local function slab(name, x, top, z, sx, sz, color)
	local p = part({ Name = name, Size = Vector3.new(sx, 2, sz), CFrame = at(x, top - 1, z), Color = color })
	checker(p)
	return p
end
local function disc(name, x, top, z, d, h, color)
	local p = part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = at(x, top - h / 2, z) * UPRIGHT, Color = color })
	checker(p, Enum.NormalId.Right)
	return p
end
local function bumper(x, top, z)
	return part({ Name = "Bumper", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 6, 6), CFrame = at(x, top + 2.5, z) * UPRIGHT, Color = C.hot, Material = Enum.Material.Neon, Tags = { "Bumper" } })
end
local function pad(x, top, z, sx, sz, power, push)
	return part({ Name = "BouncePad", Size = Vector3.new(sx, 1, sz), CFrame = at(x, top - 0.4, z), Color = C.lime, Material = Enum.Material.Neon, Tags = { "BouncePad" }, Attributes = { Power = power, Push = push } })
end
local function checkpoint(order, x, top, z)
	return ghost({ Name = "Checkpoint" .. order, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 16, 16), CFrame = at(x, top + 0.2, z) * UPRIGHT, Color = C.lemon, Material = Enum.Material.Neon, Transparency = 0.35, CanTouch = true, Tags = { "Checkpoint" }, Attributes = { Order = order } })
end
local function spawnPoint(x, y, z)
	ghost({ Name = "Spawn", Size = Vector3.one, CFrame = at(x, y, z), Parent = map.Spawns })
end
local function waypoint(index, x, y, z, attributes)
	ghost({ Name = tostring(index), Size = Vector3.one, CFrame = at(x, y, z), Parent = map.Waypoints, Attributes = attributes or {} })
end
local function zone(min, max, yaw, pitch, distance)
	local center = (min + max) / 2
	ghost({ Name = "CameraZone", Size = max - min, CFrame = at(center.X, center.Y, center.Z), Tags = { "CameraZone" }, Attributes = { Yaw = yaw, Priority = 5, Pitch = pitch, Distance = distance } })
end
local function sign(text, x, y, z, color)
	local anchor = ghost({ Name = "Sign", Size = Vector3.one, CFrame = at(x, y, z), Parent = map.Decor })
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
	stroke.Color = rgb(45, 30, 80)
	stroke.Parent = label
end
-- Rotating sweeper bar on an anchored post. The round (or BallServer) keeps it server-simulated.
local function sweeper(x, top, z, length, speed)
	local post = part({ Name = "SweeperPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, 5, 5), CFrame = at(x, top + 6, z) * UPRIGHT, Color = C.hot })
	local bar = part({ Name = "SweeperBar", Size = Vector3.new(length, 2.6, 2.6), CFrame = at(x, top + 1.6, z), Color = C.hot, Anchored = false, Tags = { "Spinner" }, CustomPhysicalProperties = PhysicalProperties.new(25, 0.3, 0.8, 1, 50) })
	local postAttachment = Instance.new("Attachment")
	postAttachment.CFrame = CFrame.new(-4.4, 0, 0) -- post's local X is world up
	postAttachment.Parent = post
	local barAttachment = Instance.new("Attachment")
	barAttachment.CFrame = CFrame.Angles(0, 0, math.rad(90))
	barAttachment.Parent = bar
	local hinge = Instance.new("HingeConstraint")
	hinge.Name = "Motor"
	hinge.Attachment0 = postAttachment
	hinge.Attachment1 = barAttachment
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = speed
	hinge.MotorMaxTorque = 1e10
	hinge.MotorMaxAcceleration = math.huge
	hinge.Parent = bar
	local noCollide = Instance.new("NoCollisionConstraint")
	noCollide.Part0 = post
	noCollide.Part1 = bar
	noCollide.Parent = bar
	return post, bar
end
local function cloudField(count, spreadX, spreadZ, yMin, yMax, centerZ)
	for _ = 1, count do
		local c = cloudTemplate:Clone()
		c.Size = cloudTemplate.Size * rng:NextNumber(1.2, 2.4)
		c.CFrame = at(rng:NextNumber(-spreadX, spreadX), rng:NextNumber(yMin, yMax), (centerZ or 0) + rng:NextNumber(-spreadZ, spreadZ)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		c.Material = Enum.Material.SmoothPlastic
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CastShadow = false
		c:SetAttribute("FloatAmount", 2)
		CollectionService:AddTag(c, "MoodCloud")
		c.Parent = map.Decor
	end
end
local function orbRing(count, radius, y, centerZ)
	for i = 1, count do
		local angle = i / count * math.pi * 2
		local orb = ghost({ Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(2.5, 4.5), CFrame = at(math.cos(angle) * radius, y + rng:NextNumber(-4, 8), (centerZ or 0) + math.sin(angle) * radius), Color = PASTELS[i % #PASTELS + 1], Material = Enum.Material.Neon, Transparency = 0, Parent = map.Decor, Tags = { "DreamFloat" }, Attributes = { FloatAmount = 3 } })
		orb.CastShadow = false
	end
end

--------------------------------------------------------------------------------------------
-- ROLL RACE: slope with bumpers, pinball slalom, hops, a sweeper disc, bounce pad to the finish.
--------------------------------------------------------------------------------------------
newMap("Race", Vector3.new(1500, 100, 0), { Kind = "Race", DisplayName = "ROLL RACE", Goal = "Roll to the finish!", KillY = 55 })

slab("StartPad", 0, 0, 15, 60, 30, C.lavender)
for row = 0, 4 do
	for col = 0, 3 do
		spawnPoint(-18 + col * 12, 5, 5 + row * 5)
	end
end
sign("GO!", 0, 14, 32, C.lime)

local slopeLength = math.sqrt(90 ^ 2 + 12 ^ 2)
local slopeTop = at(0, -6, 75) * CFrame.Angles(math.atan(12 / 90), 0, 0)
local slope = part({ Name = "Slope", Size = Vector3.new(50, 2, slopeLength), CFrame = slopeTop * CFrame.new(0, -1, 0), Color = C.mint })
checker(slope)
for _, side in { -1, 1 } do
	part({ Name = "Rail", Size = Vector3.new(1.5, 3, slopeLength), CFrame = slopeTop * CFrame.new(side * 25.75, 1.5, 0), Color = C.pink })
end
local function slopeY(z)
	return -(z - 30) * 12 / 90
end
for _, p in { { -12, 55 }, { 12, 70 }, { 0, 88 }, { -15, 105 }, { 15, 105 } } do
	bumper(p[1], slopeY(p[2]), p[2])
end

slab("Slalom", 0, -12, 150, 50, 60, C.peach)
checkpoint(1, 0, -12, 128)
for _, p in { { -12, 140 }, { 12, 140 }, { 0, 155 }, { -15, 170 }, { 15, 170 } } do
	bumper(p[1], -12, p[2])
end

slab("Hop1", 0, -12, 195, 26, 18, C.sky)
slab("Hop2", 0, -10, 222, 26, 18, C.lemon)
slab("Hop3", 0, -8, 249, 26, 18, C.pink)
sign("HOP!", 0, 8, 190, C.white)

slab("Landing", 0, -8, 281, 50, 38, C.mint)
checkpoint(2, 0, -8, 272)
disc("SpinDisc", 0, -8, 325, 50, 2, C.sky)
sweeper(0, -8, 325, 48, 1.2)
slab("PadDeck", 0, -8, 362, 40, 24, C.lavender)
checkpoint(3, 0, -8, 356)
pad(0, -8, 368, 16, 8, 95, Vector3.new(0, 0, 25))
sign("BOING!", 0, 8, 366, C.lime)

slab("FinishDeck", 0, 25, 410, 50, 50, C.mint)
part({ Name = "FinishLine", Size = Vector3.new(50, 0.3, 3), CFrame = at(0, 25.15, 403), Color = C.lemon, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
ghost({ Name = "RaceFinish", Size = Vector3.new(50, 16, 32), CFrame = at(0, 33, 419) })
-- Soaks up speed (elasticity weight beats the ball's) so finishers don't bounce back off the deck.
part({ Name = "Backstop", Size = Vector3.new(50, 20, 2), CFrame = at(0, 35, 437), Material = Enum.Material.Glass, Transparency = 0.6, Color = C.sky, CustomPhysicalProperties = PhysicalProperties.new(1, 0.6, 0.2, 5, 100) })
sign("FINISH", 0, 45, 410, C.lemon)

for i, w in {
	{ 0, 0, 20 },
	{ 0, -6, 75 },
	{ 0, -12, 125, { Checkpoint = true } },
	{ 0, -12, 140 },
	{ -8, -12, 155 },
	{ 0, -12, 172 },
	{ 0, -12, 180, { Jump = true } },
	{ 0, -12, 202, { Jump = true } },
	{ 0, -10, 229, { Jump = true } },
	{ 0, -8, 256, { Jump = true } },
	{ 0, -8, 285, { Checkpoint = true } },
	{ -17, -8, 312 },
	{ -17, -8, 338 },
	{ 0, -8, 356, { Checkpoint = true } },
	{ 0, -8, 368 },
	{ 0, 25, 415 },
} do
	waypoint(i, w[1], w[2] + 4, w[3], w[4])
end

zone(Vector3.new(-45, -70, -20), Vector3.new(45, 120, 450), 180, 24, 30)
cloudField(26, 220, 320, -75, -50, 220)
orbRing(10, 60, 10, 200)

--------------------------------------------------------------------------------------------
-- HEX-A-ROLL: three layers of hex tiles that drop shortly after being touched.
--------------------------------------------------------------------------------------------
newMap("HexARoll", Vector3.new(2500, 150, 0), { Kind = "Hex", DisplayName = "HEX-A-ROLL", Goal = "Tiles fall after you touch them. Don't drop!", KillY = 55 })

local HEX_RADIUS = 6.4 -- circumradius
local HEX_RINGS = 4
local spacing = math.sqrt(3) * HEX_RADIUS
local a1 = Vector3.new(spacing, 0, 0)
local a2 = Vector3.new(spacing * math.cos(math.rad(60)), 0, spacing * math.sin(math.rad(60)))
local layerColors = { { C.pink, rgb(255, 175, 210) }, { C.mint, rgb(160, 240, 210) }, { C.lavender, rgb(210, 190, 255) } }
local tileFolder = Instance.new("Folder")
tileFolder.Name = "Tiles"
tileFolder.Parent = map.Course
for layer, top in { 0, -30, -60 } do
	for q = -HEX_RINGS, HEX_RINGS do
		for r = -HEX_RINGS, HEX_RINGS do
			if math.abs(q + r) <= HEX_RINGS then
				local offset = a1 * q + a2 * r
				local tile = Instance.new("Model")
				tile.Name = "Tile"
				tile:SetAttribute("Layer", layer)
				local color = layerColors[layer][(q - r) % 2 + 1]
				-- A hexagon is the union of three rectangles rotated 60 degrees apart.
				for _, angle in { 0, 60, 120 } do
					local p = part({
						Name = "Hex",
						Size = Vector3.new(math.sqrt(3) * HEX_RADIUS * 0.96, 2, HEX_RADIUS * 0.96),
						CFrame = at(offset.X, top - 1, offset.Z) * CFrame.Angles(0, -math.rad(angle), 0),
						Color = color,
						Tags = { "HexTile" },
						Parent = tile,
					})
					p.CastShadow = false
				end
				tile.Parent = tileFolder
				local ring = math.max(math.abs(q), math.abs(r), math.abs(q + r))
				if layer == 1 and (ring == 2 or ring == 3) then
					spawnPoint(offset.X, top + 5, offset.Z)
				end
			end
		end
	end
end
zone(Vector3.new(-90, -130, -90), Vector3.new(90, 70, 90), 180, 55, 52)
cloudField(22, 200, 200, -140, -110)
orbRing(10, 75, -20)

--------------------------------------------------------------------------------------------
-- SWEEPER: a round platform with a spinning bar that speeds up; a second arm appears later.
--------------------------------------------------------------------------------------------
newMap("Sweeper", Vector3.new(3500, 120, 0), { Kind = "Sweeper", DisplayName = "SWEEPER", Goal = "Jump the bar. Last balls standing win!", KillY = 70 })

disc("Platform", 0, 0, 0, 84, 4, C.sky)
local _, bar = sweeper(0, 0, 0, 80, 1)
local arm = part({ Name = "SweeperBar2", Size = Vector3.new(2.6, 2.6, 80), CFrame = bar.CFrame, Color = C.hot, Anchored = false, Transparency = 1, CanCollide = false, CanTouch = false, Attributes = { Phase2 = true } })
arm.CustomPhysicalProperties = PhysicalProperties.new(25, 0.3, 0.8, 1, 50)
local weld = Instance.new("WeldConstraint")
weld.Part0 = bar
weld.Part1 = arm
weld.Parent = arm
local armNoCollide = Instance.new("NoCollisionConstraint")
armNoCollide.Part0 = map.Course.SweeperPost
armNoCollide.Part1 = arm
armNoCollide.Parent = arm
for i = 1, 20 do
	local angle = i / 20 * math.pi * 2
	spawnPoint(math.cos(angle) * 26, 5, math.sin(angle) * 26)
end
zone(Vector3.new(-75, -70, -75), Vector3.new(75, 70, 75), 180, 45, 56)
cloudField(20, 180, 180, -80, -55)
orbRing(10, 60, 12)

print("Round maps built:", #roundMaps:GetChildren())
