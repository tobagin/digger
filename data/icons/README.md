# Digger Application Icons

This directory contains all the application icons for Digger in various sizes following the freedesktop.org icon theme specification.

## Icon Hierarchy

```
data/icons/hicolor/
├── 16x16/apps/io.github.tobagin.digger.png      # Very small icons (toolbars)
├── 22x22/apps/io.github.tobagin.digger.png      # Small toolbar icons
├── 24x24/apps/io.github.tobagin.digger.png      # Small menu icons
├── 32x32/apps/io.github.tobagin.digger.png      # Standard small icons
├── 48x48/apps/io.github.tobagin.digger.png      # Medium icons
├── 64x64/apps/io.github.tobagin.digger.png      # Large icons
├── 128x128/apps/io.github.tobagin.digger.png    # Extra large icons
├── 256x256/apps/io.github.tobagin.digger.png    # High DPI medium
├── 512x512/apps/io.github.tobagin.digger.png    # High DPI large
└── symbolic/apps/io.github.tobagin.digger-symbolic.png  # Monochrome variant
```

## Usage

- **16x16 to 32x32**: Used in toolbars, small buttons, and compact interfaces
- **48x48 to 128x128**: Used in application launchers, file managers, and standard UI elements
- **256x256 to 512x512**: Used for high-DPI displays and larger interface elements
- **symbolic**: Used in GNOME Shell, system themes, and monochrome contexts

## Technical Details

- **Source**: Generated from `io.github.tobagin.digger.png` (1024x1024 RGBA)
- **Format**: PNG with alpha transparency
- **Generator**: ImageMagick (`magick` command)
- **Standard**: Follows freedesktop.org Icon Theme Specification
- **Symbolic**: Monochrome version for adaptive themes

## Installation

These icons are automatically installed by the Flatpak build process into `/app/share/icons/hicolor/` following the standard directory structure that desktop environments expect.