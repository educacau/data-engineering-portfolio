# Contributing to Data Engineering Portfolio

Thank you for your interest in contributing to this project! This document provides guidelines for contributing.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/portfolio-enhancement.git`
3. Install Git hooks: `./scripts/install-hooks.sh`
4. Create a feature branch: `git checkout -b feature/your-feature-name`
5. Make your changes
6. Test thoroughly
7. Commit with clear messages
8. Push to your fork
9. Open a Pull Request

## Gitflow Workflow

**⚠️ IMPORTANT: Direct commits to `main` and `develop` branches are blocked!**

This project follows the **Gitflow workflow** to maintain code quality and organized development.

### Protected Branches

- **`main`**: Production-ready code only (releases)
- **`develop`**: Main development branch (integration)

🔒 **Git hooks enforce this locally** - commits to these branches will be rejected.

### Branch Naming Conventions

| Branch Type | Naming | Purpose | Example |
|------------|---------|---------|---------|
| **Feature** | `feature/*` | New features | `feature/add-kafka-metrics` |
| **Fix** | `fix/*` | Bug fixes | `fix/docker-memory-leak` |
| **Hotfix** | `hotfix/*` | Production fixes | `hotfix/critical-security-patch` |
| **Release** | `release/*` | Release preparation | `release/v1.0.0` |

### Workflow Steps

#### For New Features (Automated Workflow):

```bash
# 1. Start from develop
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/your-feature-name

# 3. Make changes and commit
git add .
git commit -m "feat: add your feature"

# 4. Push feature branch
git push origin feature/your-feature-name

# 5. Create PR automatically
GITHUB_TOKEN=your_token ./scripts/create-pr.sh

# 6. Merge PR on GitHub (via web interface)

# 7. Sync and cleanup automatically
./scripts/sync-after-merge.sh
```

**The script will automatically:**
- ✅ Detect if PR was merged (checks if remote branch deleted)
- ✅ Switch to develop
- ✅ Pull latest changes
- ✅ Delete local feature branch
- ✅ Show updated status

#### For New Features (Manual Workflow):

```bash
# 1. Start from develop
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/your-feature-name

# 3. Make changes and commit
git add .
git commit -m "feat: add your feature"

# 4. Push and create PR
git push origin feature/your-feature-name
# Create PR manually on GitHub

# 5. After PR is merged, sync locally
git checkout develop
git pull origin develop
git branch -d feature/your-feature-name
```

#### For Bug Fixes:

Same as features, but use `fix/bug-name` as branch name.

#### For Hotfixes (Production):

```bash
# 1. Start from main
git checkout main
git checkout -b hotfix/issue-name

# 2. Fix and commit
git add .
git commit -m "hotfix: fix critical issue"

# 3. Push and create PR
git push origin hotfix/issue-name
GITHUB_TOKEN=your_token ./scripts/create-pr.sh  # Auto-targets 'main'

# 4. After PR merged to main, also merge to develop
git checkout develop
git merge hotfix/issue-name --no-ff
git push origin develop

# 5. Cleanup
./scripts/sync-after-merge.sh hotfix/issue-name
```

### Automation Scripts

This repository includes helpful scripts to automate the Gitflow workflow:

| Script | Purpose | Usage |
|--------|---------|-------|
| **install-hooks.sh** | Install Git hooks to block direct commits | `./scripts/install-hooks.sh` |
| **create-pr.sh** | Automatically create Pull Request | `GITHUB_TOKEN=token ./scripts/create-pr.sh` |
| **sync-after-merge.sh** | Sync and cleanup after PR merge | `./scripts/sync-after-merge.sh` |
| **setup-branch-protection.sh** | Setup GitHub branch protection | `GITHUB_TOKEN=token ./scripts/setup-branch-protection.sh` |
| **adjust-branch-protection-solo.sh** | Adjust protection for solo repos | `GITHUB_TOKEN=token ./scripts/adjust-branch-protection-solo.sh` |

**Benefits of using automation scripts:**
- ⚡ Faster workflow
- ✅ No manual PR creation needed
- 🤖 Automatic detection of merged PRs
- 🧹 Automatic cleanup after merge
- 📋 Consistent process every time

### Installing Git Hooks

Git hooks are installed automatically when you run:

```bash
./scripts/install-hooks.sh
```

This installs:
- **pre-commit**: Blocks direct commits to `main` and `develop`

### Bypassing Hooks (Not Recommended)

If you absolutely must bypass the hooks (e.g., during repository setup):

```bash
git commit --no-verify
```

⚠️ **Warning**: Only use this if you know what you're doing!

## Development Setup

### Prerequisites

- Docker 24+ and Docker Compose V2
- Python 3.11+
- Git
- 8GB RAM minimum (4GB for demo mode)

### Local Setup

```bash
# Clone the repository
git clone <your-fork-url>
cd portfolio-enhancement

# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run the demo
./demo.sh
```

## Code Standards

### Python
- Follow PEP 8
- Use type hints
- Add docstrings for functions
- Write tests for new features

### Bash
- Use `set -euo pipefail`
- Follow ShellCheck recommendations
- Add comments for complex logic

### Documentation
- Use Markdown for all docs
- Follow markdownlint rules
- Add alt text to images
- Keep lines under 120 characters

### Commits
- Use conventional commits format
- Examples:
  - `feat: add Kafka throughput benchmark`
  - `fix: correct Docker memory limit`
  - `docs: update README with new screenshots`
  - `test: add integration test for NiFi flow`

## Testing

### Run All Tests
```bash
pytest tests/integration/ -v
```

### Run Benchmarks
```bash
./scripts/benchmark.sh
```

### Test Demo Locally
```bash
./demo.sh
```

## Pull Request Process

1. Update documentation for any changed functionality
2. Add tests for new features
3. Ensure all tests pass
4. Update CHANGELOG.md if applicable
5. Request review from maintainers
6. Address review feedback
7. Squash commits if requested

## Questions?

Feel free to open an issue for:
- Bug reports
- Feature requests
- Documentation improvements
- General questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
