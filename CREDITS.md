# Credits — The Clockwork Masquerade: Mystery at Sterling Manor

Original concept and game design: **Murali Dhara Sudhan (Ottran Studios)**. All game code in
`src/`, `tests/` and `scripts/` was written for this project (Oct 2026).

## Third-party code (vendored, license-compatible)

| Component | Use | License |
|---|---|---|
| [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) by MadStudioRoblox (`vendor/ProfileStore.luau`) | session-locked DataStore saves | Apache-2.0 (`vendor-licenses/ProfileStore-LICENSE.txt`) |

## Reused from Ottran Studios' own Ghost Mansion repo (same author, not third-party)

`scripts/luau_exec.py` (itself modelled on [Roblox/place-ci-cd-demo](https://github.com/Roblox/place-ci-cd-demo), MIT —
rewritten, stdlib only), `scripts/check_syntax.luau`, `tests/framework/TestRunner.luau` (TestEZ-style API, written from
scratch; TestEZ is Apache-2.0, no code copied), `tests/run.lune.luau`, `tests/run.server.luau`,
`tests/audio_check.server.luau`, `src/shared/Billboard.luau`, `src/shared/Logic/RateLimiter.luau`, the engine-smoke
shims, the fallback bot rig, and the phone-HUD lessons (stud-sized billboards with MaxDistance, small top-centre timer
pill, buttons clear of the touch jump button).

## Research (ideas only — no code copied)

Engineering rule: research maintained, clearly licensed open-source projects before building unfamiliar parts.
Searched GitHub on Oct 28 2026 for Roblox round / asymmetric-chase / hidden-role systems:

| Project | License | What we compared | Taken |
|---|---|---|---|
| [tralfa42real/roblox-round-framework](https://github.com/tralfa42real/roblox-round-framework) | MIT | server-owned match state machine (lobby → intermission → in-round → post-round), pluggable win-condition evaluator, safe client snapshots, rate-limited remotes | idea: one server state machine, win check as a pure evaluator (`Logic/Outcome`), clients only get snapshots (attributes) |
| [oh-ashen-one/roblox-infected](https://github.com/oh-ashen-one/roblox-infected) (README) | MIT | hidden-infection round game with bots, server-authoritative remotes, ProfileStore, pure unit-tested modules | idea: hidden role never replicated (we send the role only to its owner), bots through the same server paths |
| [frizzysx/RobloxRoundFramework](https://github.com/frizzysx/RobloxRoundFramework) | MIT | configurable intermission/round timers, min players | idea: durations + minimum in config |
| [DennisCalvert/Roblox-Forsaken-Style-Game](https://github.com/DennisCalvert/Roblox-Forsaken-Style-Game) | (none stated) | DbD-style killer/survivor objectives | ideas only, license unknown → nothing used |
| [CodeBotsStudio/Dysymmetrical](https://github.com/CodeBotsStudio/Dysymmetrical) | custom (credit + keep print calls) | asymmetric engine | not used (attribution terms we don't want in a shipped game) |

### M1.1 research (Oct 28 2026): minimap, large-map / multi-floor bot navigation, item systems

| Project | License | What we compared | Taken |
|---|---|---|---|
| [ReelPlum/Frederikhomes-Minimap](https://github.com/ReelPlum/Frederikhomes-Minimap) ("Plum's minimap", DevForum) | MIT | ViewportFrame minimap (clones the map into a viewport, rotating, border-snapping blips) | not used: cloning 2,000+ parts into a ViewportFrame is heavy on phones; we draw room rectangles from data as 2D Frames instead (idea: blips + heading) |
| [ShouxTech/roblox-minimap](https://github.com/ShouxTech/roblox-minimap) | none stated | TypeScript minimap with markers | license unknown → nothing used |
| [Roblox creator-docs: ViewportFrame](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/viewport-frames.md) | CC-BY-4.0 docs | when a ViewportFrame minimap is appropriate | informed the choice above |
| [ahmicy/simplepath](https://github.com/ahmicy/simplepath) | MIT | PathfindingService wrapper for humanoid NPCs | not used: Luau Execution sessions do not step physics and our map is authored rectangles, so an explicit portal graph is cheaper and testable under Lune |
| [Daemon6109/AStarPathfinding](https://github.com/Daemon6109/AStarPathfinding), [Elmuti/PfindPlugin](https://github.com/Elmuti/PfindPlugin) | MIT / none stated | node-graph A* over hand-placed nodes | idea only: our `ManorLayout.graph` = door, stair foot/head and lift nodes with Dijkstra on walking distance (written from scratch) |
| [ProtonDev-sys/StridePath](https://github.com/ProtonDev-sys/StridePath), [imezx/JPSPlus](https://github.com/imezx/JPSPlus) | none stated / LGPL-3.0 | cached nav-grids, jump point search | not used (grid not needed; LGPL not wanted in a shipped game) |
| [tralfa42real/roblox-secure-inventory-system](https://github.com/tralfa42real/roblox-secure-inventory-system) | MIT | server-authoritative inventory: argument validation, per-player rate limits, item registry | ideas: one item registry (`Config/Items`), server validates id/phase/state/count/cooldown, generic Action rate limit |
| [Zyn-ic/Stoway](https://github.com/Zyn-ic/Stoway) | MIT | data-driven inventory/hotbar | idea: item definitions drive the HUD (short label, colour chip) |

### v1.0 research (Oct 28–29 2026): docs, purchases, saves, input, cutscenes, rounds, streaming

Ideas and API guidance only — **no code copied** from any project below. All are credited because they shaped how
v1.0's systems were designed.

| Source | License | What we compared | Taken |
|---|---|---|---|
| [Roblox/creator-docs](https://github.com/Roblox/creator-docs) (Roblox Creator Documentation) | CC-BY-4.0 (docs), MIT (code samples) | Instance streaming (`StreamingEnabled`, `ModelStreamingMode`, `RequestStreamAroundAsync`), `MarketplaceService.ProcessReceipt`, badges, ContextActionService, GuiService safe area, Open Cloud Luau Execution + place publishing | API usage and the streaming / purchase / safe-area patterns; text paraphrased, not copied |
| [Corecii/PurchaseProcessor](https://github.com/Corecii/PurchaseProcessor) | MIT | idempotent developer-product receipts (record the purchase id in the player's save before granting, return `PurchaseGranted` only after a save) | idea: `ShopService` grants a receipt once, keyed by `PurchaseId` in save v2 |
| [nezuo/spark](https://github.com/nezuo/spark) | MIT | input-action mapping across keyboard / gamepad / touch with device-aware glyphs | idea: one action map (`client/Input`) that both keyboard and gamepad bind to, glyph per active device |
| [AdamMillsy/Inputter](https://github.com/AdamMillsy/Inputter) | MIT | multi-device input abstraction, last-input-type switching | idea: switch HUD glyphs on the last input type |
| [bstummer/CutsceneService](https://github.com/bstummer/CutsceneService) | MIT | scripted camera cutscenes with easing, skippable | idea: intro = list of camera shots with eased pans + skip binding (`client/Intro`) |
| [tralfa42real/roblox-round-framework](https://github.com/tralfa42real/roblox-round-framework) | MIT | server-owned round state machine (see M1 table above) | extended to the 3-night flow (Day → Night → Dawn → … → Showdown → Overdrive → Results) |

Licences: the MIT projects above require the copyright notice only when code is copied; none was, but each is listed
here as a courtesy. Creator Documentation is CC-BY-4.0 © Roblox Corporation.

The z-fighting detector (`Logic/Coplanar`) and the wall/trim layout rules were written for this project.

## Audio

Only ids already verified in Ghost Mansion (free Roblox-licensed library: APMOfficial music, Roblox UI sounds) and
re-verified in this place by `tests/audio_check.server.luau` (14/14 OK, Oct 28 2026):
Sneaky Ghost 1837467266 (lobby/day), Stalking the Prey Main 1835183577 (night), Hollow Gong 1845411462, Gong 1846269128,
Thermals (sting) 1837718092, Octagon (sting b) 9042217497, Twinkle (a 30) 1840004224, Victory Fanfare Sting 1836473398,
For Whom The Bell Tolls (B) 1840410813, Roblox_UI_Sweep 15675046931, Roblox_UI_Small_Click 15675032796,
Roblox_UI_Whoosh_03 15674975792, CoinTransfer_01 127645268874265. Nothing uploaded, nothing bought.

## Art

All geometry is parts built by script (`src/server/ManorBuilder.luau`, `ManorDecor.luau`). **No Creator Store models
in v1.0.** A shortlist of candidate free models (to vet before any use) is in `../store/creator-store-shortlist.md`;
anything adopted later gets a row here with its creator and asset id.

Store icon / thumbnail concepts in `../store/` were generated for Ottran Studios with an image model (Oct 29 2026);
they are concepts, not final art.

## v1.1 / v1.2 systems (Oct 30 2026) — ideas compared, no code copied

Quests, the season track, manor events and Rising Storm escalation are written from scratch for this repo. Before
integrating them we compared approaches in:
- **prooheckcp/RoQuest** (Apache-2.0) — Roblox quest framework: server-owned quest state, objective counters per stat,
  daily/weekly resets. Our `Logic/Quests` keeps the same "stat → counter → complete once" shape, but deterministic
  per-day rotation instead of per-player random rolls.
- **oh-ashen-one/roblox-infected** (MIT) — Rojo/Lune round game with pure, unit-tested quest and season-pass cores on
  ProfileStore; confirmed the "pure logic + Lune specs + per-season save slot" structure.
Nothing from either repository is included.
