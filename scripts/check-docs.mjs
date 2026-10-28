import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const config = JSON.parse(fs.readFileSync('docs/languages.json', 'utf8'));
const treeArg = process.argv.indexOf('--tree-file');
const baseFiles = new Set(treeArg < 0 ? [] : JSON.parse(fs.readFileSync(process.argv[treeArg + 1], 'utf8')));
const failures = [];
let links = 0;
const exists = file => fs.existsSync(path.join(root, file)) || baseFiles.has(file);
const stripCode = text => text.replace(/^(```|~~~)[^\n]*\n[\s\S]*?^\1[^\n]*$/gm, '');
const slug = value => value.toLowerCase().replace(/<[^>]+>/g, '').replace(/[^\p{L}\p{N}\p{M}_\-\s]/gu, '').replace(/\s/g, '-');
const anchors = file => {
  const found = new Set();
  const counts = new Map();
  const content = stripCode(fs.readFileSync(path.join(root, file), 'utf8'));
  for (const match of content.matchAll(/^#{1,6}\s+(.+)$/gm)) {
    const base = slug(match[1]);
    const n = counts.get(base) || 0;
    found.add(base + (n ? '-' + n : ''));
    counts.set(base, n + 1);
  }
  for (const match of content.matchAll(/(?:id|name)=["']([^"']+)["']/g)) found.add(match[1]);
  return found;
};
const walk = dir => fs.readdirSync(dir, {withFileTypes: true}).flatMap(entry => {
  if (['node_modules', '.git'].includes(entry.name)) return [];
  const file = path.join(dir, entry.name);
  return entry.isDirectory() ? walk(file) : [path.relative(root, file).split(path.sep).join('/')];
});
const markdown = walk(root).filter(file => file.endsWith('.md'));
const covered = new Set(config.aliases);
if (config.default !== 'en') failures.push('English must be the default language.');
for (const pair of config.pairs) {
  if (pair.ko !== pair.en.replace(/\.md$/, '.ko.md')) failures.push('Invalid pair: ' + pair.en);
  for (const [lang, file] of Object.entries(pair)) {
    if (covered.has(file)) failures.push('Duplicate manifest entry: ' + file);
    covered.add(file);
    if (!fs.existsSync(file)) { failures.push('Missing language edition: ' + file); continue; }
    const text = fs.readFileSync(file, 'utf8');
    const expected = `**Language / 언어:** [English](${path.posix.basename(pair.en)}) | [한국어](${path.posix.basename(pair.ko)})`;
    if (!text.split('\n').slice(0,5).includes(expected)) failures.push('Missing reciprocal selector: ' + file);
    if (text.trim().length < 120) failures.push('Empty translation: ' + file);
    const body = stripCode(text).split('\n').filter(line => !line.startsWith('**Language /')).join('\n');
    if (lang === 'en') {
      const prose = body.replace(/!?\[[^\]]*\]\([^)]+\)/g,'').replace(/`[^`]*`/g,'');
      if (/[가-힣]/.test(prose)) failures.push('Untranslated Korean prose in English edition: ' + file);
    }
  }
}
for (const file of markdown) {
  if (!covered.has(file)) failures.push('Markdown missing from language manifest: ' + file);
  const text = stripCode(fs.readFileSync(file, 'utf8'));
  for (const match of text.matchAll(/!?\[[^\]]*\]\(([^)]+)\)/g)) {
    const destination = match[1];
    if (/^(?:https?:|mailto:|data:)/.test(destination)) continue;
    const [rawPath, fragment] = destination.split('#');
    let decoded;
    try { decoded = decodeURIComponent(rawPath); } catch { failures.push('Invalid URL encoding: ' + file); continue; }
    const target = rawPath ? path.posix.normalize(path.posix.join(path.posix.dirname(file), decoded)) : file;
    links++;
    if (target.startsWith('../') || path.posix.isAbsolute(target) || !exists(target)) {
      failures.push(`${file}: missing local target ${destination}`); continue;
    }
    if (fragment && target.endsWith('.md') && fs.existsSync(target) && !anchors(target).has(decodeURIComponent(fragment))) failures.push(`${file}: missing anchor ${destination}`);
    const selector = match.index >= text.indexOf('**Language /') && match.index < text.indexOf('**Language /') + text.split('\n').find(x=>x.startsWith('**Language /'))?.length;
    if (!selector && target.endsWith('.md') && !config.aliases.includes(file)) {
      if (file.endsWith('.ko.md') && !target.endsWith('.ko.md')) failures.push(`${file}: link leaves Korean edition: ${destination}`);
      if (!file.endsWith('.ko.md') && target.endsWith('.ko.md')) failures.push(`${file}: link leaves English edition: ${destination}`);
    }
  }
}
for (const file of ['docs/SP_계정안내.html','docs/attachments/account-handout.html']) {
  const text = fs.readFileSync(file, 'utf8');
  if (/\b\d{6}\b/.test(text)) failures.push('PIN-like value in account template: ' + file);
  if (!text.includes('<html lang="en">') || !text.includes('id="ko" hidden') || !text.includes('aria-pressed="true">English')) failures.push('HTML must default to English with Korean toggle: ' + file);
}
if (failures.length) { console.error(failures.join('\n')); process.exitCode = 1; }
else console.log(`Documentation checks passed: ${config.pairs.length} language pairs, ${config.aliases.length} compatibility entries, ${links} local links.`);
