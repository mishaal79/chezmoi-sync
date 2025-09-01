# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2025-09-01

### Added
- **Homebrew Distribution**: Professional package management and distribution
  - Custom Homebrew tap (mishaal79/chezmoi-sync)
  - Automatic formula updates via GitHub Actions
  - Dual-service architecture with proper LaunchAgent management
  - Seamless migration from manual installation
  - `brew install chezmoi-sync` for easy installation
- **Machine-Aware Auto-Sync Architecture**: Revolutionary architecture for conflict-free multi-machine synchronization
  - Machine-specific branching (auto-sync/mac-mini, auto-sync/macbook-air)
  - Zero cognitive load system with automatic machine detection
  - Single-repository workflow replacing dual-repository complexity
  - CI-based conflict resolution with Claude Code AI assistance
  - Development mode toggle to prevent conflicts during feature work
- **OS-Agnostic Machine Detection**: Reliable machine identification independent of chezmoi
  - Uses macOS scutil LocalHostName for stable, clean identification
  - Fallback to hostname -s on Linux/other systems
  - Persistent machine ID file survives hostname changes
  - Config override support with MACHINE_ID variable
- **Enhanced Scripts with Machine Intelligence**:
  - **chezmoi-push.sh**: Complete rewrite with machine detection, auto-sync branches, development mode check, significance filtering, and retry logic
  - **chezmoi-pull.sh**: Enhanced with pre/post validation, safe pull with conflict detection, rollback capability, and dry-run testing
  - **chezmoi-sync-dev-mode.sh**: Development mode toggle for disabling auto-sync during feature work, manages LaunchAgents
  - **chezmoi-sync-status.sh**: Comprehensive status tool with system overview, detailed info, logs viewer, and configuration display
- **Comprehensive Configuration System**: Machine-aware settings with validation options, retry configuration, and comprehensive defaults
- **GitHub Actions CI Workflows**:
  - **auto-sync-handler.yml**: Handles auto-sync/* branch pushes, validates changes, creates PRs, enables auto-merge for safe changes
  - **conflict-resolver.yml**: AI-assisted conflict resolution with Claude Code subagent, falls back to manual review
- **Safety and Reliability Features**:
  - Pre/post validation with chezmoi verify
  - Smart change detection filtering trivial files
  - Retry logic with exponential backoff
  - Comprehensive logging and status reporting
  - Rollback capability for failed operations
- **Comprehensive Testing Infrastructure**: Complete isolation testing framework
  - Alpine Linux Docker containers for minimal, fast testing
  - GitHub Actions CI/CD pipeline with matrix testing strategy
  - Mock environments for mac-mini, macbook-air, and default machine types
  - Test fixtures with machine-specific configurations and templates
  - Conflict resolution test scenarios for comprehensive coverage
  - Complete isolation from production environment (zero pollution guarantee)
- **Test Runner**: Automated test execution with Docker and GitHub Actions
- **Enhanced .gitignore**: Comprehensive coverage for Docker, testing, and development environments

### Changed
- **Architecture**: Moved from dual-repository model to single-repository workflow with machine-specific branches
- **Machine Detection**: Replaced chezmoi-dependent detection with OS-native tools for reliability and independence
- **Branching Strategy**: Each machine now pushes to its own auto-sync/[machine-name] branch instead of main
- **Conflict Resolution**: Implemented CI-based automated resolution with AI assistance instead of manual intervention

### Technical Details
- **Machine Detection**: Uses `scutil --get LocalHostName` on macOS, `hostname -s` fallback
- **Branch Pattern**: `auto-sync/mishals-mac-mini`, `auto-sync/mishals-macbook-air`
- **Machine ID File**: `~/.config/chezmoi-sync/machine-id` for persistence
- **Development Mode**: `~/.config/chezmoi-sync/.dev-mode` marker file
- **Configuration Override**: `MACHINE_ID="custom-name"` in config file

## [1.0.0] - 2025-08-27

### Added
- **Machine-Aware Sync System**: Complete rewrite with machine-specific branching
- **OS-Agnostic Machine Detection**: Uses native OS tools instead of chezmoi data
- **Development Mode**: Toggle to disable sync during feature development
- **Comprehensive Status Tool**: Machine info, service status, and logs viewer

## [0.0.1] - 2025-07-09

### Added
- Release 0.0.1


## [0.0.1] - 2025-07-09 (Beta)

### Added
- **Beta release** - Initial beta version for early adopters
- Initial release of chezmoi auto-sync
- Real-time file watching with fswatch for automatic push
- Periodic pull every 5 minutes from remote repository
- Safe conflict handling with backup and rollback capabilities
- Interactive conflict resolution tool (`chezmoi-resolve`)
- One-line installer for easy setup across machines
- Comprehensive logging system with rotation
- Desktop notifications for important events
- Lock file mechanism to prevent concurrent operations
- Management script (`chezmoi-sync`) for service control
- Clean uninstaller with optional data retention
- LaunchAgent integration for macOS service management
- Automatic backup system with configurable retention
- SSH and HTTPS git authentication support
- Comprehensive documentation and troubleshooting guide
- CI/CD pipeline with GitHub Actions
- Semantic versioning with automated releases
- Version checking and update functionality
- Release management script for maintainers

### Security
- No hardcoded credentials or secrets
- User-level permissions only (no sudo required)
- Secure lock file handling
- Input validation and sanitization
- Safe error handling with graceful degradation

### Technical Details
- **Push Agent**: Monitors `~/.local/share/chezmoi/` using fswatch
- **Pull Agent**: Runs every 5 minutes via LaunchAgent StartInterval
- **Backup Location**: `~/.local/share/chezmoi-backups/`
- **Log Location**: `~/Library/Logs/chezmoi/`
- **Configuration**: `~/code/private/chezmoi-sync/config/chezmoi-sync.conf`

### Scripts
- `chezmoi-push.sh`: Safe push with conflict handling
- `chezmoi-pull.sh`: Safe pull with conflict handling  
- `chezmoi-resolve.sh`: Interactive conflict resolution
- `chezmoi-sync`: Service management and status monitoring
- `install.sh`: One-line installer with prerequisite checking
- `uninstall.sh`: Complete removal with optional data retention
- `release.sh`: Release management script for maintainers

### Requirements
- macOS 14+ (tested)
- chezmoi installed and initialized
- Git repository configured for chezmoi source
- fswatch (auto-installed if missing)
- SSH keys configured for GitHub (recommended)

[Unreleased]: https://github.com/mishaal79/chezmoi-sync/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/mishaal79/chezmoi-sync/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/mishaal79/chezmoi-sync/compare/v0.0.1...v1.0.0
[0.0.1]: https://github.com/mishaal79/chezmoi-sync/releases/tag/v0.0.1
