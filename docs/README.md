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
git switch -c dev
```

- [`nix/fixed-node.nix`](../nix/fixed-node.nix) の `nodeVersion`, `pnpmVersion` をプロジェクトに合わせて変更  
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

## 3. `.envrc`を作成
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

## 4. `.envrc`の許可
``` sh
git add -N nix/runtimes.lock.json
```
``` sh
direnv allow

# node と pnpm のバージョン確認
node -v
pnpm -v
```

## 5. スキャフォールド  
**手動取り込み版: `scaffold-app-manual`**

プロジェクト内に `.scaffold.XXXXXX` という一時ディレクトリを作成し、その直下に元のプロジェクト名で生成します（例: `template/.scaffold.XXXXXX/template/package.json`）。CLI には相対パスを渡します。依存インストールはスキップし、生成物の取り込み・manifest の統合・Agent Skills の設定は行いません。成功・失敗のどちらでも一時ディレクトリを残し、生成先の絶対パスを表示します。

``` sh
nix run .#scaffold-app-manual -- vite
nix run .#scaffold-app-manual -- next
nix run .#scaffold-app-manual -- astro
nix run .#scaffold-app-manual -- tanstack
```

生成された内容を確認して元のプロジェクトに取り込みます。`package.json` は scripts・依存関係などを取り込みつつ、元の `engines`・`devEngines` を保持してください。`pnpm-workspace.yaml` は元の保護設定を保持し、`.gitignore` は両方の内容を統合します。元のプロジェクトで依存インストールとビルドを確認してから、一時ディレクトリを手動で削除してください。

TanStack は React の `blank` 構成を生成します。Agent Skills が必要な場合は、元のプロジェクトに取り込んで依存インストールを完了してから `pnpm dlx @tanstack/intent@latest install --map` を実行してください。

> [!TIP]
> スクリプトの内容は [`nix/scaffold-app-manual.nix`](../nix/scaffold-app-manual.nix) を参照

**自動取り込み版: `scaffold-app-auto`（従来の処理）**

初期の `package.json` の `engines`・`devEngines` を保持し、各フレームワークを一時ディレクトリに生成してから統合します。生成された scripts・依存関係を取り込み、元の `pnpm-workspace.yaml` の保護設定で依存解決・インストールを行います。すでに scripts・依存関係・`pnpm-lock.yaml`・`node_modules` があるプロジェクトでは停止します。

生成側の Node.js・pnpm 要件が固定バージョンと両立しない場合は、取り込み前に停止します。依存解決・インストールで失敗した場合は生成物を残すため、原因を解消して失敗した段階から再開してください。スキャフォールド全体の再実行は既存プロジェクトとして拒否されます。

> [!TIP]
> スクリプトの内容は [`nix/scaffold-app-auto.nix`](../nix/scaffold-app-auto.nix) を参照

``` sh
# Vite
nix run .#scaffold-app-auto -- vite

# Next.js
nix run .#scaffold-app-auto -- next

# Astro
nix run .#scaffold-app-auto -- astro

# TanStack Start (React / blank)
nix run .#scaffold-app-auto -- tanstack
```

<!--TanStack Start は [`--blank`](https://tanstack.com/cli/latest/docs/cli-reference) で最小構成を生成し、のアドオンは追加しない  
依存関係のインストール後、`pnpm dlx @tanstack/intent@latest install --map` で [TanStack Intent](https://tanstack.com/intent/latest/docs/overview) の Agent Skills を設定します。インストール済みライブラリを対象に、`AGENTS.md` などへ Skills の読み込み案内とタスクとの対応付けを追加します。生成中は `--no-install` を使うため、`--intent` による設定はこの段階まで待ちます。Intent の設定が失敗した場合も停止するため、原因を解消してこのコマンドを再実行してください。

TanStack の生成先は一時ディレクトリです。初期の `package.json` は生成された内容と統合し、他の既存ファイルは保持します。`.gitignore` は追記で統合します。すでに scripts・依存関係・`pnpm-lock.yaml`・`node_modules` がある場合は停止します。

`pnpm-workspace.yaml` は生成されたものを採用せず、このテンプレートの設定を維持します。`allowBuilds` を変更せず、`minimumReleaseAge: 10080`（7日）と `trustPolicy: no-downgrade` を適用します。`semver@6.3.1` の例外は、同ファイルに記載した上流の provenance の問題に対応するものです。

固定バージョンの指定は初期の `devEngines` に統一し、生成された `packageManager` は除去します。`@types/node` のメジャーバージョンを固定した Node.js に合わせます。その後、Start と Router の v1 から公開後の待機期間を満たすバージョンを解決して完全固定し、ロックファイルを作成して `pnpm install --frozen-lockfile` を実行します。他の依存関係も含め、[pnpm のポリシー](https://pnpm.io/settings)を満たせなければ設定を緩和せずに停止します。依存解決・インストールで停止した場合、生成済みファイルは残るため、原因を解消してその段階のコマンドから再開してください。

TanStack では手順6・7も自動で反映します。生成後は次のコマンドで動作を確認してください。

``` sh
nix develop -c pnpm run build
nix develop -c pnpm run dev
```-->

## 6. `node`, `pnpm`バージョンの明示
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

## 7. `.gitignore`に追記
フレームワークにより生成される内容は異なるため、プロジェクトに合わせて調整  
``` sh
echo '.direnv
.pre-commit-config.yaml
.env' >> .gitignore
```

## 8. リモートに反映  
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
