#!/bin/bash

# Script to combine dark and light screenshots diagonally
# The diagonal will split the image: top-left will be dark theme, bottom-right will be light theme

set -e

SCREENSHOTS_DIR="screenshots"

# Function to combine two images diagonally
combine_diagonal() {
    local dark_image="$1"
    local light_image="$2"
    local output_image="$3"
    
    echo "Combining $dark_image and $light_image -> $output_image"
    
    # Get dimensions of the images (assuming both are the same size)
    width=$(magick identify -format "%w" "$dark_image")
    height=$(magick identify -format "%h" "$dark_image")
    
    echo "Image dimensions: ${width}x${height}"
    
    # Start with light image as base (preserves original alpha/transparency)
    cp "$light_image" "$output_image"
    
    # Create mask for diagonal triangle
    magick -size "${width}x${height}" xc:none \
        -fill white \
        -draw "polygon 0,0 ${width},0 0,${height}" \
        /tmp/mask.png
    
    # Extract triangle from dark image with transparency preserved
    magick "$dark_image" /tmp/mask.png -alpha off -compose copy_opacity -composite /tmp/triangle.png
    
    # Composite triangle onto the base image
    magick "$output_image" /tmp/triangle.png -compose over -composite "$output_image"
    
    # Clean up
    rm -f /tmp/mask.png /tmp/triangle.png
    
    echo "Created: $output_image"
}

# List of screenshot pairs to combine
declare -A screenshots=(
    ["A-lookup"]="A-lookup"
    ["AAAA-lookup"]="AAAA-lookup" 
    ["CNAME-lookup"]="CNAME-lookup"
    ["MX-lookup"]="MX-lookup"
    ["NS-lookup"]="NS-lookup"
    ["SOA-lookup"]="SOA-lookup"
    ["TXT-lookup"]="TXT-lookup"
    ["about"]="about"
    ["main-window"]="main-window"
)

# Combine each pair
for key in "${!screenshots[@]}"; do
    dark_file="${key}-dark.png"
    light_file="${key}-light.png"
    output_file="$SCREENSHOTS_DIR/${screenshots[$key]}.png"
    
    if [[ -f "$dark_file" && -f "$light_file" ]]; then
        combine_diagonal "$dark_file" "$light_file" "$output_file"
    else
        echo "Warning: Missing files for $key (looking for $dark_file and $light_file)"
    fi
done

echo "All screenshots combined successfully!"
echo "Combined screenshots saved in: $SCREENSHOTS_DIR/"