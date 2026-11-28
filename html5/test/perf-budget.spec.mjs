// Performance budgets of the game page: exact counts per rendered frame, read from the ?perf meter.
import { test, expect } from '@playwright/test';

async function startGame(page, query) {
  await page.goto(`/pixi/game.html?lang=fr${query}`);
  await expect(page.locator('.loading')).toHaveCount(0, { timeout: 30000 });
}

/** @spec html5.perf::meter-off-by-default */
test('without ?perf, the page has no meter', async ({ page }) => {
  await startGame(page, '');
  await page.waitForTimeout(1000);

  expect(await page.evaluate(() => typeof window.rockfallerPerf)).toBe('undefined');
  await expect(page.locator('#perf-meter')).toHaveCount(0);
});

/** @spec html5.perf::meter-off-by-default */
test('with ?perf, the meter counts the rendered frames and their draw calls', async ({ page }) => {
  await startGame(page, '&perf');
  await page.waitForTimeout(2000);

  const frames = await page.evaluate(() => window.rockfallerPerf.frames.slice(-30));

  expect(frames.length).toBeGreaterThan(0);
  for (const frame of frames) expect(frame.drawCalls).toBeGreaterThan(0);
});

/** @spec html5.perf::meter-off-by-default */
test('with ?perf, the meter shows the rendered frames per second', async ({ page }) => {
  await startGame(page, '&perf');

  await expect(page.locator('#perf-meter')).toContainText(/\d+ images\/s/, { timeout: 5000 });
});

// A progress with level 5 unlocked: the game opens on the map (see src/com/progress/ProgressJson.hx).
const LEVEL_5_UNLOCKED = JSON.stringify({ version: 1, unlockedLevel: 5, bestScores: { 1: 5000, 2: 5000, 3: 5000, 4: 5000 },
  tutorialsSeen: [1, 2, 3, 4, 5], inventory: { pickaxes: 1, loots: {} } });
const LOGIN_CLOSE = [606, 60];
const LEVEL_5 = [318, 213];

/** Clicks the game at its own coordinates, whatever size the page shows its canvas at. */
async function clickGame(page, [x, y]) {
  const box = await page.locator('canvas').boundingBox();
  await page.mouse.click(box.x + x * box.width / 640, box.y + y * box.height / 768);
}

/** The meter's frames over the given time, from now. */
async function framesDuring(page, ms) {
  await page.evaluate(() => { window.rockfallerPerf.frames.length = 0; });
  await page.waitForTimeout(ms);
  return page.evaluate(() => window.rockfallerPerf.frames);
}

function expectNoRenderPass(frames, screen) {
  expect(frames.length, `${screen}: frames were rendered`).toBeGreaterThan(0);
  expect(Math.max(...frames.map((frame) => frame.renderTargetSwitches)), `${screen}: render target switches per frame`).toBe(0);
  expect(Math.max(...frames.map((frame) => frame.filtered)), `${screen}: filtered sprites`).toBe(0);
}

/** @spec html5.perf::no-render-pass-on-menus */
test('the map and the level popup draw without any render target switch', async ({ page }) => {
  await page.addInitScript((progress) => localStorage.setItem('rockfaller.progress', progress), LEVEL_5_UNLOCKED);
  await startGame(page, '&perf');
  await page.waitForTimeout(3000);
  await clickGame(page, LOGIN_CLOSE);
  await page.waitForTimeout(2000);

  expectNoRenderPass(await framesDuring(page, 1000), 'the map');

  await clickGame(page, LEVEL_5);
  await page.waitForTimeout(3000);
  expectNoRenderPass(await framesDuring(page, 1000), 'the level popup');
});
