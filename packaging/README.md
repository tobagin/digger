# Flatpak Packaging

This directory contains the Flatpak packaging files for Digger.

## Files

- **`io.github.tobagin.digger.yml`** - Production Flatpak manifest
- **`io.github.tobagin.digger.Devel.yml`** - Development Flatpak manifest  
- **`build-flatpak.sh`** - Build script for both manifests
- **`README.md`** - This file

## Build Script Usage

The build script (`build-flatpak.sh`) can build either development or production versions:

### Development Build
```bash
# Build and install development version
./build-flatpak.sh --dev --install

# Build, install, and run development version
./build-flatpak.sh --dev --install --run
```

### Production Build
```bash
# Build and install production version (default)
./build-flatpak.sh --install

# Build production version explicitly
./build-flatpak.sh --prod --install
```

### Available Options

- `--dev` - Build development version (io.github.tobagin.digger.Devel)
- `--prod` - Build production version (io.github.tobagin.digger) [default]
- `--install` - Install the built package using flatpak-builder --install
- `--run` - Run the application after building/installing
- `--user` - Build/install for current user [default]
- `--system` - Build/install system-wide (requires sudo)
- `--build-dir DIR` - Specify custom build directory
- `--verbose` - Show verbose build output
- `-h, --help` - Show help message

### Examples

```bash
# Quick development build and test
./build-flatpak.sh --dev --install --run

# Production build with custom build directory
./build-flatpak.sh --prod --build-dir my-build --install

# System-wide installation
./build-flatpak.sh --dev --system --install
```

## Manifest Differences

### Development Version (`io.github.tobagin.digger.Devel.yml`)
- Uses local source directory (type: dir, path: .)
- App ID: `io.github.tobagin.digger.Devel`
- Development branding (orange icon, "(Development)" suffix)
- Separate GSettings schema path

### Production Version (`io.github.tobagin.digger.yml`)
- Uses GitHub release archive (type: archive)
- App ID: `io.github.tobagin.digger`
- Standard branding
- Standard GSettings schema path

## Dependencies

Both manifests include the following dependencies:

1. **blueprint-compiler** - For compiling Blueprint UI templates (build-time only)
2. **libgee** - Vala collection library
3. **libuv** - Async I/O library (required by BIND)
4. **bind-dig** - DNS lookup utility
5. **digger-vala** - The main application

## Prerequisites

Ensure you have the GNOME Platform and SDK installed:

```bash
flatpak install flathub org.gnome.Platform//48 org.gnome.Sdk//48
```

The build script will check for these and install them automatically if missing.
