// Run after verify_admin.py. Credentials are read privately, never logged.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = path.resolve(import.meta.dirname, '..');
const directory = path.join(root, 'build/analytics');
const qa = JSON.parse(fs.readFileSync(path.join(directory, 'admin-browser-qa.json')));
const browser = await chromium.launch({headless: true, ...(process.env.CHROME_CHANNEL ? {channel: process.env.CHROME_CHANNEL} : {})});
const page = await browser.newPage({viewport: {width: 1440, height: 1100}});
const errors = [];
page.on('pageerror', () => errors.push('pageerror'));
page.on('console', message => { if (message.type() === 'error' && message.text().includes('Content Security Policy')) errors.push('CSP'); });
try {
  await page.goto(qa.Site, {waitUntil: 'networkidle'});
  await page.getByRole('button', {name: 'Sign in as administrator'}).waitFor();
  if (await page.locator('#dashboard').isVisible()) throw new Error('Report visible without login');
  await page.screenshot({path: path.join(directory, 'admin-login.png'), fullPage: true});
  await page.getByRole('button', {name: 'Sign in as administrator'}).click();
  await page.waitForURL(/amazoncognito\.com/, {timeout: 45000});
  await page.waitForLoadState('networkidle');
  if (process.argv.includes('--inspect')) {
    console.log(await page.locator('input,button').evaluateAll(nodes => nodes.map(n => ({tag: n.tagName, name: n.name, type: n.type, text: n.tagName === 'BUTTON' ? n.textContent.trim() : ''}))));
    await page.screenshot({path: path.join(directory, 'admin-cognito.png'), fullPage: true});
  } else {
    await page.locator('input[name="username"]:visible').fill(qa.username);
    await page.locator('input[name="password"]:visible').fill(qa.password);
    await page.locator('input[name="signInSubmitButton"]:visible').click();
    await page.waitForURL(qa.Site + '/**', {timeout: 45000});
    await page.locator('#dashboard').waitFor({state: 'visible', timeout: 30000});
    await page.screenshot({path: path.join(directory, 'admin-dashboard.png'), fullPage: true});
    await page.locator('#period').selectOption('current');
    await page.locator('#platform').selectOption('ios');
    if (!(await page.locator('#range').textContent()).includes('incomplete')) throw new Error('Period selection failed');
    await page.setViewportSize({width: 390, height: 844});
    await page.screenshot({path: path.join(directory, 'admin-mobile.png'), fullPage: true});
    if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)) throw new Error('Mobile overflow');
    // Exercise populated charts without writing fictitious production activity.
    const fixturePath = path.join(directory, 'admin-fixture.json');
    if (fs.existsSync(fixturePath)) {
      await page.route('**/v1/admin/overview', route => route.fulfill({status: 200, contentType: 'application/json',
        headers: {'access-control-allow-origin': qa.Site}, body: fs.readFileSync(fixturePath, 'utf8')}));
      await page.getByRole('button', {name: 'Refresh report'}).click();
      await page.locator('#songs .bar-row').first().waitFor();
      await page.locator('#period').selectOption('4');
      await page.locator('#platform').selectOption('all');
      await page.evaluate(() => { document.getElementById('status').textContent = 'QA PREVIEW · Synthetic test data, not production statistics'; });
      if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)) throw new Error('Populated mobile overflow');
      await page.screenshot({path: path.join(directory, 'admin-fixture-mobile.png'), fullPage: true});
      await page.setViewportSize({width: 1440, height: 1100});
      await page.screenshot({path: path.join(directory, 'admin-fixture-desktop.png'), fullPage: true});
      if (!(await page.locator('#playback').textContent()).includes('220 ms')) throw new Error('Playback mean calculation failed');
    }
    await page.getByRole('button', {name: 'Sign out', exact: true}).click();
    await page.waitForURL(qa.Site + '/**', {timeout: 45000});
    await page.getByRole('button', {name: 'Sign in as administrator'}).waitFor();
    if (await page.locator('#dashboard').isVisible()) throw new Error('Report remains visible after logout');
    if (errors.length) throw new Error('Browser script/CSP errors: ' + errors.join(','));
    fs.writeFileSync(path.join(directory, 'admin-browser-verification.json'), JSON.stringify({checks: [
      'unauthenticated landing hides report', 'real Cognito login', 'PKCE callback and protected report',
      'period/platform controls', 'mobile layout', 'logout hides report', 'no script or CSP errors']}, null, 2));
    console.log('PASS: real Cognito browser login, protected dashboard, filters, mobile layout and logout.');
  }
} finally { await browser.close(); }
