// node shots.js '<json [[name, js, waitMs]...]>' outdir  — every shot starts from a fresh page, signed in unless js starts with "!"
const chromium = require('@sparticuz/chromium').default || require('@sparticuz/chromium');
const puppeteer = require('puppeteer-core'); const fs = require('fs');
(async () => {
  const steps = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')), out = process.argv[3]; fs.mkdirSync(out, { recursive: true });
  const browser = await puppeteer.launch({ args: [...chromium.args, '--no-sandbox'], executablePath: await chromium.executablePath(), headless: 'shell' });
  for (const [name, js, wait = 500] of steps) {
    const page = await browser.newPage(); await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 1.5 });
    const errs = []; page.on('pageerror', e => errs.push(String(e).slice(0, 200)));
    await page.goto('file:///home/claude/work/indie_preview.html', { waitUntil: 'load' });
    try { if (!js.startsWith('!')) await page.evaluate('signIn()'); await page.evaluate(js.replace(/^!/, '')); } catch (e) { errs.push('EVAL ' + String(e).slice(0, 200)); }
    await new Promise(r => setTimeout(r, wait)); await page.screenshot({ path: `${out}/${name}.png` }); await page.close();
    console.log(name, errs.length ? 'ERRORS: ' + errs.join(' | ') : 'ok');
  }
  await browser.close();
})();
