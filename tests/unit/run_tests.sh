#!/bin/bash
# Unit test runner for chezmoi-sync

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_BIN="$SCRIPT_DIR/bats/bats-core/bin/bats"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_red() { echo -e "${RED}$1${NC}"; }
print_green() { echo -e "${GREEN}$1${NC}"; }
print_yellow() { echo -e "${YELLOW}$1${NC}"; }
print_blue() { echo -e "${BLUE}$1${NC}"; }

# Check if bats is installed
if [ ! -x "$BATS_BIN" ]; then
    print_red "❌ Bats not found. Running setup..."
    "$SCRIPT_DIR/setup_bats.sh"
fi

print_blue "🧪 Running chezmoi-sync unit tests..."

# Run all tests
if [ $# -eq 0 ]; then
    # Run all test files
    test_files=("$SCRIPT_DIR"/*.bats)
else
    # Run specific test files
    test_files=("$@")
fi

# Run tests with proper error handling
failed_tests=0
total_tests=${#test_files[@]}

for test_file in "${test_files[@]}"; do
    if [ -f "$test_file" ]; then
        print_blue "🔍 Running $(basename "$test_file")..."
        if "$BATS_BIN" "$test_file"; then
            print_green "✅ $(basename "$test_file") passed"
        else
            print_red "❌ $(basename "$test_file") failed"
            ((failed_tests++))
        fi
    else
        print_yellow "⚠️  Test file not found: $test_file"
        ((failed_tests++))
    fi
done

# Summary
echo
if [ $failed_tests -eq 0 ]; then
    print_green "🎉 All tests passed! ($total_tests/$total_tests)"
    exit 0
else
    print_red "💥 $failed_tests/$total_tests test files failed"
    exit 1
fi