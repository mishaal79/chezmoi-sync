#!/bin/bash

# Chezmoi Sync Release Script
# This script helps maintainers create new releases following semver

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output functions
print_red() { echo -e "${RED}$1${NC}"; }
print_green() { echo -e "${GREEN}$1${NC}"; }
print_yellow() { echo -e "${YELLOW}$1${NC}"; }
print_blue() { echo -e "${BLUE}$1${NC}"; }

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$REPO_ROOT/VERSION"
CHANGELOG_FILE="$REPO_ROOT/CHANGELOG.md"

# Show help
show_help() {
	cat <<EOF
Chezmoi Sync Release Script

Usage: $0 [version_type] [options]

Version Types:
    major      - Increment major version (x.0.0)
    minor      - Increment minor version (x.y.0)
    patch      - Increment patch version (x.y.z)
    [x.y.z]    - Set specific version

Options:
    -h, --help     Show this help message
    -d, --dry-run  Show what would be done without making changes
    -f, --force    Skip confirmation prompts

Examples:
    $0 patch                    # Increment patch version
    $0 minor                    # Increment minor version
    $0 1.2.3                    # Set specific version
    $0 patch --dry-run          # Show what would happen
    $0 major --force            # Release major version without prompts

The script will:
1. Update VERSION file
2. Update CHANGELOG.md with new section
3. Commit changes
4. Create and push git tag
5. Trigger GitHub Actions release workflow
EOF
}

# Get current version
get_current_version() {
	if [[ -f "$VERSION_FILE" ]]; then
		cat "$VERSION_FILE"
	else
		echo "0.0.0"
	fi
}

# Validate version format
validate_version() {
	local version="$1"
	if ! echo "$version" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null; then
		print_red "ERROR: Version must follow semver format (x.y.z)"
		exit 1
	fi
}

# Increment version
increment_version() {
	local current="$1"
	local type="$2"

	IFS='.' read -r major minor patch <<<"$current"

	case "$type" in
	major)
		echo "$((major + 1)).0.0"
		;;
	minor)
		echo "$major.$((minor + 1)).0"
		;;
	patch)
		echo "$major.$minor.$((patch + 1))"
		;;
	*)
		print_red "ERROR: Invalid version type: $type"
		exit 1
		;;
	esac
}

# Update changelog
update_changelog() {
	local version="$1"
	local date=$(date +%Y-%m-%d)

	print_blue "Updating CHANGELOG.md..."

	# Create temporary file
	local temp_file=$(mktemp)

	# Read changelog and insert new version
	{
		# Keep header and unreleased section
		sed -n '1,/^## \[Unreleased\]/p' "$CHANGELOG_FILE"

		# Add new version section
		echo ""
		echo "## [$version] - $date"
		echo ""
		echo "### Added"
		echo "- Release $version"
		echo ""

		# Add rest of file, but skip the first occurrence of unreleased
		sed -n '/^## \[Unreleased\]/,$p' "$CHANGELOG_FILE" | tail -n +2

		# Update links at bottom
		echo ""
		echo "[Unreleased]: https://github.com/mishaal79/chezmoi-sync/compare/v$version...HEAD"
		echo "[$version]: https://github.com/mishaal79/chezmoi-sync/releases/tag/v$version"

	} >"$temp_file"

	# Replace original file
	mv "$temp_file" "$CHANGELOG_FILE"

	print_green "CHANGELOG.md updated"
}

# Check git status
check_git_status() {
	print_blue "Checking git status..."

	# Check if we're in a git repository
	if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		print_red "ERROR: Not in a git repository"
		exit 1
	fi

	# Check if working directory is clean
	if ! git diff --quiet || ! git diff --cached --quiet; then
		print_red "ERROR: Working directory is not clean"
		print_red "Please commit or stash your changes first"
		exit 1
	fi

	# Check if we're on main branch
	local branch=$(git rev-parse --abbrev-ref HEAD)
	if [[ "$branch" != "main" ]]; then
		print_yellow "WARNING: Not on main branch (current: $branch)"
		if [[ "${FORCE:-false}" != "true" ]]; then
			read -p "Continue anyway? (y/N): " -n 1 -r
			echo
			if [[ ! $REPLY =~ ^[Yy]$ ]]; then
				print_blue "Release cancelled"
				exit 0
			fi
		fi
	fi

	print_green "Git status OK"
}

# Create and push release
create_release() {
	local version="$1"

	print_blue "Creating release $version..."

	# Update version file
	echo "$version" >"$VERSION_FILE"
	print_green "Updated VERSION file"

	# Update changelog
	update_changelog "$version"

	# Commit changes
	git add "$VERSION_FILE" "$CHANGELOG_FILE"
	git commit -m "Release $version

- Update VERSION to $version
- Update CHANGELOG.md with release notes

🚀 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

	print_green "Created release commit"

	# Create tag
	git tag -a "v$version" -m "Release $version"
	print_green "Created tag v$version"

	# Push changes and tag
	git push origin main
	git push origin "v$version"
	print_green "Pushed changes and tag"

	print_green "✅ Release $version created successfully!"
	print_blue "GitHub Actions will now build and publish the release"
	print_blue "View at: https://github.com/mishaal79/chezmoi-sync/releases/tag/v$version"
}

# Main function
main() {
	local version_type=""
	local dry_run=false
	local force=false

	# Parse command line arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
		-h | --help)
			show_help
			exit 0
			;;
		-d | --dry-run)
			dry_run=true
			shift
			;;
		-f | --force)
			force=true
			shift
			;;
		major | minor | patch)
			version_type="$1"
			shift
			;;
		[0-9]*)
			version_type="$1"
			shift
			;;
		*)
			print_red "Unknown option: $1"
			show_help
			exit 1
			;;
		esac
	done

	# Check if version type is provided
	if [[ -z "$version_type" ]]; then
		print_red "ERROR: Version type is required"
		show_help
		exit 1
	fi

	# Set global variables
	FORCE="$force"

	# Change to repo root
	cd "$REPO_ROOT"

	# Get current version
	local current_version=$(get_current_version)
	print_blue "Current version: $current_version"

	# Calculate new version
	local new_version
	if [[ "$version_type" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		new_version="$version_type"
		validate_version "$new_version"
	else
		new_version=$(increment_version "$current_version" "$version_type")
	fi

	print_blue "New version: $new_version"

	# Check if version already exists
	if git tag -l | grep -q "v$new_version"; then
		print_red "ERROR: Tag v$new_version already exists"
		exit 1
	fi

	# Dry run mode
	if [[ "$dry_run" == "true" ]]; then
		print_yellow "DRY RUN MODE - No changes will be made"
		print_blue "Would create release $new_version"
		print_blue "Would update VERSION file"
		print_blue "Would update CHANGELOG.md"
		print_blue "Would create commit and tag"
		print_blue "Would push to GitHub"
		exit 0
	fi

	# Check git status
	check_git_status

	# Confirm release
	if [[ "$force" != "true" ]]; then
		print_yellow "Ready to create release $new_version"
		print_yellow "This will:"
		print_yellow "  - Update VERSION file to $new_version"
		print_yellow "  - Update CHANGELOG.md"
		print_yellow "  - Create git commit and tag"
		print_yellow "  - Push to GitHub"
		print_yellow "  - Trigger automated release build"
		echo
		read -p "Proceed with release? (y/N): " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			print_blue "Release cancelled"
			exit 0
		fi
	fi

	# Create release
	create_release "$new_version"
}

# Run main function with all arguments
main "$@"
