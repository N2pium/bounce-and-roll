# Bounce & Roll

Roblox physics party game: you're a hamster ball. Tilt your phone (or use a stick/keyboard) to roll, bump your friends off the map, and survive a show of elimination rounds. See [ROADMAP.md](ROADMAP.md) for status, [GAME_DESIGN.md](GAME_DESIGN.md) for the design, and [VIRAL_ROBLOX_RESEARCH.md](VIRAL_ROBLOX_RESEARCH.md) for the research behind it.

## Layout

| File | Lives in Studio at | What it does |
|---|---|---|
| `src/shared/BounceRoll/Config.luau` | `ReplicatedStorage.BounceRoll.Config` | Feel + show tuning: gravity, bounce, speed, jump, dash, bumps, camera, tilt, round timings |
| `src/shared/BounceRoll/TubePath.luau` | `ReplicatedStorage.BounceRoll.TubePath` | Glass tube rides (shared by the client controller and server bots) |
| `src/shared/BounceRoll/Moods.luau` | `ReplicatedStorage.BounceRoll.Moods` | The 8 lighting moods (sky + light + haze + grade + tints) and which rounds use which |
| `src/server/BallServer.server.luau` | `ServerScriptService.BallServer` | Puts avatars in hamster balls, relays bumps, squad counts, lobby bump bots |
| `src/server/BallFactory.luau` | `ServerScriptService.BallFactory` | Shared ball + name-tag builder for players and bots |
| `src/server/MoodDirector.luau` | `ServerScriptService.MoodDirector` | Picks the current mood (per round kind, or a slow lobby cycle) |
| `src/server/MoodServer.server.luau` | `ServerScriptService.MoodServer` | Starts the level's mood |
| `src/server/Show/ShowManager.server.luau` | `ServerScriptService.Show.ShowManager` | The show loop: intermission → rounds → podium |
| `src/server/Show/Participants.luau` | `…Show.Participants` | One interface over players and bots |
| `src/server/Show/BotBrain.luau` | `…Show.BotBrain` | Bot balls and their Race / Hex / Sweeper behaviors |
| `src/server/Show/Rounds/*.luau` | `…Show.Rounds.*` | Race (Roll Race / Tube Town), Hex-a-Roll, Sweeper (+ shared Survival rules) |
| `src/client/BounceClient/init.client.luau` | `StarterPlayerScripts.BounceClient` | Client entry: input, controller, bumps, camera, show teleports/freezes |
| `src/client/BounceClient/*.luau` | child modules | BallController, ChaseCamera, Bumps, TiltInput, MoveInput, Effects, Hud, Mood, Ambience, ShowClient |
| `tools/build_map.luau` | — | Builds Bounce Park (the lobby), remotes, lighting and StarterPlayer settings |
| `tools/dress_map.luau` | — | Dreamcore dressing: checker floors, cloud ocean, rainbows, doorways, orbs, default mood |
| `tools/build_rounds.luau` | — | Builds the round maps into `ServerStorage.RoundMaps`; races are lists of sections (Start, Slope, Slalom, Hops, Tube, Spinner, PadUp, Bridge, Finish) |

Assets that only live in the place file: `ReplicatedStorage.BounceRoll.Skies` (the 8 skyboxes, named after their moods) and `ReplicatedStorage.BounceRoll.Assets` (the cloud mesh used by the tools).

## Setting up a place

1. Open the place in Studio and run, in the command bar (Edit mode): `tools/build_map.luau`, then `tools/dress_map.luau`, then `tools/build_rounds.luau`.
2. Sync the scripts, either with [Rojo](https://rojo.space) (`rojo serve`, using `default.project.json`) or by copying each file into the Studio location in the table above.
3. `workspace.StreamingEnabled` must be off: the show teleports players between maps that are far apart.

## The show

`Intermission (20s) → race (Roll Race or Tube Town) → Sweeper → Hex-a-Roll final → Podium`. Bots fill every show up to 8 participants. Fewer than 5 participants shortens the playlist. The show stops early once no human players are left. Eliminated players are sent to the lobby and can spectate (Z / X or the arrows) or leave to play the lobby.

## Level-design tags

| Tag / attribute | Effect |
|---|---|
| `BouncePad` (`Power`, optional `Push` Vector3) | Launches the ball up; `Push` guarantees forward speed |
| `Bumper` (`Power`) | Pinball bumper |
| `Checkpoint` (`Order`) | Respawn point; must increase along the course |
| `CameraZone` (`Yaw` degrees, `Priority`, optional `Pitch`, `Distance`) | Camera faces `Yaw` inside the box (180 = +Z, -90 = +X) |
| `KillPart` | Touching it respawns you |
| `Finish` | Stops the lobby course timer |
| `Spinner` | Kept server-simulated |
| `TubeMouth` | Entrance trigger of a tube Model (`Speed`, `ExitSpeed` attributes; `Path` part with numbered Attachments) |
| `HexTile` | Hex-a-Roll tile part (a tile Model is three of them) |
| `MoodCloud` / `MoodSea` | Tinted by the current mood; clouds also bob (`FloatAmount`) |
| `DreamFloat` | Bobs gently (`FloatAmount`) |

Round maps (`ServerStorage.RoundMaps.*`) carry `Kind`, `DisplayName`, `Goal` and `KillY` attributes, plus `Spawns/`, `Waypoints/` (bot route: `Jump`, `Checkpoint` attributes) and `Course/`.
