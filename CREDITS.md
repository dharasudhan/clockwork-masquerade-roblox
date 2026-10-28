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

## Audio

Only ids already verified in Ghost Mansion (free Roblox-licensed library: APMOfficial music, Roblox UI sounds) and
re-verified in this place by `tests/audio_check.server.luau` (14/14 OK, Oct 28 2026):
Sneaky Ghost 1837467266 (lobby/day), Stalking the Prey Main 1835183577 (night), Hollow Gong 1845411462, Gong 1846269128,
Thermals (sting) 1837718092, Octagon (sting b) 9042217497, Twinkle (a 30) 1840004224, Victory Fanfare Sting 1836473398,
For Whom The Bell Tolls (B) 1840410813, Roblox_UI_Sweep 15675046931, Roblox_UI_Small_Click 15675032796,
Roblox_UI_Whoosh_03 15674975792, CoinTransfer_01 127645268874265. Nothing uploaded, nothing bought.

## Art

All geometry is greybox parts built by script (`src/server/ManorBuilder.luau`). No Creator Store models in M1.
