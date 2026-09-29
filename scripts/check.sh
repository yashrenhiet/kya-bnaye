#!/usr/bin/env bash
# Quality gate for the KyaCore Swift package. Fails (non-zero exit) on any
# format violation, compiler warning, failing test (in the local time zone and
# under America/New_York DST), forbidden import (UI/persistence frameworks, or
# XCTest/Testing in a library target), oversized file, or line coverage of
# KyaCore/Sources (KyaCore and KyaCoreContracts) below MIN_COVERAGE (default 90).
#
# Usage: scripts/check.sh            (from anywhere)
#        MIN_COVERAGE=95 scripts/check.sh
#        APP=1 scripts/check.sh      (also lint, build and test the iOS app; ~5 min)
#        APP=1 APP_DESTINATION='platform=iOS Simulator,name=iPhone 16' scripts/check.sh
#        (default: the newest available iPhone simulator; the full xcodebuild log is kept
#        at build-logs/xcodebuild-app.log)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PACKAGE="KyaCore"
MIN_COVERAGE="${MIN_COVERAGE:-90}"
MAX_FILE_LINES=400
# Same flags for every build/test step so SwiftPM does not rebuild between them.
SWIFT_FLAGS=(-Xswiftc -warnings-as-errors)

step() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nFAIL: %s\n' "$*" >&2; exit 1; }

step "Format lint (swift format, strict)"
swift format lint --strict --recursive \
    --configuration "$PACKAGE/.swift-format" \
    "$PACKAGE/Sources" "$PACKAGE/Tests" || fail "swift format lint reported violations"

step "Architecture rules (Foundation-only core, files < $MAX_FILE_LINES lines)"
forbidden_import='^[[:space:]]*(@[A-Za-z]+[[:space:]]+)*([a-z]+[[:space:]]+)?import[[:space:]]+'
forbidden_import+='(SwiftUI|SwiftData|UIKit|AppKit|Combine)([[:space:].]|$)'
if grep -rnE "$forbidden_import" "$PACKAGE/Sources"; then
    fail "KyaCore must only depend on Foundation"
fi
# Library targets (including KyaCoreContracts) must stay test-framework agnostic.
test_import='^[[:space:]]*(@[A-Za-z]+[[:space:]]+)*([a-z]+[[:space:]]+)?import[[:space:]]+'
test_import+='(XCTest|Testing)([[:space:].]|$)'
if grep -rnE "$test_import" "$PACKAGE/Sources"; then
    fail "library targets must not import XCTest or Testing"
fi
oversized="$(find "$PACKAGE/Sources" "$PACKAGE/Tests" -name '*.swift' -print0 \
    | xargs -0 wc -l | awk -v max="$MAX_FILE_LINES" '$2 != "total" && $1 >= max')"
if [[ -n "$oversized" ]]; then
    printf '%s\n' "$oversized" >&2
    fail "files must stay under $MAX_FILE_LINES lines"
fi

step "Build library and tests with warnings as errors"
swift build --package-path "$PACKAGE" --build-tests "${SWIFT_FLAGS[@]}" \
    || fail "build failed or emitted warnings"

step "Tests with code coverage (TZ=${TZ:-system default})"
test_log="$(mktemp)"
trap 'rm -f "$test_log"' EXIT
swift test --package-path "$PACKAGE" --enable-code-coverage "${SWIFT_FLAGS[@]}" 2>&1 \
    | tee "$test_log" || fail "tests failed"
test_summary="$(grep -E 'Test run with [0-9]+ tests' "$test_log" | tail -1 || true)"

step "Coverage of $PACKAGE/Sources"
codecov_json="$(swift test --package-path "$PACKAGE" --enable-code-coverage \
    --show-codecov-path "${SWIFT_FLAGS[@]}")"
[[ -f "$codecov_json" ]] || fail "coverage report not found at $codecov_json"
coverage="$(python3 - "$codecov_json" "$REPO_ROOT/$PACKAGE/Sources/" <<'PY'
import json
import sys

report_path, sources_prefix = sys.argv[1], sys.argv[2]
with open(report_path, encoding="utf-8") as handle:
    report = json.load(handle)

count = covered = 0
rows = []
for export in report["data"]:
    for entry in export["files"]:
        name = entry["filename"]
        if not name.startswith(sources_prefix):
            continue
        lines = entry["summary"]["lines"]
        count += lines["count"]
        covered += lines["covered"]
        rows.append((name[len(sources_prefix):], lines["covered"], lines["count"]))

if count == 0:
    sys.exit("no source files found in coverage report")
for name, file_covered, file_count in sorted(rows):
    percent = 100.0 * file_covered / file_count if file_count else 100.0
    print(f"  {percent:6.2f}%  {file_covered:5d}/{file_count:<5d} {name}", file=sys.stderr)
print(f"{100.0 * covered / count:.2f}")
PY
)" || fail "could not compute coverage"
echo "  total: ${coverage}% (minimum ${MIN_COVERAGE}%)"

step "Tests under TZ=America/New_York (DST)"
TZ=America/New_York swift test --package-path "$PACKAGE" "${SWIFT_FLAGS[@]}" \
    || fail "tests failed under TZ=America/New_York"

step "Coverage gate"
if ! python3 -c "import sys; sys.exit(0 if float('$coverage') >= float('$MIN_COVERAGE') else 1)"; then
    fail "line coverage ${coverage}% is below ${MIN_COVERAGE}%"
fi

if [[ "${APP:-0}" == "1" ]]; then
    APP_PROJECT="KyaBnaye/KyaBnaye.xcodeproj"
    APP_SOURCES=(KyaBnaye/KyaBnaye KyaBnaye/KyaBnayeTests KyaBnaye/KyaBnayeUITests)
    if [[ -z "${APP_DESTINATION:-}" ]]; then
        # Newest iOS runtime first, then device name, so the pick is stable per machine.
        sim_id="$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
def version(runtime):
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return (int(match[1]), int(match[2])) if match else (-1, -1)
phones = sorted(
    ((version(runtime), device["name"], device["udid"])
     for runtime, devices in json.load(sys.stdin)["devices"].items()
     if "SimRuntime.iOS" in runtime
     for device in devices if device["name"].startswith("iPhone")),
    key=lambda phone: (phone[0], phone[1]), reverse=True)
print(phones[0][2] if phones else "")
')"
        [[ -n "$sim_id" ]] || fail "no available iPhone simulator (xcrun simctl list devices)"
        APP_DESTINATION="platform=iOS Simulator,id=$sim_id"
    fi

    step "App: format lint (swift format, strict)"
    swift format lint --strict --recursive \
        --configuration "$PACKAGE/.swift-format" \
        "${APP_SOURCES[@]}" || fail "swift format lint reported violations in the app"

    step "App: architecture rules (no SwiftData in views, files < $MAX_FILE_LINES lines)"
    swiftdata_import='^[[:space:]]*(@[A-Za-z]+[[:space:]]+)*([a-z]+[[:space:]]+)?import[[:space:]]+'
    swiftdata_import+='SwiftData([[:space:].]|$)'
    if grep -rnE "$swiftdata_import" KyaBnaye/KyaBnaye/Features KyaBnaye/KyaBnaye/Shared; then
        fail "views must not import SwiftData (AGENTS.md section 5.3)"
    fi
    oversized_app="$(find "${APP_SOURCES[@]}" -name '*.swift' -print0 \
        | xargs -0 wc -l | awk -v max="$MAX_FILE_LINES" '$2 != "total" && $1 >= max')"
    if [[ -n "$oversized_app" ]]; then
        printf '%s\n' "$oversized_app" >&2
        fail "app files must stay under $MAX_FILE_LINES lines"
    fi

    step "App: build and test on $APP_DESTINATION (warnings are errors via project settings)"
    # Kept (not a temp file) so a failure can be read in full afterwards.
    mkdir -p build-logs
    app_log="build-logs/xcodebuild-app.log"
    # -retry-tests-on-failure: GitHub's macOS runners have proven measurably slower and
    # occasionally flaky under load (a UI-test timing assertion or an on-device
    # accessibility-audit snapshot taken mid-transition, observed 2026-09-29) in ways that
    # don't reproduce locally. This retries only the tests that actually failed, up to
    # Xcode's default attempt count — a test that is genuinely broken still fails every
    # attempt and still fails the gate; only transient flakes get absorbed.
    if ! xcodebuild -project "$APP_PROJECT" -scheme KyaBnaye -destination "$APP_DESTINATION" \
        -retry-tests-on-failure \
        build test CODE_SIGNING_ALLOWED=NO >"$app_log" 2>&1; then
        # Compiler errors sit far above the footer, and a compiler crash prints a stack
        # dump instead of an `error:` line, so show those before the tail.
        printf '\n--- diagnostics ---\n' >&2
        grep -nE '(error|fatal error): |Stack dump|PLEASE submit a bug report|failed \(' \
            "$app_log" | head -n 200 >&2 || true
        printf '\n--- last 60 lines ---\n' >&2
        tail -n 60 "$app_log" >&2
        fail "app build or tests failed (full log: $REPO_ROOT/$app_log)"
    fi
    app_summary="$(grep -E 'Executed [0-9]+ tests?' "$app_log" | tail -1 | sed 's/^[[:space:]]*//' || true)"
fi

printf '\n==> Summary\n'
echo "  format lint:      ok"
echo "  architecture:     ok"
echo "  build (-Werror):  ok"
echo "  tests:            ${test_summary:-ok}"
echo "  tests (New York): ok"
echo "  line coverage:    ${coverage}% (>= ${MIN_COVERAGE}%)"
if [[ "${APP:-0}" == "1" ]]; then
    echo "  app lint/arch:    ok"
    echo "  app build+tests:  ok (UI tests: ${app_summary:-ok})"
else
    echo "  app:              skipped (set APP=1 to build and test the iOS app)"
fi
echo "PASS"
