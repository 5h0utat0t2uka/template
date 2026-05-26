# Frontend Template with Nix  
This repository is a template for setting up a development environment for front-end projects using direnv, flake.nix, and pnpm.  
This document provides an example of a Vite + React + TypeScript project.  

**REQUIREMENTS**  
- Nix with flakes enabled  
- GitHub CLI (`gh`) authentication  

If you have not authenticated GitHub CLI yet:
``` sh
nix shell nixpkgs#gh -c gh auth login
```

## プロジェクト作成・クローン
1. テンプレートからリポジトリを作成
``` sh
# クローンするディレクトリに移動
cd path/to/parent-directory
```
``` sh
# OWNER: GitHubのユーザー名または組織名 
# REPO: 作成するリポジトリ名
# VISIBILITY: public もしくは private
nix run github:5h0utat0t2uka/template#create-project -- OWNER REPO VISIBILITY
```

2. リポジトリに移動
``` sh
cd REPO
```
> [!TIP]
> `.github/dependabot.yml` の `open-pull-requests-limit: 0` を削除して有効化  
> `.github/dependabot.yml` の `assignees`を適時変更  

3. `.envrc`を作成
``` sh
echo 'watch_dir nix
watch_file pnpm-lock.yaml
use flake' >> .envrc
```

4. `.envrc`の許可
``` sh
direnv allow

# nodeとpnpmのバージョン確認
node -v
pnpm -v
```

5. フレームワークのスキャフォールド
`flake.nix`で定義した`writeShellApplication`を使用

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

`package.json` の `packageManager` にpnpmのバージョンを追加
``` json
{
  "packageManager": "pnpm@10.33.2",
}
```

6. `.gitignore`に追記
``` sh
echo '.direnv' >> .gitignore
```

