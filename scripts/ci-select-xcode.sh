#!/usr/bin/env bash
# CI only: selects the newest installed non-beta Xcode (exported via GITHUB_ENV when run in
# GitHub Actions) and fails fast if its Swift is older than the app needs. The app uses
# `@concurrent` (SE-0461), which needs Swift 6.2 / Xcode 26.
set -euo pipefail

MIN_SWIFT="6.2"

newest="$(find /Applications -maxdepth 1 -name 'Xcode*.app' ! -iname '*beta*' | sort -V | tail -1)"
[[ -n "$newest" ]] || { echo "::error::no Xcode found in /Applications"; exit 1; }
export DEVELOPER_DIR="$newest/Contents/Developer"
if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "DEVELOPER_DIR=$DEVELOPER_DIR" >>"$GITHUB_ENV"
fi
echo "Selected $newest"
xcodebuild -version
swift --version

swift_version="$(swift --version 2>&1 | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+).*/\1/p' | head -1)"
if ! printf '%s\n%s\n' "$MIN_SWIFT" "$swift_version" | sort -V -C; then
    echo "::error::Swift $swift_version is older than $MIN_SWIFT (needed for @concurrent)"
    exit 1
fi
