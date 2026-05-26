{
  description = "A flake for a Node.js development environment with pnpm and TypeScript support.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = { nixpkgs, flake-utils, git-hooks, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      node = import ./nix/node.nix { inherit nixpkgs system; };
      createProject = import ./nix/create-project.nix { inherit pkgs; };
      scaffoldApp = import ./nix/scaffold-app.nix { inherit pkgs node; };

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

