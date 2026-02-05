#!/bin/bash
#
# Adjust Branch Protection for Solo Repository
#
# Keeps PR requirement but removes approval requirement
# Perfect for personal/portfolio repositories
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Adjust Branch Protection for Solo Repository${NC}"
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

# Check for GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo -e "${YELLOW}GitHub Personal Access Token required.${NC}"
    echo ""
    read -sp "Enter your GitHub Token: " GITHUB_TOKEN
    echo ""
    echo ""
fi

# Function to adjust protection
adjust_protection() {
    local branch=$1

    echo -e "${YELLOW}Adjusting protection for '${branch}' branch...${NC}"

    # Protection rules JSON - PR required, NO approval required
    local protection_rules=$(cat <<EOF
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": null,
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

    response=$(curl -s -w "\n%{http_code}" \
        -X PUT \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${OWNER}/${REPO}/branches/${branch}/protection" \
        -d "${protection_rules}")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo -e "${GREEN}✅ Protection adjusted for '${branch}' branch${NC}"
        echo -e "   ${BLUE}→${NC} Pull requests REQUIRED"
        echo -e "   ${BLUE}→${NC} Approvals NOT required (solo repo)"
        echo -e "   ${BLUE}→${NC} Admins included in restrictions"
        echo -e "   ${BLUE}→${NC} Force pushes blocked"
        echo ""
        return 0
    else
        echo -e "${RED}❌ Error: Failed to adjust protection${NC}"
        echo "$response" | head -n-1
        return 1
    fi
}

# Adjust both branches
adjust_protection "main"
adjust_protection "develop"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Branch protection adjusted for solo repository!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  ✅ Pull requests REQUIRED (maintains workflow)"
echo "  ✅ No approval needed (solo repo friendly)"
echo "  ✅ Direct commits still blocked"
echo "  ✅ Force pushes still blocked"
echo ""
echo -e "${GREEN}You can now merge your own PRs!${NC}"
echo ""
