# Release checklist for Murali — The Clockwork Masquerade v1.6.3 (Oct 30 2026)

State today: build **v1.6.3** published privately to place `80777289760756` (universe `10773325724`) as
**place version 23** (Published; 21–22 were Saved test uploads). Experience visibility read back via Open Cloud
v2: **PRIVATE**. Experience still named "GhostMansionTest", voice chat ON, server size 8. Code: private GitHub
`dharasudhan/clockwork-masquerade-roblox`. Hark does none of the steps below without your explicit yes; the ones
marked **[you]** are done by you in Creator Hub / Studio.

## 1. Play it on a real phone first (Gate 3)
- [ ] [you] Join from the Roblox app on your phone (private experience: only you / your group can join).
- [ ] Check: intro + tutorial readable in portrait and landscape, buttons clear of the jump button, FPS feels
      smooth in the Ballroom and the Boiler Level, lift and stairs work, the Tower is reachable.
- [ ] v1.6: the story intro now plays **when the lobby countdown ends** (full on your first match, a 3 s card after);
      the round starts when everyone has watched/skipped it (45 s cap). Check it feels right with 2+ phones.
- [ ] v1.6: Settings › **Scoreboard** (Tab / L3 on PC/console) during a match; Settings › **Robux specials** shows
      four "Coming soon" items; the **Hall of Fame** board on the terrace's west rail (fills after real wins); the
      **gatehouse** and the castle crown from the terrace; the **Grotto Baths** (B1, through the Coal Store) — walk
      into the pool, check the water looks right and nothing snags.
- [ ] Open the Developer Console (F9 / chat `/console`): no red errors; Memory → PlaceMemory under ~600 MB on phone.
- [ ] Tell Hark what felt off; balance tweaks are config-only.

## 2. Basic settings (Creator Hub → experience → Configure / Studio → Game Settings)
- [ ] [you] **Rename** from "GhostMansionTest" to **Clockwork Masquerade: Mystery at Sterling Castle** (48/50 chars;
      the version with a leading "The" is 52 and too long). Place name too.
- [ ] [you] **Max Players = 10** (Places → Configure → server size; currently **8**).
- [ ] [you] Description, genre and devices from `listing.md`. Turn **VR off**. Decide **voice chat** (currently ON;
      recommended OFF for a family audience).
- [ ] [you] Upload the v1.6 icon **`store/v1.6/icon_512.png`** (master `store/v1.6/icon_1024.png`; the old v1.0
      `store/icon_512.png` is superseded) and thumbnails — add **real in-game captures**; generated art alone can be
      flagged as misleading.
- [ ] [you] Paste the title + description from `listing.md` (description 981/1000 characters).
- [ ] [you] Enable **Studio Access to API Services** (only needed to test saves in Studio).
- [ ] [you] Turn **Collaborative Editing / Team Create off** or close Studio when Hark publishes (otherwise HTTP 409).

## 3. Age / content questionnaire
- [ ] [you] Creator Hub → Audience → **Maturity & Compliance questionnaire**. Use the notes in `listing.md`
      (cartoon tagging, no blood, mild suspense, no gambling, optional cosmetic purchases). Current label read via
      Open Cloud: **13+** — likely to drop once the questionnaire is done and voice is off.
- [ ] Consider renaming the "Wine Cellar" room to "Pantry Cellar" if the alcohol question would raise the label.
- [ ] v1.6 new content to declare truthfully: the **Grotto Baths** indoor wading pool (decor water, no swimming,
      no swimwear, nothing suggestive); the Hall of Fame shows Roblox display names (top 10). The new emote is
      "Teacup Toast" (was a champagne toast; changed so no purchasable item shows alcohol).

## 4. Badges + Robux products (Gate 4 — your money/decision)
Badges may cost Robux to create beyond the free daily allowance; passes and products need prices. **Hark never
creates or prices these.**
- [ ] [you] Create the 9 badges (names/descriptions in `game/src/shared/Config/Progression.luau` → `Badges`):
      Welcome to Sterling Manor (suggest "Welcome to Sterling Castle"), First Dawn, Masked Menace, Chief Engineer,
      Overdrive Master, Detective, Key Keeper, Archivist, Regular Guest. **No new badges in v1.6.**
- [ ] [you] Create the **4 game passes + 13 developer products** from `price-list.md` (prices are DRAFT — set your
      own). New in v1.6.3: Phantom Regent Mask (99), Midnight Lantern (79), Phantom Shimmer Trail (99), Masquerade
      Emotes (Teacup Toast + Applause) (49).
- [ ] Send Hark the ids (badge ids, pass ids, product ids). Hark pastes them into `Config/Progression.luau` and
      `Config/Monetization.luau`, re-runs tests + cloud checks (purchase flow is idempotent per PurchaseId) and
      republishes privately. Until then every id is `0` = "Coming soon", no prompts.

## 5. Open Cloud key scope
- [ ] [you] Creator Hub → Open Cloud → API keys: give this game **its own key** restricted to universe
      `10773325724` only, scopes: `universe-places:write`, `universe.place.luau-execution-session:write` and
      `:read`; optional `universe:read` (to read visibility). IP restriction optional. Today the key in the vault is
      the one labelled for Ghost Mansion — a game-specific key avoids any risk to the other universe. Save it with
      Hark (Hark Secured Login / vault), never in chat.

## 6. Going public (Gate 5 + Gate 6) — final explicit approval
- [ ] All of 1–5 done; real-device test OK; CREDITS.md complete.
- [ ] Hark republishes the final build privately and re-runs: unit specs, boot check, bot match, audio check
      (v1.6.3 run: 141/141, boot OK, bot match OK, audio 26/26; balance 48 % guest wins over 44 bot matches).
- [ ] **You** say explicitly: "Make The Clockwork Masquerade public." Then **you** set Visibility → Public in
      Creator Hub (Hark never sets an experience public).
- [ ] After launch: watch Analytics (retention D1, session length, errors) and tell Hark what to tune.
