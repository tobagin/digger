# Digger Screenshots

This directory contains screenshots of the Digger DNS lookup tool showcasing both dark and light themes.

## Image Format

All screenshots are combined images showing both themes:
- **Top-left diagonal**: Dark theme
- **Bottom-right diagonal**: Light theme

This format demonstrates the application's adaptive theming capabilities and ensures compatibility with both light and dark desktop environments.

## Screenshot Contents

### Application Interface
- `main-window.png` - Main application window with query interface
- `about.png` - About dialog showing application information

### DNS Record Types
- `A-lookup.png` - IPv4 address (A record) lookup example
- `AAAA-lookup.png` - IPv6 address (AAAA record) lookup example
- `MX-lookup.png` - Mail exchange (MX record) lookup with priorities
- `TXT-lookup.png` - Text (TXT record) lookup showing various text records
- `CNAME-lookup.png` - Canonical name (CNAME record) lookup showing aliasing
- `NS-lookup.png` - Name server (NS record) lookup showing authoritative servers
- `SOA-lookup.png` - Start of Authority (SOA record) lookup with zone information

## Creation Process

The screenshots were created using the `combine-screenshots.sh` script that:
1. Takes separate dark and light theme screenshots
2. Creates a diagonal mask dividing the image
3. Combines both themes into a single image using ImageMagick
4. Preserves image quality and dimensions

## Usage in Documentation

These screenshots are used in:
- **README.md**: Main project documentation with visual examples
- **MetaInfo XML**: App store listings and package manager displays
- **Marketing materials**: Project presentations and Flathub submission

## Image Specifications

- **Format**: PNG with transparency support
- **Theme division**: Diagonal split (top-left dark, bottom-right light)
- **Quality**: High resolution suitable for documentation and app stores
- **Accessibility**: Alt text provided for all images in documentation