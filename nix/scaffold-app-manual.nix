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
    WORK_DIR="$(mktemp -d "$PWD/.scaffold.XXXXXX")"
    SCAFFOLD_DIR="$WORK_DIR/$PROJECT_NAME"
    # Retain successful and partial output for manual inspection and copying.
    trap 'printf "\nGenerated files (retained): %s\nTemporary directory: %s\n" "$SCAFFOLD_DIR" "$WORK_DIR"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    # Generate in an empty child directory, preserving the project basename.
    # Pass relative targets: create-vite joins the target to its working directory.
    cd "$WORK_DIR"
    case "$FRAMEWORK" in
      vite)
        pnpm create vite@latest "./$PROJECT_NAME" --no-immediate
        ;;
      next)
        pnpm create next-app@latest "./$PROJECT_NAME" \
          --use-pnpm --skip-install --disable-git --no-tailwind
        ;;
      astro)
        pnpm create astro@latest "./$PROJECT_NAME" --no-install --no-git
        ;;
      tanstack)
        pnpm dlx @tanstack/cli@latest create "$PROJECT_NAME" \
          --target-dir "./$PROJECT_NAME" \
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
