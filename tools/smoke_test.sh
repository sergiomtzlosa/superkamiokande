#!/bin/bash
# Launch the built app in automated screenshot mode and verify both the
# AppKit chrome and the Metal scene are produced. Run after building the app:
#
#   xcodebuild -project SuperKamiokande.xcodeproj -scheme SuperKamiokande \
#              -configuration Debug -derivedDataPath ./build build
#   tools/smoke_test.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${SKO_BUILD_DIR:-$ROOT/build}"
APP="$BUILD_DIR/Build/Products/Debug/SuperKamiokande.app"
BIN="$APP/Contents/MacOS/SuperKamiokande"
OUT="$BUILD_DIR/smoke"
mkdir -p "$OUT"

if [[ ! -x "$BIN" ]]; then
    echo "error: app binary not found at $BIN" >&2
    echo "Build first: xcodebuild -project SuperKamiokande.xcodeproj -scheme SuperKamiokande -configuration Debug -derivedDataPath ./build build" >&2
    exit 1
fi

for resource in AppIcon.icns CavernRock.png WaterSurface.png CavernEnvironment.jpg; do
    if [[ ! -s "$APP/Contents/Resources/$resource" ]]; then
        echo "error: missing app resource: $resource" >&2
        exit 1
    fi
done

run_case() {
    local name="$1"
    local expected="$2"
    shift 2
    local log="$OUT/$name.log"
    local shot="$OUT/$name.png"
    local sceneshot="$OUT/$name-scene.png"
    rm -f "$log" "$shot" "$sceneshot"

    SKO_SMOKE_TEST=1 SKO_SCREENSHOT="$shot" "$@" "$BIN" >"$log" 2>&1 &
    local pid=$!
    for _ in $(seq 1 24); do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 0.25
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        echo "error: $name timed out" >&2
        cat "$log" >&2
        exit 1
    fi
    wait "$pid" || true

    if ! grep -q "SKO smoke: window=yes scene=yes sidebar=yes labels=yes $expected" "$log"; then
        echo "error: unexpected smoke log for $name" >&2
        cat "$log" >&2
        exit 1
    fi
    if [[ ! -s "$shot" || ! -s "$sceneshot" ]]; then
        echo "error: screenshots were not written for $name" >&2
        exit 1
    fi
    if [[ "$expected" == *"helpVisible=yes"* && ! -s "$OUT/$name-help.png" ]]; then
        echo "error: help screenshot was not written for $name" >&2
        exit 1
    fi
    echo "PASS  $name  ($(du -h "$shot" | cut -f1) UI / $(du -h "$sceneshot" | cut -f1) scene)"
}

echo "Smoke-testing $APP"
run_case "default" "sidebarVisible=yes labelsVisible=yes helpVisible=no"
run_case "collapsed-no-labels" "sidebarVisible=no labelsVisible=no helpVisible=no" \
    env SKO_START_COLLAPSED=1 SKO_START_LABELS_HIDDEN=1
run_case "help" "sidebarVisible=yes labelsVisible=yes helpVisible=yes" \
    env SKO_START_HELP=1
echo "Smoke test passed. Artifacts: $OUT"
