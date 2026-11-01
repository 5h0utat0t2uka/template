# Frontend Template with Nix  
Template for setting up a development environment for front-end projects using direnv, flake.nix, and pnpm.  
This template includes basic security measures:  
- [Dependabot](https://docs.github.com/ja/code-security/tutorials/secure-your-dependencies/dependabot-quickstart-guide) for dependency auto updates  
- [GitHub Copilot](https://github.com/features/copilot) for code review with AI (optional)
- [OSV-Scanner](https://github.com/google/osv-scanner) for existing vulnerability scanning  
- [semgrep](https://github.com/semgrep/semgrep) for static application security testing
- [zizmor](https://github.com/zizmorcore/zizmor) for GitHub Actions static analysis  
- [Betterleaks](https://github.com/betterleaks/betterleaks) for secret scanning  
- [SOPS](https://github.com/getsops/sops) for secret encryption  

# Requirements  
- **Nix with flakes enabled**  
  If you have not installed Nix yet:  
  Install via [Determinate Nix installer](https://github.com/DeterminateSystems/nix-installer) or [Official Nix installer](https://github.com/NixOS/nix-installer)  

- **`gh` authentication**  
  If you have not authenticated `gh` yet:  
  ``` nix
  # Check authentication status 
  nix shell nixpkgs#gh -c gh auth status  

  # Run the following command to login
  nix shell nixpkgs#gh -c gh auth login  
  ```


## 1. リポジトリを作成
クローン先のディレクトリに移動
``` sh
cd path/to/parent-directory
```

以下のコマンドでリポジトリを作成  
``` sh
nix run github:5h0utat0t2uka/template#create-project -- OWNER REPO VISIBILITY COPILOT_REVIEW
```

引数の内容は下記  

| Argument | Required | Default | Description |
|:---|:---|:---|:---|
| `OWNER`          | required | -        | GitHub のユーザー名もしくは組織名 |
| `REPO`           | required | -        | GitHub のリポジトリ名 |
| `VISIBILITY`     | optional | `public` | GitHub の可視性を `public`, `private`, `internal` のいずれかで指定 |
| `COPILOT_REVIEW` | optional | `false`  | GitHub Copilot のレビュー可否を `true`もしくは`false` で指定 |

> [!TIP]
> スクリプトの内容は [`nix/create-project.nix`](../nix/create-project.nix) を参照

## 2. プロジェクトの設定
``` sh
cd REPO
```

- [`pnpm-workspace.yaml`](../pnpm-workspace.yaml) の内容をプロジェクトに合わせて変更  
- Dependabotの設定  
  - [`.github/dependabot.yml`](../.github/dependabot.yml.template) の `assignees`を変更  
  - PRラベルを作成:  
  ``` sh
  gh label create "dependencies" --color "#C7C7C7" 
  gh label create "github-actions" --color "#474747" 
  gh label create "npm" --color "#CC3534" 
  gh label create "nix" --color "#4D6FB7" 
  ```

テンプレートのDependabot, CIの設定内容は下記  

| File | Schedule | Description | Auto merge |
|:---|:---|:---|:---|
| [`dependabot.yml`](../.github/dependabot.yml.templrte) | 毎週日曜日の AM 04:00 | GitHub Actions, npm, flake.lock のバージョンを更新してPR作成 | 未設定 |
| [`ci.yml`](../.github/workflows/ci.yml)                | `main` ブランチへのPR | - 追加・更新された依存関係に対してOSSVデータベースから脆弱性を確認<br>- GitHub ActionsのLintや、シークレットの漏洩を確認<br>- `pnpm install --frozen-lockfile`を行い`lint`, `build`まで実行 | 未設定 |

## 3. `node`, `pnpm`バージョンの明示
ランタイムのバージョンは `package.json` のこの内容を参照して `nix/runtimes.nix` から `runtimes.lock.json` を作成して固定する  
``` json
{
  "engines": {
    "node": "26.x"
  },
  "devEngines": {
    "runtime": {
      "name": "node",
      "version": "26.13.0",
      "onFail": "warn"
    },
    "packageManager": {
      "name": "pnpm",
      "version": "12.17.0",
      "onFail": "download"
    }
  },
}
```

## 4. `.envrc`を作成
これにより `nix/runtimes.lock.json` が存在しない場合、もしくは `package.json` の `devEngines` のバージョンがロックファイルと異なる場合に、ハッシュの取得・計算を行い `nix/runtimes.lock.json` を更新する  
``` sh
cat > .envrc <<'EOF'
watch_dir nix
watch_file package.json
watch_file pnpm-lock.yaml
watch_file pnpm-workspace.yaml

needs_update=true
if [[ -f nix/runtimes.lock.json ]]; then
  runtimes_locked="$(nix eval --impure --expr '
    let
      engines = (builtins.fromJSON (builtins.readFile ./package.json)).devEngines;
      lock = builtins.fromJSON (builtins.readFile ./nix/runtimes.lock.json);
    in
      engines.runtime.version == lock.node.version
      && engines.packageManager.version == lock.pnpm.version
  ')" || {
    log_error "Failed to validate runtimes.lock.json"
    exit 1
  }
  [[ "$runtimes_locked" == true ]] && needs_update=false
fi
if [[ "$needs_update" == true ]]; then
  log_status "Updating nix/runtimes.lock.json"
  if ! nix run .#update-runtimes; then
    log_error "Failed to update-runtimes"
    exit 1
  fi
fi

use flake
EOF
```

## 5. `.envrc`の許可
`nix/runtimes.lock.json` をインデックスに追加  
``` sh
nix run .#update-runtimes
git add -N nix/runtimes.lock.json
```

`node` と `pnpm` のバージョン確認  
``` sh
direnv allow
node -v
pnpm -v
```

## 6. スキャフォールド  
各フレームワークはディレクトリ内に既存のファイルがある場合停止するため、プロジェクト内に一時ディレクトリを作成し、その直下に元のプロジェクト名で生成する  
``` sh
nix run .#scaffold-app -- vite
nix run .#scaffold-app -- next
nix run .#scaffold-app -- astro
nix run .#scaffold-app -- tanstack
```

生成された内容を確認して、調整を行い元のプロジェクトに取り込み、元々の`package.json` に関してはフレームワークの依存関係などを取り込みつつ `engines`, `devEngines` は保持する  
`pnpm-workspace.yaml`, `.gitignore` は両方の内容を統合し、元のプロジェクトで依存インストールとビルドを確認してから、一時ディレクトリを手動で削除する  

> [!TIP]
> スクリプトの内容は [`nix/scaffold-app.nix`](../nix/scaffold-app.nix) を参照  
> 一時ディレクトリは `.scaffold.XXXXXX/template` のような名前で作成  

## 7. リモートに反映  
- `dev`にコミットしてプッシュ  
``` sh
git add .
git commit -m "setup project"
git push -u origin dev
```

- PR作成後`main`にマージ  
``` sh
gh pr create --base main --head dev --fill
gh pr checks --watch
gh pr merge --squash --delete-branch
```

- ローカルをリモートの`main`に揃える  
``` sh
git switch main
git pull --ff-only --prune origin main
git fetch --prune origin
```
``` sh
git switch -c <branch-name> origin/main
```
