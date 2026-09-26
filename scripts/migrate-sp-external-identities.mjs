#!/usr/bin/env node

import { createClient } from '@supabase/supabase-js';

const APPLY = process.argv.includes('--apply');
const SOURCE_SYSTEM = 'STUDY_PLANNER';
const DEFAULT_SP_PROJECT_REF = 'wqvtgrcwiumglohbybih';
const EXCLUDED_LOGIN_IDS = new Set(['T01', 'T02', 'T03', 'T04', 'T05', 'DEV1']);

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function clean(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function duplicates(values) {
  const seen = new Set();
  const dup = new Set();
  for (const value of values) {
    if (seen.has(value)) dup.add(value);
    seen.add(value);
  }
  return dup;
}

function summary(label, value) {
  process.stdout.write(`${label.padEnd(34)} ${value}\n`);
}

async function main() {
  const sp = createClient(
    required('SP_SUPABASE_URL'),
    required('SP_SUPABASE_SERVICE_ROLE_KEY'),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const core = createClient(
    required('CORE_SUPABASE_URL'),
    required('CORE_SUPABASE_SERVICE_ROLE_KEY'),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const spProjectRef = process.env.SP_PROJECT_REF || DEFAULT_SP_PROJECT_REF;

  // The source query intentionally includes no name, email, PIN, or profile PII.
  const { data: sourceRows, error: sourceError } = await sp
    .from('students')
    .select('id,student_no,core_student_id');

  if (sourceError) {
    throw new Error(
      'Unable to read SP identity bridge columns. Apply the SP Core bridge migration first. ' +
      sourceError.message,
    );
  }

  const { data: coreRows, error: coreError } = await core
    .schema('core')
    .from('students')
    .select('id,student_no')
    .not('student_no', 'is', null);

  if (coreError) throw new Error(`Unable to read Core students: ${coreError.message}`);

  const realSource = sourceRows.filter((row) => {
    const login = clean(row.student_no);
    return login && !EXCLUDED_LOGIN_IDS.has(login);
  });

  const sourceStudentNos = realSource.map((row) => clean(row.student_no));
  const sourceDup = duplicates(sourceStudentNos);
  if (sourceDup.size > 0) {
    throw new Error(
      `Aborting: duplicate real-student student_no values exist in SP source (count=${sourceDup.size}).`,
    );
  }

  const coreByStudentNo = new Map();
  for (const row of coreRows) {
    const studentNo = clean(row.student_no);
    if (!studentNo) continue;
    if (coreByStudentNo.has(studentNo)) {
      throw new Error('Aborting: duplicate student_no detected in Core.');
    }
    coreByStudentNo.set(studentNo, row.id);
  }

  const matched = [];
  let unmatched = 0;
  let sourceBridgeAlreadyCorrect = 0;
  let sourceBridgeConflict = 0;

  for (const row of realSource) {
    const studentNo = clean(row.student_no);
    const coreStudentId = coreByStudentNo.get(studentNo);

    if (!coreStudentId) {
      unmatched += 1;
      continue;
    }

    if (row.core_student_id && row.core_student_id !== coreStudentId) {
      sourceBridgeConflict += 1;
      continue;
    }

    if (row.core_student_id === coreStudentId) {
      sourceBridgeAlreadyCorrect += 1;
    }

    matched.push({
      sourceUserId: row.id,
      studentNo,
      coreStudentId,
    });
  }

  if (sourceBridgeConflict > 0) {
    throw new Error(
      `Aborting: SP core_student_id conflicts detected (count=${sourceBridgeConflict}). No writes performed.`,
    );
  }

  const { data: existingExternal, error: externalError } = await core
    .schema('core')
    .from('external_auth_identities')
    .select('student_id,external_user_id')
    .eq('source_system', SOURCE_SYSTEM);

  if (externalError) {
    throw new Error(`Unable to read Core external identity bridge: ${externalError.message}`);
  }

  const externalByUser = new Map(existingExternal.map((row) => [row.external_user_id, row.student_id]));
  const externalByStudent = new Map(existingExternal.map((row) => [row.student_id, row.external_user_id]));

  let externalConflict = 0;
  let externalAlreadyCorrect = 0;

  for (const row of matched) {
    const byUser = externalByUser.get(row.sourceUserId);
    const byStudent = externalByStudent.get(row.coreStudentId);

    if ((byUser && byUser !== row.coreStudentId)
      || (byStudent && byStudent !== row.sourceUserId)) {
      externalConflict += 1;
      continue;
    }

    if (byUser === row.coreStudentId && byStudent === row.sourceUserId) {
      externalAlreadyCorrect += 1;
    }
  }

  if (externalConflict > 0) {
    throw new Error(
      `Aborting: external identity conflicts detected (count=${externalConflict}). No writes performed.`,
    );
  }

  summary('Mode', APPLY ? 'APPLY' : 'DRY RUN');
  summary('SP total rows', sourceRows.length);
  summary('Excluded non-student rows', sourceRows.length - realSource.length);
  summary('Real source students', realSource.length);
  summary('Core students with student_no', coreRows.length);
  summary('Exact student_no matches', matched.length);
  summary('Unmatched source students', unmatched);
  summary('SP bridge already correct', sourceBridgeAlreadyCorrect);
  summary('External bridge already correct', externalAlreadyCorrect);
  summary('Conflicts', 0);

  if (!APPLY) {
    process.stdout.write('\nDry run only. Re-run with --apply after reviewing aggregate counts.\n');
    return;
  }

  if (matched.length === 0) {
    process.stdout.write('\nNothing to apply.\n');
    return;
  }

  // Cross-project writes cannot be wrapped in one distributed transaction.
  // Both sides are therefore written idempotently so an interrupted run can
  // safely be repeated.

  const now = new Date().toISOString();
  const targetRows = matched.map((row) => ({
    student_id: row.coreStudentId,
    source_system: SOURCE_SYSTEM,
    source_project_ref: spProjectRef,
    external_user_id: row.sourceUserId,
    external_login_id: row.studentNo,
    is_active: true,
    last_verified_at: now,
  }));

  const { error: upsertError } = await core
    .schema('core')
    .from('external_auth_identities')
    .upsert(targetRows, {
      onConflict: 'source_system,external_user_id',
      ignoreDuplicates: false,
    });

  if (upsertError) {
    throw new Error(`Core external identity upsert failed: ${upsertError.message}`);
  }

  let sourceUpdated = 0;
  for (const row of matched) {
    if (row.coreStudentId === realSource.find((source) => source.id === row.sourceUserId)?.core_student_id) {
      continue;
    }

    const { error: updateError } = await sp
      .from('students')
      .update({ core_student_id: row.coreStudentId })
      .eq('id', row.sourceUserId);

    if (updateError) {
      throw new Error(
        'SP bridge update failed after Core upsert. Re-run is safe because the Core write is idempotent. ' +
        updateError.message,
      );
    }
    sourceUpdated += 1;
  }

  const { count: externalCount, error: countError } = await core
    .schema('core')
    .from('external_auth_identities')
    .select('*', { count: 'exact', head: true })
    .eq('source_system', SOURCE_SYSTEM)
    .eq('is_active', true);

  if (countError) throw new Error(`Post-apply verification failed: ${countError.message}`);

  process.stdout.write('\nApply completed.\n');
  summary('Core external links now', externalCount ?? 0);
  summary('SP bridge rows updated', sourceUpdated);
  summary('Expected exact mappings', matched.length);
}

main().catch((error) => {
  process.stderr.write(`Identity migration failed: ${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});
