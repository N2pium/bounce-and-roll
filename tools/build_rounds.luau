-- Builds the round maps as Models in ServerStorage.RoundMaps:
--   Race, TubeTown   long races assembled from sections, with glass tubes
--   HexARoll         three layers of hex tiles that drop after you touch them
--   Sweeper          a big round platform with a spinning bar
-- The show clones one into workspace.ActiveRound for each round. Each map carries:
--   attributes  Kind, DisplayName, Goal, KillY
--   Course/     the level (tags: Checkpoint, Bumper, BouncePad, Spinner, HexTile, TubeMouth)
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
local ALONG = CFrame.Angles(0, math.rad(90), 0) -- after CFrame.lookAt, turns a cylinder's axis along the look direction
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
-- Decoration / trigger: never collides or blocks the camera.
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
	return ghost({ Name = "Checkpoint" .. order, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 24, 24), CFrame = at(x, top + 0.2, z) * UPRIGHT, Color = C.lemon, Material = Enum.Material.Neon, Transparency = 0.35, CanTouch = true, Tags = { "Checkpoint" }, Attributes = { Order = order } })
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
-- Rotating sweeper bar on an anchored post. The show keeps it server-simulated.
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
local function cloud(position, scale)
	local c = cloudTemplate:Clone()
	c.Size = cloudTemplate.Size * scale
	c.CFrame = at(position.X, position.Y, position.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
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
local function cloudField(count, spreadX, spreadZ, yMin, yMax, centerZ)
	for _ = 1, count do
		cloud(Vector3.new(rng:NextNumber(-spreadX, spreadX), rng:NextNumber(yMin, yMax), (centerZ or 0) + rng:NextNumber(-spreadZ, spreadZ)), rng:NextNumber(1.2, 2.4))
	end
end
local function orb(x, y, z, i)
	local o = ghost({ Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(2.5, 4.5), CFrame = at(x, y, z), Color = PASTELS[i % #PASTELS + 1], Material = Enum.Material.Neon, Transparency = 0, Parent = map.Decor, Tags = { "DreamFloat" }, Attributes = { FloatAmount = 3 } })
	o.CastShadow = false
end
local function orbRing(count, radius, y)
	for i = 1, count do
		local angle = i / count * math.pi * 2
		orb(math.cos(angle) * radius, y + rng:NextNumber(-4, 8), math.sin(angle) * radius, i)
	end
end

--------------------------------------------------------------------------------------------
-- Race builder. A race is a list of sections laid end to end along +Z. The cursor tracks where
-- the next section starts (z) and the height of the surface there (y). Sections add bot
-- waypoints (ball-centre height) and checkpoints as they go.
--------------------------------------------------------------------------------------------
local W = 70 -- standard platform width: wide enough that one bump doesn't knock you off
local cursor

local function wp(x, top, z, attributes)
	table.insert(cursor.waypoints, { x, top + 4, z, attributes })
end
local function advance(dz, top)
	cursor.z += dz
	cursor.y = top or cursor.y
	cursor.minY = math.min(cursor.minY, cursor.y)
	cursor.maxY = math.max(cursor.maxY, cursor.y)
end
local function raceCheckpoint(top, z)
	cursor.checkpoints += 1
	checkpoint(cursor.checkpoints, 0, top, z)
	wp(0, top, z, { Checkpoint = true })
end

local function catmullRom(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

-- A glass hamster tube through `controls` (relative points; the first and last only shape the
-- curve's ends). Builds the ride path, the glass, glowing rings and the mouth trigger.
local tubeCount = 0
local function tube(controls, options)
	tubeCount += 1
	local model = Instance.new("Model")
	model.Name = "Tube" .. tubeCount
	model:SetAttribute("Speed", options.speed or 95)
	model:SetAttribute("ExitSpeed", options.exitSpeed or 45)
	model.Parent = map.Course

	local points = {}
	for i = 2, #controls - 2 do
		local p0, p1, p2, p3 = controls[i - 1], controls[i], controls[i + 1], controls[i + 2]
		local steps = math.max(2, math.ceil((p2 - p1).Magnitude / 5))
		for s = 0, steps - 1 do
			table.insert(points, catmullRom(p0, p1, p2, p3, s / steps))
		end
	end
	table.insert(points, controls[#controls - 1])

	local path = ghost({ Name = "Path", Size = Vector3.one, CFrame = at(0, 0, 0), Parent = model })
	for i, p in points do
		local attachment = Instance.new("Attachment")
		attachment.Name = tostring(i)
		attachment.Position = p
		attachment.Parent = path
	end

	local color = options.color or C.sky
	for i = 1, #points - 1 do
		local a, b = origin + points[i], origin + points[i + 1]
		local glass = ghost({
			Name = "Glass",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new((b - a).Magnitude + 0.6, 12, 12),
			CFrame = CFrame.lookAt((a + b) / 2, b) * ALONG,
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.6,
			Parent = model,
		})
		glass.CastShadow = false
		if i % 4 == 1 then
			local ring = ghost({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 13, 13), CFrame = CFrame.lookAt(a, b) * ALONG, Color = C.white, Material = Enum.Material.Neon, Transparency = 0.25, Parent = model })
			ring.CastShadow = false
		end
	end
	local mouth = origin + points[1]
	local mouthRing = ghost({ Name = "MouthRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 17, 17), CFrame = CFrame.lookAt(mouth, origin + points[2]) * ALONG, Color = C.lemon, Material = Enum.Material.Neon, Transparency = 0, Parent = model })
	mouthRing.CastShadow = false
	ghost({ Name = "Mouth", Size = Vector3.new(14, 12, 4), CFrame = CFrame.new(mouth), CanTouch = true, Parent = model, Tags = { "TubeMouth" } })
	return model
end

local S = {}

function S.Start()
	local z, y = cursor.z, cursor.y
	slab("Start", 0, y, z + 20, 80, 40, C.lavender)
	for row = 0, 3 do
		for col = 0, 4 do
			spawnPoint(-24 + col * 12, y + 5, z + 6 + row * 8)
		end
	end
	sign("GO!", 0, y + 16, z + 40, C.lime)
	wp(0, y, z + 36)
	advance(40)
end

-- bumpers: { {x, fraction along the slope}, ... }
function S.Slope(length, drop, bumpers)
	local z, y = cursor.z, cursor.y
	local slopeLength = math.sqrt(length ^ 2 + drop ^ 2)
	local topCenter = at(0, y - drop / 2, z + length / 2) * CFrame.Angles(math.atan(drop / length), 0, 0)
	checker(part({ Name = "Slope", Size = Vector3.new(W, 2, slopeLength), CFrame = topCenter * CFrame.new(0, -1, 0), Color = C.mint }))
	for _, side in { -1, 1 } do
		part({ Name = "Rail", Size = Vector3.new(1.5, 3, slopeLength), CFrame = topCenter * CFrame.new(side * (W / 2 + 0.75), 1.5, 0), Color = C.pink })
	end
	for _, b in bumpers or {} do
		bumper(b[1], y - drop * b[2], z + length * b[2])
	end
	wp(0, y - drop / 2, z + length / 2)
	advance(length, y - drop)
	wp(0, cursor.y, cursor.z - 4)
end

-- Rows of pinball bumpers on alternating sides; the open lane weaves left and right.
function S.Slalom(length, rows)
	local z, y = cursor.z, cursor.y
	slab("Slalom", 0, y, z + length / 2, W, length, C.peach)
	raceCheckpoint(y, z + 8)
	for i = 1, rows do
		local rowZ = z + length * i / (rows + 1)
		local side = i % 2 == 0 and 1 or -1
		bumper(side * 10, y, rowZ)
		bumper(side * 28, y, rowZ)
		wp(-side * 16, y, rowZ)
	end
	advance(length)
	wp(0, y, cursor.z - 4)
end

-- Rising platforms across gaps you have to jump.
function S.Hops(count, rise)
	local depth, gap, width = 28, 12, 46
	rise = rise or 2.5
	local z, y = cursor.z, cursor.y
	local colors = { C.sky, C.lemon, C.pink, C.lavender }
	wp(0, y, z - 3, { Jump = true })
	for i = 1, count do
		local startZ = z + gap + (i - 1) * (depth + gap)
		local top = y + i * rise
		slab("Hop" .. i, 0, top, startZ + depth / 2, width, depth, colors[(i - 1) % #colors + 1])
		wp(0, top, startZ + depth - 3, { Jump = true })
	end
	advance(count * (depth + gap) + gap, y + (count + 1) * rise)
end

-- A deck with a tube mouth, the tube itself (path points are {x, dy, dz} from the mouth), and a
-- landing `length` studs past the mouth, `climb` studs higher.
function S.Tube(options)
	local z, y = cursor.z, cursor.y
	local deck = 36
	slab("TubeDeck", 0, y, z + deck / 2, W, deck, C.lavender)
	local mouthZ, mouthY = z + deck - 4, y + 5.5
	local landingTop = y + (options.climb or 0)
	local landingZ = mouthZ + options.length
	local controls = { Vector3.new(0, mouthY, mouthZ - 8), Vector3.new(0, mouthY, mouthZ), Vector3.new(0, mouthY, mouthZ + 14) }
	for _, p in options.path do
		table.insert(controls, Vector3.new(p[1], mouthY + p[2], mouthZ + p[3]))
	end
	table.insert(controls, Vector3.new(0, landingTop + 9, landingZ - 6))
	table.insert(controls, Vector3.new(0, landingTop + 5, landingZ + 6))
	table.insert(controls, Vector3.new(0, landingTop + 4, landingZ + 16))
	tube(controls, options)
	sign("TUBE!", 0, y + 20, mouthZ, C.mint)
	wp(0, y, mouthZ - 1)

	local landingDepth = 50
	slab("TubeLanding", 0, landingTop, landingZ + landingDepth / 2, W, landingDepth, C.mint)
	cursor.z = landingZ
	advance(landingDepth, landingTop)
	raceCheckpoint(landingTop, landingZ + 24)
	wp(0, landingTop, cursor.z - 4)
end

-- A disc with a sweeper bar spinning around a centre post; the bot line goes around the left.
function S.Spinner(d)
	local z, y = cursor.z, cursor.y
	disc("SpinDisc", 0, y, z + d / 2, d, 2, C.sky)
	sweeper(0, y, z + d / 2, d - 6, 1.1)
	sign("JUMP THE SWEEPER", 0, y + 22, z + d / 2, C.white)
	wp(-d * 0.3, y, z + d * 0.25)
	wp(-d * 0.3, y, z + d * 0.75)
	advance(d)
	wp(0, y, cursor.z - 3)
end

function S.Bridge(length, width)
	local z, y = cursor.z, cursor.y
	slab("Bridge", 0, y, z + length / 2, width or 40, length, C.lemon)
	wp(0, y, z + length / 2)
	advance(length)
	wp(0, y, cursor.z - 4)
end

-- A bounce pad that launches you up to a higher deck (rise must stay under ~38).
function S.PadUp(rise)
	local z, y = cursor.z, cursor.y
	slab("PadDeck", 0, y, z + 15, 60, 30, C.lavender)
	raceCheckpoint(y, z + 8)
	pad(0, y, z + 24, 20, 10, 95, Vector3.new(0, 0, 25))
	sign("BOING!", 0, y + 16, z + 24, C.lime)
	wp(0, y, z + 24)
	local deckStart = z + 52
	slab("UpperDeck", 0, y + rise, deckStart + 30, W, 60, C.pink)
	cursor.z = deckStart
	advance(60, y + rise)
	wp(0, cursor.y, cursor.z - 20)
end

function S.Finish()
	local z, y = cursor.z, cursor.y
	slab("FinishDeck", 0, y, z + 40, 90, 80, C.mint)
	part({ Name = "FinishLine", Size = Vector3.new(90, 0.3, 3), CFrame = at(0, y + 0.15, z + 14), Color = C.lemon, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
	ghost({ Name = "RaceFinish", Size = Vector3.new(90, 16, 64), CFrame = at(0, y + 8, z + 48) })
	-- Soaks up speed (elasticity weight beats the ball's) so finishers don't bounce back off the deck.
	part({ Name = "Backstop", Size = Vector3.new(90, 20, 2), CFrame = at(0, y + 10, z + 81), Material = Enum.Material.Glass, Transparency = 0.6, Color = C.sky, CustomPhysicalProperties = PhysicalProperties.new(1, 0.6, 0.2, 5, 100) })
	sign("FINISH", 0, y + 24, z + 40, C.lemon)
	wp(0, y, z + 50)
	advance(80)
end

local function buildRace(name, worldOrigin, displayName, goal, sections)
	newMap(name, worldOrigin, { Kind = "Race", DisplayName = displayName, Goal = goal })
	cursor = { z = 0, y = 0, waypoints = {}, checkpoints = 0, minY = 0, maxY = 0 }
	for _, section in sections do
		section[1](table.unpack(section, 2))
	end
	for i, w in cursor.waypoints do
		waypoint(i, w[1], w[2], w[3], w[4])
	end
	local length = cursor.z
	map:SetAttribute("KillY", origin.Y + cursor.minY - 45)
	zone(Vector3.new(-160, cursor.minY - 80, -30), Vector3.new(160, cursor.maxY + 150, length + 40), 180, 24, 32)
	cloudField(math.floor(length / 30), 260, length / 2 + 120, cursor.minY - 85, cursor.minY - 55, length / 2)
	for i = 1, math.floor(length / 60) do
		local z = rng:NextNumber(0, length)
		orb((i % 2 == 0 and 1 or -1) * rng:NextNumber(55, 80), cursor.y + rng:NextNumber(5, 30), z, i)
	end
	return length
end

--------------------------------------------------------------------------------------------
-- ROLL RACE
--------------------------------------------------------------------------------------------
local rollLength = buildRace("Race", Vector3.new(1500, 200, 0), "ROLL RACE", "Roll to the finish! Tubes are your friend.", {
	{ S.Start },
	{ S.Slope, 120, 14, { { -18, 0.2 }, { 16, 0.4 }, { 0, 0.6 }, { -24, 0.78 }, { 22, 0.85 } } },
	{ S.Slalom, 100, 4 },
	{ S.Hops, 3 },
	{ S.Tube, { path = { { 0, 25, 60 }, { 20, 38, 110 }, { 0, 28, 160 } }, length = 210, climb = 6, color = C.sky } },
	{ S.Spinner, 90 },
	{ S.Slope, 110, 12, { { -15, 0.3 }, { 15, 0.55 }, { 0, 0.8 } } },
	{ S.Hops, 3 },
	{ S.PadUp, 34 },
	{ S.Bridge, 90, 40 },
	{ S.Tube, { path = { { 30, 12, 50 }, { 0, 22, 100 }, { -30, 12, 150 }, { 0, 4, 195 } }, length = 240, climb = -10, color = C.pink, speed = 105 } },
	{ S.Finish },
})

--------------------------------------------------------------------------------------------
-- TUBE TOWN: more tubes, more air
--------------------------------------------------------------------------------------------
local tubeLength = buildRace("TubeTown", Vector3.new(1900, 200, 0), "TUBE TOWN", "Ride the tubes to the finish!", {
	{ S.Start },
	{ S.Tube, { path = { { 0, 14, 50 }, { 0, 14, 100 } }, length = 150, climb = 0, color = C.mint } },
	{ S.Slalom, 90, 3 },
	{ S.Tube, { path = { { -30, 24, 60 }, { 30, 36, 130 }, { 0, 22, 190 } }, length = 240, climb = 10, color = C.lavender } },
	{ S.Hops, 4 },
	{ S.Spinner, 100 },
	{ S.Tube, { path = { { 25, 18, 60 }, { -25, 6, 120 }, { 25, 18, 180 }, { -25, 6, 240 }, { 0, 10, 290 } }, length = 330, climb = -8, color = C.sky, speed = 110 } },
	{ S.Bridge, 80, 40 },
	{ S.PadUp, 34 },
	{ S.Tube, { path = { { 0, 30, 70 } }, length = 140, climb = 4, color = C.peach } },
	{ S.Finish },
})

--------------------------------------------------------------------------------------------
-- HEX-A-ROLL: three layers of big hex tiles that drop shortly after being touched.
--------------------------------------------------------------------------------------------
newMap("HexARoll", Vector3.new(2700, 150, 0), { Kind = "Hex", DisplayName = "HEX-A-ROLL", Goal = "Tiles fall after you touch them. Don't drop!", KillY = 55 })

local HEX_RADIUS = 9 -- circumradius
local HEX_RINGS = 5
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
						Size = Vector3.new(math.sqrt(3) * HEX_RADIUS * 0.97, 2, HEX_RADIUS * 0.97),
						CFrame = at(offset.X, top - 1, offset.Z) * CFrame.Angles(0, -math.rad(angle), 0),
						Color = color,
						Tags = { "HexTile" },
						Parent = tile,
					})
					p.CastShadow = false
				end
				tile.Parent = tileFolder
				local ring = math.max(math.abs(q), math.abs(r), math.abs(q + r))
				if layer == 1 and (ring == 3 or ring == 4) then
					spawnPoint(offset.X, top + 5, offset.Z)
				end
			end
		end
	end
end
zone(Vector3.new(-150, -130, -150), Vector3.new(150, 80, 150), 180, 55, 74)
cloudField(30, 280, 280, -140, -110)
orbRing(12, 115, -20)

--------------------------------------------------------------------------------------------
-- SWEEPER: a big round platform with a spinning bar that speeds up; a second arm appears later.
--------------------------------------------------------------------------------------------
newMap("Sweeper", Vector3.new(3500, 120, 0), { Kind = "Sweeper", DisplayName = "SWEEPER", Goal = "Jump the bar. Last balls standing win!", KillY = 70 })

disc("Platform", 0, 0, 0, 130, 4, C.sky)
local _, bar = sweeper(0, 0, 0, 124, 1)
local arm = part({ Name = "SweeperBar2", Size = Vector3.new(2.6, 2.6, 124), CFrame = bar.CFrame, Color = C.hot, Anchored = false, Transparency = 1, CanCollide = false, CanTouch = false, Attributes = { Phase2 = true } })
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
	spawnPoint(math.cos(angle) * 42, 5, math.sin(angle) * 42)
end
zone(Vector3.new(-120, -70, -120), Vector3.new(120, 80, 120), 180, 45, 78)
cloudField(26, 240, 240, -80, -55)
orbRing(12, 95, 12)

print(("Round maps built: Roll Race %d studs, Tube Town %d studs"):format(rollLength, tubeLength))
