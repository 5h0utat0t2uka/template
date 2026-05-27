# Frontend Template with Nix  
Template for setting up a development environment for front-end projects using direnv, flake.nix, and pnpm.  
This template includes basic security measures that Dependabot, zizmor, GitLeaks, and SOPS encryption.  

# Requirements  
- **Nix with flakes enabled**  
  If you have not installed Nix yet:  
  Install via [Determinate Nix installer](https://github.com/DeterminateSystems/nix-installer) or [Official Nix installer](https://github.com/NixOS/nix-installer)  

- **`gh` authentication**  
  If you have not authenticated `gh` yet:  
  ``` nix
  nix shell nixpkgs#gh -c gh auth login  
  ```


## 1. リポジトリを作成
クローン先のディレクトリに移動
``` sh
cd path/to/parent-directory
```

`OWNER`にGitHubのユーザー名または組織名, `REPO`に作成するリポジトリ名, `VISIBILITY`に`public`もしくは`privare` を指定してリポジトリを作成
``` sh
nix run github:5h0utat0t2uka/template#create-project -- OWNER REPO VISIBILITY
```

## 2. プロジェクトの設定
``` sh
cd REPO
```

- [`nix/fixed-node.nix`](../nix/fixed-node.nix) の `nodeVersion`, `pnpmVersion` をプロジェクトに合わせて変更  
- [`pnpm-workspace.yaml`](../pnpm-workspace.yaml) の内容をプロジェクトに合わせて変更  
- [`CI`](../.github/workflows/ci.yml) を有効化  
``` sh
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  "/repos/OWNER/REPO/actions/workflows/ci.yml/enable"
```
- Dependabotの設定  
  - [`.github/dependabot.yml`](../.github/dependabot.yml) の `open-pull-requests-limit: 0` を削除して有効化  
  - [`.github/dependabot.yml`](../.github/dependabot.yml) の `assignees`を変更  
  - PRラベルを作成  
  ``` sh
  gh label create "dependencies" --color "#C7C7C7" 
  gh label create "github-actions" --color "#474747" 
  gh label create "npm" --color "#CC3534" 
  ```

> [!TIP]
> 必要に応じて[PRのauto merge](https://docs.github.com/ja/code-security/tutorials/secure-your-dependencies/automating-dependabot-with-github-actions#enabling-automerge-on-a-pull-request)を有効にする  

## 3. `.envrc`を作成
``` sh
echo 'watch_dir nix
watch_file pnpm-lock.yaml
use flake' >> .envrc
```

## 4. `.envrc`の許可
``` sh
direnv allow

# node と pnpm のバージョン確認
node -v
pnpm -v
```

## 5. スキャフォールド  
フレームワークによってプロジェクトルートの既存ファイルがスキャフォールドを止めるため、下記のコマンドで一時的に既存ファイルを親ディレクトリに退避させる薄いラッパースクリプトを実行   

> [!TIP]
> スクリプトの内容は [`nix/scaffold-app.nix`](../nix/scaffold-app.nix) を参照

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

## 6. `pnpm`バージョンの明示
`package.json` の `packageManager` に追記
``` json
{
  "packageManager": "pnpm@10.33.2",
}
```

`pnpm`のバージョンが`11.0.0`以降の場合
``` json
{
  "devEngines": {
    "packageManager": {
      "name": "pnpm",
      "version": ">=11.0.0"
      "onFail": "error"
    }
  }
}
```

## 7. `.gitignore`に追記
フレームワークにより生成される内容は異なるため、プロジェクトに合わせて調整  
``` sh
echo '.direnv' >> .gitignore
```

