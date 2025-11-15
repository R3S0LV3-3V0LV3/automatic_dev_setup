# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2024-10-28

### Added
- Comprehensive audit module (11-comprehensive-audit.sh) for system compliance
- Bash update functionality in preflight.sh with --update-bash flag
- ShellCheck compliance automation with auto-fixes
- Performance optimisations for all shell scripts
- Essential modern CLI utilities (hyperfine, glow, entr, mkcert, etc.)
- Google Cloud SDK integration
- Proper GitHub documentation (README, LICENSE, CONTRIBUTING)
- .gitignore and .gitattributes for repository management

### Changed
- Enhanced preflight script with Bash compilation from source
- Updated Brewfile to remove unwanted applications (Kitty, Firefox, Brave, iTerm2)
- Improved script headers with proper author attribution
- Optimized module execution with better error handling

### Removed
- Redundant applications from default installation
- Temporary files and caches from repository
- IDE-specific configuration files

## [3.0.0] - 2024-10-01

### Added
- Modular architecture with 10 independent modules
- Intelligent dependency management system
- Performance and standard installation modes
- Comprehensive validation suite
- Automated maintenance setup with launchd
- Project template system
- Database systems module (PostgreSQL, Redis, MongoDB)

### Changed
- Complete refactor of installation process
- Improved error handling and recovery
- Enhanced shell environment configuration
- Updated to latest versions of all tools

## [2.0.0] - 2024-07-01

### Added
- Support for Apple Silicon Macs
- Python ecosystem management with pyenv
- Container tooling with Colima
- Modern CLI utilities (eza, bat, ripgrep, etc.)

### Changed
- Migrated from bash to more robust shell scripting
- Improved Homebrew package management
- Enhanced system optimisation routines

## [1.0.0] - 2024-01-01

### Added
- Initial release
- Basic Homebrew installation
- Core development tools
- Shell configuration
- Python setup
- Basic validation

---

*For detailed information about each release, please refer to the [GitHub Releases](https://github.com/kierantandi/automatic_dev_setup/releases) page.*
