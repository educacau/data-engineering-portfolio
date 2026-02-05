#!/bin/bash
#
# Install Git hooks for enforcing Gitflow workflow
#
# Usage:
#   ./scripts/install-hooks.sh
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing Git hooks for Gitflow enforcement...${NC}"

# Get the repository root directory
REPO_ROOT=$(git rev-parse --show-toplevel)
HOOKS_DIR="${REPO_ROOT}/.git/hooks"
HOOKS_TEMPLATE="${REPO_ROOT}/scripts/hooks"

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Pre-commit hook content
PRE_COMMIT_HOOK=$(cat <<'EOF'
#!/bin/bash
#
# Git pre-commit hook to enforce Gitflow workflow
# Blocks direct commits to protected branches (main, develop)
#

# Get the current branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Define protected branches
PROTECTED_BRANCHES=("main" "develop")

# Check if current branch is protected
for protected in "${PROTECTED_BRANCHES[@]}"; do
    if [ "$BRANCH" = "$protected" ]; then
        cat <<EOFMSG

❌ ERROR: Direct commits to '$BRANCH' branch are not allowed!

🎯 Gitflow Workflow Required:
   1. Create a feature branch:
      git checkout -b feature/your-feature-name

   2. Commit your changes:
      git add .
      git commit -m "your message"

   3. Merge to develop:
      git checkout develop
      git merge feature/your-feature-name --no-ff

   4. Delete feature branch:
      git branch -d feature/your-feature-name

📚 Branch naming conventions:
   - feature/feature-name   (new features)
   - fix/bug-name          (bug fixes)
   - hotfix/issue-name     (production hotfixes)
   - release/version       (release preparation)

🔒 Protected branches: main, develop

EOFMSG
        exit 1
    fi
done

# If we got here, the commit is allowed
exit 0
EOF
)

# Install pre-commit hook
echo "$PRE_COMMIT_HOOK" > "${HOOKS_DIR}/pre-commit"
chmod +x "${HOOKS_DIR}/pre-commit"

echo -e "${GREEN}✅ Git hooks installed successfully!${NC}"
echo ""
echo -e "${YELLOW}Installed hooks:${NC}"
echo "  - pre-commit: Blocks direct commits to main/develop branches"
echo ""
echo -e "${GREEN}Gitflow workflow is now enforced locally!${NC}"
echo -e "${YELLOW}To bypass (not recommended):${NC} git commit --no-verify"
