// The /pixi/ page, in Chrome: PixiJS shows exactly what the h2d layer asks to draw.
// The page runs the debug bundle (dist/html5-test/main.js), which exposes window.rockfallerDebug.
import { test, expect } from '@playwright/test';
import { readFile } from 'node:fs/promises';

const GRIP_FRAME_TO_CATCH = 5;

test.beforeEach(async ({ page }) => {
  // Counts the Web Audio sources the page creates, without any test code in the page.
  await page.addInitScript(() => {
    window.audioSources = 0;
    const createBufferSource = AudioContext.prototype.createBufferSource;
    AudioContext.prototype.createBufferSource = function () {
      window.audioSources++;
      return createBufferSource.call(this);
    };
  });
  const debugBundle = await readFile('dist/html5-test/main.js');
  await page.route('**/pixi/main.js', (route) => route.fulfill({ body: debugBundle, contentType: 'text/javascript' }));
  await page.goto('/pixi/');
  // The duck, the grip, then the title's glyphs.
  await page.waitForFunction(() => window.rockfallerDebug?.context.drawn.length > 2);
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

/**
 * The RGBA bytes of a screen area, read back from the GPU after a render.
 * extract.canvas(), not extract.pixels(): from the screen, pixels() comes upside down.
 */
function readScreen(page, area) {
  return page.evaluate(({ x, y, width, height }) => {
    const { app } = window.rockfallerDebug;
    app.render();
    return Array.from(app.renderer.extract.canvas().getContext('2d').getImageData(x, y, width, height).data);
  }, area);
}

async function duckCentrePixel(page) {
  const { x, y } = await page.evaluate(() => ({ x: Math.round(window.rockfallerDebug.duck.x), y: Math.round(window.rockfallerDebug.duck.y) }));
  return (await readScreen(page, { x, y, width: 1, height: 1 })).slice(0, 3);
}

/** Places the colour bench, then reads it: the centre of each square, and the brightest pixel of the text. */
async function readColorBench(page) {
  const bench = await page.evaluate(() => window.rockfallerDebug.colorBench());
  await twoFrames(page);
  const centre = (index) => readScreen(page, { x: bench.x + index * 2 * bench.square + bench.square / 2, y: bench.y + bench.square / 2, width: 1, height: 1 })
    .then((pixel) => pixel.slice(0, 3));
  const textPixels = await readScreen(page, { x: bench.x, y: bench.textY, width: 200, height: Math.ceil(bench.textHeight) });
  let brightest = [0, 0, 0];
  for (let index = 0; index < textPixels.length; index += 4) {
    const pixel = textPixels.slice(index, index + 3);
    if (pixel[0] + pixel[1] + pixel[2] > brightest[0] + brightest[1] + brightest[2]) brightest = pixel;
  }
  const filtered = await page.evaluate(() => window.rockfallerDebug.renderer.sprites.filter((sprite) => sprite.visible && sprite.filters && sprite.filters.length).length);
  return {
    halfRed: await centre(0), alphaByColor: await centre(1), alphaAlone: await centre(2), invisibleRed: await centre(3), text: brightest, filtered,
    magmaOnWhite: await centre(4), magmaOnGrey: await centre(5), batchOpaque: await centre(6), batchHalf: await centre(7), batchAdded: await centre(8),
  };
}

function expectNear(actual, expected, what) {
  actual.forEach((channel, index) => expect(Math.abs(channel - expected[index]), `${what}: got ${actual}, expected ${expected}`).toBeLessThanOrEqual(1));
}

/** @spec html5.h2d.color::multiplied-color-as-tint */
test('a white text coloured 0x804020 reads (128, 64, 32) where its glyphs are full', async ({ page }) => {
  expectNear((await readColorBench(page)).text, [128, 64, 32], 'the text');
});

/** @spec html5.h2d.color::multiplied-color-as-tint */
test('a white square coloured (0.5, 1, 1) at alpha 0.5 over black reads (64, 128, 128)', async ({ page }) => {
  expectNear((await readColorBench(page)).halfRed, [64, 128, 128], 'the square');
});

/** @spec html5.h2d.color::multiplied-color-as-tint */
test('a colour that only halves the alpha reads like an alpha of 0.5', async ({ page }) => {
  const bench = await readColorBench(page);

  expectNear(bench.alphaByColor, bench.alphaAlone, 'the square halved by its colour');
  expectNear(bench.alphaAlone, [128, 128, 128], 'the square at alpha 0.5');
});

/** @spec html5.h2d.color::multiplied-color-as-tint */
test('a red square at alpha 0 leaves no trace on black', async ({ page }) => {
  expect((await readColorBench(page)).invisibleRed).toEqual([0, 0, 0]);
});

/** @spec html5.h2d.color::color-matrix-in-batch: a filter costs two render target switches */
test('no colour of the bench draws with a PixiJS filter', async ({ page }) => {
  expect((await readColorBench(page)).filtered).toBe(0);
});

// The magma colorize mixes the channels. Its pixels were read with PixiJS's ColorMatrixFilter (lot 1), which
// follows the fork's shader: they must not change when the colour moves into the batch shader.

/** @spec html5.h2d.color::color-matrix-in-batch */
test('the magma colorize turns white into (255, 198, 69) and grey into (255, 99, 35)', async ({ page }) => {
  const bench = await readColorBench(page);

  expectNear(bench.magmaOnWhite, [255, 198, 69], 'white');
  expectNear(bench.magmaOnGrey, [255, 99, 35], 'grey');
});

/** @spec html5.h2d.color::color-matrix-in-batch: the colour is not clamped before the alpha multiplies it, like the fork's blending */
test('in a colorized batch, each element keeps its own alpha', async ({ page }) => {
  const bench = await readColorBench(page);

  expectNear(bench.batchOpaque, [255, 198, 69], 'the opaque element');
  expectNear(bench.batchHalf, [255, 99, 35], 'the element at alpha 0.5');
});

/**
 * @spec html5.h2d.color::color-matrix-in-batch: the fork adds (SrcAlpha, One): grey 128 + (255+, 198, 69) x 0.5.
 * PixiJS's ColorMatrixFilter blended its result in Normal mode and lost the Add: it read (255, 163, 99).
 */
test('a colorized batch in Add mode adds its colour to the grey under it', async ({ page }) => {
  expectNear((await readColorBench(page)).batchAdded, [255, 227, 163], 'the added element');
});

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

/** @spec html5.h2d.color::color-like-fork-shader */
test('a black duck with pure red added shows pure red: PixiJS reads the added color in 0..1, like the fork', async ({ page }) => {
  await page.evaluate(() => {
    const { duck, Vector } = window.rockfallerDebug;
    // color and colorAdd are Haxe properties: their setters store them in the drawable's shader.
    duck.set_color(new Vector(0, 0, 0, 1));
    duck.set_colorAdd(new Vector(1, 0, 0, 0));
  });
  await twoFrames(page);

  expect(await duckCentrePixel(page)).toEqual([255, 0, 0]);
});

/** Where the duck's centre is on the page, in CSS pixels, whatever size the canvas is shown at. */
async function duckOnPage(page) {
  return page.evaluate(() => {
    const { app, duck } = window.rockfallerDebug;
    const box = app.view.getBoundingClientRect();
    return { x: box.left + duck.x * box.width / app.renderer.width, y: box.top + duck.y * box.height / app.renderer.height };
  });
}

const duckClicks = (page) => page.evaluate(() => window.rockfallerDebug.duckClicks());

/** @spec html5.h2d.interactive::pointer-from-canvas */
test('a mouse click on the duck reaches its Interactive', async ({ page }) => {
  const { x, y } = await duckOnPage(page);

  await page.mouse.click(x, y);

  await expect.poll(() => duckClicks(page)).toBe(1);
});

/** @spec html5.h2d.interactive::pointer-from-canvas */
test('a click beside the duck does not reach it', async ({ page }) => {
  const { x, y } = await duckOnPage(page);

  await page.mouse.click(x + 80, y);
  await twoFrames(page);

  expect(await duckClicks(page)).toBe(0);
});

/** @spec html5.h2d.interactive::pointer-from-canvas */
test('a click still reaches the duck when the page shows the canvas at half size', async ({ page }) => {
  await page.evaluate(() => { window.rockfallerDebug.app.view.style.width = '320px'; });
  const { x, y } = await duckOnPage(page);

  await page.mouse.click(x, y);

  await expect.poll(() => duckClicks(page)).toBe(1);
});

/** @spec html5.h2d.interactive::pointer-from-canvas */
test('the cursor becomes a hand over the duck', async ({ page }) => {
  const { x, y } = await duckOnPage(page);

  await page.mouse.move(x, y);

  await expect.poll(() => page.evaluate(() => window.rockfallerDebug.app.view.style.cursor)).toBe('pointer');
});

/** @spec html5::sound-starts-on-first-click */
test('the audio context waits for a gesture, then runs after the first click', async ({ page }) => {
  const stateBefore = await page.evaluate(() => window.rockfallerDebug.audio.context.state);
  const { x, y } = await duckOnPage(page);

  await page.mouse.click(x, y);

  expect(stateBefore).toBe('suspended');
  await expect.poll(() => page.evaluate(() => window.rockfallerDebug.audio.context.state)).toBe('running');
});

/** @spec html5.sound::sfx-like-flash */
test('clicking the duck once the audio runs plays its sound through Web Audio', async ({ page }) => {
  const { x, y } = await duckOnPage(page);
  await page.mouse.click(x, y);
  await expect.poll(() => page.evaluate(() => window.rockfallerDebug.audio.context.state)).toBe('running');
  const sourcesBefore = await page.evaluate(() => window.audioSources);

  await page.mouse.click(x, y);

  await expect.poll(() => page.evaluate(() => window.audioSources)).toBe(sourcesBefore + 1);
});

test.describe('on a touch screen', () => {
  test.use({ hasTouch: true });

  /** @spec html5.h2d.interactive::pointer-from-canvas */
  test('a tap on the duck reaches its Interactive', async ({ page }) => {
    const { x, y } = await duckOnPage(page);

    await page.touchscreen.tap(x, y);

    await expect.poll(() => duckClicks(page)).toBe(1);
  });
});

/** @spec html5.h2d.color::alpha-map */
test('a veil at 0.75 with a white mask darkens the duck', async ({ page }) => {
  const before = await duckCentrePixel(page);

  await page.evaluate(() => window.rockfallerDebug.spotlight(false));
  await twoFrames(page);

  const veiled = await duckCentrePixel(page);
  expect(veiled[0], `a quarter of the duck's red is left (${before} became ${veiled})`).toBeLessThan(before[0] * 0.35);
});

/** @spec html5.h2d.color::alpha-map */
test('where the mask is black, the veil leaves the duck as it was', async ({ page }) => {
  const before = await duckCentrePixel(page);

  await page.evaluate(() => window.rockfallerDebug.spotlight(true));
  await twoFrames(page);

  const spotlit = await duckCentrePixel(page);
  spotlit.forEach((channel, index) => expect(Math.abs(channel - before[index]), `channel ${index}: ${before} became ${spotlit}`).toBeLessThanOrEqual(2));
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
  const before = (await readCommandsAndSprites(page)).commands.length;

  await page.evaluate(() => window.rockfallerDebug.grip.remove());
  await twoFrames(page);

  const { commands, sprites } = await readCommandsAndSprites(page);
  expect(commands).toHaveLength(before - 1);
  expect(sprites).toHaveLength(commands.length);
});

/** The title's font, and what Canvas 2D measures for the same font. */
function readTitleFont(page) {
  return page.evaluate(() => {
    const { title } = window.rockfallerDebug;
    const font = title.font;
    const context = document.createElement('canvas').getContext('2d');
    context.font = `${font.size}px "${font.name}"`;
    const metrics = context.measureText('A');
    return {
      advance: font.getChar('A'.charCodeAt(0)).width,
      measuredAdvance: Math.ceil(metrics.width),
      lineHeight: font.lineHeight,
      measuredLineHeight: Math.ceil(metrics.fontBoundingBoxAscent + metrics.fontBoundingBoxDescent) + 1,
      accentedGlyphWidth: font.getChar(0xe9).t.width,
    };
  });
}

/** @spec html5.h2d.text::font-built-like-fork */
test('a built font has the glyph advances and line height of the fork, measured on the loaded font', async ({ page }) => {
  const font = await readTitleFont(page);

  expect(font.advance).toBe(font.measuredAdvance);
  expect(font.lineHeight).toBe(font.measuredLineHeight);
  expect(font.accentedGlyphWidth, 'é has a glyph of its own').toBeGreaterThan(0);
});

/** @spec html5.h2d.text::font-built-like-fork */
test('the title is drawn: its glyphs light pixels on the black background', async ({ page }) => {
  const area = await page.evaluate(() => {
    const { title } = window.rockfallerDebug;
    return { x: title.x, y: title.y, width: 200, height: title.font.lineHeight };
  });

  const pixels = await readScreen(page, area);

  const litPixels = pixels.filter((value, index) => index % 4 === 0 && value > 128).length;
  expect(litPixels).toBeGreaterThan(100);
});

/** @spec html5.h2d.text::font-built-like-fork: like a Flash TextField, the line's top is the font's ascent above the baseline */
test('a glyph stands on the baseline, the font ascent below the top of its tile', async ({ page }) => {
  const glyph = await page.evaluate(() => {
    const { title } = window.rockfallerDebug;
    const tile = title.font.getChar('H'.charCodeAt(0)).t;
    const canvas = tile.getTexture().pixiTexture.resource.source;
    const pixels = canvas.getContext('2d').getImageData(tile.x, tile.y, tile.width, tile.height).data;
    let lowestLitRow = -1;
    for (let index = 3; index < pixels.length; index += 4)
      if (pixels[index] > 128) lowestLitRow = Math.floor(index / 4 / tile.width);
    const context = document.createElement('canvas').getContext('2d');
    context.font = `${title.font.size}px "${title.font.name}"`;
    return { baseline: lowestLitRow + 1, ascent: context.measureText('H').fontBoundingBoxAscent };
  });

  expect(Math.abs(glyph.baseline - glyph.ascent), `baseline at ${glyph.baseline}, ascent ${glyph.ascent}`).toBeLessThanOrEqual(1);
});

/** @spec html5.h2d.text::font-built-like-fork */
test('building a font the browser has not loaded fails and names it', async ({ page }) => {
  const message = await page.evaluate(() => {
    try {
      window.rockfallerDebug.FontBuilder.getFont('Comic Platypus', 20);
      return null;
    } catch (error) {
      return String(error.message ?? error);
    }
  });

  expect(message).toContain('Comic Platypus');
});
