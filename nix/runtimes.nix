{ pkgs, system }:

let
  inherit (pkgs.stdenv.hostPlatform) isLinux;

  manifest = builtins.fromJSON (builtins.readFile ../package.json);
  lock = builtins.fromJSON (builtins.readFile ./runtimes.lock.json);
  nodeVersion = manifest.devEngines.runtime.version;
  pnpmVersion = manifest.devEngines.packageManager.version;

  lockedSrc = name: version:
    let
      entry = lock.${name};
      platform =
        entry.platforms.${system} or (throw "No ${name} entry for ${system} in runtimes.lock.json");
    in
    if entry.version != version then
      throw "${name}: package.json specifies ${version}, but runtimes.lock.json has ${entry.version}. Run 'nix run .#update-runtimes'."
    else
      pkgs.fetchurl { inherit (platform) url hash; };

  nodejs = pkgs.stdenvNoCC.mkDerivation {
    pname = "nodejs";
    version = nodeVersion;
    src = lockedSrc "node" nodeVersion;
    nativeBuildInputs = [
      pkgs.gnutar
    ]
    ++ pkgs.lib.optionals isLinux [
      pkgs.autoPatchelfHook
    ];
    buildInputs = pkgs.lib.optionals isLinux [
      pkgs.stdenv.cc.cc.lib
    ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      tar -xf "$src" --strip-components=1 -C "$out"
      runHook postInstall
    '';
  };

  pnpm = pkgs.stdenvNoCC.mkDerivation {
    pname = "pnpm";
    version = pnpmVersion;
    src = lockedSrc "pnpm" pnpmVersion;
    nativeBuildInputs = [
      pkgs.gnutar
      pkgs.gzip
      pkgs.makeWrapper
    ]
    ++ pkgs.lib.optionals isLinux [
      pkgs.autoPatchelfHook
    ];
    buildInputs = pkgs.lib.optionals isLinux [
      pkgs.stdenv.cc.cc.lib
    ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/libexec" "$out/bin"
      tar -xzf "$src" -C "$out/libexec"
      makeWrapper "$out/libexec/pnpm" "$out/bin/pnpm" \
        --prefix PATH : "${nodejs}/bin" \
        --set pnpm_config_pm_on_fail error
    '';
  };

  # node, pnpm に依存しないので、lock が古い・未作成でも実行できる。
  # nix コマンドは呼び出し元のもの（デーモンと同じバージョン）を使う。
  update-runtimes = pkgs.writeShellApplication {
    name = "update-runtimes";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.gh
      pkgs.gnupg
      pkgs.jq
      pkgs.yq-go
    ];
    text = builtins.readFile ../scripts/update-runtimes.sh;
  };
in
{
  inherit nodejs pnpm update-runtimes;
}
