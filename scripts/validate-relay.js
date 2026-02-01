#!/usr/bin/env node
// Simple validation/diagnostic script for OpenClaw Browser Relay
// Usage: node validate-relay.js --manifest ./manifest.json --gateway http://127.0.0.1:9229 --test-url https://example.com

const fs = require('fs');
const http = require('http');
const https = require('https');
const { URL } = require('url');

function parseArgs() {
  const args = require('minimist')(process.argv.slice(2));
  return {
    manifest: args.manifest || './manifest.json',
    gateway: args.gateway || 'http://127.0.0.1:9229',
    testUrl: args['test-url'] || null,
    timeout: args.timeout ? Number(args.timeout) : 3000,
  };
}

function checkManifest(path) {
  console.log('Checking manifest:', path);
  try {
    const raw = fs.readFileSync(path, 'utf8');
    const json = JSON.parse(raw);
    console.log('  manifest parsed OK. name=%s version=%s', json.name, json.version);
    if (json.content_scripts && json.content_scripts.length) {
      console.log('  content_scripts present:', json.content_scripts.map(c=>c.js).flat().join(', '));
    }
    return { ok: true, json };
  } catch (e) {
    console.error('  manifest parse error:', e.message);
    return { ok: false, error: e };
  }
}

function httpHead(url, timeout=3000) {
  return new Promise((resolve) => {
    try {
      const u = new URL(url);
      const lib = u.protocol === 'https:' ? https : http;
      const req = lib.request({ method: 'HEAD', hostname: u.hostname, port: u.port, path: u.pathname+u.search, timeout }, (res) => {
        resolve({ status: res.statusCode, headers: res.headers });
      });
      req.on('error', (err) => resolve({ error: err }));
      req.on('timeout', () => { req.destroy(); resolve({ error: new Error('timeout') }); });
      req.end();
    } catch (e) { resolve({ error: e }); }
  });
}

async function checkGateway(url, timeout) {
  console.log('Checking gateway URL reachability:', url);
  const r = await httpHead(url, timeout);
  if (r.error) {
    console.error('  Gateway not reachable:', r.error.message || r.error);
    return { ok: false, error: r.error };
  }
  console.log('  Gateway reachable. status=', r.status);
  return { ok: true, status: r.status, headers: r.headers };
}

async function checkCSP(testUrl, timeout) {
  if (!testUrl) return { ok: null };
  console.log('Checking CSP headers for:', testUrl);
  const r = await httpHead(testUrl, timeout);
  if (r.error) { console.error('  Request failed:', r.error.message||r.error); return { ok: false, error: r.error }; }
  const csp = r.headers['content-security-policy'] || r.headers['content-security-policy-report-only'];
  if (csp) {
    console.log('  CSP found:', csp);
    return { ok: true, csp };
  } else {
    console.log('  No CSP header detected (might still have CSP via meta tag).');
    return { ok: false };
  }
}

(async function main(){
  const opts = parseArgs();
  const out = { time: new Date().toISOString() };
  out.manifest = checkManifest(opts.manifest);
  out.gateway = await checkGateway(opts.gateway, opts.timeout);
  if (opts.testUrl) out.csp = await checkCSP(opts.testUrl, opts.timeout);
  const outPath = './diagnostics-relay-output.json';
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log('\nResult written to', outPath);
  if (!out.manifest.ok || (out.gateway && !out.gateway.ok)) process.exitCode = 2;
})()
