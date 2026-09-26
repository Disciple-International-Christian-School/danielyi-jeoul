#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const migrationDir = path.join(root, 'supabase', 'migrations');
const ledgerPath = path.join(root, 'supabase', 'migration-ledger.json');

function fail(message) {
  process.stderr.write(`Migration ledger check failed: ${message}\n`);
  process.exitCode = 1;
}

function migrationFiles() {
  return fs.readdirSync(migrationDir)
    .filter((name) => name.endsWith('.sql'))
    .sort();
}

const ledger = JSON.parse(fs.readFileSync(ledgerPath, 'utf8'));
const entries = Array.isArray(ledger.migrations) ? ledger.migrations : [];
const files = migrationFiles();
const fileSet = new Set(files);

if (ledger.schema_version !== 1) {
  fail(`unsupported schema_version ${ledger.schema_version}`);
}

const versions = new Set();
const trackedFiles = new Set();
let trackedCount = 0;
let liveOnlyCount = 0;

for (const entry of entries) {
  if (!/^\d{14}$/.test(entry.version ?? '')) {
    fail(`invalid migration version: ${String(entry.version)}`);
    continue;
  }

  if (versions.has(entry.version)) {
    fail(`duplicate ledger version: ${entry.version}`);
    continue;
  }
  versions.add(entry.version);

  if (entry.status === 'TRACKED') {
    trackedCount += 1;

    if (!entry.name || !/^[a-z0-9_]+$/.test(entry.name)) {
      fail(`TRACKED entry ${entry.version} has invalid name`);
      continue;
    }

    const expected = `${entry.version}_${entry.name}.sql`;
    const declared = entry.file?.replace(/^supabase\/migrations\//, '');

    if (declared !== expected) {
      fail(`TRACKED entry ${entry.version} file must be ${expected}`);
    }

    if (!fileSet.has(expected)) {
      fail(`TRACKED migration missing from Git: ${expected}`);
    }

    trackedFiles.add(expected);
    continue;
  }

  if (entry.status === 'LIVE_ONLY_DATA') {
    liveOnlyCount += 1;

    if (!entry.rationale || typeof entry.rationale !== 'string') {
      fail(`LIVE_ONLY_DATA entry ${entry.version} needs a rationale`);
    }

    const matchingVersionFiles = files.filter((name) => name.startsWith(`${entry.version}_`));
    if (matchingVersionFiles.length > 0) {
      fail(
        `LIVE_ONLY_DATA migration ${entry.version} must not have SQL committed: `
        + matchingVersionFiles.join(', '),
      );
    }

    if (entry.name_redacted === true && entry.name) {
      fail(`redacted LIVE_ONLY_DATA entry ${entry.version} must not contain name`);
    }

    continue;
  }

  fail(`unknown status for ${entry.version}: ${String(entry.status)}`);
}

for (const file of files) {
  if (!trackedFiles.has(file)) {
    fail(`Git migration is not represented as TRACKED in ledger: ${file}`);
  }
}

if (process.exitCode) {
  process.exit();
}

process.stdout.write(
  `Migration ledger OK: ${trackedCount} tracked structural migrations, `
  + `${liveOnlyCount} live-only data migrations, ${files.length} SQL files.\n`,
);
