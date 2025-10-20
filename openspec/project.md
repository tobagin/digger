# Project Context

## Purpose
Digger is an advanced DNS lookup tool that provides a modern, user-friendly graphical interface for performing DNS queries. The project aims to:
- Provide comprehensive DNS query capabilities with support for all major record types (A, AAAA, CNAME, MX, NS, PTR, TXT, SOA, SRV, DNSKEY, DS, RRSIG, ANY)
- Offer advanced features like DNS-over-HTTPS (DoH), DNSSEC validation, batch lookups, and server comparison
- Deliver native Linux performance through Vala while maintaining a clean, modern interface using GTK4 and libadwaita
- Replace command-line DNS tools with an intuitive desktop application that retains power-user features
- Support network diagnostics and troubleshooting with detailed error handling and response analysis

## Tech Stack
- **Language**: Vala (compiles to C for native performance)
- **UI Framework**: GTK4 (>= 4.6.0)
- **UI Components**: libadwaita 1.8+ (modern GNOME design)
- **UI Templates**: Blueprint (declarative UI markup)
- **Build System**: Meson (>= 0.58.0)
- **Distribution**: Flatpak (GNOME Platform/SDK 49)
- **Dependencies**:
  - gio-2.0 (GLib I/O)
  - gee-0.8 (libgee - collections library)
  - json-glib-1.0 (JSON parsing)
  - libsoup-3.0 (HTTP client for DoH)
  - BIND dig 9.16.48 (embedded DNS query tool)
  - libuv (dependency for BIND)

## Project Conventions

### Code Style
- **File Naming**: PascalCase for Vala files (e.g., `DnsQuery.vala`, `BatchLookupDialog.vala`)
- **Blueprint Files**: kebab-case for UI templates (e.g., `enhanced-query-form.blp`, `batch-lookup-dialog.blp`)
- **Namespacing**: All code resides in the `Digger` namespace
- **Class Naming**: PascalCase (e.g., `DnsQuery`, `QueryHistory`)
- **Method Naming**: snake_case (e.g., `perform_query`, `check_dig_available`)
- **Signal Naming**: snake_case (e.g., `query_completed`, `query_failed`)
- **Constants**: SCREAMING_SNAKE_CASE (e.g., `DIG_COMMAND`, `DEFAULT_TIMEOUT`)
- **Copyright Headers**: All Vala files include GPL-3.0 license header with copyright year and author
- **Comments**: Use `//` for single-line comments, `/* */` for multi-line blocks
- **Error Handling**: Defensive null checks for GSettings and defensive programming patterns throughout

### Architecture Patterns
- **Modular Organization**:
  - `src/dialogs/` - Top-level window and dialog classes
  - `src/models/` - Data structures (e.g., DnsRecord)
  - `src/services/` - Business logic (DNS queries, history, secure DNS, DNSSEC)
  - `src/managers/` - Feature orchestration (export, favorites, batch operations, comparison)
  - `src/widgets/` - Reusable UI components
  - `src/utils/` - Utility classes (theme management, DNS presets, domain suggestions)
- **Signal-Based Communication**: Services emit signals (e.g., `query_completed`, `query_failed`) for async operations
- **Async/Await**: Heavy use of async methods for non-blocking I/O operations
- **GSettings Integration**: Persistent configuration using GSettings schemas
- **Blueprint UI**: Declarative UI templates compiled to GTK XML resources
- **Resource Bundling**: UI files, icons, and schemas compiled into GResource bundles
- **Service Layer Pattern**: Separation between UI (dialogs/widgets) and business logic (services/managers)

### Testing Strategy
- Manual testing with various DNS queries and record types
- Test edge cases: NXDOMAIN, SERVFAIL, timeouts, invalid domains
- Verify DoH functionality with multiple providers
- Test DNSSEC validation with signed and unsigned domains
- Batch operation testing with multiple domains
- Flatpak testing in both production and development modes
- Cross-server comparison validation

### Git Workflow
- **Main Branch**: `main` - production-ready code
- **Commit Style**: Descriptive commit messages explaining the "why"
- **Recent Commits**: Focused on cleanup (removing config files), documentation updates, and icon improvements
- **Versioning**: Semantic versioning (currently v2.2.1)
- **Tags**: Version tags for releases (e.g., v2.1.4, v2.2.0)

## Domain Context

### DNS Concepts
- **Record Types**: Understanding of A, AAAA, CNAME, MX, NS, PTR, TXT, SOA, SRV, DNSKEY, DS, RRSIG records
- **DNSSEC**: DNS Security Extensions with chain of trust validation
- **DNS-over-HTTPS (DoH)**: RFC 1035 wire format over HTTPS for encrypted DNS queries
- **DNS Status Codes**: NXDOMAIN (non-existent domain), SERVFAIL (server failure), REFUSED, NOERROR
- **Reverse DNS**: PTR record lookups for IP-to-hostname resolution
- **Trace Queries**: Following DNS resolution path from root servers

### Application Architecture
- **dig Command Integration**: Embedded BIND dig tool executed via subprocess
- **Query Result Parsing**: Custom parsing of dig output to extract records and metadata
- **GResource System**: GTK resource compilation for bundling UI templates and assets
- **Flatpak Sandboxing**: Network and IPC permissions, filesystem isolation
- **libadwaita Widgets**: Adw.Application, Adw.PreferencesDialog, Adw.ActionRow, etc.
- **Blueprint Compilation**: `.blp` files compiled to `.ui` XML at build time

## Important Constraints

### Technical Constraints
- **GPL-3.0 License**: All code must be GPL-compatible
- **Linux Target**: Primarily targets Linux desktop environments
- **Flatpak-First**: Build and distribution designed around Flatpak
- **GNOME Platform 49**: Runtime dependency on specific GNOME platform version
- **dig Dependency**: Requires BIND dig command (embedded in Flatpak)
- **libadwaita 1.8+**: Uses modern libadwaita features (ShortcutsDialog API)
- **Vala Compilation**: Code must be valid Vala that compiles to C

### Design Constraints
- **GNOME HIG Compliance**: Follows GNOME Human Interface Guidelines
- **Adaptive Design**: UI should work across different window sizes
- **Accessibility**: Must work with keyboard navigation and screen readers
- **No Package Manager**: As a Flatpak, no system-level package dependencies

## External Dependencies

### DNS Infrastructure
- **System DNS Resolver**: Used when no custom server specified
- **DoH Providers**: Cloudflare (1.1.1.1), Google (8.8.8.8), Quad9 (9.9.9.9), custom endpoints
- **Root DNS Servers**: For trace queries following resolution path
- **Public DNS Servers**: Google, Cloudflare, Quad9, OpenDNS for comparison features

### Build and Distribution
- **Flathub**: Primary distribution channel (io.github.tobagin.digger)
- **GNOME SDK/Platform 49**: Build and runtime environment
- **ISC BIND**: dig command source (https://downloads.isc.org/isc/bind9/)
- **libuv**: BIND dependency (https://dist.libuv.org/)
- **libgee**: Collections library (https://download.gnome.org/sources/libgee/)

### Development Tools
- **blueprint-compiler**: Required for compiling .blp UI templates
- **flatpak-builder**: For building Flatpak packages
- **Meson**: Build configuration and compilation
- **Vala compiler**: valac for compiling Vala to C
