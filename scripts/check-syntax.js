// npm test: 전체 .js 파일 문법 검사 (node --check)
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const SKIP = new Set(['node_modules', '.git', 'uploads']);

function collect(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (SKIP.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) collect(full, out);
    else if (entry.name.endsWith('.js')) out.push(full);
  }
  return out;
}

const files = collect(ROOT);
let failed = 0;

for (const file of files) {
  try {
    execFileSync(process.execPath, ['--check', file], { stdio: 'pipe' });
  } catch (err) {
    failed++;
    console.error(`FAIL ${path.relative(ROOT, file)}\n${err.stderr.toString()}`);
  }
}

console.log(`syntax check: ${files.length - failed}/${files.length} passed`);
process.exit(failed ? 1 : 0);
