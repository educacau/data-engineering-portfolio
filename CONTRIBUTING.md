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

#### For New Features:

```bash
# 1. Start from develop
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/your-feature-name

# 3. Make changes and commit
git add .
git commit -m "feat: add your feature"

# 4. Merge back to develop
git checkout develop
git merge feature/your-feature-name --no-ff

# 5. Clean up
git branch -d feature/your-feature-name

# 6. Push to remote
git push origin develop
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

# 3. Merge to both main AND develop
git checkout main
git merge hotfix/issue-name --no-ff
git checkout develop
git merge hotfix/issue-name --no-ff

# 4. Clean up
git branch -d hotfix/issue-name
```

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
