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
    in 
    {
      checks = {
        pre-commit = preCommit;
      };
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.gitleaks
          node.nodejs
          node.pnpm
          # pkgs.nodejs_24
          # pkgs.pnpm
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
