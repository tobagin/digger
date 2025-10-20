# Changelog

All notable changes to Digger will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.3.0] - 2025-10-20

### Added
- **Custom Icons** - Added fastest-server, slowest-server, average-query-time, and query-time symbolic icons
- **Semantic Record Type Icons** - Visual icons for DNS record types (A, AAAA, MX, CNAME, NS, TXT, SOA, PTR, SRV)
- **System Default Display** - Shows "System Default (localhost)" for clarity when using default DNS server
- **Menu Integration** - Added Batch Lookup and Compare DNS Servers to Tools menu for better discoverability

### Changed
- **Redesigned Comparison Dialog** - Two-page architecture (Setup → Results) for cleaner, focused interface
- **Sequential Async Queries** - Comparison uses 50ms yields between queries to keep UI fully responsive
- **Reusable Rows Pattern** - Statistics rows created once and updated instead of removed/recreated
- **Set-Based Discrepancy Detection** - Order-independent comparison eliminates false positives
- Migrated from PNG to SVG application icon for better scalability
- Updated build system to install scalable SVG icon
- Removed PNG icon variants from build configuration

### Fixed
- **Critical UI Freeze** - Comparison dialog no longer freezes UI during multi-server queries
- **Results Accumulation Bug** - Comparison results now properly clear between runs
- **Discrepancy False Positives** - DNS records in different order no longer trigger false discrepancy warnings

### Improved
- **Enhanced Export** - Full JSON/CSV/TXT export with smart filename generation for comparison results
- **Performance Optimization** - Reusable widgets eliminate creation/destruction overhead in results display
- Icon quality on high-DPI displays
- Reduced package size by using single SVG icon instead of multiple PNG variants

## [2.2.0] - 2025-10-09

### Added
- **Export Manager** - Export query results to JSON, CSV, plain text, or DNS zone file formats
- **Favorites System** - Star and save frequently queried domains with record types
- **Batch Lookup** - Import and query multiple domains from CSV/TXT files with progress tracking
- **Server Comparison** - Compare DNS responses across multiple servers with discrepancy detection
- **DNS-over-HTTPS (DoH)** - Secure DNS queries with support for Cloudflare, Google, Quad9, and custom endpoints
- **DNSSEC Validation** - Verify DNSSEC chain of trust with DNSKEY, DS, and RRSIG record validation
- **Advanced Preferences** - Configure DoH providers and DNSSEC validation settings
- **Enhanced About Dialog** - Comprehensive about dialog with automatic release notes display

### Changed
- Updated keyboard shortcuts to Libadwaita 1.8 ShortcutsDialog API
- Renamed all Vala files to PascalCase naming convention
- Organized source code into logical folders (dialogs, models, services, managers, widgets, utils)
- Organized Blueprint UI files into dialogs and widgets folders
- Moved screenshots to data folder for better organization

### Improved
- Stability with defensive null checks for GSettings
- Enhanced metainfo with comprehensive v2.2.0 release notes
- Better error handling throughout the application

## [2.1.4] - 2025-09-18

### Added
- Comprehensive project links: help, donations, contact, and contribution
- Enhanced AppStream metadata for better app store integration

### Improved
- Project visibility and user support resources

## [2.1.3] - 2025-09-18

### Changed
- Updated to GNOME runtime version 49

### Improved
- Compatibility with latest GNOME platform

## [2.1.2] - 2025-09-15

### Fixed
- Application crash when changing DNS servers via combo row dropdown
- Application crash when using DNS quick preset buttons (Google, Cloudflare, Quad9)
- Index out of bounds error in DNS server selection handler

### Improved
- DNS server dropdown stability and reliability

## [2.1.1] - 2025-08-25

### Added
- Complete GitHub Actions automation for Flatpak releases with zero-maintenance workflow
- Automatic Flathub PR creation on tag push with cross-repository integration
- Implemented proper branch-based PR creation for protected repositories
- GitHub API integration for automated pull request creation
- Enhanced manifest validation and error handling with comprehensive checks
- Automated branch cleanup to prevent conflicts
- External data checker for dependency updates and automatic version detection
- Professional What's New dialog with About integration
- Comprehensive Flatpak-Flathub automation guide for developers
- Automatic commit hash and version tracking

### Changed
- Convert appdata.xml to metainfo.xml format for standards compliance
- Simplified preferences dialog layout with cleaner page groupings
- Streamlined automation workflow with simplified GitHub Actions
- More reliable and maintainable automation system with manual control over updates

### Fixed
- Workflow to properly handle Flathub's master branch requirements
- Git push conflicts and improved branch handling for manifest updates
- Fast-forward issues with enhanced workflow robustness

### Improved
- Zero-maintenance releases with full Flathub integration

## [2.1.0] - 2025-08-24

### Added
- Comprehensive DNS behavior defaults: reverse lookup, trace path, short output, auto-clear form
- Configurable query timeout setting (5-60 seconds) with real-time application
- Default DNS server preference with full preset integration
- Display customization: query time display, TTL highlighting, compact results layout
- Auto-clear form functionality to clear domain field after successful queries
- Comprehensive preference validation and fallback mechanisms

### Changed
- Completely reorganized preferences into 4 logical pages: General, DNS Settings, Display, and Data
- Synchronized record type lists between preferences and query form for consistency
- Enhanced settings initialization with proper timing to prevent null reference errors
- Improved preferences loading and saving with dynamic record type support

### Fixed
- Critical bug where default record type preference wasn't being applied on startup
- GLib settings initialization issues in development builds

## [2.0.9] - 2025-08-24

### Added
- "What's New in Version X.X.X" alert dialog on first run after update

### Changed
- Replaced About dialog auto-navigation with clean AlertDialog for release notes
- Improved release notes formatting with compact bullet points
- Better text conversion from HTML with single-line spacing
- Cleaner presentation without empty rows between items

### Improved
- Automatic display with 500ms delay for smooth transition

## [2.0.8] - 2025-08-24

### Added
- Comprehensive keyboard shortcuts including F1 for About and Ctrl+, for Preferences
- Dynamic release notes loading from appdata/metainfo XML files
- Automatic release notes version tracking and display
- Enhanced About dialog with developers, designers, and artists credits
- Source code link to About dialog for easy repository access
- GTK Project Team and Contributors to acknowledgements
- Application description (comments) field to About dialog

### Changed
- Replaced separate What's New dialog with automatic About dialog display on version updates
- Simplified keyboard shortcuts dialog with cleaner text-based display
- Updated website URL to new GitHub Pages location
- Reorganized build scripts to scripts folder for better project structure

### Removed
- Redundant What's New functionality in favor of unified About dialog

### Improved
- Version detection for showing release notes on first run after update

## [2.0.7] - 2025-08-24

### Added
- Comprehensive keyboard shortcuts dialog with individual key badges and Ctrl+? access
- What's New dialog system that automatically shows new features on version updates
- Support questions link to GitHub Discussions for community help
- Integrated What's New access directly from About dialog for better discoverability
- Dynamic content loading from application metadata for future releases

### Changed
- Completely reorganized main menu with logical grouping and visual separators
- Enhanced keyboard shortcuts display with separate labels for each key combination
- Improved dialog layouts with professional header bars and fixed action buttons

### Improved
- Enhanced About dialog with acknowledgements to GNOME, libadwaita, Vala, BIND, and GTK teams

## [2.0.6] - 2025-08-17

### Changed
- Updated application screenshots with latest interface improvements
- Fixed repository URLs to point to correct GitHub location
- Corrected homepage and issue tracker links in AppData
- Updated about dialog URLs for consistency

## [2.0.5] - 2025-08-17

### Fixed
- Restored correct developer name to "Thiago Fernandes"
- Fixed project license to proper "GPL-3.0-or-later" SPDX identifier
- Restored original summary text for consistency

### Improved
- Flathub review compatibility by maintaining established metadata

## [2.0.4] - 2025-08-17

### Fixed
- AppStream screenshot URLs to point to correct repository
- Added proper XML language attributes for AppStream compliance
- Improved XML formatting to meet AppStream specification
- Resolved flatpak-builder-lint validation issues

## [2.0.3] - 2025-08-17

### Changed
- Fixed AppStream screenshot URLs for proper web validation
- Corrected repository URLs throughout documentation
- Updated README with accurate version information and installation instructions

### Improved
- Documentation clarity and removed obsolete information

## [2.0.2] - 2025-08-17

### Added
- OARS content rating for AppStream compliance

### Changed
- Fixed screenshot references to use bundled local files
- Removed unnecessary Flatpak filesystem permissions
- Enhanced README with comprehensive screenshots showcase

### Improved
- AppStream metadata validation

## [2.0.1] - 2025-08-17

### Added
- Comprehensive application screenshots showcasing all major features

### Changed
- Enhanced autocomplete dropdown behavior for better user interaction
- Improved DNS error handling for NXDOMAIN and other response statuses
- Fixed history icon theme adaptation for proper light/dark mode support
- Cleaned up Flatpak permissions following security best practices

### Improved
- General UI polish and stability improvements

## [2.0.0] - 2025-08-17

### Added
- Complete rewrite in Vala for improved performance and native integration
- Advanced DNS options including reverse lookups and trace queries
- Comprehensive query history with search and filtering capabilities
- Support for additional DNS record types (SRV, PTR)
- Dynamic app ID system with blueprint UI templates
- Better keyboard shortcuts and productivity features
- Optimized for better desktop and mobile compatibility

### Changed
- Enhanced modern GTK4/libadwaita interface with improved user experience
- Improved domain autocomplete functionality
- Enhanced clipboard integration and one-click copying

### Improved
- Native performance through Vala implementation
- Better integration with GNOME desktop environment

## [1.0.1] - 2025-07-14

### Changed
- Refreshed application icon with improved visual design

### Improved
- Better integration with modern desktop environments

## [1.0.0] - 2025-07-10

### Added
- Query history with advanced search and filtering
- Advanced DNS query options and configurations
- Modern GTK4/libadwaita interface
- Full support for all common DNS record types

## [0.2.2] - 2025-07-10

### Changed
- Removed scalable icon directory references
- Updated icon documentation and verification scripts

## [0.2.1] - 2025-07-10

### Fixed
- Corrected version information in about dialog
- Updated Flatpak manifest
- Ensured version consistency across components

## [0.2.0] - 2025-07-10

### Added
- Bundled dig command (BIND 9.16.48)

### Changed
- Eliminated system DNS tool dependencies

### Improved
- Sandbox compatibility

## [0.1.0] - 2025-07-07

### Added
- Initial release
- Support for A, AAAA, MX, TXT, NS, CNAME, and SOA record types
- Custom DNS server specification
- GTK4/LibAdwaita interface
- Structured results display

---

## Release Types

- **Major** (X.0.0): Breaking changes, major rewrites, or significant architectural changes
- **Minor** (0.X.0): New features, enhancements, and non-breaking changes
- **Patch** (0.0.X): Bug fixes, minor improvements, and maintenance updates

## Links

- [GitHub Repository](https://github.com/tobagin/digger)
- [Issue Tracker](https://github.com/tobagin/digger/issues)
- [Flathub Page](https://flathub.org/apps/io.github.tobagin.digger)
