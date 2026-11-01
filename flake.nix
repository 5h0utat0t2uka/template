{
  description = "A flake for a Node.js development environment with pnpm and TypeScript support.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = { nixpkgs, flake-utils, git-hooks, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      # pkgs = import nixpkgs { inherit system; };
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            # Semgrep 1.180.0 requires mcp==1.29.0.
            # Remove after adopting a nixpkgs revision with corrected dependencies.
            # https://github.com/semgrep/semgrep/blob/v1.180.0/cli/pyproject.toml
            semgrep =
              if prev.semgrep.version == "1.180.0" then
                prev.semgrep.override {
                  mcp = final.python3Packages.mcp_1;
                }
              else
                prev.semgrep;
          })
        ];
      };
      runtimes = import ./nix/runtimes.nix { inherit pkgs system; };
      preCommit = import ./nix/pre-commit.nix {
        inherit pkgs git-hooks system runtimes;
        src = ./.;
      };
      preCommitCheck = import ./nix/pre-commit.nix {
        inherit pkgs git-hooks system runtimes;
        src = ./.;
        enableSemgrep = false;
      };
      createProject = import ./nix/create-project.nix { inherit pkgs; };
      scaffoldAppAuto = import ./nix/scaffold-app-auto.nix { inherit pkgs runtimes; };
      scaffoldAppManual = import ./nix/scaffold-app-manual.nix { inherit pkgs runtimes; };
    in
    {
      formatter = pkgs.nixfmt;
      checks = {
        pre-commit = preCommitCheck;
        semgrep-package = pkgs.semgrep;
      };
      packages = {
        update-runtimes = runtimes.update-runtimes;
        create-project = createProject;
        scaffold-app-auto = scaffoldAppAuto;
        scaffold-app-manual = scaffoldAppManual;
      };
      apps = {
        create-project = {
          type = "app";
          program = "${createProject}/bin/create-project";
        };
        scaffold-app-auto = {
          type = "app";
          program = "${scaffoldAppAuto}/bin/scaffold-app-auto";
        };
        scaffold-app-manual = {
          type = "app";
          program = "${scaffoldAppManual}/bin/scaffold-app-manual";
        };
      };
      devShells.default = pkgs.mkShell {
        packages = [
          runtimes.nodejs
          runtimes.pnpm
          pkgs.age
          pkgs.betterleaks
          pkgs.prek
          pkgs.semgrep
          pkgs.sops
          pkgs.typescript-language-server
          pkgs.zizmor
        ] ++ preCommit.enabledPackages;
        shellHook = ''
          ${preCommit.shellHook}
          echo "node: $(node -v)"
          echo "pnpm: $(pnpm -v)"
        '';
      };
      devShells.ci = pkgs.mkShell {
        packages = [
          runtimes.nodejs
          runtimes.pnpm
        ];
      };
    }
  );
}
