{ pkgs, git-hooks, system, src }:

git-hooks.lib.${system}.run {
  inherit src;
  hooks = {
    detect-private-keys.enable = true;
    check-merge-conflicts.enable = true;
    check-added-large-files = {
      enable = true;
      args = [ "--maxkb=500" ];
    };
    betterleaks = {
      enable = true;
      name = "betterleaks";
      entry = "${pkgs.betterleaks}/bin/betterleaks git --pre-commit --redact --staged --verbose";
      pass_filenames = false;
    };
    semgrep = {
      enable = true;
      name = "semgrep";
      entry = "${pkgs.semgrep}/bin/semgrep --config=auto --metrics=off --error";
      pass_filenames = true;
    };
    zizmor = {
      enable = true;
      name = "zizmor";
      entry = "${pkgs.zizmor}/bin/zizmor .github/workflows";
      files = "^\\.github/(workflows|actions)/.*";
      pass_filenames = false;
    };
  };
}
