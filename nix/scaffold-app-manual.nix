{ pkgs, runtimes }:

pkgs.writeShellApplication {
  name = "scaffold-app-manual";
  runtimeInputs = [
    runtimes.nodejs
    runtimes.pnpm
    pkgs.coreutils
  ];
  text = ''
    set -euo pipefail
    FRAMEWORK="''${1:-}"
    if [ "$#" -ne 1 ]; then
      echo "Usage: nix run .#scaffold-app-manual -- <vite|next|astro|tanstack>" >&2
      exit 1
    fi
    case "$FRAMEWORK" in
      vite|next|astro|tanstack) ;;
      *)
        echo "Unsupported framework: $FRAMEWORK (expected: vite, next, astro, tanstack)" >&2
        exit 1
        ;;
    esac

    PROJECT_NAME="$(basename "$PWD")"
    WORK_DIR="$(mktemp -d "$(dirname "$PWD")/.$PROJECT_NAME-scaffold.XXXXXX")"
    SCAFFOLD_DIR="$WORK_DIR/$PROJECT_NAME"
    # Retain successful and partial output for manual inspection and copying.
    trap 'printf "\nGenerated files (retained): %s\nTemporary directory: %s\n" "$SCAFFOLD_DIR" "$WORK_DIR"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    # Run outside the original project so the CLI cannot rewrite its manifest.
    cd "$WORK_DIR"
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
    if [ ! -f "$SCAFFOLD_DIR/package.json" ]; then
      echo "Error: no package.json was generated; scaffolding may have been cancelled." >&2
      exit 1
    fi
    echo "Review the generated files, then copy and merge them into your project manually."
  '';
}
