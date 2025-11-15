# Automatic Dev Setup

[![macOS](https://img.shields.io/badge/macOS-13%2B-blue)](https://www.apple.com/macos/)
[![Bash](https://img.shields.io/badge/bash-5.2%2B-green)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-purple)](LICENSE)

Comprehensive development environment orchestration suite — built for macOS, engineered for reliability. This isn't just another dotfiles repo; it's a complete workstation transformation protocol that respects both system integrity and user agency. Every module operates with surgical precision whilst maintaining full reversibility.

## 🎯 What This Actually Does

- **Modular Architecture** — 11 discrete modules, each independently executable. No monolithic nightmares here
- **Intelligent Dependency Resolution** — the system knows what you need before you do. Handles circular deps, version conflicts, the whole spiral
- **Performance Optimisation** — parallelised where it matters, sequential where it counts. Built for M-series chips but Intel-aware
- **Comprehensive Toolchain** — 100+ tools, but curated. Not just throwing formulae at brew and hoping
- **Shell Environment** — your terminal becomes actually pleasant. Modern replacements for ancient UNIX cruft
- **Database Stack** — PostgreSQL, Redis, MongoDB. Configured properly, secured by default, no localhost:5432 nonsense
- **Language Ecosystems** — Python (with pyenv sanity), Node.js, Go, Rust, Java. Each isolated, none conflicting
- **Security Posture** — credentials stay safe, permissions stay sane, nothing phones home without your explicit consent

## 📋 Prerequisites

- macOS 13.0 (Ventura) or later
- Administrator access (you'll be prompted for your password once)
- ~50GB free disk space (recommended)
- Internet connection

## 🚀 Quick Start

```bash
# Get the code
git clone https://github.com/kierantandi/automatic_dev_setup.git
cd automatic_dev_setup

# Preflight — clears quarantine flags, sets permissions. Essential.
./preflight.sh

# Want modern Bash? (Apple's is ancient)
./preflight.sh --update-bash

# Run it. Grab coffee, this takes a while.
./install.sh
```

## 📦 What's Installed

### Core Development Tools
- **Version Control**: Git, GitHub CLI, Git LFS, LazyGit, Delta
- **Package Managers**: Homebrew, npm, yarn, pnpm, pip, cargo
- **Languages**: Python 3.10/3.11/3.12, Node.js 20, Go, Rust, Java (OpenJDK), Ruby
- **Cloud Tools**: AWS CLI, Google Cloud SDK, Terraform, Kubernetes tools
- **Containers**: Docker, Colima, Container management tools

### Modern CLI Utilities
- **File Management**: eza, bat, ripgrep, fd, fzf, zoxide
- **System Monitoring**: btop, glances, dust, procs
- **Network Tools**: gping, doggo, httpie, curl, wget
- **Development**: neovim, tmux, direnv, shellcheck

### GUI Applications
- **Editors**: Visual Studio Code, Cursor, Sublime Text
- **Terminals**: Warp
- **Database Tools**: TablePlus, DBeaver
- **Utilities**: Raycast, Rectangle, Stats

## 🔧 Configuration Options

### Installation Modes

```bash
# Standard installation (balanced)
./install.sh --standard

# Performance mode (additional optimisation tools)
./install.sh --performance
```

### Module Control

```bash
# List available modules
./core/00-automatic-dev-orchestrator.sh --list

# Run specific module only
./core/00-automatic-dev-orchestrator.sh --only 04-python-ecosystem

# Skip specific modules
./core/00-automatic-dev-orchestrator.sh --skip 06-database-systems

# Start from specific module
./core/00-automatic-dev-orchestrator.sh --start 05-development-stack

# Resume after an interrupted run
./core/00-automatic-dev-orchestrator.sh --resume

# Verify locked tool versions
./tools/ads-verify-versions.sh

# Create an on-demand restore point
./tools/ads-create-restore-point.sh manual-backup
```

## 📁 Project Structure

```
automatic_dev_setup/
├── core/                    # Core setup modules (01-11)
│   ├── 00-automatic-dev-orchestrator.sh
│   ├── 01-system-bootstrap.sh
│   ├── 02-homebrew-foundation.sh
│   └── ...
├── lib/                     # Shared libraries and utilities
├── config/                  # Configuration files
│   ├── Brewfile.automatic-dev
│   └── requirements-automatic-dev.txt
├── templates/               # Project templates
├── testing/                 # Test suites
├── maintenance/             # Maintenance scripts
└── operations_support/      # Support and repair tools
```

## 🔍 Module Breakdown

1. **System Bootstrap** — Xcode tools, directory structure, the foundations
2. **Homebrew Foundation** — Package manager plus ~100 formulae/casks. The heavy lifting
3. **Shell Environment** — Makes your terminal not feel like 1979. Zsh, modern tools, actual colours
4. **Python Ecosystem** — Pyenv, multiple Python versions, virtual environments that actually work
5. **Development Stack** — Node.js (via nvm), Go, Rust, Java. Each properly isolated
6. **Database Systems** — PostgreSQL 16, Redis, MongoDB. Configured, optimised, secured
7. **Project Templates** — Starter scaffolds that don't suck
8. **System Optimisation** — Cache cleanup, power management, the subtle stuff
9. **Integration Validation** — Comprehensive test suite. Confirms nothing's broken
10. **Maintenance Setup** — Launchd jobs, automated updates, self-healing where possible
11. **Comprehensive Audit** — ShellCheck compliance, tool verification, the final sweep

## 🛠️ Advanced Usage

### Troubleshooting

```bash
# Run diagnostic checks
./troubleshooting.sh

# Validate installation
./operations_support/09-automatic-dev-validate.sh

# Repair installation
./operations_support/10-automatic-dev-repair.sh
```

### Custom Configuration

Edit `automatic-dev-config.env` to customize:
- Installation paths
- Python versions
- Resource thresholds
- Feature toggles

## 📊 System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| macOS | 13.0 (Ventura) | Whatever's current |
| RAM | 8GB (you'll suffer) | 16GB+ (actually usable) |
| Storage | 20GB free | 50GB+ (be realistic) |
| CPU | Intel works | Apple Silicon (M-series) |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and enhancement requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Kieran Tandi**

- GitHub: [@kierantandi](https://github.com/kierantandi)

## 🙏 Acknowledgments

- Homebrew maintainers — genuinely transformative work
- Every open source developer whose tools are in here
- The countless Stack Overflow answers that made this possible
- Coffee. So much coffee.

---

*Built because manual setup is soul-destroying. Automated because life's too short.*
