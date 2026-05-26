# Frontend Template with Nix  
Template for setting up a development environment for front-end projects using direnv, flake.nix, and pnpm.  
This template implements basic security measures, including dependency management with `dependabot`, static analysis of GitHub workflows with `zizmor`, secret detection with `gitLeaks`, and secret management with `age` and `sops`.

⚠️ **REQUIREMENTS**  
- Nix with flakes enabled  
- `gh` (GitHub CLI) authentication  

If you have not authenticated `gh` yet:
``` sh
nix shell nixpkgs#gh -c gh auth login
```

## プロジェクト作成
クローン先のディレクトリに移動
``` sh
cd path/to/parent-directory
```

### 1. テンプレートからリポジトリを作成
`OWNER`: GitHubのユーザー名または組織名, `REPO`: 作成するリポジトリ名, `VISIBILITY`: `public`もしくは`privare` を指定してリポジトリを作成
``` sh
nix run github:5h0utat0t2uka/template#create-project -- OWNER REPO VISIBILITY
```

### 2. リポジトリに移動
``` sh
cd REPO
```
> [!TIP]
> `.github/dependabot.yml` の `open-pull-requests-limit: 0` を削除して有効化  
> `.github/dependabot.yml` の `assignees`を適時変更  

### 3. `.envrc`を作成
``` sh
echo 'watch_dir nix
watch_file pnpm-lock.yaml
use flake' >> .envrc
```

### 4. `.envrc`の許可
``` sh
direnv allow

# nodeとpnpmのバージョン確認
node -v
pnpm -v
```

### 5. フレームワークのスキャフォールド  
`flake.nix`の`writeShellApplication`で定義したコマンドを実行  

> [!TIP]
> Vite の場合 Ignore files and continue を選択

``` sh
# Vite
nix run .#scaffold-app -- vite

# Next.js
nix run .#scaffold-app -- next

# Astro
nix run .#scaffold-app -- astro
```

もしくは
``` sh
# プロジェクトルートにあるファイルを一時退避
BACKUP_DIR="../.$(basename "$PWD")-template-backup-$(date +%s)"
mkdir "$BACKUP_DIR"
find . -mindepth 1 -maxdepth 1 \
  ! -name .git \
  -exec mv {} "$BACKUP_DIR/" \;

# スキャフォールド
# pnpm create next-app ., pnpm create astro ., pnpm create ...

# 復元
find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 \
  -exec mv -n {} . \;

rmdir "$BACKUP_DIR"
```

### 6. `pnpm`のバージョンを指定
`package.json` の `packageManager` に追記
``` json
{
  "packageManager": "pnpm@10.33.2",
}
```

### 7. `.gitignore`に追記
``` sh
echo '.direnv' >> .gitignore
```

