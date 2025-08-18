#!/bin/bash
# Conflict scenario: Local and remote branches have diverged

set -euo pipefail

SCENARIO_NAME="diverged-branches"
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

# Simulate remote repository
git clone --bare . /tmp/test-diverged-repo.git
git remote add origin /tmp/test-diverged-repo.git
git push -u origin main

# Make and commit local changes
echo 'export LOCAL_FEATURE=enabled' >> dot_zshrc.tmpl
git add .
git commit -m "Local feature addition"

# Simulate remote changes from another machine
cd /tmp
git clone /tmp/test-diverged-repo.git test-diverged-work
cd test-diverged-work
echo 'export REMOTE_FEATURE=enabled' >> dot_zshrc.tmpl
git add .
git commit -m "Remote feature addition"
git push origin main

echo "✅ Diverged branches scenario set up:"
echo "   - Local has committed changes"
echo "   - Remote has different committed changes"
echo "   - Branches have diverged and need manual merge"

cd ~/.local/share/chezmoi
git log --oneline --graph --all || true
git status