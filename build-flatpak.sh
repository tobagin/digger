#!/bin/bash
# Flatpak build script for Digger

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

# Default values
BUILD_DEV=false
INSTALL=false
CLEAN=false
RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            BUILD_DEV=true
            shift
            ;;
        --install)
            INSTALL=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --run)
            RUN=true
            shift
            ;;
        --help|-h)
            echo "Flatpak build script for Digger"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dev      Build development version"
            echo "  --install  Install after building"
            echo "  --clean    Clean build directory before building"
            echo "  --run      Run application after building/installing"
            echo "  --help     Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --dev --install --run    # Build dev version, install and run"
            echo "  $0 --clean --install        # Clean build, install production version"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if flatpak-builder is installed
if ! command -v flatpak-builder &> /dev/null; then
    print_error "flatpak-builder is not installed"
    print_info "Install it with: sudo apt install flatpak-builder (Ubuntu/Debian)"
    print_info "                sudo dnf install flatpak-builder (Fedora)"
    print_info "                sudo pacman -S flatpak-builder (Arch)"
    exit 1
fi

# Check if required runtimes are installed
RUNTIME="org.gnome.Platform//48"
SDK="org.gnome.Sdk//48"

print_info "Checking for required Flatpak runtimes..."

if ! flatpak list --runtime | grep -q "org.gnome.Platform.*48"; then
    print_warning "GNOME Platform runtime not found, installing..."
    flatpak install -y flathub "$RUNTIME" || {
        print_error "Failed to install GNOME Platform runtime"
        exit 1
    }
fi

if ! flatpak list --runtime | grep -q "org.gnome.Sdk.*48"; then
    print_warning "GNOME SDK not found, installing..."
    flatpak install -y flathub "$SDK" || {
        print_error "Failed to install GNOME SDK"
        exit 1
    }
fi

print_success "Required runtimes are installed"

# Determine manifest and app ID
if [ "$BUILD_DEV" = true ]; then
    MANIFEST="io.github.tobagin.digger.dev.yml"
    APP_ID="io.github.tobagin.digger.dev"
    print_info "Building development version"
else
    MANIFEST="io.github.tobagin.digger.yml"
    APP_ID="io.github.tobagin.digger"
    print_info "Building production version"
fi

# Clean build directory if requested
if [ "$CLEAN" = true ]; then
    print_info "Cleaning build directory..."
    rm -rf build-dir
    print_success "Build directory cleaned"
fi

# Build arguments
BUILD_ARGS="--force-clean"
if [ "$INSTALL" = true ]; then
    BUILD_ARGS="$BUILD_ARGS --install --user"
    print_info "Will install after building"
fi

# Build the Flatpak
print_info "Building Flatpak package..."
print_info "Manifest: $MANIFEST"
print_info "App ID: $APP_ID"

if flatpak-builder build-dir "$MANIFEST" $BUILD_ARGS; then
    print_success "Flatpak build completed successfully"
else
    print_error "Flatpak build failed"
    exit 1
fi

# Run the application if requested
if [ "$RUN" = true ]; then
    if [ "$INSTALL" = true ]; then
        print_info "Running installed application..."
        flatpak run "$APP_ID"
    else
        print_warning "Cannot run application: not installed"
        print_info "Use --install flag to install the application"
    fi
fi

print_success "Script completed successfully"

# Show next steps
echo ""
print_info "Next steps:"
if [ "$INSTALL" = false ]; then
    echo "  • Install: flatpak install --user build-dir/$APP_ID.flatpak"
fi
echo "  • Run: flatpak run $APP_ID"
echo "  • Uninstall: flatpak uninstall --user $APP_ID"
echo "  • List installed: flatpak list --user"