#!/bin/bash

# Script to remove black backgrounds from screenshots and make them transparent

set -e

SCREENSHOTS_DIR="screenshots"

echo "Making screenshot backgrounds transparent..."

# Process each screenshot
for screenshot in "$SCREENSHOTS_DIR"/*.png; do
    if [[ -f "$screenshot" ]]; then
        filename=$(basename "$screenshot")
        echo "Processing: $filename"
        
        # Remove black background with some fuzz tolerance for anti-aliased edges
        magick "$screenshot" -fuzz 10% -transparent black "$screenshot"
        
        echo "Made transparent: $filename"
    fi
done

echo "All screenshots processed successfully!"
echo "Black backgrounds removed and made transparent."