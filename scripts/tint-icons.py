#!/usr/bin/env python3
"""
Script to create reddish-tinted versions of PNG icons for development builds.
"""

import os
import sys
try:
    from PIL import Image, ImageEnhance, ImageOps
except ImportError:
    print("Error: PIL/Pillow is required. Install with: pip install Pillow")
    sys.exit(1)
import argparse


def apply_red_tint(input_path, output_path, tint_strength=0.3):
    """Apply a red tint to a PNG image."""
    try:
        # Open the image
        with Image.open(input_path) as img:
            # Convert to RGBA if not already
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # Create a red overlay
            red_overlay = Image.new('RGBA', img.size, (255, 0, 0, int(255 * tint_strength)))
            
            # Blend the original image with the red overlay
            tinted = Image.alpha_composite(img, red_overlay)
            
            # Save the result
            tinted.save(output_path, 'PNG')
            print(f"Created tinted icon: {output_path}")
            
    except Exception as e:
        print(f"Error processing {input_path}: {e}")
        return False
    
    return True


def main():
    parser = argparse.ArgumentParser(description='Apply red tint to PNG icons')
    parser.add_argument('input', help='Input PNG file or directory containing icon hierarchy')
    parser.add_argument('output', help='Output PNG file or directory for tinted icons')
    parser.add_argument('--tint', type=float, default=0.25, help='Tint strength (0.0-1.0)')
    
    args = parser.parse_args()
    
    input_path = args.input
    output_path = args.output
    
    if not os.path.exists(input_path):
        print(f"Error: Input {input_path} does not exist")
        return 1
    
    # Handle single file processing
    if os.path.isfile(input_path) and input_path.endswith('.png'):
        # Create output directory if needed
        output_dir = os.path.dirname(output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
        
        if not apply_red_tint(input_path, output_path, args.tint):
            return 1
        return 0
    
    # Handle directory processing (original functionality)
    if os.path.isdir(input_path):
        # Create output directory structure
        os.makedirs(output_path, exist_ok=True)
        
        # Process all PNG files in the hierarchy
        for root, dirs, files in os.walk(input_path):
            for file in files:
                if file.endswith('.png'):
                    file_input_path = os.path.join(root, file)
                    
                    # Recreate directory structure in output
                    rel_path = os.path.relpath(root, input_path)
                    output_root = os.path.join(output_path, rel_path)
                    os.makedirs(output_root, exist_ok=True)
                    
                    file_output_path = os.path.join(output_root, file)
                    
                    if not apply_red_tint(file_input_path, file_output_path, args.tint):
                        return 1
        
        print("Icon tinting completed successfully!")
        return 0
    
    print(f"Error: {input_path} is not a PNG file or directory")
    return 1


if __name__ == '__main__':
    sys.exit(main())