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
            # Semgrep requires MCP v1, which is incompatible with MCP v2.
            # https://github.com/semgrep/semgrep/blob/v1.180.0/cli/pyproject.toml
            semgrep =
              if prev.lib.versionOlder prev.python3Packages.mcp.version "2.0" then
                prev.semgrep
              else if prev.python3Packages ? mcp_1 then
                prev.semgrep.override {
                  mcp = final.python3Packages.mcp_1;
                }
              else
                throw "Semgrep requires MCP v1, but python3Packages.mcp_1 is unavailable.";
          })
        ];
      };
      fixedNode = import ./nix/fixed-node.nix { inherit pkgs system; };
      # preCommit = import ./nix/pre-commit.nix { inherit pkgs git-hooks system fixedNode; src = ./.; };
      preCommit = import ./nix/pre-commit.nix {
        inherit pkgs git-hooks system fixedNode;
        src = ./.;
      };
      preCommitCheck = import ./nix/pre-commit.nix {
        inherit pkgs git-hooks system fixedNode;
        src = ./.;
        enableSemgrep = false;
      };
      createProject = import ./nix/create-project.nix { inherit pkgs; };
      scaffoldApp = import ./nix/scaffold-app.nix { inherit pkgs fixedNode; };
    in
    {
      formatter = pkgs.nixfmt;
      checks = {
        pre-commit = preCommitCheck;
        semgrep-package = pkgs.semgrep;
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
          fixedNode.nodejs
          fixedNode.pnpm
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
          fixedNode.nodejs
          fixedNode.pnpm
        ];
      };
    }
  );
}
