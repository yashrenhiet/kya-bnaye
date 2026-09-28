#!/usr/bin/env bash
# Local quality gate for kya_core that avoids the Dart SDK's `dartaotruntime`.
#
# macOS security tooling on the dev Mac removes `dartaotruntime` (and other
# Flutter host binaries), which breaks `dart analyze` and `dart test`. This
# script runs the same gates on the JIT VM instead:
#   1. dart format --set-exit-if-changed   (format does not need the AOT runtime)
#   2. tool/analyze.dart                   (JIT analysis server, fatal infos)
#   3. package:test with --compiler=source (JIT, no frontend_server)
#   4. line coverage for packages/kya_core/lib, with an optional minimum
#
# CI (Linux) still runs the real `dart analyze` / `dart test`; see
# .github/workflows/ci.yml. See AGENTS.md section 9 for background.
#
# Usage (from anywhere in the repo, after `flutter pub get`):
#   tool/check.sh                  # all gates, report coverage
#   MIN_COVERAGE=90 tool/check.sh  # also fail below 90% line coverage
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_config="$repo_root/.dart_tool/package_config.json"
core_dir="$repo_root/packages/kya_core"
coverage_dir="$core_dir/coverage"

if [[ ! -f "$package_config" ]]; then
  echo "check: $package_config missing; run 'flutter pub get' at the repo root." >&2
  exit 2
fi

# Prints the on-disk root of a resolved package from package_config.json.
package_root() {
  local root
  root="$(grep -A1 "\"name\": \"$1\"" "$package_config" \
    | sed -n 's#.*"rootUri": "file://\(.*\)".*#\1#p')"
  if [[ -z "$root" || ! -d "$root" ]]; then
    echo "check: package '$1' not resolved; run 'flutter pub get'." >&2
    exit 2
  fi
  echo "$root"
}

jit_dart() {
  dart --packages="$package_config" "$@"
}

echo "==> format"
dart format --output=none --set-exit-if-changed "$repo_root"

echo "==> analyze"
(cd "$repo_root" && jit_dart tool/analyze.dart)

echo "==> test (kya_core)"
rm -rf "$coverage_dir"
(cd "$core_dir" && jit_dart "$(package_root test)/bin/test.dart" \
  --compiler=source --coverage="$coverage_dir")

echo "==> coverage (kya_core/lib)"
(cd "$core_dir" && jit_dart "$(package_root coverage)/bin/format_coverage.dart" \
  --lcov --in="$coverage_dir" --out="$coverage_dir/lcov.info" \
  --report-on=lib --package=.)
awk -F: -v min="${MIN_COVERAGE:-0}" '
  /^LF:/ { found += $2 }
  /^LH:/ { hit += $2 }
  END {
    pct = found ? 100 * hit / found : 0
    printf "line coverage: %d/%d = %.1f%% (minimum %s%%)\n", hit, found, pct, min
    exit (pct + 0 < min + 0) ? 1 : 0
  }' "$coverage_dir/lcov.info"
