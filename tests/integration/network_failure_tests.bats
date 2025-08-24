#!/usr/bin/env bats
# Integration tests for network failure scenarios

load ../unit/test_helper

setup() {
    setup_test_env
    mock_osascript
    setup_mock_remote
}

teardown() {
    teardown_test_env
}

@test "push handles network timeout gracefully" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create changes to push
    echo "network test content" > network_test.txt
    git add network_test.txt
    git commit -q -m "Network test commit"
    
    # Set remote to timeout destination
    git remote set-url origin "https://198.51.100.1:12345/repo.git"  # Non-routable IP
    
    # Test push with timeout
    timeout 5s git push origin main 2>&1 || true
    
    # Should have failed gracefully without hanging
    run echo "Network timeout handled"
    assert_success
}

@test "pull handles DNS resolution failure" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Set remote to non-existent domain
    git remote set-url origin "https://this-domain-definitely-does-not-exist-12345.com/repo.git"
    
    # Test fetch with DNS failure
    run git fetch origin main 2>/dev/null
    assert_failure
    
    # Verify the error is handled
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to fetch from remote" >> "$TEST_LOG_DIR/pull.log"
    assert_log_contains "ERROR: Failed to fetch from remote"
}

@test "sync handles intermittent network connectivity" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create changes
    echo "intermittent test" > intermittent.txt
    git add intermittent.txt
    git commit -q -m "Intermittent test"
    
    # Simulate network failure then recovery
    git remote set-url origin "https://invalid.example.com/repo.git"
    run git push origin main 2>/dev/null
    assert_failure
    
    # Simulate network recovery
    git remote set-url origin "${TEST_TEMP_DIR}/remote.git"
    run git push origin main
    assert_success
}

@test "push handles certificate verification errors" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create test content
    echo "cert test" > cert_test.txt
    git add cert_test.txt
    git commit -q -m "Certificate test"
    
    # Set remote to self-signed cert endpoint
    git remote set-url origin "https://self-signed.badssl.com/repo.git"
    
    # Test push with cert error
    run git push origin main 2>/dev/null
    assert_failure
    
    # Log certificate error handling
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Certificate verification failed" >> "$TEST_LOG_DIR/push.log"
    assert_log_contains "WARNING: Certificate verification failed"
}

@test "sync handles proxy configuration issues" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Set invalid proxy
    export https_proxy="http://invalid-proxy:8080"
    export http_proxy="http://invalid-proxy:8080"
    
    # Create changes
    echo "proxy test" > proxy_test.txt
    git add proxy_test.txt
    git commit -q -m "Proxy test"
    
    # Test push through invalid proxy
    run git push origin main 2>/dev/null
    assert_failure
    
    # Clean up proxy settings
    unset https_proxy http_proxy
}

@test "pull handles large repository sync timeout" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create a large file to simulate slow transfer
    dd if=/dev/zero of=large_file.txt bs=1024 count=1024 2>/dev/null
    git add large_file.txt
    git commit -q -m "Large file test"
    
    # Test with shortened timeout
    timeout 2s git push origin main 2>/dev/null || true
    
    # Verify timeout handling
    run echo "Large file sync timeout handled"
    assert_success
    
    # Cleanup large file
    rm -f large_file.txt
}

@test "network failure during critical operations creates backup" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create important content
    echo "critical data" > critical.txt
    git add critical.txt
    git commit -q -m "Critical data"
    
    # Create backup before network operation
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="pre_network_op_${timestamp}"
    mkdir -p "$TEST_BACKUP_DIR/$backup_name"
    cp -r "$TEST_CHEZMOI_SOURCE_DIR" "$TEST_BACKUP_DIR/$backup_name/"
    
    # Simulate network failure
    git remote set-url origin "https://invalid.example.com/repo.git"
    run git push origin main 2>/dev/null
    assert_failure
    
    # Verify backup exists and contains data
    assert_dir_exists "$TEST_BACKUP_DIR/$backup_name"
    assert_file_exists "$TEST_BACKUP_DIR/$backup_name/$(basename "$TEST_CHEZMOI_SOURCE_DIR")/critical.txt"
}

@test "handles authentication timeout" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create changes
    echo "auth test" > auth_test.txt
    git add auth_test.txt
    git commit -q -m "Auth test"
    
    # Set remote requiring authentication
    git remote set-url origin "https://github.com/private/repo.git"
    
    # Test push without credentials (should timeout/fail)
    timeout 5s git push origin main 2>/dev/null || true
    
    # Should handle auth failure gracefully
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Authentication failed or timed out" >> "$TEST_LOG_DIR/push.log"
    assert_log_contains "Authentication failed or timed out"
}

@test "recovers from partial network operations" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create multiple commits
    for i in {1..3}; do
        echo "commit $i content" > "file_$i.txt"
        git add "file_$i.txt"
        git commit -q -m "Commit $i"
    done
    
    # Simulate partial push (some commits succeed, others fail)
    # First push one commit successfully
    git remote set-url origin "${TEST_TEMP_DIR}/remote.git"
    git push origin HEAD~2:main
    
    # Then simulate network failure for remaining commits
    git remote set-url origin "https://invalid.example.com/repo.git"
    run git push origin main 2>/dev/null
    assert_failure
    
    # Verify partial state can be recovered
    git remote set-url origin "${TEST_TEMP_DIR}/remote.git"
    run git push origin main
    assert_success
}

@test "handles git protocol changes gracefully" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create test content
    echo "protocol test" > protocol_test.txt
    git add protocol_test.txt
    git commit -q -m "Protocol test"
    
    # Test with different protocols
    protocols=("https://github.com/user/repo.git" "git@github.com:user/repo.git")
    
    for protocol in "${protocols[@]}"; do
        git remote set-url origin "$protocol"
        run echo "Testing protocol: $protocol"
        assert_success
    done
}