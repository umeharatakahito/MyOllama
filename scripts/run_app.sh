#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$PROJECT_ROOT"

echo "🔨 Building latest MyOllama.app..."
"$SCRIPT_DIR/build_app.sh"

echo "🔄 Closing any running MyOllama instances..."
pkill -x MyOllama || true
sleep 0.5

echo "🚀 Launching latest MyOllama.app from ${PROJECT_ROOT}..."
open "${PROJECT_ROOT}/MyOllama.app"
