import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';

const source = readFileSync(new URL('../src/lib/reflection-queue.ts', import.meta.url), 'utf8');
const javascript = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } }).outputText;
const { isDoubleReflection, reflectionIsOnNotice, reflectionMatchesFilter } =
  await import('data:text/javascript;base64,' + Buffer.from(javascript).toString('base64'));

const day = '2026-11-18';
const pending = (overrides = {}) => ({
  status: 'MISSING', isCurrentStudent: true, reflectionPages: 2,
  seondoNoticeDay: day, recordedAt: day, submissionDeadline: day,
  dueAt: '2026-11-18T08:00:00Z', submittedAt: null, ...overrides,
});
const matches = (row, filter, managed = true) => reflectionMatchesFilter(row, filter, day, managed);

const standard = pending();
assert.equal(matches(standard, 'TODAY'), true);
assert.equal(matches(standard, 'MISSING'), true);
assert.equal(matches(standard, 'DOUBLE'), false);
assert.equal(isDoubleReflection(standard), false);

const carriedDouble = pending({
  status: 'DOUBLE', recordedAt: '2026-11-16', submissionDeadline: '2026-11-17',
  seondoNoticeDay: day,
});
assert.equal(matches(carriedDouble, 'TODAY'), true, 'Double carried to today\'s notice');
assert.equal(matches(carriedDouble, 'MISSING'), true, 'All unsubmitted includes doubled');
assert.equal(matches(carriedDouble, 'DOUBLE'), true);
assert.equal(isDoubleReflection(carriedDouble), true);

const oldDouble = pending({ ...carriedDouble, seondoNoticeDay: '2026-11-17' });
assert.equal(matches(oldDouble, 'TODAY'), false, 'Managed today shows only today\'s notice');
assert.equal(matches(oldDouble, 'MISSING'), true);

const oldMissing = pending({ recordedAt: '2026-11-17', seondoNoticeDay: '2026-11-17' });
assert.equal(matches(oldMissing, 'TODAY'), false);
assert.equal(matches(oldMissing, 'MISSING'), true);

const waived = pending({ reflectionPages: 0 });
assert.equal(matches(waived, 'ALL'), false, 'Waived zero-page rows are not actionable');
assert.equal(matches(waived, 'TODAY'), false);
assert.equal(reflectionIsOnNotice(waived, day, day, true), false);

const withdrawn = pending({ isCurrentStudent: false, status: 'DOUBLE' });
assert.equal(matches(withdrawn, 'ALL'), false);
assert.equal(matches(withdrawn, 'DOUBLE'), false);

const submittedEarly = pending({ status: 'SUBMITTED', submittedAt: '2026-11-18T07:00:00Z' });
assert.equal(matches(submittedEarly, 'SUBMITTED'), true);
assert.equal(matches(submittedEarly, 'MISSING'), false);
assert.equal(matches(submittedEarly, 'TODAY'), false);
assert.equal(isDoubleReflection(submittedEarly), false);

const submittedDouble = pending({
  status: 'SUBMITTED', submittedAt: '2026-11-18T09:00:00Z',
  recordedAt: '2026-11-16',
});
assert.equal(matches(submittedDouble, 'SUBMITTED'), true);
assert.equal(matches(submittedDouble, 'DOUBLE'), false, 'Submitted is no longer overdue');
assert.equal(matches(submittedDouble, 'MISSING'), false);
assert.equal(isDoubleReflection(submittedDouble), true, 'Late completion must retain double pages');

assert.equal(matches(pending({ recordedAt: '2026-11-16', seondoNoticeDay: null, status: 'DOUBLE' }), 'TODAY', false), true, 'Legacy daily carryover');
assert.equal(matches(pending({ recordedAt: '2026-11-16', seondoNoticeDay: null, status: 'MISSING', submissionDeadline: '2026-11-17' }), 'TODAY', false), false);

console.log('Reflection queue filters and double-completion states passed.');
