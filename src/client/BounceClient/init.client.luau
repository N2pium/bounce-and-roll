-- Bounce & Roll client: wires input (tilt / stick / keyboard / gamepad), the ball controller,
-- bumps, the chase camera, effects and the HUD together.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BounceRoll")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")

local TiltInput = require(script:WaitForChild("TiltInput"))
local ChaseCamera = require(script:WaitForChild("ChaseCamera"))
local BallController = require(script:WaitForChild("BallController"))
local Bumps = require(script:WaitForChild("Bumps"))
local Effects = require(script:WaitForChild("Effects"))
local Hud = require(script:WaitForChild("Hud"))
local MoveInput = require(script:WaitForChild("MoveInput"))
local Mood = require(script:WaitForChild("Mood"))
local Ambience = require(script:WaitForChild("Ambience"))
local ShowClient = require(script:WaitForChild("ShowClient"))
local Moods = require(Shared:WaitForChild("Moods"))

local player = Players.LocalPlayer

local isTouch = UserInputService.TouchEnabled
local tilt = TiltInput.new(Config.Tilt)
local chaseCamera = ChaseCamera.new(Config.Camera)
local effects = Effects.new()
local hud = Hud.new(player, { touch = isTouch, tiltSupported = tilt.supported })
local moveInput = MoveInput.new(isTouch and hud.gui or nil)

local mood
local ambience = Ambience.new(function(part)
	if mood then
		mood:TintNew(part)
	end
end)
mood = Mood.new(Shared, Moods, function(_, def)
	hud:Caption(def.Caption)
	ambience:SetMoteColor(def.Motes)
end)
local showClient = ShowClient.new(Shared, hud)

local GOLD = Color3.fromRGB(255, 225, 110)
local MINT = Color3.fromRGB(120, 230, 190)
local PINK = Color3.fromRGB(255, 120, 180)

local useTilt = false
local jumpHeld = false
local turnLeft, turnRight = false, false
local stickTurn = 0
local mouseDragging = false
local cameraTouch = nil

local session = nil -- state for the current character
local runStartedAt, runFinishedAt, bestTime = nil, nil, nil -- the lobby course run
local frozen = false -- held still by the show (intro / countdown / between rounds)
local frozenCFrame = nil
local pendingTeleport = nil -- a show teleport that arrived before our ball existed

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function formatTime(seconds)
	return string.format("%d:%05.2f", seconds // 60, seconds % 60)
end

-- Camera zones are invisible boxes that tell the camera which way the course runs (Yaw), and
-- optionally how high / far to sit (Pitch, Distance). Returns nil outside every zone.
local function zoneAt(position)
	local best, bestPriority, bestVolume
	for _, zone in CollectionService:GetTagged("CameraZone") do
		local p = zone.CFrame:PointToObjectSpace(position)
		local half = zone.Size / 2
		if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
			local priority = zone:GetAttribute("Priority") or 0
			local volume = zone.Size.X * zone.Size.Y * zone.Size.Z
			if not best or priority > bestPriority or (priority == bestPriority and volume < bestVolume) then
				best, bestPriority, bestVolume = zone, priority, volume
			end
		end
	end
	if not best then
		return nil
	end
	return { Yaw = math.rad(best:GetAttribute("Yaw") or 0), Pitch = best:GetAttribute("Pitch"), Distance = best:GetAttribute("Distance") }
end

local function cameraForward()
	local yaw = chaseCamera:GetYaw()
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

-- World-space move direction (magnitude 0..1), relative to where the camera faces.
local function readMoveDirection(dt)
	local raw
	if useTilt then
		local t = tilt:Read(dt)
		raw = Vector3.new(t.X, 0, -t.Y)
	else
		local stick = moveInput:Read()
		raw = Vector3.new(stick.X, 0, -stick.Y)
	end
	if raw.Magnitude > 1 then
		raw = raw.Unit
	end
	return CFrame.Angles(0, chaseCamera:GetYaw(), 0):VectorToWorldSpace(raw)
end

local function setTiltMode(enabled)
	useTilt = enabled and tilt.supported
	moveInput:SetTouchEnabled(not useTilt)
	if useTilt then
		hud:ShowCalibrate(function()
			tilt:Calibrate()
		end)
	end
	hud:SetTiltMode(useTilt)
end

local function respawnAllowed()
	-- In survival rounds a fall is final: the server eliminates you instead.
	return not showClient:IsCompeting() or Shared:GetAttribute("RespawnEnabled") ~= false
end

local function respawn()
	if not session or frozen or not respawnAllowed() then
		return
	end
	if runFinishedAt and not showClient:IsCompeting() then
		-- After a finish, respawning restarts the whole run.
		runStartedAt, runFinishedAt = nil, nil
		session.checkpoint.order = 0
		session.checkpoint.position = session.startPosition
	end
	local position = session.checkpoint.position + Vector3.new(0, Config.Ball.Radius + 2, 0)
	session.controller:Teleport(position)
	local zone = zoneAt(position)
	chaseCamera:Snap(position, zone and zone.Yaw or chaseCamera:GetYaw(), zone)
	effects:Burst("puff", position, 12)
end

-- Frozen balls are pinned in place every frame rather than anchored: anchoring our own ball
-- would stop its position replicating, and the server would keep seeing it where it used to be.
local function setFrozen(value)
	frozen = value
	frozenCFrame = value and session and session.ball.CFrame or nil
	if session then
		session.ball.AssemblyLinearVelocity = Vector3.zero
		session.ball.AssemblyAngularVelocity = Vector3.zero
	end
end

-- The show moves us between the lobby and round maps. The new spot becomes our checkpoint.
local function showTeleport(position, yaw, freeze)
	if not session then
		pendingTeleport = { position, yaw, freeze }
		return
	end
	session.checkpoint.order = 0
	session.checkpoint.position = position
	runStartedAt, runFinishedAt = nil, nil -- the lobby course run restarts after a show
	hud:SetTimer("0:00.00")
	session.controller:Teleport(position)
	local zone = zoneAt(position)
	chaseCamera:Snap(position, zone and zone.Yaw or yaw or math.pi, zone)
	setFrozen(freeze == true)
end

local function finish(part)
	if not runStartedAt or runFinishedAt or showClient:IsCompeting() then
		return
	end
	runFinishedAt = os.clock()
	local time = runFinishedAt - runStartedAt
	local isBest = not bestTime or time < bestTime
	if isBest then
		bestTime = time
		hud:SetBest("BEST " .. formatTime(time))
	end
	hud:Toast((isBest and "NEW BEST!  " or "FINISH!  ") .. formatTime(time), GOLD)
	effects:Burst("confetti", part.Position + Vector3.new(0, 3, 0), 120)
	effects:Play("chime", 1)
	task.delay(0.15, function()
		effects:Play("chime", 1.25)
	end)
end

local function onCharacterAdded(character)
	if session then
		session.cleanup()
		session = nil
	end
	local ball = character:WaitForChild("Ball", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not ball or not root then
		return
	end
	local upright = root:WaitForChild("Upright", 5)
	local radius = ball.Size.X / 2

	local controller = BallController.new(ball, root, Config)
	local bumps = Bumps.new(ball, controller, Config, Remotes)
	local connections = {}

	session = {
		ball = ball,
		controller = controller,
		bumps = bumps,
		upright = upright,
		startPosition = ball.Position,
		checkpoint = { order = 0, position = ball.Position },
	}
	session.cleanup = function()
		bumps:Destroy()
		for _, connection in connections do
			connection:Disconnect()
		end
	end

	controller.onEvent = function(name, data)
		local feet = ball.Position - Vector3.new(0, radius, 0)
		if name == "jump" then
			effects:Play("jump", 1)
			effects:Burst("puff", feet, 6)
		elseif name == "airjump" then
			effects:Play("jump", 1.35)
			effects:Burst("puff", feet, 10)
		elseif name == "land" then
			if data > 35 then
				effects:Play("land", math.clamp(1.3 - data / 200, 0.8, 1.2))
				effects:Burst("puff", feet, math.clamp(math.floor(data / 6), 4, 18))
			end
		elseif name == "dash" then
			effects:Play("jump", 0.7)
			effects:Burst("spark", ball.Position, 10)
		elseif name == "pad" then
			effects:Play("boing", 1)
			effects:Flash(data)
			effects:PopText("BOING!", ball.Position, Color3.fromRGB(150, 255, 90))
		elseif name == "bumper" then
			effects:Play("bump", 1.2)
			effects:Flash(data)
			effects:Burst("spark", ball.Position, 12)
			effects:PopText("BONK!", ball.Position, PINK)
		elseif name == "tubeEnter" then
			effects:Play("boing", 1.7)
			effects:PopText("WHEE!", ball.Position, MINT)
		elseif name == "tubeExit" then
			effects:Play("jump", 0.8)
			effects:Burst("puff", ball.Position, 10)
		end
	end

	bumps.onBump = function(kind, position)
		effects:Burst("spark", position, kind == "hit" and 22 or 14)
		effects:Play("bump", kind == "hit" and 1 or 0.8)
		local text = kind == "hit" and "BONK!" or kind == "boosted" and "BOOST!" or "BUMPED!"
		effects:PopText(text, position, kind == "boosted" and MINT or PINK)
	end

	table.insert(connections, ball.Touched:Connect(function(hit)
		controller:HandleTouch(hit)
		if CollectionService:HasTag(hit, "Checkpoint") then
			local order = hit:GetAttribute("Order") or 0
			if order > session.checkpoint.order then
				session.checkpoint.order = order
				session.checkpoint.position = hit.Position
				hit.Color = MINT
				if order > 1 then
					hud:Toast("CHECKPOINT!", MINT)
					effects:Play("chime", 1)
				end
			end
		elseif CollectionService:HasTag(hit, "KillPart") then
			respawn()
		elseif CollectionService:HasTag(hit, "Finish") then
			finish(hit)
		end
	end))

	local zone = zoneAt(ball.Position)
	chaseCamera:Snap(ball.Position, zone and zone.Yaw or math.pi, zone)
	if pendingTeleport then
		local teleport = pendingTeleport
		pendingTeleport = nil
		showTeleport(table.unpack(teleport))
	elseif frozen then
		setFrozen(true)
	end
end

Remotes.ShowEvent.OnClientEvent:Connect(function(kind, ...)
	if kind == "teleport" then
		showTeleport(...)
	elseif kind == "freeze" then
		setFrozen(...)
	elseif kind == "feed" then
		showClient:Feed(...)
	elseif kind == "confetti" then
		effects:Burst("confetti", ..., 150)
		effects:Play("chime", 1)
	end
end)

-- Input ------------------------------------------------------------------------
local function requestJump()
	jumpHeld = true
	if session then
		session.controller:RequestJump()
	end
end

local function requestDash()
	if not session then
		return
	end
	local direction = session.lastMove or Vector3.zero
	if direction.Magnitude < 0.1 then
		direction = cameraForward()
	end
	session.controller:RequestDash(direction)
end

local PRIORITY = Enum.ContextActionPriority.High.Value

ContextActionService:BindActionAtPriority("BR_Jump", function(_, state)
	if state == Enum.UserInputState.Begin then
		requestJump()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		jumpHeld = false
	end
	return Enum.ContextActionResult.Sink
end, false, PRIORITY, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

ContextActionService:BindActionAtPriority("BR_Dash", function(_, state)
	if state == Enum.UserInputState.Begin then
		requestDash()
	end
	return Enum.ContextActionResult.Sink
end, false, PRIORITY, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonR2)

ContextActionService:BindActionAtPriority("BR_Respawn", function(_, state)
	if state == Enum.UserInputState.Begin then
		respawn()
	end
	return Enum.ContextActionResult.Sink
end, false, PRIORITY, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

ContextActionService:BindActionAtPriority("BR_Turn", function(_, state, input)
	local down = state == Enum.UserInputState.Begin
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1 then
		turnLeft = down
	else
		turnRight = down
	end
	return Enum.ContextActionResult.Sink
end, false, PRIORITY, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		mouseDragging = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	elseif input.UserInputType == Enum.UserInputType.Touch and not cameraTouch then
		-- In stick mode the left side belongs to the thumbstick.
		local viewport = workspace.CurrentCamera.ViewportSize
		if useTilt or input.Position.X > viewport.X * 0.4 then
			cameraTouch = input
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement and mouseDragging then
		chaseCamera:AddManualYaw(-math.rad(input.Delta.X * Config.Camera.MouseSensitivity))
	elseif input == cameraTouch then
		chaseCamera:AddManualYaw(-math.rad(input.Delta.X * Config.Camera.TouchSensitivity))
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		stickTurn = math.abs(input.Position.X) > 0.2 and input.Position.X or 0
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		mouseDragging = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	elseif input == cameraTouch then
		cameraTouch = nil
	end
end)

hud:On("jumpDown", requestJump)
hud:On("jumpUp", function()
	jumpHeld = false
end)
hud:On("dash", requestDash)
hud:On("respawn", respawn)
hud:On("toggleTilt", function()
	setTiltMode(not useTilt)
end)
hud:On("calibrate", function()
	tilt:Calibrate()
	hud:Toast("LEVEL SET", MINT)
end)

local function updateSquad()
	hud:SetSquad(player:GetAttribute("SquadFriends") or 0)
end
player:GetAttributeChangedSignal("SquadFriends"):Connect(updateSquad)
updateSquad()

-- Loops ------------------------------------------------------------------------
RunService.PreSimulation:Connect(function(dt)
	local s = session
	if not s or not s.ball.Parent then
		return
	end
	if frozen then
		if frozenCFrame then
			s.ball.AssemblyLinearVelocity = Vector3.zero
			s.ball.AssemblyAngularVelocity = Vector3.zero
			s.ball.CFrame = frozenCFrame
		end
		return
	end
	if s.controller:InTube() then
		s.controller:StepTube(dt)
		return
	end
	local move = readMoveDirection(dt)
	if showClient:GetSpectateTarget() then
		move = Vector3.zero -- watching someone else; our own ball waits
	end
	s.lastMove = move
	if not runStartedAt and move.Magnitude > 0.1 and not showClient:IsCompeting() then
		runStartedAt = os.clock()
	end

	s.controller:Step(dt, move, jumpHeld)
	s.bumps:Step(dt)

	if s.ball.Position.Y < (Shared:GetAttribute("KillY") or Config.World.KillY) then
		respawn()
	end

	-- The avatar inside faces the way the ball is rolling.
	local velocity = flat(s.ball.AssemblyLinearVelocity)
	if s.upright and velocity.Magnitude > 4 then
		s.upright.CFrame = CFrame.Angles(0, math.atan2(-velocity.X, -velocity.Z), 0)
	end
end)

RunService:BindToRenderStep("BounceRollCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local turn = (turnRight and 1 or 0) - (turnLeft and 1 or 0) + stickTurn
	if math.abs(turn) > 0.05 then
		chaseCamera:AddManualYaw(-turn * Config.Camera.KeyTurnSpeed * dt)
	end

	local s = session
	if s and s.ball.Parent then
		local subject = showClient:GetSpectateTarget() or s.ball
		chaseCamera:Update(dt, subject.Position, subject.AssemblyLinearVelocity, zoneAt(subject.Position))
		hud:SetDashReady(s.controller:DashReadiness())
	end

	if runStartedAt then
		hud:SetTimer(formatTime((runFinishedAt or os.clock()) - runStartedAt))
	end
end)

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

-- Phones default to tilt; everything else uses stick / keyboard / gamepad.
setTiltMode(isTouch and tilt.supported)
