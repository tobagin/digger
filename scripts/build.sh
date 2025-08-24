#!/bin/bash

# Digger build script
# Usage: ./scripts/build.sh [--dev]

set -e

# Default to production build
BUILD_TYPE="prod"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            BUILD_TYPE="dev"
            shift
            ;;
        --help)
            echo "Usage: $0 [--dev]"
            echo "  --dev      Build development version (uses Devel manifest)"
            echo "Default: Build production version"
            echo ""
            echo "The Flatpak will always be installed after building."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set manifest based on build type
if [ "$BUILD_TYPE" = "dev" ]; then
    MANIFEST="packaging/io.github.tobagin.digger.Devel.yml"
    APP_ID="io.github.tobagin.digger.Devel"
    BUILD_DIR="build-dev"
    echo -e "\033[0;34m[INFO]\033[0m Building development version"
else
    MANIFEST="packaging/io.github.tobagin.digger.yml"
    APP_ID="io.github.tobagin.digger"
    BUILD_DIR="build"
    echo -e "\033[0;34m[INFO]\033[0m Building production version"
fi

echo -e "\033[0;34m[INFO]\033[0m Using manifest: $(basename $MANIFEST)"
echo -e "\033[0;34m[INFO]\033[0m Build directory: $BUILD_DIR"

# Check for required Flatpak runtimes
echo -e "\033[0;34m[INFO]\033[0m Checking for required Flatpak runtimes..."

# Build and install with Flatpak (always install)
echo -e "\033[0;34m[INFO]\033[0m Running: flatpak-builder --force-clean --install --user $BUILD_DIR $MANIFEST"
flatpak-builder --force-clean --install --user "$BUILD_DIR" "$MANIFEST"

echo -e "\033[0;32m[SUCCESS]\033[0m Build and installation complete!"
echo -e "\033[0;32m[SUCCESS]\033[0m Run with: flatpak run $APP_ID"