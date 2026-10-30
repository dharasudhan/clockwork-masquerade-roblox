# The Clockwork Masquerade: Mystery at Sterling Manor (Roblox)

Ottran Studios · Rojo + Luau · **M1.1 — "enormous manor" update** of the M1 core-loop slice (built Oct 28 2026
from Murali's playtest: "the time is too less for the game. have more items and more rooms, make the mansion
enormous" + "wall edges flicker"). Asymmetric chase with light sabotage: guests repair Sterling Manor's grid;
1–2 Phantoms hide among them by day and hunt by night. Tagged guests become Electro-Wisps and keep playing.
Secular 1920s inventor / steampunk-neon look, family-safe, **no ghosts** (deliberately not Ghost Mansion's look).

> **v1.0 release candidate (Oct 29 2026).** The sections below from "M1.1 rules" on describe the M1.1 base; v1.0 adds a
> 5-level manor (B1 Boiler Level, Ground, 1st, 2nd/Attic, Tower: 55 rooms, 80 doors, 4-stop lift, 6 breakers A–F),
> 3 nights (Breaker → Blueprint Archives → Dawn Reboot finale), Expose voting, Mechanist/Illuminator gadgets,
> progression / save v2 / daily / 9 badges, cosmetic shop (all Robux ids **0** = disabled), keyboard + gamepad input,
> console safe area + portrait HUD, skippable 7-shot intro + guided first match. Bot-only balance: **44 % guest wins**.
> Store kit + Murali's release checklist: `../store/` (`RELEASE-CHECKLIST.md`). Credits: `CREDITS.md`.

> **v1.2 (Oct 30 2026)** — merged from branch `upgrade/v1.2` (see `docs/UPGRADE-NOTES.md`): v1.1 monetization rework
> (4 passes / 9 products, all ids **0**), daily/weekly quests + co-play ×1.1 + friend quest, Season 1 track (inactive
> while `Season.StartsAt == 0`), bot Phantom cover acts, save v3 (v2 migrates on load), Quests panel; v1.2 Rising
> Storm escalation, Dawn Rush, Last Stand, manor events, witness tells, Grazed near-miss. Bot-only balance (30 matches):
> **47 % guest wins**. Build label `v1.2`.

> **v1.4 (Oct 30 2026)** — merged from PR #2 (v1.3 season pass premium track) and PR #3 (v1.4 every-session
> skippable intro + deduction fix: night Phantom anonymous, bots unlabelled) plus Hark's review fixes (season
> cosmetics kept in `Owned` and tagged per season, pass gift owned for good, stale-season purchase keeps premium,
> premium XP rounding, tier-sorted reward lines, night Phantom ribbon hidden). All Robux ids still **0**; season
> still unscheduled. Bot-only balance (30 matches): **50 % guest wins**. Build label `v1.4`.

## Streaming + performance budget (v1.0 RC)

`Workspace.StreamingEnabled = true` (both project files): **StreamingTargetRadius 256**, **StreamingMinRadius 96**,
**StreamingIntegrityMode PauseOutsideLoadedArea** (a player whose floor hasn't streamed in is paused, never falls).
The manor footprint is ~180 × 160 studs over 5 levels, so on a normal device the target radius covers most of it;
streaming mainly lets low-memory phones drop far rooms. Key interactables are **Persistent** models that never stream
out: `Map.Manor.Breakers` (+ each `Breaker_*`), `Map.Manor.Lifts`, `Map.Manor.Props` (blueprint cabinets, Projector,
Evidence Board, Exit Console, key pedestals). Clients only reach the map through `FindFirstChild` chains with nil
guards (Minimap, PromptFilter, Guide) and `WaitForChild` for remotes/modules, so a streamed-out room just hides its
minimap dot (chests) until it streams back. Round start asks the client to `RequestStreamAroundAsync` the ballroom
before the teleport. Checked by `verify_place` (workspace settings) and the engine smoke (Persistent groups).

**FPS / part-budget risk:** the built map is **3,537 BaseParts + 3,046 GUI objects** (SurfaceGui art, name plates,
billboards), above the M1.1 budget of 3,000 parts. Only ballroom chandeliers cast shadows, decor is non-colliding,
but Lighting is `Future` and there has been **no real-device test** yet. If a low-end phone drops below ~30 FPS:
first switch Lighting to `ShadowMap`, then cut SurfaceGui art per room (`Config/Decor`), then lower
StreamingTargetRadius to 160. Watch MicroProfiler + Developer Console (Memory → PlaceMemory) on the first phone test.

Roblox target: universe `10773325724`, root place `80777289760756` (Murali's private experience, formerly
"GhostMansionTest", repurposed). **Private. No Robux products.** Never touch universe `10773325904` (Ghost Mansion) —
`scripts/luau_exec.py` refuses it. Build label: workspace attribute `CM_Version` = `M1.1`.

## M1.1 rules and numbers (all in `src/shared/Config/*`, data-driven)

| | M1 | **M1.1** |
|---|---|---|
| Lobby | 30 s | 30 s (min 6 participants, bots fill; max 10) |
| Day / Night | 60 s / 90 s | **150 s / 240 s** (`Config/Nights[1]`) |
| Manor | 1 floor, 10 rooms, 16.6k sq studs | **3 floors, 35 named rooms + 3 stairwells + 3-stop lift, 61.4k sq studs (3.7x)** |
| Breakers | 3 (A–C), 1 tamper/night | **5 on all floors** (A Generator Vault B1, B Clock Workshop G, C Observatory Dome U, D Inventor's Laboratory G, E Telegraph Room U); **2 tampers/night across Phantoms**; Phantom bots tamper any breaker in the **last 40 s** of the day |
| Reboot | 100 % in 72 s; fix by 54 s | **100 % in 200 s** with all online; each tripped breaker removes 1/5 of the rate → downtime budget 200 breaker-s: **one trip must be fixed by 200 s, two by ~100 s each** |
| Repair | 6 s / 3 s with wire | **8 s / 4 s with wire**; brass wrench x0.6; cooperative |
| Chests | 12 of 16 | **28 of 43 spots** (every floor) |
| Lantern | start 20 s, cap 40, 1 s/s, cell +20 | **start 60 s, cap 120, 0.75 s/s, cell +45** |
| Phantom | 21 speed, tag cd 3 s, recoil 1.5 s | **18.5, tag cd 8 s, recoil 4 s** (balance passes 1–3) |
| Wisp | flicker cd 20 s (4 s), slick cd 30 s, 45 s life, x0.7 | **flicker cd 30 s (5 s), slick cd 45 s, 100 s life (max 2 alive), x0.8** |
| Glow-stick | 30 s | 45 s |
| Gear Tokens | 5 + 10 win + 1/chest + 3/repair + 2/tag, cap 40 | **8** + 10 win + 1/chest + 3/repair + 2/tag, **cap 60**. Cosmetic-only plan unchanged, no Robux products |

### Items (`Config/Items`, 9 kinds; caps; per-item server cooldowns)

| Item | Use | When | Effect |
|---|---|---|---|
| Dry-cell (cap 3) | consumed | night | lantern +45 s |
| Copper wire (2) | passive | – | repair 4 s instead of 8 (used up on completion) |
| Glow-stick (3) | consumed | night | drop: Phantoms within 16 studs outlined through walls (45 s) |
| **Brass wrench** (1) | passive | – | repairs x0.6 time (stacks with wire) |
| **Smoke pellet** (2) | consumed, cd 6 s | night | blink up to 12 studs (stops before walls) + smoke cloud + 1.5 s tag immunity |
| **Pocket watch** (1) | kept, cd 30 s | day + night | private readout: day = how many breakers were tampered; night = dawn ETA + which breakers are down (%) |
| **Tripwire bell** (2) | consumed, cd 3 s, 1 set per guest | day + night | rings for everyone ("A tripwire bell rang in the Library!") + red minimap ping when an unmasked Phantom passes within 7 studs (150 s life) |
| **Spring boots** (2) | consumed, cd 4 s | day + night | x1.5 speed for 3 s |
| **Clockwork decoy** (1) | consumed, cd 5 s | night | ticking decoy for 10 s: the nearest tag goes to it (Phantom loses its cooldown), Phantom bots are lured within 45 studs |

Loot weights: cell 28, wire 15, glow 11, wrench 8, smoke 10, watch 6, bell 8, boots 8, decoy 6. Everyone loots the
same table and item counters are public for everyone, so a Phantom's decoy loot never reveals it; anyone who
**looks like a guest** (a Guest, or a Phantom by day) may use the items allowed in that phase. Server checks: item id is
a known string, phase, state, count, per-item cooldown, plus the global Action limiter (8 burst, 6/s).

Interpretation notes (unchanged from M1): Wisps help the Phantoms; reaching 100 % ends the night at once; an
unfinished night is a Phantom win in M1.x.

## Map (Sterling Manor, 3 levels; `Config/Manor` + `Logic/ManorLayout`)

Rooms are rectangles per level (LevelHeight 20, RoomHeight 16, DoorHeight 12); doors join rooms on a shared edge at
a level. **Ground**: Grand Ballroom (2 storeys, spawn ring), Foyer, North/West/East Corridors, Library, Billiard Room,
Music Room, Inventor's Laboratory, Dining Hall, Kitchen, Map Room, Clock Workshop, Conservatory, Greenhouse.
**Upper**: Gallery Balcony (inside the ballroom's upper half, brass railing), Portrait Hall, West/East Landing,
Observatory Dome, Telegraph Room, Clocktower Loft, West/East Guest Suite, Drafting Room, Trophy Room, Tea Salon,
Clock Mezzanine, Linen Room. **Basement**: Steam Corridor, Wine Cellar, Boiler Room, Generator Vault, Coal Store,
Laundry. **Connections**: West + East Grand Stair (ground↔upper), Service Stair (basement↔ground), Service Lift
(3 stops; "Up/Down" prompts) → every floor has loops, no dead-end floors. 64 doors, each with a brass name plate on
both faces ("LIBRARY / GROUND FLOOR", "WEST GRAND STAIR / UP TO UPPER FLOOR"). Room dressing kits (shelves,
billiard table, piano, tesla coil, globe, telescope, beds, barrels, boiler, dynamos, …) are non-colliding so walkers
and bots never snag. **2,214 map parts** (budget < 3,000); only the ballroom's chandeliers cast shadows (mobile).

**Z-fighting fix (playtest bug)**: all static geometry comes from `ManorLayout.geometry` — N/S walls run the full side
and W/E walls butt-join between them (no overlapping corner columns), floor/ceiling slabs are inset to the walls'
inner faces, trim (dado rail 0.2 deep, crown 0.3 deep) sits ON the inner face and stops short of perpendicular
trim and door frames, door posts/lintels/plates protrude by different amounts (0.10 / 0.08 / 0.15), chest bands start
0.05 above the floor, gear teeth are thinner than their discs, lobby rails butt-join. `Logic/Coplanar` flags any two
same-facing faces in one plane (±0.01 studs) that overlap, and any SurfaceGui/Decal face touching another face; it
runs on the pure geometry (unit spec), on every anchored part of the built map (engine smoke: 2,054 boxes, 0
problems) and in the real engine (cloud boot check).

## Navigation + bots

`ManorLayout.route(M, from, to)` runs Dijkstra on a portal graph (door points, stair foot/head points, lift stops)
weighted by walking distance and returns `{x, y, z, lift?}` waypoints. Bots (`BotService` + pure `Logic/BotBrain`)
walk them with `Humanoid:MoveTo` (y-aware), ride the lift through `LiftService.ride`, hop when stuck. Brains are
level-aware (flat distance + 2.5 per stud of height) and use items: guests smoke-blink / decoy / boots away from a
close Phantom, set bells at breakers, check the watch, boots to far goals; Phantom bots blend in with day items and go
for decoys.

## Phone-first HUD

`Logic/HudLayout` computes every rect: role chip, **3x3 item chips** (selected one outlined), phase timer pill top
centre, objective, reboot meter, toasts, **minimap (top right, 112 px on phones)** = north-up plan of your floor with
your room lit, breakers green/red, objective dot, red ping when a bell rings, your heading needle; **compass** under it:
needle (relative to your camera) to the NEXT waypoint of the route to your objective (so it points at the right
staircase), objective name + "273 m - GO DOWN". Buttons (max 3, left of Roblox's jump button): guest night
**LAMP · USE <item> · NEXT**, day **USE · NEXT**, Phantom **TAG**, Wisp **FLICKER · SLICK**. A low lantern pre-selects
the dry-cell. Keys: F lantern, V use, B next, C cell, G glow, Q tag, Z flicker, X slick, E/R lift. Layout renders
(rects, not device screenshots) in `../shots/m1.1/`.

## Code layout

```
src/shared/Config   Match, Nights, Gadgets, Items, Manor, Style, Lighting, Audio, Bots, Billboards, DataTemplate
src/shared/Logic    Roles, Lantern, Grid, Outcome, Loot, Cooldown, Channel, Rewards, SaveData, ManorLayout, Coplanar,
                    BotBrain, HudLayout, RateLimiter   (pure, no requires — unit-tested under Lune)
src/server          MatchService (state machine, 10 Hz tick, remotes), Participants (players + bots behind one
                    record), ManorBuilder, LightingService, ChestService, GridService, LanternService, ChaseService,
                    ItemService, LiftService, BotService, DataService, Net (remotes + rate limits), Clock, Build
src/client          init (buttons/keys, lantern aim), Hud, Minimap (minimap + compass), State, PromptFilter, SoundManager
```

Remotes: `Action(kind, arg)` (lantern / use itemId / cell / glow / tag / flicker / slick / lift level / cancel /
whoami; 8 burst, 6/s),
`Aim(x, y, z)` (20 burst, 15/s), `Notify(payload)` server → client (toast, sfx, role, channel, results). Public state is
attributes: workspace `CM_Phase`, `CM_PhaseEndsAt`, `CM_Reboot`, `CM_Tripped`, `CM_Night*`, `CM_Guests*`,
`CM_Winner/Reason`, `CM_BellAt/Time`, `CM_Version`; per player/bot `PState` (a Phantom shows `Guest` by day), one
count per item id, `ReadyAt_<item>`, `Battery`, `LanternOn`, `ImmuneUntil`, `BoostUntil`, cooldown `*ReadyAt`. A Phantom's tamper channel is only told to that player.

## Tests

```sh
./scripts/test.sh     # syntax (69 files), 59 unit specs (Lune), rojo build x2, place verify (55 checks),
                      # engine smoke (21 steps), stylua check (non-fatal)
BAL_ROUNDS=30 .tools/bin/lune run scripts/engine_smoke.luau build/ClockworkMasquerade.rbxl   # bot balance sim
```

Engine smoke (`scripts/engine_smoke.luau`, Lune + shims): builds the 3-floor manor (part budget, 5 breakers on 3
floors, 3 lift stops, 128 plate GUIs), **z-fight scan of every anchored part**, a full real-length round with
1 human + 5 bots (Lobby → Day 150 → Night 240 → Results → Lobby, role privacy, 28 chests, 2 tampers), staged rules
(chests per floor, tamper channel + 2/night + floor check, lantern slow + no beams through floors, wire/wrench/coop
repair, every item by day and night incl. disguised-Phantom use, smoke immunity, decoy taking a tag, bell ringing,
lift rules, tag → bubble → wisp, slick cap, remote validation, both win paths), N full-length bot-only rounds
(asserts all 3 floors visited and ≥ 4 item kinds used), HUD layouts on 780×360 / 891×411 / 2340×1080 / 1024×768 /
1366×768, HUD states (USE/NEXT cycle, item chips, disguised Phantom, minimap floor + lit room, compass
"BREAKER A / 273 m - GO DOWN" from the Library), prompt filter, music hand-over.

Cloud (Open Cloud Luau Execution; key injected on the wire as `ROBLOX_API_KEY`):

```sh
export ROBLOX_UNIVERSE_ID=10773325724 ROBLOX_PLACE_ID=80777289760756
python3 scripts/luau_exec.py build/ClockworkMasquerade.rbxl tests/run.server.luau     # all specs incl. ProfileStore engine spec
python3 scripts/luau_exec.py build/ClockworkMasquerade.rbxl tests/boot_check.server.luau
python3 scripts/luau_exec.py --no-wait build/ClockworkMasquerade.rbxl tests/bots_check.server.luau   # ~95 s, then --resume <task> <place> <script>
python3 scripts/luau_exec.py build/ClockworkMasquerade.rbxl tests/audio_check.server.luau
python3 scripts/luau_exec.py --publish build/ClockworkMasquerade.production.rbxl tests/boot_check.server.luau  # private test publish
```

Luau Execution sessions don't run the place's Scripts (checks replay `init.server.luau`) and don't step physics (bots
hop between waypoints there; real servers walk). HTTP 409 = place open in Studio / Team Create: the script waits 60 s
and retries 5×.

## Studio settings to set by hand (scripts can't)

Max Players **10**; Enable Studio Access to API Services (to test saves in Studio); keep the experience **Private**
until Gate 6; rename the experience from "GhostMansionTest" when Murali wants.

## Status

**Oct 30 2026 — v1.4**: local 94/94 specs, place verify 56/56, engine smoke 0 failures (new: premium XP, season
rewards kept, pass gift + stale-season receipt, anonymous night Phantom, no [BOT] tags); balance 30 bot matches
15/30 = 50 % guest wins. Cloud (universe 10773325724 only): 95/95 specs, boot OK (v1.4), real-engine bot match OK,
audio 25/25. **Published privately as place version 15**; universe read back PRIVATE. Quests mock-ups: `../shots/v1.4/`.
Known flake: the 1-human smoke match occasionally misses "nobody reached level 2" (random bot routes; passes on rerun).

**Oct 30 2026 — v1.2**: local 88/88 specs, place verify 56/56, engine smoke 0 failures (incl. v1.1/v1.2 step:
v2→v3 migration, quests, season, starter/season receipts, manor events; Quests panel gamepad + live refresh);
balance 30 bot matches 14/30 = 47 % guest wins. Cloud (universe 10773325724 only): 89/89 specs, boot OK (v1.2),
real-engine bot match OK, audio 25/25. Layout mock-ups from the real rects: `../shots/v1.2/`.

**Oct 29 2026 — v1.0 RC**: StreamingEnabled + Persistent interactables, CREDITS, store kit; local 72/72 specs,
engine smoke 0 failures. Cloud (Open Cloud Luau Execution, universe 10773325724 only): 73/73 specs, boot OK
(v1.0-rc1, StreamingEnabled true, 3,537 parts, 3,235 boxes z-fight free), real-engine 3-night bot match OK (4/5 floors,
11 lift rides, 18 items used), audio 25/25. **Published privately as place version 10**; experience visibility read
back as PRIVATE. Store kit in `../store/` (mirrored to `docs/store/` on GitHub).

### Oct 28 2026

M1 built, tested, published (place v5) and playtested by Murali. **M1.1** (this version): local 59/59 specs + 21/21
smoke steps, 0 z-fight faces; cloud 60/60 specs, boot OK (real-engine z-fight scan clean), real-engine bot round OK
(3/3 floors, lift rides, items), audio 14/14; published privately as **place version 8** (experience still PRIVATE).
Bot-only balance after 3 tuning passes: **guest win ~20 % (13/66)** — below the 40–50 % target, see milestones.
Next: Gate 3 phone playtest of M1.1, then M2.
