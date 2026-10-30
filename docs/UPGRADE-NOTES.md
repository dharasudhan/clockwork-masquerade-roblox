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
  sleeves, a brass gear clasp and two glowing amber clockwork eyes (one PointLight) in front of
  the existing neon Phantom mask. Names, colours, materials and part count never depend on the
  avatar; only the fit scales with the rig (R15, R6, rthro).
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

- `tests/specs/Shroud.spec.luau` (14): classification, undo ledger (exact restore, idempotent
  apply, newest-first undo), uniform look across R15/R6/rthro, part budget, skirt/hood/eye fit.
- `tests/specs/Scatter.spec.luau`: candidate rules, spots in-room / clear of props / resolving
  to that room, B1–2F only, one per room + never the previous room (40 seeds), floor spread,
  deterministic per seed, order-independent, more people than rooms, blackout timing.
- Engine smoke: every Phantom (bots too) shrouded each night; at dawn the shroud stays on until
  the strike and comes off only while the screen is fully black; blackout notify + chime +
  stream request sent; everyone lands in a new, distinct room; a dressed human Phantom (shirt,
  pants, t-shirt, hat, layered jacket, body colours, face, skin texture, trail) and a bot Phantom
  wear identical cloaks, a night respawn re-shrouds, dawn / match end / lobby restore everything
  exactly; client blackout GUI fade. (De-flake: the staged-night step clears a Phantom stun that
  bot Expose votes can cause in the staged day.)
- Cloud: `boot_check` probes R15 + R6 HumanoidDescription rigs (on/off, accessory re-attach) and
  all scatter spots in the real map; `bots_check` asserts the real-rig night shroud and the dawn
  scatter (everyone moved, distinct rooms, shroud gone).
- Test hooks: `MatchService.setScatterEnabled`, `MatchService.setScatterLevels`; smoke env
  `SCATTER=0`, `SCATTER_LEVELS="-1,0,1,2"` for balance experiments.

## Results (Oct 30 2026)

- Local `./scripts/test.sh`: syntax 109 files, **118/118 specs**, place verify 56/56, engine smoke 0 failures.
- Bot balance, 30 bot-only matches each, final config: **33%** (10/30) and **47%** (14/30) guest wins
  (an earlier identical-logic run: 43%); pooled **37/90 = 41%**, inside the 40–50% target.
  Scatter-off control: 43%. Bot-sim noise is about ±9 points per 30-match run.
- Cloud (universe 10773325724 / place 80777289760756 only): 119/119 specs, boot OK (v1.4.1, shroud
  R15+R6 on/off, 156 scatter spots safe), real-engine bot match OK (shroud 15 parts, scatter 6 moved
  into 6 rooms), audio 26/26.
- **Published privately as place version 20** (label v1.4.1); universe read back **PRIVATE**.
- Mock-up: `../shots/v1.4.1/phantom-shroud-day-vs-night.png` (geometry render from `Logic/Shroud.layout`,
  not an in-engine capture).

## Open points / risks

- Body size still differs between avatars (rthro vs classic): the cloak hides outfit and colours
  but not height; forcing scale would change hitboxes, so it was left alone.
- Emote props and a player's own emotes are untouched (voluntary signals).
- Real-device check still needed: the blackout fade on a phone and a console, and the hood/eyes on
  rthro and dynamic-head avatars.
- Night-3 position tells are gone, but a player who watched someone enter a room by day can still
  reason about routes - that is intended deduction.

# Clockwork Masquerade — v1.4 session intro (Oct 30, 2026)

## Every-session story intro

- The story intro now plays at the START OF EVERY SESSION (was: first visit only).
- Still fully skippable on every device: SKIP button, Space / Backspace, gamepad A / B —
  gamepad focus lands on the SKIP button.
- `IntroSeen` is still sent to the server (`introDone`) for stats, but it no longer gates
  the cinematic on the client.
- The guided first match still follows the intro for anyone who has not finished the
  tutorial (`TutorialDone` is checked in the intro callback), so returning players who
  dodged the tutorial in v1.2–v1.3 re-enter the funnel.
- Why: every session opens with the brand and the story premise; skip is one input on
  every device, so retention cost is minimal while the manor's identity stays front-and-
  center (it also re-teaches the witness-tell after updates).
- One-line revert: in `init.client.luau`, restore the `IntroSeen == false` gate in the
  `introChecked` block.

## Deduction leaks fixed (the Phantom was guessable)

Two information leaks made the human Phantom identifiable, so the Expose vote was
degenerating into elimination:

- **Nametag on the transformed Phantom.** The night monster kept the humanoid's floating
  name — a name over the Phantom literally named its account. New `ChaseService.setNameShown`
  hides the nametag at `nightFalls` (both flavours: the Humanoid default tag via
  `DisplayDistanceType = None`, and the bot `NameTag` billboard via `Enabled = false`), and
  restores it at dawn (disguise back on), on `reapply` (respawn), and on match `reset` —
  a hidden name can never leak into the next match.
- **Bots labelled `[BOT]` in-world.** In-world bots read `Name [BOT]` while the vote panel
  listed plain names, so guests cleared every bot from suspicion and the human Phantom was
  the only candidate left by elimination. Bot nametags now show the plain name, exactly
  like human guests. The `IsBot` model attribute stays (server logic only, replicated but
  never rendered) — no brain, vote or stats behaviour changes.

Names stay visible for everyone by day: daytime accusations, the vote panel and the
witness-tell all need referable identity, and a name over a guest is not a leak — it
becomes one only when that character transforms.

Known side effect (intended): guests can now "waste" Expose votes on bots, which is
healthy misdirection — bot suspicion is a feature, not a bug.

## Merge review fixes (Hark, Oct 30 2026)

- Season cosmetics are copied into `Owned` as tiers are reached (free track always, premium track
  with the pass) and every season item carries `season = "winter-masquerade"`, so a later season's
  track reset never takes away an earned or paid-for cosmetic, and a later season's tiers never
  re-unlock winter items (`Progression.seasonRewards`, `Progression.owns`).
- The pass's Rime Regent gift goes into `Owned` (kept for good) as well as being equipped; premium
  rewards for tiers already reached unlock at purchase.
- Buying the pass while the save still carries an older season's id now starts this season's
  track at once (before, the next match end would have wiped the premium flag just paid for).
- `PremiumXpFactor` rounds instead of floors (100 XP gave 114 because 100 × 1.15 = 114.999…).
- Quests panel: reward lines sorted by tier number (string sort put T10 before T3), compact
  `FREE:` / `PASS:` lines with more height (≈15 px text on a 780×360 phone instead of 8–10 px).
- Shop: season items show `TIER n` / `👑 TIER n` and a hint toast instead of `?`.
- The night Phantom's match ribbon is hidden too (the vote panel lists name + ribbon colour, so a
  visible ribbon named the Phantom just like the nametag); restored at dawn / reset.

---

# Clockwork Masquerade — v1.3 season premium track (Oct 30, 2026)

The Winter Masquerade Pass finally has a reason to exist. Until now it set a 👑 flag and nothing
else; this pass makes premium worth 399 R$ while keeping the two hard rules from the v1.1
economy work: **no gameplay power** (symmetric information is the whole game — young Roblox
audiences are pay-to-win sensitive) and **no token stipends** (that would reopen the
undercut-the-2x-pass hole the v1.1 pricing fixed).

## What premium unlocks

1. **Instant purchase reward.** The moment the pass is bought, the buyer gets the **Rime Regent
   mask** granted AND auto-equipped — visible on their character in the lobby or in-match
   (`prod.instantCosmetic` on `SeasonWinter`, applied + dressed in
   `ShopService.processReceipt`). Instant gratification before a single tier is earned.
2. **Premium track cosmetics** (`seasonPremium = true` in `Config/Cosmetics`, gated in
   `Progression.owns` by `data.Season.Premium` on top of the existing tier check):
   - **T1 Rime Regent mask** (the purchase gift, still listed on the track)
   - **T3 Aurora Borealis trail**
   - **T5 Ice Sculpture emote**
   - **T7 Solstice lantern** (gold beam)
   - **T10 Winter King mask** — the season-end flex prize
   - The free track is unchanged: Frost Filigree (t2), Northern Lights (t4), Snowfall (t6),
     Gift Box (t8). The pass accelerates and decorates; it never walls off free rewards.
3. **+15% season XP** (`Config/Season.PremiumXpFactor`, applied in `QuestService.seasonXp`) —
   pass holders reach the same tiers ~13% fewer matches. Grind-shortening only: XP buys tier
   cosmetics, never power.

## What it deliberately does NOT do
- **No token stipend, no token multiplier** — tokens stay earned only through play, or the
  2x pass via the 2x Gear Tokens game pass. A season pass that prints tokens would re-create
  the v1.1 economy bug at 399 R$.
- **No power, no information**: no gadget unlocks, no clue reveals, no Phantom-side perks.
  Every competitive edge stays earned in-match.

## Client
- Quests panel season block now shows **two reward lines**: `FREE TRACK:` (Amber) and
  `PREMIUM TRACK:` (Gold), prefixed 👑 when owned and 🔒 when not. Spacing adjusted so both
  wrapped lines fit above the quest list (portrait + landscape rects unchanged).
- The coming-soon state teases the premium line ("buy the Winter Masquerade Pass when it goes
  on sale") so the track sells itself before the season starts.

## Season rollover note
A pass belongs to the season it was bought for: `QuestService.seasonXp` already resets
`Season.Premium` when a NEW season id arrives (a pre-season purchase pre-fills the id at
receipt time, so it survives the start line). Next season = new pass purchase. Standard
battle-pass convention; document it in the shop description when the real id goes in.

## New tests
- `tests/specs/Progression.spec.luau` — premium gate: pass required even at max tier, pass
  alone not enough (tier still matters), free track unaffected.
- Re-run `./scripts/test.sh` + the bot balance sim; nothing here touches match logic, but the
  suite should stay green before merging.

---

# Clockwork Masquerade — v1.2 gameplay upgrade (Oct 30, 2026)

The engagement pass: makes matches escalate, gives losing sides a comeback, and turns the social
deduction layer into a real information game. All tuning lives in `Config/Escalation` +
`Config/Events` and pure logic under `Logic/` — balance iteration stays data-only.

## Rising Storm (escalation)
- `Config/Escalation.Nights`: night 2 drains lanterns 15% faster (+0.5 Phantom speed);
  night 3 drains 30% faster (+1 Phantom speed, +15% reboot rate). Applied through workspace
  attributes set in `MatchService.beginDay` and consumed per tick by LanternService (drain),
  ChaseService (Phantom speed) and GridService (reboot rate).
- **Dawn Rush**: past 80% reboot the grid fills 25% faster — every night ends in a sprint
  instead of stalling at 95% (`Logic/Escalation.rushBoost` in GridService.step).
- **Last Stand**: at ≤2 surviving guests, they move +2 studs/s and their lanterns burn 15%
  slower. Rubber-banding that manufactures comeback stories (`Logic/Escalation.lastStand*`).

## Manor events (variety engine)
- One event per Day and per Night, fired at a random moment in the 30–70% window:
  **Power Surge** (night; reboot +8%), **Deep Dark** (night; 25 s of 1.5× lantern drain),
  **Clockwork Rush** (day; 20 s of 1.15× speed), **Loose Gears** (day; dry-cell for every guest),
  **Rumor Mill** (day; reveals one Expose clue for free).
- `server/EventService` schedules and fires; timed effects are workspace attributes
  (CM_EventDrain / CM_EventSpeed) the per-tick services already read — no chase-code changes.

## Social deduction juice
- **Witness tells**: a guest within 16 studs of a breaker when it is tampered HEARS it
  (location + moment, no identity — `ExposeService.tampered`). Human Phantoms must now tamper
  unobserved or pocket-watch players will triangulate them; attentive guests get real evidence.
- New `ExposeService.revealOne()` backs the Rumor Mill event.
- The first-visit story intro now teaches the tell: a new shot (`src/client/Intro.luau`) has
  Bellows warn "If you HEAR a breaker die nearby, someone is close! Remember where you stood."

## Chase feel
- **Grazed**: when a Phantom swipe just misses (nearest guest within tag range +3.5), that
  guest gets a rate-limited "claws grazed you" sting — near-misses become heartbeats
  (`ChaseService.tryTag`).

## New tests
- `tests/specs/Escalation.spec.luau`, `tests/specs/Events.spec.luau` (auto-discovered).
- **Re-run the bot balance sim after this patch**: the night-3 reboot boost and Last Stand
  change win rates by design (`BAL_ROUNDS=30 ... engine_smoke.luau`).

---

# Clockwork Masquerade — v1.1 business upgrade (Oct 30, 2026)

Implements the revenue-and-retention changes from the product analysis. Drop the folders in this
archive over your repo (`src/` and `tests/` merge by path; `docs/` is new). Then run the usual
pipeline: `./scripts/test.sh`, `BAL_ROUNDS=30 .tools/bin/lune run scripts/engine_smoke.luau ...`,
then the cloud checks. Save template is v3; existing v2 saves migrate automatically through
ProfileStore `Reconcile` + `SaveData.sanitize` (new keys appear on first load).

## What changed, per file

### Monetization: fixed economy + real catalog (`src/shared/Config/Monetization.luau`)
- **Token economy conflict fixed.** Old TokenPouch: 25 R$ ≈ 150 tokens ≈ 3 matches of play → made
  the 249 R$ 2x Tokens pass worthless. New: Pouch 49 R$ → 100 tokens (~5–6 matches); Chest
  99 R$ → 240 tokens (~20% bonus over two pouches). Buying now saves real grind time.
- **Price ladder with an anchor.** New **Sterling Founder** pass at 599 R$ (VIP set + Founder
  mask/trail/emote) so 199 R$ VIP reads mid-tier. 4 passes, 9 products total (was 2 + 5).
- **First-purchase hook.** Guest's Starter Trunk (49 R$, one-time): welcome mask + lamp + 100
  tokens. Flag `StarterPackBought` hides it after purchase (receipt handler sets it).
- **Private-server lane.** Masquerade Host pass (129 R$) — pair it with a monthly private-server
  subscription in Creator Hub (this is a party game; friend groups pay for their own manor).
- **Season 1.** Winter Masquerade Pass (399 R$) unlocks the premium season track.
- All ids still 0 = disabled; nothing prompts until Gate 4/5 creates the products.

### Quests + social retention (new: `Config/Quests`, `Logic/Quests`, `server/QuestService`)
- 3 daily + 2 weekly quests from rotating pools (deterministic per day/week — everyone shares the
  same dailies). All goals use stats the server already tracks; no new gameplay surface.
- **Co-play bonus**: a match with ≥2 humans pays ×1.1 Gear Tokens (applied after the cap, like
  the 2x pass) — rewards social sessions without needing friendship checks.
- **Friend quest**: "Play 3 matches with a Roblox friend" uses cached `IsFriendsWith` lookups
  (pair cache, cleared daily).
- Wired into `MatchService.endRound` → `QuestService.onMatchEnd` after every match; payouts are
  toast + token grant. Save holds `Quests = { Day, Daily, Week, Weekly }`.

### Season 1 track (new: `Config/Season`, `Logic/Season`)
- "Winter Masquerade": 10 tiers, 250 XP each (a match earns ~10–90 XP), so tier 10 ≈ 10–25
  matches over the season. **Inactive while `StartsAt == 0`** — set the unix-day window at
  Gate 4/5. Season XP accrues in `DataService.award` (lazy require, no load-order risk).
- Tier cosmetics unlock automatically through the existing `Progression.owns` check
  (`seasonTier` field) — no grant code needed. Buying the pass sets `Season.Premium` in
  `ProcessReceipt`.

### Bot Phantoms act suspicious (new: `BotBrain.suspicious`, `Config/Bots.Suspicion`)
- When a bot Phantom has no tamper/trap/loot work left in the Day it now puts on an
  innocent-bystander act instead of idling: shadows a guest at ~11 studs ("bodyguard") or hovers
  near the busiest breaker "watching repairs". One cover act per 8-second window, chosen
  deterministically (unit-testable, no jitter). Gives human guests readable behavior to
  Expose — previously bots only looted chests and never generated clues.

### Cosmetics (new items in `Config/Cosmetics`)
- Season track: Frost Filigree mask (t2), Northern Lights lantern (t4), Snowfall trail (t6),
  Gift Box emote (t8).
- Founder set (VIPPlus), Host Laurel + Party Whistle (Host pass), Guest's Welcome Mask + Lamp
  (StarterPack). All cosmetic-only, as before.

### Rewards (`Logic/Rewards`)
- Optional `coPlay` multiplier parameter (default 1) — signature backwards-compatible.

### Save template v3 (`Config/DataTemplate`)
- Adds `Quests`, `Season`, `StarterPackBought`. v2 saves migrate automatically.

### Quest/season client UI (was the one open dev to-do — DONE on this branch)
- `builders.Quests` in `Menus.luau`: season block (name, tier x/10, XP-to-next bar, 👑 premium
  tag, tier-reward list from `Config/Cosmetics`) + scrolling daily/weekly quest rows parsed from
  the `QuestDaily` / `QuestWeekly` attributes (`id:progress/goal:done`), done rows turn
  TealNeon with a ✔.
- Lobby 📜 QUESTS button (`Hud.luau` + layout rects in `Logic/HudLayout.luau`, portrait and
  landscape) and a Settings entry; gamepad-navigable like every other panel.
- `init.client.luau`: the `quest` Notify payload now toasts "✔ <text> +N ⚙" and `seasonTier`
  fires a "❄️ SEASON TIER N!" banner pointing at the Quests panel.
- Studio check: quest rows only refresh when the panel reopens (no live ticker) — fine for a
  lobby panel; eyeball the season block spacing on a portrait phone.

## What still needs doing (deliberately NOT code)

1. **Studio-side (your checklist)**: rename the experience off "GhostMansionTest", voice chat OFF,
   age questionnaire, real-capture thumbnails, Max Players 10.
2. **Gate 4**: create the 4 passes + 9 products in Creator Hub with the draft prices, paste the
   real ids into `Monetization.luau`, schedule `Season.StartsAt/EndsAt`.
3. **Real-device performance test** before any ad spend — unchanged from the v1.0 risk list.

## New tests
- `tests/specs/Quests.spec.luau` — rotation determinism, apply/complete-once, gains mapping,
  tokensFrom, summary encoding.
- `tests/specs/Season.spec.luau` — window gating, tier math + cap, progress reporting.
- Auto-discovered by `tests/run.lune.luau` (specs are read from the directory).
