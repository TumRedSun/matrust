#!/usr/bin/env bash
# scripts/build.sh — release build helper.
set -euo pipefail

cd "$(dirname "$0")/.."

# Use qmake6 if available, otherwise qmake.
if command -v qmake6 >/dev/null 2>&1; then
    export QMAKE="${QMAKE:-$(command -v qmake6)}"
elif command -v qmake >/dev/null 2>&1; then
    export QMAKE="${QMAKE:-$(command -v qmake)}"
else
    echo "ERROR: qmake / qmake6 not found. Install Qt 6 development packages." >&2
    exit 1
fi

echo "Using QMAKE=$QMAKE"
cargo build --release "$@"
echo
echo "Release binary: target/release/matrix-client"
