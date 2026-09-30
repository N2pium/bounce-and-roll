-- Starts on the level's mood (the map's "Mood" attribute), then slowly cycles moods while in the
-- lobby. During a show, ShowManager stops the cycle and picks a mood per round instead.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Moods = require(ReplicatedStorage:WaitForChild("BounceRoll"):WaitForChild("Moods"))
local MoodDirector = require(ServerScriptService:WaitForChild("MoodDirector"))

local map = workspace:FindFirstChild("BounceParkMap")
MoodDirector.Set(map and map:GetAttribute("Mood") or Moods.Default)
MoodDirector.StartLobbyCycle()
