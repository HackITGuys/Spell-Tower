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
- **Esc** pauses the game.
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
- **Python 3** (any recent version), only for the local web server.

All commands run from the project folder. After cloning, and after changing `i18n/ui.csv`, word files or other assets, import once:
```sh
godot --headless --path . --import
```
To play from source, run `godot --path .` (or press F5 in the editor).

## Testing
There are two kinds of tests. Both run headless (no window) and never touch your real players, settings or stats.

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

## Building the versions locally
Every build goes into `build/` (git-ignored). Run the import step first.

| Version | Command | Output |
|---|---|---|
| Web | `godot --headless --path . --export-release "Web" build/web/index.html` | `build/web/` (`index.html`, `.js`, `.wasm`, `.pck`, …) |
| Windows | `godot --headless --path . --export-release "Windows Desktop" build/windows/SpellTower.exe` | one portable `SpellTower.exe` |
| Linux | `godot --headless --path . --export-release "Linux" build/linux/SpellTower.x86_64` | one binary, `SpellTower.x86_64` |

- **Debug builds:** use `--export-debug` instead of `--export-release`. They print more and allow remote debugging.
- **Try the web version:** run `python tools/serve_web.py` and open http://localhost:8060.
  - With `--lan`, a phone on the same Wi-Fi can open it too; the address is printed when the server starts.
  - The server sends no-cache headers, so after a new export a reload is enough.
- **Try a desktop build:** just run the file. To check that it starts without opening a window: `build/windows/SpellTower.exe --headless --quit-after 300`. It should exit with code 0.
- **Cross-exporting:** each export works from any OS, e.g. the Windows `.exe` can be built on Linux and the Linux binary on Windows.
- **AppImage:** only built in CI (it needs Linux and `appimagetool`). To build one on Linux yourself, follow the *Build AppImage* step in [build.yml](.github/workflows/build.yml).
- **Export settings** live in [export_presets.cfg](export_presets.cfg):
  - Desktop builds embed the game data, so each is a single file.
  - Tests, tools, docs and GdUnit4 are left out of every build.

## CI/CD pipeline
All automation is in [.github/workflows/](.github/workflows/):

| Workflow | Runs when | What it does |
|---|---|---|
| [build.yml](.github/workflows/build.yml) | every push (any branch except `web-deploy`), every PR, manual run | install Godot → import → **unit tests** → **smoke tests** (en, nb, pre-school) → **exports** (web, Windows, Linux, AppImage) → **launch checks** (Linux binary and AppImage on Ubuntu, `.exe` on Windows) → check `serve_web.py`. On `main` it also **deploys** the web version to DigitalOcean. |
| [release.yml](.github/workflows/release.yml) | a GitHub Release is published | runs all of `build.yml` on the release; if it passes, attaches the builds to the release and opens the develop → main PR |
| [godot-update.yml](.github/workflows/godot-update.yml) | weekly, or manual | PR to `develop` for a new Godot patch release; an issue for a new minor or major version |
| [Dependabot](.github/dependabot.yml) | weekly | PRs to `develop` that keep the workflows' actions up to date |

- **Results:**
  - A run's page in the *Actions* tab shows each step.
  - At the bottom, under **Artifacts**, are `test-report` (the GdUnit4 HTML report) and the builds: `spelltower-web`, `spelltower-windows`, `spelltower-linux` and `spelltower-appimage`.
  - So any push gives you downloadable builds, without a release.
- **Run it by hand:** *Actions → build → Run workflow* and pick the branch.
  - Tick "Publish this build to DigitalOcean" to deploy that branch's web build. Use `main` for this, unless you deliberately want something else live.
- **Re-run a failed run:** open it and click *Re-run jobs*, e.g. after a network hiccup.
- **Godot version:** CI always uses `.godot-version`. Changing that file (or merging the bot's PR) upgrades CI.

## Releasing a new version
`main` is protected: it only changes through pull requests, and what's on `main` is what's live. Day-to-day work goes to `develop`.

1. **Finish on `develop`.** Push your changes and wait until the **build** run for that push is green in the *Actions* tab.
2. **Publish a release.** *Releases → Draft a new release*:
   - Create a new tag, e.g. `v0.3.0`.
   - Set **Target: `develop`**.
   - Add a title and notes ("Generate release notes" fills them from the commits).
   - Click **Publish release**.
3. **Wait for `release.yml`.** It builds and tests the release again. If everything passes:
   - The release gets its downloads: `SpellTower-<tag>-web.zip`, `-windows.exe`, `-linux.x86_64` and `-x86_64.AppImage`.
   - A **"Release &lt;tag&gt;" PR from `develop` to `main`** is opened. If one is already open, it gets a comment instead.

   If a test fails, nothing is attached and no PR is opened. Fix it on `develop`, delete the release (and its tag), and publish again.
4. **Review and merge the PR.** Approve it if your rules require that: it was opened by the bot, so you're allowed to.
5. **Deploy happens by itself.**
   - Merging updates `main`, and `build.yml` runs on it.
   - If it passes, the `deploy-digitalocean` job pushes the web build to the **`web-deploy`** branch, under `public/`. That branch is generated and replaced on every deploy, so don't edit it.
   - DigitalOcean notices the push and redeploys the site, usually within a few minutes.
   - Check the app's *Activity* tab in DigitalOcean, then reload the site.

**Redeploy without a new release:** *Actions → build → Run workflow* on `main`, with "Publish this build to DigitalOcean" ticked.

A stricter gate, where browser tests run *before* a release is published, is proposed in [docs/release-testing.md](docs/release-testing.md).

### One-time setup
1. **Let Actions open PRs:** turn on *Settings → Actions → General → "Allow GitHub Actions to create and approve pull requests"*. The workflows only open PRs; they never approve or merge them.
2. **Branch protection:** the rule must apply to `main` only, not to all branches. Otherwise the bot can't push `web-deploy`.
3. **First release:** get these workflow files onto `main` with a first release PR. Merging it creates the `web-deploy` branch.
4. **DigitalOcean:**
   - Choose *Create App → GitHub*, and authorise the DigitalOcean GitHub App for the `HackITGuys` organisation (an org admin may need to approve it).
   - Pick the repo `Spell-Tower`, branch **`web-deploy`**, autodeploy on, and output directory `public`. It's a static site with no build command.
   - Or apply the spec instead: `doctl apps create --spec .do/app.yaml` ([.do/app.yaml](.do/app.yaml)).
5. **GitHub Pages (optional):** to also publish there, enable Pages with the source set to "GitHub Actions" and set the repository variable `DEPLOY_PAGES=true`.

### Cost
- **DigitalOcean:** App Platform static-only apps are free, up to 3 apps. Each includes 1 GiB of outbound data a month, and further data costs $0.02/GiB.
- **Traffic:** one game load is about 40 MB (`index.wasm`), so 1,000 plays cost about $1.
- **GitHub Actions:** minutes are free for public repos. Private repos on the Free plan get 2,000 minutes a month.
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
| `scripts/autoload/` | settings, profiles and platform (web/touch), stats, word bank, locale, look (Term), sound (Sfx) |
| `tests/unit/` | GdUnit4 unit suites; `tests/smoke_game.gd` is the scripted playthrough |
| `addons/gdUnit4/` | the GdUnit4 test framework (vendored, v6.2.3) |
| `.claude/agents/` | Claude Code agents for consistency reviews and refactoring (rules in [CLAUDE.md](CLAUDE.md)) |
| `data/` | language manifest + word banks |
| `i18n/ui.csv` | UI strings, one column per locale |
| `docs/languages-and-difficulty.md` | how to add languages, and the difficulty/server design |
| `docs/style-guide.md` | the series' visual and interaction style |
| `docs/release-testing.md` | proposal: browser tests before a release is published |

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
- Release gate with browser end-to-end tests (proposal: [docs/release-testing.md](docs/release-testing.md))
- Server: word-list upload, stats sync and dynamic difficulty (see docs)
- More languages. The Norwegian lists (bokmål `nb`, nynorsk `nn`) are ~310-word samples that need review by a native speaker.
- Extract `terminal_kit` before game 2
- Style: explore the "line-art" direction (see the style guide TODO)

Font: JetBrains Mono (SIL OFL 1.1, `fonts/OFL.txt`).
