# SpellTower

A terminal-styled spelling game for kids, made with Godot 4.7. Words fall toward your tower, and you type them before they land. The game is multi-lingual (UI and words), and words are grouped by school grade, from pre-school to grade 10.

## How it plays
- Type the first letter of a falling word to lock on, then finish typing it. **Backspace** lets go of the word.
- A finished word gives points based on its difficulty. A wrong letter or a word reaching the base costs bar, and the penalty grows the better you are doing.
- **A missed word shows its correct spelling** at the base. Missed and misspelled words **come back** later in the game, and in the next game. They're listed under "words to practise" when the game ends.
- **Grades:** words are grouped into grades: *Pre-school* (single letters and first words), then *Grade 1* to *Grade 10*. Each grade is played as 5 stages, shown as e.g. `GRADE 3 · 2/5`.
  - A full bar takes you **up a stage**, and an empty bar takes you **down a stage**. Beating stage 5 moves you up a grade. If the bar empties when you're 2 stages below where you started, it's game over.
  - Every game starts at stage 1 of the *Start grade* chosen in the menu. There's no save/continue.
  - Each game picks a random set of 20 words from the grade for stage 1, and every later stage adds 10 more.
  - Words from lower grades are mixed in: 75% of the words come from the current grade, 15% from the grade below, and 10% from all the grades below that.
  - Words fall a little faster at each stage (+4% per stage). A new grade starts slower again, and dropping back into the grade below speeds up, because its words are easier.
- Power-ups (keys **1/2/3** or the buttons): **AUTO** spells the current word, **CLEAR** wipes the screen, **SHAKE** swaps every word for new ones.
  - +1 AUTO for every 10 correctly spelled words, but every 3rd of those rewards is a SHAKE instead.
  - +1 CLEAR for every stage cleared.
- **Esc** lets go of a locked word; with no word locked, it pauses the game.
- **Typing** depends on the platform (it isn't a setting):
  - **Phone or tablet** (app or browser): the game's own on-screen keyboard. It has no autocorrect, its layout comes from the language file, and the phone's own keyboard never opens, so it can't cover the game.
  - **Desktop app or desktop browser:** the physical keyboard. A physical keyboard also works on touch devices.
- **Menus** use `< value >` pickers instead of drop-down lists, so they work by touch, mouse and keyboard (Left/Right).

## Players
- **Web version:** no players and nothing stored. Pick the settings and a start grade, and press START. Scores last until the page is closed.
- **Desktop and mobile apps:** players are name-based and stored on the device only. Use a nickname: no other personal data is collected.
- Each player keeps their own:
  - start grade, language, colour, text size and sound settings
  - best score per word language, and an all-time best
  - spelling statistics, used for review
- Colours come from six presets. Each is one base colour, and the rest of the palette is derived from it (see [docs/style-guide.md](docs/style-guide.md)).

## Development setup
You need:
- **Godot 4.7.2**, the version pinned in [.godot-version](.godot-version), with the `godot` command on your PATH.
- **Export templates** for that same version. In the editor: *Editor → Manage Export Templates → Download and Install*. They're needed for every build below.
- **Python 3**, for the local web server and the commit checks.
- **Node.js** (LTS), only to run the browser function tests locally.

**Once per clone**, turn on the commit checks. The [pre-commit](https://pre-commit.com) tool runs gdtoolkit's formatter and linter on every commit:
```sh
pip install pre-commit
pre-commit install
```

All commands run from the project folder. After cloning, and after changing `i18n/ui.csv`, word files or other assets, import once:
```sh
godot --headless --path . --import
```
To play from source, run `godot --path .` (or press F5 in the editor).

## Code style
GDScript is formatted and linted with [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdformat` and `gdlint`), pinned to v4.5.0.
- **Line length:** 120.
- **Linter settings:** in [gdlintrc](gdlintrc).
- **Not checked:** `addons/` (vendored code).

**On commit:** the pre-commit hook ([.pre-commit-config.yaml](.pre-commit-config.yaml)) runs both on the files you commit. If `gdformat` changes a file, the commit stops: `git add` the file again and commit. The hook also checks JSON/YAML syntax, line endings and trailing spaces.

**By hand:**
```sh
pre-commit run --all-files                               # everything the hook checks
gdformat --line-length 120 scenes scripts tests          # reformat
gdlint scenes scripts tests                              # lint
```
**In CI:** the same checks run on every push to `develop` (`format and lint` in [checks.yml](.github/workflows/checks.yml)). A push that skipped the hook still gets caught there.

## Testing
There are three kinds of tests. None of them touch your real players, settings or stats.

### Unit tests (GdUnit4)
[GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) is the test framework. It's vendored in `addons/gdUnit4/` (pinned to v6.2.3), so there's nothing to install.
- **Where:** suites live in `tests/unit/`, one file per area: `test_tuning.gd`, `test_word_picker.gd`, `test_word_files.gd`, `test_platform.gd` and so on.
- **Run all of them:**
  ```sh
  godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode
  ```
- **One suite:** pass a file instead, e.g. `-a res://tests/unit/test_word_files.gd`.
- **Result:** the run ends with `Overall Summary: … failures` and an exit code:
  - `0`: all passed
  - `100`: something failed
  - `101`: test objects were left in memory, which also counts as a failure
- **Report:** a full HTML report is written to `reports/report_N/index.html` (git-ignored).
- **In the editor:** the GdUnit4 panel is enabled. Right-click `tests/unit` in the FileSystem dock and choose *Run Tests*.
- **Writing a test:**
  - Make a file `tests/unit/test_<area>.gd` that `extends GdUnitTestSuite`, with functions named `test_…` that use `assert_int(…)`, `assert_str(…)` and so on.
  - For checks that loop over many items (every word, every palette), extend `SpellTestSuite` and use `check(condition, message)`.
  - Tests can pretend to run on another platform with `Settings.force_web`, `force_touch` and `force_input_mode`.

### Smoke tests (scripted playthroughs)
[tests/smoke_game.gd](tests/smoke_game.gd) plays the real game scene with a scripted player. The player types perfectly for 90 seconds, uses power-ups, then stops, and the test checks it climbs stages, falls back and reaches game over. Each run takes a few seconds:
```sh
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_game.gd -- en
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_game.gd -- nb
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_game.gd -- nn
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_game.gd -- en 0   # start grade 0 = pre-school
```
- **Arguments:** the language, then an optional start grade (default 2).
- **Result:** each run ends with `smoke[…]: OK` or a list of `FAIL` lines.

### Browser function tests (Playwright)
[Playwright](https://playwright.dev) plays the real web build in three browsers: an emulated **Pixel 7** (Chromium), an emulated **iPhone 14** (WebKit, Safari's engine) and **desktop Chrome**. The tests are in [tests/e2e/specs/](tests/e2e/specs/):
- the menu has no player screen, and its pickers and START react to taps
- touch devices get the game's own keyboard, and desktop gets none
- taps never focus a page text field, so the phone's own keyboard never opens
- the HUD, playfield and keyboard fit the screen without overlapping
- typing a falling word (by tapping keys, or on a real keyboard) destroys it and scores
- pause and RESUME work by tap

**How they reach the game:** Godot draws everything on one canvas, so there are no page buttons to click. A small test bridge ([test_bridge.gd](scripts/autoload/test_bridge.gd)) publishes the game's state and the on-screen positions of buttons and keys. It's part of every build, but only switches on in the special **"Web (e2e)"** export; everywhere else it does nothing.

**Run them locally:**
```sh
godot --headless --path . --export-release "Web (e2e)" build/web-e2e/index.html
cd tests/e2e
npm ci                                   # first time: installs Playwright
npx playwright install chromium webkit   # first time: downloads the browsers
npx playwright test                      # starts tools/serve_web.py by itself
npx playwright show-report               # open the HTML report
```
- **One device only:** `npx playwright test --project=pixel-7`. The others are `iphone-14` and `desktop-chrome`.
- **Watch it play:** `npx playwright test --headed`.
- **Limits:** emulation can't show a real phone's own keyboard or every browser quirk. Each release PR includes a short manual phone checklist for that.

## Building the versions locally
Every build goes into `build/` (git-ignored). Run the import step first.

| Version | Command | Output |
|---|---|---|
| Web | `godot --headless --path . --export-release "Web" build/web/index.html` | `build/web/` (`index.html`, `.js`, `.wasm`, `.pck`, …) |
| Web (e2e) | `godot --headless --path . --export-release "Web (e2e)" build/web-e2e/index.html` | like Web, plus the test bridge. Only for the browser tests. |
| Windows | `godot --headless --path . --export-release "Windows Desktop" build/windows/SpellTower.exe` | one portable `SpellTower.exe` |
| Linux | `godot --headless --path . --export-release "Linux" build/linux/SpellTower.x86_64` | one binary, `SpellTower.x86_64` |

- **Debug builds:** use `--export-debug` instead of `--export-release`. They print more and allow remote debugging.
- **Try the web version:** run `python tools/serve_web.py` and open http://localhost:8060.
  - With `--lan`, a phone on the same Wi-Fi can open it too; the address is printed when the server starts.
  - The server sends no-cache headers, so after a new export a reload is enough.
- **Try a desktop build:** just run the file. To check that it starts without opening a window: `build/windows/SpellTower.exe --headless --quit-after 300`. It should exit with code 0.
- **Cross-exporting:** each export works from any OS, e.g. the Windows `.exe` can be built on Linux and the Linux binary on Windows.
- **AppImage:** only built in CI (it needs Linux and `appimagetool`). To build one on Linux yourself, follow the *Build AppImage* step in [release.yml](.github/workflows/release.yml).
- **Export settings** live in [export_presets.cfg](export_presets.cfg):
  - Desktop builds embed the game data, so each is a single file.
  - Tests, tools, docs and GdUnit4 are left out of every build.

## Branches and CI/CD
| Branch | What it holds | Rules ([.github/rulesets/](.github/rulesets/)) |
|---|---|---|
| `develop` | day-to-day work | direct pushes allowed; no force-push or deletion. Every push runs the **checks**. |
| `main` | **released versions only**; what's on `main` is what's live | changes only through a PR from `release/<tag>`. That needs the **release-gate** check (only a tag that passed the full release pipeline has it) and your approval, and it's merged with a merge commit. |
| `release/<tag>` | created by the pipeline, pointing at a tagged commit | none; it's the PR source for `main` |
| `web-deploy` | the live web build, generated | none; replaced on every deploy, so don't edit it |
| tags `v*` | one per release, e.g. `v0.3.0`, always on `develop` | can't be moved once pushed |

**Workflows** ([.github/workflows/](.github/workflows/)):

| Workflow | Runs when | What it does |
|---|---|---|
| [checks.yml](.github/workflows/checks.yml) | every push to `develop` or a feature branch, every PR into `develop` | **format and lint** (gdformat, gdlint) · **unit tests** (GdUnit4) · **smoke tests** (en, nb, nn, pre-school). A few minutes. |
| [release.yml](.github/workflows/release.yml) | a tag `v*` is pushed | checks that the tag is `vMAJOR.MINOR.PATCH` and on `develop` → all **checks** → **builds** (web, web e2e, Windows, Linux, AppImage) → **launch checks** (Linux, AppImage, Windows) → **browser function tests** → **release-gate**: draft GitHub Release with the downloads, branch `release/<tag>`, and a PR into `main` |
| [deploy.yml](.github/workflows/deploy.yml) | `main` changes (a release PR was merged), or by hand | deploys **exactly the tested web build** from that tag's release to `web-deploy` (DigitalOcean picks it up) and publishes the release |
| [main-guard.yml](.github/workflows/main-guard.yml) | a PR into `main` opened by hand | explains early that `main` only takes release PRs |
| [godot-update.yml](.github/workflows/godot-update.yml) | weekly, or by hand | PR to `develop` for a new Godot patch release; an issue for a new minor or major version |
| [Dependabot](.github/dependabot.yml) | weekly | PRs to `develop` that update the workflows' actions and Playwright |

- **Results:**
  - A run's page in the *Actions* tab shows each job and step.
  - Its **Artifacts** section has the reports (`unit-test-report`, and `e2e-report` with screenshots and traces of failures) and, for release runs, the builds.
- **Run checks by hand:** *Actions → checks → Run workflow*, then pick the branch.
- **Re-run a failed run:** open it and click *Re-run failed jobs*, e.g. after a network hiccup. A re-run of a release run updates its draft release and PR.
- **Godot version:** CI always uses `.godot-version`. Changing that file (or merging the bot's PR) upgrades CI.

## Releasing a new version
1. **Work on `develop`** and push. Each push runs **checks**; keep them green.
   ```sh
   git switch develop
   git pull
   git add -A
   git commit -m "Describe the change"     # the pre-commit hook formats and lints first
   git push
   ```
2. **Tag the version on `develop` and push the tag.** Use [semantic versioning](https://semver.org): `vMAJOR.MINOR.PATCH`.
   ```sh
   git switch develop && git pull           # tag the latest develop commit
   git tag                                  # existing tags, to pick the next number
   git tag -a v0.3.0 -m "SpellTower v0.3.0"
   git push origin v0.3.0                   # this starts the release pipeline
   ```
3. **Wait for the release pipeline** (*Actions → release*, about 15 minutes). If every job passes, **release-gate** creates:
   - a **draft release** `v0.3.0` with the downloads: `SpellTower-v0.3.0-web.zip`, `-windows.exe`, `-linux.x86_64` and `-x86_64.AppImage`
   - a **PR `release/v0.3.0` → `main`** called "Release v0.3.0", with a short manual phone checklist

   **If a job fails:** nothing is created. Fix the problem on `develop`, then tag the next patch version (`v0.3.1`). Or, to reuse the number, delete the tag (`git push origin --delete v0.3.0` and `git tag -d v0.3.0`) and tag again.
4. **Review and approve the PR, then merge it** with *Create a merge commit*, the only method `main` allows.
5. **Deploy happens by itself.** [deploy.yml](.github/workflows/deploy.yml):
   - deploys the tested web build to the `web-deploy` branch, and DigitalOcean redeploys within a few minutes (check the app's *Activity* tab)
   - publishes the draft release, which becomes *Latest*
6. **Bring `main` back into `develop`**, so the two don't drift apart:
   ```sh
   git switch develop
   git pull origin main
   git push
   ```

**Redeploy an older release:** *Actions → deploy → Run workflow*, and enter its tag.

### One-time setup
1. **Repository settings:**
   - *Settings → Actions → General*: turn on "Allow GitHub Actions to create and approve pull requests". The workflows only open PRs; they never approve or merge them.
   - *Settings → General → Pull Requests*: allow merge commits, and turn on "Automatically delete head branches" so `release/*` branches are tidied up.
2. **Import the rulesets:**
   - Go to *Settings → Rules → Rulesets → New ruleset → Import a ruleset*, and import [main.json](.github/rulesets/main.json), [develop.json](.github/rulesets/develop.json) and [release-tags.json](.github/rulesets/release-tags.json) one by one.
   - Remove any older branch protection rules for `main`/`develop` (*Settings → Branches*), so only the rulesets apply.
   - **Note:** `main` requires the **release-gate** check. GitHub only offers a check in its list after the check has run once, but the imported file already names it.
3. **Turn on the commit checks** in your clone (see [Development setup](#development-setup)).
4. **First release:**
   - Push these files to `develop`, then tag and push `v0.3.0` (or your next number).
   - Merging its PR creates the `web-deploy` branch.
5. **DigitalOcean:**
   - Choose *Create App → GitHub*, and authorise the DigitalOcean GitHub App for the `HackITGuys` organisation (an org admin may need to approve it).
   - Pick the repo `Spell-Tower`, branch **`web-deploy`**, autodeploy on, and output directory `public`. It's a static site with no build command.
   - Or apply the spec instead: `doctl apps create --spec .do/app.yaml` ([.do/app.yaml](.do/app.yaml)).
6. **GitHub Pages (optional):** to also publish there, enable Pages with the source set to "GitHub Actions" and set the repository variable `DEPLOY_PAGES=true`.

### Cost
- **DigitalOcean:** App Platform static-only apps are free, up to 3 apps. Each includes 1 GiB of outbound data a month, and further data costs $0.02/GiB.
- **Traffic:** one game load is about 40 MB (`index.wasm`), so 1,000 plays cost about $1.
- **GitHub Actions:**
  - Minutes are free for public repos. Private repos on the Free plan get 2,000 minutes a month.
  - A `checks` run takes a few minutes, and a full release run about 15. Windows minutes count double on private repos.
- **Headers:** the web export is single-threaded, so it doesn't need the COOP/COEP headers that App Platform static sites can't set.

## Desktop downloads
Each release has portable builds attached; nothing needs installing:
- **Windows:** `SpellTower-<tag>-windows.exe`, a single file with the game data inside. Windows may warn about an unknown publisher because the file isn't code-signed.
- **Linux:** `SpellTower-<tag>-linux.x86_64` (make it executable with `chmod +x`) or `SpellTower-<tag>-x86_64.AppImage`.
  - Both use the system's graphics (OpenGL), window (X11/Wayland) and sound libraries. Those can't be bundled, because graphics drivers belong to the system.
  - **NixOS** can't run ordinary Linux binaries directly. Use `steam-run ./SpellTower-<tag>-linux.x86_64`, `appimage-run SpellTower-<tag>-x86_64.AppImage`, or enable `programs.nix-ld` (or `programs.appimage` with `binfmt = true`).

Android needs a signing keystore stored in repository secrets, so it isn't built yet.

## Layout
| Path | What |
|---|---|
| `scenes/` | main menu, game, game over, falling word, on-screen keyboard, `< value >` stepper, width cap (UI built in code) |
| `scripts/logic/` | pure, unit-tested rules: tuning, scoring, targeting, word picking, review queue, text normalisation, power-ups |
| `scripts/autoload/` | settings, profiles and platform (web/touch), stats, word bank, locale, look (Term), sound (Sfx), browser-test bridge (TestBridge) |
| `tests/unit/` | GdUnit4 unit suites; `tests/smoke_game.gd` is the scripted playthrough |
| `tests/e2e/` | Playwright browser function tests (Node project) |
| `.github/workflows/`, `.github/rulesets/` | CI/CD and the branch/tag rules to import |
| `addons/gdUnit4/` | the GdUnit4 test framework (vendored, v6.2.3) |
| `.claude/agents/` | Claude Code agents for consistency reviews and refactoring (rules in [CLAUDE.md](CLAUDE.md)) |
| `data/` | language manifest + word banks |
| `i18n/ui.csv` | UI strings, one column per locale |
| `docs/languages-and-difficulty.md` | how to add languages, and the difficulty/server design |
| `docs/style-guide.md` | the series' visual and interaction style |
| `docs/release-testing.md` | how releases are tested, and what isn't covered yet |

All gameplay numbers live in [scripts/logic/tuning.gd](scripts/logic/tuning.gd).

## Series ideas
SpellTower is meant to be the first game in a series that shares the same style and toolkit. The plan is to move the theme, keyboard, profiles, locale and stats into a shared `terminal_kit` addon before game 2.

**Modes that fit inside SpellTower:**
- **Anagram:** a falling word is shown scrambled (`[ t c a ]`), and you type it unscrambled.
- **Touch typing:** words built from a key set that grows over time (home row first, then outward), with timing and accuracy per finger.
- **Translation:** see or hear a word in one language and type it in another. The word files already link translations through `concept` ids (`animal.cat` ↔ `katt`), so this mostly needs a mode and more linked words.

**Separate games:**
- **Maths drops:** falling sums, answered on a number-pad keyboard, using the same bar, grade and stage system.
- **Robot commands:** type `move 3` or `turn left` to steer a robot through a grid, a first taste of coding.
- **Geography or vocabulary drops:** the same mechanic with different content, through the same server difficulty model.

**Single app or many?** The current preference is **one hub app**, styled as a fake terminal where each game is a command (`> spelltower`). That gives one install, one set of profiles, one store listing, and one purchase that covers the series. This is still undecided.

### Distribution and monetisation (undecided)
Kids' apps carry extra rules: Google Play's *Designed for Families* programme, COPPA in the US, and GDPR-K in the EU. In practice that means no behavioural ads, only certified ad SDKs if any, and minimal data collection. Options that fit those rules:
1. **Free core + a one-time "family unlock" in-app purchase:** more languages, modes, or the whole hub. Parents generally prefer this to ads, and it's simple to build with the Google Play Billing plugin.
2. **Paid app:** the simplest option, but it gets fewer installs.
3. **School or teacher subscription:** later, once the server exists. It would cover uploading class word lists, class progress and per-class difficulty, and the money would come from schools, not children.
4. **Web:** a free demo on itch.io, linking to the app stores.

Avoid ads in the child-facing app. A server-side subscription (3) fits best with the planned word-list upload feature.

## Status / TODO
- Android export, signing and device testing
- Server: word-list upload, stats sync and dynamic difficulty (see docs)
- More languages. The Norwegian lists (bokmål `nb`, nynorsk `nn`) are ~310-word samples that need review by a native speaker.
- Extract `terminal_kit` before game 2
- Style: explore the "line-art" direction (see the style guide TODO)

Font: JetBrains Mono (SIL OFL 1.1, `fonts/OFL.txt`).
