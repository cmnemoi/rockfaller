// The performance probe (mise run perf): plays the audit's screens in Chrome on the real GPU, and measures each one
// with the page's ?perf meter, a CPU profile and a heap sampling. Durations vary with the machine: not run in CI.
// Usage: node tools/perf.mjs [--throttle 4] [--texture-units 8] [--gpu-time]
// See docs/specs/html5-performance.md (the audit) and html5-performance-budgets.md.
import { chromium } from '@playwright/test';
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';

const options = parseOptions(process.argv.slice(2));
const PORT = 4175;
const PAGE = `http://127.0.0.1:${PORT}/pixi/game.html?lang=fr&perf`;
const CANVAS_ORIGIN = 16; // game.html's body padding
// A progress with level 5 unlocked: the map and level 5 are reachable (see src/com/progress/ProgressJson.hx).
const LEVEL_5_UNLOCKED = JSON.stringify({ version: 1, unlockedLevel: 5, bestScores: { 1: 5000, 2: 5000, 3: 5000, 4: 5000 },
  tutorialsSeen: [1, 2, 3, 4, 5], inventory: { pickaxes: 1, loots: {} } });
// Game coordinates of what the probe clicks.
const LOGIN_CLOSE = [606, 60];
const TUTORIAL_OK = [281, 152];
const LEVEL_5 = [318, 213];
const PLAY = [320, 692];
const GRID_CORNER = [184, 209];
const GRID_CELL = 54;

const server = spawn('python3', ['-m', 'http.server', String(PORT), '--bind', '127.0.0.1', '--directory', 'dist/web'], { stdio: 'ignore' });
const browser = await chromium.launch({ channel: 'chrome' });
const results = { options, startup: null, screens: [] };
try {
  await measureNewGame();
  await measureLevel5();
} finally {
  await browser.close();
  server.kill();
}
report(results);

async function measureNewGame() {
  const { page, cdp } = await openGame(null);
  results.startup = await startupOf(page, cdp);
  results.screens.push(await measure(page, cdp, 'tutoriel', () => page.waitForTimeout(6000)));
  results.screens.push(await measure(page, cdp, 'projecteur', async () => {
    await click(page, TUTORIAL_OK);
    await page.waitForTimeout(4000);
  }));
  await page.context().close();
}

async function measureLevel5() {
  const { page, cdp } = await openGame(LEVEL_5_UNLOCKED);
  await click(page, LOGIN_CLOSE);
  await page.waitForTimeout(2500);
  results.screens.push(await measure(page, cdp, 'carte', () => page.waitForTimeout(5000)));
  results.screens.push(await measure(page, cdp, 'défilement de la carte', async () => {
    for (let drag = 0; drag < 4; drag++) {
      await dragVertically(page, 200, 600);
      await dragVertically(page, 600, 200);
    }
  }));
  await page.waitForTimeout(1500);
  await click(page, LEVEL_5);
  await page.waitForTimeout(4000);
  results.screens.push(await measure(page, cdp, 'fenêtre du niveau 5', () => page.waitForTimeout(4000)));
  for (let attempt = 0; attempt < 3; attempt++) { // the popup's button answers once its animation ends
    await click(page, PLAY);
    await page.waitForTimeout(3000);
  }
  await page.waitForTimeout(3000);
  results.screens.push(await measure(page, cdp, 'partie', () => page.waitForTimeout(6000)));
  results.screens.push(await measure(page, cdp, 'coups', async () => {
    for (let move = 0; move < 12; move++) { // the corners of the 5 x 6 grid's groups
      await click(page, [GRID_CORNER[0] + GRID_CELL * (1 + move % 4), GRID_CORNER[1] + GRID_CELL * (1 + Math.floor(move / 4) % 5)]);
      await page.waitForTimeout(700);
    }
  }));
  mkdirSync('dist/perf', { recursive: true });
  await page.screenshot({ path: 'dist/perf/last-screen.png' }); // to check the moves were played
  await page.context().close();
}

async function openGame(progress) {
  const context = await browser.newContext({ viewport: { width: 900, height: 1000 } });
  if (progress) await context.addInitScript((saved) => localStorage.setItem('rockfaller.progress', saved), progress);
  await context.addInitScript(countDecodedSound);
  if (options.textureUnits) await context.addInitScript(limitTextureUnits, options.textureUnits);
  if (options.gpuTime) await context.addInitScript(timeGpu);
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send('Page.bringToFront'); // a hidden page gets no animation frames
  await cdp.send('Profiler.enable');
  await cdp.send('Profiler.setSamplingInterval', { interval: 200 });
  await cdp.send('HeapProfiler.enable');
  await page.goto(PAGE);
  await page.waitForFunction(() => window.rockfallerPerf && window.rockfallerPerf.frames.length > 0, null, { timeout: 120000 });
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: options.throttle });
  await page.waitForTimeout(4000);
  return { page, cdp };
}

function countDecodedSound() {
  window.decodedSoundBytes = 0;
  const decode = AudioContext.prototype.decodeAudioData;
  AudioContext.prototype.decodeAudioData = function (...args) {
    return decode.apply(this, args).then((buffer) => {
      window.decodedSoundBytes += buffer.length * buffer.numberOfChannels * 4;
      return buffer;
    });
  };
}

/** A modest phone's texture units: set before the renderer exists. */
function limitTextureUnits(units) {
  const waitForPixi = setInterval(() => {
    if (!window.PIXI) return;
    clearInterval(waitForPixi);
    PIXI.settings.SPRITE_MAX_TEXTURES = units;
  }, 1);
}

/** GPU time of each render, by EXT_disjoint_timer_query_webgl2 when the browser has it. */
function timeGpu() {
  window.gpuMs = [];
  const waitForPixi = setInterval(() => {
    if (!window.PIXI) return;
    clearInterval(waitForPixi);
    const render = PIXI.Renderer.prototype.render;
    const pending = [];
    PIXI.Renderer.prototype.render = function (...args) {
      const gl = this.gl;
      const timer = gl.getExtension('EXT_disjoint_timer_query_webgl2');
      if (!timer) return render.apply(this, args);
      for (let index = pending.length - 1; index >= 0; index--) {
        const query = pending[index];
        if (!gl.getQueryParameter(query, gl.QUERY_RESULT_AVAILABLE)) continue;
        if (!gl.getParameter(timer.GPU_DISJOINT_EXT)) window.gpuMs.push(gl.getQueryParameter(query, gl.QUERY_RESULT) / 1e6);
        gl.deleteQuery(query);
        pending.splice(index, 1);
      }
      const query = gl.createQuery();
      gl.beginQuery(timer.TIME_ELAPSED_EXT, query);
      const result = render.apply(this, args);
      gl.endQuery(timer.TIME_ELAPSED_EXT);
      pending.push(query);
      return result;
    };
  }, 1);
}

async function startupOf(page, cdp) {
  const startup = await page.evaluate(() => ({
    transferredMB: performance.getEntriesByType('resource').reduce((sum, entry) => sum + entry.transferSize, 0) / 1e6,
    decodedSoundMB: window.decodedSoundBytes / 1e6,
    programsLinked: window.rockfallerPerf.gl.programsLinked,
  }));
  startup.javascriptHeapMB = (await cdp.send('Runtime.getHeapUsage')).usedSize / 1e6;
  return startup;
}

async function measure(page, cdp, name, play) {
  await page.evaluate(() => { window.rockfallerPerf.frames.length = 0; window.gpuMs = []; });
  await cdp.send('HeapProfiler.startSampling', { samplingInterval: 4096, includeObjectsCollectedByMajorGC: true, includeObjectsCollectedByMinorGC: true });
  await cdp.send('Profiler.start');
  const start = Date.now();
  await play();
  const seconds = (Date.now() - start) / 1000;
  const { profile } = await cdp.send('Profiler.stop');
  const { profile: heap } = await cdp.send('HeapProfiler.stopSampling');
  const { frames, gpuMs } = await page.evaluate(() => ({ frames: window.rockfallerPerf.frames, gpuMs: window.gpuMs || [] }));
  const intervals = frames.slice(1).map((frame, index) => frame.at - frames[index].at);
  return {
    name,
    framesPerSecond: frames.length / seconds,
    longestFrameMs: Math.max(0, ...intervals),
    drawCalls: maximum(frames, 'drawCalls'),
    renderTargetSwitches: maximum(frames, 'renderTargetSwitches'),
    sprites: maximum(frames, 'sprites'),
    filtered: maximum(frames, 'filtered'),
    masked: maximum(frames, 'masked'),
    callbacksPerFrame: maximum(frames, 'callbacks'),
    javascriptMs: statistics(frames.map((frame) => frame.javascriptMs)),
    gpuMs: statistics(gpuMs),
    programsLinked: sum(frames, 'programsLinked'),
    textureUploads: sum(frames, 'textureUploads'),
    allocatedKBPerFrame: frames.length ? heapBytes(heap.head) / 1024 / frames.length : 0,
    topFunctions: topSelfTime(profile, 8),
  };
}

function maximum(frames, key) {
  return Math.max(0, ...frames.map((frame) => frame[key]));
}

function sum(frames, key) {
  return frames.reduce((total, frame) => total + frame[key], 0);
}

function heapBytes(node) {
  return node.selfSize + node.children.reduce((total, child) => total + heapBytes(child), 0);
}

function statistics(values) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  return { mean: values.reduce((a, b) => a + b, 0) / values.length, p95: sorted[Math.floor(0.95 * (sorted.length - 1))], max: sorted[sorted.length - 1] };
}

function topSelfTime(profile, count) {
  const nodes = new Map(profile.nodes.map((node) => [node.id, node]));
  const selfMs = new Map();
  let totalMs = 0;
  profile.samples.forEach((id, index) => {
    const frame = nodes.get(id).callFrame;
    const name = `${frame.functionName || '(anonyme)'} ${frame.url.split('/').pop()}:${frame.lineNumber + 1}`;
    const ms = (profile.timeDeltas[index] || 0) / 1000;
    totalMs += ms;
    selfMs.set(name, (selfMs.get(name) || 0) + ms);
  });
  return [...selfMs].sort((a, b) => b[1] - a[1]).slice(0, count).map(([name, ms]) => `${(100 * ms / totalMs).toFixed(1)} % ${name}`);
}

function click(page, [x, y]) {
  return page.mouse.click(CANVAS_ORIGIN + x, CANVAS_ORIGIN + y);
}

async function dragVertically(page, fromY, toY) {
  await page.mouse.move(CANVAS_ORIGIN + 320, CANVAS_ORIGIN + fromY);
  await page.mouse.down();
  await page.mouse.move(CANVAS_ORIGIN + 320, CANVAS_ORIGIN + toY, { steps: 30 });
  await page.mouse.up();
  await page.waitForTimeout(400);
}

function parseOptions(args) {
  const valueOf = (name, fallback) => (args.includes(name) ? Number(args[args.indexOf(name) + 1]) : fallback);
  return { throttle: valueOf('--throttle', 1), textureUnits: valueOf('--texture-units', 0), gpuTime: args.includes('--gpu-time') };
}

function report({ options, startup, screens }) {
  const number = (value, digits = 1) => (value == null ? '—' : value.toFixed(digits).replace('.', ','));
  const lines = [
    `Sonde du ${new Date().toISOString().slice(0, 10)} : CPU ×${options.throttle}`
      + (options.textureUnits ? `, ${options.textureUnits} unités de texture` : '') + (options.gpuTime ? ', temps GPU' : '') + '.',
    '',
    `Démarrage : ${number(startup.transferredMB)} Mo téléchargés, ${number(startup.decodedSoundMB)} Mo de sons décodés, `
      + `${startup.programsLinked} programmes liés, ${number(startup.javascriptHeapMB)} Mo de tas JS.`,
    '',
    '| Écran | Images/s | Plus longue (ms) | Appels GPU | Changements de cible | Sprites (filtrés, masqués) | Rappels/image | JS moyen / p95 (ms) | GPU moyen (ms) | Programmes | Envois | Ko alloués/image |',
    '|---|---|---|---|---|---|---|---|---|---|---|---|',
    ...screens.map((screen) => `| ${screen.name} | ${number(screen.framesPerSecond)} | ${number(screen.longestFrameMs, 0)} | ${screen.drawCalls} `
      + `| ${screen.renderTargetSwitches} | ${screen.sprites} (${screen.filtered}, ${screen.masked}) | ${screen.callbacksPerFrame} `
      + `| ${number(screen.javascriptMs?.mean, 2)} / ${number(screen.javascriptMs?.p95, 2)} | ${number(screen.gpuMs?.mean, 2)} `
      + `| ${screen.programsLinked} | ${screen.textureUploads} | ${number(screen.allocatedKBPerFrame, 0)} |`),
  ];
  mkdirSync('dist/perf', { recursive: true });
  writeFileSync('dist/perf/report.json', JSON.stringify(results, null, 1));
  writeFileSync('dist/perf/report.md', lines.join('\n') + '\n');
  console.log(lines.join('\n'));
  console.log('\nDétails (fonctions les plus coûteuses) : dist/perf/report.json');
}
