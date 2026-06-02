{ pkgs, fixedNode }:

pkgs.writeShellApplication {
  name = "scaffold-app";
  runtimeInputs = [
    fixedNode.nodejs
    fixedNode.pnpm
  ];
  text = ''
    set -euo pipefail
    FRAMEWORK="''${1:-}"
    PATH="$PWD"
    NAME="$(basename "$PATH")"
    if [ -z "$FRAMEWORK" ]; then
      echo "Usage: nix run .#scaffold-app -- <vite|next|astro>" >&2
      exit 1
    fi
    case "$FRAMEWORK" in
      vite)
        exec pnpm create vite .
        ;;
      next|astro)
        ;;
      *)
        echo "Unsupported framework: $FRAMEWORK (expected: vite, next, astro)" >&2
        exit 1
        ;;
    esac

    BACKUP_DIR="$(cd .. && pwd)/.''${NAME}-template-backup-$(date +%s)"
    DUPLICATES_FILE="$(mktemp)"
    if [ -e "$BACKUP_DIR" ]; then
      echo "Error: $BACKUP_DIR already exists." >&2
      exit 1
    fi
    mkdir "$BACKUP_DIR"

    restore() {
      if [ -d "$BACKUP_DIR" ]; then
        for path in "$BACKUP_DIR"/* "$BACKUP_DIR"/.[!.]* "$BACKUP_DIR"/..?*; do
          [ -e "$path" ] || continue
          file="$(basename "$path")"
          dist="$PATH/$file"
          if [ -e "$dist" ]; then
            prefixed_file="template_$file"
            prefixed_dist="$PATH/$prefixed_file"
            if [ -e "$prefixed_dist" ]; then
              i=1
              while [ -e "$PATH/template_''${i}_$file" ]; do
                i=$((i + 1))
              done
              prefixed_file="template_''${i}_$file"
              prefixed_dist="$PATH/$prefixed_file"
            fi
            mv "$path" "$prefixed_dist"
            printf '%s -> %s\n' "$file" "$prefixed_file" >> "$DUPLICATES_FILE"
            continue
          fi
          mv "$path" "$PATH/"
        done
        rm -rf "$BACKUP_DIR"
        if [ -s "$DUPLICATES_FILE" ]; then
          echo " Some template files conflicted with scaffold-generated files and were restored with a prefix:" >&2
          sed 's/^/  - /' "$DUPLICATES_FILE" >&2
        fi
      fi
      rm -f "$DUPLICATES_FILE"
    }

    trap 'status=$?; restore; exit "$status"' EXIT
    find "$PATH" -mindepth 1 -maxdepth 1 \
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
