#!/bin/bash
# Icon verification script for Digger

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info "Verifying Digger application icons..."

# Expected sizes and their purposes
declare -A EXPECTED_SIZES=(
    ["16x16"]="Toolbar icons"
    ["22x22"]="Small toolbar icons"
    ["24x24"]="Menu icons"
    ["32x32"]="Standard small icons"
    ["48x48"]="Medium icons"
    ["64x64"]="Large icons"
    ["128x128"]="Extra large icons"
    ["256x256"]="High DPI medium"
    ["512x512"]="High DPI large"
    ["scalable"]="Original/vector (1024x1024)"
)

MISSING_ICONS=0
TOTAL_ICONS=0

print_info "Checking standard icon sizes..."

for size in "${!EXPECTED_SIZES[@]}"; do
    TOTAL_ICONS=$((TOTAL_ICONS + 1))
    icon_path="data/icons/hicolor/$size/apps/io.github.tobagin.digger.png"
    
    if [[ -f "$icon_path" ]]; then
        # Get actual dimensions
        if command -v identify >/dev/null 2>&1; then
            dimensions=$(identify -format "%wx%h" "$icon_path" 2>/dev/null || echo "unknown")
            file_size=$(du -h "$icon_path" | cut -f1)
            print_success "$size: $icon_path ($dimensions, $file_size) - ${EXPECTED_SIZES[$size]}"
        else
            file_size=$(du -h "$icon_path" | cut -f1)
            print_success "$size: $icon_path ($file_size) - ${EXPECTED_SIZES[$size]}"
        fi
    else
        print_error "$size: Missing $icon_path"
        MISSING_ICONS=$((MISSING_ICONS + 1))
    fi
done

# Check symbolic icon
TOTAL_ICONS=$((TOTAL_ICONS + 1))
symbolic_path="data/icons/hicolor/symbolic/apps/io.github.tobagin.digger-symbolic.png"
if [[ -f "$symbolic_path" ]]; then
    file_size=$(du -h "$symbolic_path" | cut -f1)
    print_success "symbolic: $symbolic_path ($file_size) - Monochrome variant"
else
    print_error "symbolic: Missing $symbolic_path"
    MISSING_ICONS=$((MISSING_ICONS + 1))
fi

# Summary
echo ""
print_info "Icon verification summary:"
print_info "Total expected icons: $TOTAL_ICONS"
print_info "Found icons: $((TOTAL_ICONS - MISSING_ICONS))"

if [[ $MISSING_ICONS -eq 0 ]]; then
    print_success "All icons are present! ✓"
    
    # Additional checks
    print_info "Running additional checks..."
    
    # Check if original source exists
    if [[ -f "io.github.tobagin.digger.png" ]]; then
        print_success "Source icon found: io.github.tobagin.digger.png"
    else
        print_error "Source icon missing: io.github.tobagin.digger.png"
    fi
    
    # Check directory structure
    if [[ -d "data/icons/hicolor" ]]; then
        icon_count=$(find data/icons/hicolor -name "*.png" | wc -l)
        print_success "Icon directory structure is correct ($icon_count PNG files total)"
    else
        print_error "Icon directory structure is missing"
    fi
    
    print_success "Icon verification completed successfully!"
    exit 0
else
    print_error "$MISSING_ICONS icons are missing!"
    print_error "Please run the icon generation process again."
    exit 1
fi