#!/bin/bash

# Chezmoi Auto-Push Script with Machine-Aware Branching
# This script safely commits and pushes changes to machine-specific branches

set -euo pipefail

# Load configuration if available
CONFIG_FILE="${HOME}/code/private/chezmoi-sync/config/chezmoi-sync.conf"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Configuration with defaults
CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"
LOCK_FILE="${LOCK_FILE:-/tmp/chezmoi-push.lock}"
LOG_DIR="${LOG_DIR:-$HOME/Library/Logs/chezmoi}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/push.log}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.local/share/chezmoi-backups}"
DEV_MODE_FILE="${DEV_MODE_FILE:-$HOME/.config/chezmoi-sync/.dev-mode}"
GIT_MAIN_BRANCH="${GIT_MAIN_BRANCH:-main}"
GIT_AUTO_SYNC_PREFIX="${GIT_AUTO_SYNC_PREFIX:-auto-sync}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"
REQUIRE_VERIFICATION="${REQUIRE_VERIFICATION:-true}"

# Create necessary directories
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$(dirname "$DEV_MODE_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Send notification
notify() {
    local message="$1"
    local title="${2:-Chezmoi Push}"
    if command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
    fi
}

# Check development mode
check_dev_mode() {
    if [ -f "$DEV_MODE_FILE" ]; then
        local dev_start=$(cat "$DEV_MODE_FILE" 2>/dev/null || echo "0")
        local duration=$(( $(date +%s) - dev_start ))
        local hours=$(( duration / 3600 ))
        local minutes=$(( (duration % 3600) / 60 ))
        
        log "Development mode is active (${hours}h ${minutes}m) - auto-push disabled"
        notify "Development mode active - auto-push skipped" "Chezmoi Push"
        exit 0
    fi
}

# Detect machine type from chezmoi data
detect_machine_type() {
    local machine_type
    
    if command -v chezmoi >/dev/null 2>&1; then
        machine_type=$(chezmoi data --format=json 2>/dev/null | jq -r '.chezmoi.hostname // "unknown"' 2>/dev/null || echo "unknown")
    else
        machine_type=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "unknown")
    fi
    
    # Clean machine type for branch name (only alphanumeric and hyphens)
    echo "$machine_type" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g'
}

# Check if changes are significant (not just temporary/trivial files)
is_significant_change() {
    local changed_files
    changed_files=$(git diff --name-only 2>/dev/null || echo "")
    
    # If no changed files, check staged files
    if [ -z "$changed_files" ]; then
        changed_files=$(git diff --cached --name-only 2>/dev/null || echo "")
    fi
    
    # If still no files, no significant changes
    if [ -z "$changed_files" ]; then
        return 1
    fi
    
    # Check against ignore patterns
    while IFS= read -r file; do
        if [[ -z "$file" ]]; then
            continue
        fi
        
        # Skip trivial patterns
        if [[ "$file" =~ \.(tmp|swp|test|log|bak)$ ]] || \
           [[ "$file" == ".DS_Store" ]] || \
           [[ "$file" =~ \.(history|cache)$ ]] || \
           [[ "$file" =~ \.local$ ]]; then
            continue
        fi
        
        # This is a significant change
        return 0
    done <<< "$changed_files"
    
    # Only insignificant changes found
    return 1
}

# Acquire lock with timeout
acquire_lock() {
    local timeout=30
    local count=0
    
    while [ -f "$LOCK_FILE" ] && [ $count -lt $timeout ]; do
        if ! kill -0 "$(cat "$LOCK_FILE" 2>/dev/null)" 2>/dev/null; then
            # Stale lock file
            rm -f "$LOCK_FILE"
            break
        fi
        log "Another push operation is running. Waiting... ($count/${timeout})"
        sleep 1
        count=$((count + 1))
    done
    
    if [ -f "$LOCK_FILE" ]; then
        log "ERROR: Another push operation is running and not responding. Exiting."
        exit 1
    fi
    
    # Create lock file with PID
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
}

# Retry function with exponential backoff
retry_with_backoff() {
    local cmd="$1"
    local max_attempts="$MAX_RETRIES"
    local delay="$RETRY_DELAY"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Attempt $attempt of $max_attempts: $cmd"
        
        if eval "$cmd"; then
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log "ERROR: All attempts failed for: $cmd"
            return 1
        fi
        
        log "Command failed, retrying in ${delay}s..."
        sleep $delay
        attempt=$((attempt + 1))
        delay=$((delay * 2))  # Exponential backoff
    done
}

# Validate changes with chezmoi verify
validate_changes() {
    if [ "$REQUIRE_VERIFICATION" != "true" ]; then
        return 0
    fi
    
    log "Validating changes with chezmoi verify..."
    
    if command -v chezmoi >/dev/null 2>&1; then
        if chezmoi verify --source "$CHEZMOI_SOURCE_DIR" 2>&1 | tee -a "$LOG_FILE"; then
            log "✅ Chezmoi verification passed"
            return 0
        else
            log "❌ Chezmoi verification failed"
            return 1
        fi
    else
        log "⚠️ chezmoi command not available, skipping verification"
        return 0
    fi
}

# Main sync logic
main() {
    log "Starting machine-aware chezmoi push operation"
    
    # Check development mode first
    check_dev_mode
    
    # Acquire lock
    acquire_lock
    
    # Change to chezmoi source directory
    if ! cd "$CHEZMOI_SOURCE_DIR"; then
        log "ERROR: Cannot access chezmoi source directory: $CHEZMOI_SOURCE_DIR"
        notify "Cannot access chezmoi directory" "Chezmoi Push Error"
        exit 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log "ERROR: Not in a git repository"
        notify "Not in a git repository" "Chezmoi Push Error"
        exit 1
    fi
    
    # Check for changes
    if git diff --quiet && git diff --cached --quiet; then
        log "No changes to commit"
        exit 0
    fi
    
    # Check if changes are significant
    if ! is_significant_change; then
        log "Only trivial changes detected - skipping push"
        exit 0
    fi
    
    # Detect machine type
    local machine_type
    machine_type=$(detect_machine_type)
    local auto_sync_branch="${GIT_AUTO_SYNC_PREFIX}/${machine_type}"
    log "Detected machine type: $machine_type"
    log "Target branch: $auto_sync_branch"
    
    # Create backup
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    log "Creating backup: $backup_name"
    cp -r "$CHEZMOI_SOURCE_DIR" "$BACKUP_DIR/$backup_name"
    
    # Stash any unstaged changes
    local stashed=false
    if ! git diff --quiet; then
        log "Stashing unstaged changes"
        git stash push -m "Auto-stash before sync - $(date '+%Y-%m-%d %H:%M:%S')"
        stashed=true
    fi
    
    # Pull latest from main branch first (single source of truth)
    log "Pulling latest changes from $GIT_MAIN_BRANCH..."
    if ! retry_with_backoff "git pull --rebase --autostash origin $GIT_MAIN_BRANCH"; then
        log "ERROR: Failed to pull from $GIT_MAIN_BRANCH after retries"
        notify "Failed to pull from main branch" "Chezmoi Push Error"
        [ "$stashed" = true ] && git stash pop 2>/dev/null || true
        exit 1
    fi
    
    # Restore stashed changes
    if [ "$stashed" = true ]; then
        log "Restoring stashed changes"
        if ! git stash pop; then
            log "WARNING: Conflicts detected when restoring stashed changes"
            notify "Stash conflicts detected - manual resolution needed" "Chezmoi Push Warning"
            # Continue with the process anyway
        fi
    fi
    
    # Validate changes
    if ! validate_changes; then
        log "ERROR: Validation failed - aborting push"
        notify "Validation failed - aborting sync" "Chezmoi Push Error"
        exit 1
    fi
    
    # Stage all changes
    log "Staging changes"
    git add .
    
    # Check if there are staged changes after adding
    if git diff --cached --quiet; then
        log "No staged changes after git add"
        exit 0
    fi
    
    # Commit changes
    local commit_msg="Auto-sync from ${machine_type} - $(date '+%Y-%m-%d %H:%M:%S')"
    log "Creating commit: $commit_msg"
    
    if ! git commit -m "$commit_msg"; then
        log "ERROR: Failed to create commit"
        notify "Failed to create commit" "Chezmoi Push Error"
        exit 1
    fi
    
    # Push to machine-specific branch
    log "Pushing to branch: $auto_sync_branch"
    
    if ! retry_with_backoff "git push origin HEAD:$auto_sync_branch"; then
        log "ERROR: Failed to push to $auto_sync_branch after retries"
        notify "Failed to push to remote branch" "Chezmoi Push Error"
        
        # Attempt to reset to previous state
        log "Attempting to reset to previous state"
        git reset --hard HEAD~1 2>/dev/null || true
        exit 1
    fi
    
    log "✅ Successfully pushed to $auto_sync_branch"
    notify "Changes synced to $auto_sync_branch" "Chezmoi Push"
    
    # Record successful sync
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > ~/.local/share/chezmoi/.last-sync 2>/dev/null || true
    
    # Clean up old backups (keep last 10)
    log "Cleaning up old backups"
    find "$BACKUP_DIR" -type d -name "backup-*" | sort -r | tail -n +11 | xargs -I {} rm -rf {} 2>/dev/null || true
    
    log "Push operation completed successfully"
}

# Handle signals gracefully
trap 'log "Received termination signal, cleaning up..."; rm -f "$LOCK_FILE"; exit 130' INT TERM

# Run main function
main "$@"