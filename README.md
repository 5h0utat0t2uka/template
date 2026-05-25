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
# OWNER: GitHubのユーザー名, REPO: 作成するリポジトリ名, public/privateを選択
nix run github:5h0utat0t2uka/template -- OWNER REPO public
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

5. `create vite`でreactのテンプレート作成
> [!TIP]
> Ignore files and continue を選択する

``` sh
pnpm create vite .
```
`package.json` の `packageManager` にpnpmのバージョンを追加
``` json
{
  "packageManager": "pnpm@10.33.2",
}
```

6. `.gitignore`に`.direnv`を追加
``` sh
echo '.direnv' >> .gitignore
```

