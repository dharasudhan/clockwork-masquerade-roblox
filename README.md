# The Clockwork Masquerade: Mystery at Sterling Manor (Roblox)

Ottran Studios · Rojo + Luau · **Milestone M1 — core loop vertical slice** (Gate 1 + Gate 2 approved Oct 28 2026).
Asymmetric chase with light sabotage: guests repair Sterling Manor's grid; 1–2 Phantoms hide among them by day and
hunt by night. Tagged guests become Electro-Wisps and keep playing. Secular 1920s inventor / steampunk-neon look,
family-safe, **no ghosts** (deliberately not Ghost Mansion's look).

Roblox target: universe `10773325724`, root place `80777289760756` (Murali's private experience, formerly
"GhostMansionTest", repurposed). **Private. No Robux products.** Never touch universe `10773325904` (Ghost Mansion) —
`scripts/luau_exec.py` refuses it.

## M1 rules and numbers (all in `src/shared/Config/*`, data-driven)

| | |
|---|---|
| Lobby | 30 s on the Phonograph Terrace; min **6** participants (bots fill), max **10** (`Config/Match`) |
| Roles | 1 Phantom per 5: **1 at ≤ 6, 2 at 7–10**; last round's Phantoms go to the back of the queue; the role is sent **only to its owner** (never a replicated attribute) |
| Night 1 "Main Breaker Tripped" | Day **60 s** → Night **90 s** (`Config/Nights[1]`); M1 ends after Night 1 |
| Day: scavenge | 12 of 16 chest spots stocked; 1 s hold to search; loot weights dry-cell 50 / copper wire 30 / glow-stick 20; carry caps 3 / 2 / 3. Phantoms can search too (decoy loot) so item counters never reveal them |
| Day: tamper | Phantom stands still **4 s** within 7 studs of a breaker (moving > 2 studs cancels); **1 tamper per night** total; stays hidden until night falls, then the breaker trips (red light, sparks) |
| Night: transform | Phantoms unmask (neon mask, violet glow, 1.5 s freeze), speed **21** vs guests **16** |
| Night: lantern | battery 20 s at start, cap 40 s, drains 1 s/s, dry-cell +20 s; cone 30 studs / ±20°, needs line of sight; each beam on a Phantom **−25 % speed, stacking, capped at −60 %** (one focused beam: 21 → 15.75 < 16). Aim = client camera look vector (rate-limited 15/s, NaN/zero rejected, stale > 1.2 s → body facing) |
| Night: repair | stand still at the tripped breaker: **6 s** alone, **3 s** carrying copper wire (used up); cooperative — rates add |
| Reboot | with all 3 breakers online the grid reaches 100 % in 72 s; each tripped breaker removes 1/3 of the rate → a tripped breaker must be repaired by ~54 s into the night |
| Tag | Phantom, range 6 studs (+1.5 latency slack for real players), line of sight, cooldown 3 s, then 1.5 s recoil at half speed → **Energy Bubble** 3 s → **Electro-Wisp** |
| Electro-Wisp | floating orb drone (body hidden, does not collide with characters), speed 18, **cannot tag**; **Flicker** the room's lights 4 s (cd 20 s); **Oil slick** (cd 30 s, **max 2 alive**, lasts 45 s, guests ×0.7 speed for 2 s, Phantoms unaffected) |
| Glow-stick | guests at night: drop one (max 2 alive, 30 s); Phantoms within 16 studs are outlined through walls |
| Win check | all guests tagged → **Phantoms**; reboot 100 % with ≥ 1 guest untagged → **Guests** (dawn, ends the night); night timer out below 100 % → Phantoms ("the manor stayed dark"); all Phantoms leave → Guests |
| Results | 10 s card (winner, reason, the Phantoms revealed, Gear Tokens) → characters reloaded on the terrace → loop |
| Saves | ProfileStore `ClockworkMasquerade_PlayerData_v1`: `GearTokens`, `Wins.Guest`, `Wins.Phantom`, `Played`, `Settings`; sanitised on load (`Logic/SaveData`). Tokens per match: 5 + 10 win + 1/chest + 3/repair + 2/tag, cap 40. Bots never save |

Interpretation notes: Wisps help the Phantoms (the GDD's "snowball (Wisp caps)" risk) — flicker hurts guests' sight,
slicks slow guests only. Reaching 100 % ends the night immediately (dawn). The full game will carry an unfinished
night into Night 2 (M2); in M1 that case is a Phantom win.

## Map

`Config/Manor` (rooms as rectangles + doors on shared edges → `Logic/ManorLayout` builds walls with door gaps, door
points and BFS routes): Ballroom (centre, spawn ring), Foyer, West/East/North corridors, **Boiler Room (A)**, **Clock
Workshop (B)**, **Observatory (C)** (the 3 breaker rooms, dead ends), Luggage Room, Tea Parlour. Walnut floors, teal
walls with walnut wainscot and brass rails, copper pipes, brass gears with teal-neon hubs, chandeliers (warm by day,
deep violet emergency light at night, `Config/Lighting`). 636 parts. Lobby: checkered marble terrace with a phonograph,
title board and lamps south of the closed front doors.

## Code layout

```
src/shared/Config   Match, Nights, Gadgets, Manor, Style, Lighting, Audio, Bots, Billboards, DataTemplate (pure data)
src/shared/Logic    Roles, Lantern, Grid, Outcome, Loot, Cooldown, Channel, Rewards, SaveData, ManorLayout,
                    BotBrain, HudLayout, RateLimiter   (pure, no requires — unit-tested under Lune)
src/server          MatchService (state machine, 10 Hz tick, remotes), Participants (players + bots behind one
                    record), ManorBuilder, LightingService, ChestService, GridService, LanternService, ChaseService,
                    BotService, DataService, Net (remotes + rate limits), Clock, Build
src/client          init (buttons/keys, lantern aim), Hud, State, PromptFilter, SoundManager
```

Remotes: `Action(kind, arg)` (lantern / cell / glow / tag / flicker / slick / cancel / whoami; 8 burst, 6/s),
`Aim(x, y, z)` (20 burst, 15/s), `Notify(payload)` server → client (toast, sfx, role, channel, results). Public state is
attributes: workspace `CM_Phase`, `CM_PhaseEndsAt`, `CM_Reboot`, `CM_Tripped`, `CM_Night*`, `CM_Guests*`,
`CM_Winner/Reason`; per player/bot `PState` (a Phantom shows `Guest` by day), items, `Battery`, `LanternOn`, cooldown
`*ReadyAt`. A Phantom's tamper channel is only told to that player.

Bots (`BotService` + pure `Logic/BotBrain`): guests scavenge, repair, shine lanterns at a near Phantom, flee (away, or
dodge out of a dead-end room), group up; Phantoms tamper an unwatched breaker (bold in the last 25 s of the day), blend
by searching chests, hunt the most isolated guest at night; Wisps drop slicks near guests and flicker rooms with
guests. They call the same server entry points as players. Rigs: R15 from HumanoidDescription (fallback block rig).

## Phone-first HUD

`Logic/HudLayout` computes every rect: role chip top-left, **phase timer pill top centre**, objective line, reboot
meter, toasts, items and lantern battery, up to 3 context buttons in a row **left of Roblox's touch jump button**
(nothing interactive in the thumbstick half). Phones (min axis ≤ 500 px) scale to 0.75, tablets 1.15. Tested at
780×360, 891×411, 2340×1080, 1024×768 tablet and 1366×768 desktop (no overlaps, on screen, clear of jump/thumbstick).
Keys: F lantern, C dry-cell, G glow-stick, Q tag, Z flicker, X slick (E = prompts). World labels are stud-sized with
MaxDistance ≤ 90 and hidden behind walls.

## Tests

```sh
./scripts/test.sh     # syntax (59 files), 47 unit specs (Lune), rojo build x2, place verify (50 checks),
                      # engine smoke (19 steps incl. full rounds), stylua check (non-fatal)
```

Engine smoke (`scripts/engine_smoke.luau`, Lune + shims): builds the manor; a full round with 1 human + 5 bots
(Lobby → Day → Night → Results → Lobby, role privacy, chests, bot tamper, trip at night, mask, results + save);
staged rules (chest once, tamper channel cancel + max 1, lantern slow stacking/cap, NaN aim, cooperative repair, tag →
bubble → wisp, flicker/slick cooldowns + cap, slick slows guests not Phantoms, remote validation + rate limit, both win
paths); 6 bot-only rounds with speed-true walking; HUD layouts + states; prompt filter; music hand-over.

Cloud (Open Cloud Luau Execution; key injected on the wire as `ROBLOX_API_KEY`):

```sh
export ROBLOX_UNIVERSE_ID=10773325724 ROBLOX_PLACE_ID=80777289760756
python3 scripts/luau_exec.py build/ClockworkMasquerade.rbxl tests/run.server.luau     # all specs incl. ProfileStore engine spec
python3 scripts/luau_exec.py build/ClockworkMasquerade.rbxl tests/boot_check.server.luau
python3 scripts/luau_exec.py --no-wait build/ClockworkMasquerade.rbxl tests/bots_check.server.luau   # ~75 s, then --resume <task>
python3 scripts/luau_exec.py build/ClockworkMasquerade.rbxl tests/audio_check.server.luau
python3 scripts/luau_exec.py --publish build/ClockworkMasquerade.production.rbxl tests/boot_check.server.luau  # private test publish
```

Luau Execution sessions don't run the place's Scripts (checks replay `init.server.luau`) and don't step physics (bots
hop between waypoints there; real servers walk). HTTP 409 = place open in Studio / Team Create: the script waits 60 s
and retries 5×.

## Studio settings to set by hand (scripts can't)

Max Players **10**; Enable Studio Access to API Services (to test saves in Studio); keep the experience **Private**
until Gate 6; rename the experience from "GhostMansionTest" when Murali wants.

## Status (Oct 28 2026)

M1 built and tested: local 47/47 specs + 19/19 smoke steps; cloud 48/48 specs, boot OK, real-engine bot round OK,
audio 14/14; published privately as place version 5. Next: Gate 3 playtest (phones), then M2 (Nights 2–3, Expose,
classes, badges, models).
