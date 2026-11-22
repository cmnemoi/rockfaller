// The game itself, built for the browser: it preloads its assets, then starts on its first screen.
import { test, expect } from '@playwright/test';

/** @spec html5.boot::everything-preloaded */
test('the game preloads its assets and starts without a JavaScript error', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()); });

  await page.goto('/pixi/game.html?lang=fr');

  await expect(page.locator('.loading')).toHaveCount(0, { timeout: 30000 });
  await expect(page.locator('canvas')).toHaveCount(1);
  await page.waitForTimeout(3000); // the preloader's steps, then the first screen
  expect(errors).toEqual([]);
});
