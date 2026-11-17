import { defineConfig, devices } from '@playwright/test';

// Browser function tests for the web build.
// The game must be exported first with the "Web (e2e)" preset:
//   godot --headless --path . --export-release "Web (e2e)" build/web-e2e/index.html
// Then, from tests/e2e:  npm ci  &&  npx playwright install  &&  npx playwright test

const PORT = 8061;

// Godot's web build needs WebGL 2. Headless Chromium on machines without a GPU
// (CI runners) only provides it through SwiftShader.
const chromiumWebGL = { launchOptions: { args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] } };

export default defineConfig({
  testDir: './specs',
  timeout: 120_000,
  expect: { timeout: 30_000 },
  retries: process.env.CI ? 1 : 0,
  workers: 1, // one Godot instance at a time: software WebGL is CPU-heavy
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'pixel-7', use: { ...devices['Pixel 7'], ...chromiumWebGL } },
    { name: 'iphone-14', use: { ...devices['iPhone 14'] } },
    { name: 'desktop-chrome', use: { ...devices['Desktop Chrome'], ...chromiumWebGL } },
  ],
  webServer: {
    command: `python ../../tools/serve_web.py --port ${PORT} --dir ../../build/web-e2e`,
    url: `http://127.0.0.1:${PORT}/index.html`,
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
    stderr: 'ignore', // the server logs every request
  },
});
