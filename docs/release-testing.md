# Release testing

How a version gets from `develop` to players, and what is tested on the way. The step-by-step commands are in the README under *Releasing a new version*; the branch rules are in `.github/rulesets/`.

## The gate
```
push to develop ──► checks.yml: format + lint, unit tests, smoke tests          (every commit)

git tag v1.2.3 on develop + push
  └─► release.yml
        ├─ verify tag         vMAJOR.MINOR.PATCH, and the commit is on develop
        ├─ checks             same as above
        ├─ build              web, web (e2e), Windows .exe, Linux binary, AppImage
        │                     + launch checks: Linux binary and AppImage start and quit cleanly
        ├─ launch-windows     the .exe starts and quits cleanly on Windows
        ├─ e2e                browser function tests (Playwright) on the web (e2e) build
        └─ release-gate       only if all of the above passed:
                              draft release with the downloads, branch release/v1.2.3,
                              PR release/v1.2.3 → main

PR into main  ── needs the "release-gate" check + your approval, merged with a merge commit
merge         ──► deploy.yml: the tested web zip → web-deploy (DigitalOcean), release published
```
**Why `main` only gets tested releases:** `main`'s ruleset requires the **release-gate** check, and only `release.yml` produces it. That workflow only runs for `v*` tags, so a commit that wasn't tagged, or failed any job, can't be merged into `main`.

**Why the deployed site is exactly what was tested:** `deploy.yml` doesn't rebuild. It deploys the web zip attached to the tag's release by the same pipeline run that tested it.

## Browser function tests
- **Tool:** [Playwright](https://playwright.dev), in `tests/e2e/`. The README explains how to run them locally.
- **Devices:** an emulated **Pixel 7** (Chromium), an emulated **iPhone 14** (WebKit, Safari's engine) and **desktop Chrome**.
- **How the tests see the game:** Godot draws on a single `<canvas>`. The "Web (e2e)" export, with the custom feature tag `e2e`, turns on `scripts/autoload/test_bridge.gd`. It publishes `window.spelltowerState`: the current screen, buttons, labels, pickers, keyboard keys with their positions, and the game state. The tests tap or click at those positions. The normal web build contains the bridge, but it stays inactive there.

| Test | Catches |
|---|---|
| menu has no player screen; only the six settings pickers + START | web version asking for a player |
| the start-grade picker reacts to taps; START starts at that grade | pickers not reacting to touch (the old drop-downs) |
| touch devices get the game keyboard, desktop gets none | wrong input mode per platform |
| taps never focus a page text field | the phone's own keyboard opening and closing on every tap |
| HUD, playfield and keyboard fit without overlapping | the keyboard covering the game |
| typing a falling word destroys it and scores | input not reaching the game |
| pause and RESUME work by tap | broken pause by touch |

- **On failure:** the run keeps screenshots and a Playwright trace in the `e2e-report` artifact. Open the trace with `npx playwright show-trace <file>`.

## Not covered (yet)
- **Real phones:** emulation can't show a real phone keyboard or every browser quirk. Real devices would need a paid service (BrowserStack, Sauce Labs). Each release PR has a short manual checklist instead:
  - [ ] Android Chrome: the menu works by tap; play to game over; the phone keyboard never opens
  - [ ] iPhone Safari: the same
  - [ ] Landscape: everything is still usable
- **Game over in the browser:** reaching game over takes minutes of game time. The smoke tests cover it headless, but the browser tests don't.
- **Smoke tests in GdUnit4:** they could move to GdUnit4's `SceneRunner`, so they appear in the same report.
- **Exported desktop builds:** they're only launch-checked. Running the smoke playthrough inside an exported build would need a `--smoke` command-line switch.
