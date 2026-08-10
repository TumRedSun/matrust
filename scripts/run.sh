#!/usr/bin/env bash
# scripts/run.sh — debug build + run.
set -euo pipefail

cd "$(dirname "$0")/.."

if command -v qmake6 >/dev/null 2>&1; then
    export QMAKE="${QMAKE:-$(command -v qmake6)}"
elif command -v qmake >/dev/null 2>&1; then
    export QMAKE="${QMAKE:-$(command -v qmake)}"
fi

RUST_LOG="${RUST_LOG:-info}" cargo run "$@"
