import { expect, Page, TestInfo } from '@playwright/test';

// Mirrors window.spelltowerState, published by scripts/autoload/test_bridge.gd
// in the "Web (e2e)" export. Rectangles are [x, y, w, h] in canvas pixels.
export type Rect = [number, number, number, number];
export interface Stepper { label: string; value: string; prev: Rect; next: Rect }
export interface GameState {
  level: number; grade: number; stage: number; score: number; words_done: number; over: boolean;
  words: { text: string; typed: number; rect: Rect }[];
  hud: Rect; playfield: Rect;
  keyboard: null | { rect: Rect; keys: { ch: string; rect: Rect }[] };
}
export interface State {
  scene: string; frame: number; paused: boolean; input_mode: string; uses_profiles: boolean; start_grade: number;
  buttons: { text: string; rect: Rect; disabled: boolean }[];
  labels: { text: string; rect: Rect }[];
  steppers: Stepper[];
  game?: GameState;
}

export const isTouch = (info: TestInfo) => Boolean(info.project.use.hasTouch);

export async function state(page: Page): Promise<State> {
  return page.evaluate(() => (window as any).spelltowerState);
}

/** Wait until the bridge reports a fresh state for this scene. */
export async function waitForScene(page: Page, scene: string): Promise<State> {
  await expect.poll(async () => (await state(page))?.scene, { timeout: 90_000 }).toBe(scene);
  const frame = (await state(page)).frame;
  await expect.poll(async () => (await state(page)).frame, { timeout: 10_000 }).toBeGreaterThan(frame);
  return state(page);
}

export async function openGame(page: Page): Promise<State> {
  await page.goto('/index.html');
  return waitForScene(page, 'menu');
}

/** Canvas size in canvas pixels and in page (CSS) pixels. */
export async function canvasBox(page: Page) {
  return page.evaluate(() => {
    const c = document.querySelector('canvas') as HTMLCanvasElement;
    const b = c.getBoundingClientRect();
    return { x: b.x, y: b.y, w: b.width, h: b.height, cw: c.width, ch: c.height };
  });
}

/** Centre of a canvas-pixel rectangle, in page coordinates. */
export async function toPage(page: Page, r: Rect) {
  const b = await canvasBox(page);
  return { x: b.x + (r[0] + r[2] / 2) * (b.w / b.cw), y: b.y + (r[1] + r[3] / 2) * (b.h / b.ch) };
}

/** Tap on touch devices, click elsewhere. */
export async function press(page: Page, info: TestInfo, r: Rect) {
  const p = await toPage(page, r);
  if (isTouch(info)) await page.touchscreen.tap(p.x, p.y);
  else await page.mouse.click(p.x, p.y);
}

export function button(s: State, text: string) {
  const b = s.buttons.find((x) => x.text === text);
  expect(b, `button "${text}" on screen (buttons: ${s.buttons.map((x) => x.text).join(', ')})`).toBeTruthy();
  return b!;
}

export function stepper(s: State, label: string): Stepper {
  const st = s.steppers.find((x) => x.label === label);
  expect(st, `stepper "${label}" (steppers: ${s.steppers.map((x) => x.label).join(', ')})`).toBeTruthy();
  return st!;
}

/** The page must never hold focus in a text field: that's what opens the phone's own keyboard. */
export async function focusedTag(page: Page): Promise<string> {
  return page.evaluate(() => (document.activeElement?.tagName ?? '').toUpperCase());
}

export function inside(inner: Rect, outer: { cw: number; ch: number }, slack = 1) {
  return inner[0] >= -slack && inner[1] >= -slack &&
    inner[0] + inner[2] <= outer.cw + slack && inner[1] + inner[3] <= outer.ch + slack;
}
