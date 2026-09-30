-- Bounce & Roll HUD: timer, toasts, dash meter, squad badge and touch controls.
-- Built in code so there are no GUI assets to keep in sync.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(45, 30, 80)
local WHITE = Color3.new(1, 1, 1)
local PINK = Color3.fromRGB(255, 120, 180)
local LAVENDER = Color3.fromRGB(160, 130, 255)
local SKY = Color3.fromRGB(100, 170, 255)
local GREY = Color3.fromRGB(130, 128, 145)
local GOLD = Color3.fromRGB(255, 225, 110)

local function make(className, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = props.Parent
	return instance
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = FONT
	props.TextColor3 = props.TextColor3 or WHITE
	return make("TextLabel", props, { make("UIStroke", { Thickness = 3, Color = INK }) })
end

local function button(text, size, position, color, parent)
	return make("TextButton", {
		Text = text,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Parent = parent,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		make("UIStroke", { Thickness = 4, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		make("UIPadding", {
			PaddingTop = UDim.new(0.24, 0),
			PaddingBottom = UDim.new(0.24, 0),
			PaddingLeft = UDim.new(0.12, 0),
			PaddingRight = UDim.new(0.12, 0),
		}),
	})
end

local Hud = {}
Hud.__index = Hud

function Hud.new(player, options)
	local self = setmetatable({}, Hud)
	self.handlers = {}
	self.toastId = 0

	local gui = make("ScreenGui", {
		Name = "BounceHud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	self.timer = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(260, 44), TextSize = 38, Text = "0:00.00", Parent = gui })
	self.best = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(260, 24), TextSize = 20, Text = "", TextColor3 = GOLD, Parent = gui })
	self.toast = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(700, 90), TextSize = 60, Text = "", TextTransparency = 1, Parent = gui })
	self.toastStroke = self.toast:FindFirstChildOfClass("UIStroke")
	self.toastStroke.Transparency = 1
	self.squad = label({ Position = UDim2.new(0, 16, 0, 8), Size = UDim2.fromOffset(260, 30), TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, Visible = false, Parent = gui })

	if options.touch then
		self.jumpButton = button("JUMP", UDim2.fromOffset(120, 120), UDim2.new(1, -90, 1, -90), PINK, gui)
		self.dashButton = button("DASH", UDim2.fromOffset(86, 86), UDim2.new(1, -205, 1, -62), LAVENDER, gui)
		self:_bindHold(self.jumpButton, "jumpDown", "jumpUp")
		self:_bindHold(self.dashButton, "dash")
		local reset = button("RESET", UDim2.fromOffset(96, 42), UDim2.new(1, -60, 0, 30), GREY, gui)
		reset.Activated:Connect(function()
			self:_fire("respawn")
		end)
		if options.tiltSupported then
			self.tiltButton = button("TILT: ON", UDim2.fromOffset(130, 42), UDim2.new(1, -180, 0, 30), SKY, gui)
			self.tiltButton.Activated:Connect(function()
				self:_fire("toggleTilt")
			end)
			self.levelButton = button("LEVEL", UDim2.fromOffset(96, 42), UDim2.new(1, -300, 0, 30), GREY, gui)
			self.levelButton.Activated:Connect(function()
				self:_fire("calibrate")
			end)
		end
	else
		self.dashPill = label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -34), Size = UDim2.fromOffset(200, 30), TextSize = 26, Text = "DASH READY", TextColor3 = LAVENDER, Parent = gui })
		label({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromOffset(900, 24),
			TextSize = 18,
			Text = "WASD roll    SPACE jump (hold to float)    SHIFT dash    Q/E or right-drag camera    R respawn",
			Parent = gui,
		})
	end
	return self
end

function Hud:On(event, handler)
	self.handlers[event] = handler
end

function Hud:_fire(event, ...)
	local handler = self.handlers[event]
	if handler then
		handler(...)
	end
end

-- Fires down/up for a held button, tracking the exact touch so sliding off still releases.
function Hud:_bindHold(target, downEvent, upEvent)
	local activeInput = nil
	target.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if activeInput or (kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1) then
			return
		end
		activeInput = input
		self:_fire(downEvent)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not activeInput then
			return
		end
		local sameMouse = input.UserInputType == Enum.UserInputType.MouseButton1 and activeInput.UserInputType == Enum.UserInputType.MouseButton1
		if input == activeInput or sameMouse then
			activeInput = nil
			if upEvent then
				self:_fire(upEvent)
			end
		end
	end)
end

function Hud:SetTimer(text)
	self.timer.Text = text
end

function Hud:SetBest(text)
	self.best.Text = text
end

function Hud:SetSquad(count)
	self.squad.Visible = count > 0
	self.squad.Text = string.format("SQUAD x%d  (sturdier!)", count)
end

function Hud:SetDashReady(fraction)
	local ready = fraction >= 1
	if self.dashButton then
		self.dashButton.BackgroundColor3 = ready and LAVENDER or GREY:Lerp(LAVENDER, fraction * 0.6)
	end
	if self.dashPill then
		self.dashPill.Text = ready and "DASH READY" or "DASH ..."
		self.dashPill.TextColor3 = ready and LAVENDER or GREY
	end
end

function Hud:SetTiltMode(enabled)
	if self.tiltButton then
		self.tiltButton.Text = enabled and "TILT: ON" or "TILT: OFF"
		self.levelButton.Visible = enabled
	end
end

function Hud:Toast(text, color)
	self.toastId += 1
	local id = self.toastId
	local toast, stroke = self.toast, self.toastStroke
	toast.Text = text
	toast.TextColor3 = color or WHITE
	toast.TextTransparency = 0
	stroke.Transparency = 0
	toast.TextSize = 84
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 60 }):Play()
	task.delay(1.1, function()
		if self.toastId ~= id then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	end)
end

-- Tilt calibration: whatever angle the phone is at when they tap becomes "level".
function Hud:ShowCalibrate(onDone)
	if self.calibrateOverlay then
		self.calibrateOverlay:Destroy()
	end
	local overlay = make("TextButton", {
		Name = "Calibrate",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.35,
		AutoButtonColor = false,
		Text = "Hold your phone the way you want to play\n\nTAP TO START",
		Font = FONT,
		TextSize = 34,
		TextColor3 = WHITE,
		TextWrapped = true,
		ZIndex = 50,
		Parent = self.gui,
	})
	self.calibrateOverlay = overlay
	overlay.Activated:Connect(function()
		overlay:Destroy()
		self.calibrateOverlay = nil
		onDone()
	end)
end

return Hud
