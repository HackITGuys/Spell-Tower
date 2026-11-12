# Series style guide

The look and feel shared by SpellTower and future games in the series. It's a modern, friendly "terminal": monospace text on a dark background, one neon colour family, no bitmaps. It isn't retro-CRT: there are no scanlines, curvature or flicker.

The source of truth in code is [scripts/autoload/term.gd](../scripts/autoload/term.gd).

## 1. Colour

The player picks one **base colour**, and every other colour is derived from it (`Term.derive()`):

| Role | Derivation | Used for |
|---|---|---|
| `FG` | the base colour | normal text, borders, untyped letters |
| `BG` | the base hue, saturation 0.6, value 0.045 (near black, tinted) | background, button fill |
| `DIM` | base mixed 45 % toward `BG` | secondary text, brackets, hints, disabled |
| `ACCENT` | base hue rotated −0.22, saturation 0.8, value 1 (amber for grey bases) | typed letters, the prompt, scores, highlights, focus |
| `ERROR` | red, unless within 0.12 hue of `FG` or `ACCENT`; then the next of cyan, yellow, violet that is far enough from both | wrong letters, misses, game over, a low bar |

Presets: neon green (the default), neon orange, cyan, pink, purple, white.

Rules:
- Use at most **five colours** on screen, all from the table above.
- **Never hard-code a colour.** Always use `Term.FG`, `Term.ACCENT` and the others, so every preset works.
- Meaning must never rely on colour alone. Pair it with motion, sound or text: a red flash plus the "wrong" buzz, a miss plus a shake plus the correct spelling.
- A new preset only needs a base colour. The unit tests check that every preset keeps the roles far enough apart and the background dark.

## 2. Type

- There is **one typeface**: JetBrains Mono (OFL), Regular and Bold. It covers Latin-Ext, Cyrillic and Greek, plus box-drawing and block characters.
- **Base sizes** (before the player's text-size setting):

  | Size | Use |
  |---|---|
  | 56 | titles |
  | 44 | big messages |
  | 36–40 | primary buttons |
  | 30 | falling words |
  | 26 | body text |
  | 20–22 | hints and small buttons |

- **Text-size setting**: S 0.85×, M 1.0×, L 1.2×, XL 1.45×. Always apply a size through `Term.sz(base)`.
- Use Bold only for the title and for "correct spelling" emphasis.
- Lower-case is the default for words and hints. Use UPPER-CASE for buttons, the HUD and big messages.

## 3. ASCII conventions

| Element | Look |
|---|---|
| falling word | `[ word ]`. Brackets are DIM, or ACCENT when locked; typed letters are ACCENT |
| masked word (dictation) | `[ b _ _ _ _ _ _ ]`, one slot per letter |
| prompt | `> typed█`, with a blinking block cursor |
| base / ground | a row of `═` |
| bar | `[██████░░░░] 62%` |
| primary button | `[ START ]` |
| title art | small ASCII drawings in DIM (a tower made of `/\ |[]| __`) |
| keyboard keys | outlined boxes, filled ACCENT for 0.12 s when pressed |

Draw characters on a grid. Monospace cell width is `Term.char_width()`, and custom drawing should snap to cells (see [falling_word.gd](../scenes/falling_word.gd)).

## 4. Layout

- **Portrait first.** The base viewport is 720×1280 with `canvas_items` + `expand` stretch.
- **Scrolling**: the scroll area always spans the full screen, so the scrollbar sits at the screen edge. The width-capped content goes inside it, and the bar must never overlap the content.
- **Width caps**: menus and result screens at most 760, the play area at most 960. Both scale with text size, using `WidthCap`, and are centred. Wide screens get calm empty margins, never stretched rows.
- **Input lives at the bottom**: prompt, then power-ups, then the on-screen keyboard. The playfield fills the rest, and the HUD stays at the top.
- Settings are a two-column grid: label on the left, dropdown on the right.
- Keep touch targets at least 56 px tall in the base viewport.

## 5. Controls (shared across the series)

| Key | Action |
|---|---|
| letters | play |
| Backspace | release, undo |
| Esc | pause; back from a result screen |
| Enter | confirm, start, continue |
| 1 / 2 / 3 | power-ups |
| Tab | repeat speech |

- Input is chosen by platform, never by a setting (`Settings.input_mode()`):
  - **Native mobile app:** the game's own on-screen keyboard. The system keyboard is disabled, and the layout comes from the language file.
  - **Browser on a phone:** the phone's own keyboard, opened by a tap, through `WebKeys` (a hidden input with autocorrect off).
  - **Desktop:** the physical keyboard.
- Buttons in the play area don't invert on hover (`Term.calm_button`), because touch screens leave buttons "hovered".

## 6. Motion

- Keep tweens short: 0.15–0.7 s.
- Words grow and fade when destroyed. A missed word fades in `ERROR`.
- **Screen shake only for big events**: miss (small), CLEAR (large), SHAKE (medium).
- The correct-spelling panel pops in with a back ease, holds for 1.6 s, then fades.
- No looping background animation and no flicker.

## 7. Sound

Sounds are generated in code (`Sfx`): short square, sine or noise blips, and there are no audio files.

| Sound | Character |
|---|---|
| key | a 18 ms noise tick |
| lock | a high blip |
| hit | two rising notes |
| wrong | a low buzz |
| miss | a falling sweep |
| level up / down | a 4-note arpeggio, up or down |
| power / earn | a sine sweep or chime |

- Volume is −10 dB. Each profile can turn sound off.
- Keep new sounds under 0.4 s and in the same "chip" family.

## 8. Copy and tone

- Short, friendly and lower-case: "type the words before they reach your tower".
- Never shame the player. Show the correct spelling, not "WRONG".
- Every string goes through `i18n/ui.csv`, with no literal UI text in code.

## 9. Accessibility

- Text size up to 1.45×, six colour presets (including white), and a sound toggle.
- Colour is never the only signal (see §1).
- Dictation mode helps players who struggle with reading, and the speech rate is set a little slower (0.85).
- TODO: a reduced-motion setting (no shake), and a dyslexia-friendly font option.

## TODO: line-art direction
Explore a "line-art" evolution of the style: thin vector strokes (`draw_line`, `draw_arc`) for towers, the base, frames and simple characters instead of ASCII glyphs. The palette, grid and type stay the same, so it reads as the same family but with more shape and motion. Prototype it on the title tower and the base line first, and keep ASCII as the fallback.
