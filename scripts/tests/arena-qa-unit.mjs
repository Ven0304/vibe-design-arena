import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeEquivalentViewport, validateQaConfig } from '../arena-qa.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const fixturePath = path.resolve(here, '../fixtures/chapter-scrollspy-qa-config.json');
const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));

validateQaConfig(fixture);
assert.deepEqual(makeEquivalentViewport(fixture.viewports), { id: 'desktop-equivalent-200-percent', width: 720, height: 1000 });

function clone(value) { return JSON.parse(JSON.stringify(value)); }
function mustReject(mutator, pattern) {
  const candidate = clone(fixture);
  mutator(candidate);
  assert.throws(() => validateQaConfig(candidate), pattern);
}

mustReject((config) => { config.scenarios.find((item) => item.id === 'stale-data').reason = ''; }, /reason/);
mustReject((config) => { config.scenarios.find((item) => item.id === 'primary').actions.push({ type: 'javascript', source: 'return true' }); }, /non-whitelisted/);
mustReject((config) => { config.viewports = config.viewports.filter((item) => item.width !== 320); }, /320x800/);
mustReject((config) => { config.scenarios.find((item) => item.id === 'equivalent-200-percent-layout').mode = 'standard'; }, /proxy mode/);
mustReject((config) => { config.scenarios.find((item) => item.id === 'loading').approvedBy = ''; }, /approvedBy/);
mustReject((config) => { config.scenarios.find((item) => item.id === 'error').evidenceIds = ['unknown-evidence']; }, /unknown evidence/);
mustReject((config) => { config.scenarios.find((item) => item.id === 'touch-targets').assertions[0].minHeight = 40; }, /44x44/);

process.stdout.write(`${JSON.stringify({ status: 'PASS', fixture: fixturePath, rejectedInvalidCases: 7 })}\n`);
