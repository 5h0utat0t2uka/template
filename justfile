default:
  @just --list

runtime:
  # `package.json` の指定に従って `nix/runtimes.lock.json` を再生成する
  nix run .#update-runtimes

prek:
  # `prek run --all-files` を実行
  nix run .#prek
