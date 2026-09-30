# Bounce & Roll

Roblox physics party game: you're a hamster ball. Tilt your phone (or use a stick/keyboard) to roll, bump your friends off the map. See [GAME_DESIGN.md](GAME_DESIGN.md) and [VIRAL_ROBLOX_RESEARCH.md](VIRAL_ROBLOX_RESEARCH.md).

## Layout

| File | Lives in Studio at | What it does |
|---|---|---|
| `src/shared/BounceRoll/Config.luau` | `ReplicatedStorage.BounceRoll.Config` | All feel tuning: gravity, bounce, speed, jump, dash, bumps, camera, tilt |
| `src/server/BallServer.server.luau` | `ServerScriptService.BallServer` | Puts avatars in hamster balls, relays bumps, squad counts, bump bots |
| `src/client/BounceClient/init.client.luau` | `StarterPlayerScripts.BounceClient` | Client entry: wires input, controller, bumps, camera, HUD |
| `src/client/BounceClient/BallController.luau` | child module | Rolling, jumps, float, dash, pads, bumpers |
| `src/client/BounceClient/ChaseCamera.luau` | child module | Tilt-friendly chase camera (camera zones) |
| `src/client/BounceClient/Bumps.luau` | child module | Ball-vs-ball bump detection |
| `src/client/BounceClient/TiltInput.luau` | child module | Phone tilt + calibration |
| `src/client/BounceClient/MoveInput.luau` | child module | Keyboard / gamepad / touch thumbstick |
| `src/client/BounceClient/Effects.luau` | child module | Particles, pop text, sounds |
| `src/client/BounceClient/Hud.luau` | child module | Timer, toasts, touch buttons |
| `tools/build_map.luau` | — | Builds the Bounce Park test map, remotes, lighting and StarterPlayer settings |

## Setting up a place

1. Open a place in Studio and paste `tools/build_map.luau` into the command bar (Edit mode). This builds the map and the remotes, and sets the StarterPlayer and lighting options.
2. Sync the scripts, either with [Rojo](https://rojo.space) (`rojo serve`, using `default.project.json`) or by copying each file into the Studio location in the table above.

## Level-design tags

| Tag / attribute | Effect |
|---|---|
| `BouncePad` (`Power`, optional `Push` Vector3) | Launches the ball up; `Push` guarantees forward speed |
| `Bumper` (`Power`) | Pinball bumper |
| `Checkpoint` (`Order`) | Respawn point; must increase along the course |
| `CameraZone` (`Yaw` degrees, `Priority`) | Camera faces `Yaw` inside the box (180 = +Z, -90 = +X) |
| `KillPart` | Touching it respawns you |
| `Finish` | Stops the run timer |
| `Spinner` | Kept server-simulated |
