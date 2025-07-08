#!/bin/bash

# Chezmoi Conflict Resolution Helper Script
# Interactive script to help resolve conflicts in chezmoi repositories

set -euo pipefail

# Configuration
CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"
LOG_DIR="$HOME/Library/Logs/chezmoi"
LOG_FILE="$LOG_DIR/resolve.log"
BACKUP_DIR="$HOME/.local/share/chezmoi-backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Colored output functions
print_red() { echo -e "${RED}$1${NC}"; }
print_green() { echo -e "${GREEN}$1${NC}"; }
print_yellow() { echo -e "${YELLOW}$1${NC}"; }
print_blue() { echo -e "${BLUE}$1${NC}"; }

# Send notification
notify() {
    local message="$1"
    local title="${2:-Chezmoi Resolve}"
    osascript -e "display notification \"$message\" with title \"$title\""
}

# Show help
show_help() {
    cat << EOF
Chezmoi Conflict Resolution Helper

Usage: $0 [options]

Options:
    -h, --help          Show this help message
    -s, --status        Show current git status
    -d, --diff          Show diff of conflicts
    -r, --reset         Reset to last known good state
    -b, --backup        Create backup of current state

Interactive mode (default):
    The script will guide you through resolving conflicts step by step.
EOF
}

# Create backup
create_backup() {
    local backup_name="resolve-backup-$(date +%Y%m%d-%H%M%S)"
    print_blue "Creating backup: $backup_name"
    cp -r "$CHEZMOI_SOURCE_DIR" "$BACKUP_DIR/$backup_name"
    log "Created backup: $backup_name"
    print_green "Backup created successfully"
}

# Show git status
show_status() {
    cd "$CHEZMOI_SOURCE_DIR"
    print_blue "Git Status:"
    git status --porcelain
    echo
    print_blue "Branch Information:"
    git branch -vv
    echo
    print_blue "Remote Status:"
    git remote -v
}

# Show diff
show_diff() {
    cd "$CHEZMOI_SOURCE_DIR"
    print_blue "Unstaged Changes:"
    git diff --color=always | head -50
    echo
    print_blue "Staged Changes:"
    git diff --cached --color=always | head -50
}

# Reset to last known good state
reset_to_good_state() {
    cd "$CHEZMOI_SOURCE_DIR"
    print_yellow "WARNING: This will reset your repository to the last committed state."
    print_yellow "All local changes will be lost."
    echo
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_blue "Resetting to HEAD..."
        git reset --hard HEAD
        git clean -fd
        print_green "Repository reset successfully"
        log "Repository reset to HEAD"
    else
        print_yellow "Reset cancelled"
    fi
}

# Interactive conflict resolution
interactive_resolve() {
    cd "$CHEZMOI_SOURCE_DIR"
    
    print_blue "=== Chezmoi Conflict Resolution ==="
    echo
    
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        print_red "ERROR: Not in a git repository"
        exit 1
    fi
    
    # Check for conflicts
    if git diff --name-only --diff-filter=U | grep -q .; then
        print_red "Git merge conflicts detected:"
        git diff --name-only --diff-filter=U
        echo
        print_blue "Please resolve conflicts manually using your preferred editor or merge tool:"
        print_blue "  git mergetool"
        print_blue "  or edit files manually and then run: git add <file>"
        echo
        read -p "Press Enter when conflicts are resolved..."
        
        # Check if conflicts are resolved
        if git diff --name-only --diff-filter=U | grep -q .; then
            print_red "Conflicts still exist. Please resolve them first."
            exit 1
        fi
        
        print_green "Conflicts resolved!"
    fi
    
    # Show current status
    print_blue "Current Status:"
    show_status
    echo
    
    # Main menu
    while true; do
        print_blue "=== Resolution Options ==="
        echo "1) Show detailed diff"
        echo "2) Create backup"
        echo "3) Commit current changes"
        echo "4) Reset to last commit (DESTRUCTIVE)"
        echo "5) Apply chezmoi changes"
        echo "6) Push to remote"
        echo "7) Pull from remote"
        echo "8) Exit"
        echo
        read -p "Choose an option (1-8): " -n 1 -r
        echo
        
        case $REPLY in
            1)
                show_diff
                ;;
            2)
                create_backup
                ;;
            3)
                if git diff --quiet && git diff --cached --quiet; then
                    print_yellow "No changes to commit"
                else
                    read -p "Enter commit message: " commit_msg
                    if [ -z "$commit_msg" ]; then
                        commit_msg="Manual conflict resolution - $(date '+%Y-%m-%d %H:%M:%S')"
                    fi
                    git add .
                    git commit -m "$commit_msg"
                    print_green "Changes committed successfully"
                    log "Manual commit: $commit_msg"
                fi
                ;;
            4)
                reset_to_good_state
                ;;
            5)
                print_blue "Applying chezmoi changes..."
                if chezmoi apply; then
                    print_green "Chezmoi apply successful"
                    log "Chezmoi apply successful"
                else
                    print_red "Chezmoi apply failed"
                    log "ERROR: Chezmoi apply failed"
                fi
                ;;
            6)
                print_blue "Pushing to remote..."
                if git push origin main; then
                    print_green "Push successful"
                    log "Manual push successful"
                else
                    print_red "Push failed"
                    log "ERROR: Manual push failed"
                fi
                ;;
            7)
                print_blue "Pulling from remote..."
                if git pull origin main; then
                    print_green "Pull successful"
                    log "Manual pull successful"
                else
                    print_red "Pull failed - may have conflicts"
                    log "ERROR: Manual pull failed"
                fi
                ;;
            8)
                print_blue "Exiting..."
                exit 0
                ;;
            *)
                print_red "Invalid option. Please choose 1-8."
                ;;
        esac
        echo
    done
}

# Main script
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        -s|--status)
            show_status
            ;;
        -d|--diff)
            show_diff
            ;;
        -r|--reset)
            reset_to_good_state
            ;;
        -b|--backup)
            create_backup
            ;;
        *)
            interactive_resolve
            ;;
    esac
}

# Run main function with all arguments
main "$@"