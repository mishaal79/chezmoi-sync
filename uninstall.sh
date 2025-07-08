#!/bin/bash

# Chezmoi Auto-Sync Uninstaller
# This script completely removes chezmoi auto-sync functionality

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPTS_DIR="$HOME/scripts"
PLIST_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/chezmoi"
BACKUP_DIR="$HOME/.local/share/chezmoi-backups"

# Output functions
print_red() { echo -e "${RED}$1${NC}"; }
print_green() { echo -e "${GREEN}$1${NC}"; }
print_yellow() { echo -e "${YELLOW}$1${NC}"; }
print_blue() { echo -e "${BLUE}$1${NC}"; }

# Send notification
notify() {
    local message="$1"
    local title="${2:-Chezmoi Sync Uninstall}"
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
}

# Show help
show_help() {
    cat << EOF
Chezmoi Auto-Sync Uninstaller

Usage: $0 [options]

Options:
    -h, --help          Show this help message
    -f, --force         Force uninstall without confirmation
    -k, --keep-logs     Keep log files
    -k, --keep-backups  Keep backup files

This script will remove:
    - LaunchAgent plist files
    - Sync scripts from ~/scripts/
    - Log files (unless --keep-logs is used)
    - Backup files (unless --keep-backups is used)
EOF
}

# Confirm uninstallation
confirm_uninstall() {
    if [[ "${FORCE:-false}" == "true" ]]; then
        return 0
    fi
    
    print_yellow "This will completely remove chezmoi auto-sync functionality."
    print_yellow "The following will be removed:"
    echo "  - LaunchAgent services"
    echo "  - Sync scripts from $SCRIPTS_DIR"
    echo "  - Log files from $LOG_DIR"
    echo "  - Backup files from $BACKUP_DIR"
    echo
    print_yellow "Your chezmoi configuration and dotfiles will NOT be affected."
    echo
    
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_blue "Uninstall cancelled"
        exit 0
    fi
}

# Stop and remove LaunchAgents
remove_launchagents() {
    print_blue "Stopping and removing LaunchAgents..."
    
    # Stop agents
    launchctl unload "$PLIST_DIR/com.chezmoi.autopush.plist" 2>/dev/null || true
    launchctl unload "$PLIST_DIR/com.chezmoi.autopull.plist" 2>/dev/null || true
    
    # Remove plist files
    rm -f "$PLIST_DIR/com.chezmoi.autopush.plist"
    rm -f "$PLIST_DIR/com.chezmoi.autopull.plist"
    
    # Verify removal
    if launchctl list | grep -q com.chezmoi; then
        print_red "WARNING: Some chezmoi services are still running"
        print_red "You may need to restart your system"
    else
        print_green "LaunchAgents removed successfully"
    fi
}

# Remove scripts
remove_scripts() {
    print_blue "Removing scripts..."
    
    rm -f "$SCRIPTS_DIR/chezmoi-push.sh"
    rm -f "$SCRIPTS_DIR/chezmoi-pull.sh"
    rm -f "$SCRIPTS_DIR/chezmoi-resolve.sh"
    rm -f "$SCRIPTS_DIR/chezmoi-sync"
    
    print_green "Scripts removed"
}

# Remove log files
remove_logs() {
    if [[ "${KEEP_LOGS:-false}" == "true" ]]; then
        print_yellow "Keeping log files as requested"
        return 0
    fi
    
    print_blue "Removing log files..."
    
    rm -rf "$LOG_DIR"
    
    print_green "Log files removed"
}

# Remove backup files
remove_backups() {
    if [[ "${KEEP_BACKUPS:-false}" == "true" ]]; then
        print_yellow "Keeping backup files as requested"
        return 0
    fi
    
    print_blue "Removing backup files..."
    
    if [[ -d "$BACKUP_DIR" ]]; then
        print_yellow "Backup directory contains $(ls -1 "$BACKUP_DIR" | wc -l) backups"
        read -p "Are you sure you want to delete all backups? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$BACKUP_DIR"
            print_green "Backup files removed"
        else
            print_yellow "Backup files kept"
        fi
    else
        print_blue "No backup directory found"
    fi
}

# Clean up any remaining files
cleanup() {
    print_blue "Cleaning up remaining files..."
    
    # Remove lock files
    rm -f /tmp/chezmoi-push.lock
    rm -f /tmp/chezmoi-pull.lock
    
    # Remove any temporary files
    rm -f /tmp/chezmoi-*
    
    print_green "Cleanup completed"
}

# Verify uninstallation
verify_uninstall() {
    print_blue "Verifying uninstallation..."
    
    local issues=0
    
    # Check LaunchAgents
    if launchctl list | grep -q com.chezmoi; then
        print_red "WARNING: Some chezmoi services are still running"
        issues=$((issues + 1))
    fi
    
    # Check for plist files
    if [[ -f "$PLIST_DIR/com.chezmoi.autopush.plist" ]] || [[ -f "$PLIST_DIR/com.chezmoi.autopull.plist" ]]; then
        print_red "WARNING: Some plist files still exist"
        issues=$((issues + 1))
    fi
    
    # Check for scripts
    if [[ -f "$SCRIPTS_DIR/chezmoi-push.sh" ]] || [[ -f "$SCRIPTS_DIR/chezmoi-pull.sh" ]] || [[ -f "$SCRIPTS_DIR/chezmoi-resolve.sh" ]] || [[ -f "$SCRIPTS_DIR/chezmoi-sync" ]]; then
        print_red "WARNING: Some scripts still exist"
        issues=$((issues + 1))
    fi
    
    if [[ $issues -eq 0 ]]; then
        print_green "Uninstallation verified successfully"
    else
        print_red "Uninstallation completed with $issues warnings"
    fi
}

# Main uninstallation function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -k|--keep-logs)
                KEEP_LOGS=true
                shift
                ;;
            -b|--keep-backups)
                KEEP_BACKUPS=true
                shift
                ;;
            *)
                print_red "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    print_blue "🗑️  Chezmoi Auto-Sync Uninstaller"
    print_blue "================================"
    echo
    
    confirm_uninstall
    remove_launchagents
    remove_scripts
    remove_logs
    remove_backups
    cleanup
    verify_uninstall
    
    echo
    print_green "✅ Uninstallation completed!"
    echo
    print_blue "Chezmoi auto-sync has been removed from your system."
    print_blue "Your chezmoi configuration and dotfiles are unchanged."
    echo
    
    notify "Chezmoi auto-sync uninstalled successfully!"
}

# Run main function with all arguments
main "$@"