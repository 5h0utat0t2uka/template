/**
  # to get the hash of nodejs, run the following command in your terminal:
  node_version=26.13.0
  for platform in darwin-arm64 darwin-x64 linux-arm64 linux-x64; do
    case "$platform" in
      darwin-*) archive_ext=tar.gz ;;
      linux-*) archive_ext=tar.xz ;;
    esac
    nix store prefetch-file --json \
      "https://nodejs.org/dist/v${node_version}/node-v${node_version}-${platform}.${archive_ext}" |
      jq --arg platform "$platform" '{platform: $platform, hash: .hash}'
  done

  # to get the hash of pnpm, run the following command in your terminal:
  pnpm_version=12.17.0
  for platform in darwin-arm64 darwin-x64 linux-arm64 linux-x64; do
    nix store prefetch-file --json \
      "https://github.com/pnpm/pnpm/releases/download/v${pnpm_version}/pnpm-${platform}.tar.gz" |
      jq --arg platform "$platform" '{platform: $platform, hash: .hash}'
  done
  */

{ pkgs, system }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux isAarch64 isx86_64;

  # manifest = builtins.fromJSON (builtins.readFile ../package.json);
  # nodeVersion = manifest.devEngines.runtime.version;
  # pnpmVersion = manifest.devEngines.packageManager.version;

  nodeVersion = "26.13.0";
  pnpmVersion = "12.17.0";

  nodePlatform =
    if isDarwin && isAarch64 then {
      slug = "darwin-arm64";
      ext = "tar.gz";
      hash = "sha256-04vV5aLdzmu7XOReRuIIM32k1R//5hHlZ/0yBz1kOfY=";
    } else if isDarwin && isx86_64 then {
      slug = "darwin-x64";
      ext = "tar.gz";
      hash = "sha256-UlybKbsCY9aH3mCkzsDiptuHao6wMjaeV5Xspx58NY4=";
    } else if isLinux && isAarch64 then {
      slug = "linux-arm64";
      ext = "tar.xz";
      hash = "sha256-QG/j+94cBUrf+LKXwW/bWvZlnbMnwayKzUa1bvGvmpI=";
    } else if isLinux && isx86_64 then {
      slug = "linux-x64";
      ext = "tar.xz";
      hash = "sha256-0oqWr2w4WW9tnZfA7lMcE9I411d0I4fRko3oItlZ6Zc=";
    } else
      throw "Unsupported system: ${system}";

  pnpmPlatform =
    if isDarwin && isAarch64 then {
      slug = "darwin-arm64";
      hash = "sha256-RGwzTUk738bMLbaTdk0YEvygZFb2pL55lqE9cAh4Ajk=";
    } else if isDarwin && isx86_64 then {
      slug = "darwin-x64";
      hash = "sha256-uOdUoj0Z1fVn3RaWgbFWJ96asSmXJItsI1Bsbie9zpI=";
    } else if isLinux && isAarch64 then {
      slug = "linux-arm64";
      hash = "sha256-zlpblamXSgu9cTpe90QW280OP98R9p6pLFmVucGMy0c=";
    } else if isLinux && isx86_64 then {
      slug = "linux-x64";
      hash = "sha256-LFiVn9XfXLn05yeEwIpg/8fuVY/tmwSyIlTikRIgOlE=";
    } else
      throw "Unsupported system: ${system}";

  nodejs = pkgs.stdenvNoCC.mkDerivation {
    pname = "nodejs";
    version = nodeVersion;
    src = pkgs.fetchurl {
      url = "https://nodejs.org/dist/v${nodeVersion}/node-v${nodeVersion}-${nodePlatform.slug}.${nodePlatform.ext}";
      inherit (nodePlatform) hash;
    };
    nativeBuildInputs = [
      pkgs.gnutar
    ] ++ pkgs.lib.optionals isLinux [
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
    src = pkgs.fetchurl {
      url = "https://github.com/pnpm/pnpm/releases/download/v${pnpmVersion}/pnpm-${pnpmPlatform.slug}.tar.gz";
      inherit (pnpmPlatform) hash;
    };
    nativeBuildInputs = [
      pkgs.gnutar
      pkgs.gzip
      pkgs.makeWrapper
    ] ++ pkgs.lib.optionals isLinux [
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
      runHook postInstall
    '';
  };
in
{
  inherit nodejs pnpm;
}
