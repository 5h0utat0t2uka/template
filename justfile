default:
  @just --list

runtime:
  nix run .#update-runtimes

prek:
  nix run .#prek
