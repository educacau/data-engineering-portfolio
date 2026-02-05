#!/bin/bash
#
# Setup GitHub Branch Protection Rules via API
#
# This script configures branch protection for 'main' and 'develop' branches
# to enforce Gitflow workflow at the repository level.
#
# Prerequisites:
#   - GitHub Personal Access Token with 'repo' scope
#   - Admin access to the repository
#
# Usage:
#   GITHUB_TOKEN=your_token ./scripts/setup-branch-protection.sh
#   OR
#   ./scripts/setup-branch-protection.sh (will prompt for token)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  GitHub Branch Protection Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Get repository information
REPO_URL=$(git config --get remote.origin.url)
if [[ "$REPO_URL" =~ github.com[:/]([^/]+)/([^/.]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
else
    echo -e "${RED}❌ Error: Could not extract repository information from Git remote${NC}"
    exit 1
fi

echo -e "${YELLOW}Repository:${NC} ${OWNER}/${REPO}"
echo ""

# Check for GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo -e "${YELLOW}GitHub Personal Access Token required.${NC}"
    echo ""
    echo "To create a token:"
    echo "1. Go to: https://github.com/settings/tokens/new"
    echo "2. Note: 'Branch Protection Setup'"
    echo "3. Expiration: 7 days (or as needed)"
    echo "4. Scopes: Select 'repo' (Full control of private repositories)"
    echo "5. Generate token and copy it"
    echo ""
    read -sp "Enter your GitHub Token: " GITHUB_TOKEN
    echo ""
    echo ""
fi

# Validate token
echo -e "${YELLOW}Validating GitHub token...${NC}"
if ! curl -sf -H "Authorization: token ${GITHUB_TOKEN}" \
     "https://api.github.com/user" > /dev/null; then
    echo -e "${RED}❌ Error: Invalid GitHub token${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Token validated${NC}"
echo ""

# Function to setup branch protection
setup_protection() {
    local branch=$1
    local branch_type=$2

    echo -e "${YELLOW}Setting up protection for '${branch}' branch...${NC}"

    # Protection rules JSON
    local protection_rules=$(cat <<EOF
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
EOF
)

    # Apply protection rules
    response=$(curl -s -w "\n%{http_code}" \
        -X PUT \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${OWNER}/${REPO}/branches/${branch}/protection" \
        -d "${protection_rules}")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo -e "${GREEN}✅ Protection enabled for '${branch}' branch${NC}"
        echo -e "   ${BLUE}→${NC} Pull requests required for merging"
        echo -e "   ${BLUE}→${NC} 1 approval required"
        echo -e "   ${BLUE}→${NC} Stale reviews dismissed on new commits"
        echo -e "   ${BLUE}→${NC} Admins included in restrictions"
        echo -e "   ${BLUE}→${NC} Force pushes blocked"
        echo ""
        return 0
    else
        echo -e "${RED}❌ Error: Failed to setup protection for '${branch}'${NC}"
        echo -e "${RED}   HTTP Code: ${http_code}${NC}"
        echo "$response" | head -n-1
        echo ""
        return 1
    fi
}

# Setup protection for main branch
echo -e "${BLUE}═══ Protecting 'main' branch ═══${NC}"
setup_protection "main" "production"

# Setup protection for develop branch
echo -e "${BLUE}═══ Protecting 'develop' branch ═══${NC}"
setup_protection "develop" "development"

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Branch protection setup complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Protected branches:${NC}"
echo -e "  • main    ${BLUE}→${NC} Production releases only"
echo -e "  • develop ${BLUE}→${NC} Development integration"
echo ""
echo -e "${YELLOW}Enforcement:${NC}"
echo -e "  ✅ Local:  Git hooks block direct commits"
echo -e "  ✅ Remote: GitHub requires pull requests"
echo ""
echo -e "${GREEN}Gitflow workflow is now fully enforced!${NC}"
echo ""
echo -e "${YELLOW}View protection rules:${NC}"
echo -e "  https://github.com/${OWNER}/${REPO}/settings/branches"
echo ""
