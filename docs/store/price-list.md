# Robux price list — **ALL DRAFT** (v1.6.3, Oct 30 2026)

Nothing below exists on Roblox. Creating passes/products and setting prices is **Gate 4** and needs Murali's
explicit yes; Hark never creates, activates or prices them. Every id in `game/src/shared/Config/Monetization.luau`
is `0` (the shop shows "Coming soon" and never opens a purchase prompt). Cosmetic only — nothing gives power
(Gear Tokens only buy cosmetics). Source of truth: `Config/Monetization.luau` (this table mirrors it).

## Game passes (one-time) — 4

| Key (config) | Name | Draft price (R$) | Grants |
|---|---|---|---|
| VIP | VIP Inventor | **199** | Golden Inventor mask, Golden Lantern, Inventor's Comet trail, gold name ribbon |
| VIPPlus | Sterling Founder | **599** | everything in VIP + Founder Clockwork mask, Founder's Halo trail, Founder Salute emote |
| DoubleTokens | 2x Gear Tokens | **249** | double Gear Tokens (tokens only buy cosmetics) |
| Host | Masquerade Host | **129** | Host Laurel mask + Party Whistle emote (for private-server hosts) |

## Developer products — 13 (9 from v1.1–v1.4, **4 new in v1.6.3**)

| Key (config) | Name | Draft price (R$) | Grants | Where it shows |
|---|---|---|---|---|
| StarterPack | Guest's Starter Trunk | **49** | Guest's Welcome mask + Guest's Lamp + 100 Gear Tokens (one per player) | Shop › Robux |
| SeasonWinter | Winter Masquerade Pass | **399** | season premium track + Rime Regent mask at once (hidden until a season is scheduled) | Shop › Robux |
| MaskPackNeon | Neon Carnival Mask | **79** | mask_neon_pack | Shop › Robux |
| LanternPackEmber | Ember Lantern | **79** | lantern_ember | Shop › Robux |
| TrailPackRainbow | Rainbow Gears Trail | **99** | trail_rainbow | Shop › Robux |
| EmotePackParty | Party Emotes (Confetti + Dance) | **49** | emote_confetti, emote_dance | Shop › Robux |
| TokenPouch | Pouch of 100 Gear Tokens | **49** | +100 Gear Tokens | Shop › Robux |
| TokenChest | Chest of 240 Gear Tokens | **99** | +240 Gear Tokens | Shop › Robux |
| **MaskPackReaper** (v1.6.3) | Phantom Regent Mask | **99** | mask_reaper, auto-equipped on purchase | Shop › Robux + Settings › Robux specials (in match) |
| **LanternPackMidnight** (v1.6.3) | Midnight Lantern | **79** | lantern_midnight (navy lamp, violet beam), auto-equipped | Shop › Robux + in-match specials |
| **TrailPackPhantom** (v1.6.3) | Phantom Shimmer Trail | **99** | trail_phantom (Electro-Wisp trail), auto-equipped | Shop › Robux + in-match specials |
| **EmotePackMasquerade** (v1.6.3) | Masquerade Emotes (Teacup Toast + Applause) | **49** | emote_toast, emote_applause | Shop › Robux + in-match specials |

v1.6.3 in-match rules (built in, nothing to set up): bought mid-match the item is granted at once and saved; it is
worn immediately in the lobby or by day, but **never over a Phantom's night shroud** (it goes on at the next dawn) so a
purchase can't reveal who the Phantom is. Phantom-themed items are day/lobby looks only; no per-player Phantom night
form or tag effect is sold (it would out its owner). Purchases are idempotent per PurchaseId (a retried receipt never
grants twice) and a receipt for an unknown/0 id stays unprocessed.

Rationale (unchanged from v1.1): Founder (599) anchors the top so VIP (199) reads mid-tier; single cosmetics 49–99
keep impulse buys cheap; the token pouch saves roughly 5–6 matches of play, a convenience rather than a gate. Free
path: every non-Robux cosmetic is earnable by tokens, levels, the 7-day streak or the free season track.

## Badges — 9 (ids 0; creating badges can cost Robux beyond the free daily allowance = Gate 4)
Welcome to Sterling Manor (suggest renaming to **Welcome to Sterling Castle** when you create it), First Dawn, Masked
Menace, Chief Engineer, Overdrive Master, Detective, Key Keeper, Archivist, Regular Guest. No new badges in v1.6.
