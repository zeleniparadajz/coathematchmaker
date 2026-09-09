import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const checkpoint = path.join(root, '.local-backups/pre-refresh-20260909');
const archive = path.join(checkpoint, 'before.tar.gz');
const manifestPath = path.join(checkpoint, 'changes.json');
const command = process.argv[2] ?? 'check';
const hash = file => fs.existsSync(file)
  ? crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') : null;
const safePath = relative => {
  if (path.isAbsolute(relative) || relative.split('/').includes('..')) throw new Error('Invalid checkpoint path');
  return path.join(root, relative);
};

if (command === 'seal') {
  if (fs.existsSync(manifestPath)) throw new Error('Checkpoint is already sealed. Do not replace its hashes.');
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'coa-before-'));
  try {
    execFileSync('tar', ['-xzf', archive, '-C', temp]);
    const before = execFileSync('tar', ['-tzf', archive], {encoding: 'utf8'}).trim().split('\n');
    const current = execFileSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z'],
      {cwd: root, encoding: 'utf8'}).split('\0').filter(Boolean);
    const changes = [...new Set([...before, ...current])].sort().flatMap(relative => {
      safePath(relative);
      const beforeHash = hash(path.join(temp, relative));
      const afterHash = hash(path.join(root, relative));
      return beforeHash === afterHash ? [] : [{path: relative, before: beforeHash, after: afterHash}];
    });
    fs.writeFileSync(manifestPath, JSON.stringify({createdAt: new Date().toISOString(), changes}, null, 2) + '\n');
    console.log('Sealed checkpoint for ' + changes.length + ' changed or added files.');
  } finally { fs.rmSync(temp, {recursive: true, force: true}); }
} else if (command === 'check' || command === 'restore') {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const conflicts = manifest.changes.filter(item => hash(safePath(item.path)) !== item.after);
  if (conflicts.length) {
    console.error('Files changed since the checkpoint. Nothing restored:');
    console.error(conflicts.map(item => item.path).join('\n'));
    process.exitCode = 1;
  } else if (command === 'check') {
    console.log('Restore is ready. ' + manifest.changes.length + ' files match the saved changes. No files modified.');
  } else {
    const originals = manifest.changes.filter(item => item.before !== null).map(item => item.path);
    // Restore only files in this change set, preserving pre-existing local edits.
    execFileSync('tar', ['-xzf', archive, '-C', root, '--', ...originals]);
    for (const item of manifest.changes.filter(item => item.before === null)) {
      fs.unlinkSync(safePath(item.path));
    }
    console.log('Restored pre-refresh source files. Database, uploads and .env were not touched.');
  }
} else { throw new Error('Use seal, check or restore.'); }
