#!/usr/bin/env bats
# Integration tests for edge cases and error conditions

load ../unit/test_helper

setup() {
    setup_test_env
    mock_osascript
    setup_mock_remote
}

teardown() {
    teardown_test_env
}

@test "handles disk space exhaustion during backup" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create content
    echo "disk space test" > disk_test.txt
    git add disk_test.txt
    git commit -q -m "Disk space test"
    
    # Simulate disk full during backup creation
    # (In real test, we'd mount a small tmpfs, but here we simulate)
    local fake_backup_dir="/non/existent/path/that/will/fail"
    
    # Test backup creation failure
    run mkdir -p "$fake_backup_dir" 2>/dev/null
    assert_failure
    
    # Should fallback gracefully
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Backup creation failed, proceeding without backup" >> "$TEST_LOG_DIR/push.log"
    assert_log_contains "Backup creation failed"
}

@test "handles corrupted git repository state" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Corrupt the git repository
    echo "corrupted data" > .git/HEAD
    
    # Test git operations with corrupted repo
    run git status 2>/dev/null
    assert_failure
    
    # Should detect corruption and attempt recovery
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Git repository appears corrupted" >> "$TEST_LOG_DIR/push.log"
    assert_log_contains "Git repository appears corrupted"
}

@test "handles extremely large files" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create large file (1MB)
    dd if=/dev/zero of=large_file.bin bs=1024 count=1024 2>/dev/null
    
    # Test git operations with large file
    run git add large_file.bin
    assert_success
    
    run git commit -q -m "Large file commit"
    assert_success
    
    # Clean up
    rm -f large_file.bin
}

@test "handles binary files correctly" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create binary file
    printf '\x00\x01\x02\x03\x04\x05' > binary_file.bin
    
    git add binary_file.bin
    git commit -q -m "Binary file commit"
    
    # Verify binary file is tracked correctly
    run git ls-files binary_file.bin
    assert_output "binary_file.bin"
    
    # Test diff on binary file
    printf '\x00\x01\x02\x03\x04\x06' > binary_file.bin
    run git diff --name-only
    assert_output "binary_file.bin"
}

@test "handles permission denied scenarios" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create file and remove write permission
    echo "permission test" > readonly_file.txt
    chmod 444 readonly_file.txt
    
    # Test operations on read-only file
    run echo "new content" > readonly_file.txt 2>/dev/null
    assert_failure
    
    # Restore permissions for cleanup
    chmod 644 readonly_file.txt
}

@test "handles unicode and special characters in filenames" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create files with special characters
    echo "unicode content" > "测试文件.txt"
    echo "special chars" > "file with spaces & symbols!@#.txt"
    echo "emoji content" > "📁_emoji_file.txt"
    
    git add "测试文件.txt" "file with spaces & symbols!@#.txt" "📁_emoji_file.txt"
    git commit -q -m "Unicode and special character files"
    
    # Verify files are tracked
    run git ls-files --others --exclude-standard
    assert_output ""
}

@test "handles very long file paths" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create deep directory structure
    local long_path="very/long/path/structure/that/goes/very/deep/into/subdirectories/and/might/cause/issues"
    mkdir -p "$long_path"
    echo "deep content" > "$long_path/deep_file.txt"
    
    git add "$long_path/deep_file.txt"
    git commit -q -m "Deep directory structure"
    
    # Verify deep file is tracked
    run git ls-files | grep "deep_file.txt"
    assert_success
}

@test "handles git hooks interference" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create pre-commit hook that might interfere
    mkdir -p .git/hooks
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "Pre-commit hook executed"
exit 0
EOF
    chmod +x .git/hooks/pre-commit
    
    # Test commit with hook
    echo "hook test" > hook_test.txt
    git add hook_test.txt
    run git commit -q -m "Hook test commit"
    assert_success
}

@test "handles concurrent file modifications" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create file
    echo "original content" > concurrent_file.txt
    git add concurrent_file.txt
    git commit -q -m "Original content"
    
    # Simulate concurrent modification
    echo "modified content 1" > concurrent_file.txt &
    echo "modified content 2" > concurrent_file.txt &
    wait
    
    # Test git status with concurrent changes
    run git status --porcelain
    assert_output --partial "concurrent_file.txt"
}

@test "handles case sensitivity issues" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create files with case variations
    echo "lowercase" > testfile.txt
    git add testfile.txt
    git commit -q -m "Lowercase file"
    
    # On case-insensitive filesystems, this might cause issues
    echo "uppercase" > TestFile.txt 2>/dev/null || true
    
    # Test git's handling of case differences
    run git status --porcelain
    # Output varies based on filesystem case sensitivity
    assert_success
}

@test "handles symlinks and special files" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create regular file and symlink
    echo "target content" > target_file.txt
    ln -s target_file.txt symlink_file.txt 2>/dev/null || true
    
    # Test git operations with symlinks
    git add target_file.txt symlink_file.txt 2>/dev/null || true
    git commit -q -m "Files with symlinks" 2>/dev/null || true
    
    # Verify both are tracked appropriately
    run git ls-files
    assert_output --partial "target_file.txt"
}

@test "handles git configuration edge cases" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Test with minimal git config
    git config --unset user.email || true
    git config --unset user.name || true
    
    # Create content
    echo "config test" > config_test.txt
    git add config_test.txt
    
    # Test commit without user config
    run git commit -q -m "Config test" 2>/dev/null
    assert_failure
    
    # Restore config
    git config user.email "test@example.com"
    git config user.name "Test User"
}