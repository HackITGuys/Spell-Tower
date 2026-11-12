# SpellTower

A terminal-styled spelling game for kids, made with Godot 4.7. Words fall toward your tower, and you type them before they land. The game is multi-lingual (UI and words), and the starting difficulty comes from the player's age.

## How it plays
- Type the first letter of a falling word to lock on, then finish typing it. **Backspace** lets go of the word.
- A finished word gives points based on its difficulty. A wrong letter or a word reaching the base costs bar, and the penalty grows the better you are doing.
- **A missed word shows its correct spelling** at the base. Missed and misspelled words **come back** later in the game, and in the next game. They're listed under "words to practise" when the game ends.
- A full bar takes you **up a level**, and an empty bar takes you **down a level**. If the bar empties when you're 2 levels below where you started, it's game over.
- Power-ups (keys **1/2/3** or the buttons): **AUTO** spells the current word, **CLEAR** wipes the screen, **SHAKE** swaps every word for new ones.
  - +1 AUTO for every 10 correctly spelled words, but every 3rd of those rewards is a SHAKE instead.
  - +1 CLEAR for every level cleared.
- **Modes**:
  - *Read and type*: words are shown in full.
  - *Listen and spell* (dictation): words show only their first letter, as `[ b _ _ _ _ _ _ ]`. When you type that letter and lock on, the word is spoken. **Tab** or **SAY** repeats it. If the device has no voice for the language, the game falls back to showing words.
- **Esc** pauses the game.
- **Typing** depends on the platform (it isn't a setting):
  - **Native phone or tablet app:** the game's own on-screen keyboard. It has no autocorrect, and its layout comes from the language file.
  - **Desktop app or desktop browser:** the physical keyboard.
  - **Browser on a phone:** the phone's own keyboard. Tap the game to open it. It types into a hidden field with autocorrect, autocomplete and autocapitalise turned off ([web_keys.gd](scripts/autoload/web_keys.gd)).

## Players
- Players are name-based and stored on the device only. Use a nickname: no other personal data is collected.
- Each player keeps their own:
  - language, colour, text size and sound settings
  - best score per word language, and an all-time best
  - spelling statistics, used for review
  - a **continue** save at the start of the level they were on. The save is cleared on game over.
- Colours come from six presets. Each is one base colour, and the rest of the palette is derived from it (see [docs/style-guide.md](docs/style-guide.md)).

## Dev loop (web first)
```sh
godot --headless --path . --import                                        # first time / after adding assets
godot --headless --path . --script res://tests/run_tests.gd               # logic tests
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_game.gd -- en   # scripted playthrough
#   other variants: -- nb   |   -- en listen   |   -- en show continue
godot --headless --path . --export-debug "Web" build/web/index.html       # web build
python tools/serve_web.py                                                 # http://localhost:8060  (--lan for a phone)
```
Or run `godot --path .` to play natively.

The tests never write the player's real settings or stats.

**CI:** [.github/workflows/build.yml](.github/workflows/build.yml) runs on every push and pull request:
- installs the Godot version pinned in [.godot-version](.godot-version) and its export templates
- runs the unit tests and all smoke variants
- exports the web build and uploads it as an artifact
- checks `tools/serve_web.py` against the export on the latest Python 3

**Updates:** [Dependabot](.github/dependabot.yml) keeps the workflow actions patched, once a week.
Dependabot can't track Godot, so [godot-update.yml](.github/workflows/godot-update.yml) does that weekly instead. It opens a PR for a new patch release (4.7.x) and an issue for a new minor or major release. It needs *Settings → Actions → General → "Allow GitHub Actions to create and approve pull requests"* to be turned on.

To also publish to GitHub Pages:
1. Enable Pages with the source set to "GitHub Actions".
2. Set the repository variable `DEPLOY_PAGES=true`.

Windows and Android builds can be added to the same workflow later. Android release builds need a signing keystore stored in repository secrets.

## Layout
| Path | What |
|---|---|
| `scenes/` | main menu, game, game over, falling word, on-screen keyboard, width cap (UI built in code) |
| `scripts/logic/` | pure, unit-tested rules: tuning, scoring, targeting, word picking, review queue, text normalisation, power-ups |
| `scripts/autoload/` | settings and profiles, stats, word bank, locale, look (Term), sound (Sfx), speech |
| `data/` | language manifest + word banks |
| `i18n/ui.csv` | UI strings, one column per locale |
| `docs/languages-and-difficulty.md` | how to add languages, and the difficulty/server design |
| `docs/style-guide.md` | the series' visual and interaction style |

All gameplay numbers live in [scripts/logic/tuning.gd](scripts/logic/tuning.gd).

## Series ideas
SpellTower is meant to be the first game in a series that shares the same style and toolkit. The plan is to move the theme, keyboard, profiles, locale and stats into a shared `terminal_kit` addon before game 2.

**Modes that fit inside SpellTower:**
- **Anagram:** a falling word is shown scrambled (`[ t c a ]`), and you type it unscrambled.
- **Touch typing:** words built from a key set that grows over time (home row first, then outward), with timing and accuracy per finger.
- **Translation:** see or hear a word in one language and type it in another. The word files already link translations through `concept` ids (`animal.cat` ↔ `katt`), so this mostly needs a mode and more linked words.

**Separate games:**
- **Maths drops:** falling sums, answered on a number-pad keyboard, using the same bar and level system.
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
- Windows and Android export presets, packaging and device testing
- Server: word-list upload, stats sync and dynamic difficulty (see docs)
- More languages. The Norwegian list is a ~280-word sample that needs review by a native speaker.
- Extract `terminal_kit` before game 2
- Style: explore the "line-art" direction (see the style guide TODO)

Font: JetBrains Mono (SIL OFL 1.1, `fonts/OFL.txt`).
