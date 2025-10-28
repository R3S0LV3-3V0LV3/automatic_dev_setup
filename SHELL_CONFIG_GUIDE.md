# Shell Configuration Guide

## Configuration File Hierarchy

### Loading Order and Purpose

```
Login Shell (Terminal.app, SSH):
1. /etc/profile (system-wide)
2. ~/.profile (POSIX-compliant, universal)
3. ~/.zprofile (zsh-specific login)
4. ~/.zshrc (zsh interactive)

Non-Login Shell (new terminal tab/window):
1. ~/.zshrc (zsh interactive only)

Script Execution:
- No configuration files loaded by default
- Must explicitly source if needed
```

## File Purposes and Content

### ~/.profile
**Purpose:** POSIX-compliant configuration for maximum compatibility
**Loaded by:** sh, bash, dash, and zsh (if no .zprofile exists)
**Contains:**
- Core environment variables (LANG, LC_ALL)
- Default programs (EDITOR, VISUAL, PAGER)
- XDG base directories
- Development tool paths (Pyenv, Cargo, Go, etc.)
- System-wide PATH modifications
- Cross-shell compatible settings

### ~/.zprofile
**Purpose:** Zsh-specific login shell configuration
**Loaded by:** zsh login shells only
**Contains:**
- Zsh-specific environment setup
- Homebrew initialization
- Development tool paths with zsh syntax
- Architecture-specific flags (Apple Silicon)
- Security and privacy settings
- Project-specific directories

### ~/.zshrc
**Purpose:** Interactive zsh configuration
**Loaded by:** All interactive zsh shells
**Contains:**
- Oh-My-Zsh configuration
- Shell completions
- Aliases (git, docker, development)
- Interactive functions
- Prompt customization (Powerlevel10k)
- Tool initializations requiring shell functions

## Best Practices

### What Goes Where

#### Environment Variables & PATH
- **Universal:** → `.profile` (POSIX syntax)
- **Zsh-specific:** → `.zprofile` (can use zsh features)
- **Interactive only:** → `.zshrc` (prompts, completions)

#### Tool Initialization
- **Path exports:** → `.profile` or `.zprofile`
- **Interactive features:** → `.zshrc`
- **Completions:** → `.zshrc`

#### Aliases & Functions
- **Always:** → `.zshrc` (interactive use only)
- **Never:** → `.profile` or `.zprofile`

### Performance Considerations

1. **Minimize login shell overhead:** Keep `.profile` and `.zprofile` lean
2. **Cache completions:** Use daily completion dumps (as configured)
3. **Lazy load when possible:** Defer expensive operations
4. **Avoid duplication:** Don't repeat PATH additions

### Debugging

```bash
# Check load order
zsh -xl  # Login shell with trace
zsh -x   # Interactive shell with trace

# Verify PATH
echo $PATH | tr ':' '\n' | nl

# Check for duplicates
echo $PATH | tr ':' '\n' | sort | uniq -d

# Profile startup time
zsh -i -c exit  # Time interactive startup
time zsh -l -c exit  # Time login shell
```

## Current Configuration Summary

### Structure Consistency
All configuration files now follow:
- Clear section headers with separators
- Logical grouping of related settings
- Consistent commenting style
- Proper conditional checks for paths

### Key Improvements Made
1. **`.zprofile`:** Restructured with clear sections matching `.zshrc` style
2. **`.profile`:** POSIX-compliant with proper conditionals
3. **Separation of concerns:** Each file serves its intended purpose
4. **Path management:** Consistent PATH building with existence checks
5. **Tool initialization:** Proper placement based on requirements

### Maintenance Tips
- Keep aliases and functions in `.zshrc` only
- Add new PATH entries with existence checks
- Use POSIX syntax in `.profile` for compatibility
- Document any non-standard configurations
- Regularly audit for duplicate PATH entries