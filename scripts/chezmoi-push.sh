#!/bin/bash

# Chezmoi Auto-Push Script with Safe Conflict Handling
# This script safely commits and pushes changes to the chezmoi git repository

set -euo pipefail

# Configuration
CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"
LOCK_FILE="/tmp/chezmoi-push.lock"
LOG_DIR="$HOME/Library/Logs/chezmoi"
LOG_FILE="$LOG_DIR/push.log"
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
    local title="${2:-Chezmoi Push}"
    osascript -e "display notification \"$message\" with title \"$title\""
}

# Check if another instance is running
if [ -f "$LOCK_FILE" ]; then
    log "Another push operation is already running. Exiting."
    exit 1
fi

# Create lock file
trap 'rm -f "$LOCK_FILE"' EXIT
echo $$ > "$LOCK_FILE"

# Change to chezmoi source directory
cd "$CHEZMOI_SOURCE_DIR"

log "Starting chezmoi push operation"

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log "ERROR: Not in a git repository"
    notify "Error: Not in a git repository" "Chezmoi Push Error"
    exit 1
fi

# Check git status
if git diff --quiet && git diff --cached --quiet; then
    log "No changes to commit"
    exit 0
fi

# Create backup before making changes
BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
log "Creating backup: $BACKUP_NAME"
cp -r "$CHEZMOI_SOURCE_DIR" "$BACKUP_DIR/$BACKUP_NAME"

# Check if we're behind remote
git fetch origin

LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")
BASE=$(git merge-base @ @{u} 2>/dev/null || echo "")

if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ] && [ "$LOCAL" = "$BASE" ]; then
    log "Local branch is behind remote. Pulling first..."
    
    # Try to pull
    if ! git pull origin main; then
        log "ERROR: Failed to pull from remote. Manual intervention required."
        notify "Pull failed - conflicts detected" "Chezmoi Push Error"
        exit 1
    fi
    
    log "Successfully pulled from remote"
elif [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ] && [ "$REMOTE" = "$BASE" ]; then
    log "Local branch is ahead of remote. Proceeding with push..."
elif [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ] && [ "$LOCAL" != "$BASE" ] && [ "$REMOTE" != "$BASE" ]; then
    log "ERROR: Branches have diverged. Manual intervention required."
    notify "Branches have diverged - manual merge needed" "Chezmoi Push Error"
    exit 1
fi

# Add all changes
log "Adding changes to git"
git add .

# Check if there are staged changes
if git diff --cached --quiet; then
    log "No staged changes after git add"
    exit 0
fi

# Commit changes
COMMIT_MSG="Auto-sync dotfiles - $(date '+%Y-%m-%d %H:%M:%S')"
log "Committing changes: $COMMIT_MSG"

if ! git commit -m "$COMMIT_MSG"; then
    log "ERROR: Failed to commit changes"
    notify "Failed to commit changes" "Chezmoi Push Error"
    exit 1
fi

# Push changes
log "Pushing to remote repository"
if ! git push origin main; then
    log "ERROR: Failed to push to remote"
    notify "Failed to push to remote" "Chezmoi Push Error"
    
    # Try to reset to previous state
    log "Attempting to reset to previous state"
    git reset --hard HEAD~1
    
    exit 1
fi

log "Successfully pushed changes to remote"
notify "Dotfiles synced successfully" "Chezmoi Push"

# Clean up old backups (keep last 10)
log "Cleaning up old backups"
ls -t "$BACKUP_DIR" | tail -n +11 | xargs -I {} rm -rf "$BACKUP_DIR/{}" 2>/dev/null || true

log "Push operation completed successfully"