# Release testing: proposal

**Status:** proposal, not implemented yet. What runs today is described under *Today* below.

## Goal
A release is published only after it passes:
- unit tests
- functionality tests on the real builds: the web version in phone and desktop browsers, and the desktop executables

The bugs this should have caught:
- On a phone browser, the phone's keyboard opened and closed on every tap.
- The menu's drop-down lists didn't react to touch.
- In "Desktop site" mode, the phone keyboard covered most of the game.

## Today
| When | What runs | Where |
|---|---|---|
| Every push and PR | GdUnit4 unit tests, smoke playthroughs (en, nb, pre-school), all exports, launch checks of the Linux binary, AppImage and Windows `.exe` | [build.yml](../.github/workflows/build.yml) |
| Release published | the same build on the release's commit; only if it passes are the builds attached and the develop→main PR opened | [release.yml](../.github/workflows/release.yml) |
| PR into `main` | needs your approval; merging deploys the web version | branch protection |

**The gap:** the release is already *published* when the tests run, and nothing exercises the web version in a phone browser.

## Proposed flow
```
draft release (target develop)
  └─ release workflow
       ├─ unit tests (GdUnit4)
       ├─ smoke playthroughs
       ├─ exports + desktop launch checks
       ├─ web end-to-end tests (Playwright, phone + desktop browsers)
       └─ all green? ─ yes → attach builds, publish the release, open the develop→main PR
                      └ no  → release stays a draft; the failing report is attached to the run
```
- **Trigger:**
  - GitHub has no "a draft was created" workflow trigger. Use a `v*` tag push, or a manual *Run workflow* with a version input.
  - The workflow creates the draft itself (`gh release create --draft`) and publishes it at the end (`gh release edit --draft=false`).
- **One workflow:** everything happens in one workflow run. A release published with the workflow's own token doesn't start other workflows, so a separate "on release published" workflow would never run.
- **Optional manual approval:** put the publish job in a protected environment called `release`, with you as required reviewer (*Settings → Environments*). The workflow then waits for your click after all tests pass.

## Web end-to-end tests
**Tool:** [Playwright](https://playwright.dev), off the shelf and free. It drives real Chromium and WebKit (the engine behind Safari), with built-in phone emulation: screen size, touch and user agent.
- Devices: **Pixel 7** (Chromium), **iPhone 14** (WebKit), and **Desktop Chrome**.
- It runs against the web export served by `tools/serve_web.py`.

**Reaching the game from the test:** Godot draws everything on a single `<canvas>`, so there are no page elements to click. The proposal is a small test bridge:
- A second web export preset, "Web (e2e)", with the custom feature tag `e2e`.
- When that tag is present, the game registers `window.spelltowerTest` through `JavaScriptBridge`, with:
  - the current screen (`menu` / `game` / `game_over`)
  - visible buttons and pickers, with their screen rectangles and texts
  - the game state (grade, stage, score, words on screen)
- The normal web export doesn't contain the bridge.

**First test cases:**
1. The menu loads with no player screen. Tapping `>` on *Start grade* changes the grade, and START starts the game.
2. In the game on Pixel 7 and iPhone 14, the game's own keyboard is visible and **no page text field ever has focus**. That's the phone-keyboard bug: `document.activeElement` must never be an `<input>`.
3. At 390×844, the HUD, the playfield, the power-ups and the keyboard all fit on screen without overlapping.
4. Tapping the keys of the next word on the game's own keyboard destroys it and the score goes up.
5. Pause and resume by tap work, and game over leads to the result screen.
6. Desktop Chrome: typing with the physical keyboard works, and no on-screen keyboard is shown.

**Kept as artifacts:** a screenshot per device and step, the Playwright trace, and the HTML report.

**Limits:**
- Emulation can't show a real phone's keyboard or its browser quirks. The game no longer uses the phone keyboard, which removes the biggest risk.
- Testing on real devices needs a paid service (BrowserStack or Sauce Labs). Until then, a short **manual phone check** before approving the release PR:
  - [ ] Android Chrome: the menu works by tap, a game can be played to game over, and the phone keyboard never opens
  - [ ] iPhone Safari: the same
  - [ ] Landscape: everything is still usable

## Unit tests (GdUnit4)
- Suites live in `tests/unit/`, run in CI by `build.yml`, and publish a JUnit/HTML report.
- **Next step:** move the smoke playthrough (`tests/smoke_game.gd`) into GdUnit4's `SceneRunner`. It can simulate taps and key presses on the real scenes, so the smoke tests appear in the same report.

## Desktop
- **Already today:** the launch checks prove each executable starts with its embedded data.
- **Proposed:** run the smoke playthrough against the *exported* Linux binary, not the editor build. This needs a tiny `--smoke` command-line switch in the game that runs the scripted player.

## Work estimate
| Step | Size |
|---|---|
| Release workflow with draft → test → publish | small |
| "Web (e2e)" preset + `window.spelltowerTest` bridge | small |
| Playwright project (`tests/e2e/`), 6 cases × 3 devices, CI job | medium |
| Smoke tests into GdUnit4 SceneRunner | medium |
| `--smoke` switch for exported builds | small |
