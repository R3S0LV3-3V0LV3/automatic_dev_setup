# Sudo Requirements & Handling

## Overview

The Automatic Dev Setup requires administrator privileges for specific system-level operations. The suite is designed to request sudo **once** at the beginning and maintain it throughout the installation process.

## When Sudo is Required

### Module-Specific Requirements

| Module | Sudo Operations |
|--------|-----------------|
| **01-system-bootstrap** | Software updates check, timezone configuration |
| **02-homebrew-foundation** | None (Homebrew handles its own) |
| **03-shell-environment** | Shell change (`chsh`) if needed |
| **05-development-stack** | Java symlink creation |
| **06-database-systems** | Service management (PostgreSQL, Redis, MongoDB) |
| **08-system-optimization** | Power management settings (`pmset`), DNS cache flush |
| **10-maintenance-setup** | LaunchAgent installation |
| **11-comprehensive-audit** | Bash installation (if `--update-bash` used) |

## How It Works

### Initial Request
```bash
./install.sh
# [Setup] This installation requires administrator privileges for certain operations.
# [Setup] You may be prompted for your password now.
Password: [enter your password]
```

### Sudo Persistence

The installer implements a "sudo keeper" — a background process that refreshes your sudo credentials every 50 seconds. This prevents repeated password prompts during the ~30-minute installation.

### Safety Features

1. **Single Entry Point**: Password requested once at start
2. **Automatic Cleanup**: Sudo keeper terminated on script exit
3. **Non-Root Execution**: Scripts run as your user, only elevating when necessary
4. **Bypass Option**: Set `ADS_NO_SUDO=1` to skip sudo operations (limited functionality)

## Manual Installation Without Sudo

If you prefer not to grant sudo access, you can run individual modules that don't require it:

```bash
# These modules work without sudo
./core/02-homebrew-foundation.sh
./core/04-python-ecosystem.sh
./core/07-project-templates.sh
./core/09-integration-validation.sh
```

## Troubleshooting

### "Unable to obtain sudo privileges"

Check if you're in the admin group:
```bash
groups $(whoami) | grep -q admin && echo "You're an admin" || echo "Not an admin"
```

### Repeated Password Prompts

If you're getting repeated prompts, the sudo keeper may have failed. Run:
```bash
# Extend sudo timeout manually
sudo sh -c 'echo "Defaults timestamp_timeout=30" >> /etc/sudoers.d/ads_temp'
# Run installation
./install.sh
# Clean up after
sudo rm -f /etc/sudoers.d/ads_temp
```

### Running Without Sudo

For development/testing without sudo:
```bash
export ADS_NO_SUDO=1
./install.sh  # Will skip sudo-requiring operations
```

## Security Notes

- Your password is **never** stored or logged
- Sudo credentials are only valid for the current terminal session
- The sudo keeper process is killed automatically on exit
- No permanent sudoers modifications are made

---

*The suite is designed to be transparent about when and why it needs elevated privileges. Every sudo operation is logged and can be audited in `~/.automatic_dev_setup/logs/`*