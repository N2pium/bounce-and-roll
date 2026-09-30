-- Picks the server's lighting mood and publishes it as the "Mood" attribute on
-- ReplicatedStorage.BounceRoll; every client crossfades to it. The round system calls
-- MoodDirector.ForRound(kind) at the start of each round; until then the lobby cycles slowly.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BounceRoll")
local Moods = require(Shared:WaitForChild("Moods"))

local MoodDirector = {}

local cursors = {} -- rotation position per round kind
local lobbyThread = nil

function MoodDirector.Get()
	return Shared:GetAttribute("Mood")
end

function MoodDirector.Set(name)
	if not Moods.List[name] then
		warn("MoodDirector: unknown mood " .. tostring(name))
		return
	end
	Shared:SetAttribute("Mood", name)
end

-- Advances the rotation for a round kind (Lobby / Race / Survival / Final) and applies it,
-- skipping the current mood so consecutive rounds always look different.
function MoodDirector.ForRound(kind)
	local list = Moods.Rotation[kind] or Moods.Rotation.Lobby
	local index = (cursors[kind] or math.random(0, #list - 1)) % #list + 1
	if list[index] == MoodDirector.Get() and #list > 1 then
		index = index % #list + 1
	end
	cursors[kind] = index
	MoodDirector.Set(list[index])
	return list[index]
end

function MoodDirector.StartLobbyCycle(seconds)
	MoodDirector.StopLobbyCycle()
	lobbyThread = task.spawn(function()
		while true do
			task.wait(seconds or Moods.LobbyRotateSeconds)
			MoodDirector.ForRound("Lobby")
		end
	end)
end

function MoodDirector.StopLobbyCycle()
	if lobbyThread then
		task.cancel(lobbyThread)
		lobbyThread = nil
	end
end

return MoodDirector
