#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
const REQUIRED_VIEWPORTS = [
  { id: 'mobile', width: 320, height: 800 },
  { id: 'tablet', width: 834, height: 1112 },
  { id: 'desktop', width: 1440, height: 1000 },
];
const REQUIRED_SCENARIOS = [
  'primary',
  'dense',
  'loading',
  'empty',
  'error',
  'disabled',
  'stale-data',
  'long-text',
  'missing-value',
  'negative-number',
  'extreme-number',
  'touch-targets',
  'container-overflow',
  'keyboard-traversal',
  'focus-visibility',
  'focus-return',
  'reduced-motion',
  'rapid-toggle',
  'equivalent-200-percent-layout',
];
const ACTION_FIELDS = {
  navigate: ['type', 'path', 'waitUntil'],
  click: ['type', 'selector', 'repeat', 'delayMs'],
  keyboard: ['type', 'keys', 'repeat'],
  fill: ['type', 'selector', 'value'],
  select: ['type', 'selector', 'value'],
  wait: ['type', 'ms', 'selector', 'state'],
  viewport: ['type', 'width', 'height'],
  'reduced-motion': ['type', 'value'],
  screenshot: ['type', 'name', 'fullPage'],
  scroll: ['type', 'selector', 'block'],
};
const ASSERTION_FIELDS = {
  url: ['id', 'type', 'expected', 'mode'],
  hash: ['id', 'type', 'expected'],
  attribute: ['id', 'type', 'selector', 'name', 'expected', 'mode'],
  text: ['id', 'type', 'selector', 'expected', 'mode'],
  visibility: ['id', 'type', 'selector', 'expected'],
  count: ['id', 'type', 'selector', 'exact', 'min', 'max'],
  focus: ['id', 'type', 'selector', 'visibleIndicator'],
  'bounding-box': ['id', 'type', 'selector', 'minWidth', 'minHeight', 'topMin', 'topMax', 'withinViewport'],
  overflow: ['id', 'type', 'selector', 'axis', 'expected'],
  'aria-current': ['id', 'type', 'selector', 'value', 'exactCount'],
};

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function assertCondition(condition, message) {
  if (!condition) throw new Error(message);
}

function assertOnlyFields(value, allowed, label) {
  for (const key of Object.keys(value)) {
    assertCondition(allowed.includes(key), `${label} contains unsupported field: ${key}`);
  }
}

function requireString(value, label) {
  assertCondition(typeof value === 'string' && value.trim().length > 0, `${label} must be a non-empty string.`);
}

function requireFiniteNumber(value, label) {
  assertCondition(typeof value === 'number' && Number.isFinite(value), `${label} must be a finite number.`);
}

function validateAction(action, scenarioId, index) {
  const label = `Scenario ${scenarioId} action ${index}`;
  assertCondition(isObject(action), `${label} must be an object.`);
  requireString(action.type, `${label}.type`);
  const allowed = ACTION_FIELDS[action.type];
  assertCondition(Boolean(allowed), `${label} uses non-whitelisted type: ${action.type}`);
  assertOnlyFields(action, allowed, label);
  if (['click', 'fill', 'select', 'scroll'].includes(action.type)) requireString(action.selector, `${label}.selector`);
  if (action.type === 'navigate') requireString(action.path, `${label}.path`);
  if (action.type === 'keyboard') {
    assertCondition(Array.isArray(action.keys) && action.keys.length > 0, `${label}.keys must be a non-empty array.`);
    action.keys.forEach((key, keyIndex) => requireString(key, `${label}.keys[${keyIndex}]`));
  }
  if (action.type === 'fill' || action.type === 'select') assertCondition(typeof action.value === 'string', `${label}.value must be a string.`);
  if (action.type === 'wait') {
    assertCondition(Number.isInteger(action.ms) || typeof action.selector === 'string', `${label} requires bounded ms or selector.`);
    if (Number.isInteger(action.ms)) assertCondition(action.ms >= 0 && action.ms <= 30000, `${label}.ms is outside 0..30000.`);
  }
  if (action.type === 'viewport') {
    assertCondition(Number.isInteger(action.width) && Number.isInteger(action.height), `${label} requires integer width and height.`);
  }
  if (action.type === 'reduced-motion') assertCondition(['reduce', 'no-preference'].includes(action.value), `${label}.value is invalid.`);
  if (action.type === 'screenshot') requireString(action.name, `${label}.name`);
}

function validateAssertion(assertion, scenarioId, index) {
  const label = `Scenario ${scenarioId} assertion ${index}`;
  assertCondition(isObject(assertion), `${label} must be an object.`);
  requireString(assertion.id, `${label}.id`);
  requireString(assertion.type, `${label}.type`);
  const allowed = ASSERTION_FIELDS[assertion.type];
  assertCondition(Boolean(allowed), `${label} uses non-whitelisted type: ${assertion.type}`);
  assertOnlyFields(assertion, allowed, label);
  if (!['url', 'hash', 'overflow'].includes(assertion.type)) requireString(assertion.selector, `${label}.selector`);
  if (['url', 'hash', 'text'].includes(assertion.type)) assertCondition(typeof assertion.expected === 'string', `${label}.expected must be a string.`);
  if (assertion.type === 'attribute') {
    requireString(assertion.name, `${label}.name`);
    assertCondition(typeof assertion.expected === 'string' || assertion.expected === null, `${label}.expected must be a string or null.`);
  }
  if (assertion.type === 'visibility' || assertion.type === 'overflow') assertCondition(typeof assertion.expected === 'boolean', `${label}.expected must be boolean.`);
  if (assertion.type === 'count') assertCondition(['exact', 'min', 'max'].some((key) => Number.isInteger(assertion[key])), `${label} requires exact, min, or max.`);
  if (assertion.type === 'bounding-box') {
    ['minWidth', 'minHeight', 'topMin', 'topMax'].filter((key) => key in assertion).forEach((key) => requireFiniteNumber(assertion[key], `${label}.${key}`));
  }
  if (assertion.type === 'aria-current') {
    requireString(assertion.value, `${label}.value`);
    assertCondition(Number.isInteger(assertion.exactCount) && assertion.exactCount >= 0, `${label}.exactCount must be a non-negative integer.`);
  }
}

export function validateQaConfig(config) {
  assertCondition(isObject(config), 'QA configuration must be an object.');
  assertOnlyFields(config, ['schemaVersion', 'timeoutMs', 'viewports', 'evidenceDefinitions', 'scenarios'], 'QA configuration');
  assertCondition(config.schemaVersion === '1.0', 'QA configuration schemaVersion must be 1.0.');
  assertCondition(Array.isArray(config.viewports), 'QA configuration viewports must be an array.');
  assertCondition(Array.isArray(config.evidenceDefinitions), 'QA configuration evidenceDefinitions must be an array.');
  assertCondition(Array.isArray(config.scenarios), 'QA configuration scenarios must be an array.');
  if (config.timeoutMs !== undefined) assertCondition(Number.isInteger(config.timeoutMs) && config.timeoutMs >= 500 && config.timeoutMs <= 120000, 'timeoutMs must be an integer from 500 to 120000.');

  const viewportIds = new Set();
  for (const viewport of config.viewports) {
    assertCondition(isObject(viewport), 'Each viewport must be an object.');
    assertOnlyFields(viewport, ['id', 'width', 'height'], `Viewport ${viewport.id ?? '<unknown>'}`);
    requireString(viewport.id, 'Viewport id');
    assertCondition(!viewportIds.has(viewport.id), `Duplicate viewport id: ${viewport.id}`);
    viewportIds.add(viewport.id);
    assertCondition(Number.isInteger(viewport.width) && Number.isInteger(viewport.height), `Viewport ${viewport.id} must use integer dimensions.`);
  }
  for (const required of REQUIRED_VIEWPORTS) {
    const match = config.viewports.find((viewport) => viewport.width === required.width && viewport.height === required.height);
    assertCondition(Boolean(match), `Missing required viewport ${required.width}x${required.height}.`);
  }

  const evidenceIds = new Set();
  for (const evidence of config.evidenceDefinitions) {
    assertCondition(isObject(evidence), 'Each evidence definition must be an object.');
    assertOnlyFields(evidence, ['id', 'kind', 'description', 'path'], `Evidence definition ${evidence.id ?? '<unknown>'}`);
    requireString(evidence.id, 'Evidence definition id');
    requireString(evidence.description, `Evidence definition ${evidence.id}.description`);
    assertCondition(['product-contract', 'design-brief', 'manual-record'].includes(evidence.kind), `Evidence definition ${evidence.id} has invalid kind.`);
    assertCondition(!evidenceIds.has(evidence.id), `Duplicate evidence definition id: ${evidence.id}`);
    evidenceIds.add(evidence.id);
  }

  const scenarioIds = new Set();
  const assertionIds = new Set();
  for (const scenario of config.scenarios) {
    assertCondition(isObject(scenario), 'Each scenario must be an object.');
    assertOnlyFields(scenario, ['id', 'applicability', 'route', 'reason', 'approvedBy', 'evidenceIds', 'mode', 'actions', 'assertions'], `Scenario ${scenario.id ?? '<unknown>'}`);
    requireString(scenario.id, 'Scenario id');
    assertCondition(!scenarioIds.has(scenario.id), `Duplicate scenario id: ${scenario.id}`);
    scenarioIds.add(scenario.id);
    assertCondition(['required', 'applicable', 'not-applicable'].includes(scenario.applicability), `Scenario ${scenario.id} has invalid applicability.`);
    assertCondition(Array.isArray(scenario.actions), `Scenario ${scenario.id}.actions must be an array.`);
    assertCondition(Array.isArray(scenario.assertions), `Scenario ${scenario.id}.assertions must be an array.`);
    if (scenario.applicability === 'not-applicable') {
      requireString(scenario.reason, `Scenario ${scenario.id}.reason`);
      requireString(scenario.approvedBy, `Scenario ${scenario.id}.approvedBy`);
      assertCondition(Array.isArray(scenario.evidenceIds) && scenario.evidenceIds.length > 0, `Scenario ${scenario.id} N/A requires evidenceIds.`);
      for (const id of scenario.evidenceIds) assertCondition(evidenceIds.has(id), `Scenario ${scenario.id} references unknown evidence ID: ${id}`);
      assertCondition(scenario.actions.length === 0 && scenario.assertions.length === 0, `Scenario ${scenario.id} N/A cannot contain actions or assertions.`);
    } else {
      requireString(scenario.route, `Scenario ${scenario.id}.route`);
      assertCondition(scenario.assertions.length > 0, `Scenario ${scenario.id} must contain at least one assertion.`);
      scenario.actions.forEach((action, index) => validateAction(action, scenario.id, index));
      scenario.assertions.forEach((assertion, index) => {
        validateAssertion(assertion, scenario.id, index);
        assertCondition(!assertionIds.has(assertion.id), `Duplicate assertion id: ${assertion.id}`);
        assertionIds.add(assertion.id);
      });
    }
  }
  for (const scenarioId of REQUIRED_SCENARIOS) assertCondition(scenarioIds.has(scenarioId), `Missing required QA scenario declaration: ${scenarioId}`);
  for (const scenarioId of ['primary', 'dense', 'touch-targets', 'keyboard-traversal', 'focus-visibility', 'focus-return', 'reduced-motion', 'rapid-toggle', 'equivalent-200-percent-layout']) {
    const scenario = config.scenarios.find((candidate) => candidate.id === scenarioId);
    assertCondition(scenario.applicability === 'required', `Scenario ${scenarioId} is a universal hard gate and must be required.`);
  }
  const proxy = config.scenarios.find((scenario) => scenario.id === 'equivalent-200-percent-layout');
  assertCondition(proxy.mode === 'equivalent-200-percent-layout', 'equivalent-200-percent-layout must use the proxy mode with the same name.');
  const touchTargets = config.scenarios.find((scenario) => scenario.id === 'touch-targets');
  assertCondition(touchTargets.assertions.some((item) => item.type === 'bounding-box' && item.minWidth >= 44 && item.minHeight >= 44), 'touch-targets must assert at least 44x44 bounding-box dimensions.');
  const keyboardTraversal = config.scenarios.find((scenario) => scenario.id === 'keyboard-traversal');
  assertCondition(keyboardTraversal.actions.some((item) => item.type === 'keyboard') && keyboardTraversal.assertions.some((item) => item.type === 'focus'), 'keyboard-traversal must use keyboard actions and a focus assertion.');
  const focusVisibility = config.scenarios.find((scenario) => scenario.id === 'focus-visibility');
  assertCondition(focusVisibility.assertions.some((item) => item.type === 'focus' && item.visibleIndicator === true), 'focus-visibility must require a visible focus indicator.');
  const focusReturn = config.scenarios.find((scenario) => scenario.id === 'focus-return');
  assertCondition(focusReturn.assertions.some((item) => item.type === 'focus'), 'focus-return must assert the restored focus target.');
  const reducedMotion = config.scenarios.find((scenario) => scenario.id === 'reduced-motion');
  assertCondition(reducedMotion.actions.some((item) => item.type === 'reduced-motion' && item.value === 'reduce'), 'reduced-motion must emulate the reduce preference.');
  const rapidToggle = config.scenarios.find((scenario) => scenario.id === 'rapid-toggle');
  assertCondition(rapidToggle.actions.some((item) => item.type === 'click' && item.repeat >= 2), 'rapid-toggle must perform at least two rapid clicks.');
  const containerOverflow = config.scenarios.find((scenario) => scenario.id === 'container-overflow');
  if (containerOverflow.applicability !== 'not-applicable') {
    assertCondition(containerOverflow.assertions.some((item) => item.type === 'overflow' && typeof item.selector === 'string' && item.selector.length > 0), 'container-overflow must inspect a declared local container selector.');
  }
  return config;
}

export function makeEquivalentViewport(viewports) {
  const desktop = viewports.find((viewport) => viewport.width === 1440 && viewport.height === 1000);
  assertCondition(Boolean(desktop), 'The 1440x1000 desktop viewport is required for equivalent-200-percent-layout.');
  return { id: 'desktop-equivalent-200-percent', width: Math.floor(desktop.width / 2), height: desktop.height };
}

function parseArguments(argv) {
  const result = {};
  const allowed = new Set(['config', 'output', 'arena-id', 'style', 'candidate-generation', 'candidate-commit', 'base-url', 'validate-config']);
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    assertCondition(token.startsWith('--'), `Unexpected positional argument: ${token}`);
    const key = token.slice(2);
    assertCondition(allowed.has(key), `Unknown argument: --${key}`);
    assertCondition(index + 1 < argv.length && !argv[index + 1].startsWith('--'), `Argument --${key} requires a value.`);
    result[key] = argv[index + 1];
    index += 1;
  }
  return result;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(path.resolve(filePath), 'utf8'));
}

function sha256File(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(path.resolve(filePath))).digest('hex');
}

function sanitizeName(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, '') || 'item';
}

function evidenceRecord({ id, kind, description, filePath = null, scenarioId = null, viewportId = null, route = null }) {
  return { id, kind, description, path: filePath, scenarioId, viewportId, route };
}

function resolveUrl(baseUrl, route) {
  const resolved = new URL(route, baseUrl);
  assertCondition(['http:', 'https:', 'file:'].includes(resolved.protocol), `Unsupported navigation protocol: ${resolved.protocol}`);
  return resolved.href;
}

async function executeAction(page, action, context) {
  const timeout = context.timeoutMs;
  switch (action.type) {
    case 'navigate':
      await page.goto(resolveUrl(context.baseUrl, action.path), { waitUntil: action.waitUntil ?? 'domcontentloaded', timeout });
      break;
    case 'click':
      for (let count = 0; count < (action.repeat ?? 1); count += 1) await page.locator(action.selector).click({ delay: action.delayMs ?? 0, timeout });
      break;
    case 'keyboard':
      for (let repeat = 0; repeat < (action.repeat ?? 1); repeat += 1) for (const key of action.keys) await page.keyboard.press(key);
      break;
    case 'fill':
      await page.locator(action.selector).fill(action.value, { timeout });
      break;
    case 'select':
      await page.locator(action.selector).selectOption(action.value, { timeout });
      break;
    case 'wait':
      if (Number.isInteger(action.ms)) await page.waitForTimeout(action.ms);
      else await page.locator(action.selector).waitFor({ state: action.state ?? 'visible', timeout });
      break;
    case 'viewport':
      await page.setViewportSize({ width: action.width, height: action.height });
      break;
    case 'reduced-motion':
      await page.emulateMedia({ reducedMotion: action.value });
      break;
    case 'screenshot': {
      const screenshotPath = path.join(context.screenshotRoot, `${context.prefix}-${sanitizeName(action.name)}.png`);
      await page.screenshot({ path: screenshotPath, fullPage: action.fullPage ?? true });
      const id = `qa.${context.scenarioId}.${context.viewportId}.screenshot.${sanitizeName(action.name)}`;
      context.evidence.push(evidenceRecord({ id, kind: 'screenshot', description: `Scenario screenshot: ${action.name}`, filePath: screenshotPath, scenarioId: context.scenarioId, viewportId: context.viewportId, route: page.url() }));
      context.evidenceIds.push(id);
      break;
    }
    case 'scroll':
      await page.locator(action.selector).evaluate((element, block) => element.scrollIntoView({ block, behavior: 'instant' }), action.block ?? 'start');
      break;
    default:
      throw new Error(`Unsupported action type: ${action.type}`);
  }
}

async function executeAssertion(page, assertion) {
  let actual;
  let passed = false;
  switch (assertion.type) {
    case 'url':
      actual = page.url();
      passed = (assertion.mode ?? 'exact') === 'includes' ? actual.includes(assertion.expected) : actual === assertion.expected;
      break;
    case 'hash':
      actual = new URL(page.url()).hash;
      passed = actual === assertion.expected;
      break;
    case 'attribute':
      actual = await page.locator(assertion.selector).first().getAttribute(assertion.name);
      passed = (assertion.mode ?? 'exact') === 'includes' && typeof actual === 'string' ? actual.includes(assertion.expected) : actual === assertion.expected;
      break;
    case 'text':
      actual = (await page.locator(assertion.selector).first().innerText()).trim();
      passed = (assertion.mode ?? 'exact') === 'includes' ? actual.includes(assertion.expected) : actual === assertion.expected;
      break;
    case 'visibility':
      actual = await page.locator(assertion.selector).first().isVisible();
      passed = actual === assertion.expected;
      break;
    case 'count':
      actual = await page.locator(assertion.selector).count();
      passed = (assertion.exact === undefined || actual === assertion.exact)
        && (assertion.min === undefined || actual >= assertion.min)
        && (assertion.max === undefined || actual <= assertion.max);
      break;
    case 'focus':
      actual = await page.locator(assertion.selector).first().evaluate((element) => {
        const style = getComputedStyle(element);
        const hasOutline = style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0;
        const hasBoxShadow = style.boxShadow !== 'none';
        const borderWidths = [style.borderTopWidth, style.borderRightWidth, style.borderBottomWidth, style.borderLeftWidth].map(Number.parseFloat);
        const borderStyles = [style.borderTopStyle, style.borderRightStyle, style.borderBottomStyle, style.borderLeftStyle];
        const borderColors = [style.borderTopColor, style.borderRightColor, style.borderBottomColor, style.borderLeftColor];
        const hasVisibleBorder = borderWidths.some((width, index) => width > 0
          && !['none', 'hidden'].includes(borderStyles[index])
          && !['transparent', 'rgba(0, 0, 0, 0)'].includes(borderColors[index]));
        const indicator = hasOutline || hasBoxShadow || hasVisibleBorder;
        return { focused: document.activeElement === element, visibleIndicator: indicator };
      });
      passed = actual.focused && (assertion.visibleIndicator !== true || actual.visibleIndicator);
      break;
    case 'bounding-box': {
      actual = await page.locator(assertion.selector).first().boundingBox();
      const viewport = page.viewportSize();
      passed = actual !== null
        && (assertion.minWidth === undefined || actual.width >= assertion.minWidth)
        && (assertion.minHeight === undefined || actual.height >= assertion.minHeight)
        && (assertion.topMin === undefined || actual.y >= assertion.topMin)
        && (assertion.topMax === undefined || actual.y <= assertion.topMax)
        && (assertion.withinViewport !== true || (actual.x >= 0 && actual.y >= 0 && actual.x + actual.width <= viewport.width && actual.y + actual.height <= viewport.height));
      break;
    }
    case 'overflow':
      actual = assertion.selector
        ? await page.locator(assertion.selector).first().evaluate((element) => ({ x: element.scrollWidth > element.clientWidth + 1, y: element.scrollHeight > element.clientHeight + 1 }))
        : await page.evaluate(() => ({ x: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1, y: document.documentElement.scrollHeight > document.documentElement.clientHeight + 1 }));
      if ((assertion.axis ?? 'x') === 'both') passed = actual.x === assertion.expected && actual.y === assertion.expected;
      else passed = actual[assertion.axis ?? 'x'] === assertion.expected;
      break;
    case 'aria-current':
      actual = await page.locator(assertion.selector).evaluateAll((elements, value) => elements.filter((element) => element.getAttribute('aria-current') === value).length, assertion.value);
      passed = actual === assertion.exactCount;
      break;
    default:
      throw new Error(`Unsupported assertion type: ${assertion.type}`);
  }
  return { id: assertion.id, type: assertion.type, status: passed ? 'PASS' : 'FAIL', expected: assertion.expected ?? null, actual };
}

async function runAxe(page, axeSource) {
  await page.addScriptTag({ content: axeSource });
  return page.evaluate(async () => {
    const result = await globalThis.axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'] } });
    return result.violations.map((violation) => ({ id: violation.id, impact: violation.impact, description: violation.description, nodes: violation.nodes.length }));
  });
}

function newBaseResult(args, configPath, outputRoot) {
  return {
    schemaVersion: '1.0',
    arenaId: args['arena-id'],
    style: args.style,
    candidateGeneration: Number(args['candidate-generation']),
    candidateCommit: args['candidate-commit'],
    generatedAt: new Date().toISOString(),
    configSha256: sha256File(configPath),
    baseUrl: args['base-url'],
    outputRoot,
    overall: 'BLOCKED',
    environmentBlocked: false,
    blocker: null,
    proxyDisclosure: { name: 'equivalent-200-percent-layout', isRealBrowserZoom: false, deviceScaleFactor: 1 },
    coverage: { required: 0, applicable: 0, notApplicable: 0, executed: 0, failed: 0 },
    checks: [],
    evidence: [],
    browserErrors: [],
  };
}

function writeArtifacts(result) {
  fs.mkdirSync(result.outputRoot, { recursive: true });
  const resultPath = path.join(result.outputRoot, 'qa-results.json');
  const summaryPath = path.join(result.outputRoot, 'qa-summary.md');
  const errorsPath = path.join(result.outputRoot, 'browser-errors.jsonl');
  fs.writeFileSync(resultPath, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
  const summary = [
    '# Vibe Design Arena QA Summary',
    '',
    `- Style: ${result.style}`,
    `- Candidate commit: ${result.candidateCommit}`,
    `- Overall: ${result.overall}`,
    `- Environment blocked: ${result.environmentBlocked}`,
    `- Required checks: ${result.coverage.required}`,
    `- Applicable checks: ${result.coverage.applicable}`,
    `- Not applicable: ${result.coverage.notApplicable}`,
    `- Failed checks: ${result.coverage.failed}`,
    '',
    '## Equivalent 200 percent layout disclosure',
    '',
    'This is an automated proxy: the 1440px desktop CSS viewport is halved to 720px with deviceScaleFactor=1. It is not a real Chrome UI 200% zoom test.',
    '',
    '## Checks',
    '',
    ...result.checks.map((check) => `- ${check.id}: ${check.status}`),
    '',
  ].join('\n');
  fs.writeFileSync(summaryPath, summary, 'utf8');
  fs.writeFileSync(errorsPath, result.browserErrors.map((error) => JSON.stringify(error)).join('\n') + (result.browserErrors.length ? '\n' : ''), 'utf8');
  return { resultPath, summaryPath, errorsPath };
}

export async function runQa(args) {
  for (const required of ['config', 'output', 'arena-id', 'style', 'candidate-generation', 'candidate-commit', 'base-url']) requireString(args[required], `--${required}`);
  assertCondition(['style-a', 'style-b', 'style-c'].includes(args.style), '--style must be style-a, style-b, or style-c.');
  assertCondition(Number.isInteger(Number(args['candidate-generation'])) && Number(args['candidate-generation']) >= 1, '--candidate-generation must be a positive integer.');
  assertCondition(/^[0-9a-fA-F]{40,64}$/.test(args['candidate-commit']), '--candidate-commit must be a full hexadecimal commit ID.');
  const configPath = path.resolve(args.config);
  const outputRoot = path.resolve(args.output);
  const screenshotRoot = path.join(outputRoot, 'screenshots');
  fs.mkdirSync(screenshotRoot, { recursive: true });
  const config = validateQaConfig(readJson(configPath));
  const result = newBaseResult(args, configPath, outputRoot);
  for (const item of config.evidenceDefinitions) {
    result.evidence.push(evidenceRecord({ id: item.id, kind: item.kind, description: item.description, filePath: item.path ? path.resolve(item.path) : null }));
  }

  let playwright;
  let axeSource;
  try {
    const dependencyRoot = process.env.ARENA_QA_NODE_MODULES ? path.resolve(process.env.ARENA_QA_NODE_MODULES) : null;
    const dependencyRequire = dependencyRoot ? createRequire(path.join(dependencyRoot, 'package.json')) : require;
    try { playwright = dependencyRequire('playwright'); }
    catch { playwright = dependencyRequire('playwright-core'); }
    let axePath;
    try { axePath = dependencyRequire.resolve('axe-core/axe.min.js'); }
    catch { axePath = require.resolve('axe-core/axe.min.js'); }
    axeSource = fs.readFileSync(axePath, 'utf8');
  } catch (error) {
    result.environmentBlocked = true;
    result.blocker = `QA dependencies are unavailable. Install compatible playwright or playwright-core plus axe-core packages, or point ARENA_QA_NODE_MODULES to an approved dependency root, then rerun the exact command. ${error.message}`;
    result.checks.push({ id: 'qa.environment.dependencies', scenarioId: 'environment', viewportId: null, applicability: 'required', status: 'BLOCKED', reason: result.blocker, approvedBy: null, evidenceIds: [], assertions: [] });
    result.coverage.required = 1;
    result.coverage.executed = 1;
    result.coverage.failed = 1;
    writeArtifacts(result);
    return result;
  }

  let browser;
  try {
    const launchOptions = { headless: true };
    if (process.env.ARENA_QA_BROWSER_EXECUTABLE) {
      const browserExecutable = path.resolve(process.env.ARENA_QA_BROWSER_EXECUTABLE);
      assertCondition(fs.existsSync(browserExecutable), `ARENA_QA_BROWSER_EXECUTABLE does not exist: ${browserExecutable}`);
      launchOptions.executablePath = browserExecutable;
    }
    browser = await playwright.chromium.launch(launchOptions);
  } catch (error) {
    result.environmentBlocked = true;
    result.blocker = `Playwright Chromium could not start. Install the matching browser runtime or repair environment permissions, then rerun the exact command. ${error.message}`;
    result.checks.push({ id: 'qa.environment.browser-launch', scenarioId: 'environment', viewportId: null, applicability: 'required', status: 'BLOCKED', reason: result.blocker, approvedBy: null, evidenceIds: [], assertions: [] });
    result.coverage.required = 1;
    result.coverage.executed = 1;
    result.coverage.failed = 1;
    writeArtifacts(result);
    return result;
  }

  try {
    const timeoutMs = config.timeoutMs ?? 15000;
    for (const scenario of config.scenarios) {
      if (scenario.applicability === 'not-applicable') {
        result.coverage.notApplicable += 1;
        result.checks.push({ id: `qa.${scenario.id}.not-applicable`, scenarioId: scenario.id, viewportId: null, applicability: scenario.applicability, status: 'NOT-APPLICABLE', reason: scenario.reason, approvedBy: scenario.approvedBy, evidenceIds: [...scenario.evidenceIds], assertions: [] });
        continue;
      }
      const viewports = scenario.mode === 'equivalent-200-percent-layout' ? [makeEquivalentViewport(config.viewports)] : config.viewports;
      for (const viewport of viewports) {
        if (scenario.applicability === 'required') result.coverage.required += 1;
        else result.coverage.applicable += 1;
        result.coverage.executed += 1;
        const check = { id: `qa.${scenario.id}.${viewport.id}`, scenarioId: scenario.id, viewportId: viewport.id, applicability: scenario.applicability, status: 'FAIL', reason: null, approvedBy: null, evidenceIds: [], assertions: [] };
        const page = await browser.newPage({ viewport: { width: viewport.width, height: viewport.height }, deviceScaleFactor: 1 });
        const scenarioErrors = [];
        page.on('console', (message) => {
          if (message.type() === 'error') scenarioErrors.push({ type: 'console', text: message.text(), scenarioId: scenario.id, viewportId: viewport.id, url: page.url() });
        });
        page.on('pageerror', (error) => scenarioErrors.push({ type: 'pageerror', text: error.message, scenarioId: scenario.id, viewportId: viewport.id, url: page.url() }));
        try {
          await page.goto(resolveUrl(args['base-url'], scenario.route), { waitUntil: 'domcontentloaded', timeout: timeoutMs });
          const actionContext = { timeoutMs, baseUrl: args['base-url'], screenshotRoot, prefix: `${sanitizeName(scenario.id)}-${sanitizeName(viewport.id)}`, scenarioId: scenario.id, viewportId: viewport.id, evidence: result.evidence, evidenceIds: check.evidenceIds };
          for (const action of scenario.actions) await executeAction(page, action, actionContext);
          for (const assertion of scenario.assertions) check.assertions.push(await executeAssertion(page, assertion));
          check.assertions.push(await executeAssertion(page, { id: `${scenario.id}.${viewport.id}.page-overflow-x`, type: 'overflow', axis: 'x', expected: false }));
          const axeViolations = await runAxe(page, axeSource);
          check.assertions.push({ id: `${scenario.id}.${viewport.id}.axe-wcag-a-aa`, type: 'axe', status: axeViolations.length === 0 ? 'PASS' : 'FAIL', expected: 0, actual: axeViolations });
          const axeEvidenceId = `qa.${scenario.id}.${viewport.id}.axe`;
          result.evidence.push(evidenceRecord({ id: axeEvidenceId, kind: 'axe', description: `axe WCAG A/AA result with ${axeViolations.length} violations`, scenarioId: scenario.id, viewportId: viewport.id, route: page.url() }));
          check.evidenceIds.push(axeEvidenceId);
          const screenshotPath = path.join(screenshotRoot, `${sanitizeName(scenario.id)}-${sanitizeName(viewport.id)}-final.png`);
          await page.screenshot({ path: screenshotPath, fullPage: true });
          const screenshotId = `qa.${scenario.id}.${viewport.id}.screenshot.final`;
          result.evidence.push(evidenceRecord({ id: screenshotId, kind: 'screenshot', description: 'Final rendered state screenshot', filePath: screenshotPath, scenarioId: scenario.id, viewportId: viewport.id, route: page.url() }));
          check.evidenceIds.push(screenshotId);
          if (scenarioErrors.length > 0) check.assertions.push({ id: `${scenario.id}.${viewport.id}.browser-errors`, type: 'browser-errors', status: 'FAIL', expected: 0, actual: scenarioErrors.length });
          else check.assertions.push({ id: `${scenario.id}.${viewport.id}.browser-errors`, type: 'browser-errors', status: 'PASS', expected: 0, actual: 0 });
          check.status = check.assertions.every((assertion) => assertion.status === 'PASS') ? 'PASS' : 'FAIL';
        } catch (error) {
          check.reason = error.message;
          check.assertions.push({ id: `${scenario.id}.${viewport.id}.runner`, type: 'runner', status: 'FAIL', expected: 'scenario completes', actual: error.message });
          try {
            const failurePath = path.join(screenshotRoot, `${sanitizeName(scenario.id)}-${sanitizeName(viewport.id)}-failure.png`);
            await page.screenshot({ path: failurePath, fullPage: true });
            const failureId = `qa.${scenario.id}.${viewport.id}.screenshot.failure`;
            result.evidence.push(evidenceRecord({ id: failureId, kind: 'screenshot', description: 'Failure-state screenshot', filePath: failurePath, scenarioId: scenario.id, viewportId: viewport.id, route: page.url() }));
            check.evidenceIds.push(failureId);
          } catch {
            // A crashed page may be unable to capture failure evidence.
          }
        } finally {
          result.browserErrors.push(...scenarioErrors);
          await page.close();
        }
        if (check.status !== 'PASS') result.coverage.failed += 1;
        result.checks.push(check);
      }
    }
  } finally {
    await browser.close();
  }

  result.overall = result.coverage.failed === 0 ? 'PASS' : 'FAIL';
  writeArtifacts(result);
  return result;
}

async function main() {
  const args = parseArguments(process.argv.slice(2));
  if (args['validate-config']) {
    validateQaConfig(readJson(args['validate-config']));
    process.stdout.write(`${JSON.stringify({ status: 'PASS', config: path.resolve(args['validate-config']) })}\n`);
    return;
  }
  const result = await runQa(args);
  process.stdout.write(`${JSON.stringify({ status: result.overall, resultPath: path.join(result.outputRoot, 'qa-results.json') })}\n`);
  if (result.overall !== 'PASS') process.exitCode = result.overall === 'BLOCKED' ? 2 : 1;
}

if (import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => {
    process.stderr.write(`${error.stack ?? error.message}\n`);
    process.exitCode = 1;
  });
}
