#!/bin/bash
#
# Configure GitHub to Auto-Delete Branches After PR Merge
#
# Automatically deletes head branches after pull requests are merged.
# This keeps the repository clean and follows Gitflow best practices.
#
# Usage:
#   ./scripts/configure-auto-delete-branches.sh
#
# Prerequisites:
#   - GitHub credentials (uses git credential manager)
#   - Repository must exist on GitHub
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  GitHub Auto-Delete Branches Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Get repository information
REPO_URL=$(git config --get remote.origin.url)
if [[ "$REPO_URL" =~ github.com[:/]([^/]+)/([^/.]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
else
    echo -e "${RED}❌ Error: Could not extract repository information${NC}"
    exit 1
fi

echo -e "${YELLOW}Repository:${NC} ${OWNER}/${REPO}"
echo ""

# Get GitHub token from credential manager
echo -e "${YELLOW}Extracting GitHub token from credential manager...${NC}"
GITHUB_TOKEN=$(printf "protocol=https\nhost=github.com\n" | git credential fill | grep "password=" | cut -d'=' -f2)

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}❌ Error: Could not extract GitHub token${NC}"
    echo -e "${YELLOW}Make sure you have authenticated with GitHub${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Token extracted${NC}"
echo ""

# Check current configuration
echo -e "${YELLOW}Checking current configuration...${NC}"
CURRENT_CONFIG=$(curl -s \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${OWNER}/${REPO}" | grep '"delete_branch_on_merge":' || echo "Not found")

if echo "$CURRENT_CONFIG" | grep -q "true"; then
    echo -e "${GREEN}✅ Auto-delete is already enabled${NC}"
    echo ""
    echo -e "${BLUE}Current Settings:${NC}"
    echo "$CURRENT_CONFIG"
    exit 0
fi

echo -e "${YELLOW}Current status: Auto-delete is disabled${NC}"
echo ""

# Enable auto-delete
echo -e "${YELLOW}Enabling auto-delete branches after merge...${NC}"

# Create temporary JSON file
cat > /tmp/repo_config.json << 'EOF'
{
  "delete_branch_on_merge": true
}
EOF

# Update repository settings
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X PATCH \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${OWNER}/${REPO}" \
    -d @/tmp/repo_config.json)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

# Clean up
rm -f /tmp/repo_config.json

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✅ Auto-delete branches enabled successfully!${NC}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Configuration Complete${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}What happens now:${NC}"
    echo "  • When you merge a PR on GitHub, the head branch is deleted automatically"
    echo "  • Applies to all future PR merges"
    echo "  • Keeps repository clean (only main, develop, and active feature branches)"
    echo ""
    echo -e "${YELLOW}Note:${NC}"
    echo "  • You can still manually restore deleted branches if needed"
    echo "  • Protected branches (main, develop) are never deleted"
    echo "  • Only the head branch of merged PRs is deleted"
    echo ""
    echo -e "${GREEN}Gitflow Best Practice: ✅ Enabled${NC}"
else
    echo -e "${RED}❌ Error: Failed to enable auto-delete${NC}"
    echo -e "${RED}HTTP Code: ${HTTP_CODE}${NC}"
    echo "$RESPONSE_BODY" | grep -E "message|errors" || echo "$RESPONSE_BODY"
    exit 1
fi
