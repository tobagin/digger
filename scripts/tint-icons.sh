#!/bin/bash
# Script to create reddish-tinted versions of PNG icons using ImageMagick
# Usage: tint-icons.sh input.png output.png [tint_strength]

INPUT="$1"
OUTPUT="$2"
TINT_STRENGTH="${3:-25}"  # Default to 25% tint

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
    echo "Usage: $0 input.png output.png [tint_strength]"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file $INPUT does not exist"
    exit 1
fi

# Create output directory if needed
OUTPUT_DIR=$(dirname "$OUTPUT")
if [ -n "$OUTPUT_DIR" ] && [ "$OUTPUT_DIR" != "." ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Check if ImageMagick is available
if ! command -v convert >/dev/null 2>&1; then
    echo "Warning: ImageMagick not found, copying original file"
    cp "$INPUT" "$OUTPUT"
    exit 0
fi

# Apply red tint using ImageMagick
# This creates a red overlay and blends it with the original image
convert "$INPUT" \
    \( +clone -fill "rgba(255,0,0,0.${TINT_STRENGTH})" -colorize 100% \) \
    -compose over -composite \
    "$OUTPUT"

if [ $? -eq 0 ]; then
    echo "Created tinted icon: $OUTPUT"
else
    echo "Error: Failed to create tinted icon, copying original"
    cp "$INPUT" "$OUTPUT"
fi