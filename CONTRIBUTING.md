# Contributing to Automatic Dev Setup

Right — so you want to contribute. Brilliant. Let's establish some ground rules so we don't descend into chaos.

## Code of Conduct

Basic respect, yeah? We're all trying to build something useful here. No gatekeeping, no condescension, no "well actually" nonsense. If you wouldn't say it to someone's face over coffee, don't type it.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* **Use a clear and descriptive title**
* **Describe the exact steps which reproduce the problem**
* **Provide specific examples to demonstrate the steps**
* **Describe the behavior you observed after following the steps**
* **Explain which behavior you expected to see instead and why**
* **Include system information** (macOS version, shell version, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* **Use a clear and descriptive title**
* **Provide a step-by-step description of the suggested enhancement**
* **Provide specific examples to demonstrate the steps**
* **Describe the current behavior and explain which behavior you expected to see instead**
* **Explain why this enhancement would be useful**

### Pull Requests

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run shellcheck on any modified shell scripts:
   ```bash
   shellcheck -S warning your-script.sh
   ```
5. Test your changes thoroughly
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## Style Guidelines

### Shell Scripts

* `#!/usr/bin/env bash` — always. Not sh, not zsh, bash.
* Error handling is mandatory: `set -Eeuo pipefail`
* IFS gets set properly: `IFS=$'\n\t'`
* Variable names in UPPER_CASE — and make them meaningful, not `VAR1` rubbish
* Quote your variables: `"$VARIABLE"` — unquoted variables are how disasters happen
* Comment the why, not the what. I can see it's a loop, tell me why it exists
* ShellCheck is law. If it complains, fix it

### Documentation

* Use Markdown for all documentation
* Include code examples where appropriate
* Keep language clear and concise
* Update README.md if adding new features

### Commit Messages

* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit the first line to 72 characters or less
* Reference issues and pull requests liberally after the first line

## Project Structure

When contributing, please maintain the existing project structure:

* `core/` - Core setup modules
* `lib/` - Shared libraries and utilities
* `config/` - Configuration files
* `templates/` - Project templates
* `testing/` - Test suites
* `maintenance/` - Maintenance scripts
* `operations_support/` - Support and repair tools
* `docs/` - Documentation

## Testing

Before submitting a pull request:

1. Test your changes on a clean macOS installation if possible
2. Run the validation suite:
   ```bash
   ./operations_support/09-automatic-dev-validate.sh
   ```
3. Ensure all existing functionality still works
4. Add tests for new functionality where applicable

## Questions?

Feel free to open an issue with your question or reach out to the maintainer.

Thank you for contributing!