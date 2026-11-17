import { test, expect } from '@playwright/test';
import {
  openGame, waitForScene, state, press, button, stepper, focusedTag, canvasBox, inside, isTouch, State,
} from './helpers';

// Function tests for the web build, on an emulated Pixel 7, iPhone 14 and desktop
// Chrome (see playwright.config.ts). They cover the bugs found on phones: the phone
// keyboard toggling on every tap, menu pickers that didn't react to touch, and the
// phone keyboard covering the game.

async function startGame(page, info): Promise<State> {
  const menu = await openGame(page);
  await press(page, info, button(menu, '[ START ]').rect);
  return waitForScene(page, 'game');
}

test('menu: no player screen, settings only, nothing stored', async ({ page }) => {
  const s = await openGame(page);
  const texts = [...s.labels, ...s.buttons].map((x) => x.text);
  expect(s.uses_profiles).toBe(false);
  expect(texts).not.toContain('Player');
  expect(texts).not.toContain('Who is playing?');
  expect(s.steppers.map((x) => x.label)).toEqual([
    'Interface language', 'Word language', 'Start grade', 'Colour', 'Text size', 'Sound',
  ]);
  button(s, '[ START ]');
});

test('menu: the start grade picker reacts to taps and START uses it', async ({ page }, info) => {
  let s = await openGame(page);
  const before = stepper(s, 'Start grade').value;
  await press(page, info, stepper(s, 'Start grade').next);
  await expect.poll(async () => stepper(await state(page), 'Start grade').value).not.toBe(before);
  s = await state(page);
  const chosen = s.start_grade;
  await press(page, info, button(s, '[ START ]').rect);
  const g = await waitForScene(page, 'game');
  expect(g.game!.grade).toBe(chosen);
  expect(g.game!.stage).toBe(1);
});

test('input: touch devices get the game keyboard, desktop gets none', async ({ page }, info) => {
  const g = await startGame(page, info);
  if (isTouch(info)) {
    expect(g.input_mode).toBe('osk');
    expect(g.game!.keyboard, 'on-screen keyboard shown').not.toBeNull();
  } else {
    expect(g.input_mode).toBe('keys');
    expect(g.game!.keyboard, 'no on-screen keyboard on desktop').toBeNull();
  }
});

test('input: taps never focus a page text field (the phone keyboard stays closed)', async ({ page }, info) => {
  const g = await startGame(page, info);
  const spots = [g.game!.playfield, g.game!.hud];
  if (g.game!.keyboard) spots.push(...g.game!.keyboard.keys.slice(0, 5).map((k) => k.rect));
  for (const r of spots) {
    await press(page, info, r);
    expect(await focusedTag(page)).not.toMatch(/^(INPUT|TEXTAREA)$/);
  }
  expect(await page.locator('input, textarea').count(), 'no text fields in the page').toBe(0);
});

test('layout: HUD, playfield and keyboard fit the screen without overlapping', async ({ page }, info) => {
  const g = (await startGame(page, info)).game!;
  const box = await canvasBox(page);
  expect(inside(g.hud, box), 'HUD on screen').toBe(true);
  expect(inside(g.playfield, box), 'playfield on screen').toBe(true);
  expect(g.playfield[3], 'playfield gets a real share of the height').toBeGreaterThan(box.ch * 0.3);
  if (g.keyboard) {
    expect(inside(g.keyboard.rect, box), 'keyboard on screen').toBe(true);
    for (const k of g.keyboard.keys) expect(inside(k.rect, box), `key ${k.ch} on screen`).toBe(true);
    expect(g.keyboard.rect[1], 'keyboard below the playfield').toBeGreaterThanOrEqual(g.playfield[1] + g.playfield[3] - 1);
  }
});

test('play: typing a falling word destroys it and scores', async ({ page }, info) => {
  await startGame(page, info);
  await expect.poll(async () => (await state(page)).game!.words.length, { timeout: 15_000 }).toBeGreaterThan(0);
  if (!isTouch(info)) await page.locator('canvas').click({ position: { x: 5, y: 5 } }); // keyboard focus
  for (let i = 0; i < 6; i++) {
    const g = (await state(page)).game!;
    if (g.words_done > 0) break;
    const w = g.words.find((x) => x.typed > 0) ?? g.words[0];
    if (!w) continue;
    const rest = w.text.slice(w.typed);
    if (g.keyboard) {
      for (const ch of rest) {
        const key = g.keyboard.keys.find((k) => k.ch === ch);
        expect(key, `key "${ch}" on the game keyboard`).toBeTruthy();
        await press(page, info, key!.rect);
      }
    } else {
      await page.keyboard.type(rest, { delay: 30 });
    }
    await page.waitForTimeout(300);
  }
  await expect.poll(async () => (await state(page)).game!.words_done).toBeGreaterThan(0);
  expect((await state(page)).game!.score).toBeGreaterThan(0);
});

test('pause: the pause button and RESUME work by tap', async ({ page }, info) => {
  const g = await startGame(page, info);
  await press(page, info, button(g, '||').rect);
  await expect.poll(async () => (await state(page)).paused).toBe(true);
  await press(page, info, button(await state(page), 'RESUME').rect);
  await expect.poll(async () => (await state(page)).paused).toBe(false);
});
