# The Clockwork Masquerade: Mystery at Sterling Manor — GDD v0.1 (MVP)

Gate 1 approved by Murali Oct 28 2026 ("do this" on the 3-night MVP cut). Original concept by Murali.
Separate Roblox experience (not a Ghost Mansion mode). Secular 1920s inventor / steampunk-neon theme. Family-safe.

## Pitch
Asymmetric chase with light sabotage. Guests repair Sterling Manor's grid across 3 nights; 1-2 Anomaly Hosts (Phantoms) hide among them by day and hunt by night. Tagged guests become Electro-Wisps and keep playing.

## MVP scope (v1)
- Players: 8-10 per server (config), bots fill to minimum 6. Phantoms: 1 per 5 players (1 at <=6, 2 at 7-10).
- Match: lobby 30 s -> 3 nights -> results. Target 8-9 min.
  - Day 60 s (sabotage/scavenge) -> Night 90 s (chase). Night 3 finale: Showdown 90 s + Overdrive 120 s.
- Nights:
  1. **Main Breaker Tripped** — Day: guests scavenge dry-cells, copper wire, glow-sticks from chests; Phantoms channel 4 s to tamper with 1 of 3 breaker terminals. Night: violet emergency light; guests group and focus lantern beams to slow Phantoms; tag = Energy Bubble -> Wisp.
  2. **Blueprint Archives** — library unlocks. Day: collect 3 blueprint pages; Phantoms trap cabinets (alarm + ink screen splash). Night: Phantoms get Phase Glide (short blink through wooden doors); guests slot pages into projector -> light barrier zone that repels Phantoms.
  3. **Dawn Reboot (finale)** — Showdown (open, no disguise): find 3 Master Override Keys (Clockwork Engine, Attic, Greenhouse) -> Exit Console. Overdrive: hold Console Activation Ring for 45 s cumulative while Phantoms get speed + telegraphed Shockwave Dash; central dynamo hazard.
- **Expose (new)**: during Day, any guest can accuse once per day at an Evidence Board; a correct accusation stuns that Phantom 5 s at night start and reveals them; wrong one costs the accuser their sprint for the night. Sleuth (later) gets evidence to make it informed.
- **Classes at launch**: Mechanist (repair 50% faster; Spring Barricade 30 s), Illuminator (battery drains 40% slower, wider cone; Strobe Flash 60 s, 2 s freeze). Later: Sleuth (needs Expose), Caretaker.
- **Electro-Wisps** (simple): flicker a room's lights (cooldown 20 s), drop an oil slick (cooldown 30 s, max 2 per Wisp alive). No darts in v1. Wisps can't tag.
- Win: Survivors = reboot reaches 100% (gates open, sunrise, Phantoms turn into soot-covered guests). Phantoms = all guests tagged before reboot.
- Rewards: Gear Tokens (soft currency), badges "Chief Engineer" / "Overdrive Master", saved Wins per side.

## Monetization (Gate 4 before any Robux product)
Cosmetic only: lantern skins and beam colours, Phantom forms, tag-bubble effects, trails, emotes. Never gadgets or stats. Battle pass / seasonal masks later.

## Tech
- Same pipeline as Ghost Mansion: Rojo + Luau, pure Logic modules + specs, Open Cloud Luau Execution tests on a test place, bots for fill/testing, ModelLoader for owned Creator Store models.
- One manor map; nights toggle lighting presets, unlock zone doors, swap effects. Server authoritative tags, cooldowns, channel timers.
- Mobile-first HUD (lessons from Ghost Mansion: billboards in studs + MaxDistance, phone UIScale, timer pill top centre).
- Visual identity must differ from Ghost Mansion: brass/copper/teal/neon, no ghost sprites.

## Later updates (weeks 3-6 drops)
Night "Static Surge" (prism mirrors, tilting floors, Wisp darts), Night "Gravity Calibration" hard mode, Sleuth + Caretaker, 14-player mode if lobbies fill.

## Risks
Lobby fill (bots mitigate), chase balance (needs real-player playtests), snowball (Wisp caps), phone controls.
