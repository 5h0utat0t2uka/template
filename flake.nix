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
      # pkgs = import nixpkgs {
      #   inherit system;
      #   overlays = [
      #     (final: prev: {
      #       semgrep =
      #         if prev.semgrep.version == "1.180.0" then
      #           prev.semgrep.override {
      #             mcp = final.python3Packages.mcp_1;
      #           }
      #         else
      #           prev.semgrep;
      #     })
      #   ];
      # };
      runtimes = import ./nix/runtimes.nix { inherit pkgs system; };
      preCommit = import ./nix/pre-commit.nix { inherit pkgs git-hooks system runtimes; src = ./.; };
      createProject = import ./nix/create-project.nix { inherit pkgs; };
      scaffoldApp = import ./nix/scaffold-app.nix { inherit pkgs runtimes; };
    in
    {
      formatter = pkgs.nixfmt;
      checks = {
        semgrep-package = pkgs.semgrep;
      };
      packages = {
        update-runtimes = runtimes.update-runtimes;
        prek = preCommit.prek;
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
          runtimes.nodejs
          runtimes.pnpm
          pkgs.age
          pkgs.just
          pkgs.sops
          pkgs.typescript-language-server
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
