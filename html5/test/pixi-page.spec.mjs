// The /pixi/ page, in Chrome: PixiJS shows exactly what the h2d layer asks to draw.
// The page runs the debug bundle (dist/html5-test/main.js), which exposes window.rockfallerDebug.
import { test, expect } from '@playwright/test';
import { readFile } from 'node:fs/promises';

const GRIP_FRAME_TO_CATCH = 5;

test.beforeEach(async ({ page }) => {
  const debugBundle = await readFile('dist/html5-test/main.js');
  await page.route('**/pixi/main.js', (route) => route.fulfill({ body: debugBundle, contentType: 'text/javascript' }));
  await page.goto('/pixi/');
  await page.waitForFunction(() => window.rockfallerDebug?.context.drawn.length === 2);
});

/** Every draw command, next to the PixiJS sprite that shows it, read in the same frame. */
function readCommandsAndSprites(page) {
  return page.evaluate(() => {
    const { context, renderer } = window.rockfallerDebug;
    return {
      commands: context.drawn.map(({ cutX, cutY, cutWidth, cutHeight, a, b, c, d, tx, ty, alpha }) => ({ cutX, cutY, cutWidth, cutHeight, a, b, c, d, tx, ty, alpha })),
      sprites: renderer.sprites.filter((sprite) => sprite.visible).map((sprite) => {
        const { x, y, width, height } = sprite.texture.frame;
        const { a, b, c, d, tx, ty } = sprite.worldTransform;
        return { cutX: x, cutY: y, cutWidth: width, cutHeight: height, a, b, c, d, tx, ty, alpha: sprite.alpha };
      }),
    };
  });
}

function expectPixiToShowTheCommands({ commands, sprites }) {
  expect(sprites).toHaveLength(commands.length);
  commands.forEach((command, index) => {
    const sprite = sprites[index];
    for (const key of ['cutX', 'cutY', 'cutWidth', 'cutHeight', 'alpha']) expect(sprite[key], `sprite ${index} ${key}`).toBe(command[key]);
    for (const key of ['a', 'b', 'c', 'd', 'tx', 'ty']) expect(sprite[key], `sprite ${index} ${key}`).toBeCloseTo(command[key], 6);
  });
}

const twoFrames = (page) => page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));

/** @spec html5.h2d::tile-drawn-at-its-place */
test('PixiJS shows each draw command at its cut and matrix, in drawing order', async ({ page }) => {
  expectPixiToShowTheCommands(await readCommandsAndSprites(page));
});

/** @spec html5.h2d::flip-keeps-pivot */
test('PixiJS shows a rotated, flipped, half-transparent sprite with its whole matrix and alpha', async ({ page }) => {
  // Without rotation, b and c stay 0 and a renderer that swapped them would pass.
  // Haxe properties go through their setters, which mark the position as changed.
  await page.evaluate(() => {
    const { duck } = window.rockfallerDebug;
    duck.set_rotation(0.3);
    duck.set_scaleX(-1.5);
    duck.alpha = 0.5;
  });
  await twoFrames(page);

  const drawn = await readCommandsAndSprites(page);

  expect(drawn.commands.some(({ b, c }) => b !== 0 && c !== 0 && b !== c), 'the duck is drawn rotated').toBe(true);
  expectPixiToShowTheCommands(drawn);
});

/** The colour drawn at the duck's centre, read back from the GPU. */
function duckCentrePixel(page) {
  return page.evaluate(() => {
    const { app, duck } = window.rockfallerDebug;
    app.render();
    const width = app.renderer.width;
    const pixels = app.renderer.extract.pixels();
    const index = (Math.round(duck.y) * width + Math.round(duck.x)) * 4;
    return Array.from(pixels.slice(index, index + 3));
  });
}

/** @spec html5.h2d.color::blend-mode-like-fork */
test('a SoftOverlay sprite over black leaves black, as the DstColor + One factors of the fork do', async ({ page }) => {
  const normal = await duckCentrePixel(page);

  await page.evaluate(() => {
    const { duck, BlendMode } = window.rockfallerDebug;
    duck.blendMode = BlendMode.SoftOverlay;
  });
  await twoFrames(page);
  const softOverlay = await duckCentrePixel(page);

  expect(normal.some((channel) => channel > 100), `the duck shows in Normal mode (got ${normal})`).toBe(true);
  expect(softOverlay).toEqual([0, 0, 0]);
});

/** @spec html5.slb::page-plays-grip-anim */
test('PixiJS shows the grip animation frame the SpriteLib is on', async ({ page }) => {
  const caught = await page.waitForFunction((frameToCatch) => {
    const { grip, renderer } = window.rockfallerDebug;
    if (grip.frame !== frameToCatch) return null;
    const { x, y, width, height } = renderer.sprites[1].texture.frame;
    const frame = grip.frameData;
    return { shown: [x, y, width, height], expected: [frame.x, frame.y, frame.wid, frame.hei] };
  }, GRIP_FRAME_TO_CATCH);

  const { shown, expected } = await caught.jsonValue();
  expect(shown).toEqual(expected);
});

/** @spec html5.h2d::positions-compose */
test('a sprite removed from the scene disappears from PixiJS', async ({ page }) => {
  await page.evaluate(() => window.rockfallerDebug.grip.remove());
  await twoFrames(page);

  const { commands, sprites } = await readCommandsAndSprites(page);

  expect(commands).toHaveLength(1);
  expect(sprites).toHaveLength(1);
});
