#!/bin/bash
# Setup script for bats testing framework

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_DIR="$SCRIPT_DIR/bats"

echo "🔧 Setting up bats testing framework..."

# Create bats directory structure
mkdir -p "$BATS_DIR"/{bats-core,bats-support,bats-assert,bats-file}

# Install bats-core
if [ ! -d "$BATS_DIR/bats-core" ] || [ -z "$(ls -A "$BATS_DIR/bats-core")" ]; then
    echo "📦 Installing bats-core..."
    git clone --depth 1 https://github.com/bats-core/bats-core.git "$BATS_DIR/bats-core"
    rm -rf "$BATS_DIR/bats-core/.git"
fi

# Install bats-support (helper functions)
if [ ! -d "$BATS_DIR/bats-support" ] || [ -z "$(ls -A "$BATS_DIR/bats-support")" ]; then
    echo "📦 Installing bats-support..."
    git clone --depth 1 https://github.com/bats-core/bats-support.git "$BATS_DIR/bats-support"
    rm -rf "$BATS_DIR/bats-support/.git"
fi

# Install bats-assert (assertion helpers)
if [ ! -d "$BATS_DIR/bats-assert" ] || [ -z "$(ls -A "$BATS_DIR/bats-assert")" ]; then
    echo "📦 Installing bats-assert..."
    git clone --depth 1 https://github.com/bats-core/bats-assert.git "$BATS_DIR/bats-assert"
    rm -rf "$BATS_DIR/bats-assert/.git"
fi

# Install bats-file (file system assertions)
if [ ! -d "$BATS_DIR/bats-file" ] || [ -z "$(ls -A "$BATS_DIR/bats-file")" ]; then
    echo "📦 Installing bats-file..."
    git clone --depth 1 https://github.com/bats-core/bats-file.git "$BATS_DIR/bats-file"
    rm -rf "$BATS_DIR/bats-file/.git"
fi

# Make bats executable available
if [ ! -L "$SCRIPT_DIR/bats" ]; then
    ln -sf "$BATS_DIR/bats-core/bin/bats" "$SCRIPT_DIR/bats"
fi

echo "✅ Bats testing framework setup complete!"
echo "🧪 Run tests with: ./tests/unit/bats tests/unit/*.bats"