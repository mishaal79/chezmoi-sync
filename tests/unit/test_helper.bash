#!/bin/bash
# Test helper functions for bats tests

# Load bats libraries
load "bats/bats-support/load"
load "bats/bats-assert/load"
load "bats/bats-file/load"

# Test configuration
export TEST_TEMP_DIR="${BATS_TMPDIR}/chezmoi-sync-test"
export TEST_CHEZMOI_SOURCE_DIR="${TEST_TEMP_DIR}/.local/share/chezmoi"
export TEST_LOG_DIR="${TEST_TEMP_DIR}/logs"
export TEST_BACKUP_DIR="${TEST_TEMP_DIR}/backups"
export TEST_LOCK_FILE="${TEST_TEMP_DIR}/chezmoi-push.lock"

# Setup test environment
setup_test_env() {
    # Create isolated test directories
    mkdir -p "$TEST_TEMP_DIR"/{.local/share/chezmoi,logs,backups,scripts}
    mkdir -p "$TEST_CHEZMOI_SOURCE_DIR"
    mkdir -p "$TEST_LOG_DIR"
    mkdir -p "$TEST_BACKUP_DIR"
    
    # Initialize git repository for testing
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    git init --quiet --initial-branch=main
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create initial commit
    echo "# Test dotfiles" > README.md
    git add README.md
    git commit --quiet -m "Initial commit"
    
    # Set up environment variables for scripts
    export CHEZMOI_SOURCE_DIR="$TEST_CHEZMOI_SOURCE_DIR"
    export LOG_DIR="$TEST_LOG_DIR"
    export BACKUP_DIR="$TEST_BACKUP_DIR"
    export LOCK_FILE="$TEST_LOCK_FILE"
}

# Cleanup test environment
teardown_test_env() {
    rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
    unset CHEZMOI_SOURCE_DIR LOG_DIR BACKUP_DIR LOCK_FILE
}

# Mock osascript for notifications (since we're testing on CI)
mock_osascript() {
    export PATH="${TEST_TEMP_DIR}/scripts:$PATH"
    cat > "${TEST_TEMP_DIR}/scripts/osascript" << 'EOF'
#!/bin/bash
# Mock osascript for testing
echo "[MOCK NOTIFICATION] $*" >> "${TEST_LOG_DIR}/notifications.log"
EOF
    chmod +x "${TEST_TEMP_DIR}/scripts/osascript"
}

# Create a test file with content
create_test_file() {
    local filename="$1"
    local content="$2"
    echo "$content" > "$TEST_CHEZMOI_SOURCE_DIR/$filename"
}

# Simulate file changes for testing
simulate_file_change() {
    local filename="$1"
    local new_content="$2"
    create_test_file "$filename" "$new_content"
}

# Create mock remote repository
setup_mock_remote() {
    local remote_dir="${TEST_TEMP_DIR}/remote.git"
    mkdir -p "$remote_dir"
    cd "$remote_dir"
    git init --bare --quiet --initial-branch=main
    
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    git remote add origin "$remote_dir"
    git push --quiet -u origin main
}

# Create conflict scenario
create_conflict_scenario() {
    # Make local changes
    echo "local change" >> "$TEST_CHEZMOI_SOURCE_DIR/test_file.txt"
    
    # Make conflicting remote changes
    local temp_clone="${TEST_TEMP_DIR}/temp_clone"
    git clone --quiet "$TEST_CHEZMOI_SOURCE_DIR/.git" "$temp_clone"
    cd "$temp_clone"
    echo "remote change" >> test_file.txt
    git add test_file.txt
    git commit --quiet -m "Remote change"
    git push --quiet origin main
    
    cd "$TEST_CHEZMOI_SOURCE_DIR"
}

# Assert log contains message
assert_log_contains() {
    local message="$1"
    local log_file="${TEST_LOG_DIR}/push.log"
    assert_file_exists "$log_file"
    run grep -q "$message" "$log_file"
    assert_success
}

# Assert backup was created
assert_backup_created() {
    local backup_pattern="$1"
    run find "$TEST_BACKUP_DIR" -name "*${backup_pattern}*"
    assert_output --partial "$backup_pattern"
}

# Source script functions for testing (without executing main logic)
source_script_functions() {
    local script_path="$1"
    # Extract functions from script by sourcing in a way that doesn't execute main logic
    source <(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$script_path" -A 1000 | grep -B 1000 -E '^}$' | head -n -1)
}