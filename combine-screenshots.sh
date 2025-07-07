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
    
    # Get dimensions of the dark image (assuming both are the same size)
    width=$(identify -format "%w" "$dark_image")
    height=$(identify -format "%h" "$light_image")
    
    # Create a diagonal mask
    # The mask will be white (255) for dark theme area and black (0) for light theme area
    convert -size "${width}x${height}" xc:black \
        -fill white \
        -draw "polygon 0,0 ${width},0 0,${height}" \
        /tmp/diagonal_mask.png
    
    # Apply the mask to combine the images
    # Dark image where mask is white, light image where mask is black
    convert "$light_image" "$dark_image" /tmp/diagonal_mask.png \
        -composite "$output_image"
    
    # Clean up temporary mask
    rm -f /tmp/diagonal_mask.png
    
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