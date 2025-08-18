#!/bin/bash
# Conflict scenario: Local changes exist when remote changes arrive

set -euo pipefail

SCENARIO_NAME="local-changes-conflict"
echo "🧪 Setting up conflict scenario: $SCENARIO_NAME"

# Create chezmoi source directory
mkdir -p ~/.local/share/chezmoi
cd ~/.local/share/chezmoi

# Initialize git repo
git init
git config user.email "test@example.com"
git config user.name "Test User"

# Create initial commit
echo 'export INITIAL_VAR=true' > dot_zshrc.tmpl
git add .
git commit -m "Initial dotfiles"

# Simulate remote repository (using local bare repo for testing)
git clone --bare . /tmp/test-remote-repo.git

# Add remote
git remote add origin /tmp/test-remote-repo.git
git push -u origin main

# Make local changes (not committed)
echo 'export LOCAL_CHANGE=true' >> dot_zshrc.tmpl
echo 'export ANOTHER_LOCAL=value' >> dot_zshrc.tmpl

# Simulate remote changes by pushing from another location
cd /tmp
git clone /tmp/test-remote-repo.git test-remote-work
cd test-remote-work
echo 'export REMOTE_CHANGE=true' >> dot_zshrc.tmpl
git add .
git commit -m "Remote changes"
git push origin main

echo "✅ Conflict scenario set up:"
echo "   - Local uncommitted changes exist"
echo "   - Remote has new commits"
echo "   - This should trigger conflict resolution"

cd ~/.local/share/chezmoi
git status