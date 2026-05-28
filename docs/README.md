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

以下の引数を指定したコマンドでリポジトリを作成  

| argument | required | default | description |
|:---|:---|:---|:---|
| `OWNER`          | required | -        | GitHub のユーザー名もしくは組織名 |
| `REPO`           | required | -        | リポジトリ名 |
| `VISIBILITY`     | optional | `public` | `public`, `private`, `internal` のいずれか |
| `COPILOT_REVIEW` | optional | `false`  | `true`もしくは`false` |

``` sh
nix run github:5h0utat0t2uka/template#create-project -- OWNER REPO VISIBILITY COPILOT_REVIEW
```

## 2. プロジェクトの設定
``` sh
cd REPO
git switch -c dev
```

- [`nix/fixed-node.nix`](../nix/fixed-node.nix) の `nodeVersion`, `pnpmVersion` をプロジェクトに合わせて変更  
- [`pnpm-workspace.yaml`](../pnpm-workspace.yaml) の内容をプロジェクトに合わせて変更  
- Dependabotの設定  
  - [`.github/dependabot.yml`](../.github/dependabot.yml) の `assignees`を変更  
  - PRラベルを作成  
  ``` sh
  gh label create "dependencies" --color "#C7C7C7" 
  gh label create "github-actions" --color "#474747" 
  gh label create "npm" --color "#CC3534" 
  gh label create "nix" --color "#4D6FB7" 
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

``` sh
# Vite (Select "Ignore files and continue" when prompted)
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

## 8. リモートに反映  
- コミットしてプッシュ  
``` sh
git add .
git commit -m "setup project"
git push -u origin dev
gh pr create --base main --head dev --fill
```

- CI通過後に`main`にマージ  
``` sh
gh pr merge --squash
```

- `dev`ブランチを`main`に揃える  
``` sh
git switch main
git pull --ff-only
git switch dev
git reset --hard main
git push --force-with-lease
```

