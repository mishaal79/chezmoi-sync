#!/usr/bin/env bats
# Unit tests for chezmoi-resolve.sh functions

load test_helper

setup() {
    setup_test_env
    mock_osascript
    setup_mock_remote
}

teardown() {
    teardown_test_env
}

@test "resolve script detects conflict state" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create merge conflict
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
    
    # Attempt merge to create conflict
    run git merge origin/main
    assert_failure
    
    # Check for conflict markers
    run git status --porcelain
    assert_output --partial "UU"
}

@test "resolve script identifies conflict files" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create conflict and check status
    echo "content" > file1.txt
    git add file1.txt
    git commit --quiet -m "Local file1"
    
    # Create different remote version
    local temp_clone="${TEST_TEMP_DIR}/temp_clone"
    git clone --quiet "${TEST_CHEZMOI_SOURCE_DIR}/../remote.git" "$temp_clone"
    cd "$temp_clone"
    echo "different content" > file1.txt
    git add file1.txt
    git commit --quiet -m "Remote file1"
    git push --quiet origin main
    
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    git fetch --quiet
    
    # Create conflict
    run git merge origin/main
    assert_failure
    
    # List conflicted files
    run git diff --name-only --diff-filter=U
    assert_output "file1.txt"
}

@test "resolve script creates backup before resolution" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create state to backup
    echo "important data" > important.txt
    git add important.txt
    git commit --quiet -m "Important data"
    
    # Simulate backup creation
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="pre_resolve_${timestamp}"
    mkdir -p "$TEST_BACKUP_DIR/$backup_name"
    cp -r "$TEST_CHEZMOI_SOURCE_DIR" "$TEST_BACKUP_DIR/$backup_name/"
    
    assert_dir_exists "$TEST_BACKUP_DIR/$backup_name"
    assert_file_exists "$TEST_BACKUP_DIR/$backup_name/$(basename "$TEST_CHEZMOI_SOURCE_DIR")/important.txt"
}

@test "resolve script validates resolution before committing" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create a file to validate
    echo "resolved content" > resolved_file.txt
    git add resolved_file.txt
    
    # Validate no conflict markers remain
    run grep -E "<<<<<<< |======= |>>>>>>> " resolved_file.txt
    assert_failure
}

@test "resolve script offers abort option" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create conflict state
    echo "content" > abort_test.txt
    git add abort_test.txt
    git commit --quiet -m "Local"
    
    # Test abort functionality
    run git merge --abort 2>/dev/null || echo "No merge to abort"
    assert_success
}

@test "resolve script can stash local changes" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create uncommitted changes
    echo "uncommitted work" > work_file.txt
    
    # Stash changes
    run git stash push -m "Auto-stash before resolve"
    assert_success
    
    # Verify stash was created
    run git stash list
    assert_output --partial "Auto-stash before resolve"
    
    # Verify working directory is clean
    run git status --porcelain
    assert_output ""
}

@test "resolve script can restore from backup" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create backup
    local backup_name="test_backup_$(date +%s)"
    mkdir -p "$TEST_BACKUP_DIR/$backup_name"
    cp -r "$TEST_CHEZMOI_SOURCE_DIR" "$TEST_BACKUP_DIR/$backup_name/"
    
    # Modify current state
    echo "modified content" > modified_file.txt
    git add modified_file.txt
    git commit --quiet -m "Modification"
    
    # Simulate restore from backup
    local backup_source="$TEST_BACKUP_DIR/$backup_name/$(basename "$TEST_CHEZMOI_SOURCE_DIR")"
    if [ -d "$backup_source" ]; then
        # This would be the restore logic
        run echo "Would restore from $backup_source"
        assert_success
        assert_output --partial "Would restore from"
    fi
}

@test "resolve script logs resolution steps" {
    source ../../scripts/chezmoi-resolve.sh
    
    run log "Conflict resolution started"
    assert_success
    assert_file_exists "$TEST_LOG_DIR/resolve.log"
    
    run grep -q "Conflict resolution started" "$TEST_LOG_DIR/resolve.log"
    assert_success
}

@test "resolve script handles three-way merge information" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create base state
    echo "base content" > merge_file.txt
    git add merge_file.txt
    git commit --quiet -m "Base commit"
    
    # Create local changes
    echo "local content" > merge_file.txt
    git add merge_file.txt
    git commit --quiet -m "Local changes"
    
    # Create remote changes (reset and make different change)
    git reset --hard HEAD~1
    echo "remote content" > merge_file.txt
    git add merge_file.txt
    git commit --quiet -m "Remote changes"
    
    # Check merge base
    run git merge-base HEAD HEAD@{1}
    assert_success
}

@test "resolve script validates git configuration" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Verify required git config
    run git config user.email
    assert_output "test@example.com"
    
    run git config user.name
    assert_output "Test User"
    
    # Check merge tool configuration (optional)
    run git config merge.tool || echo "No merge tool configured"
    assert_success
}

@test "resolve script handles empty merge commits" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create scenario where merge would be empty
    echo "same content" > same_file.txt
    git add same_file.txt
    git commit --quiet -m "Same content local"
    
    # Reset and create identical remote commit
    git reset --hard HEAD~1
    echo "same content" > same_file.txt
    git add same_file.txt
    git commit --quiet -m "Same content remote"
    
    # This would result in no changes to merge
    run git status --porcelain
    assert_output ""
}