{ pkgs, runtimes }:

let
  # Use npm's semver parser from the pinned Node.js distribution, without downloads.
  prepareManifest = pkgs.writeText "scaffold-manifest.cjs" ''
    const fs = require('node:fs');
    const semver = require('${runtimes.nodejs}/lib/node_modules/npm/node_modules/semver');
    const [initialPath, pnpmVersion, generatedPath] = process.argv.slice(2);
    const initial = JSON.parse(fs.readFileSync(initialPath, 'utf8'));
    const fail = (message) => { throw new Error(message); };

    for (const field of [
      'scripts', 'dependencies', 'devDependencies', 'optionalDependencies',
      'peerDependencies', 'bundledDependencies', 'bundleDependencies', 'workspaces',
    ]) {
      if (Object.keys(initial[field] ?? {}).length > 0) {
        fail('Already initialized: package.json contains ' + field);
      }
    }

    const runtime = initial.devEngines?.runtime;
    const manager = initial.devEngines?.packageManager;
    if (runtime?.name !== 'node' || !semver.valid(runtime.version) ||
        manager?.name !== 'pnpm' || !semver.valid(manager.version)) {
      fail('devEngines must declare exact Node.js and pnpm versions.');
    }
    if (runtime.version !== process.versions.node || manager.version !== pnpmVersion) {
      fail('The running Node.js/pnpm do not match devEngines. Update the runtime lock and re-enter Nix.');
    }

    function checkRange(version, range, field) {
      if (!semver.validRange(range) || !semver.satisfies(version, range)) {
        fail(field + ' requires ' + range + ', but the pinned version is ' + version);
      }
    }
    function checkEngines(manifest) {
      for (const [name, version] of [['node', runtime.version], ['pnpm', manager.version]]) {
        if (manifest.engines?.[name] !== undefined) {
          checkRange(version, manifest.engines[name], 'engines.' + name);
        }
      }
      for (const [field, name, version] of [
        ['runtime', 'node', runtime.version],
        ['packageManager', 'pnpm', manager.version],
      ]) {
        const requirement = manifest.devEngines?.[field];
        if (requirement === undefined) continue;
        for (const entry of Array.isArray(requirement) ? requirement : [requirement]) {
          if (entry?.name !== name) fail('Unsupported devEngines.' + field + ': ' + entry?.name);
          if (entry.version !== undefined) checkRange(version, entry.version, 'devEngines.' + field);
        }
      }
    }
    checkEngines(initial);

    if (generatedPath) {
      const generated = JSON.parse(fs.readFileSync(generatedPath, 'utf8'));
      if (typeof generated.name !== 'string' || !generated.scripts) {
        fail('The generator did not produce an application manifest.');
      }
      checkEngines(generated);
      const merged = {
        ...initial,
        ...generated,
        engines: { ...generated.engines, ...initial.engines },
        devEngines: { ...generated.devEngines, ...initial.devEngines },
      };
      for (const field of ['private', 'version']) {
        if (Object.hasOwn(initial, field)) merged[field] = initial[field];
      }
      // An absent type is also meaningful (CommonJS); follow the generated app.
      if (!Object.hasOwn(generated, 'type')) delete merged.type;
      delete merged.packageManager;
      if (merged.devDependencies?.['@types/node']) {
        merged.devDependencies['@types/node'] = '^' + semver.major(runtime.version) + '.0.0';
      }
      fs.writeFileSync(generatedPath, JSON.stringify(merged, null, 2) + '\n');
    }
  '';
in
pkgs.writeShellApplication {
  name = "scaffold-app-auto";
  runtimeInputs = [
    runtimes.nodejs
    runtimes.pnpm
    pkgs.rsync
  ];
  text = ''
    set -euo pipefail
    FRAMEWORK="''${1:-}"
    case "$FRAMEWORK" in
      vite|next|astro|tanstack) ;;
      *)
        echo "Usage: nix run .#scaffold-app-auto -- <vite|next|astro|tanstack>" >&2
        exit 1
        ;;
    esac
    if [ ! -f package.json ] || [ ! -f pnpm-workspace.yaml ]; then
      echo "Error: the initial package.json and pnpm-workspace.yaml are required." >&2
      exit 1
    fi
    if [ -e pnpm-lock.yaml ] || [ -e node_modules ]; then
      echo "Error: this project already has a lockfile or node_modules." >&2
      exit 1
    fi
    PNPM_VERSION="$(pnpm --version)"
    node ${prepareManifest} package.json "$PNPM_VERSION"

    PROJECT_NAME="$(basename "$PWD")"
    WORK_DIR="$(mktemp -d "$PWD/.scaffold.XXXXXX")"
    SCAFFOLD_DIR="$WORK_DIR/$PROJECT_NAME"
    trap 'rm -rf "$WORK_DIR"' EXIT

    # Keep framework prompts, but defer installation until policies and runtime
    # declarations have been restored. The target basename is the project name.
    case "$FRAMEWORK" in
      vite)
        pnpm create vite@latest "$SCAFFOLD_DIR" --no-immediate
        ;;
      next)
        pnpm create next-app@latest "$SCAFFOLD_DIR" \
          --use-pnpm --skip-install --disable-git --no-tailwind
        ;;
      astro)
        pnpm create astro@latest "$SCAFFOLD_DIR" --no-install --no-git
        ;;
      tanstack)
        pnpm dlx @tanstack/cli@latest create "$PROJECT_NAME" \
          --target-dir "$SCAFFOLD_DIR" \
          --framework React --package-manager pnpm \
          --blank --no-git --no-install --yes
        ;;
    esac

    # Validate and merge before changing anything in the project itself.
    node ${prepareManifest} package.json "$PNPM_VERSION" "$SCAFFOLD_DIR/package.json"
    rsync -a --ignore-existing \
      --exclude='/package.json' --exclude='/pnpm-workspace.yaml' \
      --exclude='/pnpm-lock.yaml' --exclude='/package-lock.json' \
      --exclude='/yarn.lock' --exclude='/bun.lock' --exclude='/bun.lockb' \
      --exclude='/node_modules' --exclude='/.git' --exclude='/.gitignore' \
      "$SCAFFOLD_DIR/" ./
    if [ -f "$SCAFFOLD_DIR/.gitignore" ]; then
      printf '\n' >> .gitignore
      cat "$SCAFFOLD_DIR/.gitignore" >> .gitignore
    fi
    printf '\n.direnv/\n.pre-commit-config.yaml\n.env\n.env.*\n!.env.example\n' >> .gitignore
    mv "$SCAFFOLD_DIR/package.json" package.json

    # Failed installs leave the generated app in place for diagnosis and retry.
    # Never weaken dependency policies automatically.
    if [ "$FRAMEWORK" = tanstack ]; then
      pnpm add --workspace-root --save-exact --lockfile-only \
        '@tanstack/react-start@1' '@tanstack/react-router@1'
    else
      pnpm install --lockfile-only
    fi
    pnpm install --frozen-lockfile
    if [ "$FRAMEWORK" = tanstack ]; then
      pnpm dlx @tanstack/intent@latest install --map
    fi
  '';
}
