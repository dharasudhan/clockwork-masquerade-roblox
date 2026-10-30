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

## What still needs doing (deliberately NOT code)

1. **Client UI**: quest tab + season track UI in `Menus.luau`. Server already publishes
   `QuestDaily` / `QuestWeekly` / `Season` / `SeasonXP` / `StarterPackBought` attributes and
   `quest` / `seasonTier` Notify payloads — the client just renders them.
2. **Studio-side (your checklist)**: rename the experience off "GhostMansionTest", voice chat OFF,
   age questionnaire, real-capture thumbnails, Max Players 10.
3. **Gate 4**: create the 4 passes + 9 products in Creator Hub with the draft prices, paste the
   real ids into `Monetization.luau`, schedule `Season.StartsAt/EndsAt`.
4. **Real-device performance test** before any ad spend — unchanged from the v1.0 risk list.

## New tests
- `tests/specs/Quests.spec.luau` — rotation determinism, apply/complete-once, gains mapping,
  tokensFrom, summary encoding.
- `tests/specs/Season.spec.luau` — window gating, tier math + cap, progress reporting.
- Auto-discovered by `tests/run.lune.luau` (specs are read from the directory).
