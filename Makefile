# Makefile for chezmoi-sync project automation

# Ensure Make uses bash for command execution
SHELL := /bin/bash

# Default goal
.DEFAULT_GOAL := help

# Phony targets don't represent files
.PHONY: all test lint format install-hooks clean help validate ci-local

## --------------------------------------
## Variables
## --------------------------------------

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Directories
SCRIPTS_DIR := scripts
TEST_DIR := tests
WORKFLOWS_DIR := .github/workflows

## --------------------------------------
## Development Setup
## --------------------------------------

install-hooks: ## Install pre-commit hooks for local development
	@echo -e "$(BLUE)→ Installing pre-commit hooks...$(NC)"
	@command -v pre-commit >/dev/null 2>&1 || { \
		echo -e "$(YELLOW)pre-commit not found. Installing...$(NC)"; \
		pip install --user pre-commit || brew install pre-commit; \
	}
	@pre-commit install
	@echo -e "$(GREEN)✓ Pre-commit hooks installed$(NC)"

install-deps: ## Install all development dependencies
	@echo -e "$(BLUE)→ Installing development dependencies...$(NC)"
	@brew install shellcheck shfmt bats-core yamllint || true
	@pip install --user pre-commit || true
	@echo -e "$(GREEN)✓ Dependencies installed$(NC)"

## --------------------------------------
## Quality Assurance
## --------------------------------------

lint: ## Run all linters on the codebase
	@echo -e "$(BLUE)→ Running linters...$(NC)"
	@echo -e "$(BLUE)  Checking shell scripts...$(NC)"
	@shellcheck $(SCRIPTS_DIR)/*.sh install.sh uninstall.sh release.sh || true
	@echo -e "$(BLUE)  Checking YAML files...$(NC)"
	@yamllint -c .yamllint.yml $(WORKFLOWS_DIR)/*.yml .*.yml || true
	@echo -e "$(GREEN)✓ Linting complete$(NC)"

format: ## Format all code automatically
	@echo -e "$(BLUE)→ Formatting code...$(NC)"
	@echo -e "$(BLUE)  Formatting shell scripts...$(NC)"
	@shfmt -w $(SCRIPTS_DIR)/*.sh install.sh uninstall.sh release.sh
	@echo -e "$(GREEN)✓ Formatting complete$(NC)"

validate: lint test ## Run all validation checks (lint + test)
	@echo -e "$(GREEN)✓ All validation checks passed$(NC)"

## --------------------------------------
## Testing
## --------------------------------------

test: ## Run the full test suite
	@echo -e "$(BLUE)→ Running test suite...$(NC)"
	@if [ -f "$(TEST_DIR)/unit/run_tests.sh" ]; then \
		$(TEST_DIR)/unit/run_tests.sh; \
	else \
		echo -e "$(YELLOW)⚠ Unit tests not found$(NC)"; \
	fi
	@echo -e "$(GREEN)✓ Tests complete$(NC)"

test-unit: ## Run unit tests only
	@echo -e "$(BLUE)→ Running unit tests...$(NC)"
	@bats $(TEST_DIR)/unit/*.bats

test-integration: ## Run integration tests only
	@echo -e "$(BLUE)→ Running integration tests...$(NC)"
	@if [ -d "$(TEST_DIR)/integration" ]; then \
		bats $(TEST_DIR)/integration/*.bats; \
	else \
		echo -e "$(YELLOW)⚠ Integration tests not found$(NC)"; \
	fi

## --------------------------------------
## CI Simulation
## --------------------------------------

ci-local: ## Simulate CI pipeline locally
	@echo -e "$(BLUE)→ Simulating CI pipeline locally...$(NC)"
	@$(MAKE) format
	@$(MAKE) lint
	@$(MAKE) test
	@echo -e "$(GREEN)✓ CI simulation complete$(NC)"

## --------------------------------------
## Homebrew
## --------------------------------------

brew-audit: ## Audit the Homebrew formula
	@echo -e "$(BLUE)→ Auditing Homebrew formula...$(NC)"
	@brew audit --strict mishaal79/chezmoi-sync/chezmoi-sync || true

brew-test: ## Test Homebrew installation
	@echo -e "$(BLUE)→ Testing Homebrew installation...$(NC)"
	@brew test mishaal79/chezmoi-sync/chezmoi-sync || true

## --------------------------------------
## Cleanup
## --------------------------------------

clean: ## Clean up temporary files and test artifacts
	@echo -e "$(BLUE)→ Cleaning up...$(NC)"
	@rm -rf test_results_* || true
	@rm -f *.log || true
	@find . -name "*.orig" -delete || true
	@echo -e "$(GREEN)✓ Cleanup complete$(NC)"

## --------------------------------------
## Help
## --------------------------------------

help: ## Display this help message
	@echo "Chezmoi-Sync Development Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick start:"
	@echo "  make install-deps    # Install dependencies"
	@echo "  make install-hooks   # Set up pre-commit"
	@echo "  make ci-local        # Run all checks locally"