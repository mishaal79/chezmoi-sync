#!/bin/bash

# Chezmoi Auto-Pull Script with Enhanced Verification and Safety
# This script safely pulls from main branch and applies changes

set -euo pipefail

# Load configuration if available
CONFIG_FILE="${HOME}/code/private/chezmoi-sync/config/chezmoi-sync.conf"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Configuration with defaults
CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"
LOCK_FILE="${LOCK_FILE:-/tmp/chezmoi-pull.lock}"
LOG_DIR="${LOG_DIR:-$HOME/Library/Logs/chezmoi}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/pull.log}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.local/share/chezmoi-backups}"
GIT_MAIN_BRANCH="${GIT_MAIN_BRANCH:-main}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"
REQUIRE_VERIFICATION="${REQUIRE_VERIFICATION:-true}"

# Create necessary directories
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Send notification
notify() {
    local message="$1"
    local title="${2:-Chezmoi Pull}"
    if command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
    fi
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
        log "Another pull operation is running. Waiting... ($count/${timeout})"
        sleep 1
        count=$((count + 1))
    done
    
    if [ -f "$LOCK_FILE" ]; then
        log "ERROR: Another pull operation is running and not responding. Exiting."
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

# Pre-pull validation
validate_pre_pull() {
    log "Running pre-pull validation..."
    
    # Check if chezmoi source directory exists
    if [ ! -d "$CHEZMOI_SOURCE_DIR" ]; then
        log "ERROR: Chezmoi source directory does not exist: $CHEZMOI_SOURCE_DIR"
        return 1
    fi
    
    # Check if it's a git repository
    if ! git -C "$CHEZMOI_SOURCE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log "ERROR: Not a git repository: $CHEZMOI_SOURCE_DIR"
        return 1
    fi
    
    # Check chezmoi command availability
    if ! command -v chezmoi >/dev/null 2>&1; then
        log "WARNING: chezmoi command not available"
        return 0  # Not fatal, but should be noted
    fi
    
    log "✅ Pre-pull validation passed"
    return 0
}

# Post-pull validation
validate_post_pull() {
    if [ "$REQUIRE_VERIFICATION" != "true" ]; then
        log "Verification disabled, skipping post-pull validation"
        return 0
    fi
    
    log "Running post-pull validation..."
    
    # Verify chezmoi templates and data
    if command -v chezmoi >/dev/null 2>&1; then
        if chezmoi verify --source "$CHEZMOI_SOURCE_DIR" 2>&1 | tee -a "$LOG_FILE"; then
            log "✅ Chezmoi verification passed"
        else
            log "❌ Chezmoi verification failed"
            return 1
        fi
        
        # Test apply dry-run
        if chezmoi apply --dry-run --source "$CHEZMOI_SOURCE_DIR" >/dev/null 2>&1; then
            log "✅ Dry-run application test passed"
        else
            log "❌ Dry-run application test failed"
            return 1
        fi
    else
        log "⚠️ chezmoi command not available, skipping verification"
    fi
    
    return 0
}

# Check if there are any conflicts with local changes
check_merge_conflicts() {
    local remote_commit="$1"
    local current_commit
    current_commit=$(git rev-parse HEAD)
    
    # Use git merge-tree to detect potential conflicts
    if git merge-tree "$current_commit" "$remote_commit" "$remote_commit" | grep -q "^<<<<<<< "; then
        log "⚠️ Potential merge conflicts detected"
        return 1
    fi
    
    return 0
}

# Safe git pull with conflict detection
safe_git_pull() {
    local branch="$GIT_MAIN_BRANCH"
    log "Performing safe pull from $branch..."
    
    # Fetch first to see what we're dealing with
    if ! retry_with_backoff "git fetch origin $branch"; then
        log "ERROR: Failed to fetch from $branch"
        return 1
    fi
    
    # Get commit information
    local local_commit remote_commit
    local_commit=$(git rev-parse HEAD)
    remote_commit=$(git rev-parse "origin/$branch")
    
    if [ "$local_commit" = "$remote_commit" ]; then
        log "Already up to date"
        return 0
    fi
    
    log "Local: $local_commit"
    log "Remote: $remote_commit"
    
    # Check for potential conflicts before pulling
    if ! check_merge_conflicts "$remote_commit"; then
        log "⚠️ Potential conflicts detected - using rebase strategy"
    fi
    
    # Pull with rebase and auto-stash for safety
    if ! retry_with_backoff "git pull --rebase --autostash origin $branch"; then
        log "ERROR: Failed to pull with rebase from $branch"
        return 1
    fi
    
    log "✅ Successfully pulled from $branch"
    return 0
}

# Apply changes with rollback capability
apply_changes_safely() {
    local backup_commit
    backup_commit=$(git rev-parse HEAD)
    
    log "Applying changes with chezmoi..."
    
    # First, test with dry-run
    if command -v chezmoi >/dev/null 2>&1; then
        if ! chezmoi apply --dry-run --source "$CHEZMOI_SOURCE_DIR" >/dev/null; then
            log "❌ Dry-run failed - changes would break configuration"
            return 1
        fi
        
        # Apply for real
        if chezmoi apply --source "$CHEZMOI_SOURCE_DIR" 2>&1 | tee -a "$LOG_FILE"; then
            log "✅ Changes applied successfully"
            return 0
        else
            log "❌ Failed to apply changes"
            
            # Attempt rollback
            log "Attempting rollback to $backup_commit"
            if git reset --hard "$backup_commit"; then
                log "✅ Successfully rolled back"
                notify "Pull failed, rolled back to previous state" "Chezmoi Pull Error"
            else
                log "❌ Rollback failed - manual intervention required"
                notify "Pull failed and rollback failed - manual intervention needed" "Chezmoi Pull Critical"
            fi
            return 1
        fi
    else
        log "⚠️ chezmoi command not available, skipping apply"
        return 0
    fi
}

# Main pull operation
main() {
    log "Starting enhanced chezmoi pull operation"
    
    # Acquire lock
    acquire_lock
    
    # Pre-pull validation
    if ! validate_pre_pull; then
        log "ERROR: Pre-pull validation failed"
        notify "Pre-pull validation failed" "Chezmoi Pull Error"
        exit 1
    fi
    
    # Change to chezmoi source directory
    if ! cd "$CHEZMOI_SOURCE_DIR"; then
        log "ERROR: Cannot access chezmoi source directory: $CHEZMOI_SOURCE_DIR"
        notify "Cannot access chezmoi directory" "Chezmoi Pull Error"
        exit 1
    fi
    
    # Create backup before any changes
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    log "Creating backup: $backup_name"
    if ! cp -r "$CHEZMOI_SOURCE_DIR" "$BACKUP_DIR/$backup_name"; then
        log "WARNING: Failed to create backup"
    fi
    
    # Store initial state for potential rollback
    local initial_commit
    initial_commit=$(git rev-parse HEAD 2>/dev/null || echo "")
    
    # Check if there are local changes to stash
    local stashed=false
    if ! git diff --quiet || ! git diff --cached --quiet; then
        log "Local changes detected, stashing..."
        if git stash push -m "Auto-stash before pull - $(date '+%Y-%m-%d %H:%M:%S')"; then
            stashed=true
            log "✅ Local changes stashed"
        else
            log "❌ Failed to stash local changes"
            notify "Failed to stash local changes" "Chezmoi Pull Error"
            exit 1
        fi
    fi
    
    # Perform safe git pull
    if ! safe_git_pull; then
        log "ERROR: Git pull failed"
        
        # Restore stashed changes if any
        if [ "$stashed" = true ]; then
            log "Restoring stashed changes..."
            git stash pop 2>/dev/null || log "WARNING: Failed to restore stashed changes"
        fi
        
        notify "Failed to pull changes from remote" "Chezmoi Pull Error"
        exit 1
    fi
    
    # Post-pull validation
    if ! validate_post_pull; then
        log "ERROR: Post-pull validation failed"
        
        # Rollback if possible
        if [ -n "$initial_commit" ]; then
            log "Rolling back to initial state: $initial_commit"
            git reset --hard "$initial_commit"
        fi
        
        # Restore stashed changes
        if [ "$stashed" = true ]; then
            git stash pop 2>/dev/null || log "WARNING: Failed to restore stashed changes"
        fi
        
        notify "Post-pull validation failed, rolled back" "Chezmoi Pull Error"
        exit 1
    fi
    
    # Apply changes if validation passed
    if ! apply_changes_safely; then
        log "ERROR: Failed to apply changes safely"
        
        # Restore stashed changes
        if [ "$stashed" = true ]; then
            git stash pop 2>/dev/null || log "WARNING: Failed to restore stashed changes"
        fi
        
        exit 1
    fi
    
    # Restore stashed local changes
    if [ "$stashed" = true ]; then
        log "Restoring stashed local changes..."
        if git stash pop; then
            log "✅ Local changes restored successfully"
        else
            log "⚠️ Conflicts detected when restoring local changes"
            notify "Stash conflicts detected - manual resolution may be needed" "Chezmoi Pull Warning"
        fi
    fi
    
    # Clean up old backups (keep last 10)
    log "Cleaning up old backups..."
    find "$BACKUP_DIR" -type d -name "backup-*" | sort -r | tail -n +11 | xargs -I {} rm -rf {} 2>/dev/null || true
    
    log "✅ Pull operation completed successfully"
    notify "Dotfiles updated from main branch" "Chezmoi Pull"
}

# Handle signals gracefully
trap 'log "Received termination signal, cleaning up..."; rm -f "$LOCK_FILE"; exit 130' INT TERM

# Run main function
main "$@"