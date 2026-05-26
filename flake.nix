{
  description = "A flake for a Node.js development environment with pnpm and TypeScript support.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = { nixpkgs, flake-utils, git-hooks, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      node = import ./nix/node.nix { inherit nixpkgs system; };
      pkgs = import nixpkgs { inherit system; };

      preCommit = git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          detect-private-keys.enable = true;
          check-merge-conflicts.enable = true;
          check-added-large-files = {
            enable = true;
            args = [ "--maxkb=500" ];
          };
          gitleaks = {
            enable = true;
            name = "gitleaks";
            entry = "${pkgs.gitleaks}/bin/gitleaks git --pre-commit --redact --staged --verbose";
            pass_filenames = false;
          };
          zizmor = {
            enable = true;
            name = "zizmor";
            entry = "${pkgs.writeShellScript "zizmor-hook" ''
              if [ -d .github/workflows ]; then
                exec ${pkgs.zizmor}/bin/zizmor .github/workflows
              fi
            ''}";
            pass_filenames = false;
            always_run = true;
          };
        };
      };

      createProject = pkgs.writeShellApplication {
        name = "create-project";
        runtimeInputs = with pkgs; [
          gh
          git
        ];
        text = ''
          set -euo pipefail
          OWNER="''${1:?OWNER is required}"
          REPO="''${2:?REPO is required}"
          VISIBILITY="''${3:-public}"
          case "$VISIBILITY" in
            public)
              visibility_flag="--public"
              ;;
            private)
              visibility_flag="--private"
              ;;
            internal)
              visibility_flag="--internal"
              ;;
            *)
              echo "VISIBILITY must be public, private, or internal" >&2
              exit 1
              ;;
          esac
          gh auth status >/dev/null
          gh repo create "$OWNER/$REPO" \
            --template 5h0utat0t2uka/template \
            "$visibility_flag" \
            --clone
          gh api \
            --method PUT \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "/repos/$OWNER/$REPO/actions/permissions/workflow" \
            -f default_workflow_permissions=write \
            -F can_approve_pull_request_reviews=false
          gh api \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "/repos/$OWNER/$REPO/actions/permissions/workflow"

          echo " Created and cloned: $OWNER/$REPO"
          echo " Next:"
          echo "  cd $REPO"
        '';
      };

      scaffoldApp = pkgs.writeShellApplication {
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
              pnpm create next-app .
              ;;
            astro)
              pnpm create astro .
              ;;
          esac
        '';
      };
    in
    {
      checks = {
        pre-commit = preCommit;
      };
      packages = {
        create-project = createProject;
        scaffold-app = scaffoldApp;
      };
      apps = {
        create-project = {
          type = "app";
          program = "${createProject}/bin/create-project";
        };
        scaffold-app = {
          type = "app";
          program = "${scaffoldApp}/bin/scaffold-app";
        };
      };
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.age
          pkgs.gitleaks
          node.nodejs
          node.pnpm
          pkgs.sops
          pkgs.typescript-language-server
          pkgs.zizmor
        ];
        shellHook = ''
          ${preCommit.shellHook}
          echo "node: $(node -v)"
          echo "pnpm: $(pnpm -v)"
        '';
      };
    }
  );
}

