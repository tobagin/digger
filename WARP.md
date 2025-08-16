# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

digger-vala is a DNS lookup tool written in Vala using GTK4 and libadwaita. It provides an intuitive interface for performing DNS queries, viewing results, and managing query history. This is a Vala rewrite of the original digger project.

## Building and Development

### Prerequisites

Install the required dependencies:
```bash
# Fedora/RHEL
sudo dnf install vala meson gtk4-devel libadwaita-devel json-glib-devel libgee-devel

# Ubuntu/Debian
sudo apt install valac meson libgtk-4-dev libadwaita-1-dev libjson-glib-dev libgee-0.8-dev

# Arch Linux
sudo pacman -S vala meson gtk4 libadwaita json-glib gee
```

### Build Commands

#### Flatpak Build (Recommended)
```bash
# Install Flatpak and GNOME SDK (if not already installed)
sudo dnf install flatpak flatpak-builder
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.gnome.Platform//47 org.gnome.Sdk//47

# Build the Flatpak (Production)
flatpak-builder --user --install --force-clean builddir io.github.tobagin.digger.yml

# Build the Flatpak (Development)
flatpak-builder --user --install --force-clean builddir io.github.tobagin.digger.Devel.yml

# Run the Production Flatpak
flatpak run io.github.tobagin.digger

# Run the Development Flatpak
flatpak run io.github.tobagin.digger.Devel
```

#### Local Development Build
```bash
# Set up build directory (requires local dependencies)
meson setup builddir

# Compile the application
meson compile -C builddir

# Run the application
./builddir/digger-vala

# Install the application
meson install -C builddir

# Run tests (when implemented)
meson test -C builddir
```

### Development Workflow

1. **Building**: Use `meson compile -C builddir` after making changes
2. **Testing**: Run `./builddir/digger-vala` to test locally
3. **Debugging**: Use `G_MESSAGES_DEBUG=all ./builddir/digger-vala` for detailed logging
4. **Schema compilation**: After changing GSchema files, run `glib-compile-schemas data/`

## Architecture

### Core Components

- **Application (`src/application.vala`)**: Main GTK application class, handles app lifecycle and global actions
- **Window (`src/window.vala`)**: Main application window with UI layout, form handling, and user interactions
- **DnsQuery (`src/dns-query.vala`)**: Backend DNS query engine that wraps the system `dig` command
- **QueryHistory (`src/query-history.vala`)**: Persistent query history management with JSON storage
- **QueryResultView (`src/query-result-view.vala`)**: Results display widget with organized DNS record sections
- **AdvancedOptions (`src/advanced-options.vala`)**: Expandable options panel for advanced DNS settings

### Data Models

- **DnsRecord (`src/dns-record.vala`)**: Individual DNS record representation
- **QueryResult (`src/dns-record.vala`)**: Complete query result with all sections and metadata
- **RecordType/QueryStatus enums**: Type-safe representations of DNS record types and query states

### Key Features

- **DNS Record Types**: Support for A, AAAA, CNAME, MX, NS, PTR, TXT, SOA, SRV, ANY records
- **Advanced Options**: Reverse DNS lookup, trace queries, custom DNS servers, short output format
- **Query History**: Persistent history with search functionality stored in JSON format
- **Clipboard Integration**: One-click copying of DNS record values
- **Keyboard Shortcuts**: 
  - `Ctrl+L`: Focus domain entry
  - `Ctrl+R`: Repeat last query
  - `Escape`: Clear results
  - `Enter`: Submit query

## File Organization

```
src/
├── main.vala              # Application entry point
├── application.vala       # GTK Application class
├── window.vala           # Main window UI and logic
├── dns-query.vala        # DNS query backend
├── dns-record.vala       # Data models and enums
├── query-history.vala    # History management
├── query-result-view.vala # Results display widget
├── advanced-options.vala # Advanced options panel
└── config.vala.in        # Build configuration template

data/
├── icons/                # Application icons
├── *.desktop.in          # Desktop entry template
├── *.appdata.xml.in      # AppData metadata template
└── *.gschema.xml         # GSettings schema
```

## Dependencies and Technologies

- **Vala**: Modern programming language compiling to C
- **GTK4**: Cross-platform GUI toolkit with modern widgets
- **libadwaita**: GNOME's adaptive UI components and styling
- **GLib/GIO**: Core libraries for file I/O, async operations, and utilities
- **JSON-GLib**: JSON parsing and generation for history persistence
- **libgee**: Collection library providing ArrayList, HashMap, etc.
- **Meson**: Build system with dependency management

## DNS Integration

The application uses the system `dig` command for DNS resolution:
- Validates `dig` availability at startup
- Builds command arguments dynamically based on user input
- Parses structured `dig` output into organized result sections
- Handles various DNS error conditions (NXDOMAIN, SERVFAIL, timeouts)
- Supports advanced dig options like `+trace`, `+short`, reverse lookups

## UI Design Patterns

- **Adaptive Layout**: Uses libadwaita widgets that adapt to different screen sizes
- **Progressive Disclosure**: Advanced options hidden in expandable section
- **Immediate Feedback**: Real-time validation and toast notifications
- **Keyboard Navigation**: Full keyboard accessibility with logical tab order
- **Copy Integration**: Copy buttons with visual feedback via toasts

## Data Persistence

- **Query History**: JSON file stored in user data directory (`~/.local/share/digger/`)
- **Application Settings**: GSettings for window state and preferences
- **Automatic Cleanup**: History limited to 100 most recent queries

## Common Development Tasks

- **Adding new DNS record types**: Update `RecordType` enum and parsing logic
- **UI modifications**: Most widgets use programmatic creation rather than UI files
- **New query options**: Add properties to `AdvancedOptions` and wire to `DnsQuery`
- **Result formatting**: Modify `QueryResultView` and `DnsRecord.get_display_value()`
- **Keyboard shortcuts**: Add to `Application.construct()` accelerators

## Error Handling

The application handles several error conditions gracefully:
- Missing `dig` command with installation guidance
- Network connectivity issues
- Invalid domain/IP format validation
- DNS resolution failures with descriptive error messages
- JSON parsing errors for corrupted history files

## Testing Notes

When testing DNS functionality:
- Use public domains like `example.com` for reliable results
- Test various record types, especially MX records with priorities
- Verify error handling with invalid domains like `nonexistent.invalid`
- Test advanced options like custom DNS servers (`8.8.8.8`, `1.1.1.1`)
- Verify history persistence across application restarts
