// Checks the built site (dist/web) in the Chrome already installed: run `mise run web`, then `mise run test:site`.
import { defineConfig } from '@playwright/test';

const PORT = 4173;

export default defineConfig({
  testDir: 'html5/test',
  forbidOnly: !!process.env.CI,
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    channel: 'chrome',
  },
  webServer: {
    command: `python3 -m http.server ${PORT} --bind 127.0.0.1 --directory dist/web`,
    url: `http://127.0.0.1:${PORT}/pixi/`,
    stderr: 'ignore', // python's http.server logs every request there
  },
});
