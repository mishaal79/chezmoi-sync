#!/bin/bash

# Chezmoi Development Mode Toggle
# Controls auto-sync behavior during active development

set -euo pipefail

# Load configuration if available
CONFIG_FILE="${HOME}/code/private/chezmoi-sync/config/chezmoi-sync.conf"
if [ -f "$CONFIG_FILE" ]; then
	# shellcheck source=/dev/null
	source "$CONFIG_FILE"
fi

# Configuration with defaults
DEV_MODE_FILE="${DEV_MODE_FILE:-$HOME/.config/chezmoi-sync/.dev-mode}"
LOG_DIR="${LOG_DIR:-$HOME/Library/Logs/chezmoi}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/dev-mode.log}"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
AUTOPUSH_PLIST="$LAUNCH_AGENTS_DIR/com.chezmoi.autopush.plist"
AUTOPULL_PLIST="$LAUNCH_AGENTS_DIR/com.chezmoi.autopull.plist"

# Create necessary directories
mkdir -p "$(dirname "$DEV_MODE_FILE")" "$LOG_DIR"

# Logging function
log() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Send notification
notify() {
	local message="$1"
	local title="${2:-Chezmoi Dev Mode}"
	if command -v osascript >/dev/null 2>&1; then
		osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
	fi
}

# Check current development mode status
check_status() {
	if [ -f "$DEV_MODE_FILE" ]; then
		local dev_start=$(cat "$DEV_MODE_FILE" 2>/dev/null || echo "0")
		local duration=$(($(date +%s) - dev_start))
		local hours=$((duration / 3600))
		local minutes=$(((duration % 3600) / 60))

		echo "🔧 Development mode is ACTIVE (${hours}h ${minutes}m)"

		# Check LaunchAgent status
		if launchctl list | grep -q "com.chezmoi.autopush"; then
			echo "⚠️  AutoPush agent is still RUNNING (should be stopped)"
		else
			echo "✅ AutoPush agent is STOPPED"
		fi

		if launchctl list | grep -q "com.chezmoi.autopull"; then
			echo "⚠️  AutoPull agent is still RUNNING (should be stopped)"
		else
			echo "✅ AutoPull agent is STOPPED"
		fi
	else
		echo "⚡ Development mode is INACTIVE"

		# Check LaunchAgent status
		if launchctl list | grep -q "com.chezmoi.autopush"; then
			echo "✅ AutoPush agent is RUNNING"
		else
			echo "⚠️  AutoPush agent is STOPPED (should be running)"
		fi

		if launchctl list | grep -q "com.chezmoi.autopull"; then
			echo "✅ AutoPull agent is RUNNING"
		else
			echo "⚠️  AutoPull agent is STOPPED (should be running)"
		fi
	fi
}

# Enable development mode
enable_dev_mode() {
	local reason="${1:-Manual activation}"

	log "Enabling development mode: $reason"

	# Create dev mode file with current timestamp
	echo "$(date +%s)" >"$DEV_MODE_FILE"

	# Stop LaunchAgents if they exist and are loaded
	if [ -f "$AUTOPUSH_PLIST" ]; then
		if launchctl list | grep -q "com.chezmoi.autopush"; then
			log "Stopping AutoPush LaunchAgent"
			launchctl unload "$AUTOPUSH_PLIST" 2>/dev/null || true
		fi
	fi

	if [ -f "$AUTOPULL_PLIST" ]; then
		if launchctl list | grep -q "com.chezmoi.autopull"; then
			log "Stopping AutoPull LaunchAgent"
			launchctl unload "$AUTOPULL_PLIST" 2>/dev/null || true
		fi
	fi

	log "✅ Development mode enabled"
	notify "Development mode enabled - auto-sync disabled" "Chezmoi Dev Mode"

	echo "🔧 Development mode ENABLED"
	echo "📝 Reason: $reason"
	echo ""
	echo "Auto-sync is now DISABLED. Your changes will not be automatically pushed."
	echo "Use 'chezmoi-sync-dev-mode disable' when you're done with development."
}

# Disable development mode
disable_dev_mode() {
	if [ ! -f "$DEV_MODE_FILE" ]; then
		echo "⚡ Development mode is already INACTIVE"
		return 0
	fi

	log "Disabling development mode"

	# Remove dev mode file
	rm -f "$DEV_MODE_FILE"

	# Restart LaunchAgents if they exist
	if [ -f "$AUTOPUSH_PLIST" ]; then
		if ! launchctl list | grep -q "com.chezmoi.autopush"; then
			log "Starting AutoPush LaunchAgent"
			launchctl load "$AUTOPUSH_PLIST" 2>/dev/null || true
		fi
	fi

	if [ -f "$AUTOPULL_PLIST" ]; then
		if ! launchctl list | grep -q "com.chezmoi.autopull"; then
			log "Starting AutoPull LaunchAgent"
			launchctl load "$AUTOPULL_PLIST" 2>/dev/null || true
		fi
	fi

	log "✅ Development mode disabled"
	notify "Development mode disabled - auto-sync restored" "Chezmoi Dev Mode"

	echo "⚡ Development mode DISABLED"
	echo "🔄 Auto-sync has been restored"
	echo ""
	echo "Your changes will now be automatically synchronized."
}

# Auto-enable development mode with timeout
auto_enable() {
	local timeout_hours="${1:-4}"
	local reason="${2:-Auto-detected development activity}"

	enable_dev_mode "$reason"

	# Schedule automatic disable
	local disable_time=$(($(date +%s) + timeout_hours * 3600))

	echo "⏰ Auto-disable scheduled in ${timeout_hours} hours"
	echo "📅 Will re-enable auto-sync at: $(date -r $disable_time '+%Y-%m-%d %H:%M:%S')"

	# Create a simple at job for auto-disable
	if command -v at >/dev/null 2>&1; then
		echo "$(realpath "$0") disable" | at "now + ${timeout_hours} hours" 2>/dev/null || {
			log "WARNING: Could not schedule auto-disable (at command failed)"
		}
	else
		log "WARNING: 'at' command not available - manual disable required"
	fi
}

# Show usage information
show_usage() {
	cat <<EOF
Chezmoi Development Mode Control

USAGE:
    $(basename "$0") COMMAND [OPTIONS]

COMMANDS:
    status              Show current development mode status
    enable [reason]     Enable development mode (disable auto-sync)
    disable             Disable development mode (restore auto-sync)
    auto [hours]        Auto-enable with timeout (default: 4 hours)
    toggle              Toggle between enabled/disabled states
    
EXAMPLES:
    $(basename "$0") enable "Working on zsh config"
    $(basename "$0") auto 2
    $(basename "$0") status
    $(basename "$0") disable

DESCRIPTION:
    Development mode temporarily disables chezmoi auto-sync to prevent
    conflicts during active configuration development. 
    
    When enabled:
    - AutoPush and AutoPull LaunchAgents are stopped
    - Manual 'chezmoi apply' is required for changes
    - .dev-mode marker file tracks activation time
    
    When disabled:
    - Auto-sync LaunchAgents are restored
    - Normal 5-minute sync cycle resumes
    - Changes are automatically synchronized

FILES:
    $DEV_MODE_FILE
    $LOG_FILE
    $AUTOPUSH_PLIST
    $AUTOPULL_PLIST
EOF
}

# Toggle development mode
toggle_dev_mode() {
	if [ -f "$DEV_MODE_FILE" ]; then
		disable_dev_mode
	else
		enable_dev_mode "Manual toggle activation"
	fi
}

# Main command handling
main() {
	local command="${1:-status}"

	case "$command" in
	"status" | "st")
		check_status
		;;
	"enable" | "on")
		local reason="${2:-Manual activation}"
		enable_dev_mode "$reason"
		;;
	"disable" | "off")
		disable_dev_mode
		;;
	"auto")
		local hours="${2:-4}"
		local reason="${3:-Auto-detected development activity}"
		auto_enable "$hours" "$reason"
		;;
	"toggle" | "t")
		toggle_dev_mode
		;;
	"help" | "-h" | "--help")
		show_usage
		;;
	*)
		echo "❌ Unknown command: $command"
		echo ""
		show_usage
		exit 1
		;;
	esac
}

# Handle signals gracefully
trap 'log "Received termination signal"; exit 130' INT TERM

# Run main function
main "$@"
