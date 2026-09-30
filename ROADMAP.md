# Bounce & Roll: Roadmap

*Last updated 2026-09-29. The design rationale lives in [GAME_DESIGN.md](GAME_DESIGN.md); this file tracks what's built and what's next.*

## Where we are

A full show is playable end to end in Studio. There's a lobby to roll around in, then a race, a sweeper round and a hex final, with bots filling out the field, and finally a winner crowned on the podium. It hasn't been tested on a phone or with more than one real player yet.

---

## Done

### Phase 1: Feel ✅
- Hamster-ball movement: floaty gravity, bouncy glass ball, avatar riding upright inside, air jump, hold-to-float, dash.
- Input: phone tilt with calibration, on-screen stick, keyboard and gamepad.
- Chase camera that stays readable with tilt controls. It uses per-section camera zones with their own direction, pitch and distance.
- Player-vs-player bumps are resolved by a custom networked system instead of physics collisions. Bumping a friend boosts them, and friends in the server make you sturdier.
- Bounce Park lobby course: pads, pinball bumpers, a sweeper, a bump arena with bots, checkpoints and a run timer.

### Phase 1.5: Dreamcore look ✅
- 8 lighting moods, one per skybox, each with its own light, haze, color grade and tints. Changes crossfade through a soft haze, with a caption.
- A cloud ocean made from the cloud mesh, pastel checker floors, rainbows, floating doorways, glowing orbs and sparkles around the camera.

### Phase 2: The show ✅
- Show loop: intermission → rounds → podium. Bots fill each show to 8. The show ends early when no humans are left.
- Rounds:
  - **Roll Race** and **Tube Town**: long races (1.6–1.9k studs), picked at random.
  - **Sweeper**: survival.
  - **Hex-a-Roll**: the final.
- Qualify/eliminate rules, falls in survival rounds are final, spectating, a show HUD (intro cards, countdown, live counters, feed, winner card), a Wins leaderboard, and moods chosen per round type.

### Phase 2.5: Scale & tubes ✅
- Platforms roughly doubled everywhere, so one bump rarely knocks you off.
  - Race platforms are 70 wide.
  - Hex tiles have about 3× the area across 91 tiles per layer.
  - The Sweeper platform is 130 across.
  - The lobby course is widened throughout.
- **Glass hamster tubes:** roll into a mouth and you're carried along a curved path at speed, then launched out at the end. Players and bots share the same ride code (`TubePath`).
- Races are built from reusable sections (`tools/build_rounds.luau`), so new races are just a list of sections.

---

## Next up

### Phase 3: Progression & polish (the "week 3" plan)
| Item | Notes |
|---|---|
| **Save data** (DataStore) | Coins, XP/level, Wins, owned cosmetics. Session locking plus retry on failure. |
| **Coins & XP** | Coins per round played, a bonus for qualifying, a big bonus for winning. An XP bar fills every show. |
| **Cosmetics shop** | 10 ball skins and 5 trails to start, bought with coins. A daily rotating featured slot. |
| **Daily quests** | 3 per day: "bump 10 players", "qualify 3 races", "ride 5 tubes". Reset at a fixed UTC time. |
| **"BUMPED!" kill-cam** | Slow-mo and zoom on the bump that knocks someone out. This is the clip moment. |
| **Real sound design** | Replace the built-in placeholder sounds: bump, boing, tube whoosh, chimes, soft lobby music per mood. |
| **Squad invite prompt** | A `SocialService` invite button that explains the squad buff. |
| **Thumbnail + icon** | Hamster ball mid-bump over the cloud sea, with a rainbow. |

### Phase 4: Launch readiness
- **Real-device tests:**
  - Tilt on iOS and Android, and flip `InvertX`/`InvertY` if needed.
  - A low-end Android phone at 60 FPS with 20 balls.
  - The dense Hex map (~1,100 parts) is the first performance check.
- **Multiplayer tests:**
  - 2-player (spectate, friend boost, bump relay under real latency).
  - Full 12–20 player servers.
- **Anti-exploit:** server-side speed and position sanity checks on client-owned balls, and a tighter bump reach check.
- **Analytics:** custom events for round reached, qualified, quit mid-show, tube rides and bumps. Watch D1 retention, first-play bounce and sessions per user.
- **Publishing:** experience questionnaire and age rating, private servers enabled, server size, and the place description and tags.

### Phase 5: Content & live ops
- **New rounds:**
  - King of the Hill (final).
  - Bumper Brawl (team).
  - Egg Grab (carry and steal).
  - Tilt Maze (race).
- **New race sections:** moving platforms, conveyors, fans, split paths, tube junctions (pick a branch).
- A weekly new-map rotation and weekend playlists (all-survival, low gravity).
- A Crown Pass (seasonal cosmetic track).
- A solo campaign ("Marble Worlds") for when friends are offline.

---

## Known issues & tech debt
- **Tilt is untested on a real phone.** The axis mapping comes from Roblox's docs.
- **Sounds are Roblox built-in placeholders.**
- **The server trusts client-owned ball physics.** An exploiter could fly or teleport. Sanity checks are in Phase 4.
- **Bots never bump players on purpose.** They only bump by accident.
- **Survival rounds end once enough players are out,** so a solo player vs bots can see short Sweeper rounds. Bot jump accuracy now drops as the bar speeds up, but it could use tuning with real players.
- **Scripts live in both the repo and the place file.** Studio is the source of truth while editing. Export back to `src/` after changes (Rojo would remove this step).
