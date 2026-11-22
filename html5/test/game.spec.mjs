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

/** @spec html5::sound-starts-on-first-click: level 1's music starts before the player's first click */
test('the music started before the first click is heard once the player clicks', async ({ page }) => {
  // Notes the length of every buffer Web Audio starts, without any test code in the game.
  await page.addInitScript(() => {
    window.startedSeconds = [];
    const start = AudioBufferSourceNode.prototype.start;
    AudioBufferSourceNode.prototype.start = function (...args) {
      window.startedSeconds.push(this.buffer ? this.buffer.duration : 0);
      return start.apply(this, args);
    };
  });
  await page.goto('/pixi/game.html?lang=fr');
  await expect(page.locator('.loading')).toHaveCount(0, { timeout: 30000 });
  await page.waitForTimeout(3000);
  const box = await page.locator('canvas').boundingBox();

  await page.mouse.click(box.x + 10, box.y + box.height - 10);

  await expect.poll(() => page.evaluate(() => window.startedSeconds.filter((seconds) => seconds > 30).length)).toBeGreaterThan(0);
});
