import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runQa } from '../arena-qa.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const fixtureRoot = path.resolve(here, '../fixtures');
const configPath = path.join(fixtureRoot, 'chapter-scrollspy-qa-config.json');
const outputRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'vda-qa-scrollspy-'));
let completed = false;
const server = http.createServer((request, response) => {
  const requested = request.url === '/' ? '/chapter-scrollspy-upward.html' : request.url.split('?')[0];
  const filePath = path.resolve(fixtureRoot, `.${requested}`);
  if (!filePath.startsWith(`${fixtureRoot}${path.sep}`) || !fs.existsSync(filePath)) {
    response.writeHead(404).end('not found');
    return;
  }
  response.writeHead(200, { 'content-type': filePath.endsWith('.html') ? 'text/html; charset=utf-8' : 'application/octet-stream' });
  fs.createReadStream(filePath).pipe(response);
});

try {
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  const port = server.address().port;
  const result = await runQa({
    config: configPath,
    output: outputRoot,
    'arena-id': 'scrollspy-fixture',
    style: 'style-a',
    'candidate-generation': '1',
    'candidate-commit': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'base-url': `http://127.0.0.1:${port}/`,
  });
  if (result.overall === 'BLOCKED') {
    process.stderr.write(`${result.blocker}\n`);
    process.exitCode = 2;
  } else if (result.overall !== 'PASS') {
    const failedChecks = result.checks.filter((check) => check.status !== 'PASS' && check.status !== 'NOT-APPLICABLE');
    process.stderr.write(`${JSON.stringify({ status: result.overall, outputRoot, failedChecks }, null, 2)}\n`);
    process.exitCode = 1;
  } else {
    const scrollspy = result.checks.filter((check) => check.scenarioId === 'chapter-scrollspy-upward');
    assert.equal(scrollspy.length, 3);
    assert.ok(scrollspy.every((check) => check.status === 'PASS'));
    assert.equal(result.proxyDisclosure.isRealBrowserZoom, false);
    assert.equal(result.proxyDisclosure.deviceScaleFactor, 1);
    completed = true;
    process.stdout.write(`${JSON.stringify({ status: 'PASS', scrollspyChecks: scrollspy.length, outputRoot })}\n`);
  }
} finally {
  await new Promise((resolve) => server.close(resolve));
  if (completed) fs.rmSync(outputRoot, { recursive: true, force: true });
  else process.stderr.write(`Preserved QA evidence: ${outputRoot}\n`);
}
