# Chezmoi Auto-Sync

🚀 **Automatic synchronization for your chezmoi dotfiles with safe conflict handling**

This project provides a complete auto-sync solution for chezmoi dotfiles on macOS, featuring:
- **Real-time push** when files change (using fswatch)
- **Periodic pull** every 5 minutes from remote
- **Safe conflict resolution** with backup and rollback capabilities
- **One-line installation** for easy setup across machines
- **Comprehensive logging** and desktop notifications

## Features

### 🔄 Auto-Sync Capabilities
- **Push**: Automatically commits and pushes changes when dotfiles are modified
- **Pull**: Periodically checks for remote changes and applies them
- **Throttling**: Prevents excessive git operations with built-in rate limiting
- **Lock files**: Prevents concurrent operations that could cause conflicts

### 🛡️ Safety Features
- **Conflict detection**: Identifies and handles git merge conflicts safely
- **Backup system**: Creates backups before any destructive operations
- **Rollback capability**: Easy restoration to previous states
- **Validation**: Verifies operations before applying changes

### 🔧 Management Tools
- **Interactive resolver**: GUI-like conflict resolution tool
- **Status monitoring**: Real-time service status and log viewing
- **Easy restart**: Simple service management commands
- **Clean uninstall**: Complete removal with optional data retention

## Quick Start

### Installation via Homebrew (Recommended)

```bash
# Add the tap and install
brew tap mishaal79/chezmoi-sync
brew install chezmoi-sync

# Start the services
brew services start chezmoi-sync       # Push service
brew services start chezmoi-sync-pull   # Pull service
```

### Manual Installation

```bash
curl -fsSL https://raw.githubusercontent.com/mishaal79/chezmoi-sync/main/install.sh | bash
```

### Prerequisites

- macOS (tested on macOS 14+)
- [chezmoi](https://github.com/twpayne/chezmoi) installed and initialized
- Git repository configured for your chezmoi source directory
- [fswatch](https://github.com/emcrisostomo/fswatch) (auto-installed if missing)

### Verification

After installation, verify everything is working:

```bash
chezmoi-sync status
```

## Usage

### Management Commands

```bash
# Check service status and recent logs
chezmoi-sync status

# Restart sync services
chezmoi-sync restart

# View detailed logs
chezmoi-sync logs

# Complete uninstall
chezmoi-sync uninstall
```

### Conflict Resolution

When conflicts occur, use the interactive resolver:

```bash
chezmoi-resolve
```

The resolver provides options to:
- View detailed diffs
- Create backups
- Reset to known good state
- Manually resolve conflicts
- Apply changes safely

## How It Works

### Architecture

The system consists of two LaunchAgents:

1. **Push Agent** (`com.chezmoi.autopush`)
   - Monitors `~/.local/share/chezmoi/` using fswatch
   - Triggers push script when files change
   - Runs continuously with throttling

2. **Pull Agent** (`com.chezmoi.autopull`)
   - Runs every 5 minutes via StartInterval
   - Checks for remote changes
   - Applies updates using `chezmoi apply`

### File Structure

```
~/code/private/chezmoi-sync/
├── scripts/
│   ├── chezmoi-push.sh      # Safe push with conflict handling
│   ├── chezmoi-pull.sh      # Safe pull with conflict handling
│   └── chezmoi-resolve.sh   # Interactive conflict resolution
├── plists/
│   ├── com.chezmoi.autopush.plist
│   └── com.chezmoi.autopull.plist
├── config/
│   └── chezmoi-sync.conf    # Configuration file
├── install.sh               # One-line installer
├── uninstall.sh            # Clean removal script
└── README.md               # This file
```

### Safety Mechanisms

1. **Lock Files**: Prevent concurrent operations
2. **Backups**: Automatic backups before destructive changes
3. **Conflict Detection**: Checks for diverged branches
4. **Validation**: Verifies git operations before applying
5. **Logging**: Comprehensive logging for troubleshooting
6. **Notifications**: Desktop alerts for important events

## Configuration

### Default Settings

- **Pull Interval**: 5 minutes
- **Push Throttle**: 5 seconds
- **Max Backups**: 10 (older backups auto-deleted)
- **Log Location**: `~/Library/Logs/chezmoi/`
- **Backup Location**: `~/.local/share/chezmoi-backups/`

### Customization

Edit `~/code/private/chezmoi-sync/config/chezmoi-sync.conf` to modify:
- Sync intervals
- Backup retention
- Log levels
- Notification preferences

## Troubleshooting

### Common Issues

**Services not starting:**
```bash
# Check LaunchAgent status
launchctl list | grep chezmoi

# Reload services
chezmoi-sync restart
```

**Conflicts not resolving:**
```bash
# Use interactive resolver
chezmoi-resolve

# Or reset to known good state
chezmoi-resolve --reset
```

**Missing fswatch:**
```bash
# Install manually
brew install fswatch
```

### Log Locations

- **Push logs**: `~/Library/Logs/chezmoi/push.log`
- **Pull logs**: `~/Library/Logs/chezmoi/pull.log`
- **System logs**: `~/Library/Logs/chezmoi/autopush.err` and `autopull.err`

### Manual Operations

If auto-sync fails, you can run scripts manually:

```bash
# Manual push
~/scripts/chezmoi-push.sh

# Manual pull
~/scripts/chezmoi-pull.sh

# Interactive resolution
~/scripts/chezmoi-resolve.sh
```

## Advanced Usage

### Custom Git Branch

If you use a different branch than `main`, update the scripts:

```bash
# Edit push script
sed -i 's/main/your-branch/g' ~/scripts/chezmoi-push.sh

# Edit pull script
sed -i 's/main/your-branch/g' ~/scripts/chezmoi-pull.sh
```

### Multiple Machines

To install on additional machines:

1. Ensure chezmoi is set up and synced
2. Run the one-line installer
3. The system will automatically use your existing dotfiles

### Backup Management

Backups are stored in `~/.local/share/chezmoi-backups/`:

```bash
# List backups
ls -la ~/.local/share/chezmoi-backups/

# Restore from backup
cp -r ~/.local/share/chezmoi-backups/backup-YYYYMMDD-HHMMSS ~/.local/share/chezmoi
```

## Security Considerations

- Scripts run with user privileges (no sudo required)
- Git operations use your existing SSH keys/credentials
- Backups are stored locally and not transmitted
- Lock files prevent race conditions
- All operations are logged for audit trails

## Uninstallation

To completely remove chezmoi auto-sync:

```bash
# Standard uninstall
chezmoi-sync uninstall

# Keep logs and backups
~/code/private/chezmoi-sync/uninstall.sh --keep-logs --keep-backups

# Force uninstall without prompts
~/code/private/chezmoi-sync/uninstall.sh --force
```

## Contributing

This project is tailored for personal use but contributions are welcome:

1. Fork the repository
2. Create a feature branch
3. Test on macOS
4. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

For issues or questions:
- Check the troubleshooting section
- Review logs in `~/Library/Logs/chezmoi/`
- Open an issue on GitHub

---

**Note**: This tool is designed for macOS and requires chezmoi to be properly initialized with a git repository. It's recommended to test in a non-production environment first.