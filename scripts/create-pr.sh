#!/bin/bash
#
# Create Pull Request via GitHub API
#
# Automatically creates a PR for the current branch targeting 'develop'
#
# Prerequisites:
#   - GitHub Personal Access Token with 'repo' scope
#   - Feature branch pushed to remote
#
# Usage:
#   GITHUB_TOKEN=your_token ./scripts/create-pr.sh
#   OR
#   ./scripts/create-pr.sh (will prompt for token)
#   OR
#   ./scripts/create-pr.sh "PR Title" "PR Description"
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  GitHub Pull Request Creator${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Check if on protected branch
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "develop" ]; then
    echo -e "${RED}❌ Error: Cannot create PR from protected branch '${CURRENT_BRANCH}'${NC}"
    echo -e "${YELLOW}Please create a feature branch first:${NC}"
    echo -e "  git checkout -b feature/your-feature-name"
    exit 1
fi

echo -e "${YELLOW}Current branch:${NC} ${CURRENT_BRANCH}"

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

# Check if branch is pushed to remote
if ! git ls-remote --heads origin "$CURRENT_BRANCH" | grep -q "$CURRENT_BRANCH"; then
    echo -e "${RED}❌ Error: Branch '${CURRENT_BRANCH}' not found on remote${NC}"
    echo -e "${YELLOW}Push the branch first:${NC}"
    echo -e "  git push origin ${CURRENT_BRANCH}"
    exit 1
fi

echo -e "${GREEN}✅ Branch exists on remote${NC}"
echo ""

# Check for GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo -e "${YELLOW}GitHub Personal Access Token required.${NC}"
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

# Determine base branch (default: develop)
BASE_BRANCH="develop"

# Check if this is a hotfix (should target main)
if [[ "$CURRENT_BRANCH" =~ ^hotfix/ ]]; then
    BASE_BRANCH="main"
fi

echo -e "${YELLOW}Target branch:${NC} ${BASE_BRANCH}"
echo ""

# Get PR title and body
if [ $# -ge 2 ]; then
    PR_TITLE="$1"
    PR_BODY="$2"
else
    # Generate PR title from branch name
    PR_TITLE=$(echo "$CURRENT_BRANCH" | sed 's|^feature/||;s|^fix/||;s|^hotfix/||;s|-| |g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')

    # Get commit messages for PR body
    COMMITS=$(git log --oneline origin/${BASE_BRANCH}..HEAD --pretty=format:"- %s" | head -n 10)

    # Escape special characters for JSON
    COMMITS_ESCAPED=$(echo "$COMMITS" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed '$ s/\\n$//')

    PR_BODY="## Changes\n\n${COMMITS_ESCAPED}\n\n## Type of Change\n\n- [ ] Bug fix (non-breaking change which fixes an issue)\n- [ ] New feature (non-breaking change which adds functionality)\n- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)\n- [ ] Documentation update\n\n## Checklist\n\n- [ ] Code follows project style guidelines\n- [ ] Self-review completed\n- [ ] Comments added for complex logic\n- [ ] Documentation updated\n- [ ] No new warnings generated\n- [ ] Tests added/updated (if applicable)\n- [ ] All tests pass locally\n\n---\n🤖 Generated with automated PR script"
fi

echo -e "${YELLOW}PR Title:${NC} ${PR_TITLE}"
echo ""

# Escape title and body for JSON
PR_TITLE_ESCAPED=$(echo "$PR_TITLE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
PR_BODY_ESCAPED=$(echo -e "$PR_BODY" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed '$ s/\\n$//')

# Create PR JSON payload
PR_JSON=$(cat <<EOF
{
  "title": "${PR_TITLE_ESCAPED}",
  "body": "${PR_BODY_ESCAPED}",
  "head": "${CURRENT_BRANCH}",
  "base": "${BASE_BRANCH}",
  "draft": false
}
EOF
)

# Create the pull request
echo -e "${YELLOW}Creating pull request...${NC}"
response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${OWNER}/${REPO}/pulls" \
    -d "$PR_JSON")

http_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 201 ]; then
    # Extract PR URL and number from JSON response (without jq)
    PR_URL=$(echo "$response_body" | grep -o '"html_url"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"html_url"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
    PR_NUMBER=$(echo "$response_body" | grep -o '"number"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')

    echo -e "${GREEN}✅ Pull request created successfully!${NC}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}PR #${PR_NUMBER}: ${PR_TITLE}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Branch:${NC} ${CURRENT_BRANCH} → ${BASE_BRANCH}"
    echo -e "${YELLOW}URL:${NC} ${PR_URL}"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "  1. Review the PR at: ${PR_URL}"
    echo "  2. Wait for approval (1 required)"
    echo "  3. Merge the PR"
    echo "  4. Delete the feature branch"
    echo ""
else
    echo -e "${RED}❌ Error: Failed to create pull request${NC}"
    echo -e "${RED}HTTP Code: ${http_code}${NC}"
    echo "$response_body"
    exit 1
fi
