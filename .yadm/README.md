# Yadm Configuration for Termux

This directory contains yadm configuration files for managing dotfiles in Termux on Android.

## Files

- **bootstrap**: Bootstrap script that runs after `yadm clone --bootstrap`
- **config**: Yadm configuration settings
- **README.md**: This file

## Usage

### First-time setup

```bash
# Clone the dotfiles repository with yadm
yadm clone --bootstrap https://github.com/Ven0m0/dot-termux.git
```

The bootstrap script will automatically:
1. Set up directory structure
2. Generate SSH keys if needed
3. Configure Zsh
4. Set up Sheldon plugins
5. Make bin scripts executable
6. Apply Termux-specific settings

### Update dotfiles

```bash
# Pull latest changes
yadm pull --rebase

# Or use the setup script
bash ~/setup.sh
```

### Manage dotfiles

```bash
# Check status
yadm status

# Add files
yadm add <file>

# Commit changes
yadm commit -m "message"

# Push changes
yadm push
```

## Bootstrap Script

The bootstrap script (`.yadm/bootstrap`) automatically runs when you clone with the `--bootstrap` flag. It:

- Creates necessary directories (.ssh, bin, .config, etc.)
- Generates SSH keys
- Sets up Zsh as default shell
- Compiles Zsh configuration files
- Locks Sheldon plugins
- Makes bin scripts executable
- Applies Termux-specific settings

## Ignore Patterns

Files matching patterns in `.yadmignore` are not tracked by yadm. This includes:

- Log files
- Cache directories
- SSH keys
- Shell history
- Compiled files
- Temporary files

## Alt Files

Yadm supports alternate files for different environments using the `##` syntax:

```
.bashrc##class.Termux
.bashrc##os.Linux
```

These allow you to maintain different versions of the same file for different systems.
