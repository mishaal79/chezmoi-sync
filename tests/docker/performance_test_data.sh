#!/bin/bash
# Performance test data generator

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DATA_DIR="$HOME/test-data"
CHEZMOI_DIR="$HOME/.local/share/chezmoi"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[PERF]${NC} $1"; }
print_success() { echo -e "${GREEN}[PERF]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[PERF]${NC} $1"; }
print_error() { echo -e "${RED}[PERF]${NC} $1"; }

# Generate test data of various sizes
generate_test_files() {
    local count="${1:-100}"
    local size="${2:-1K}"
    
    print_status "Generating $count test files of $size each..."
    
    mkdir -p "$TEST_DATA_DIR"
    cd "$TEST_DATA_DIR"
    
    for ((i=1; i<=count; i++)); do
        case "$size" in
            "1K")
                head -c 1024 /dev/urandom | base64 > "test_file_${i}.txt"
                ;;
            "10K")
                head -c 10240 /dev/urandom | base64 > "test_file_${i}.txt"
                ;;
            "100K")
                head -c 102400 /dev/urandom | base64 > "test_file_${i}.txt"
                ;;
            "1M")
                head -c 1048576 /dev/urandom | base64 > "test_file_${i}.txt"
                ;;
        esac
        
        # Add some text content for better compression testing
        echo "# Test file $i - generated at $(date)" >> "test_file_${i}.txt"
        echo "# Size: $size, Type: performance test data" >> "test_file_${i}.txt"
    done
    
    print_success "Generated $count files of $size each"
}

# Generate chezmoi template files
generate_chezmoi_templates() {
    local count="${1:-50}"
    
    print_status "Generating $count chezmoi template files..."
    
    mkdir -p "$CHEZMOI_DIR"
    cd "$CHEZMOI_DIR"
    
    for ((i=1; i<=count; i++)); do
        cat > "dot_config_app${i}.conf.tmpl" << EOF
# Configuration file for app${i}
# Generated at: $(date)
# Machine: {{ .chezmoi.hostname }}
# User: {{ .chezmoi.username }}

[settings]
app_name = "app${i}"
version = "1.0.${i}"
debug = {{ if eq .chezmoi.hostname "debug-machine" }}true{{ else }}false{{ end }}
data_dir = "{{ .chezmoi.homeDir }}/.config/app${i}/data"

[performance]
cache_size = $((i * 1024))
max_connections = $((i * 10))
timeout = $((i + 30))

[features]
feature_a = {{ if gt ${i} 25 }}true{{ else }}false{{ end }}
feature_b = {{ if eq (mod ${i} 2) 0 }}true{{ else }}false{{ end }}
feature_c = {{ if lt ${i} 75 }}true{{ else }}false{{ end }}

# Dynamic content based on machine type
{{ if eq .test_machine_type "mac-mini" }}
optimization = "desktop"
resources = "high"
{{ else if eq .test_machine_type "macbook-air" }}
optimization = "laptop"
resources = "medium"
{{ else }}
optimization = "server"
resources = "low"
{{ end }}

# Random configuration data
random_value = $((RANDOM % 1000))
timestamp = $(date +%s)
EOF
    done
    
    print_success "Generated $count chezmoi template files"
}

# Generate nested directory structure
generate_directory_structure() {
    local depth="${1:-5}"
    local width="${2:-5}"
    
    print_status "Generating directory structure (depth: $depth, width: $width)..."
    
    cd "$CHEZMOI_DIR"
    
    generate_dirs() {
        local current_depth="$1"
        local current_path="$2"
        
        if [ "$current_depth" -le 0 ]; then
            return
        fi
        
        for ((i=1; i<=width; i++)); do
            local dir_path="${current_path}/level${current_depth}_dir${i}"
            mkdir -p "$dir_path"
            
            # Add files in each directory
            echo "Content for depth $current_depth, dir $i" > "${dir_path}/file${i}.txt"
            echo "{{ .chezmoi.hostname }}-${current_depth}-${i}" > "${dir_path}/dot_config${i}.tmpl"
            
            # Recurse to next level
            generate_dirs $((current_depth - 1)) "$dir_path"
        done
    }
    
    generate_dirs "$depth" "."
    print_success "Generated nested directory structure"
}

# Create git repository with history
initialize_git_repo() {
    local commits="${1:-100}"
    
    print_status "Initializing git repository with $commits commits..."
    
    cd "$CHEZMOI_DIR"
    git init --initial-branch=main
    git config user.email "perf@example.com"
    git config user.name "Performance Test"
    
    # Create initial commit
    echo "# Performance Test Repository" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Generate commit history
    for ((i=1; i<=commits; i++)); do
        echo "Commit $i content" > "commit_${i}.txt"
        git add "commit_${i}.txt"
        git commit -m "Performance test commit $i"
        
        # Occasionally modify existing files
        if [ $((i % 10)) -eq 0 ]; then
            echo "Modified at commit $i" >> README.md
            git add README.md
            git commit -m "Update README at commit $i"
        fi
    done
    
    print_success "Created git repository with $commits commits"
}

# Performance test scenarios
run_performance_scenario() {
    local scenario="$1"
    
    case "$scenario" in
        "small")
            generate_test_files 10 "1K"
            generate_chezmoi_templates 5
            generate_directory_structure 2 3
            initialize_git_repo 10
            ;;
        "medium")
            generate_test_files 100 "10K"
            generate_chezmoi_templates 50
            generate_directory_structure 3 5
            initialize_git_repo 50
            ;;
        "large")
            generate_test_files 500 "100K"
            generate_chezmoi_templates 200
            generate_directory_structure 5 5
            initialize_git_repo 100
            ;;
        "extreme")
            generate_test_files 1000 "1M"
            generate_chezmoi_templates 500
            generate_directory_structure 7 7
            initialize_git_repo 200
            ;;
        *)
            print_error "Unknown scenario: $scenario"
            print_warning "Available scenarios: small, medium, large, extreme"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    local scenario="${1:-medium}"
    
    print_status "Starting performance test data generation..."
    print_status "Scenario: $scenario"
    
    # Clean up existing data
    rm -rf "$TEST_DATA_DIR" "$CHEZMOI_DIR" 2>/dev/null || true
    mkdir -p "$TEST_DATA_DIR" "$CHEZMOI_DIR"
    
    # Run scenario
    run_performance_scenario "$scenario"
    
    # Report statistics
    print_status "Performance test data statistics:"
    echo "  Test data files: $(find "$TEST_DATA_DIR" -type f | wc -l)"
    echo "  Chezmoi files: $(find "$CHEZMOI_DIR" -name "*.tmpl" | wc -l)"
    echo "  Total files: $(find "$CHEZMOI_DIR" -type f | wc -l)"
    echo "  Git commits: $(cd "$CHEZMOI_DIR" && git rev-list --count HEAD)"
    echo "  Total disk usage: $(du -sh "$CHEZMOI_DIR" | cut -f1)"
    
    print_success "Performance test data generation complete!"
}

# Show help
show_help() {
    echo "Performance Test Data Generator"
    echo ""
    echo "Usage: $0 [scenario]"
    echo ""
    echo "Scenarios:"
    echo "  small   - 10 files, 5 templates, light git history"
    echo "  medium  - 100 files, 50 templates, moderate git history (default)"
    echo "  large   - 500 files, 200 templates, extensive git history"
    echo "  extreme - 1000 files, 500 templates, massive git history"
    echo ""
    echo "Examples:"
    echo "  $0 small"
    echo "  $0 medium"
    echo "  $0 large"
}

# Handle command line arguments
case "${1:-medium}" in
    "-h"|"--help"|"help")
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac