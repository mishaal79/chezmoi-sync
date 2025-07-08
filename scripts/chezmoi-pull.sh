#!/bin/bash

# Chezmoi Auto-Pull Script with Safe Conflict Handling
# This script safely pulls remote changes and applies them with chezmoi update

set -euo pipefail

# Configuration
CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"
LOCK_FILE="/tmp/chezmoi-pull.lock"
LOG_DIR="$HOME/Library/Logs/chezmoi"
LOG_FILE="$LOG_DIR/pull.log"
BACKUP_DIR="$HOME/.local/share/chezmoi-backups"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Send notification
notify() {
    local message="$1"
    local title="${2:-Chezmoi Pull}"
    osascript -e "display notification \"$message\" with title \"$title\""
}

# Check if another instance is running
if [ -f "$LOCK_FILE" ]; then
    log "Another pull operation is already running. Exiting."
    exit 1
fi

# Create lock file
trap 'rm -f "$LOCK_FILE"' EXIT
echo $$ > "$LOCK_FILE"

# Change to chezmoi source directory
cd "$CHEZMOI_SOURCE_DIR"

log "Starting chezmoi pull operation"

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log "ERROR: Not in a git repository"
    notify "Error: Not in a git repository" "Chezmoi Pull Error"
    exit 1
fi

# Create backup before making changes
BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
log "Creating backup: $BACKUP_NAME"
cp -r "$CHEZMOI_SOURCE_DIR" "$BACKUP_DIR/$BACKUP_NAME"

# Check for uncommitted local changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    log "Local changes detected. Stashing them..."
    git stash push -m "Auto-stash before pull - $(date '+%Y-%m-%d %H:%M:%S')"
    STASHED=true
else
    STASHED=false
fi

# Fetch remote changes
log "Fetching from remote repository"
if ! git fetch origin; then
    log "ERROR: Failed to fetch from remote"
    notify "Failed to fetch from remote" "Chezmoi Pull Error"
    exit 1
fi

# Check if remote has changes
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")

if [ -z "$REMOTE" ]; then
    log "No remote tracking branch found"
    if [ "$STASHED" = true ]; then
        log "Restoring stashed changes"
        git stash pop
    fi
    exit 0
fi

if [ "$LOCAL" = "$REMOTE" ]; then
    log "Already up to date"
    if [ "$STASHED" = true ]; then
        log "Restoring stashed changes"
        git stash pop
    fi
    exit 0
fi

# Pull remote changes
log "Pulling changes from remote"
if ! git pull origin main; then
    log "ERROR: Failed to pull from remote - conflicts detected"
    notify "Pull failed - conflicts detected. Manual intervention required." "Chezmoi Pull Error"
    
    # Reset to previous state
    log "Resetting to previous state"
    git reset --hard "$LOCAL"
    
    if [ "$STASHED" = true ]; then
        log "Restoring stashed changes"
        git stash pop
    fi
    
    exit 1
fi

log "Successfully pulled from remote"

# Apply changes with chezmoi
log "Applying changes with chezmoi"
if ! chezmoi apply; then
    log "ERROR: Failed to apply changes with chezmoi"
    notify "Failed to apply changes with chezmoi" "Chezmoi Pull Error"
    
    # Reset to previous state
    log "Resetting to previous state"
    git reset --hard "$LOCAL"
    
    if [ "$STASHED" = true ]; then
        log "Restoring stashed changes"
        git stash pop
    fi
    
    exit 1
fi

log "Successfully applied changes"

# Restore stashed changes if any
if [ "$STASHED" = true ]; then
    log "Restoring stashed changes"
    if ! git stash pop; then
        log "WARNING: Failed to restore stashed changes - conflicts may exist"
        notify "Stash conflicts detected - manual resolution needed" "Chezmoi Pull Warning"
    fi
fi

log "Pull operation completed successfully"
notify "Dotfiles updated successfully" "Chezmoi Pull"

# Clean up old backups (keep last 10)
log "Cleaning up old backups"
ls -t "$BACKUP_DIR" | tail -n +11 | xargs -I {} rm -rf "$BACKUP_DIR/{}" 2>/dev/null || true

log "Pull operation completed successfully"