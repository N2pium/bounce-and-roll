-- One interface over players and bots so rounds don't care which is which.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("BounceRoll"):WaitForChild("Remotes")
local BotBrain = require(script.Parent:WaitForChild("BotBrain"))

local Participants = {}

local Participant = {}
Participant.__index = Participant

function Participants.FromPlayer(player)
	return setmetatable({ player = player, name = player.DisplayName, isBot = false }, Participant)
end

function Participants.NewBot()
	local bot = BotBrain.New()
	return setmetatable({ bot = bot, name = bot.name, isBot = true }, Participant)
end

function Participant:IsValid()
	if self.isBot then
		return self.bot.ball.Parent ~= nil
	end
	return self.player.Parent ~= nil
end

function Participant:GetBall()
	if self.isBot then
		return self.bot.ball.Parent and self.bot.ball or nil
	end
	local character = self.player.Character
	return character and character:FindFirstChild("Ball")
end

-- Players teleport themselves (their client owns the ball); bots are moved directly.
function Participant:Teleport(position, yaw, frozen)
	if self.isBot then
		self.bot:Teleport(position)
		self.bot:SetFrozen(frozen == true)
	else
		Remotes.ShowEvent:FireClient(self.player, "teleport", position, yaw, frozen == true)
	end
end

function Participant:SetFrozen(frozen)
	if self.isBot then
		self.bot:SetFrozen(frozen)
	else
		Remotes.ShowEvent:FireClient(self.player, "freeze", frozen)
	end
end

function Participant:SetStatus(status)
	self.status = status
	if not self.isBot then
		self.player:SetAttribute("ShowStatus", status)
	end
	local ball = self:GetBall()
	if ball then
		ball:SetAttribute("ShowAlive", status == "Alive" or status == "Qualified")
	end
end

function Participant:SetBehavior(behavior, context)
	if self.isBot then
		self.bot:SetBehavior(behavior, context)
	end
end

function Participant:Destroy()
	if self.isBot then
		self.bot:Destroy()
	end
end

return Participants
