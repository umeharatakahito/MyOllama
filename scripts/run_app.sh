#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$PROJECT_ROOT"

if [ ! -d "${PROJECT_ROOT}/MyOllama.app" ]; then
    echo "⚠️ MyOllama.app not found. Building now..."
    "$SCRIPT_DIR/build_app.sh"
fi

echo "🚀 Launching MyOllama.app from ${PROJECT_ROOT}..."
open "${PROJECT_ROOT}/MyOllama.app"
