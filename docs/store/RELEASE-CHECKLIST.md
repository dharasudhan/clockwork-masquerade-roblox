# Release checklist for Murali — The Clockwork Masquerade v1.0 (Oct 29 2026)

State today: build **v1.0-rc1** published privately to place `80777289760756` (universe `10773325724`) as
**place version 10**. Experience visibility read back via Open Cloud: **PRIVATE**. Code: private GitHub
`dharasudhan/clockwork-masquerade-roblox`. Hark does none of the steps below without your explicit yes; the ones
marked **[you]** are done by you in Creator Hub / Studio.

## 1. Play it on a real phone first (Gate 3)
- [ ] [you] Join from the Roblox app on your phone (private experience: only you / your group can join).
- [ ] Check: intro + tutorial readable in portrait and landscape, buttons clear of the jump button, FPS feels
      smooth in the Ballroom and the Boiler Level, lift and stairs work, the Tower is reachable.
- [ ] Open the Developer Console (F9 / chat `/console`): no red errors; Memory → PlaceMemory under ~600 MB on phone.
- [ ] Tell Hark what felt off; balance tweaks are config-only.

## 2. Basic settings (Creator Hub → experience → Configure / Studio → Game Settings)
- [ ] [you] **Rename** from "GhostMansionTest" to **The Clockwork Masquerade: Mystery at Sterling Manor** (place name too).
- [ ] [you] **Max Players = 10** (Places → Configure → server size; currently **8**).
- [ ] [you] Description, genre and devices from `listing.md`. Turn **VR off**. Decide **voice chat** (currently ON;
      recommended OFF for a family audience).
- [ ] [you] Upload `icon_512.png` (or the final icon) and thumbnails — add **real in-game captures**; generated
      art alone can be flagged as misleading.
- [ ] [you] Enable **Studio Access to API Services** (only needed to test saves in Studio).
- [ ] [you] Turn **Collaborative Editing / Team Create off** or close Studio when Hark publishes (otherwise HTTP 409).

## 3. Age / content questionnaire
- [ ] [you] Creator Hub → Audience → **Maturity & Compliance questionnaire**. Use the notes in `listing.md`
      (cartoon tagging, no blood, mild suspense, no gambling, optional cosmetic purchases). Current label read via
      Open Cloud: **13+** — likely to drop once the questionnaire is done and voice is off.
- [ ] Consider renaming the "Wine Cellar" room to "Pantry Cellar" if the alcohol question would raise the label.

## 4. Badges + Robux products (Gate 4 — your money/decision)
Badges may cost Robux to create beyond the free daily allowance; passes and products need prices. **Hark never
creates or prices these.**
- [ ] [you] Create the 9 badges (names/descriptions in `game/src/shared/Config/Progression.luau` → `Badges`):
      Welcome to Sterling Manor, First Dawn, Masked Menace, Chief Engineer, Overdrive Master, Detective, Key Keeper,
      Archivist, Regular Guest.
- [ ] [you] Create the 2 game passes + 5 developer products from `price-list.md` (prices are DRAFT — set your own).
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
- [ ] Hark republishes the final build privately and re-runs: unit specs, boot check, bot match, audio check.
- [ ] **You** say explicitly: "Make The Clockwork Masquerade public." Then **you** set Visibility → Public in
      Creator Hub (Hark never sets an experience public).
- [ ] After launch: watch Analytics (retention D1, session length, errors) and tell Hark what to tune.
