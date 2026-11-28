// The performance meter of the game page: off unless the address has ?perf (html5.perf::meter-off-by-default).
// Loaded before PixiJS, it counts per rendered frame what costs: draw calls, render target switches, filters,
// masks, linked programs, texture uploads, requestAnimationFrame callbacks. It shows them twice a second and
// exposes them in window.rockfallerPerf, for the tests and tools/perf.mjs.
(() => {
  if (!new URLSearchParams(location.search).has('perf')) return;

  const KEPT_FRAMES = 600;
  const gl = { drawCalls: 0, renderTargetSwitches: 0, programsLinked: 0, textureUploads: 0 };
  const perf = (window.rockfallerPerf = { frames: [], programsLinked: [], gl });
  let callbacksSinceLastFrame = 0;
  let javascriptMsSinceLastFrame = 0;

  // Callbacks per screen refresh: all callbacks of one refresh get the same time.
  perf.callbacksPerRefresh = [];
  const requestAnimationFrame = window.requestAnimationFrame.bind(window);
  window.requestAnimationFrame = (callback) => requestAnimationFrame((time) => {
    const start = performance.now();
    callback(time);
    callbacksSinceLastFrame++;
    javascriptMsSinceLastFrame += performance.now() - start;
    const refreshes = perf.callbacksPerRefresh;
    if (refreshes.length && refreshes[refreshes.length - 1].time === time) refreshes[refreshes.length - 1].callbacks++;
    else refreshes.push({ time, callbacks: 1 });
    if (refreshes.length > KEPT_FRAMES) refreshes.shift();
  });

  for (const prototype of [WebGLRenderingContext.prototype, WebGL2RenderingContext.prototype]) {
    countCalls(prototype, ['drawElements', 'drawArrays'], () => gl.drawCalls++);
    countCalls(prototype, ['bindFramebuffer'], () => gl.renderTargetSwitches++);
    countCalls(prototype, ['texImage2D', 'texSubImage2D'], () => gl.textureUploads++);
    const linkProgram = prototype.linkProgram;
    prototype.linkProgram = function (program) {
      const start = performance.now();
      linkProgram.call(this, program);
      this.getProgramParameter(program, this.LINK_STATUS); // links now, as the first draw would
      gl.programsLinked++;
      perf.programsLinked.push({ at: Math.round(performance.now()), ms: performance.now() - start });
    };
  }

  function countCalls(prototype, names, count) {
    for (const name of names) {
      const original = prototype[name];
      prototype[name] = function (...args) {
        count();
        return original.apply(this, args);
      };
    }
  }

  // PixiJS is loaded after this script: its renderer is wrapped as soon as it exists.
  const waitForPixi = setInterval(() => {
    if (!window.PIXI) return;
    clearInterval(waitForPixi);
    const render = PIXI.Renderer.prototype.render;
    PIXI.Renderer.prototype.render = function (root, ...rest) {
      perf.renderer = this; // for the checks of its settings
      const before = { ...gl };
      const start = performance.now();
      const result = render.call(this, root, ...rest);
      const target = rest[0];
      perf.frames.push({
        at: start,
        offscreen: !!(target && (target.renderTexture || target instanceof PIXI.RenderTexture)), // a picture made off the page
        pixiMs: performance.now() - start,
        javascriptMs: javascriptMsSinceLastFrame,
        callbacks: callbacksSinceLastFrame,
        drawCalls: gl.drawCalls - before.drawCalls,
        renderTargetSwitches: gl.renderTargetSwitches - before.renderTargetSwitches,
        programsLinked: gl.programsLinked - before.programsLinked,
        textureUploads: gl.textureUploads - before.textureUploads,
        ...spritesOf(root),
      });
      if (perf.frames.length > KEPT_FRAMES) perf.frames.shift();
      callbacksSinceLastFrame = 0;
      javascriptMsSinceLastFrame = 0;
      return result;
    };
  }, 1);

  function spritesOf(root) {
    let sprites = 0, filtered = 0, masked = 0;
    for (const child of root.children || []) {
      if (!child.visible) continue;
      sprites++;
      if (child.filters && child.filters.length) filtered++;
      if (child.mask) masked++;
    }
    return { sprites, filtered, masked };
  }

  const display = document.createElement('div');
  display.id = 'perf-meter';
  display.style.cssText = 'position:fixed;top:0;right:0;z-index:10;padding:4px 8px;background:rgba(0,0,0,.75);'
    + 'color:#9f9;font:12px/1.4 monospace;white-space:pre;pointer-events:none';
  document.body.appendChild(display);
  setInterval(() => {
    const now = performance.now();
    const lastSecond = perf.frames.filter((frame) => now - frame.at <= 1000);
    const last = perf.frames[perf.frames.length - 1];
    if (!last) return;
    const longest = Math.max(...lastSecond.map((frame, index) => index ? frame.at - lastSecond[index - 1].at : 0));
    display.textContent = [
      `${lastSecond.length} images/s, la plus longue ${Math.round(longest)} ms`,
      `GPU : ${last.drawCalls} appels, ${last.renderTargetSwitches} changements de cible`,
      `sprites : ${last.sprites}, ${last.filtered} filtrés, ${last.masked} masqués`,
      `JS : ${last.javascriptMs.toFixed(1)} ms par image, ${perf.callbacksPerRefresh.at(-1).callbacks} rappel(s) par rafraîchissement`,
      `depuis le début : ${gl.programsLinked} programmes, ${gl.textureUploads} envois de textures`,
    ].join('\n');
  }, 500);
})();
