#!/bin/bash
# Isolated test runner for chezmoi-sync integration testing

set -euo pipefail

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

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_DIR="$TEST_DIR/docker"

# Cleanup function
cleanup() {
    print_yellow "🧹 Cleaning up test containers..."
    cd "$DOCKER_DIR"
    docker-compose down --remove-orphans --volumes 2>/dev/null || true
    docker system prune -f --volumes 2>/dev/null || true
    rm -rf /tmp/chezmoi-test-* 2>/dev/null || true
}

# Trap cleanup on exit
trap cleanup EXIT

# Main test function
run_tests() {
    local test_type="${1:-all}"
    
    print_blue "🐳 Starting isolated chezmoi-sync testing..."
    print_blue "📦 Using Alpine Linux containers (minimal and fast)"
    
    cd "$DOCKER_DIR"
    
    # Build containers
    print_blue "🔨 Building test containers..."
    docker-compose build --no-cache
    
    # Start containers
    print_blue "🚀 Starting test environments..."
    docker-compose up -d
    
    # Wait for containers to be ready
    sleep 2
    
    case "$test_type" in
        "alpine"|"base")
            run_alpine_tests
            ;;
        "macos")
            run_macos_tests
            ;;
        "integration")
            run_integration_tests
            ;;
        "all")
            run_alpine_tests
            run_macos_tests
            run_integration_tests
            ;;
        *)
            print_red "❌ Unknown test type: $test_type"
            print_yellow "Available types: alpine, macos, integration, all"
            exit 1
            ;;
    esac
}

run_alpine_tests() {
    print_blue "🔬 Running Alpine base tests..."
    
    # Test basic chezmoi installation
    docker-compose exec -T alpine-base bash -c "
        set -euo pipefail
        echo '🧪 Testing chezmoi installation...'
        chezmoi --version
        echo '✅ chezmoi is working'
    "
    
    # Test git configuration
    docker-compose exec -T alpine-base bash -c "
        set -euo pipefail
        echo '🧪 Testing git configuration...'
        git config --global --list | grep -E '(user\.name|user\.email)'
        echo '✅ git is configured'
    "
    
    print_green "✅ Alpine base tests passed"
}

run_macos_tests() {
    print_blue "🍎 Running macOS simulation tests..."
    
    # Test macOS hostname simulation
    docker-compose exec -T macos-sim bash -c "
        set -euo pipefail
        echo '🧪 Testing macOS hostname simulation...'
        hostname
        echo '✅ hostname simulation working'
    "
    
    # Test fswatch simulation
    docker-compose exec -T macos-sim bash -c "
        set -euo pipefail
        echo '🧪 Testing fswatch simulation...'
        command -v fswatch
        echo '✅ fswatch simulation available'
    "
    
    print_green "✅ macOS simulation tests passed"
}

run_integration_tests() {
    print_blue "🔗 Running integration tests..."
    
    # Test chezmoi-sync installation simulation
    docker-compose exec -T alpine-base bash -c "
        set -euo pipefail
        echo '🧪 Testing chezmoi-sync installation simulation...'
        
        # Create mock chezmoi source directory
        mkdir -p ~/.local/share/chezmoi
        cd ~/.local/share/chezmoi
        git init
        echo 'export TEST_VAR=alpine' > dot_zshrc.tmpl
        git add .
        git commit -m 'Initial commit'
        
        echo '✅ Mock chezmoi repository created'
    "
    
    print_green "✅ Integration tests passed"
}

# Help function
show_help() {
    echo "Usage: $0 [test_type]"
    echo ""
    echo "Test types:"
    echo "  alpine      - Run Alpine base tests only"
    echo "  macos       - Run macOS simulation tests only"
    echo "  integration - Run integration tests only"
    echo "  all         - Run all tests (default)"
    echo ""
    echo "Examples:"
    echo "  $0              # Run all tests"
    echo "  $0 alpine       # Run only Alpine tests"
    echo "  $0 integration  # Run only integration tests"
}

# Main execution
main() {
    case "${1:-all}" in
        "-h"|"--help"|"help")
            show_help
            exit 0
            ;;
        *)
            run_tests "$@"
            ;;
    esac
}

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_red "❌ Docker is not installed or not in PATH"
    print_yellow "Please install Docker to run integration tests"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_red "❌ docker-compose is not installed or not in PATH"
    print_yellow "Please install docker-compose to run integration tests"
    exit 1
fi

main "$@"