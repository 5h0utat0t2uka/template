{ pkgs, git-hooks, system, runtimes, src }:

let
  preCommit = git-hooks.lib.${system}.run {
    inherit src;
    package = pkgs.prek;
    hooks = {
      detect-private-keys.enable = true;
      check-merge-conflicts.enable = true;
      check-added-large-files = {
        enable = true;
        args = [ "--maxkb=500" ];
      };
      node-tests = {
        enable = false;
        name = "node-test";
        entry = "${runtimes.pnpm}/bin/pnpm test";
        files = "^(apps|packages)/.*\\.tsx?$";
        pass_filenames = false;
      };
      # biome = {
      #   enable = true;
      #   name = "biome";
      #   package = pkgs.biome;
      #   entry = "${pkgs.biome}/bin/biome check --write --files-ignore-unknown=true --no-errors-on-unmatched";
      #   pass_filenames = true;
      # };
      # oxfmt = {
      #   enable = true;
      #   package = pkgs.oxfmt;
      #   settings.mode = "write";
      # };
      # oxlint = {
      #   enable = true;
      #   name = "oxlint";
      #   package = pkgs.oxlint;
      #   entry = "${pkgs.oxlint}/bin/oxlint";
      #   files = "\\.(js|jsx|mjs|cjs|ts|tsx|mts|cts)$";
      # };
      betterleaks = rec {
        enable = true;
        name = "betterleaks";
        package = pkgs.betterleaks;
        entry = "${package}/bin/betterleaks git --pre-commit --redact --staged --verbose";
        pass_filenames = false;
      };
      semgrep = rec {
        enable = true;
        name = "semgrep";
        package = pkgs.semgrep;
        entry = "${package}/bin/semgrep --config=p/default --config=p/typescript --config=p/javascript --config=p/react --metrics=off --error .";
        pass_filenames = false;
      };
      zizmor = {
        enable = true;
        package = pkgs.zizmor;
        args = [ "--collect=workflows,actions" "." ];
        files = "^\\.github/(workflows|actions)/.*";
        pass_filenames = false;
      };
    };
  };
in
{
  inherit (preCommit) enabledPackages shellHook;
  prek = pkgs.writeShellApplication {
    name = "prek";
    runtimeInputs = [ preCommit.config.gitPackage ] ++ preCommit.enabledPackages;
    text = let
      configDir = pkgs.linkFarm "prek-config" { ".pre-commit-config.yaml" = preCommit.config.configFile; };
    in ''
      exec ${pkgs.lib.getExe preCommit.config.package} run \
        --config ${configDir}/.pre-commit-config.yaml --all-files "$@"
    '';
  };
}
