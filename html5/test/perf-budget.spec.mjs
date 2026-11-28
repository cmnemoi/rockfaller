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
