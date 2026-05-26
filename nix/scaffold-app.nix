{ pkgs, node }:

pkgs.writeShellApplication {
  name = "scaffold-app";
  runtimeInputs = [
    node.nodejs
    node.pnpm
  ];
  text = ''
    set -euo pipefail
    FRAMEWORK="''${1:-}"
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

    # 退避先を親ディレクトリに作成
    PROJECT_DIR="$PWD"
    PROJECT_NAME="$(basename "$PROJECT_DIR")"
    BACKUP_DIR="$(cd .. && pwd)/.''${PROJECT_NAME}-template-backup-$(date +%s)"
    if [ -e "$BACKUP_DIR" ]; then
      echo "Error: $BACKUP_DIR already exists." >&2
      exit 1
    fi
    mkdir "$BACKUP_DIR"
    restore() {
      if [ -d "$BACKUP_DIR" ]; then
        find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 \
          -exec mv -n {} "$PROJECT_DIR/" \;
        rmdir "$BACKUP_DIR" 2>/dev/null || \
          echo "Warning: $BACKUP_DIR is not empty. Inspect remaining files manually." >&2
      fi
    }
    trap restore EXIT
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
  '';
}

