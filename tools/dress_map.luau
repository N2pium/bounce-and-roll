-- Dreamcore dressing for Bounce Park: pastel checker floors, a cloud ocean and drifting clouds
-- (from BounceRoll.Assets.CloudMesh), rainbows, floating doorways and glowing dream orbs, plus the
-- default mood applied in Edit mode so Studio looks like the game.
-- Run in the Studio command bar (Edit mode) after build_map.luau. Safe to re-run.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage.BounceRoll
local Moods = require(shared.Moods)
local cloudTemplate = shared.Assets.CloudMesh
local map = workspace.BounceParkMap
local course = map.Course

local CHECKER = "rbxassetid://10630078103" -- transparent checker overlay; the platform colour shows through
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local PASTELS = { rgb(255, 170, 205), rgb(150, 235, 205), rgb(195, 175, 255), rgb(255, 232, 150), rgb(160, 210, 255), rgb(255, 195, 160) }

local old = map:FindFirstChild("Dream")
if old then
	old:Destroy()
end
local dream = Instance.new("Folder")
dream.Name = "Dream"
dream.Parent = map
local function subfolder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = dream
	return f
end
local cloudFolder, rainbowFolder, doorFolder, orbFolder = subfolder("Clouds"), subfolder("Rainbows"), subfolder("Doorways"), subfolder("Orbs")

-- Decorations never collide, block the camera, or trigger touches.
local function ghost(part, parent)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
local function block(size, cframe, color, parent, material)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	return ghost(p, parent)
end

-- Placeholder ball clouds from build_map are replaced by the mesh clouds below.
for _, child in map.Decor:GetChildren() do
	if child.Name == "Cloud" then
		child:Destroy()
	end
end
map:SetAttribute("Mood", Moods.Default)
CollectionService:AddTag(map.Decor.CandySea, "MoodSea")

-- 1. Pastel checker floors ------------------------------------------------------------
local function checker(part, face)
	for _, t in part:GetChildren() do
		if t:IsA("Texture") then
			t:Destroy()
		end
	end
	local texture = Instance.new("Texture")
	texture.Texture = CHECKER
	texture.Face = face
	texture.StudsPerTileU = 8
	texture.StudsPerTileV = 8
	texture.Transparency = 0.7
	texture.Parent = part
end
for _, name in { "WelcomeSlope", "Landing1", "Hop1", "Hop2", "Hop3", "Landing2", "UpperDeck", "Beam1", "Beam2", "TurnPlatform", "Arena" } do
	checker(course[name], Enum.NormalId.Top)
end
for _, name in { "SpawnIsland", "SweeperDisc", "FinishIsland" } do
	checker(course[name], Enum.NormalId.Right) -- upright cylinders: local +X points up
end

-- 2. Clouds: an ocean below the course, drifting clouds around it, and a high layer ----
local rng = Random.new(42)
-- Boxes around the course where mid-height clouds would block the view.
local keepClear = {
	{ Vector3.new(-60, 25, -60), Vector3.new(60, 140, 460) },
	{ Vector3.new(-60, 60, 390), Vector3.new(185, 140, 560) },
	{ Vector3.new(185, 70, 400), Vector3.new(310, 160, 540) },
}
local function blocked(position, size)
	local half = size / 2
	for _, box in keepClear do
		local lo, hi = box[1] - half, box[2] + half
		if position.X > lo.X and position.X < hi.X and position.Y > lo.Y and position.Y < hi.Y and position.Z > lo.Z and position.Z < hi.Z then
			return true
		end
	end
	return false
end
local function cloud(position, scale, floatAmount, parent)
	local c = cloudTemplate:Clone()
	c.Size = cloudTemplate.Size * scale
	c.CFrame = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	c.Material = Enum.Material.SmoothPlastic
	c.CastShadow = false
	c:SetAttribute("FloatAmount", floatAmount)
	CollectionService:AddTag(c, "MoodCloud")
	return ghost(c, parent or cloudFolder)
end
for _ = 1, 55 do
	cloud(Vector3.new(rng:NextNumber(-260, 380), rng:NextNumber(-12, 4), rng:NextNumber(-180, 720)), rng:NextNumber(1.6, 3), 2)
end
local placed, tries = 0, 0
while placed < 24 and tries < 600 do
	tries += 1
	local scale = rng:NextNumber(0.6, 1.4)
	local position = Vector3.new(rng:NextNumber(-200, 330), rng:NextNumber(35, 130), rng:NextNumber(-120, 650))
	if not blocked(position, cloudTemplate.Size * scale) then
		cloud(position, scale, 5)
		placed += 1
	end
end
for _ = 1, 12 do
	cloud(Vector3.new(rng:NextNumber(-250, 380), rng:NextNumber(170, 230), rng:NextNumber(-150, 700)), rng:NextNumber(1.5, 2.5), 6)
end

-- 3. Pastel rainbows ---------------------------------------------------------------------
local RAINBOW = { rgb(255, 160, 170), rgb(255, 195, 150), rgb(255, 235, 155), rgb(175, 240, 180), rgb(155, 205, 255), rgb(200, 175, 255) }
-- A half-ring in the vertical plane that contains `across` (horizontal), red band outermost.
local function rainbow(name, center, across, innerRadius, bandWidth, thickness, segments)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = rainbowFolder
	local normal = across:Cross(Vector3.yAxis)
	for band, color in RAINBOW do
		local radius = innerRadius + (#RAINBOW - band + 0.5) * bandWidth
		for s = 0, segments - 1 do
			local mid = math.pi * (s + 0.5) / segments
			local radial = across * math.cos(mid) + Vector3.yAxis * math.sin(mid)
			local length = 2 * radius * math.sin(math.pi / segments / 2) * 1.04
			local cframe = CFrame.fromMatrix(center + radial * radius, normal, radial)
			local p = block(Vector3.new(thickness, bandWidth, length), cframe, color, folder)
			p.Transparency = 0.12
			p.CastShadow = false
		end
	end
end
rainbow("FinishArch", Vector3.new(238, 99, 470), Vector3.zAxis, 32, 2.4, 1.4, 28)
rainbow("HorizonAhead", Vector3.new(0, -20, 820), Vector3.xAxis, 170, 6, 3, 30)
rainbow("HorizonArena", Vector3.new(650, -20, 470), Vector3.zAxis, 160, 6, 3, 30)

-- 4. Floating doorways: doors to nowhere on little cloud islands, light spilling out ------
local function doorway(base, lookAt, doorColor)
	local model = Instance.new("Model")
	model.Name = "Doorway"
	model.Parent = doorFolder
	local cf = CFrame.lookAt(base, Vector3.new(lookAt.X, base.Y, lookAt.Z))
	local white = rgb(252, 250, 255)
	local island = block(Vector3.new(2.5, 16, 16), cf * CFrame.new(0, -1.25, 0) * UPRIGHT, white, model)
	island.Shape = Enum.PartType.Cylinder
	for i = 1, 3 do
		local angle = i * 2.1
		cloud((cf * CFrame.new(math.cos(angle) * 7, -3, math.sin(angle) * 7)).Position, rng:NextNumber(0.22, 0.32), 1, model)
	end
	for _, side in { -1, 1 } do
		block(Vector3.new(1, 12, 1), cf * CFrame.new(side * 3.6, 6, 0), white, model)
	end
	block(Vector3.new(8.2, 1, 1), cf * CFrame.new(0, 12.5, 0), white, model)
	block(Vector3.new(6.2, 11.5, 0.2), cf * CFrame.new(0, 5.75, 0.3), rgb(255, 246, 225), model, Enum.Material.Neon)
	-- Door swung 40 degrees open toward the viewer, hinged on the left post.
	local hinge = cf * CFrame.new(-3.1, 5.9, 0) * CFrame.Angles(0, math.rad(40), 0)
	block(Vector3.new(6, 11.4, 0.4), hinge * CFrame.new(3, 0, 0), doorColor, model)
	local knob = block(Vector3.new(0.6, 0.6, 0.6), hinge * CFrame.new(5.3, 0, -0.4), rgb(255, 220, 140), model)
	knob.Shape = Enum.PartType.Ball
end
doorway(Vector3.new(-85, 72, 110), Vector3.new(0, 72, 110), PASTELS[1])
doorway(Vector3.new(95, 98, 300), Vector3.new(0, 98, 300), PASTELS[2])
doorway(Vector3.new(-90, 120, 470), Vector3.new(0, 120, 470), PASTELS[3])
doorway(Vector3.new(300, 125, 380), Vector3.new(250, 125, 470), PASTELS[4])

-- 5. Dream orbs: soft glowing spheres floating beside the course ---------------------------
local function courseHeight(z)
	if z < 130 then
		return 60 - (z - 30) * 0.15
	elseif z < 260 then
		return 47
	elseif z < 310 then
		return 51
	end
	return 85
end
for i = 1, 14 do
	local z = rng:NextNumber(0, 450)
	local side = i % 2 == 0 and 1 or -1
	local orb = block(Vector3.one * rng:NextNumber(2, 4.5), CFrame.new(side * rng:NextNumber(45, 62), courseHeight(z) + rng:NextNumber(8, 24), z), PASTELS[i % #PASTELS + 1], orbFolder, Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	orb.CastShadow = false
	orb:SetAttribute("FloatAmount", 3)
	CollectionService:AddTag(orb, "DreamFloat")
end
for i = 1, 8 do
	local angle = i / 8 * math.pi * 2
	local orb = block(Vector3.one * rng:NextNumber(2.5, 4.5), CFrame.new(105 + math.cos(angle) * 90, 100 + rng:NextNumber(0, 14), 470 + math.sin(angle) * 90), PASTELS[i % #PASTELS + 1], orbFolder, Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	orb.CastShadow = false
	orb:SetAttribute("FloatAmount", 3)
	CollectionService:AddTag(orb, "DreamFloat")
end

-- 6. Apply the default mood in Edit mode so Studio matches the game ---------------------------
local def = Moods.List[Moods.Default]
for _, child in Lighting:GetChildren() do
	if child:IsA("Sky") then
		child:Destroy()
	end
end
shared.Skies[def.Sky]:Clone().Parent = Lighting
local function effect(className, name)
	local e = Lighting:FindFirstChildOfClass(className)
	if not e then
		e = Instance.new(className)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end
local grade = Lighting:FindFirstChild("DreamGrade") or Instance.new("ColorCorrectionEffect")
grade.Name = "DreamGrade"
grade.Parent = Lighting
for target, props in {
	[Lighting] = def.Lighting,
	[effect("Atmosphere", "Atmosphere")] = def.Atmosphere,
	[grade] = def.Grade,
	[effect("BloomEffect", "Bloom")] = def.Bloom,
	[effect("SunRaysEffect", "SunRays")] = def.SunRays,
} do
	for property, value in props do
		target[property] = value
	end
end
map.Decor.CandySea.Color = def.Sea
for _, c in CollectionService:GetTagged("MoodCloud") do
	c.Color = def.Cloud
end

print("Bounce Park dressed")
