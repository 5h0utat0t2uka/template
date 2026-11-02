# shellcheck shell=bash
# package.json の devEngines で指定した node, pnpm を検証して nix/runtimes.lock.json（system ごとの URL, SRI）を生成する。
#   node: nodejs/release-keys の keyring で SHASUMS256.txt.asc の署名を検証し、その値を採用
#   pnpm: GitHub artifact attestation（pnpm/pnpm の release.yml・該当タグ）を検証し、検証済みファイルのハッシュを採用

set -euo pipefail
shopt -s inherit_errexit

root="${1:-.}"
manifest="$root/package.json"
lockfile="$root/nix/runtimes.lock.json"
platforms=(
  "aarch64-darwin darwin-arm64 tar.gz"
  "x86_64-darwin darwin-x64 tar.gz"
  "aarch64-linux linux-arm64 tar.xz"
  "x86_64-linux linux-x64 tar.xz"
)

fetch() {
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL -o "$1" "$2" || {
    echo "error: 取得できません: $2" >&2
    return 1
  }
}
read_version() {
  jq -er "$1" "$manifest" || {
    echo "error: package.json から読めません: $1" >&2
    return 1
  }
}

node_version="$(read_version '.devEngines.runtime | select(.name == "node") | .version')"
pnpm_version="$(read_version '.devEngines.packageManager | select(.name == "pnpm") | .version')"
for version in "$node_version" "$pnpm_version"; do
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: devEngines の version は x.y.z で完全指定してください（範囲指定は不可）: $version" >&2
    exit 1
  fi
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
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
    echo "error: 署名済み SHASUMS256.txt に $node_file がありません" >&2
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
echo "updated: $lockfile (node $node_version, pnpm $pnpm_version)" >&2
