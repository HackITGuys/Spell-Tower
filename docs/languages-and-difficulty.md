# Languages, words and difficulty

How SpellTower handles multiple languages and how word difficulty is computed, now (locally) and later (server). The two are designed together so that adding languages and adding the server never needs a data-format change.

## 1. Two separate language settings

| Setting | Drives | Source |
|---|---|---|
| **Interface language** (`Settings.ui_locale`) | menus, HUD, messages | `i18n/ui.csv` → Godot `TranslationServer` |
| **Word language** (`Settings.word_lang`) | words, alphabet, on-screen keyboard, stats | `data/languages.json` + `data/words/<code>.json` |

By default the word language follows the interface language. They can differ on purpose, for example Norwegian menus with English words for a child learning English.

### Adding a UI locale
1. Add a column to `i18n/ui.csv`, headed with the locale code (e.g. `de`). Fill every row, including `LOCALE_NAME` (the language's own name, e.g. `Deutsch`).
2. Add `res://i18n/ui.<code>.translation` to `internationalization/locale/translations` in `project.godot`.
3. Run the unit tests (see the README's dev loop). `tests/unit/test_translations.gd` fails if any key is missing for any locale.

### Adding a word language
1. Add an entry to `data/languages.json`:
   ```json
   { "code": "de", "name": "Deutsch", "word_file": "res://data/words/de.json",
     "alphabet": "abcdefghijklmnopqrstuvwxyzäöüß",
     "keyboard": ["qwertzuiopü", "asdfghjklöä", "yxcvbnmß"],
     "casefold": {}, "equivalents": {} }
   ```
   - `alphabet`: the only characters that are accepted, lower-case. Every letter must be on the `keyboard` (tested).
   - `casefold`: characters mapped *before* lower-casing, for languages where the default rule is wrong (Turkish: `{"I": "ı", "İ": "i"}`).
   - `equivalents`: typed character → canonical character, for players on a neighbouring keyboard layout (Norwegian accepts `ä→æ`, `ö→ø`).
2. Create `data/words/<code>.json`:
   ```json
   { "lang": "de", "version": 1,
     "tiers": { "0": ["a", "b", "..."], "1": ["hund", "..."], "2": ["..."] },
     "concepts": { "hund": "animal.dog" } }
   ```
   - Words are lower-case and in Unicode **NFC** (precomposed `å`, not `a` + combining ring). The tests reject combining marks.
   - A tier is a grade: `"0"` is pre-school (single letters of the alphabet and first words), `"1"`..`"10"` are school grades 1..10.
   - Tiers can be sparse. The picker falls back to the nearest tier that has words.
3. Run the tests.

### Scope of the typing model
- It covers alphabetic scripts only: Latin, Cyrillic, Greek and similar, where one key gives one letter. CJK and other scripts that need an IME don't fit "type the falling word letter by letter". They would need a different game mode.
- Letters with diacritics get their own keys on the in-game keyboard (`æ ø å`, `é`, `ü`…). There's no long-press or dead-key composition in v1.

## 2. Word identity across languages

```
entry = { id: "en:cat", w: "cat", d: 1, concept: "animal.cat" }
```

- **`id` = `<lang>:<word>`** is the unit for all statistics and difficulty. "cat" (en) and "katt" (nb) are *different spelling problems*. They're never merged, even though they mean the same thing.
- **`d`** is the curated base tier, which is the grade the word belongs to: 0 = pre-school, 1..10 = school grade 1..10. Each language is calibrated **for its own speakers**. A more phonetic language (Norwegian, Finnish) may place longer words at a lower tier than English would.
- **`concept`** is optional and links translations (`animal.cat`). It has **no effect on difficulty**. It exists for future modes such as "see the English word, type the Norwegian" or showing a picture. A concept can exist in one language and not another.

## 3. Difficulty pipeline

```
effective_difficulty(lang, word, grade) = clamp(base_d + local_adjust + server_adjust, 0, 10)
```

| Term | v1 | Later |
|---|---|---|
| `base_d` | curated tier from the word file | same |
| `local_adjust` | 0..+2 from this device's stats (`Stats.local_adjust`) | same |
| `server_adjust` | always 0 (`WordBank.server_adjust` is empty) | from the server, per `(lang, word, grade)` |

The effective difficulty decides **which grade a word is drawn from** and **how many points it is worth** (pre-school words count as 0.5).

### Picking words in a game
- 75% of words come from the current grade, 15% from the grade below, and 10% from any grade below that (each equally likely). At the bottom, a missing share goes to the current grade.
- The current grade is shuffled once per game. Stage 1 uses the first 20 words of that order and every stage adds 10 more, so new words are introduced while the earlier ones keep coming back. Lower grades use all their words.
- Constants live in `scripts/logic/tuning.gd` (`WEIGHT_*`, `POOL_START`, `POOL_GROWTH`).

### Local stats (`user://stats_<profile_id>.json`, implemented)
Stats are kept **per player profile**. Profiles are listed in `user://profiles.json`, and each profile has an anonymous random `anon_id`, which is the id the server would see. The nickname is never sent.

Each `"<lang>:<word>"` entry stores:
- `a`: attempts (completed + missed)
- `c`: completed cleanly
- `x`: completed with mistakes
- `m`: missed
- `wl`: wrong letters
- `b`: review box, from 0 up to the number of review gaps. Reaching that number means the word has "graduated" from review.

The file also holds the player's start `grade` (0..10). It replaced the earlier age band.

**Review (failed words come back).** A miss or a misspelling puts the word in box 0 of a small Leitner queue (`scripts/logic/review_queue.gd`), counted in word spawns:
- The gaps are `REVIEW_GAPS = [4, 10, 25]` spawns.
- Each clean spelling moves the word to the next box, and after the last box it graduates.
- Failing again resets it to box 0.
- At the start of a game, up to 12 earlier failures that haven't graduated are seeded, worst first, and staggered. That's how review carries over between games.

On the server this becomes the same signal as the fail rate: words many children keep failing get a higher `d_server`.

`local_adjust` stays 0 until a word has 3 attempts. After that, a fail rate (`(x + m) / a`) of 50% or more gives +1, and 75% or more gives +2.

### Server (design only, nothing is sent in v1)

```
POST /v1/stats
{ "anon_id": "9f3c…", "lang": "en", "grade": 3, "app_version": "0.1",
  "words": [ { "id": "en:because", "a": 6, "c": 2, "x": 3, "m": 1, "wl": 5 } ] }

GET /v1/words/en?grade=3&since=2026-11-01
→ { "version": 42, "words": [ { "id": "en:because", "w": "because", "d_base": 5, "d_server": 6 } ] }
```

- The server aggregates by **`(lang, word, grade)`**. A word that's hard in grade 2 can be easy in grade 6, and the same English word can behave differently from its Norwegian counterpart.
- Difficulty comes from the miss rate, shrunk towards the curated tier (Bayesian prior). With `k` = prior strength (e.g. 30 attempts), `rate = (fails + k·prior_rate(d_base)) / (attempts + k)`, mapped back to a tier. Words with few plays stay at their curated tier, and popular words move as data comes in.
- The client stores `server_adjust = d_server - d_base` per word. It is capped at ±2 per sync so a word can't swing wildly.
- The server can also ship **new words and whole new languages** with the same file format as `data/words/*.json`. The bundled files stay as the offline fallback.
- The client syncs at the end of a game when online and caches the result in `user://`. It never blocks play.

### Privacy (GDPR / children)
- **Default: collect only** the anonymous per-profile id, the language, the chosen start grade (no age or birth date) and the per-word counts above. There's no name, email, device id or IP logging beyond what transport requires.
- **Gender and country are not collected.** For children they are special-care data with little value for spelling difficulty. If ever needed they must be opt-in, with parental consent for under-16s (GDPR Art. 8; the threshold varies by EU country, 13–16), a privacy notice, and a delete-my-data path keyed by that id.
- Uploading is off until there's a settings toggle and a privacy notice. Deleting a profile already deletes its local stats. Resetting the id must also be possible.

## 4. Where it lives in code
| Concern | File |
|---|---|
| UI strings | `i18n/ui.csv`, `scripts/autoload/locale.gd` |
| Manifest, word loading, effective difficulty | `scripts/autoload/word_bank.gd` |
| Text normalisation (casefold, equivalents, alphabet) | `scripts/logic/text_norm.gd` |
| Grade mix, growing word pools, shuffle bag, unique initials, fallback | `scripts/logic/word_picker.gd` |
| Grades and stages, speed, pool sizes | `scripts/logic/tuning.gd` |
| Review of failed words | `scripts/logic/review_queue.gd` |
| Local stats (per profile) | `scripts/autoload/stats.gd` |
| Profiles, preferences, start grade | `scripts/autoload/settings.gd` |
