// Checks the /pixi/ page in headless Chrome: PixiJS shows exactly what the h2d layer asks to draw.
// Needs the site in dist/web (tools/build-web.sh) and the debug bundle in dist/html5-test (mise run html5:test:browser).
// Node 22, no dependency: a static server, Chrome, and the DevTools protocol over WebSocket.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { readFile, mkdtemp, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, extname } from 'node:path';

const root = new URL('../../', import.meta.url).pathname;
const site = join(root, 'dist/web');
const debugBundle = join(root, 'dist/html5-test/main.js');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png', '.xml': 'text/xml' };
const GRIP_FRAME_TO_CATCH = 5;

let server, chrome, profile, page;

function serveSite() {
  // The page loads main.js: the test serves the debug bundle in its place.
  server = createServer(async (request, response) => {
    const path = new URL(request.url, 'http://localhost').pathname;
    const file = path === '/pixi/main.js' ? debugBundle : join(site, path.endsWith('/') ? path + 'index.html' : path);
    try {
      response.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream' });
      response.end(await readFile(file));
    } catch {
      response.writeHead(404).end();
    }
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server.address().port)));
}

function chromePath() {
  const candidates = [process.env.CHROME, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/usr/bin/google-chrome', '/usr/bin/chromium'];
  const found = candidates.find((path) => path && existsSync(path));
  if (!found) throw new Error('Chrome not found: set CHROME to its path');
  return found;
}

async function startChrome() {
  profile = await mkdtemp(join(tmpdir(), 'rockfaller-chrome-'));
  chrome = spawn(chromePath(), ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--no-sandbox', 'about:blank'], { stdio: 'ignore' });
  const portFile = join(profile, 'DevToolsActivePort');
  for (let attempt = 0; attempt < 100 && !existsSync(portFile); attempt++) await new Promise((resolve) => setTimeout(resolve, 100));
  const [port] = (await readFile(portFile, 'utf8')).split('\n');
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  return connect(targets.find((target) => target.type === 'page').webSocketDebuggerUrl);
}

function connect(url) {
  const socket = new WebSocket(url);
  let nextId = 0;
  const pending = new Map();
  socket.onmessage = ({ data }) => {
    const message = JSON.parse(data);
    pending.get(message.id)?.(message);
    pending.delete(message.id);
  };
  const send = (method, params = {}) => new Promise((resolve) => {
    const id = ++nextId;
    pending.set(id, resolve);
    socket.send(JSON.stringify({ id, method, params }));
  });
  return new Promise((resolve) => socket.onopen = () => resolve({
    socket,
    send,
    async evaluate(expression) {
      const { result, error } = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
      if (error) throw new Error(`${error.message}: ${expression}`);
      if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description ?? result.exceptionDetails.text);
      return result.result.value;
    },
  }));
}

async function waitFor(expression, what) {
  for (let attempt = 0; attempt < 200; attempt++) {
    const value = await page.evaluate(expression);
    if (value !== null && value !== undefined && value !== false) return value;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`timed out waiting for ${what}`);
}

// Every command, next to the PixiJS sprite that shows it, read in the same frame.
const COMMANDS_AND_SPRITES = `(() => {
  const { context, renderer } = window.rockfallerDebug;
  return {
    commands: context.drawn.map(({ cutX, cutY, cutWidth, cutHeight, a, b, c, d, tx, ty, alpha }) => ({ cutX, cutY, cutWidth, cutHeight, a, b, c, d, tx, ty, alpha })),
    visibleSprites: renderer.sprites.filter((sprite) => sprite.visible).map((sprite) => {
      const { x, y, width, height } = sprite.texture.frame;
      const { a, b, c, d, tx, ty } = sprite.worldTransform;
      return { cutX: x, cutY: y, cutWidth: width, cutHeight: height, a, b, c, d, tx, ty, alpha: sprite.alpha };
    }),
  };
})()`;

const nextFrames = 'new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve(true))))';

before(async () => {
  const port = await serveSite();
  page = await startChrome();
  await page.send('Page.navigate', { url: `http://127.0.0.1:${port}/pixi/` });
  await waitFor('window.rockfallerDebug && window.rockfallerDebug.context.drawn.length === 2', 'the duck and the grip to be drawn');
});

after(async () => {
  page?.socket.close();
  if (chrome) {
    const exited = once(chrome, 'exit');
    chrome.kill();
    await exited;
  }
  server?.close();
  if (profile) await rm(profile, { recursive: true, force: true });
});

/** @spec html5.h2d::tile-drawn-at-its-place */
test('PixiJS shows each draw command at its cut and matrix, in drawing order', async () => {
  assertPixiShowsTheCommands(await page.evaluate(COMMANDS_AND_SPRITES));
});

/** @spec html5.h2d::flip-keeps-pivot */
test('PixiJS shows a rotated, flipped, half-transparent sprite with its whole matrix and alpha', async () => {
  // Without rotation, b and c stay 0 and a renderer that swapped them would pass.
  // Haxe properties go through their setters, which mark the position as changed.
  await page.evaluate('const { duck } = window.rockfallerDebug; duck.set_rotation(0.3); duck.set_scaleX(-1.5); duck.alpha = 0.5; true');
  await page.evaluate(nextFrames);

  const drawn = await page.evaluate(COMMANDS_AND_SPRITES);

  assert.ok(drawn.commands.some(({ b, c }) => b !== 0 && c !== 0 && b !== c), 'the duck is drawn rotated');
  assertPixiShowsTheCommands(drawn);
});

function assertPixiShowsTheCommands({ commands, visibleSprites }) {
  assert.equal(visibleSprites.length, commands.length);
  commands.forEach((command, index) => {
    const sprite = visibleSprites[index];
    for (const key of ['cutX', 'cutY', 'cutWidth', 'cutHeight', 'alpha']) assert.equal(sprite[key], command[key], `sprite ${index} ${key}`);
    for (const key of ['a', 'b', 'c', 'd', 'tx', 'ty']) assert.ok(Math.abs(sprite[key] - command[key]) < 1e-6, `sprite ${index} ${key}: ${sprite[key]} instead of ${command[key]}`);
  });
}

/** @spec html5.slb::page-plays-grip-anim */
test('PixiJS shows the grip animation frame the SpriteLib is on', async () => {
  const shown = await waitFor(`(() => {
    const { grip, renderer } = window.rockfallerDebug;
    if (grip.frame !== ${GRIP_FRAME_TO_CATCH}) return null;
    const { x, y, width, height } = renderer.sprites[1].texture.frame;
    const frame = grip.frameData;
    return { shown: [x, y, width, height], expected: [frame.x, frame.y, frame.wid, frame.hei] };
  })()`, `gripAnim frame ${GRIP_FRAME_TO_CATCH}`);

  assert.deepEqual(shown.shown, shown.expected);
});

/** @spec html5.h2d::positions-compose */
test('a sprite removed from the scene disappears from PixiJS', async () => {
  await page.evaluate('window.rockfallerDebug.grip.remove(); true');
  await page.evaluate(nextFrames);

  const { commands, visibleSprites } = await page.evaluate(COMMANDS_AND_SPRITES);

  assert.equal(commands.length, 1);
  assert.equal(visibleSprites.length, 1);
});
