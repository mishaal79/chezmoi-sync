#!/usr/bin/env bash

# Unified test script for chezmoi-sync
# Runs all validation and tests in the same order as CI

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_blue() { echo -e "${BLUE}$1${NC}"; }
print_green() { echo -e "${GREEN}$1${NC}"; }
print_yellow() { echo -e "${YELLOW}$1${NC}"; }
print_red() { echo -e "${RED}$1${NC}"; }

# Track overall status
FAILED=0

# Header
print_blue "═══════════════════════════════════════════════════════"
print_blue "         Chezmoi-Sync Test Suite"
print_blue "═══════════════════════════════════════════════════════"
echo

# Check for required tools
check_dependencies() {
	print_blue "→ Checking dependencies..."
	local missing=()

	command -v shellcheck >/dev/null 2>&1 || missing+=("shellcheck")
	command -v shfmt >/dev/null 2>&1 || missing+=("shfmt")
	command -v yamllint >/dev/null 2>&1 || missing+=("yamllint")
	command -v bats >/dev/null 2>&1 || missing+=("bats-core")

	if [ ${#missing[@]} -gt 0 ]; then
		print_yellow "⚠ Missing tools: ${missing[*]}"
		print_yellow "  Install with: brew install ${missing[*]}"
		echo
	else
		print_green "✓ All dependencies installed"
	fi
	echo
}

# Run shellcheck on all shell scripts
run_shellcheck() {
	print_blue "→ Running ShellCheck..."

	local scripts=(
		scripts/*.sh
		install.sh
		uninstall.sh
		release.sh
		test.sh
	)

	local failed=0
	for script in "${scripts[@]}"; do
		if [ -f "$script" ]; then
			if shellcheck "$script"; then
				print_green "  ✓ $script"
			else
				print_red "  ✗ $script"
				failed=1
			fi
		fi
	done

	if [ $failed -eq 0 ]; then
		print_green "✓ ShellCheck passed"
	else
		print_red "✗ ShellCheck failed"
		FAILED=1
	fi
	echo
}

# Check shell script formatting
check_formatting() {
	print_blue "→ Checking shell script formatting..."

	if shfmt -d scripts/*.sh install.sh uninstall.sh release.sh test.sh; then
		print_green "✓ Formatting check passed"
	else
		print_red "✗ Formatting issues found"
		print_yellow "  Run 'make format' or 'shfmt -w .' to fix"
		FAILED=1
	fi
	echo
}

# Run YAML linting
run_yamllint() {
	print_blue "→ Running YAML linting..."

	if [ -f ".yamllint.yml" ]; then
		if yamllint -c .yamllint.yml .github/workflows/*.yml .*.yml 2>/dev/null; then
			print_green "✓ YAML linting passed"
		else
			print_yellow "⚠ YAML linting warnings (non-fatal)"
		fi
	else
		print_yellow "⚠ .yamllint.yml not found, skipping YAML linting"
	fi
	echo
}

# Run unit tests
run_unit_tests() {
	print_blue "→ Running unit tests..."

	if [ -d "tests/unit" ] && [ -f "tests/unit/run_tests.sh" ]; then
		if ./tests/unit/run_tests.sh; then
			print_green "✓ Unit tests passed"
		else
			print_red "✗ Unit tests failed"
			FAILED=1
		fi
	elif command -v bats >/dev/null 2>&1 && [ -d "tests/unit" ]; then
		if bats tests/unit/*.bats; then
			print_green "✓ Unit tests passed"
		else
			print_red "✗ Unit tests failed"
			FAILED=1
		fi
	else
		print_yellow "⚠ Unit tests not found or bats not installed"
	fi
	echo
}

# Validate GitHub Actions workflows
validate_workflows() {
	print_blue "→ Validating GitHub Actions workflows..."

	# Check if actionlint is available
	if command -v actionlint >/dev/null 2>&1; then
		if actionlint .github/workflows/*.yml; then
			print_green "✓ GitHub Actions validation passed"
		else
			print_red "✗ GitHub Actions validation failed"
			FAILED=1
		fi
	else
		print_yellow "⚠ actionlint not installed, skipping workflow validation"
		print_yellow "  Install with: brew install actionlint"
	fi
	echo
}

# Main execution
main() {
	check_dependencies
	run_shellcheck
	check_formatting
	run_yamllint
	validate_workflows
	run_unit_tests

	# Summary
	print_blue "═══════════════════════════════════════════════════════"
	if [ $FAILED -eq 0 ]; then
		print_green "✓ All tests passed!"
		print_blue "═══════════════════════════════════════════════════════"
		exit 0
	else
		print_red "✗ Some tests failed"
		print_yellow "  Run 'make format' to fix formatting issues"
		print_yellow "  Run 'make lint' to see detailed linting errors"
		print_blue "═══════════════════════════════════════════════════════"
		exit 1
	fi
}

# Run main function
main "$@"