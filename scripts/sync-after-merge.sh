#!/bin/bash
#
# Sync Local Branch After PR Merge
#
# Automatically detects if a PR has been merged and performs cleanup:
# - Switches to develop
# - Pulls latest changes
# - Deletes merged feature branch
#
# Usage:
#   ./scripts/sync-after-merge.sh
#   OR (if still on feature branch)
#   ./scripts/sync-after-merge.sh feature/branch-name
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Post-Merge Sync & Cleanup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Determine feature branch
if [ $# -ge 1 ]; then
    FEATURE_BRANCH="$1"
else
    FEATURE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
fi

# Check if we're on a protected branch
if [ "$FEATURE_BRANCH" = "main" ] || [ "$FEATURE_BRANCH" = "develop" ]; then
    echo -e "${YELLOW}ℹ️  Already on '${FEATURE_BRANCH}' branch${NC}"
    echo -e "${YELLOW}Pulling latest changes...${NC}"
    git pull origin "$FEATURE_BRANCH"
    echo -e "${GREEN}✅ ${FEATURE_BRANCH} is up to date${NC}"
    exit 0
fi

echo -e "${YELLOW}Feature branch:${NC} ${FEATURE_BRANCH}"

# Determine base branch
BASE_BRANCH="develop"
if [[ "$FEATURE_BRANCH" =~ ^hotfix/ ]]; then
    BASE_BRANCH="main"
fi

echo -e "${YELLOW}Base branch:${NC} ${BASE_BRANCH}"
echo ""

# Fetch latest from remote
echo -e "${YELLOW}Fetching latest from remote...${NC}"
git fetch origin --prune

# Check if feature branch still exists on remote
if git ls-remote --heads origin "$FEATURE_BRANCH" | grep -q "$FEATURE_BRANCH"; then
    echo -e "${YELLOW}⚠️  Branch '${FEATURE_BRANCH}' still exists on remote${NC}"
    echo -e "${YELLOW}This usually means the PR hasn't been merged yet${NC}"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  1. Wait for PR to be merged"
    echo "  2. Check PR status on GitHub"
    echo "  3. Run this script again after merging"
    echo ""
    exit 0
fi

echo -e "${GREEN}✅ Feature branch deleted from remote (PR was merged)${NC}"
echo ""

# Switch to base branch
echo -e "${YELLOW}Switching to '${BASE_BRANCH}'...${NC}"
git checkout "$BASE_BRANCH"

# Pull latest changes
echo -e "${YELLOW}Pulling latest changes...${NC}"
if git pull origin "$BASE_BRANCH"; then
    echo -e "${GREEN}✅ ${BASE_BRANCH} updated${NC}"
else
    echo -e "${RED}❌ Error: Failed to pull changes${NC}"
    exit 1
fi
echo ""

# Delete local feature branch
echo -e "${YELLOW}Deleting local branch '${FEATURE_BRANCH}'...${NC}"
if git branch -d "$FEATURE_BRANCH" 2>/dev/null; then
    echo -e "${GREEN}✅ Local branch deleted${NC}"
elif git branch -D "$FEATURE_BRANCH" 2>/dev/null; then
    echo -e "${GREEN}✅ Local branch force-deleted (had unmerged commits)${NC}"
else
    echo -e "${YELLOW}⚠️  Branch already deleted or doesn't exist${NC}"
fi
echo ""

# Show status
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Current status:${NC}"
git status -sb
echo ""

# Show recent commits
echo -e "${YELLOW}Recent commits on ${BASE_BRANCH}:${NC}"
git log --oneline -5
echo ""
echo -e "${GREEN}Ready for next feature!${NC}"
