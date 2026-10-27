import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import ts from 'typescript';

const source = readFileSync(new URL('../src/lib/history.ts', import.meta.url), 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext } }).outputText;
const { shiftDate, weekStart } = await import('data:text/javascript;base64,' + Buffer.from(compiled).toString('base64'));
assert.equal(weekStart('2026-10-26'), '2026-10-26');
assert.equal(weekStart('2026-10-25'), '2026-10-19');
assert.equal(weekStart('2027-01-01'), '2026-12-28');
assert.equal(shiftDate('2026-10-01', -1), '2026-09-30');
assert.equal(shiftDate('2026-12-31', 1), '2027-01-01');
assert.equal(shiftDate('2028-02-28', 1), '2028-02-29');
assert.equal(shiftDate('2026-10-26', -7), '2026-10-19');
console.log('history: 7 date boundary assertions passed');
