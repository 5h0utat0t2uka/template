{ pkgs, fixedNode }:

pkgs.writeShellApplication {
  name = "scaffold-app";
  runtimeInputs = [
    fixedNode.nodejs
    fixedNode.pnpm
    pkgs.rsync
  ];
  text = ''
    set -euo pipefail
    FRAMEWORK="''${1:-}"
    if [ -z "$FRAMEWORK" ]; then
      echo "Usage: nix run .#scaffold-app -- <vite|next|astro|tanstack>" >&2
      exit 1
    fi
    case "$FRAMEWORK" in
      vite)
        exec pnpm create vite .
        ;;
      tanstack)
        if [ -e package.json ] || [ -e pnpm-lock.yaml ]; then
          echo "Error: TanStack scaffolding requires a template without package.json or pnpm-lock.yaml." >&2
          exit 1
        fi
        if [ ! -f pnpm-workspace.yaml ]; then
          echo "Error: pnpm-workspace.yaml is required to preserve the template's dependency policies." >&2
          exit 1
        fi

        PNPM_VERSION="$(pnpm --version)"
        NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
        SCAFFOLD_DIR="$(mktemp -d "$PWD/.tanstack-scaffold.XXXXXX")"
        trap 'rm -rf "$SCAFFOLD_DIR"' EXIT

        pnpm dlx @tanstack/cli@latest create "$(basename "$PWD")" \
          --target-dir "$SCAFFOLD_DIR" \
          --framework React --package-manager pnpm \
          --blank --no-git --no-install --yes

        # Keep template files, especially the dependency policies. Merge ignores
        # separately so both the app's output and the template's files are covered.
        rsync -a --ignore-existing \
          --exclude='/pnpm-workspace.yaml' \
          --exclude='/.git' --exclude='/.gitignore' \
          "$SCAFFOLD_DIR/" ./
        if [ -f "$SCAFFOLD_DIR/.gitignore" ]; then
          printf '\n' >> .gitignore
          cat "$SCAFFOLD_DIR/.gitignore" >> .gitignore
        fi
        printf '\n.direnv/\n.pre-commit-config.yaml\n.env\n.env.*\n!.env.example\n' >> .gitignore

        npm pkg set "packageManager=pnpm@$PNPM_VERSION" \
          "devDependencies.@types/node=^$NODE_MAJOR.0.0"
        # Resolve eligible v1 releases under minimumReleaseAge, then pin them.
        # Policy failures stop here; do not relax the workspace settings.
        pnpm add --workspace-root --save-exact --lockfile-only \
          '@tanstack/react-start@1' '@tanstack/react-router@1'
        pnpm install --frozen-lockfile
        # Map skills only after the final dependencies exist in this project.
        pnpm dlx @tanstack/intent@latest install --map
        exit 0
        ;;
      next|astro)
        ;;
      *)
        echo "Unsupported framework: $FRAMEWORK (expected: vite, next, astro, tanstack)" >&2
        exit 1
        ;;
    esac
    PROJECT_DIR="$PWD"
    PROJECT_NAME="$(basename "$PROJECT_DIR")"
    BACKUP_DIR="$(cd .. && pwd)/.''${PROJECT_NAME}-template-backup-$(date +%s)"
    SKIPPED_DUPLICATES_FILE="$(mktemp)"
    if [ -e "$BACKUP_DIR" ]; then
      echo "Error: $BACKUP_DIR already exists." >&2
      exit 1
    fi
    mkdir "$BACKUP_DIR"

    restore() {
      if [ -d "$BACKUP_DIR" ]; then
        for path in "$BACKUP_DIR"/* "$BACKUP_DIR"/.[!.]* "$BACKUP_DIR"/..?*; do
          [ -e "$path" ] || continue
          filename="$(basename "$path")"
          destination="$PROJECT_DIR/$filename"
          if [ -e "$destination" ]; then
            prefixed_filename="template_$filename"
            prefixed_destination="$PROJECT_DIR/$prefixed_filename"
            if [ -e "$prefixed_destination" ]; then
              i=1
              while [ -e "$PROJECT_DIR/template_''${i}_$filename" ]; do
                i=$((i + 1))
              done
              prefixed_filename="template_''${i}_$filename"
              prefixed_destination="$PROJECT_DIR/$prefixed_filename"
            fi
            mv "$path" "$prefixed_destination"
            printf '%s -> %s\n' "$filename" "$prefixed_filename" >> "$SKIPPED_DUPLICATES_FILE"
            continue
          fi
          mv "$path" "$PROJECT_DIR/"
        done
        rm -rf "$BACKUP_DIR"
        if [ -s "$SKIPPED_DUPLICATES_FILE" ]; then
          echo " Some template files conflicted with scaffold-generated files and were restored with a prefix:" >&2
          sed 's/^/  - /' "$SKIPPED_DUPLICATES_FILE" >&2
        fi
      fi
      rm -f "$SKIPPED_DUPLICATES_FILE"
    }

    trap 'status=$?; restore; exit "$status"' EXIT
    find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 \
      ! -name .git \
      -exec mv {} "$BACKUP_DIR/" \;

    case "$FRAMEWORK" in
      next)
        pnpm create next-app@latest .
        ;;
      astro)
        pnpm create astro@latest .
        ;;
    esac

    status=$?
    trap - EXIT
    restore
    exit "$status"
  '';
}
