{ pkgs, system }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux isAarch64;

  nodeVersion = "24.16.0";
  pnpmVersion = "10.33.2";

  nodePlatform =
    if isDarwin && isAarch64 then {
      slug = "darwin-arm64";
      ext = "tar.gz";
      hash = "sha256-ORidq07rFXBsQkrwrAijBEyeSPfbEqfXf2t6r8fdXfY=";
    } else if isDarwin && !isAarch64 then {
      slug = "darwin-x64";
      ext = "tar.gz";
      hash = "";
    } else if isLinux && isAarch64 then {
      slug = "linux-arm64";
      ext = "tar.xz";
      hash = "";
    } else if isLinux then {
      slug = "linux-x64";
      ext = "tar.xz";
      hash = "";
    } else
      throw "Unsupported system: ${system}";

  nodejs = pkgs.stdenvNoCC.mkDerivation {
    pname = "nodejs";
    version = nodeVersion;
    src = pkgs.fetchurl {
      url = "https://nodejs.org/dist/v${nodeVersion}/node-v${nodeVersion}-${nodePlatform.slug}.${nodePlatform.ext}";
      inherit (nodePlatform) hash;
    };
    nativeBuildInputs = [ pkgs.gnutar ];
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
      url = "https://registry.npmjs.org/pnpm/-/pnpm-${pnpmVersion}.tgz";
      hash = "sha256-envPE9f2zrOUbAOXg3PZm+n94cr8MAC9/tTE95EWdhA=";
    };
    nativeBuildInputs = [
      pkgs.gnutar
      pkgs.gzip
      pkgs.makeWrapper
    ];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/libexec" "$out/bin"
      tar -xzf "$src" --strip-components=1 -C "$out/libexec"
      makeWrapper "${nodejs}/bin/node" "$out/bin/pnpm" \
        --add-flags "$out/libexec/bin/pnpm.cjs"
      runHook postInstall
    '';
  };
in
{
  inherit nodejs pnpm;
}

