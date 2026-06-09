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
}
