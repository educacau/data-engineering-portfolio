# Contributing to Data Engineering Portfolio

Thank you for your interest in contributing to this project! This document provides guidelines for contributing.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/portfolio-enhancement.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test thoroughly
6. Commit with clear messages
7. Push to your fork
8. Open a Pull Request

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
