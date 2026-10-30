# Clockwork Masquerade — v1.5.1 Castle Sterling (Oct 30, 2026)

The manor gets its castle dress-up (cosmetic only — zero changes to rooms, collision, spawns,
items, breakers or any match logic). Approved direction from Murali's five questions: castle
skin now, swimming pool (Grotto Baths) later as v1.5.4.

## New geometry (all in `server/ManorBuilder.luau`)

- **Flank towers** flanking the facade at x = ±38, z = 62: walnut plinths buried in the lawn,
  cream marble shafts (40 studs, tops at y = 40), walnut parapets and 6 merlons each, plus two
  warm-neon arrow-slit windows facing the terrace.
- **Crenellated parapet** across the portico roofline (58 studs wide at z = 61.9) with 13
  merlons; it seats 0.1 into the column tops (y = 35.5 plane) and the merlons 0.05 into the
  parapet, so no two visible faces share a plane (Coplanar stays clean).
- **Velvet banners** hanging on brass poles between the facade columns (x = ±13.25).
- **Gatehouse** on the terrace's south edge (z = 155): twin towers with plinths, parapets and
  merlons, a connecting arch with 9 merlons and a "CASTLE STERLING / by invitation only" sign
  (SurfaceGui on the arch's north face). The brass rail and invisible boundary pass through
  the towers unchanged — nobody can leave the terrace, nothing spawns or prompts there.
- Part-count: well inside the 6000 budget (engine smoke + boot check assert 300–6000).

## Renames (display only — every room/door id is untouched)

- Dining Hall → **Banquet Hall**, Trophy Room → **Armory**, Library → **Royal Library**,
  Music Room → **Minstrel Hall** (`Config/Manor.luau` room `name` fields; nameplates, HUD and
  minimap read them automatically).
- Objective/guide strings follow: "Projector (Royal Library)" in `Hud.luau`, `Guide.luau` and
  `Config/Nights.luau`.
- Title board line 2: "Mystery at Sterling **Castle**"; intro shot 1: "Welcome to Sterling
  **Castle**!"; build label v1.5.1.
- Left alone on purpose: the "Welcome to Sterling Manor" badge display name in
  `Config/Progression.luau` (badge ids are all 0 until Gate 4/5 — the real name is set in the
  Creator Dashboard when the badge is created) and "Sterling Manor" in code comments.

## Before merge (Murali)

- `./scripts/test.sh`: the Coplanar pass over every part is the one to watch (all new parts
  embed instead of touch); place verify and the engine smoke part budget (300–6000) should
  pass unchanged otherwise.
- Eyeball in Studio: the facade crown + banners from the spawn path, and the gatehouse sign
  from the terrace (it faces the spawn).

---

# Clockwork Masquerade — v1.4.1 night shroud + Dawn Scatter (Oct 30, 2026)

Approved by Murali on Oct 30. Both changes close the last two ways to identify a Phantom by
something other than its behaviour: its own avatar outfit at night, and where it was last seen
when the night ended.

## Night shroud (new: `Logic/Shroud`, `server/ShroudService`)

- At nightfall every Phantom (human AND bot) loses everything that identifies the avatar and
  wears one uniform steampunk cloak instead. By day nothing changes: a Phantom looks like any guest.
- **Hidden / stashed**: Shirt, Pants, ShirtGraphic, every Accessory (hats, hair, faces, layered
  clothing / WrapLayer), BodyColors, R6 CharacterMesh, SurfaceAppearance skins, the face decal
  (and any decal on a body part), avatar trails/sparkles, the bot fallback top hat. Body parts are
  recoloured to the shroud colour and MeshPart skin textures cleared. The lantern lamp shows the
  default brass instead of the owner's lantern skin. (Name tag + ribbon were already hidden in v1.4.)
- **Uniform cloak** (15 primitives, no assets, welded to the body): ball hood that covers the
  face + swept peak, mantle, long skirt to just above the floor, six tattered hem strips, two
  sleeves, a brass gear clasp and two glowing amber clockwork eyes (one PointLight) in front
  of the existing neon Phantom mask. Names, colours, materials and part count never depend on
  the avatar; only the fit scales with the rig (R15, R6, rthro).
- **Reversible**: identifying instances are re-parented to a server-only stash folder
  (`ServerStorage.CM_ShroudStash/<id>`) and every changed property is written to an undo
  ledger; undo replays it backwards. Restored at dawn (inside the blackout, below), at match end
  (`endRound` → `ShroudService.clearAll`, and again in cleanup) and dropped with the old character
  on a respawn; a respawn during the night re-shrouds the new character (`ChaseService.reapply`,
  now called after the lantern is rigged). Applying twice never records the shroud as the
  "original".
- Why not `GetAppliedDescription` / `ApplyDescription`: it yields, loads assets over the network
  and can fail, it does not cover our own cosmetic parts, and it can't run in the headless smoke.
  Real-engine finding: an accessory loses its `AccessoryRigidConstraint` when it leaves the
  character, so the restore re-adds accessories through `Humanoid:AddAccessory`.
- Safe by construction: cloak parts are unanchored, massless, CanCollide/CanQuery/CanTouch off,
  so hitboxes (root distance), raycasts, the lantern, held items and the Phase Glide / Shockwave
  Dash VFX (in `workspace.Effects`) are untouched; they live inside the character model, so they
  stream with it under StreamingEnabled.

## Dawn Scatter (new: `Logic/Scatter`, `client/Blackout`; `MatchService` Dawn phase)

- Two seconds before each dawn interlude ends, the clock strikes: the server sends
  `Notify{kind="blackout"}` + the `ClockStrike` chime (re-used verified Gong 1846269128), every
  client fades to black (0.45 s), holds, and fades back in (0.45 s) as the Day begins. Pure GUI,
  no input: phone, keyboard and gamepad behave the same.
- At 0.8 s — inside the fully-black window on every client, latency shifts the fade and the
  teleport equally — the server takes the shroud off / puts disguises back / wakes Wisps
  (`ChaseService.dawn`) and moves EVERY participant (guests, Phantoms, bots) to a random safe
  spot in a different room. Landing spots are chosen at the strike and pre-streamed with
  `Player:RequestStreamAroundAsync` (StreamingEnabled + PauseOutsideLoadedArea).
- Spot rules: real rooms only (no stairwells, lift cars, balconies, or corridors/landings under
  14 studs), spots inset ≥ 25% from the walls (doorways sit in walls), ≥ 5 studs from chests,
  breaker stand points, keys, projector, and ≥ 6 from the exit console; one person per room while
  rooms last, never the room they stood in, floors interleaved, deterministic per seed. A
  real-engine boot check raycasts a floor under all spots and finds nothing solid where a
  character lands.
- **Balance call (Hark)**: the scatter uses B1, Ground, 1st and 2nd floor but **not the Tower**.
  With the Tower in, 30-match bot sims gave guests 20–30% match wins (a guest stranded in the
  dead-end Tower before the finale); without it 43% (scatter off: 43%).
- Bots drop their route after the move and re-plan from the new room (`BotService.relocated`).
- New workspace attributes: `CM_BlackoutAt`, `CM_BlackoutUntil`, `CM_ScatterAt`, `CM_ScatterMoved`.

## Tests
