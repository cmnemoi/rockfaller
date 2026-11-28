// The dev server (mise run serve): serves dist/web, and rebuilds the PixiJS game when a Haxe file changes.
// Haxe writes game.js in two steps, so Vite does not watch it: once the build ends, Vite forgets the game.js
// it keeps in memory, then the page reloads. A compile error shows on the page instead.
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { defineConfig } from 'vite';

const HAXE_SOURCES = ['client', 'html5/src', 'src/com', 'data'];
const GAME = resolve('dist/web/pixi/game.js');

function rebuildGameOnHaxeChange() {
  let building = false;
  let changedWhileBuilding = false;
  return {
    name: 'rebuild-game-on-haxe-change',
    configureServer(server) {
      server.watcher.add(HAXE_SOURCES);
      const build = () => {
        if (building) return void (changedWhileBuilding = true);
        building = true;
        const haxe = spawn('mise', ['-C', 'html5', 'exec', '--', 'haxe', 'game.hxml']);
        let errors = '';
        haxe.stdout.on('data', (chunk) => (errors += chunk));
        haxe.stderr.on('data', (chunk) => (errors += chunk));
        haxe.on('close', (code) => {
          building = false;
          if (code === 0) {
            server.config.logger.info('game rebuilt', { timestamp: true });
            const graph = server.environments.client.moduleGraph;
            for (const module of graph.getModulesByFile(GAME) ?? []) graph.invalidateModule(module);
            server.ws.send({ type: 'full-reload' });
          } else {
            server.config.logger.error(errors, { timestamp: true });
            server.ws.send({ type: 'error', err: { message: errors, stack: '' } });
          }
          if (changedWhileBuilding) {
            changedWhileBuilding = false;
            build();
          }
        });
      };
      server.watcher.on('change', (file) => file.endsWith('.hx') && build());
    },
  };
}

export default defineConfig({
  root: 'dist/web',
  publicDir: false,
  server: { port: 8000, strictPort: true, watch: { ignored: [GAME] } },
  plugins: [rebuildGameOnHaxeChange()],
});
