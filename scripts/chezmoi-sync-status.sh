#!/bin/bash

# Chezmoi Sync Status and Information Tool
# Provides comprehensive status information about the sync system

set -euo pipefail

# Load configuration if available
CONFIG_FILE="${HOME}/code/private/chezmoi-sync/config/chezmoi-sync.conf"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Configuration with defaults
CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"
DEV_MODE_FILE="${DEV_MODE_FILE:-$HOME/.config/chezmoi-sync/.dev-mode}"
LAST_SYNC_FILE="${LAST_SYNC_FILE:-$HOME/.local/share/chezmoi/.last-sync}"
LOG_DIR="${LOG_DIR:-$HOME/Library/Logs/chezmoi}"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "$1"
}

# Status icons
icon_check="✅"
icon_warning="⚠️"
icon_error="❌"
icon_info="ℹ️"
icon_sync="🔄"
icon_dev="🔧"
icon_machine="🖥️"

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get git status in a directory
get_git_status() {
    local dir="$1"
    if [ -d "$dir" ]; then
        pushd "$dir" >/dev/null
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local branch=$(git branch --show-current 2>/dev/null || echo "detached")
            local status=""
            
            if ! git diff --quiet 2>/dev/null; then
                status="${status}M"
            fi
            
            if ! git diff --cached --quiet 2>/dev/null; then
                status="${status}S"
            fi
            
            local ahead_behind
            ahead_behind=$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "0	0")
            local ahead=$(echo "$ahead_behind" | cut -f1)
            local behind=$(echo "$ahead_behind" | cut -f2)
            
            if [ "$ahead" -gt 0 ]; then
                status="${status}A${ahead}"
            fi
            
            if [ "$behind" -gt 0 ]; then
                status="${status}B${behind}"
            fi
            
            echo "${branch}${status:+ (${status})}"
        else
            echo "not a git repository"
        fi
        popd >/dev/null
    else
        echo "directory not found"
    fi
}

# Detect machine type using OS-level tools
detect_machine_type() {
    local machine_id_file="$HOME/.config/chezmoi-sync/machine-id"
    
    # Config override takes priority
    [ -n "${MACHINE_ID:-}" ] && echo "$MACHINE_ID" && return
    
    # If we have a saved ID, use it (survives hostname changes)
    if [ -f "$machine_id_file" ]; then
        cat "$machine_id_file"
        return
    fi
    
    # Otherwise detect and save it
    local machine_id=""
    
    # macOS: Use LocalHostName (clean, stable)
    if [ "$(uname)" = "Darwin" ]; then
        machine_id=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
    else
        # Linux/other: Just use hostname
        machine_id=$(hostname -s)
    fi
    
    # Clean it for git branches
    machine_id=$(echo "$machine_id" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
    
    # Save for next time
    mkdir -p "$(dirname "$machine_id_file")"
    echo "$machine_id" > "$machine_id_file"
    
    echo "$machine_id"
}

# Check LaunchAgent status
check_launch_agent() {
    local agent_name="$1"
    local plist_file="$LAUNCH_AGENTS_DIR/$agent_name.plist"
    
    if [ -f "$plist_file" ]; then
        if launchctl list | grep -q "$agent_name"; then
            echo -e "${GREEN}${icon_check} Running${NC}"
        else
            echo -e "${RED}${icon_error} Stopped${NC}"
        fi
    else
        echo -e "${YELLOW}${icon_warning} Not installed${NC}"
    fi
}

# Get last sync time
get_last_sync() {
    if [ -f "$LAST_SYNC_FILE" ]; then
        local last_sync=$(cat "$LAST_SYNC_FILE" 2>/dev/null || echo "")
        if [ -n "$last_sync" ]; then
            echo "$last_sync"
        else
            echo "unknown"
        fi
    else
        echo "never"
    fi
}

# Check development mode status
check_dev_mode() {
    if [ -f "$DEV_MODE_FILE" ]; then
        local dev_start=$(cat "$DEV_MODE_FILE" 2>/dev/null || echo "0")
        local duration=$(( $(date +%s) - dev_start ))
        local hours=$(( duration / 3600 ))
        local minutes=$(( (duration % 3600) / 60 ))
        
        echo -e "${YELLOW}${icon_dev} ACTIVE (${hours}h ${minutes}m)${NC}"
        return 0
    else
        echo -e "${GREEN}${icon_check} INACTIVE${NC}"
        return 1
    fi
}

# Show system overview
show_overview() {
    local machine_type=$(detect_machine_type)
    local auto_sync_branch="auto-sync/${machine_type}"
    
    log "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    log "${BLUE}║                ${CYAN}Chezmoi Sync System Status${BLUE}                ║${NC}"
    log "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    log ""
    
    # Machine Information
    log "${PURPLE}${icon_machine} Machine Information:${NC}"
    log "   Type: ${machine_type}"
    log "   Target Branch: ${auto_sync_branch}"
    log "   Hostname: $(hostname)"
    log ""
    
    # Development Mode
    log "${PURPLE}${icon_dev} Development Mode:${NC}"
    local dev_mode_output=$(check_dev_mode)
    log "   Status: $dev_mode_output"
    log ""
    
    # LaunchAgents Status
    log "${PURPLE}${icon_sync} LaunchAgents Status:${NC}"
    log -n "   AutoPush: "
    check_launch_agent "com.chezmoi.autopush"
    log -n "   AutoPull: "
    check_launch_agent "com.chezmoi.autopull"
    log ""
    
    # Last Sync Information
    log "${PURPLE}${icon_info} Sync Information:${NC}"
    local last_sync=$(get_last_sync)
    log "   Last Sync: $last_sync"
    log ""
    
    # Repository Status
    log "${PURPLE}${icon_info} Repository Status:${NC}"
    if [ -d "$CHEZMOI_SOURCE_DIR" ]; then
        local git_status=$(get_git_status "$CHEZMOI_SOURCE_DIR")
        log "   Chezmoi Source: ${git_status}"
    else
        log "   Chezmoi Source: ${RED}${icon_error} Directory not found${NC}"
    fi
    
    # Development Repository
    if [ -d "$HOME/code/private/dotfiles" ]; then
        local dev_git_status=$(get_git_status "$HOME/code/private/dotfiles")
        log "   Dev Repository: ${dev_git_status}"
    fi
    log ""
}

# Show detailed information
show_detailed() {
    show_overview
    
    log "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    log "${BLUE}║                    ${CYAN}Detailed Information${BLUE}                   ║${NC}"
    log "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    log ""
    
    # Configuration
    log "${PURPLE}${icon_info} Configuration:${NC}"
    log "   Config File: ${CONFIG_FILE}"
    log "   Chezmoi Source: ${CHEZMOI_SOURCE_DIR}"
    log "   Log Directory: ${LOG_DIR}"
    log "   Dev Mode File: ${DEV_MODE_FILE}"
    log ""
    
    # Recent Log Entries
    log "${PURPLE}${icon_info} Recent Activity:${NC}"
    if [ -f "${LOG_DIR}/push.log" ]; then
        log "   Last Push Events:"
        tail -3 "${LOG_DIR}/push.log" 2>/dev/null | sed 's/^/     /' || log "     No recent push events"
    fi
    
    if [ -f "${LOG_DIR}/pull.log" ]; then
        log "   Last Pull Events:"
        tail -3 "${LOG_DIR}/pull.log" 2>/dev/null | sed 's/^/     /' || log "     No recent pull events"
    fi
    log ""
    
    # File Counts and Status
    if command_exists chezmoi && [ -d "$CHEZMOI_SOURCE_DIR" ]; then
        log "${PURPLE}${icon_info} Chezmoi Status:${NC}"
        pushd "$CHEZMOI_SOURCE_DIR" >/dev/null
        
        # Count different file types
        local managed_files=$(find . -name "dot_*" -o -name "run_*" -o -name "*.tmpl" | wc -l | tr -d ' ')
        local template_files=$(find . -name "*.tmpl" | wc -l | tr -d ' ')
        
        log "   Managed Files: ${managed_files}"
        log "   Template Files: ${template_files}"
        
        # Check for changes
        if command_exists chezmoi; then
            local changes=$(chezmoi status 2>/dev/null | wc -l | tr -d ' ')
            if [ "$changes" -gt 0 ]; then
                log "   ${YELLOW}Pending Changes: ${changes}${NC}"
            else
                log "   ${GREEN}No Pending Changes${NC}"
            fi
        fi
        
        popd >/dev/null
        log ""
    fi
}

# Show logs
show_logs() {
    local log_type="${1:-all}"
    
    log "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    log "${BLUE}║                        ${CYAN}Log Viewer${BLUE}                        ║${NC}"
    log "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    log ""
    
    case "$log_type" in
        "push")
            if [ -f "${LOG_DIR}/push.log" ]; then
                log "${PURPLE}Push Log (last 20 lines):${NC}"
                tail -20 "${LOG_DIR}/push.log"
            else
                log "${YELLOW}${icon_warning} Push log not found${NC}"
            fi
            ;;
        "pull")
            if [ -f "${LOG_DIR}/pull.log" ]; then
                log "${PURPLE}Pull Log (last 20 lines):${NC}"
                tail -20 "${LOG_DIR}/pull.log"
            else
                log "${YELLOW}${icon_warning} Pull log not found${NC}"
            fi
            ;;
        "dev")
            if [ -f "${LOG_DIR}/dev-mode.log" ]; then
                log "${PURPLE}Development Mode Log (last 20 lines):${NC}"
                tail -20 "${LOG_DIR}/dev-mode.log"
            else
                log "${YELLOW}${icon_warning} Development mode log not found${NC}"
            fi
            ;;
        "all"|*)
            show_logs "push"
            log ""
            show_logs "pull"
            log ""
            show_logs "dev"
            ;;
    esac
}

# Show usage information
show_usage() {
    cat << EOF
Chezmoi Sync Status and Information Tool

USAGE:
    $(basename "$0") [COMMAND] [OPTIONS]

COMMANDS:
    status, st          Show system overview (default)
    detailed, info      Show detailed system information  
    logs [TYPE]         Show log entries (push, pull, dev, all)
    machine             Show machine detection information
    config              Show configuration values
    help, -h            Show this help message

EXAMPLES:
    $(basename "$0")                    # Quick status overview
    $(basename "$0") detailed           # Detailed system info
    $(basename "$0") logs push          # Show push logs only
    $(basename "$0") machine            # Machine detection info
    $(basename "$0") config             # Configuration dump

DESCRIPTION:
    This tool provides comprehensive status information about the
    chezmoi sync system, including LaunchAgent status, repository
    state, development mode, and recent activity logs.
EOF
}

# Show machine information
show_machine() {
    local machine_type=$(detect_machine_type)
    
    log "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    log "${BLUE}║                   ${CYAN}Machine Information${BLUE}                   ║${NC}"
    log "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    log ""
    
    log "${PURPLE}${icon_machine} Detection Results:${NC}"
    log "   Detected Type: ${machine_type}"
    log "   Auto-sync Branch: auto-sync/${machine_type}"
    log "   Hostname: $(hostname)"
    log "   Short Hostname: $(hostname -s 2>/dev/null || hostname)"
    log ""
    
    # Chezmoi data if available
    if command_exists chezmoi && [ -d "$CHEZMOI_SOURCE_DIR" ]; then
        log "${PURPLE}${icon_info} Chezmoi Data:${NC}"
        chezmoi data --format=yaml 2>/dev/null | head -20 | sed 's/^/   /' || log "   Unable to retrieve chezmoi data"
    else
        log "${YELLOW}${icon_warning} Chezmoi not available or source directory missing${NC}"
    fi
}

# Show configuration
show_config() {
    log "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    log "${BLUE}║                      ${CYAN}Configuration${BLUE}                       ║${NC}"
    log "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    log ""
    
    if [ -f "$CONFIG_FILE" ]; then
        log "${PURPLE}${icon_info} Configuration File: ${CONFIG_FILE}${NC}"
        log ""
        cat "$CONFIG_FILE" | grep -E "^[A-Z_].*=" | sed 's/^/   /'
    else
        log "${YELLOW}${icon_warning} Configuration file not found: ${CONFIG_FILE}${NC}"
        log ""
        log "${PURPLE}Using default values:${NC}"
        log "   CHEZMOI_SOURCE_DIR=$CHEZMOI_SOURCE_DIR"
        log "   DEV_MODE_FILE=$DEV_MODE_FILE"
        log "   LOG_DIR=$LOG_DIR"
    fi
}

# Main command handling
main() {
    local command="${1:-status}"
    
    case "$command" in
        "status"|"st"|"")
            show_overview
            ;;
        "detailed"|"info"|"detail")
            show_detailed
            ;;
        "logs"|"log")
            local log_type="${2:-all}"
            show_logs "$log_type"
            ;;
        "machine"|"detect")
            show_machine
            ;;
        "config"|"conf")
            show_config
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log "${RED}${icon_error} Unknown command: $command${NC}"
            log ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"