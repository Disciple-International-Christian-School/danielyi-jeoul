import { execFileSync } from 'node:child_process';
const [base, head] = process.argv.slice(2);
if (![base, head].every(value => /^[a-f0-9]{40}$/.test(value || ''))) throw new Error('Expected full base and head commit SHAs.');
const messages = execFileSync('git', ['log', '--format=%B', `${base}..${head}`], {encoding: 'utf8'});
if (/[\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]/u.test(messages)) {
  console.error('New commit subjects and bodies must use English only. Translate Korean text before merging.');
  process.exitCode = 1;
} else console.log('New commit messages are English-only.');
