import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

test('Checkpoint preserves pre-existing edits and refuses to overwrite later work', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'coa-checkpoint-test-'));
  const run = (...args) => execFileSync(process.execPath, ['tool/change_checkpoint.mjs', ...args],
    { cwd: root, encoding: 'utf8', stdio: 'pipe' });
  try {
    execFileSync('git', ['init', '-q', root]);
    fs.writeFileSync(path.join(root, '.gitignore'), '.local-backups/\n');
    fs.writeFileSync(path.join(root, 'example.txt'), 'Already edited by the user\n');
    execFileSync('git', ['add', '.'], { cwd: root });
    const checkpoint = path.join(root, '.local-backups/pre-refresh-20260909');
    fs.mkdirSync(checkpoint, { recursive: true });
    execFileSync('tar', ['-czf', path.join(checkpoint, 'before.tar.gz'), '.gitignore', 'example.txt'], { cwd: root });
    fs.mkdirSync(path.join(root, 'tool'));
    fs.copyFileSync(new URL('./change_checkpoint.mjs', import.meta.url), path.join(root, 'tool/change_checkpoint.mjs'));
    fs.writeFileSync(path.join(root, 'example.txt'), 'Refresh changes\n');
    fs.writeFileSync(path.join(root, 'added.txt'), 'New feature\n');
    run('seal');
    assert.match(run('check'), /Restore is ready/);
    fs.writeFileSync(path.join(root, 'example.txt'), 'Later user edits\n');
    assert.throws(() => run('restore'), /Nothing restored/);
    assert.equal(fs.readFileSync(path.join(root, 'example.txt'), 'utf8'), 'Later user edits\n');
    assert.ok(fs.existsSync(path.join(root, 'added.txt')));
    fs.writeFileSync(path.join(root, 'example.txt'), 'Refresh changes\n');
    assert.match(run('restore'), /Restored pre-refresh/);
    assert.equal(fs.readFileSync(path.join(root, 'example.txt'), 'utf8'), 'Already edited by the user\n');
    assert.equal(fs.existsSync(path.join(root, 'added.txt')), false);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
