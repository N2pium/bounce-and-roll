# Bounce & Roll: Game Design

*Draft 2026-09-29. Builds on [VIRAL_ROBLOX_RESEARCH.md](VIRAL_ROBLOX_RESEARCH.md).*

**One line:** a party game where you're a marble. Tilt your phone to roll, bump your friends off the map, and be the last ball standing.

---

## 1. Key decisions (and why)

| Question | Decision | Why |
|---|---|---|
| Solo obby, or Fall Guys-style party? | **Party rounds are the main loop. A solo level campaign comes in phase 2.** | Bumping other players is the viral, clippable part, and it only exists in multiplayer. Solo levels are good for long-term retention but won't make the game spread. |
| Tilt-only on mobile? | **Tilt is the default on mobile, with a one-tap switch to a joystick.** | Forcing tilt will drive up first-play bounce (players quitting in their first session), and the algorithm now penalizes that. Plenty of kids play lying down, in a car, or on an iPad flat on a table. Tilt should be the hook, not a requirement. |
| Friends make you sturdier, or friends bouncier? | **Friends make you sturdier (the "Squad" buff).** Bumping a friend also gives them a speed boost instead of knockback. | It rewards bringing friends (a discovery signal) without giving groups a trolling advantage over solo players. The same collision helps friends and knocks strangers, so friends end up bumping each other on purpose. |
| Title | **"Bounce & Roll"**, or a more literal verb + noun like **"Bump a Ball"** / **"Hamster Ball Party"** | "Balance a Ball" suggests carrying a ball, which isn't what the game is. Test 2–3 titles and thumbnails with Roblox's thumbnail A/B testing. |

---

## 2. The player's ball (core identity)

- **Your avatar rides inside a clear hamster ball.** The shell rolls while an avatar clone inside stays upright using an `AlignOrientation`. Players keep their avatar identity, which kids care about, and the result is very screenshot- and clip-friendly.
- The ball *is* the character. There's no Humanoid movement. `Camera.CameraSubject` is set to the ball part.
- Physics tuning targets: heavy enough to feel grounded, bouncy enough to feel silly. Use `CustomPhysicalProperties` with elasticity around 0.5 on the shell and friction around 0.6.
- **Jump** is a small hop on a ~1s cooldown. **Dash / Bump** is a short burst forward on a ~3s cooldown and is the main trolling tool.
- Cosmetics are what you sell: shell skins, trails, pop effects on elimination, and bump sounds such as a honk, a vine boom or a meme sound.

## 3. Controls

| Device | Move | Jump | Dash |
|---|---|---|---|
| Mobile (default) | **Tilt** | Tap left side | Tap right side |
| Mobile (toggle) | Thumbstick | Button | Button |
| PC | WASD | Space | Shift / click |
| Console | Left stick | A | X / RT |

**Tilt implementation:**
- Read `UserInputService:GetDeviceGravity()` on `RenderStepped`, or listen to `DeviceGravityChanged`. Use `UserInputService.AccelerometerEnabled` to detect support.
- **Calibrate on round start.** Show "hold your phone how you like, then tap." The current gravity vector becomes neutral, and tilt is measured relative to it.
- Add a deadzone (~0.05), a sensitivity slider, an invert option, and a low-pass filter (`smoothed = smoothed:Lerp(raw, 0.25)`) so the ball doesn't jitter.
- Map the tilt vector to **camera-relative** world directions, then drive the ball with an `AngularVelocity` or `VectorForce`. Movement should build up momentum rather than feel instant.
- Lock orientation to landscape (`PlayerGui.ScreenOrientation = LandscapeSensor`).

**Camera: the most important design constraint.** Tilting while the camera rotates is disorienting. Use a **fixed-angle chase camera** that lags behind the ball's heading, or a **fixed isometric camera** for arena rounds (Hex-a-gone, survival). Players should never have to rotate the camera by hand. Tilt games feel good because "tilt right" always means the same thing on screen.

## 4. Collision and "harmless trolling"

The fun comes from making physics collision feel good over the network.

- **Network ownership:** each player's ball is owned by that client (`SetNetworkOwner(player)`) so their own movement is smooth.
- **Problem:** Roblox's default physics can't resolve collisions between two client-owned balls reliably. You'll get jitter and "phantom hits."
- **Solution: a custom bump system.**
  1. The client detects contact with another ball (distance < r1 + r2, checked each frame).
  2. It computes an impulse from relative velocity along the contact normal, adds extra force if the attacker is dashing, then applies its own half of the knockback locally right away.
  3. It fires `BumpRemote(victim, impulse)` to the server. The server validates distance, rate-limits requests, caps the impulse, and forwards it to the victim's client, which applies it.
  4. Both sides play the bump sound and VFX immediately, so the hit feels responsive even if the physics lands a little late.
- **Squad buff:** each friend in the server gives you +10% knockback resistance, up to 3 friends. Show a small "SQUAD x2" badge above your ball.
- **Friend boost:** bumping a friend adds speed along your heading instead of knockback. This creates co-op tricks like slingshotting each other.
- **Keeping trolling harmless:**
  - There's no permanent loss. Getting eliminated costs you the round, not your coins.
  - Players get 3s of spawn protection.
  - The knockback cap stops one-shot launches across the whole map.
  - In solo mode, collisions are off (or ghosts only), so trolling stays in party mode.
  - The server checks velocity and position against the physics ceiling to catch exploiters abusing client ownership of their ball.

## 5. Game structure: the "Show"

Each server holds **12–20 players**. It runs a continuous show of 3–5 rounds, which takes about 8–12 minutes. Every round eliminates some players, and the final round crowns a winner.

**Low-player-count safeguards (critical at launch):**
- A show starts with **1+ real players**. **Bot marbles** fill the lobby up to about 8. Bots are simple waypoint-following AIs with some randomness, named like "Bot_Marble".
- Late joiners play the **lobby playground** (a physics sandbox with bumpers and ramps) and join the next show.
- Rounds with fewer than 4 players skip elimination and are scored instead.

### Round types

**MVP rounds** (build these first):

| Round | Type | Summary |
|---|---|---|
| **Roll Race** | Race | Obstacle course to a finish line. The top ~60% qualify. Features narrow beams, rotating sweepers and ramps. |
| **Hex-a-Roll** | Survival | Layered hex tiles drop ~0.5s after you touch them. The last balls standing win. Tiles are server-owned; the server detects balls touching them using region checks. |
| **Sweeper** | Survival | A rotating bar sweeps a round platform and speeds up over time. Dash-bumping others into the bar is the main strategy. |

**Later rounds:**

| Round | Type | Summary |
|---|---|---|
| **King of the Hill** | Final | A shrinking platform. The last one on it wins the crown. |
| **Bumper Brawl** | Team | Two teams score by bumping the opposing team off the arena. |
| **Egg Grab** | Team | Carry a ball item back to your base, a nod to "Steal a..." games. |
| **Tilt Maze** | Race | A pure marble-app maze, and the tilt-control showcase. |

**Structure of a show:** round 1 race, round 2 survival or race, round 3 survival or team, final is King of the Hill or Hex-a-Roll.

## 6. Progression and retention (tuned to the 2026 algorithm)

The algorithm rewards day-1 and 28-day return rates and short loops, not long sessions.

- **Currencies:**
  - **Coins** come from every round played, with more for qualifying.
  - **Crowns** come from wins. They're rare and act as a status symbol on the leaderboard.
- **Level/XP bar** fills every show and unlocks a cosmetic every few levels. Something always goes up.
- **Daily quests** reset every 24h to bring players back within the window. Examples: "Bump 10 players", "Qualify 3 races", "Win a Hex round".
- **Weekly rotation:**
  - One new round or map every week.
  - A featured "weekend event" playlist, e.g. an all-survival show or low gravity.
- **Shop rotation:** a daily cosmetic shop (the Fortnite model) creates a reason to check in each day.
- **Phase 2: Solo campaign ("Marble Worlds")** with 30–90s tilt levels, a 3-star rating per level, and ghost replays of friends' best times. It's great for players who log in when no friends are online.

## 7. Monetization (no pay-to-win)

| Item | Price idea |
|---|---|
| Ball skins (rarity tiers) | 49–399 R$ |
| Trails / elimination pops / bump sounds | 25–149 R$ |
| Crown Pass (seasonal cosmetic track) | 299–499 R$ |
| VIP (2x coins, chat tag, exclusive skin) | 199 R$ gamepass |
| Private servers | Enable so friend groups can run their own shows |

Never sell knockback, speed or mass. The game's "fair chaos" is what keeps people playing.

## 8. Virality checklist

- [ ] **Thumbnail:** a hamster ball flying off a platform, other balls laughing nearby, bright colors.
- [ ] **Icon:** a single cute ball with an avatar face inside.
- [ ] **Clip moments:** add a slow-mo + zoom **"BUMPED!" kill-cam** when someone is knocked off, since that's the TikTok moment. Also add an end-of-show **replay of the best bump**.
- [ ] **Built-in share prompts:** a "Invite friends → SQUAD buff" prompt, using the `SocialService` invite prompt.
- [ ] **Mobile first:** test on a low-end Android. Target 60 FPS with 20 balls.
- [ ] **First 30 seconds:** spawn into the lobby playground with no menus, immediately rolling and bumping. The tilt calibration prompt only appears when the first round starts.

## 9. Build plan

**Week 1: Feel (don't skip this)**
- Ball controller: physics, jump, dash.
- Chase camera.
- Tilt input with calibration, plus keyboard and joystick.
- Custom bump networking tested with 2 real devices.
- *Goal: rolling around and bumping a friend is fun in an empty baseplate.*

**Week 2: Show loop**
- Round manager state machine: Lobby → Intro → Round → Results → Next → Final → Podium.
- The 3 MVP rounds.
- Qualification and elimination.
- Bot fillers.
- Spectate for eliminated players.

**Week 3: Meta and polish**
- Coins, XP and crowns with DataStore.
- 10 skins and a shop.
- Daily quests.
- Squad buff.
- Bump kill-cam.
- Sounds, VFX, thumbnail and icon.

**Launch and measure:**
- Watch D1 retention, first-play bounce, and sessions per user per day in Creator Analytics.
- Run small ad spend and post 10+ short clips.
- Iterate on the weakest metric before adding content.

**Risks:**

| Risk | Mitigation |
|---|---|
| Bump network jank | Prototype it first, in week 1. |
| Tilt players feel disadvantaged vs keyboard | Tune assist, or add optional tilt-only lobbies. |
| Dead servers at low CCU | Bots and solo-friendly rounds. |
