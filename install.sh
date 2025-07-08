#!/bin/bash

# Chezmoi Auto-Sync One-Line Installer
# This script installs and configures chezmoi auto-sync functionality

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="https://raw.githubusercontent.com/mishaal79/chezmoi-sync/main"
INSTALL_DIR="$HOME/code/private/chezmoi-sync"
SCRIPTS_DIR="$HOME/scripts"
PLIST_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/chezmoi"
BACKUP_DIR="$HOME/.local/share/chezmoi-backups"

# Output functions
print_red() { echo -e "${RED}$1${NC}"; }
print_green() { echo -e "${GREEN}$1${NC}"; }
print_yellow() { echo -e "${YELLOW}$1${NC}"; }
print_blue() { echo -e "${BLUE}$1${NC}"; }

# Error handling
error_exit() {
    print_red "ERROR: $1"
    exit 1
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Send notification
notify() {
    local message="$1"
    local title="${2:-Chezmoi Sync Install}"
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
}

# Check prerequisites
check_prerequisites() {
    print_blue "Checking prerequisites..."
    
    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        error_exit "This installer is only for macOS"
    fi
    
    # Check for required commands
    if ! command_exists chezmoi; then
        error_exit "chezmoi is not installed. Please install it first: brew install chezmoi"
    fi
    
    if ! command_exists fswatch; then
        print_yellow "fswatch not found. Installing via Homebrew..."
        if command_exists brew; then
            brew install fswatch
        else
            error_exit "Homebrew not found. Please install fswatch manually"
        fi
    fi
    
    if ! command_exists git; then
        error_exit "git is not installed"
    fi
    
    # Check if chezmoi is initialized
    if [[ ! -d "$HOME/.local/share/chezmoi" ]]; then
        error_exit "chezmoi is not initialized. Please run 'chezmoi init' first"
    fi
    
    # Check if chezmoi has a git repository
    if ! git -C "$HOME/.local/share/chezmoi" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        error_exit "chezmoi source directory is not a git repository"
    fi
    
    print_green "Prerequisites check passed"
}

# Create directories
create_directories() {
    print_blue "Creating directories..."
    
    mkdir -p "$INSTALL_DIR"/{scripts,plists,config}
    mkdir -p "$SCRIPTS_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    
    print_green "Directories created"
}

# Download and install files
install_files() {
    print_blue "Installing files..."
    
    # If running from local directory, copy files
    if [[ -f "./scripts/chezmoi-push.sh" ]]; then
        print_blue "Installing from local directory..."
        cp -r scripts/* "$INSTALL_DIR/scripts/"
        cp -r plists/* "$INSTALL_DIR/plists/"
        cp -r config/* "$INSTALL_DIR/config/"
    else
        # Download files from GitHub
        print_blue "Downloading files from GitHub..."
        
        # Download scripts
        curl -fsSL "$GITHUB_REPO/scripts/chezmoi-push.sh" -o "$INSTALL_DIR/scripts/chezmoi-push.sh"
        curl -fsSL "$GITHUB_REPO/scripts/chezmoi-pull.sh" -o "$INSTALL_DIR/scripts/chezmoi-pull.sh"
        curl -fsSL "$GITHUB_REPO/scripts/chezmoi-resolve.sh" -o "$INSTALL_DIR/scripts/chezmoi-resolve.sh"
        
        # Download plists
        curl -fsSL "$GITHUB_REPO/plists/com.chezmoi.autopush.plist" -o "$INSTALL_DIR/plists/com.chezmoi.autopush.plist"
        curl -fsSL "$GITHUB_REPO/plists/com.chezmoi.autopull.plist" -o "$INSTALL_DIR/plists/com.chezmoi.autopull.plist"
        
        # Download config
        curl -fsSL "$GITHUB_REPO/config/chezmoi-sync.conf" -o "$INSTALL_DIR/config/chezmoi-sync.conf"
    fi
    
    # Copy scripts to user scripts directory
    cp "$INSTALL_DIR/scripts/"* "$SCRIPTS_DIR/"
    
    # Make scripts executable
    chmod +x "$SCRIPTS_DIR/chezmoi-push.sh"
    chmod +x "$SCRIPTS_DIR/chezmoi-pull.sh"
    chmod +x "$SCRIPTS_DIR/chezmoi-resolve.sh"
    
    print_green "Files installed"
}

# Install LaunchAgents
install_launchagents() {
    print_blue "Installing LaunchAgents..."
    
    # Update plist files with correct user path
    sed "s|/Users/mishal|$HOME|g" "$INSTALL_DIR/plists/com.chezmoi.autopush.plist" > "$PLIST_DIR/com.chezmoi.autopush.plist"
    sed "s|/Users/mishal|$HOME|g" "$INSTALL_DIR/plists/com.chezmoi.autopull.plist" > "$PLIST_DIR/com.chezmoi.autopull.plist"
    
    # Unload existing agents if they exist
    launchctl unload "$PLIST_DIR/com.chezmoi.autopush.plist" 2>/dev/null || true
    launchctl unload "$PLIST_DIR/com.chezmoi.autopull.plist" 2>/dev/null || true
    
    # Load new agents
    launchctl load "$PLIST_DIR/com.chezmoi.autopush.plist"
    launchctl load "$PLIST_DIR/com.chezmoi.autopull.plist"
    
    print_green "LaunchAgents installed and loaded"
}

# Create management script
create_management_script() {
    print_blue "Creating management script..."
    
    cat > "$SCRIPTS_DIR/chezmoi-sync" << 'EOF'
#!/bin/bash

# Chezmoi Sync Management Script

PLIST_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/chezmoi"

case "$1" in
    status)
        echo "Chezmoi Sync Status:"
        echo "==================="
        echo "Push Agent: $(launchctl list | grep com.chezmoi.autopush || echo 'Not running')"
        echo "Pull Agent: $(launchctl list | grep com.chezmoi.autopull || echo 'Not running')"
        echo
        echo "Recent Push Logs:"
        tail -5 "$LOG_DIR/push.log" 2>/dev/null || echo "No push logs found"
        echo
        echo "Recent Pull Logs:"
        tail -5 "$LOG_DIR/pull.log" 2>/dev/null || echo "No pull logs found"
        ;;
    restart)
        echo "Restarting chezmoi sync services..."
        launchctl unload "$PLIST_DIR/com.chezmoi.autopush.plist" 2>/dev/null || true
        launchctl unload "$PLIST_DIR/com.chezmoi.autopull.plist" 2>/dev/null || true
        sleep 2
        launchctl load "$PLIST_DIR/com.chezmoi.autopush.plist"
        launchctl load "$PLIST_DIR/com.chezmoi.autopull.plist"
        echo "Services restarted"
        ;;
    logs)
        echo "=== Push Logs ==="
        tail -20 "$LOG_DIR/push.log" 2>/dev/null || echo "No push logs found"
        echo
        echo "=== Pull Logs ==="
        tail -20 "$LOG_DIR/pull.log" 2>/dev/null || echo "No pull logs found"
        echo
        echo "=== System Logs ==="
        tail -10 "$LOG_DIR/autopush.err" 2>/dev/null || echo "No push error logs found"
        tail -10 "$LOG_DIR/autopull.err" 2>/dev/null || echo "No pull error logs found"
        ;;
    uninstall)
        echo "Uninstalling chezmoi sync..."
        launchctl unload "$PLIST_DIR/com.chezmoi.autopush.plist" 2>/dev/null || true
        launchctl unload "$PLIST_DIR/com.chezmoi.autopull.plist" 2>/dev/null || true
        rm -f "$PLIST_DIR/com.chezmoi.autopush.plist"
        rm -f "$PLIST_DIR/com.chezmoi.autopull.plist"
        rm -f "$HOME/scripts/chezmoi-push.sh"
        rm -f "$HOME/scripts/chezmoi-pull.sh"
        rm -f "$HOME/scripts/chezmoi-resolve.sh"
        rm -f "$HOME/scripts/chezmoi-sync"
        echo "Chezmoi sync uninstalled"
        ;;
    *)
        echo "Usage: $0 {status|restart|logs|uninstall}"
        echo
        echo "Commands:"
        echo "  status     - Show service status and recent logs"
        echo "  restart    - Restart sync services"
        echo "  logs       - Show detailed logs"
        echo "  uninstall  - Remove chezmoi sync completely"
        ;;
esac
EOF
    
    chmod +x "$SCRIPTS_DIR/chezmoi-sync"
    print_green "Management script created"
}

# Verify installation
verify_installation() {
    print_blue "Verifying installation..."
    
    # Check if scripts exist and are executable
    for script in chezmoi-push.sh chezmoi-pull.sh chezmoi-resolve.sh chezmoi-sync; do
        if [[ ! -x "$SCRIPTS_DIR/$script" ]]; then
            error_exit "Script $script is not executable"
        fi
    done
    
    # Check if LaunchAgents are loaded
    if ! launchctl list | grep -q com.chezmoi.autopush; then
        error_exit "Push agent is not loaded"
    fi
    
    if ! launchctl list | grep -q com.chezmoi.autopull; then
        error_exit "Pull agent is not loaded"
    fi
    
    print_green "Installation verified successfully"
}

# Main installation function
main() {
    print_blue "🚀 Chezmoi Auto-Sync Installer"
    print_blue "=============================="
    echo
    
    check_prerequisites
    create_directories
    install_files
    install_launchagents
    create_management_script
    verify_installation
    
    echo
    print_green "✅ Installation completed successfully!"
    echo
    print_blue "Usage:"
    print_blue "  chezmoi-sync status    - Check service status"
    print_blue "  chezmoi-sync restart   - Restart services"
    print_blue "  chezmoi-sync logs      - View logs"
    print_blue "  chezmoi-sync uninstall - Remove completely"
    echo
    print_blue "  chezmoi-resolve        - Interactive conflict resolution"
    echo
    print_yellow "Your dotfiles will now automatically sync!"
    print_yellow "Push: Immediately when files change"
    print_yellow "Pull: Every 5 minutes from remote"
    echo
    
    notify "Chezmoi auto-sync installed successfully!"
}

# Run main function
main "$@"