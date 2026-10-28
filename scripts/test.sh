#!/bin/sh
# Local CI: syntax check, unit tests, build, place verification, headless engine smoke
# (incl. a full bot-only round and the phone HUD layouts).
set -e
cd "$(dirname "$0")/.."
BIN="${TOOLS_BIN:-.tools/bin}"
[ -x "$BIN/lune" ] || BIN="$HOME/.rokit/bin"
"$BIN/lune" run scripts/check_syntax.luau
"$BIN/lune" run tests/run.lune.luau
mkdir -p build
"$BIN/rojo" build -o build/ClockworkMasquerade.rbxl
"$BIN/rojo" build production.project.json -o build/ClockworkMasquerade.production.rbxl
"$BIN/lune" run scripts/verify_place.luau build/ClockworkMasquerade.rbxl
"$BIN/lune" run scripts/engine_smoke.luau build/ClockworkMasquerade.rbxl
if [ -x "$BIN/stylua" ]; then "$BIN/stylua" --check src tests scripts >/dev/null 2>&1 || echo "(stylua: formatting differences, non-fatal)"; fi
echo "ALL LOCAL CHECKS PASSED"
