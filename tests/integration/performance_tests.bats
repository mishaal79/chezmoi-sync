#!/usr/bin/env bats
# Performance benchmarking tests for chezmoi-sync

load ../unit/test_helper

setup() {
    setup_test_env
    mock_osascript
    setup_mock_remote
    
    # Performance test configuration
    export PERF_LOG_DIR="$TEST_LOG_DIR/performance"
    mkdir -p "$PERF_LOG_DIR"
}

teardown() {
    teardown_test_env
}

# Performance test helper function
measure_time() {
    local operation="$1"
    shift
    
    local start_time=$(date +%s%N)
    "$@"
    local end_time=$(date +%s%N)
    
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))
    
    echo "[$operation] Duration: ${duration_ms}ms" >> "$PERF_LOG_DIR/timing.log"
    echo "$duration_ms"
}

@test "performance: git operations scale with file count" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Test with different file counts
    for file_count in 10 50 100 500; do
        print_status "Testing with $file_count files..."
        
        # Generate test files
        for ((i=1; i<=file_count; i++)); do
            echo "Content for file $i" > "perf_file_${i}.txt"
        done
        
        # Measure git add time
        local add_time=$(measure_time "git_add_${file_count}" git add .)
        
        # Measure git commit time
        local commit_time=$(measure_time "git_commit_${file_count}" git commit -q -m "Performance test with $file_count files")
        
        # Log results
        echo "Files: $file_count, Add: ${add_time}ms, Commit: ${commit_time}ms" >> "$PERF_LOG_DIR/scaling.log"
        
        # Clean up for next iteration
        git reset --hard HEAD~1
        git clean -fd
    done
    
    # Verify scaling results exist
    assert_file_exists "$PERF_LOG_DIR/scaling.log"
    run grep -c "Files:" "$PERF_LOG_DIR/scaling.log"
    assert_output "4"  # Should have 4 test runs
}

@test "performance: chezmoi template processing speed" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create various template complexities
    declare -A template_types=(
        ["simple"]='export VAR="{{ .chezmoi.hostname }}"'
        ["medium"]='{{- if eq .chezmoi.os "darwin" }}export MAC_VAR="true"{{ end }}'
        ["complex"]='{{- range $key, $value := .env }}export {{ $key }}="{{ $value }}"{{ end }}'
    )
    
    for type in "${!template_types[@]}"; do
        local template_content="${template_types[$type]}"
        
        # Create multiple files of this template type
        for ((i=1; i<=20; i++)); do
            echo "$template_content" > "dot_config_${type}_${i}.tmpl"
        done
        
        # Measure template processing time
        local process_time=$(measure_time "template_${type}" chezmoi execute-template < "dot_config_${type}_1.tmpl")
        
        echo "Template type: $type, Processing: ${process_time}ms" >> "$PERF_LOG_DIR/templates.log"
    done
    
    assert_file_exists "$PERF_LOG_DIR/templates.log"
}

@test "performance: sync operations with different data sizes" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Test with different file sizes
    declare -A file_sizes=(
        ["small"]="1024"      # 1KB
        ["medium"]="51200"    # 50KB
        ["large"]="1048576"   # 1MB
    )
    
    for size_name in "${!file_sizes[@]}"; do
        local size="${file_sizes[$size_name]}"
        
        # Create file of specific size
        head -c "$size" /dev/urandom | base64 > "${size_name}_file.txt"
        
        # Measure git operations
        local add_time=$(measure_time "add_${size_name}" git add "${size_name}_file.txt")
        local commit_time=$(measure_time "commit_${size_name}" git commit -q -m "Add $size_name file")
        
        # Measure git push simulation (to local remote)
        local push_time=$(measure_time "push_${size_name}" git push origin main)
        
        echo "Size: $size_name ($size bytes), Add: ${add_time}ms, Commit: ${commit_time}ms, Push: ${push_time}ms" >> "$PERF_LOG_DIR/sizes.log"
    done
    
    assert_file_exists "$PERF_LOG_DIR/sizes.log"
}

@test "performance: concurrent file modifications" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create base files
    for ((i=1; i<=10; i++)); do
        echo "Base content $i" > "concurrent_${i}.txt"
    done
    git add .
    git commit -q -m "Base files for concurrent test"
    
    # Simulate concurrent modifications
    local start_time=$(date +%s%N)
    
    (
        for ((i=1; i<=5; i++)); do
            echo "Modified by process 1 at $i" >> "concurrent_${i}.txt"
        done
    ) &
    
    (
        for ((i=6; i<=10; i++)); do
            echo "Modified by process 2 at $i" >> "concurrent_${i}.txt"
        done
    ) &
    
    wait
    
    local end_time=$(date +%s%N)
    local duration_ms=$(((end_time - start_time) / 1000000))
    
    # Measure git status time with concurrent changes
    local status_time=$(measure_time "git_status_concurrent" git status --porcelain)
    
    echo "Concurrent modifications: ${duration_ms}ms, Status check: ${status_time}ms" >> "$PERF_LOG_DIR/concurrent.log"
    assert_file_exists "$PERF_LOG_DIR/concurrent.log"
}

@test "performance: memory usage during large operations" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create memory-intensive test data
    for ((i=1; i<=100; i++)); do
        # Create file with repetitive content (tests compression)
        for ((j=1; j<=100; j++)); do
            echo "Repetitive content line $j in file $i"
        done > "memory_test_${i}.txt"
    done
    
    # Monitor memory usage during git operations
    local memory_before=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
    
    local add_time=$(measure_time "memory_test_add" git add .)
    local commit_time=$(measure_time "memory_test_commit" git commit -q -m "Memory test files")
    
    local memory_after=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
    local memory_diff=$((memory_after - memory_before))
    
    echo "Memory usage - Before: ${memory_before}KB, After: ${memory_after}KB, Diff: ${memory_diff}KB" >> "$PERF_LOG_DIR/memory.log"
    echo "Operations - Add: ${add_time}ms, Commit: ${commit_time}ms" >> "$PERF_LOG_DIR/memory.log"
    
    assert_file_exists "$PERF_LOG_DIR/memory.log"
}

@test "performance: deep directory structure handling" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create deep directory structure
    local deep_path="level1/level2/level3/level4/level5/level6/level7/level8/level9/level10"
    mkdir -p "$deep_path"
    
    # Add files at various depths
    for ((depth=1; depth<=10; depth++)); do
        local path_parts=$(echo "$deep_path" | cut -d'/' -f1-$depth)
        echo "Content at depth $depth" > "${path_parts}/file_depth_${depth}.txt"
    done
    
    # Measure operations with deep structure
    local add_time=$(measure_time "deep_structure_add" git add .)
    local commit_time=$(measure_time "deep_structure_commit" git commit -q -m "Deep directory structure")
    
    # Test git status on deep structure
    local status_time=$(measure_time "deep_structure_status" git status --porcelain)
    
    echo "Deep structure - Add: ${add_time}ms, Commit: ${commit_time}ms, Status: ${status_time}ms" >> "$PERF_LOG_DIR/deep_structure.log"
    assert_file_exists "$PERF_LOG_DIR/deep_structure.log"
}

@test "performance: git history traversal speed" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create commit history
    for ((i=1; i<=50; i++)); do
        echo "History content $i" > "history_${i}.txt"
        git add "history_${i}.txt"
        git commit -q -m "History commit $i"
    done
    
    # Measure history operations
    local log_time=$(measure_time "git_log" git log --oneline)
    local diff_time=$(measure_time "git_diff" git diff HEAD~10 HEAD)
    local blame_time=$(measure_time "git_blame" git blame history_25.txt)
    
    echo "History operations - Log: ${log_time}ms, Diff: ${diff_time}ms, Blame: ${blame_time}ms" >> "$PERF_LOG_DIR/history.log"
    assert_file_exists "$PERF_LOG_DIR/history.log"
}

@test "performance: network simulation latency impact" {
    cd "$TEST_CHEZMOI_SOURCE_DIR"
    
    # Create test content
    echo "Network test content" > network_perf_test.txt
    git add network_perf_test.txt
    git commit -q -m "Network performance test"
    
    # Test local push (baseline)
    local local_push_time=$(measure_time "local_push" git push origin main)
    
    # Simulate network delay with timeout (worst case)
    git remote set-url origin "https://httpbin.org/delay/2"
    local network_push_time=$(timeout 5s bash -c "measure_time network_push git push origin main" 2>/dev/null || echo "5000")
    
    # Restore local remote
    git remote set-url origin "${TEST_TEMP_DIR}/remote.git"
    
    echo "Network performance - Local: ${local_push_time}ms, Network: ${network_push_time}ms" >> "$PERF_LOG_DIR/network.log"
    assert_file_exists "$PERF_LOG_DIR/network.log"
}

@test "performance: generate comprehensive performance report" {
    # Combine all performance data into a report
    local report_file="$PERF_LOG_DIR/performance_report.txt"
    
    echo "=== Chezmoi-Sync Performance Test Report ===" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "" >> "$report_file"
    
    # Add results from each test
    for log_file in "$PERF_LOG_DIR"/*.log; do
        if [ -f "$log_file" ] && [ "$(basename "$log_file")" != "performance_report.txt" ]; then
            echo "=== $(basename "$log_file" .log | tr '_' ' ' | tr '[:lower:]' '[:upper:]') ===" >> "$report_file"
            cat "$log_file" >> "$report_file"
            echo "" >> "$report_file"
        fi
    done
    
    # Add summary statistics
    echo "=== SUMMARY ===" >> "$report_file"
    echo "Total tests run: $(find "$PERF_LOG_DIR" -name "*.log" -not -name "performance_report.txt" | wc -l)" >> "$report_file"
    echo "Total measurements: $(cat "$PERF_LOG_DIR"/*.log 2>/dev/null | wc -l)" >> "$report_file"
    
    assert_file_exists "$report_file"
    
    # Display report summary
    run head -20 "$report_file"
    assert_success
}