#!/usr/bin/env bash
# Flatpak build script for Digger
# Based on github.com/tobagin/digger.git structure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [--dev]

Build script for Digger Flatpak packages.

OPTIONS:
    --dev               Build development version (io.github.tobagin.digger.Devel)
    (no args)           Build production version (io.github.tobagin.digger) [default]
    -h, --help          Show this help message

EXAMPLES:
    # Build and install production version
    $0

    # Build and install development version  
    $0 --dev

EOF
}

# Determine mode
DEV_MODE=false
if [[ $# -eq 1 ]]; then
    case $1 in
        --dev)
            DEV_MODE=true
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
elif [[ $# -gt 1 ]]; then
    print_error "Too many arguments"
    show_usage
    exit 1
fi

# Determine script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Project root is the script directory
PROJECT_ROOT="$SCRIPT_DIR"

# Packaging directory is inside the project root
PACKAGING_DIR="$PROJECT_ROOT/packaging"

# Change to project root directory
cd "$PROJECT_ROOT"

# Set manifest and app ID based on mode
if [[ "$DEV_MODE" == "true" ]]; then
    MANIFEST="$PACKAGING_DIR/io.github.tobagin.digger.Devel.yml"
    APP_ID="io.github.tobagin.digger.Devel"
    BUILD_DIR="build-dir-dev"
    print_info "Building development version"
else
    MANIFEST="$PACKAGING_DIR/io.github.tobagin.digger.yml"
    APP_ID="io.github.tobagin.digger"
    BUILD_DIR="build-dir"
    print_info "Building production version"
fi

# Check if manifest exists
if [[ ! -f "$MANIFEST" ]]; then
    print_error "Manifest file not found: $MANIFEST"
    exit 1
fi

print_info "Using manifest: $(basename "$MANIFEST")"
print_info "Build directory: $BUILD_DIR"

# Check if required Flatpak dependencies are available
if ! command -v flatpak-builder &> /dev/null; then
    print_error "flatpak-builder is not installed"
    print_info "Please install it with: sudo dnf install flatpak-builder"
    exit 1
fi

# Check for required Flatpak runtimes
print_info "Checking for required Flatpak runtimes..."

if ! flatpak info --user org.gnome.Platform//48 &>/dev/null; then
    print_warning "GNOME Platform 48 not found, installing..."
    flatpak install --user flathub org.gnome.Platform//48 -y
fi

if ! flatpak info --user org.gnome.Sdk//48 &>/dev/null; then
    print_warning "GNOME SDK 48 not found, installing..."
    flatpak install --user flathub org.gnome.Sdk//48 -y
fi

# Print build command
print_info "Running: flatpak-builder --force-clean --install --user $BUILD_DIR $MANIFEST"
echo

# Run the build
if flatpak-builder --force-clean --install --user "$BUILD_DIR" "$MANIFEST"; then
    print_success "Build and installation completed successfully!"
    print_success "Package installed: $APP_ID"
    print_info "You can run it with: flatpak run $APP_ID"
else
    print_error "Build failed!"
    exit 1
fi