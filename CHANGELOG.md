# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Comprehensive Testing Infrastructure**: Complete isolation testing framework
  - Alpine Linux Docker containers for minimal, fast testing
  - GitHub Actions CI/CD pipeline with matrix testing strategy
  - Mock environments for mac-mini, macbook-air, and default machine types
  - Test fixtures with machine-specific configurations and templates
  - Conflict resolution test scenarios for comprehensive coverage
  - Complete isolation from production environment (zero pollution guarantee)
- **Test Runner**: Automated test execution with Docker and GitHub Actions
- **Enhanced .gitignore**: Comprehensive coverage for Docker, testing, and development environments

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

[Unreleased]: https://github.com/mishaal79/chezmoi-sync/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/mishaal79/chezmoi-sync/releases/tag/v0.0.1
[Unreleased]: https://github.com/mishaal79/chezmoi-sync/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/mishaal79/chezmoi-sync/releases/tag/v0.0.1
