import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';

const src = readFileSync(new URL('../src/lib/seondo-notice-day.ts', import.meta.url), 'utf8');
const js = ts.transpileModule(src, { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } }).outputText;
const { selectNoticeForDay, previewReflectionStatus, canFinalizeDailyNotice, selectLiveReflectionEntries } = await import('data:text/javascript;base64,' + Buffer.from(js).toString('base64'));
const old = { notice_day: '2026-11-18', managed_date: true, batch: {day:'2026-11-18'},
  entries:[{reflection_id:18,pages:3}],preview_entries:[] };
const today = { notice_day: '2026-11-19', managed_date: true, batch: null,
  entries:[],preview_entries:[{reflection_id:19,pages:2},{reflection_id:20,pages:4,is_double:true}] };
const back = selectNoticeForDay(old,'2026-11-18',false);
assert.equal(back.valid,true);
assert.deepEqual(back.entries,[{reflection_id:18,pages:3}]);
const mismatch=selectNoticeForDay(old,'2026-11-19',true);
assert.equal(mismatch.valid,false);
assert.deepEqual(mismatch.entries,[],'Never render yesterday under today title');
const current=selectNoticeForDay(today,'2026-11-19',true);
assert.equal(current.valid,true);
assert.equal(current.preview,true);
assert.deepEqual(current.entries.map(x=>x.pages),[2,4]);
assert.deepEqual(selectNoticeForDay(old,'2026-11-18',false).entries,back.entries,'Back navigation restores frozen batch');
const afterRefresh=selectNoticeForDay({...today,preview_entries:[{reflection_id:19,pages:3}]},'2026-11-19',true);
assert.deepEqual(afterRefresh.entries.map(x=>x.pages),[3],'Open preview uses newest response');
const newBatch=selectNoticeForDay({...today,batch:{day:'2026-11-19'},entries:[{reflection_id:19,pages:2}]},'2026-11-19',true);
assert.equal(newBatch.preview,false);
assert.deepEqual(newBatch.entries.map(x=>x.pages),[2],'Published/cutoff batch freezes stored pages');
assert.equal(selectNoticeForDay({...today,batch:{day:'2026-11-18'}},'2026-11-19',true).valid,false);
console.log('Seondo notice date isolation tests passed.');
assert.equal(previewReflectionStatus(false),'MISSING','Unpublished prior-day initial items are not doubled');
assert.equal(previewReflectionStatus(true),'DOUBLE','True carried double items remain doubled');

// A prior-day unpublished draft must not prevent today's cutoff.
const todayWithPriorDraft = {...today,blocked_by_unpublished_day:'2026-11-18'};
assert.equal(canFinalizeDailyNotice(todayWithPriorDraft,'2026-11-19','2026-11-19',true,false),true);
assert.equal(canFinalizeDailyNotice(todayWithPriorDraft,'2026-11-18','2026-11-19',true,false),false);
assert.equal(canFinalizeDailyNotice(todayWithPriorDraft,'2026-11-19','2026-11-19',false,false),false);
assert.equal(canFinalizeDailyNotice(todayWithPriorDraft,'2026-11-19','2026-11-19',true,true),false);
assert.equal(canFinalizeDailyNotice({...todayWithPriorDraft,batch:{day:'2026-11-19',published_at:'2026-11-19T08:00:00Z'}},'2026-11-19','2026-11-19',true,false),false);
assert.equal(canFinalizeDailyNotice({...todayWithPriorDraft,batch:{day:'2026-11-19',published_at:null}},'2026-11-19','2026-11-19',true,false),true);

const stalePrint = { ...today, batch: { day: today.notice_day }, entries: [{reflection_id:7101,is_double:true}], live_entries: [] };
assert.deepEqual(selectLiveReflectionEntries(stalePrint, today.notice_day), [], 'Empty live queue must not resurrect cancelled or submitted print rows');
assert.deepEqual(selectLiveReflectionEntries({...stalePrint,live_entries:[{reflection_id:7102,is_double:false,pages:1}]},today.notice_day).map(x=>[x.reflection_id,x.is_double,x.pages]),[[7102,false,1]],'Replacement after cutoff stays a separate normal obligation');
assert.deepEqual(selectLiveReflectionEntries(stalePrint,'2026-11-20'),[], 'Wrong-day data must never enter current queue');
