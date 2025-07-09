# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chezmoi Auto-Sync is a macOS-only tool that provides automated bidirectional synchronization for chezmoi dotfiles using a dual LaunchAgent architecture. The system safely handles git operations with comprehensive conflict resolution, backup management, and real-time file monitoring.

## Architecture

### Core Components

**Dual LaunchAgent System:**
- **Push Agent** (`com.chezmoi.autopush`): Monitors `~/.local/share/chezmoi/` using fswatch, triggers immediate git push operations when files change
- **Pull Agent** (`com.chezmoi.autopull`): Runs every 5 minutes via StartInterval to fetch remote changes and apply them via `chezmoi apply`

**Safety Layer:**
- Lock files (`/tmp/chezmoi-push.lock`, `/tmp/chezmoi-pull.lock`) prevent concurrent operations
- Automatic backups to `~/.local/share/chezmoi-backups/` before destructive operations
- Conflict detection checks for diverged branches before git operations
- Comprehensive logging to `~/Library/Logs/chezmoi/` for debugging

**Management Interface:**
- `chezmoi-sync` command provides status, restart, logs, version checking, and update functionality
- `chezmoi-resolve` interactive conflict resolution tool with backup/restore capabilities
- Configuration through `config/chezmoi-sync.conf` for intervals, paths, and behavior settings

## Essential Development Commands

### Testing and Validation
```bash
# Run all validation checks (mirrors CI)
bash -n scripts/*.sh install.sh uninstall.sh release.sh  # Syntax validation
plutil -lint plists/*.plist                             # macOS plist validation
brew install shellcheck && shellcheck scripts/*.sh *.sh # Shell script linting

# Test installer prerequisites (requires chezmoi setup)
mkdir -p ~/.local/share/chezmoi && cd ~/.local/share/chezmoi
git init && git config user.email "test@example.com" && git config user.name "Test"
echo "test" > test.txt && git add test.txt && git commit -m "Initial commit"
```

### CI/CD Pipeline
```bash
# GitHub Actions workflows automatically run on:
# - Push/PR to main: Full CI suite (scripts, security, linting)
# - Git tags (v*): Release workflow with asset creation

# Local release process (maintainers only)
./release.sh patch                    # 0.0.1 → 0.0.2
./release.sh minor                    # 0.1.0 → 0.2.0  
./release.sh major                    # 1.0.0 → 2.0.0
./release.sh 1.2.3                    # Set specific version
./release.sh patch --dry-run          # Preview changes
```

### Manual Script Execution
```bash
# Test core functionality manually
~/scripts/chezmoi-push.sh             # Manual push operation
~/scripts/chezmoi-pull.sh             # Manual pull operation
~/scripts/chezmoi-resolve.sh          # Interactive conflict resolution

# Service management
launchctl list | grep chezmoi         # Check LaunchAgent status
launchctl load ~/Library/LaunchAgents/com.chezmoi.autopush.plist
launchctl unload ~/Library/LaunchAgents/com.chezmoi.autopush.plist
```

## Key Technical Implementation Details

### LaunchAgent Integration
- **Push Agent**: Uses fswatch with null-delimited output (`-0`) to monitor file changes
- **Pull Agent**: StartInterval-based execution every 300 seconds
- Both agents run with `KeepAlive=true` and `LowPriorityIO=true` for system efficiency
- Environment variables explicitly set for `PATH` and `HOME` to ensure proper script execution

### Git Operation Safety
Scripts implement a multi-layered safety approach:
1. **Pre-operation checks**: Verify git repository state, check for uncommitted changes
2. **Branch analysis**: Compare LOCAL/REMOTE/BASE commits to detect divergence
3. **Backup creation**: Timestamped backups before any destructive operations
4. **Conflict handling**: Automatic stashing, manual conflict resolution prompts
5. **Rollback capability**: Restore from backups if operations fail

### Configuration Management
The `config/chezmoi-sync.conf` file uses shell variable format and controls:
- Sync intervals (`PULL_INTERVAL`, `PUSH_THROTTLE`)
- Directory paths (can be customized for different setups)
- Git branch/remote configuration
- Backup retention (`MAX_BACKUPS`)
- Logging levels and notification preferences

### Error Handling Patterns
All scripts follow consistent error handling:
- `set -euo pipefail` for strict error checking
- Lock file management with `trap` cleanup
- Logging with timestamps via `log()` function
- macOS notifications via `osascript` for user feedback
- Graceful degradation (continue on non-critical failures)

## Release and Version Management

### Semantic Versioning Workflow
- VERSION file contains current version (e.g., `0.0.1`)
- CHANGELOG.md follows Keep a Changelog format
- Git tags use `v` prefix (e.g., `v0.0.1`)
- 0.0.x versions automatically marked as prerelease in GitHub

### Release Process
1. `release.sh` updates VERSION and CHANGELOG.md
2. Creates git commit with conventional format
3. Tags commit with version
4. Pushes to trigger GitHub Actions release workflow
5. Workflow validates, tests, creates release assets (tar.gz, zip, checksums)

### GitHub Actions Release Pipeline
- Validates semver tag format and VERSION file consistency
- Runs full test suite with error handling for dependency installation
- Creates release archives with proper file structure
- Extracts changelog section for release notes
- Uploads assets and creates GitHub release

## macOS-Specific Considerations

### LaunchAgent Management
- Plist files use absolute paths (templated during installation)
- `launchctl` commands require proper error handling
- Service restart requires unload/load cycle with delay
- Log files use macOS-standard locations (`~/Library/Logs/`)

### File System Watching
- fswatch configured for optimal performance with event filtering
- Throttling prevents excessive git operations from rapid file changes
- Null-delimited output (`-0`) handles paths with spaces
- Recursive monitoring (`-r`) covers entire chezmoi source directory

### Security and Permissions
- Scripts run with user privileges (no sudo required)
- Lock files prevent race conditions between agents
- Desktop notifications provide user feedback without interruption
- Git operations use existing user SSH keys/credentials

## Common Debugging Scenarios

### Service Not Starting
Check LaunchAgent status, logs in `~/Library/Logs/chezmoi/`, verify plist syntax with `plutil -lint`

### Git Authentication Issues
Scripts expect SSH authentication; HTTPS with tokens may fail in background processes

### Conflict Resolution Loops
Interactive resolver provides step-by-step conflict resolution with backup/restore options

### Version Mismatch
Installer fetches latest release info from GitHub API; fallback to main branch if API fails