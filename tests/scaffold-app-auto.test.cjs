const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

// Run with: nix develop .#ci -c node --test tests/scaffold-app-auto.test.cjs
// Only the framework/package-manager commands are mocked; file copying and
// manifest validation use the real implementation and npm's semver library.
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'nix/scaffold-app-auto.nix'), 'utf8');
const nodeRoot = path.dirname(path.dirname(process.execPath));
const helper = source.match(/prepareManifest = pkgs.writeText[^\n]+ ''\n([\s\S]*?)\n  '';/)[1]
  .replace('${runtimes.nodejs}', nodeRoot);
const shell = source.match(/  text = ''\n([\s\S]*?)\n  '';/)[1]
  .replaceAll("''${", '${');
const policy = fs.readFileSync(path.join(root, 'pnpm-workspace.yaml'), 'utf8');
const pnpmVersion = '12.17.0';
const initial = {
  name: 'template', private: true, version: '0.0.0', type: 'module',
  engines: { node: process.versions.node.split('.')[0] + '.x' },
  devEngines: {
    runtime: { name: 'node', version: process.versions.node, onFail: 'warn' },
    packageManager: { name: 'pnpm', version: pnpmVersion, onFail: 'download' },
  },
};
const quote = (value) => "'" + value.replaceAll("'", "'\\''") + "'";

function fixture(t, framework, scenario = '') {
  const temp = fs.mkdtempSync(path.join(root, '.scaffold-test-'));
  t.after(() => fs.rmSync(temp, { recursive: true, force: true }));
  const project = path.join(temp, 'example-app');
  const bin = path.join(temp, 'bin');
  fs.mkdirSync(project);
  fs.mkdirSync(bin);
  fs.mkdirSync(path.join(project, '.git'));
  fs.writeFileSync(path.join(project, '.git', 'marker'), 'keep');
  fs.writeFileSync(path.join(project, 'package.json'), JSON.stringify(initial));
  fs.writeFileSync(path.join(project, 'pnpm-workspace.yaml'), policy);
  fs.writeFileSync(path.join(project, '.gitignore'), 'custom/\n');
  fs.writeFileSync(path.join(temp, 'manifest.cjs'), helper);
  fs.writeFileSync(path.join(temp, 'scaffold.sh'), shell.replaceAll('${prepareManifest}', quote(path.join(temp, 'manifest.cjs'))));
  fs.writeFileSync(path.join(bin, 'node'), '#!/bin/sh\nexec ' + quote(process.execPath) + ' "$@"\n', { mode: 0o755 });
  fs.writeFileSync(path.join(bin, 'pnpm'), '#!/bin/sh\nexec ' + quote(process.execPath) + ' ' + quote(path.join(temp, 'pnpm.cjs')) + ' "$@"\n', { mode: 0o755 });
  fs.writeFileSync(path.join(temp, 'pnpm.cjs'), `
    const fs = require('node:fs');
    const path = require('node:path');
    const a = process.argv.slice(2);
    if (a[0] === '--version') { console.log('${pnpmVersion}'); process.exit(0); }
    fs.appendFileSync('commands.log', JSON.stringify(a) + '\\n');
    if (a[0] === 'create' || a[1] === '@tanstack/cli@latest') {
      if (process.env.SCENARIO === 'generate-failure') process.exit(42);
      const target = a[0] === 'create' ? a[2] : a[a.indexOf('--target-dir') + 1];
      fs.mkdirSync(path.join(target, 'src'), { recursive: true });
      const manifest = {
        name: path.basename(target), version: '9.0.0', private: false,
        scripts: { build: 'vite build', dev: 'vite' },
        dependencies: { react: '^19.0.0' },
        devDependencies: { '@types/node': '^22.0.0' },
        engines: { node: '>=20.0.0' },
        packageManager: 'pnpm@10.0.0',
        customFrameworkField: { enabled: true },
      };
      if (process.env.FRAMEWORK !== 'next') manifest.type = 'module';
      if (process.env.FRAMEWORK === 'vite') delete manifest.devDependencies;
      if (process.env.SCENARIO === 'incompatible-node') manifest.engines.node = '>=99.0.0';
      if (process.env.SCENARIO === 'incompatible-manager') {
        manifest.devEngines = { packageManager: { name: 'pnpm', version: '^99.0.0' } };
      }
      fs.writeFileSync(path.join(target, 'package.json'), JSON.stringify(manifest));
      fs.writeFileSync(path.join(target, 'pnpm-workspace.yaml'), 'allowBuilds: unsafe');
      fs.writeFileSync(path.join(target, '.gitignore'), 'dist/\\n');
      fs.writeFileSync(path.join(target, 'src/index.js'), 'generated');
      fs.writeFileSync(path.join(target, 'package-lock.json'), 'unwanted');
    } else if (a.includes('--lockfile-only')) {
      if (process.env.SCENARIO === 'install-failure') process.exit(43);
      fs.writeFileSync('pnpm-lock.yaml', 'lock');
    } else if (a.includes('--frozen-lockfile')) {
      if (!fs.existsSync('pnpm-lock.yaml')) process.exit(44);
      fs.mkdirSync('node_modules');
    } else if (a[1] === '@tanstack/intent@latest') {
      if (!fs.existsSync('node_modules')) process.exit(45);
      fs.writeFileSync('AGENTS.md', 'skills');
    } else { process.exit(46); }
  `);
  return {
    project,
    run: () => {
      const result = spawnSync('bash', [path.join(temp, 'scaffold.sh'), framework], {
        cwd: project, encoding: 'utf8',
        env: { ...process.env, PATH: bin + path.delimiter + process.env.PATH, FRAMEWORK: framework, SCENARIO: scenario },
      });
      assert.ifError(result.error);
      assert.equal(result.signal, null, result.stderr);
      return result;
    },
    read: (file) => fs.readFileSync(path.join(project, file), 'utf8'),
  };
}

for (const framework of ['vite', 'next', 'astro', 'tanstack']) {
  test(framework + ': merge manifest and install under original policy', (t) => {
    const f = fixture(t, framework);
    const result = f.run();
    assert.equal(result.status, 0, result.stderr);
    const merged = JSON.parse(f.read('package.json'));
    assert.equal(merged.name, 'example-app');
    assert.equal(merged.private, true);
    assert.equal(merged.version, '0.0.0');
    assert.deepEqual(merged.devEngines, initial.devEngines);
    assert.deepEqual(merged.engines, initial.engines);
    assert.equal(merged.packageManager, undefined);
    assert.equal(merged.type, framework === 'next' ? undefined : 'module');
    assert.equal(merged.scripts.build, 'vite build');
    assert.equal(merged.dependencies.react, '^19.0.0');
    assert.deepEqual(merged.customFrameworkField, { enabled: true });
    assert.equal(merged.devDependencies?.['@types/node'], framework === 'vite' ? undefined : '^' + process.versions.node.split('.')[0] + '.0.0');
    assert.equal(f.read('pnpm-workspace.yaml'), policy);
    assert.equal(f.read('.git/marker'), 'keep');
    assert.match(f.read('.gitignore'), /^custom\/\ndist\/|custom\/\n\ndist\//);
    assert.match(f.read('.gitignore'), /!\.env\.example/);
    assert.ok(!fs.existsSync(path.join(f.project, 'package-lock.json')));
    const calls = f.read('commands.log').trim().split('\n').map(JSON.parse);
    for (const flag of ({ vite: ['--no-immediate'], next: ['--skip-install', '--disable-git', '--no-tailwind'], astro: ['--no-install', '--no-git'], tanstack: ['--blank', '--no-git', '--no-install'] })[framework]) {
      assert.ok(calls[0].includes(flag), flag);
    }
    assert.deepEqual(calls[1], framework === 'tanstack'
      ? ['add', '--workspace-root', '--save-exact', '--lockfile-only', '@tanstack/react-start@1', '@tanstack/react-router@1']
      : ['install', '--lockfile-only']);
    assert.deepEqual(calls[2], ['install', '--frozen-lockfile']);
    assert.equal(fs.existsSync(path.join(f.project, 'AGENTS.md')), framework === 'tanstack');
    assert.ok(!fs.readdirSync(f.project).some((name) => name.startsWith('.scaffold.')));
  });
}

for (const scenario of ['generate-failure', 'incompatible-node', 'incompatible-manager', 'scripts', 'dependencies', 'lockfile']) {
  test(scenario + ': preserve initial files and stop before installation', (t) => {
    const f = fixture(t, 'tanstack', scenario);
    if (scenario === 'scripts' || scenario === 'dependencies') {
      fs.writeFileSync(path.join(f.project, 'package.json'), JSON.stringify({ ...initial, [scenario]: { existing: 'value' } }));
    }
    if (scenario === 'lockfile') fs.writeFileSync(path.join(f.project, 'pnpm-lock.yaml'), 'existing');
    const before = f.read('package.json');
    const result = f.run();
    assert.notEqual(result.status, 0);
    if (scenario === 'generate-failure') {
      assert.equal(result.status, 42);
    } else {
      assert.match(result.stderr, {
        'incompatible-node': /engines.node requires >=99/,
        'incompatible-manager': /devEngines.packageManager requires \^99/,
        scripts: /Already initialized: package.json contains scripts/,
        dependencies: /Already initialized: package.json contains dependencies/,
        lockfile: /already has a lockfile/,
      }[scenario]);
    }
    assert.equal(f.read('package.json'), before);
    assert.equal(f.read('pnpm-workspace.yaml'), policy);
    assert.equal(f.read('.gitignore'), 'custom/\n');
    assert.ok(!fs.existsSync(path.join(f.project, 'src')));
    assert.ok(!fs.existsSync(path.join(f.project, 'node_modules')));
    assert.ok(!fs.readdirSync(f.project).some((name) => name.startsWith('.scaffold.')));
  });
}

test('installation failure retains the merged app and does not set up skills', (t) => {
  const f = fixture(t, 'tanstack', 'install-failure');
  assert.equal(f.run().status, 43);
  assert.equal(f.read('src/index.js'), 'generated');
  assert.equal(JSON.parse(f.read('package.json')).scripts.build, 'vite build');
  assert.equal(f.read('pnpm-workspace.yaml'), policy);
  assert.ok(!fs.existsSync(path.join(f.project, 'AGENTS.md')));
});
