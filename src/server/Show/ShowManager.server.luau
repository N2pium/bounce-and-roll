-- The show loop: lobby intermission -> rounds that eliminate players -> podium -> repeat.
-- Publishes its state as attributes on ReplicatedStorage.BounceRoll (ShowState, StateEndsAt,
-- RoundName, RoundGoal, RoundInfo, RoundNumber, RoundCount, KillY, RespawnEnabled, Winners)
-- and each player's "ShowStatus" attribute (Lobby / Alive / Qualified / Eliminated).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("BounceRoll")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")
local MoodDirector = require(ServerScriptService:WaitForChild("MoodDirector"))
local Participants = require(script.Parent:WaitForChild("Participants"))
local RoundsFolder = script.Parent:WaitForChild("Rounds")
local Rounds = {
	Race = require(RoundsFolder:WaitForChild("Race")),
	Hex = require(RoundsFolder:WaitForChild("Hex")),
	Sweeper = require(RoundsFolder:WaitForChild("Sweeper")),
}
local roundMaps = ServerStorage:WaitForChild("RoundMaps")

local cfg = Config.Show

local activeFolder = Instance.new("Folder")
activeFolder.Name = "ActiveRound"
activeFolder.Parent = workspace

local RACE = { map = { "Race", "TubeTown" }, round = "Race", mood = "Race" } -- one race map, picked at random
local SWEEPER = { map = "Sweeper", round = "Sweeper", mood = "Survival" }
local FINAL = { map = "HexARoll", round = "Hex", mood = "Final", final = true }

local function playlistFor(count)
	if count <= 2 then
		return { FINAL }
	elseif count <= 4 then
		return { RACE, FINAL }
	end
	return { RACE, SWEEPER, FINAL }
end

local function lobbySpawn()
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	return spawn and spawn.Position + Vector3.new(0, 5, 0) or Vector3.new(0, 70, 0)
end

-- API used by the round modules -----------------------------------------------------------
local show = { config = cfg }
local byPlayer = {} -- player -> participant in the current show

local function setState(state, seconds)
	Shared:SetAttribute("ShowState", state)
	Shared:SetAttribute("StateEndsAt", seconds and workspace:GetServerTimeNow() + seconds or 0)
end

function show:StartTimer(seconds)
	Shared:SetAttribute("StateEndsAt", workspace:GetServerTimeNow() + seconds)
	return os.clock() + seconds
end

function show:SetInfo(text)
	Shared:SetAttribute("RoundInfo", text)
end

function show:Feed(text)
	Remotes.ShowEvent:FireAllClients("feed", text)
end

function show:Qualify(p)
	p:SetStatus("Qualified")
	self:Feed(p.name .. " qualified!")
end

function show:Eliminate(p)
	if p.status == "Eliminated" then
		return
	end
	p:SetStatus("Eliminated")
	self:Feed(p.name .. " is out")
	if p.isBot then
		p:Destroy()
	elseif p:IsValid() then
		p:Teleport(lobbySpawn(), math.pi, false)
	end
end

-- Show flow ------------------------------------------------------------------------------
local function prune(list)
	local out = {}
	for _, p in list do
		if p:IsValid() and p.status ~= "Eliminated" then
			table.insert(out, p)
		end
	end
	return out
end

local function anyPlayer(list)
	for _, p in list do
		if not p.isBot then
			return true
		end
	end
	return false
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function runRound(index, total, entry, alive)
	local mapName = typeof(entry.map) == "table" and entry.map[math.random(1, #entry.map)] or entry.map
	local map = roundMaps:WaitForChild(mapName):Clone()
	map.Parent = activeFolder
	for _, part in map:GetDescendants() do
		if CollectionService:HasTag(part, "Spinner") then
			pcall(part.SetNetworkOwner, part, nil)
		end
	end

	MoodDirector.ForRound(entry.mood)
	Shared:SetAttribute("RoundName", map:GetAttribute("DisplayName"))
	Shared:SetAttribute("RoundGoal", map:GetAttribute("Goal"))
	Shared:SetAttribute("RoundNumber", index)
	Shared:SetAttribute("RoundCount", total)
	Shared:SetAttribute("RoundFinal", entry.final == true)
	Shared:SetAttribute("KillY", map:GetAttribute("KillY"))
	Shared:SetAttribute("RespawnEnabled", entry.round == "Race")
	show:SetInfo("")

	local spawns = map.Spawns:GetChildren()
	shuffle(spawns)
	for i, p in alive do
		p:SetStatus("Alive")
		local spawn = spawns[(i - 1) % #spawns + 1]
		local stack = Vector3.new(0, 10 * math.floor((i - 1) / #spawns), 0)
		p:Teleport(spawn.Position + stack, math.pi, true)
	end

	setState("Intro", cfg.IntroSeconds)
	task.wait(cfg.IntroSeconds)
	setState("Countdown", cfg.CountdownSeconds)
	task.wait(cfg.CountdownSeconds)
	for _, p in alive do
		p:SetFrozen(false)
	end
	setState("Playing")

	local ok, result = pcall(Rounds[entry.round].Run, show, map, alive, entry)
	if not ok then
		warn("Round " .. entry.round .. " failed: " .. tostring(result))
		result = alive
	end
	local qualified = prune(result)
	local made = {}
	for _, p in qualified do
		made[p] = true
		p:SetStatus("Qualified")
	end

	setState("Results", cfg.ResultsSeconds)
	for _, p in alive do
		p:SetBehavior(nil)
		if not made[p] then
			show:Eliminate(p)
		end
	end
	task.wait(cfg.ResultsSeconds)

	-- Hold survivors still while the map is swapped out from under them.
	for _, p in qualified do
		p:SetFrozen(true)
	end
	map:Destroy()
	return qualified
end

local function podium(winners)
	local names = {}
	for _, p in winners do
		table.insert(names, p.name)
		if not p.isBot and p:IsValid() then
			local wins = p.player:FindFirstChild("leaderstats") and p.player.leaderstats:FindFirstChild("Wins")
			if wins then
				wins.Value += 1
			end
		end
	end
	Shared:SetAttribute("Winners", table.concat(names, ", "))
	MoodDirector.Set("Daydream")
	for _, p in winners do
		if p:IsValid() then
			p:Teleport(lobbySpawn() + Vector3.new(0, 4, 0), math.pi, false)
		end
	end
	setState("Podium", cfg.PodiumSeconds)
	task.wait(0.5)
	for _, p in winners do
		local ball = p:IsValid() and p:GetBall()
		if ball then
			Remotes.ShowEvent:FireAllClients("confetti", ball.Position)
		end
	end
	task.wait(cfg.PodiumSeconds - 0.5)
end

local function endShow(participants)
	for _, p in participants do
		if p.isBot then
			p:Destroy()
		elseif p:IsValid() then
			p:SetStatus("Lobby")
			p:SetFrozen(false)
		end
	end
	table.clear(byPlayer)
	activeFolder:ClearAllChildren()
end

local function enterLobby()
	Shared:SetAttribute("KillY", Config.World.KillY)
	Shared:SetAttribute("RespawnEnabled", true)
	Shared:SetAttribute("RoundInfo", "")
	Shared:SetAttribute("Winners", "")
	MoodDirector.StartLobbyCycle()
end

-- Players --------------------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = leaderstats
	leaderstats.Parent = player
	player:SetAttribute("ShowStatus", "Lobby")

	-- Resetting mid-round forfeits.
	player.CharacterAdded:Connect(function()
		local p = byPlayer[player]
		if p and (p.status == "Alive" or p.status == "Qualified") then
			show:Eliminate(p)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	byPlayer[player] = nil
end)

-- Main loop ------------------------------------------------------------------------------
while true do
	setState("Lobby")
	enterLobby()
	while #Players:GetPlayers() == 0 do
		task.wait(1)
	end
	setState("Intermission", cfg.IntermissionSeconds)
	task.wait(cfg.IntermissionSeconds)

	if #Players:GetPlayers() > 0 then
		MoodDirector.StopLobbyCycle()
		local participants = {}
		for _, player in Players:GetPlayers() do
			if #participants < cfg.MaxParticipants then
				local p = Participants.FromPlayer(player)
				byPlayer[player] = p
				table.insert(participants, p)
			end
		end
		while #participants < cfg.MinParticipants do
			table.insert(participants, Participants.NewBot())
		end

		local playlist = playlistFor(#participants)
		local alive = participants
		for index, entry in playlist do
			alive = runRound(index, #playlist, entry, alive)
			-- Stop early once a winner is decided or no players are left to watch.
			if #alive <= 1 or not anyPlayer(alive) then
				break
			end
		end
		podium(alive)
		endShow(participants)
	end
end
