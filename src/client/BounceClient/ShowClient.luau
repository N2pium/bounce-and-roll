-- Show HUD + spectating: lobby countdown, round intro card, 3-2-1-GO, round info and timer,
-- QUALIFIED / ELIMINATED callouts, an event feed, the winner card, and spectate controls.
-- Everything is driven by the server's attributes (see ShowManager).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(45, 30, 80)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 225, 110)
local MINT = Color3.fromRGB(120, 230, 190)
local PINK = Color3.fromRGB(255, 120, 180)
local LAVENDER = Color3.fromRGB(160, 130, 255)
local FEED_LINES = 5
local IN_SHOW = { Intro = true, Countdown = true, Playing = true, Results = true }

local ShowClient = {}
ShowClient.__index = ShowClient

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
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	return make("TextLabel", props, { make("UIStroke", { Thickness = props.TextSize and props.TextSize > 50 and 4 or 3, Color = INK }) })
end

local function pill(text, size, position, color, parent)
	return make("TextButton", {
		Text = text,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		Parent = parent,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		make("UIStroke", { Thickness = 3, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }),
	})
end

local function formatClock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function ShowClient.new(shared, hud)
	local self = setmetatable({}, ShowClient)
	self.shared = shared
	self.hud = hud
	self.player = Players.LocalPlayer
	self.watchWanted = true
	self.spectateIndex = 1
	self.lastCount = nil

	local gui = hud.gui
	self.banner = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(560, 44), TextSize = 34, Text = "", Parent = gui })
	self.subBanner = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(560, 24), TextSize = 20, TextColor3 = GOLD, Text = "", Parent = gui })

	self.card = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(600, 180),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.3,
		Visible = false,
		Parent = gui,
	}, { make("UICorner", { CornerRadius = UDim.new(0, 28) }), make("UIStroke", { Thickness = 4, Color = LAVENDER }) })
	self.cardTop = label({ Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 28), TextSize = 24, TextColor3 = GOLD, Text = "", Parent = self.card })
	self.cardTitle = label({ Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 0, 70), TextSize = 64, Text = "", Parent = self.card })
	self.cardBody = label({ Position = UDim2.new(0, 20, 0, 116), Size = UDim2.new(1, -40, 0, 52), TextSize = 26, TextWrapped = true, Text = "", Parent = self.card })

	self.countdown = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(400, 150), TextSize = 100, Text = "", Visible = false, Parent = gui })

	self.feed = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -150), Size = UDim2.fromOffset(340, FEED_LINES * 26), BackgroundTransparency = 1, Parent = gui }, {
		make("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	self.feedOrder = 0

	self.spectateBar = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.fromOffset(460, 56), BackgroundTransparency = 1, Visible = false, Parent = gui })
	self.spectateName = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(240, 40), TextSize = 26, Text = "", Parent = self.spectateBar })
	pill("<", UDim2.fromOffset(48, 48), UDim2.new(0.5, -150, 0.5, 0), LAVENDER, self.spectateBar).Activated:Connect(function()
		self:Cycle(-1)
	end)
	pill(">", UDim2.fromOffset(48, 48), UDim2.new(0.5, 150, 0.5, 0), LAVENDER, self.spectateBar).Activated:Connect(function()
		self:Cycle(1)
	end)
	self.watchButton = pill("PLAY LOBBY", UDim2.fromOffset(150, 40), UDim2.new(0.5, 0, 0, -40), PINK, gui)
	self.watchButton.AnchorPoint = Vector2.new(0.5, 1)
	self.watchButton.Position = UDim2.new(0.5, 0, 1, -128)
	self.watchButton.Visible = false
	self.watchButton.Activated:Connect(function()
		self.watchWanted = not self.watchWanted
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Z then
			self:Cycle(-1)
		elseif input.KeyCode == Enum.KeyCode.X then
			self:Cycle(1)
		end
	end)

	shared:GetAttributeChangedSignal("ShowState"):Connect(function()
		self:_onState()
	end)
	self.player:GetAttributeChangedSignal("ShowStatus"):Connect(function()
		self:_onStatus()
	end)
	RunService.RenderStepped:Connect(function()
		self:_update()
	end)
	self:_onState()
	return self
end

function ShowClient:State()
	return self.shared:GetAttribute("ShowState") or "Lobby"
end

function ShowClient:Status()
	return self.player:GetAttribute("ShowStatus") or "Lobby"
end

-- True while this player is competing in a round (not in the lobby, not knocked out).
function ShowClient:IsCompeting()
	local status = self:Status()
	return IN_SHOW[self:State()] == true and (status == "Alive" or status == "Qualified")
end

function ShowClient:TimeLeft()
	return (self.shared:GetAttribute("StateEndsAt") or 0) - workspace:GetServerTimeNow()
end

function ShowClient:Feed(text)
	self.feedOrder += 1
	local line = label({ Size = UDim2.new(1, 0, 0, 26), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Text = text, LayoutOrder = self.feedOrder, Parent = self.feed })
	local lines = self.feed:GetChildren()
	local textLines = {}
	for _, child in lines do
		if child:IsA("TextLabel") then
			table.insert(textLines, child)
		end
	end
	table.sort(textLines, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #textLines - FEED_LINES do
		textLines[i]:Destroy()
	end
	task.delay(6, function()
		if line.Parent then
			TweenService:Create(line, TweenInfo.new(1), { TextTransparency = 1 }):Play()
			TweenService:Create(line:FindFirstChildOfClass("UIStroke"), TweenInfo.new(1), { Transparency = 1 }):Play()
			task.delay(1, function()
				line:Destroy()
			end)
		end
	end)
end

function ShowClient:_showCard(top, title, body, accent)
	self.cardTop.Text = top
	self.cardTitle.Text = title
	self.cardBody.Text = body
	self.card:FindFirstChildOfClass("UIStroke").Color = accent or LAVENDER
	self.card.Visible = true
	self.card.Size = UDim2.fromOffset(540, 160)
	TweenService:Create(self.card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(600, 180) }):Play()
end

function ShowClient:_onState()
	local state = self:State()
	local shared = self.shared
	self.card.Visible = false
	self.countdown.Visible = false
	self.lastCount = nil
	if state == "Intro" then
		local final = shared:GetAttribute("RoundFinal")
		local top = final and "FINAL ROUND" or ("ROUND %d OF %d"):format(shared:GetAttribute("RoundNumber") or 1, shared:GetAttribute("RoundCount") or 1)
		self:_showCard(top, shared:GetAttribute("RoundName") or "", shared:GetAttribute("RoundGoal") or "", final and GOLD or LAVENDER)
	elseif state == "Countdown" then
		self.countdown.Visible = true
	elseif state == "Playing" then
		self:_pop("GO!", MINT)
		task.delay(0.9, function()
			if self:State() == "Playing" then
				self.countdown.Visible = false
			end
		end)
	elseif state == "Results" then
		self.hud:Toast("ROUND OVER", GOLD)
	elseif state == "Podium" then
		local winners = shared:GetAttribute("Winners") or ""
		if winners == "" then
			self:_showCard("SHOW OVER", "NO WINNER", "Everyone dropped out. Next show soon!", PINK)
		else
			self:_showCard("CROWNED", winners, "Next show starting soon", GOLD)
			if table.find(string.split(winners, ", "), self.player.DisplayName) then
				self.hud:Toast("YOU WIN!", GOLD)
			end
		end
	end
end

function ShowClient:_onStatus()
	local status = self:Status()
	if status == "Qualified" and self:State() == "Playing" then
		self.hud:Toast("QUALIFIED!", MINT)
	elseif status == "Eliminated" then
		self.hud:Toast("ELIMINATED", PINK)
		self.watchWanted = true
	end
end

function ShowClient:_pop(text, color)
	local countdown = self.countdown
	countdown.Visible = true
	countdown.Text = text
	countdown.TextColor3 = color or WHITE
	countdown.TextSize = 130
	TweenService:Create(countdown, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 100 }):Play()
end

-- Balls still in the running, excluding our own.
function ShowClient:_candidates()
	local character = self.player.Character
	local mine = character and character:FindFirstChild("Ball")
	local list = {}
	for _, ball in CollectionService:GetTagged("RollBall") do
		if ball ~= mine and ball:GetAttribute("ShowAlive") and ball:IsDescendantOf(workspace) then
			table.insert(list, ball)
		end
	end
	table.sort(list, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return list
end

local function ballName(ball)
	local owner = Players:GetPlayerFromCharacter(ball.Parent)
	return owner and owner.DisplayName or ball.Name
end

function ShowClient:Cycle(direction)
	self.spectateIndex += direction
end

-- The ball the camera should follow instead of our own, or nil.
function ShowClient:GetSpectateTarget()
	return self.target
end

function ShowClient:_update()
	local state = self:State()
	local status = self:Status()
	local shared = self.shared
	local timeLeft = self:TimeLeft()

	-- Banner
	local banner, sub = "", ""
	if state == "Intermission" then
		banner = ("NEXT SHOW IN %d"):format(math.max(0, math.ceil(timeLeft)))
		sub = "roll around the park while you wait"
	elseif state == "Lobby" then
		banner = ""
	elseif IN_SHOW[state] then
		if status == "Lobby" then
			banner = "SHOW IN PROGRESS"
			sub = "you'll join the next one"
		else
			local info = shared:GetAttribute("RoundInfo") or ""
			local roundName = shared:GetAttribute("RoundName") or ""
			banner = info ~= "" and info or roundName
			if state == "Playing" and timeLeft > 0 then
				banner ..= "   " .. formatClock(timeLeft)
			end
			sub = info ~= "" and roundName or ""
		end
	elseif state == "Podium" then
		banner = "SHOW OVER"
	end
	self.banner.Text = banner
	self.subBanner.Text = sub
	self.hud:SetCourseVisible(banner == "") -- the banner takes the course timer's spot

	-- Countdown numbers
	if state == "Countdown" then
		local count = math.max(1, math.ceil(timeLeft))
		if count ~= self.lastCount then
			self.lastCount = count
			self:_pop(tostring(count), GOLD)
		end
	end

	-- Spectating: knocked out while the show goes on.
	local canWatch = status == "Eliminated" and IN_SHOW[state] == true
	local candidates = canWatch and self.watchWanted and self:_candidates() or {}
	if #candidates > 0 then
		self.spectateIndex = (self.spectateIndex - 1) % #candidates + 1
		self.target = candidates[self.spectateIndex]
		self.spectateName.Text = "WATCHING  " .. ballName(self.target)
	else
		self.target = nil
	end
	self.spectateBar.Visible = self.target ~= nil
	self.watchButton.Visible = canWatch
	self.watchButton.Text = self.watchWanted and "PLAY LOBBY" or "WATCH SHOW"
end

return ShowClient
