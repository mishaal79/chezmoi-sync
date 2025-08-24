# Chezmoi-Sync Testing Infrastructure

This directory contains the comprehensive testing infrastructure for chezmoi-sync, providing multiple layers of validation to ensure reliability, security, and performance.

## 🏗️ Testing Architecture

```
tests/
├── unit/                    # Unit tests for individual functions
├── integration/             # Integration tests for end-to-end scenarios
├── docker/                  # Docker-based testing environments
├── fixtures/                # Test data and mock scenarios
└── scripts/                 # Test execution and utility scripts
```

## 🧪 Test Categories

### Unit Tests (`tests/unit/`)
Fast, isolated tests for individual script functions using the **bats** testing framework.

**Coverage:**
- ✅ Logging functions
- ✅ Notification systems
- ✅ Lock file management
- ✅ Git repository operations
- ✅ Backup and restore functionality
- ✅ Error handling paths

**Run:** `./tests/unit/run_tests.sh`

### Integration Tests (`tests/integration/`)
Comprehensive end-to-end testing scenarios that validate real-world usage patterns.

**Test Suites:**
- **Network Failure Tests** (`network_failure_tests.bats`)
  - DNS resolution failures
  - Connection timeouts
  - Certificate verification errors
  - Proxy configuration issues
  - Large file sync timeouts
  - Authentication failures

- **Edge Case Tests** (`edge_case_tests.bats`)
  - Disk space exhaustion
  - Corrupted git repositories
  - Extremely large files
  - Unicode and special characters
  - Permission denied scenarios
  - Concurrent file modifications

- **LaunchAgent Tests** (`launchagent_tests.bats`)
  - Plist file validation
  - Service lifecycle management
  - Error handling and recovery
  - System sleep/wake cycles
  - Log rotation and monitoring

- **Performance Tests** (`performance_tests.bats`)
  - Git operations scaling
  - Template processing speed
  - Memory usage monitoring
  - Deep directory structures
  - Network latency impact

### Docker Testing (`tests/docker/`)
Isolated, reproducible testing environments using containerization.

**Containers:**
- **alpine-base**: Minimal Alpine Linux environment for basic testing
- **macos-sim**: macOS simulation container with fswatch and LaunchAgent mocking
- **performance-tester**: Performance benchmarking with monitoring tools
- **load-tester**: High-load testing with resource constraints

**Run:** `./tests/scripts/test-runner.sh`

## 🚀 Quick Start

### Prerequisites
```bash
# macOS
brew install bats-core docker shellcheck

# Verify installation
docker --version
bats --version
shellcheck --version
```

### Run All Tests
```bash
# Comprehensive test suite
./tests/scripts/comprehensive_test_runner.sh

# Quick validation (unit + syntax only)
./tests/scripts/comprehensive_test_runner.sh --quick

# Specific test categories
./tests/scripts/comprehensive_test_runner.sh unit security
```

### Run Individual Test Suites
```bash
# Unit tests only
./tests/unit/run_tests.sh

# Integration tests only
./tests/scripts/test-runner.sh integration

# Performance benchmarks
./tests/scripts/test-runner.sh performance
```

## 📊 Performance Benchmarking

### Test Data Generation
The performance testing infrastructure includes configurable test data generation:

```bash
# Generate test scenarios
./tests/docker/performance_test_data.sh small    # Light testing
./tests/docker/performance_test_data.sh medium   # Standard testing  
./tests/docker/performance_test_data.sh large    # Heavy testing
./tests/docker/performance_test_data.sh extreme  # Stress testing
```

### Metrics Collected
- **Operation Timing**: Git operations, template processing, file I/O
- **Memory Usage**: RSS memory consumption during operations
- **Scalability**: Performance vs. file count/size relationships
- **Network Impact**: Latency effects on sync operations

## 🔒 Security Testing

### Automated Security Scans
- **GitLeaks**: Secret detection in git history
- **Shellcheck**: Shell script security analysis
- **Custom Checks**: Hardcoded credentials, unsafe commands
- **Dependency Scanning**: Vulnerability detection
- **Infrastructure Scanning**: Docker and CI/CD security

### Security Configuration
Security scanning is configured via `.gitleaks.toml` and runs automatically in CI/CD pipelines.

## 🔄 CI/CD Integration

### GitHub Actions Workflows
- **Enhanced CI** (`.github/workflows/ci.yml`)
  - Unit tests on macOS
  - Script validation and linting
  - Syntax verification

- **Security Scanning** (`.github/workflows/security.yml`)
  - Multi-layer security analysis
  - Dependency vulnerability scanning
  - License compliance checking

- **Integration Tests** (`.github/workflows/test-integration.yml`)
  - Docker-based cross-environment testing
  - Matrix testing across machine types
  - Performance benchmarking

## 📈 Test Results and Reporting

### Automated Reporting
Tests generate comprehensive reports including:
- **Execution Summary**: Pass/fail counts and timing
- **Performance Metrics**: Benchmark results and trends
- **Security Findings**: Vulnerability and compliance status
- **Coverage Analysis**: Test coverage statistics

### Report Locations
- Unit test results: `/tmp/chezmoi-sync-test/logs/`
- Performance data: `/tmp/chezmoi-perf-results/`
- Security reports: Generated in CI artifacts
- Comprehensive report: `test_report.txt`

## 🛠️ Development Workflow

### Adding New Tests
1. **Unit Tests**: Add to `tests/unit/*.bats` using the test helper
2. **Integration Tests**: Add to `tests/integration/*.bats` for end-to-end scenarios
3. **Performance Tests**: Extend `performance_tests.bats` with benchmarks
4. **Security Tests**: Update `.gitleaks.toml` and security workflows

### Test Helper Functions
The `tests/unit/test_helper.bash` provides utilities for:
- **Environment Setup**: Isolated test directories and git repos
- **Mock Services**: osascript, launchctl, fswatch simulation
- **Assertion Helpers**: File existence, log content, backup validation
- **Cleanup**: Automatic test environment teardown

### Best Practices
- **Isolation**: Each test runs in a clean environment
- **Idempotency**: Tests can be run multiple times safely
- **Fast Execution**: Unit tests complete in seconds
- **Clear Naming**: Descriptive test names and error messages
- **Resource Cleanup**: Automatic cleanup prevents resource leaks

## 🎯 Quality Metrics

### Target Benchmarks
- **Test Coverage**: 80%+ function coverage
- **Performance**: <2s for 100 file operations
- **Security**: Zero critical vulnerabilities
- **Reliability**: 99%+ test success rate

### Continuous Monitoring
- Performance regression detection
- Security vulnerability alerting
- Test execution monitoring
- Quality trend analysis

## 🤝 Contributing

When contributing to chezmoi-sync:

1. **Write Tests**: All new features require corresponding tests
2. **Update Documentation**: Keep test documentation current
3. **Run Validation**: Execute full test suite before submitting PRs
4. **Security Review**: Ensure new code passes security scans

### Test Commands for Contributors
```bash
# Before committing
./tests/scripts/comprehensive_test_runner.sh --quick

# Before submitting PR
./tests/scripts/comprehensive_test_runner.sh --full

# Performance impact assessment
./tests/scripts/test-runner.sh performance
```

This testing infrastructure ensures chezmoi-sync maintains the highest standards of reliability, security, and performance across all supported environments.