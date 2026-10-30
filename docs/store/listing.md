# Store listing kit — The Clockwork Masquerade (DRAFT, v1.6.3, Oct 30 2026)

Everything here is a draft for Murali. Nothing has been entered on Roblox. The experience stays **Private** until
Murali explicitly approves going public (Gate 6). Build on the private place: **v1.6.3, place version 23**.

## Game name (v1.6)
Since v1.5.1 the game is set in **Sterling Castle** (not Sterling Manor): the title board reads "Mystery at Sterling
Castle", Bellows opens the intro with "Welcome to Sterling Castle!", and the terrace gatehouse sign says "CASTLE
STERLING". (Both word orders appear in-game on purpose: "Sterling Castle" as the name, "Castle Sterling" on the
gate sign and the doors banner. Use **Sterling Castle** everywhere in the store.) Code ids and comments still say
"manor"; players never see those.

## Title (48/50 characters)
**Clockwork Masquerade: Mystery at Sterling Castle**

The full "The Clockwork Masquerade: Mystery at Sterling Castle" is 52 characters, over Roblox's 50, so the leading
"The" is dropped. Discovery tiles show roughly the first 30 characters ("Clockwork Masquerade: Mystery…"), which still
reads well.

## Description (981/1000 characters) — paste exactly

```
Someone at the masquerade is not who they seem!

Professor Sterling's clockwork castle is going dark, and masked Phantoms hide among the guests. By day, explore and open chests for gadgets while the Phantoms secretly tamper with the breakers. By night, fix the power before dawn as the Phantoms hunt. Tagged guests become Electro-Wisps and keep playing.

• 3 nights: Main Breaker Tripped, the Blueprint Archives and the Dawn Reboot finale
• 5 floors and over 40 rooms, from the Boiler Level and the Grotto Baths to the Tower
• Vote at the Evidence Board to expose a Phantom
• 9 gadgets and 2 classes: Mechanist and Illuminator
• Quests, levels, login rewards and an all-time Hall of Fame
• Earn Gear Tokens by playing to unlock masks, lanterns, trails and emotes

Optional Robux items are cosmetic only and never change gameplay.

Up to 10 players; bots fill empty seats. Phone, tablet, PC and console.

A family-friendly mystery: no blood, no jump scares.

Made by Ottran Studios.
```

Accuracy notes (why each line is true today):
- "3 nights … finale": Config/Nights names. "5 floors and over 40 rooms": 45 named rooms that are not stairs, lifts or
  balconies (56 map rooms in all), Grotto Baths new in v1.6.2.
- "9 gadgets": Config/Items (dry cell, glow stick, smoke pellet, spring boots, clockwork decoy, tripwire bell, pocket
  watch, copper wire, brass wrench).
- "Hall of Fame": lobby board, top 10 all-time match wins (v1.6.1).
- "Optional Robux items are cosmetic only": every pass/product grants cosmetics or Gear Tokens (tokens only buy
  cosmetics); none exists on Roblox yet (all ids 0 = "Coming soon"). If Murali never creates any, this line can stay
  (it promises nothing) or be removed.
- "Up to 10 players": **set Max Players to 10 first** (the place is still 8; see the checklist). Bots fill to 6.
- Badges are not mentioned on purpose: none exists on Roblox yet. Add "and badges" to the quests line once they do.

## Genre / tags
- Genre: **Party & Casual** (subgenre if offered: **Social Deduction**).
- Devices: Phone, Tablet, Computer, Console. **VR: off** (not tested; still ON in settings).
- Max players: **10** (place currently **8**).

## Icon — upload `v1.6/icon_512.png` (1024 master: `v1.6/icon_1024.png`)
Murali's v1.6 icon: brass clockwork masquerade mask with a teal eye, hooded Phantom with amber eyes, castle clock tower
at night, no text. Use `v1.6/icon_512.png` in Creator Hub (Roblox asks for 512×512); keep `icon_1024.png` as the master.
The old v1.0 concept `icon_512.png` in this folder is superseded.

## Thumbnails
1. `thumbnail_1_1920x1080.png` and `thumbnail_2_1920x1080.png` — v1.0 generated key art ("manor" era). Still fine as
   mood art, but the building now has a castle crown; pair them with real captures.
2. To capture in-game (Studio, HUD off, Graphics 10): the castle facade + gatehouse at dusk; a night lantern chase in
   the Royal Library; the Evidence Board vote; the Grotto Baths; the Hall of Fame board.
Roblox requires thumbnails to represent the actual experience — don't ship generated art alone.

## Content maturity questionnaire — notes (Murali answers it himself)
- Violence: **mild / cartoon** — Phantoms "tag" guests (no weapons, no damage, no blood); tagged guests turn into
  glowing wisps.
- Blood / gore: **none**. Fear: **mild suspense** (dark rooms at night, lantern light, a 2 s clock-strike blackout at
  dawn); no jump scares, no ghosts.
- **New in v1.6: Grotto Baths** — a shallow indoor wading pool (decor only: nobody swims, drowns or changes clothes;
  avatars just walk through ankle-deep water). Nothing romantic or suggestive; no swimwear is applied to avatars.
- Alcohol: the B1 **Wine Cellar** (barrels and wine racks, set dressing, nothing consumed) is the only reference. v1.6
  renamed the new emote from "Crystal Toast 🥂" to "Teacup Toast ☕" so no purchasable item shows alcohol. If the
  questionnaire's alcohol question would raise the label, rename the room to "Pantry Cellar" (one line in
  `Config/Manor.luau`) before answering.
- Gambling / paid random items: **none** (chests are free in-match loot; no loot boxes for Robux).
- Social: Roblox default text chat. **Voice chat is ON** on the experience — recommended OFF for a family audience.
- User creation / UGC: none. Purchases: optional cosmetic passes/products (after Gate 4).
- The Hall of Fame shows players' Roblox display names (already filtered by Roblox), top 10 only.
