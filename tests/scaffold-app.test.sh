#!/usr/bin/env bash
set -euo pipefail

# Mock only pnpm; exercise the extracted shell with real filesystem operations.
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "$repo_dir/.scaffold-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
script="$test_root/scaffold.sh"
awk '/^  text = / { body = 1; next }
     body && /^  \047\047;/ { exit }
     body { gsub(/\047\047[$][{]/, "${"); print }' \
  "$repo_dir/nix/scaffold-app.nix" > "$script"
bash -n "$script"

pnpm() {
  printf '%s\n' "$PWD" > "$TEST_LOG"
  printf '%s\n' "$*" >> "$TEST_LOG"
  local target
  case "$1 $2" in
    'create vite@latest')
      [[ " $* " == *' --no-immediate '* ]] || return 80
      target="$3"
      ;;
    'create next-app@latest')
      # Pass only the target so create-next-app keeps its interactive prompts.
      [ "$#" -eq 3 ] || return 81
      target="$3"
      ;;
    'create astro@latest')
      [[ " $* " == *' --no-install '* ]] || return 84
      [[ " $* " == *' --no-git '* ]] || return 85
      target="$3"
      ;;
    'dlx @tanstack/cli@latest')
      [[ " $* " == *' --blank '* ]] || return 86
      [[ " $* " == *' --no-install '* ]] || return 87
      [[ " $* " == *' --no-git '* ]] || return 88
      target="$6"
      ;;
    *) return 89 ;;
  esac
  # Absolute targets cause nested paths with CLIs that join cwd and target.
  [ "$target" = ./example-app ] || return 90
  if [ "$TEST_SCENARIO" = cancelled ]; then return 0; fi
  mkdir -p "$target"
  printf '{"name":"generated"}\n' > "$target/package.json"
  if [ "$TEST_SCENARIO" = failure ]; then return 42; fi
}
export -f pnpm

for scenario in vite next astro tanstack failure cancelled invalid; do
  case_dir="$test_root/$scenario"
  project="$case_dir/example-app"
  mkdir -p "$project/.git"
  printf 'original manifest\n' > "$project/package.json"
  printf 'original policies\n' > "$project/pnpm-workspace.yaml"
  printf 'original ignore\n' > "$project/.gitignore"
  printf 'git marker\n' > "$project/.git/marker"
  cp -R "$project" "$case_dir/before"
  export TEST_LOG="$case_dir/commands.log" TEST_SCENARIO="$scenario"
  framework="$scenario"
  case "$scenario" in failure|cancelled) framework=tanstack ;; esac
  status=0
  (cd "$project" && bash "$script" "$framework") > "$case_dir/output" 2>&1 || status=$?
  diff -r -x '.scaffold.*' "$case_dir/before" "$project"
  case "$scenario" in
    invalid)
      [ "$status" -eq 1 ]
      [ ! -e "$TEST_LOG" ]
      [ -z "$(find "$project" -name '.scaffold.*' -print)" ]
      ;;
    *)
      work_dir="$(head -n 1 "$TEST_LOG")"
      [ "$(dirname "$work_dir")" = "$project" ]
      [ -d "$work_dir" ]
      [ "$(wc -l < "$TEST_LOG" | tr -d ' ')" -eq 2 ]
      grep -Fq "Generated files (retained): $work_dir/example-app" "$case_dir/output"
      grep -Fq "Temporary directory: $work_dir" "$case_dir/output"
      case "$scenario" in
        failure) [ "$status" -eq 42 ]; [ -f "$work_dir/example-app/package.json" ] ;;
        cancelled) [ "$status" -eq 1 ]; [ ! -e "$work_dir/example-app/package.json" ] ;;
        *) [ "$status" -eq 0 ]; [ -f "$work_dir/example-app/package.json" ] ;;
      esac
      [ "$(find "$work_dir" -name package.json | wc -l | tr -d ' ')" -le 1 ]
      ;;
  esac
  printf 'PASS: %s\n' "$scenario"
done

# Omitting the framework must not create a directory or invoke pnpm.
status=0
(cd "$project" && bash "$script") > "$test_root/no-argument-output" 2>&1 || status=$?
[ "$status" -eq 1 ]
[ ! -e "$TEST_LOG" ]
printf 'PASS: missing argument\n'
