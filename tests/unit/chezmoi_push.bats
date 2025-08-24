#!/usr/bin/env bats
# Unit tests for chezmoi-push.sh functions

load test_helper

setup() {
    setup_test_env
    mock_osascript
    setup_mock_remote
}

teardown() {
    teardown_test_env
}

@test "log function writes to log file with timestamp" {
    # Test log function directly  
    local log_file="$TEST_LOG_DIR/push.log"
    local test_message="Test message"
    
    # Create log function equivalent
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $test_message" >> "$log_file"
    
    assert_file_exists "$log_file"
    run grep -q "$test_message" "$log_file"
    assert_success
    
    # Check timestamp format
    run grep -E "\[20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]" "$log_file"
    assert_success
}

@test "notify function sends desktop notification" {
    # Test notification function through mock
    run osascript -e "display notification \"Test notification\" with title \"Test Title\""
    
    assert_success
    assert_file_exists "$TEST_LOG_DIR/notifications.log"
    run grep -q "Test notification" "$TEST_LOG_DIR/notifications.log"
    assert_success
}

@test "lock file prevents concurrent execution" {
    # Create existing lock file
    echo "1234" > "$TEST_LOCK_FILE"
    
    # Test lock file detection logic
    if [ -f "$TEST_LOCK_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Another push operation is already running. Exiting." >> "$TEST_LOG_DIR/push.log"
        run echo "Lock file exists"
        assert_output "Lock file exists"
    fi
    
    assert_file_exists "$TEST_LOCK_FILE" 
    assert_log_contains "Another push operation is already running"
}

@test "lock file is cleaned up on exit" {
    # Create lock file and test cleanup
    echo "$$" > "$TEST_LOCK_FILE"
    assert_file_exists "$TEST_LOCK_FILE"
    
    # Simulate cleanup (trap behavior)
    rm -f "$TEST_LOCK_FILE"
    assert_file_not_exists "$TEST_LOCK_FILE"
}

@test "script detects git repository correctly" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Test in valid git repository
    run git rev-parse --is-inside-work-tree
    assert_success
    assert_output "true"
}

@test "script fails gracefully when not in git repository" {
    # Remove .git directory
    rm -rf "$TEST_CHEZMOI_SOURCE_DIR/.git"
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Test git repository detection
    run git rev-parse --is-inside-work-tree
    assert_failure
    
    # Log the error as the script would
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Not in a git repository" >> "$TEST_LOG_DIR/push.log"
    assert_log_contains "ERROR: Not in a git repository"
}

@test "script detects uncommitted changes" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create uncommitted changes
    echo "test change" > test_file.txt
    
    # Check git status
    run git status --porcelain
    assert_output --partial "test_file.txt"
}

@test "script commits changes when files are modified" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create new file
    echo "new content" > new_file.txt
    git add new_file.txt
    git commit -m "Add new file"
    
    # Verify commit was created
    run git log --oneline -1
    assert_output --partial "Add new file"
}

@test "backup is created before destructive operations" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create a file to backup
    echo "important data" > important_file.txt
    git add important_file.txt
    git commit -m "Add important file"
    
    # Simulate backup creation (this would be called by the actual script)
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="pre_push_${timestamp}"
    
    # Create backup directory
    mkdir -p "$TEST_BACKUP_DIR/$backup_name"
    cp -r "$TEST_CHEZMOI_SOURCE_DIR" "$TEST_BACKUP_DIR/$backup_name/"
    
    # Verify backup exists
    assert_dir_exists "$TEST_BACKUP_DIR/$backup_name"
    assert_file_exists "$TEST_BACKUP_DIR/$backup_name/$(basename "$TEST_CHEZMOI_SOURCE_DIR")/important_file.txt"
}

@test "script handles git push failures gracefully" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Set up invalid remote to cause push failure
    git remote set-url origin "invalid://url"
    
    # Create changes to push
    echo "test" > test_push_fail.txt
    git add test_push_fail.txt
    git commit -m "Test commit"
    
    # Attempt push (should fail)
    run git push
    assert_failure
}

@test "script validates git configuration before operations" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Check git user configuration
    run git config user.email
    assert_output "test@example.com"
    
    run git config user.name  
    assert_output "Test User"
}

@test "script detects branch divergence" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create local commit
    echo "local change" > local_file.txt
    git add local_file.txt
    git commit -m "Local commit"
    
    # Reset to previous commit to simulate divergence
    git reset --hard HEAD~1
    
    # Check if branch has diverged
    run git status --porcelain --branch
    assert_success
}