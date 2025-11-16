# Termux Configuration

This directory contains Termux app configuration files.

## Color Schemes

Two color schemes are available:

### Active Color Scheme
- **File**: `colors.properties`
- **Theme**: Molokai variant (vibrant colors with dark background)
- **Background**: `#212337`
- **Foreground**: `#EBFAFA`

### Alternative Color Scheme
- **File**: `colors-catppuccin.properties`
- **Theme**: Catppuccin Macchiato (pastel colors with dark background)
- **Background**: `#1E1E2E`
- **Foreground**: `#CDD6F4`

### Switching Color Schemes

To switch to the Catppuccin theme:

```bash
cd ~/.termux
mv colors.properties colors-molokai.properties
mv colors-catppuccin.properties colors.properties
termux-reload-settings
```

To switch back to Molokai:

```bash
cd ~/.termux
mv colors.properties colors-catppuccin.properties
mv colors-molokai.properties colors.properties
termux-reload-settings
```

## Termux Properties

The `termux.properties` file contains app-specific settings:

- **Font**: JetBrains Mono (14px)
- **UI**: Black theme enabled
- **Extra Keys**: Custom row with ESC, TAB, CTRL, ALT, arrows, and special symbols
- **Cursor**: Bar style with 500ms blink rate
- **Volume Keys**: Mapped to cursor control (up/down navigation)

### Key Customizations

The extra keys row provides:
- Quick access to ESC, TAB, CTRL, ALT
- Common symbols: `|`, `&`, `/`, `~`
- Arrow keys for navigation
- HOME and END keys

## Reloading Settings

After making changes to any configuration file, run:

```bash
termux-reload-settings
```

Or restart the Termux app.
