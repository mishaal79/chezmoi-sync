#!/bin/bash
# Comprehensive test runner for all chezmoi-sync tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Test result tracking
test_results_file="/tmp/test_results_$$"
test_count=0
failed_count=0

# Record test result
record_test() {
    local test_name="$1"
    local result="$2"
    
    echo "$test_name:$result" >> "$test_results_file"
    ((test_count++))
    
    if [ "$result" != "PASS" ]; then
        ((failed_count++))
    fi
}

# Run unit tests
run_unit_tests() {
    print_blue "🧪 Running unit tests..."
    
    cd "$PROJECT_ROOT"
    if ./tests/unit/run_tests.sh; then
        record_test "Unit Tests" "PASS"
        print_green "✅ Unit tests passed"
    else
        record_test "Unit Tests" "FAIL"
        print_red "❌ Unit tests failed"
    fi
}

# Run integration tests
run_integration_tests() {
    print_blue "🔗 Running integration tests..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_yellow "⚠️  Docker not available, skipping Docker integration tests"
        record_test "Integration Tests (Docker)" "SKIP"
    else
        cd "$PROJECT_ROOT/tests/docker"
        if docker-compose up --build -d && \
           docker-compose exec -T alpine-base bats /home/testuser/test-integration/network_failure_tests.bats && \
           docker-compose exec -T alpine-base bats /home/testuser/test-integration/edge_case_tests.bats && \
           docker-compose exec -T alpine-base bats /home/testuser/test-integration/launchagent_tests.bats; then
            record_test "Integration Tests (Docker)" "PASS"
            print_green "✅ Integration tests passed"
        else
            record_test "Integration Tests (Docker)" "FAIL"
            print_red "❌ Integration tests failed"
        fi
        docker-compose down --remove-orphans --volumes 2>/dev/null || true
    fi
    
    # Run local integration tests
    cd "$PROJECT_ROOT"
    if command -v bats &> /dev/null; then
        if bats tests/integration/*.bats; then
            record_test "Integration Tests (Local)" "PASS"
            print_green "✅ Local integration tests passed"
        else
            record_test "Integration Tests (Local)" "FAIL"
            print_red "❌ Local integration tests failed"
        fi
    else
        print_yellow "⚠️  Bats not available, skipping local integration tests"
        record_test "Integration Tests (Local)" "SKIP"
    fi
}

# Run performance tests
run_performance_tests() {
    print_blue "📊 Running performance tests..."
    
    if ! command -v docker &> /dev/null; then
        print_yellow "⚠️  Docker not available, skipping performance tests"
        record_test "Performance Tests" "SKIP"
        return
    fi
    
    cd "$PROJECT_ROOT/tests/docker"
    if docker-compose up performance-tester -d && \
       docker-compose exec -T performance-tester bats /home/perfuser/test-integration/performance_tests.bats; then
        record_test "Performance Tests" "PASS"
        print_green "✅ Performance tests passed"
    else
        record_test "Performance Tests" "FAIL"
        print_red "❌ Performance tests failed"
    fi
    docker-compose down --remove-orphans --volumes 2>/dev/null || true
}

# Run security tests
run_security_tests() {
    print_blue "🔒 Running security tests..."
    
    local security_passed=true
    
    # Shellcheck
    if command -v shellcheck &> /dev/null; then
        print_blue "Running shellcheck security analysis..."
        if shellcheck -S error scripts/*.sh install.sh uninstall.sh release.sh; then
            print_green "✅ Shellcheck passed"
        else
            print_red "❌ Shellcheck found issues"
            security_passed=false
        fi
    else
        print_yellow "⚠️  Shellcheck not available"
    fi
    
    # Custom security checks
    print_blue "Running custom security checks..."
    
    # Check for hardcoded credentials
    if grep -r -E "(password|passwd|secret|key|token|api[_-]?key)" --include="*.sh" . | grep -v "README\|CHANGELOG\|\.git\|test\|mock"; then
        print_red "❌ Potential credentials found"
        security_passed=false
    else
        print_green "✅ No hardcoded credentials found"
    fi
    
    # Check for unsafe commands
    if grep -r "rm -rf /" --include="*.sh" .; then
        print_red "❌ Unsafe rm command found"
        security_passed=false
    else
        print_green "✅ No unsafe commands found"
    fi
    
    # GitLeaks (if available)
    if command -v gitleaks &> /dev/null; then
        print_blue "Running GitLeaks secret scan..."
        if gitleaks detect --source . --verbose; then
            print_green "✅ GitLeaks scan passed"
        else
            print_red "❌ GitLeaks found secrets"
            security_passed=false
        fi
    else
        print_yellow "⚠️  GitLeaks not available"
    fi
    
    if [ "$security_passed" = true ]; then
        record_test "Security Tests" "PASS"
        print_green "✅ Security tests passed"
    else
        record_test "Security Tests" "FAIL"
        print_red "❌ Security tests failed"
    fi
}

# Run syntax validation
run_syntax_validation() {
    print_blue "📝 Running syntax validation..."
    
    local syntax_passed=true
    
    # Shell script syntax
    for script in scripts/*.sh install.sh uninstall.sh release.sh; do
        if [ -f "$script" ]; then
            if bash -n "$script"; then
                print_green "✅ $script syntax valid"
            else
                print_red "❌ $script syntax invalid"
                syntax_passed=false
            fi
        fi
    done
    
    # Plist syntax
    for plist in plists/*.plist; do
        if [ -f "$plist" ]; then
            if command -v plutil &> /dev/null; then
                if plutil -lint "$plist"; then
                    print_green "✅ $plist syntax valid"
                else
                    print_red "❌ $plist syntax invalid"
                    syntax_passed=false
                fi
            else
                print_yellow "⚠️  plutil not available, skipping $plist"
            fi
        fi
    done
    
    if [ "$syntax_passed" = true ]; then
        record_test "Syntax Validation" "PASS"
        print_green "✅ Syntax validation passed"
    else
        record_test "Syntax Validation" "FAIL"
        print_red "❌ Syntax validation failed"
    fi
}

# Generate test report
generate_report() {
    local report_file="$PROJECT_ROOT/test_report.txt"
    
    print_blue "📋 Generating test report..."
    
    cat > "$report_file" << EOF
# Chezmoi-Sync Test Report
Generated: $(date)
Total Tests: $test_count
Failed Tests: $failed_count
Success Rate: $(( (test_count - failed_count) * 100 / test_count ))%

## Test Results
EOF
    
    if [ -f "$test_results_file" ]; then
        while IFS=: read -r test_name result; do
            local status_icon
            case "$result" in
                "PASS") status_icon="✅" ;;
                "FAIL") status_icon="❌" ;;
                "SKIP") status_icon="⚠️" ;;
                *) status_icon="❓" ;;
            esac
            echo "$status_icon $test_name: $result" >> "$report_file"
        done < "$test_results_file"
    fi
    
    if [ $failed_count -eq 0 ]; then
        echo "" >> "$report_file"
        echo "🎉 All tests passed!" >> "$report_file"
    else
        echo "" >> "$report_file"
        echo "💥 $failed_count test(s) failed. Review and fix issues." >> "$report_file"
    fi
    
    print_blue "📄 Test report saved to: $report_file"
    cat "$report_file"
}

# Show help
show_help() {
    cat << EOF
Comprehensive Test Runner for Chezmoi-Sync

Usage: $0 [options] [test-types]

Options:
  -h, --help          Show this help message
  -q, --quick         Run only fast tests (unit + syntax)
  -f, --full          Run all tests including performance
  --no-docker         Skip Docker-based tests
  --report-only       Generate report from existing results

Test Types:
  unit                Unit tests
  integration         Integration tests
  performance         Performance benchmarks
  security            Security scans
  syntax              Syntax validation
  all                 All tests (default)

Examples:
  $0                  # Run all tests
  $0 --quick          # Run only fast tests
  $0 unit security    # Run only unit and security tests
  $0 --no-docker      # Skip Docker tests
EOF
}

# Parse command line arguments
parse_args() {
    local test_types=()
    local quick_mode=false
    local full_mode=false
    local no_docker=false
    local report_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -q|--quick)
                quick_mode=true
                test_types=("unit" "syntax")
                shift
                ;;
            -f|--full)
                full_mode=true
                test_types=("unit" "integration" "performance" "security" "syntax")
                shift
                ;;
            --no-docker)
                no_docker=true
                export SKIP_DOCKER=true
                shift
                ;;
            --report-only)
                report_only=true
                shift
                ;;
            unit|integration|performance|security|syntax)
                test_types+=("$1")
                shift
                ;;
            all)
                test_types=("unit" "integration" "security" "syntax")
                shift
                ;;
            *)
                print_red "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default to all tests if none specified
    if [ ${#test_types[@]} -eq 0 ] && [ "$report_only" = false ]; then
        test_types=("unit" "integration" "security" "syntax")
    fi
    
    # Export configuration
    export TEST_TYPES="${test_types[*]}"
    export QUICK_MODE="$quick_mode"
    export FULL_MODE="$full_mode"
    export NO_DOCKER="$no_docker"
    export REPORT_ONLY="$report_only"
}

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    print_blue "🚀 Starting Chezmoi-Sync comprehensive test suite..."
    print_blue "📁 Project root: $PROJECT_ROOT"
    
    if [ "$REPORT_ONLY" = true ]; then
        generate_report
        exit 0
    fi
    
    # Run selected tests
    for test_type in $TEST_TYPES; do
        case "$test_type" in
            "unit")
                run_unit_tests
                ;;
            "integration")
                run_integration_tests
                ;;
            "performance")
                if [ "$QUICK_MODE" != true ]; then
                    run_performance_tests
                fi
                ;;
            "security")
                run_security_tests
                ;;
            "syntax")
                run_syntax_validation
                ;;
            *)
                print_yellow "⚠️  Unknown test type: $test_type"
                ;;
        esac
    done
    
    # Generate final report
    generate_report
    
    # Cleanup
    rm -f "$test_results_file"
    
    # Exit with appropriate code
    if [ $failed_count -eq 0 ]; then
        print_green "🎉 All tests completed successfully!"
        exit 0
    else
        print_red "💥 $failed_count test(s) failed"
        exit 1
    fi
}

# Parse arguments and run
parse_args "$@"
main