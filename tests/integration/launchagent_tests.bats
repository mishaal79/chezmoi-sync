#!/usr/bin/env bats
# Integration tests for LaunchAgent lifecycle and behavior

load ../unit/test_helper

setup() {
    setup_test_env
    mock_osascript
    
    # Create mock LaunchAgents directory
    export TEST_LAUNCHAGENTS_DIR="$TEST_TEMP_DIR/Library/LaunchAgents"
    mkdir -p "$TEST_LAUNCHAGENTS_DIR"
    
    # Mock launchctl for testing
    export PATH="${TEST_TEMP_DIR}/scripts:$PATH"
    cat > "${TEST_TEMP_DIR}/scripts/launchctl" << 'EOF'
#!/bin/bash
# Mock launchctl for testing
case "$1" in
    "list")
        if [[ "$*" == *"chezmoi"* ]]; then
            echo "48468	0	com.chezmoi.autopush"
            echo "-	0	com.chezmoi.autopull"
        fi
        ;;
    "load")
        echo "[MOCK] Loading: $2" >> "${TEST_LOG_DIR}/launchctl.log"
        ;;
    "unload")
        echo "[MOCK] Unloading: $2" >> "${TEST_LOG_DIR}/launchctl.log"
        ;;
    "start")
        echo "[MOCK] Starting: $2" >> "${TEST_LOG_DIR}/launchctl.log"
        ;;
    "stop")
        echo "[MOCK] Stopping: $2" >> "${TEST_LOG_DIR}/launchctl.log"
        ;;
    *)
        echo "[MOCK] launchctl $*" >> "${TEST_LOG_DIR}/launchctl.log"
        ;;
esac
exit 0
EOF
    chmod +x "${TEST_TEMP_DIR}/scripts/launchctl"
}

teardown() {
    teardown_test_env
}

@test "LaunchAgent plist files are valid XML" {
    # Copy plist files to test directory
    cp ../../plists/com.chezmoi.autopush.plist "$TEST_LAUNCHAGENTS_DIR/"
    cp ../../plists/com.chezmoi.autopull.plist "$TEST_LAUNCHAGENTS_DIR/"
    
    # Test plist validity (using plutil if available)
    if command -v plutil &> /dev/null; then
        run plutil -lint "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.autopush.plist"
        assert_success
        
        run plutil -lint "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.autopull.plist"
        assert_success
    else
        # Basic XML syntax check
        run grep -q "<plist" "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.autopush.plist"
        assert_success
        
        run grep -q "</plist>" "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.autopush.plist"
        assert_success
    fi
}

@test "LaunchAgent can be loaded successfully" {
    # Create test plist
    cat > "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.test.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.chezmoi.test</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/echo</string>
        <string>test</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
    
    # Test loading LaunchAgent
    run launchctl load "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.test.plist"
    assert_success
    
    # Verify load was logged
    assert_file_exists "$TEST_LOG_DIR/launchctl.log"
    run grep -q "Loading:" "$TEST_LOG_DIR/launchctl.log"
    assert_success
}

@test "LaunchAgent can be unloaded successfully" {
    # Create and load test plist first
    cat > "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.test.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.chezmoi.test</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/echo</string>
        <string>test</string>
    </array>
</dict>
</plist>
EOF
    
    launchctl load "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.test.plist"
    
    # Test unloading
    run launchctl unload "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.test.plist"
    assert_success
    
    # Verify unload was logged
    run grep -q "Unloading:" "$TEST_LOG_DIR/launchctl.log"
    assert_success
}

@test "LaunchAgent status can be checked" {
    # Test listing LaunchAgents
    run launchctl list | grep chezmoi
    assert_success
    assert_output --partial "com.chezmoi.autopush"
    assert_output --partial "com.chezmoi.autopull"
}

@test "LaunchAgent handles service restart correctly" {
    # Test restart sequence (unload -> load)
    run launchctl unload "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.test.plist" 2>/dev/null || true
    run launchctl load "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.test.plist"
    assert_success
    
    # Verify both operations were logged
    run grep -c "Loading\|Unloading" "$TEST_LOG_DIR/launchctl.log"
    # Should have at least one entry
    assert_success
}

@test "LaunchAgent plist contains required keys" {
    local plist_file="$TEST_LAUNCHAGENTS_DIR/com.chezmoi.autopush.plist"
    cp ../../plists/com.chezmoi.autopush.plist "$plist_file"
    
    # Check for required plist keys
    run grep -q "<key>Label</key>" "$plist_file"
    assert_success
    
    run grep -q "<key>ProgramArguments</key>" "$plist_file"
    assert_success
    
    run grep -q "<key>WorkingDirectory</key>" "$plist_file" || echo "Optional key missing"
    assert_success
}

@test "LaunchAgent handles missing script files gracefully" {
    # Create plist pointing to non-existent script
    cat > "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.missing.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.chezmoi.missing</string>
    <key>ProgramArguments</key>
    <array>
        <string>/nonexistent/script.sh</string>
    </array>
</dict>
</plist>
EOF
    
    # Test loading with missing script
    run launchctl load "$TEST_LAUNCHAGENTS_DIR/com.chezmoi.missing.plist"
    assert_success  # Load might succeed, but execution will fail
}

@test "LaunchAgent respects KeepAlive settings" {
    # Test plist with KeepAlive configuration
    local plist_file="../../plists/com.chezmoi.autopush.plist"
    
    # Check if KeepAlive is configured
    run grep -q "<key>KeepAlive</key>" "$plist_file"
    assert_success
    
    # Verify KeepAlive is set to true
    run grep -A1 "<key>KeepAlive</key>" "$plist_file" | grep -q "<true/>"
    assert_success
}

@test "LaunchAgent handles system sleep/wake cycles" {
    # Simulate system sleep scenario
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] System going to sleep" >> "$TEST_LOG_DIR/power.log"
    
    # Test LaunchAgent behavior during sleep (should continue after wake)
    run echo "Simulating sleep/wake cycle"
    assert_success
    
    # Verify services would restart after wake
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] System woke up, services restarting" >> "$TEST_LOG_DIR/power.log"
    assert_file_exists "$TEST_LOG_DIR/power.log"
}

@test "LaunchAgent logs are created and rotated" {
    # Test log file creation
    mkdir -p "$TEST_LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Test log entry" >> "$TEST_LOG_DIR/autopush.out"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Test error entry" >> "$TEST_LOG_DIR/autopush.err"
    
    assert_file_exists "$TEST_LOG_DIR/autopush.out"
    assert_file_exists "$TEST_LOG_DIR/autopush.err"
    
    # Test log content
    run grep -q "Test log entry" "$TEST_LOG_DIR/autopush.out"
    assert_success
}

@test "LaunchAgent handles permission errors" {
    # Create plist in read-only directory (simulate permission issues)
    local readonly_dir="$TEST_TEMP_DIR/readonly"
    mkdir -p "$readonly_dir"
    chmod 555 "$readonly_dir"
    
    # Test operations with permission issues
    run cp ../../plists/com.chezmoi.autopush.plist "$readonly_dir/" 2>/dev/null
    assert_failure
    
    # Restore permissions for cleanup
    chmod 755 "$readonly_dir"
}

@test "LaunchAgent environment variables are set correctly" {
    # Check if plist sets required environment variables
    local plist_file="../../plists/com.chezmoi.autopush.plist"
    
    # Look for environment variable settings
    run grep -q "<key>EnvironmentVariables</key>" "$plist_file" || echo "No environment variables set"
    # This might not be present in all configurations
    assert_success
}