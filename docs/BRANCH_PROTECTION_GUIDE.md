# GitHub Branch Protection Setup Guide

This guide provides instructions for setting up branch protection rules on GitHub to enforce the Gitflow workflow.

## Why Branch Protection?

Branch protection rules prevent direct commits to protected branches (`main` and `develop`), ensuring all changes go through pull requests with code review.

**Benefits:**
- ✅ Enforces code review process
- ✅ Prevents accidental commits to protected branches
- ✅ Maintains clean Git history
- ✅ Ensures CI/CD checks pass before merging
- ✅ Complements local Git hooks

---

## Quick Setup (Automated) 🤖

### Using the Script

The easiest way to setup branch protection is using our automated script:

```bash
# Method 1: With token as environment variable
GITHUB_TOKEN=your_token_here ./scripts/setup-branch-protection.sh

# Method 2: Script will prompt for token
./scripts/setup-branch-protection.sh
```

**Prerequisites:**
1. GitHub Personal Access Token with `repo` scope
2. Admin access to the repository

### Creating a GitHub Token

1. Go to: [https://github.com/settings/tokens/new](https://github.com/settings/tokens/new)
2. **Note:** `Branch Protection Setup`
3. **Expiration:** `7 days` (or as needed)
4. **Scopes:** Select `repo` (Full control of private repositories)
5. Click **Generate token**
6. Copy the token immediately (you won't see it again)

---

## Manual Setup (Web Interface) 🌐

If you prefer to configure branch protection manually through the GitHub web interface:

### Step-by-Step Instructions

#### 1. Navigate to Repository Settings

1. Go to your repository: `https://github.com/YOUR_USERNAME/data-engineering-portfolio`
2. Click **Settings** (top right, near Code/Issues/Pull requests)
3. In the left sidebar, click **Branches** (under "Code and automation")

#### 2. Add Protection Rule for `develop` Branch

1. Click **Add branch protection rule** (or **Add rule**)
2. In **Branch name pattern**, enter: `develop`
3. Configure the following settings:

**Protect matching branches:**

- ✅ **Require a pull request before merging**
  - ✅ **Require approvals**: Set to `1`
  - ✅ **Dismiss stale pull request approvals when new commits are pushed**
  - ⬜ **Require review from Code Owners** (optional, if you have CODEOWNERS file)
  - ⬜ **Restrict who can dismiss pull request reviews** (optional)
  - ⬜ **Allow specified actors to bypass required pull requests** (leave unchecked)
  - ⬜ **Require approval of the most recent reviewable push** (optional)

- ⬜ **Require status checks to pass before merging** (optional, enable when CI/CD is ready)
  - ⬜ **Require branches to be up to date before merging**
  - Add specific checks if available (e.g., `test`, `lint`, `build`)

- ⬜ **Require conversation resolution before merging** (optional but recommended)

- ⬜ **Require signed commits** (optional, for extra security)

- ⬜ **Require linear history** (optional, keeps Git history clean)

- ⬜ **Require deployments to succeed before merging** (optional)

**Rules applied to everyone including administrators:**

- ✅ **Include administrators** ⚠️ **IMPORTANT: Check this!**
  - This ensures even repository admins must follow the rules

**Restrict pushes and creations:**

- ⬜ **Restrict who can push to matching branches** (optional)
  - Leave unchecked to allow all collaborators via PR

**Allow deletions and force pushes:**

- ⬜ **Allow force pushes** (leave UNCHECKED - prevents rewriting history)
- ⬜ **Allow deletions** (leave UNCHECKED - prevents accidental deletion)

4. Scroll to bottom and click **Create** (or **Save changes**)

#### 3. Add Protection Rule for `main` Branch

Repeat the same process for the `main` branch:

1. Click **Add branch protection rule** again
2. In **Branch name pattern**, enter: `main`
3. Apply the **same settings** as for `develop` branch
4. Click **Create**

#### 4. Verify Configuration

1. Go to `Settings` → `Branches`
2. You should see two rules:
   - **Rule: develop** ✅
   - **Rule: main** ✅
3. Click on each rule to verify settings

---

## Recommended Configuration Summary

### For Both `main` and `develop` Branches:

| Setting | Status | Description |
|---------|--------|-------------|
| **Require pull request before merging** | ✅ Enabled | Forces all changes through PRs |
| **Require approvals** | ✅ 1 approval | Ensures code review |
| **Dismiss stale reviews** | ✅ Enabled | Re-review after new commits |
| **Include administrators** | ✅ Enabled | No exceptions, even for admins |
| **Allow force pushes** | ❌ Disabled | Protects Git history |
| **Allow deletions** | ❌ Disabled | Prevents accidental deletion |

### Optional Settings:

| Setting | Recommendation |
|---------|---------------|
| **Require status checks** | Enable when CI/CD is configured |
| **Require conversation resolution** | Recommended for team workflows |
| **Require signed commits** | Optional, adds extra security layer |
| **Require linear history** | Optional, keeps history clean |

---

## Testing Branch Protection

After setup, test that protection is working:

### Test 1: Try Direct Push (Should Fail)

```bash
# On develop branch
git checkout develop
echo "test" > test.txt
git add test.txt
git commit -m "test: direct commit"
git push origin develop
```

**Expected Result:**
```
remote: error: GH006: Protected branch update failed for refs/heads/develop.
remote: error: Changes must be made through a pull request.
```

### Test 2: Use Feature Branch (Should Work)

```bash
# Create feature branch
git checkout develop
git checkout -b feature/test-protection
echo "test" > test.txt
git add test.txt
git commit -m "test: via feature branch"
git push origin feature/test-protection

# Create PR on GitHub
# Merge after approval
```

**Expected Result:** ✅ PR created successfully, merge available after approval

---

## Troubleshooting

### Problem: "You don't have permission to setup branch protection"

**Solution:** You need admin access to the repository. Ask the repository owner to:
- Make you an admin: `Settings` → `Collaborators` → Change role to `Admin`
- Or have them setup branch protection

### Problem: "Branch not found"

**Solution:** Make sure the branch exists on GitHub:
```bash
git push origin develop
git push origin main
```

### Problem: "Script fails with 401 Unauthorized"

**Solution:** Check your GitHub token:
- Ensure token has `repo` scope
- Token hasn't expired
- Token is correctly copied (no extra spaces)

### Problem: "I need to bypass protection temporarily"

**Solution:**
1. ⚠️ **Not recommended**, but if absolutely necessary:
2. Go to `Settings` → `Branches` → Your rule
3. Temporarily disable **Include administrators**
4. Make your changes
5. **Re-enable immediately** after

---

## Verification Checklist

After setup, verify:

- [ ] `develop` branch has protection rule enabled
- [ ] `main` branch has protection rule enabled
- [ ] "Require pull request before merging" is checked
- [ ] "Require approvals" is set to 1
- [ ] "Dismiss stale pull request approvals" is checked
- [ ] "Include administrators" is checked ⚠️ **CRITICAL**
- [ ] "Allow force pushes" is unchecked
- [ ] "Allow deletions" is unchecked
- [ ] Direct push to `develop` is blocked (tested)
- [ ] Direct push to `main` is blocked (tested)
- [ ] Local Git hooks are installed and working

---

## Additional Resources

- **GitHub Docs:** [About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- **Gitflow Workflow:** See `CONTRIBUTING.md` for detailed workflow guide
- **Support:** Open an issue if you encounter problems

---

## Summary

**Local Protection:** Git hooks prevent commits to `main`/`develop` locally ✅

**Remote Protection:** GitHub branch rules enforce pull requests remotely ✅

**Result:** Full Gitflow workflow enforcement! 🎯
