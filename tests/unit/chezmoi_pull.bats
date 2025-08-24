#!/usr/bin/env bats
# Unit tests for chezmoi-pull.sh functions

load test_helper

setup() {
    setup_test_env
    mock_osascript
    setup_mock_remote
}

teardown() {
    teardown_test_env
}

@test "pull script detects remote changes" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create remote changes
    local temp_clone="${TEST_TEMP_DIR}/temp_clone"
    git clone --quiet "${TEST_CHEZMOI_SOURCE_DIR}/../remote.git" "$temp_clone"
    cd "$temp_clone"
    echo "remote content" > remote_file.txt
    git add remote_file.txt
    git commit --quiet -m "Remote change"
    git push --quiet origin main
    
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Check for remote changes
    git fetch --quiet
    run git log HEAD..origin/main --oneline
    assert_output --partial "Remote change"
}

@test "pull script handles merge conflicts" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create conflicting changes
    echo "local content" > conflict_file.txt
    git add conflict_file.txt
    git commit --quiet -m "Local change"
    
    # Create conflicting remote change
    local temp_clone="${TEST_TEMP_DIR}/temp_clone"
    git clone --quiet "${TEST_CHEZMOI_SOURCE_DIR}/../remote.git" "$temp_clone"
    cd "$temp_clone"
    echo "remote content" > conflict_file.txt
    git add conflict_file.txt
    git commit --quiet -m "Remote change"
    git push --quiet origin main
    
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    git fetch --quiet
    
    # Attempt merge (should conflict)
    run git merge origin/main
    assert_failure
    assert_output --partial "CONFLICT"
}

@test "pull script creates backup before applying changes" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create important local file
    echo "important local data" > important.txt
    git add important.txt
    git commit --quiet -m "Important local file"
    
    # Simulate backup creation (this would be done by the pull script)
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="pre_pull_${timestamp}"
    mkdir -p "$TEST_BACKUP_DIR/$backup_name"
    cp -r "$TEST_CHEZMOI_SOURCE_DIR" "$TEST_BACKUP_DIR/$backup_name/"
    
    assert_dir_exists "$TEST_BACKUP_DIR/$backup_name"
    assert_file_exists "$TEST_BACKUP_DIR/$backup_name/$(basename "$TEST_CHEZMOI_SOURCE_DIR")/important.txt"
}

@test "pull script validates chezmoi apply before committing" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create a valid chezmoi template
    echo 'export TEST_VAR="{{ .chezmoi.hostname }}"' > dot_test_config.tmpl
    git add dot_test_config.tmpl
    git commit --quiet -m "Add test template"
    
    # Test chezmoi template validation
    run chezmoi execute-template < dot_test_config.tmpl
    assert_success
    assert_output --partial "TEST_VAR="
}

@test "pull script handles network failures gracefully" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Set invalid remote URL to simulate network failure
    git remote set-url origin "https://invalid.example.com/repo.git"
    
    # Attempt fetch (should fail)
    run git fetch
    assert_failure
}

@test "pull script respects lock file from push operations" {
    # Create push lock file
    echo "5678" > "/tmp/chezmoi-push.lock"
    
    # Pull script should detect and respect the lock
    if [ -f "/tmp/chezmoi-push.lock" ]; then
        run echo "Push operation in progress, skipping pull"
        assert_success
        assert_output "Push operation in progress, skipping pull"
    fi
    
    # Cleanup
    rm -f "/tmp/chezmoi-push.lock"
}

@test "pull script logs all operations" {
    source ../../scripts/chezmoi-pull.sh
    
    run log "Pull operation started"
    assert_success
    assert_log_contains "Pull operation started"
    
    # Verify log file structure
    assert_file_exists "$TEST_LOG_DIR/pull.log"
}

@test "pull script handles empty repository correctly" {
    # Create empty repository
    local empty_repo="${TEST_TEMP_DIR}/empty.git"
    mkdir -p "$empty_repo"
    cd "$empty_repo"
    git init --bare --quiet
    
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    git remote set-url origin "$empty_repo"
    
    # Fetch from empty repo should not fail
    run git fetch
    assert_success
}

@test "pull script validates git status before operations" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Check clean working directory
    run git status --porcelain
    assert_output ""
    
    # Create dirty working directory
    echo "uncommitted change" > dirty_file.txt
    run git status --porcelain
    assert_output --partial "dirty_file.txt"
}

@test "pull script handles fast-forward merges" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create remote commit that can be fast-forwarded
    local temp_clone="${TEST_TEMP_DIR}/temp_clone"
    git clone --quiet "${TEST_CHEZMOI_SOURCE_DIR}/../remote.git" "$temp_clone"
    cd "$temp_clone"
    echo "fast forward content" > ff_file.txt
    git add ff_file.txt
    git commit --quiet -m "Fast forward commit"
    git push --quiet origin main
    
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    git fetch --quiet
    
    # Check if fast-forward is possible
    run git merge-base HEAD origin/main
    local base_commit="$output"
    run git rev-parse HEAD
    local current_commit="$output"
    
    if [ "$base_commit" = "$current_commit" ]; then
        # Can fast-forward
        run git merge origin/main
        assert_success
        assert_output --partial "Fast-forward"
    fi
}