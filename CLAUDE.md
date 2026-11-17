# SpellTower: project rules for Claude

A terminal-styled spelling game for kids (Godot 4.7, GDScript, UI built in code). It's web-first; desktop builds are portable single files, and Android comes later. The README has the player-facing description; this file is how to work on the code.

## Hard rules
- **Never run git.** That means no `git status`, `diff`, `add`, `commit` or `init`, not even in temp folders. The user handles all git. Read files directly to see their state.
- **Keep everything in step.** A behaviour change updates its tests, `README.md`, the relevant `docs/*.md` and `i18n/ui.csv` in the same change.
- **Every logic change gets a test** in `tests/unit/` (GdUnit4). Before calling work done, run the format/lint check, the unit tests and the smoke tests (and the browser tests if the web UI changed), and report real results.
- **Don't invent content.** Word lists (`data/words/*.json`) and translations are the user's content. Report problems in them; don't rewrite them unless asked.
- **Prefer off-the-shelf tools** over writing your own (the user's preference).

## Commands
```sh
godot --headless --path . --import                       # after adding/changing assets or ui.csv
godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_game.gd -- en    # also: -- nb, -- nn, -- en 0
gdformat --check --line-length 120 scenes scripts tests && gdlint scenes scripts tests   # gdtoolkit 4.5.0
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-release "Web (e2e)" build/web-e2e/index.html   # then: cd tests/e2e && npx playwright test
godot --headless --path . --export-release "Windows Desktop" build/windows/SpellTower.exe
godot --headless --path . --export-release "Linux" build/linux/SpellTower.x86_64
python tools/serve_web.py                                 # serve build/web on :8060
```
- Desktop presets embed the game data (`binary_format/embed_pck=true`), so each build is one file. Windows uses `application/modify_resources=false`, so CI on Linux needs no rcedit/wine (default icon and metadata). Don't put comments in `export_presets.cfg`: the editor drops them on save.
- GdUnit4 exit codes: 0 ok, 100 failures, 101 orphan nodes. Treat any non-zero as failing.
- The Godot version is pinned in `.godot-version` (CI reads it).

## Where things live
| Path | What |
|---|---|
| `scripts/logic/` | pure, testable rules. **All gameplay numbers are in `tuning.gd`.** |
| `scripts/autoload/` | Settings (profiles, platform: `is_web()`, `is_touch()`, `uses_profiles()`, `input_mode()`), Stats, WordBank, Locale, Term (theme), Sfx |
| `scenes/` | menu, game, game over, falling word, on-screen keyboard, `Stepper`, `WidthCap` |
| `data/languages.json`, `data/words/<code>.json` | word languages and word lists |
| `i18n/ui.csv` | every UI text: one row per key, one column per locale. The `.translation` files are generated and git-ignored. |
| `tests/unit/` | GdUnit4 suites (extend `GdUnitTestSuite`, or `SpellTestSuite` for bulk `check()` loops) |
| `tests/smoke_game.gd` | scripted playthrough of the real game scene |
| `tests/e2e/` | Playwright browser tests (Node). They read `window.spelltowerState` from `scripts/autoload/test_bridge.gd`, which is only active in the "Web (e2e)" export. |
| `.github/workflows/` | `checks.yml` (every push to develop), `release.yml` (tag `v*`: full pipeline, `release-gate`, PR to main), `deploy.yml` (main → `web-deploy`), `main-guard.yml`, `godot-update.yml` |
| `.github/rulesets/` | branch/tag rules for the user to import into GitHub (main: release PRs only) |

## Conventions
- **Terms:**
  - Players see **grade** (Pre-school, Grade 1–10) and **stage** (1–5 within a grade).
  - In code, `level` is the running count over all stages (`Tuning.grade_for_level`, `stage_for_level`, `first_level_of_grade`).
  - A word's `d` / word-file "tier" equals its grade.
  - Retired concepts must not come back: age, start level, resume/continue, dictation/listen mode, WebKeys.
- **Text:** never hard-code user-facing text. Use `tr("KEY")` with a row in `i18n/ui.csv`, filled for every locale, with the same `%s` placeholders in each.
- **Platforms:**
  - The web version has no profiles and stores nothing (`Settings.uses_profiles()`).
  - Touch devices, apps and browsers alike, use the game's own `OnScreenKeyboard`. The phone keyboard is never used.
  - Tests simulate platforms with `Settings.force_web`, `force_touch` and `force_input_mode`.
- **UI:**
  - Pickers are `Stepper`s (`< value >`), never `OptionButton`/popups.
  - Scroll areas set `scroll_deadzone`.
  - Style rules are in `docs/style-guide.md`.
- **Word files:**
  - lowercase NFC words, only letters from the language's `alphabet`
  - each word appears once per file
  - grades as keys `"0"` (pre-school) to `"10"`
  - every `concepts` key must exist as a word
- **Branches:**
  - Work happens on `develop`.
  - Releases are tags `vMAJOR.MINOR.PATCH` on `develop`.
  - `main` only receives `release/<tag>` PRs that passed the `release-gate` check.
  - Bot PRs (Dependabot, Godot updates) target `develop`.
- **Workflows:** action versions are kept current by Dependabot, so reuse the versions already in the files. The required check name `release-gate` is referenced in `.github/rulesets/main.json`; renaming the job breaks merging into main.
- **Formatting:** gdformat with `--line-length 120`; lint settings are in `gdlintrc`. CI fails on any difference, so format before finishing.
- **Testability:** UI that the browser tests need must stay visible to `TestBridge` (Buttons, Labels, `Stepper`s, the game's `_keyboard`/`_hud_line`/`_playfield`). Renaming those breaks `tests/e2e/`.
- **Style:** GDScript with static types where the surrounding code has them, tabs, and `##` doc comments on classes and public functions.

## Agents
- `consistency-reviewer` (read-only): finds drift between code, tests, docs, translations and data.
- `refactorer`: makes behaviour-preserving changes across all of those together, then runs the tests.
