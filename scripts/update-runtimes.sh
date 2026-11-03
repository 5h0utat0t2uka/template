# shellcheck shell=bash
# package.json の devEngines で指定した node, pnpm を検証して nix/runtimes.lock.json（system ごとの URL, SRI）を生成する。
#   node: nodejs/release-keys の keyring で SHASUMS256.txt.asc の署名を検証し、その値を採用
#   pnpm: npm レジストリの公開日時が minimumReleaseAge を満たすことを確認して GitHub artifact attestation を検証し、検証済みファイルのハッシュを採用

set -euo pipefail
shopt -s inherit_errexit

root="${1:-.}"
manifest="$root/package.json"
workspace="$root/pnpm-workspace.yaml"
lockfile="$root/nix/runtimes.lock.json"
platforms=(
  "aarch64-darwin darwin-arm64 tar.gz"
  "x86_64-darwin darwin-x64 tar.gz"
  "aarch64-linux linux-arm64 tar.xz"
  "x86_64-linux linux-x64 tar.xz"
)

fetch() {
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL -o "$1" "$2" || {
    echo "error: Failed to download $2" >&2
    return 1
  }
}

read_version() {
  jq -er --arg key "$1" --arg name "$2" \
    '.devEngines[$key] | select(.name == $name) | .version' "$manifest" || {
    echo "error: Cannot read the $2 version from devEngines.$1 in $manifest" >&2
    return 1
  }
}

node_version="$(read_version runtime node)"
pnpm_version="$(read_version packageManager pnpm)"
for version in "$node_version" "$pnpm_version"; do
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: Expected an exact x.y.z version in devEngines, got '$version'" >&2
    exit 1
  fi
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# pnpm: minimumReleaseAge（分）を満たすバージョンだけを固定する
# 判定は pnpm と同じく npm レジストリの公開日時で行う
# https://pnpm.io/config-includes#bootconfig
min_age=1440
if [[ -f "$workspace" ]]; then
  min_age="$(yq -o=json '.' "$workspace" | jq -e --argjson default "$min_age" '
    first((.bootConfig.minimumReleaseAge, .minimumReleaseAge, $default) | select(. != null))
    | if . == 0 then 0
      elif type == "number" and . > 0 then .
      else error("minimumReleaseAge must be a non-negative number of minutes")
      end
  ')"
fi
if [[ "$min_age" != 0 ]]; then
  fetch "$work/pnpm-packument.json" "https://registry.npmjs.org/pnpm"
  published="$(jq -er --arg v "$pnpm_version" '
    if (.versions | type) != "object" then error("Invalid npm metadata for pnpm")
    elif .versions[$v] == null then error("pnpm@\($v) was not found on npm")
    else (.time[$v] | strings | select(length > 0)) // error("Missing publish time for pnpm@\($v)")
    end
  ' "$work/pnpm-packument.json")"
  published_epoch="$(date --date="$published" +%s.%N)"
  if ! jq -en --argjson published "$published_epoch" --argjson min "$min_age" \
    'now - $published >= $min * 60' >/dev/null; then
    echo "error: pnpm@$pnpm_version was published at $published; minimumReleaseAge is $min_age minutes" >&2
    exit 1
  fi
fi

# 利用者の GnuPG 設定・鍵に検証結果を左右させない
export GNUPGHOME="$work/gnupg"
mkdir -m 700 "$GNUPGHOME"

# Node.js: 署名を検証した SHASUMS256.txt だけを信頼する
node_base="https://nodejs.org/dist/v$node_version"
fetch "$work/nodejs-keyring.kbx" "https://github.com/nodejs/release-keys/raw/HEAD/gpg/pubring.kbx"
fetch "$work/SHASUMS256.txt.asc" "$node_base/SHASUMS256.txt.asc"
gpgv --keyring "$work/nodejs-keyring.kbx" --output "$work/SHASUMS256.txt" <"$work/SHASUMS256.txt.asc"

node_platforms='{}'
pnpm_platforms='{}'
for entry in "${platforms[@]}"; do
  read -r system slug ext <<<"$entry"
  node_file="node-v$node_version-$slug.$ext"
  node_hex="$(awk -v f="$node_file" '$2 == f { print $1 }' "$work/SHASUMS256.txt")"
  if [[ ! "$node_hex" =~ ^[0-9a-f]{64}$ ]]; then
    echo "error: No valid signed checksum for $node_file" >&2
    exit 1
  fi
  node_hash="$(nix hash convert --hash-algo sha256 --to sri "$node_hex")"
  node_platforms="$(jq -c --arg s "$system" --arg u "$node_base/$node_file" --arg h "$node_hash" \
    '.[$s] = {url: $u, hash: $h}' <<<"$node_platforms")"

  # pnpm: 公式リリースワークフローがそのタグでビルドしたことを確認してからハッシュを取る
  pnpm_file="pnpm-$slug.tar.gz"
  pnpm_url="https://github.com/pnpm/pnpm/releases/download/v$pnpm_version/$pnpm_file"
  fetch "$work/$pnpm_file" "$pnpm_url"
  gh attestation verify "$work/$pnpm_file" \
    --repo pnpm/pnpm \
    --signer-workflow pnpm/pnpm/.github/workflows/release.yml \
    --source-ref "refs/tags/v$pnpm_version"
  pnpm_hex="$(sha256sum "$work/$pnpm_file" | cut -d ' ' -f 1)"
  pnpm_hash="$(nix hash convert --hash-algo sha256 --to sri "$pnpm_hex")"
  pnpm_platforms="$(jq -c --arg s "$system" --arg u "$pnpm_url" --arg h "$pnpm_hash" \
    '.[$s] = {url: $u, hash: $h}' <<<"$pnpm_platforms")"
done

jq -n \
  --arg nv "$node_version" --argjson np "$node_platforms" \
  --arg pv "$pnpm_version" --argjson pp "$pnpm_platforms" \
  '{node: {version: $nv, platforms: $np}, pnpm: {version: $pv, platforms: $pp}}' >"$lockfile.tmp"
mv "$lockfile.tmp" "$lockfile"
echo "Updated $lockfile (Node.js $node_version, pnpm $pnpm_version)" >&2
