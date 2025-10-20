# Contributing to Digger

Thank you for your interest in contributing to Digger! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Architecture](#project-architecture)
- [Coding Guidelines](#coding-guidelines)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Pull Request Process](#pull-request-process)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [OpenSpec Workflow](#openspec-workflow)
- [Getting Help](#getting-help)

## Code of Conduct

This project adheres to a code of conduct that promotes a welcoming and inclusive environment. By participating, you are expected to:

- Be respectful and considerate of others
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Accept responsibility and apologize for mistakes
- Focus on what is best for the community

## Getting Started

### Prerequisites

- Basic understanding of Vala programming language
- Familiarity with GTK4 and libadwaita
- Git version control knowledge
- Flatpak for building and testing

### Finding Issues to Work On

- Check the [issue tracker](https://github.com/tobagin/digger/issues) for open issues
- Look for issues labeled `good first issue` for beginner-friendly tasks
- Issues labeled `help wanted` are particularly suitable for contributions
- Feel free to ask questions on any issue before starting work

## Development Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/digger.git
cd digger

# Add upstream remote
git remote add upstream https://github.com/tobagin/digger.git
```

### 2. Install Dependencies

No system dependencies are required! Digger uses Flatpak for building, which handles all dependencies automatically.

```bash
# Install Flatpak (if not already installed)
# Fedora/RHEL
sudo dnf install flatpak flatpak-builder

# Ubuntu/Debian
sudo apt install flatpak flatpak-builder

# Arch Linux
sudo pacman -S flatpak flatpak-builder

# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install GNOME SDK (automatically handled by build scripts)
flatpak install flathub org.gnome.Platform//49 org.gnome.Sdk//49
```

### 3. Build and Run

```bash
# Development build (with debug symbols and development app ID)
./scripts/build.sh --dev

# Build and run immediately
./scripts/build.sh --dev --run

# Production build
./scripts/build.sh

# Run development version
flatpak run io.github.tobagin.digger.Devel

# Run production version
flatpak run io.github.tobagin.digger
```

### 4. Create a Feature Branch

```bash
# Update your fork
git fetch upstream
git checkout main
git merge upstream/main

# Create a feature branch
git checkout -b feature/your-feature-name
```

## Project Architecture

Digger follows a clean, modular architecture:

```
src/
├── dialogs/          # Dialog windows (Window, PreferencesDialog, ComparisonDialog, etc.)
├── models/           # Data models (DnsRecord)
├── services/         # Business logic (DnsQuery, QueryHistory, SecureDns, DnssecValidator)
├── managers/         # Feature managers (ExportManager, FavoritesManager, BatchLookupManager)
├── widgets/          # UI components (EnhancedQueryForm, EnhancedResultView, etc.)
└── utils/            # Utility classes (ThemeManager, DnsPresets, ValidationUtils, etc.)

data/ui/
├── dialogs/          # Blueprint UI files for dialogs
└── widgets/          # Blueprint UI files for widgets
```

### Key Components

- **DnsQuery.vala**: Core DNS query execution using embedded `dig` command
- **ComparisonManager.vala**: Multi-server DNS comparison logic
- **BatchLookupManager.vala**: Batch DNS lookup orchestration
- **SecureDns.vala**: DNS-over-HTTPS implementation
- **DnssecValidator.vala**: DNSSEC validation logic
- **QueryHistory.vala**: Query history persistence and search

## Coding Guidelines

### Vala Code Style

#### File Naming
- Use **PascalCase** for all Vala files: `DnsQuery.vala`, `ComparisonDialog.vala`
- Match the class name: `class DnsQuery` → `DnsQuery.vala`

#### Code Organization
```vala
// 1. Namespace
namespace Digger {

    // 2. Class declaration with proper indentation
    public class DnsQuery : Object {

        // 3. Fields (private first, then public)
        private string domain;
        public int timeout { get; set; default = 5; }

        // 4. Signals
        public signal void query_completed(QueryResult result);

        // 5. Constructor
        public DnsQuery() {
            // Initialize
        }

        // 6. Public methods
        public async QueryResult? perform_query() {
            // Implementation
        }

        // 7. Private methods
        private void parse_response(string output) {
            // Implementation
        }
    }
}
```

#### Naming Conventions
- **Classes**: PascalCase (`DnsQuery`, `ComparisonDialog`)
- **Methods**: snake_case (`perform_query`, `get_server_display_name`)
- **Variables**: snake_case (`dns_server`, `query_result`)
- **Constants**: UPPER_SNAKE_CASE (`MAX_TIMEOUT`, `DEFAULT_SERVER`)
- **Private fields**: Prefix with underscore or mark as `private`

#### Error Handling
```vala
// Always use try-catch for operations that may fail
try {
    var result = yield dns_query.perform_query(domain, record_type);
    if (result != null) {
        display_results(result);
    }
} catch (Error e) {
    warning("Query failed: %s", e.message);
    show_error_message(e.message);
}
```

#### Null Safety
```vala
// Check for null before accessing
if (dns_server != null && dns_server.strip() != "") {
    use_server(dns_server);
}

// Use null-coalescing operator when appropriate
var server = dns_server ?? "8.8.8.8";
```

#### Async Operations
```vala
// Use async/yield for non-blocking operations
public async QueryResult? perform_query(string domain) {
    // Use yield for async calls
    var result = yield execute_dig_command(domain);

    // Explicit yield to GTK main loop for UI responsiveness
    if (needs_yield) {
        Timeout.add(50, () => {
            perform_query.callback();
            return false;
        });
        yield;
    }

    return result;
}
```

### Blueprint UI Guidelines

#### File Organization
- Place dialog UI files in `data/ui/dialogs/`
- Place widget UI files in `data/ui/widgets/`
- Use lowercase with hyphens: `comparison-dialog.blp`

#### Blueprint Best Practices
```blp
// Use template for main widget
template $DiggerComparisonDialog : Adw.Dialog {
    title: "DNS Server Comparison";
    content-width: 650;
    content-height: 550;

    // Proper indentation (2 spaces)
    Adw.ToolbarView {
        [top]
        Adw.HeaderBar header_bar {
            [title]
            Adw.WindowTitle {
                title: "Compare Servers";
            }
        }

        content: Box {
            orientation: vertical;
            spacing: 12;

            // Named widgets for code access
            Button compare_button {
                label: "Compare";
                styles ["suggested-action"]
            }
        };
    }
}
```

### GSettings Schema

When adding new settings:
```xml
<!-- data/io.github.tobagin.digger.gschema.xml -->
<key name="setting-name" type="s">
    <default>"default-value"</default>
    <summary>Brief description</summary>
    <description>Detailed description of the setting</description>
</key>
```

## Commit Message Guidelines

### Format

```
Short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain the problem that this commit is solving and why this
approach was chosen.

- Bullet points are okay
- Use imperative mood: "Add feature" not "Added feature"
- Reference issues: Fixes #123, Closes #456

Modified files:
- src/dialogs/ComparisonDialog.vala
- data/ui/dialogs/comparison-dialog.blp

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Examples of Good Commits

```
Fix UI freeze during DNS server comparison

The comparison dialog was freezing the UI for 3-15 seconds during
multi-server queries. This was caused by multiple concurrent dig
processes starving the GTK main loop.

Solution: Changed from parallel to sequential async queries with
explicit 50ms yield points between each query. This keeps the UI
fully responsive while slightly increasing total comparison time
(10-12s vs 3s).

Trade-off is acceptable for better user experience.

Fixes #234

Modified files:
- src/managers/ComparisonManager.vala
```

```
Add custom icons for comparison statistics

Added four new symbolic icons to enhance the visual presentation
of DNS comparison results:
- fastest-server-symbolic.svg
- slowest-server-symbolic.svg
- average-query-time-symbolic.svg
- query-time-symbolic.svg

Icons follow GNOME HIG guidelines and integrate with system theme.

Modified files:
- data/icons/hicolor/scalable/apps/*.svg (4 new files)
- data/meson.build
- src/dialogs/ComparisonDialog.vala
```

### Commit Message Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style/formatting changes
- **refactor**: Code refactoring
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

## Pull Request Process

### Before Submitting

1. **Test your changes thoroughly**
   - Build succeeds: `./scripts/build.sh --dev`
   - Application runs without crashes
   - Feature works as expected
   - No new compiler warnings introduced

2. **Update documentation**
   - Update README.md if adding new features
   - Update relevant Blueprint files
   - Add inline code comments for complex logic

3. **Check code quality**
   - Follow coding guidelines
   - Remove debug print statements
   - Ensure proper error handling

### Submitting a Pull Request

1. **Push your branch**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create the PR**
   - Go to the [repository](https://github.com/tobagin/digger)
   - Click "New Pull Request"
   - Select your feature branch
   - Fill out the PR template

3. **PR Title Format**
   ```
   [Type] Brief description

   Examples:
   [Feature] Add DNS-over-TLS support
   [Fix] Resolve memory leak in query history
   [Docs] Update installation instructions
   ```

4. **PR Description Template**
   ```markdown
   ## Description
   Brief description of what this PR does.

   ## Motivation
   Why is this change needed? What problem does it solve?

   ## Changes
   - List of changes
   - Another change

   ## Testing
   How was this tested?
   - [ ] Tested with various DNS record types
   - [ ] Tested with invalid inputs
   - [ ] Tested UI responsiveness

   ## Screenshots (if applicable)
   [Add screenshots for UI changes]

   ## Checklist
   - [ ] Code follows project style guidelines
   - [ ] Documentation updated
   - [ ] Build succeeds without errors
   - [ ] Tested thoroughly
   - [ ] No new compiler warnings

   ## Related Issues
   Fixes #123
   Related to #456
   ```

### Review Process

- Maintainers will review your PR within a few days
- Address any feedback or requested changes
- Once approved, your PR will be merged
- Your contribution will be credited in release notes

## Testing Guidelines

### Manual Testing

Always test these scenarios when making changes:

#### DNS Query Testing
```bash
# Test various record types
- A records: google.com, example.com
- AAAA records: google.com (IPv6)
- MX records: gmail.com
- CNAME records: www.github.com
- NS records: google.com
- TXT records: google.com, _dmarc.google.com
- SOA records: google.com
- PTR records: 8.8.8.8 (with reverse lookup enabled)
- SRV records: _xmpp-server._tcp.gmail.com
```

#### Error Handling Testing
```bash
# Invalid inputs
- Invalid domain: "not a domain!"
- Non-existent domain: "thisdomaindoesnotexist12345.com"
- Invalid DNS server: "256.1.1.1"
- Invalid record type combinations

# Network conditions
- Timeout scenarios (use slow DNS server)
- SERVFAIL responses
- NXDOMAIN responses
```

#### UI/UX Testing
```bash
# Responsiveness
- UI should remain responsive during queries
- Progress bars should update smoothly
- Window should be movable during operations

# State management
- Results should clear properly
- History should persist correctly
- Preferences should save and load
```

### Comparison Dialog Testing

When modifying comparison functionality:

```bash
# Test setup
1. Enter domain: google.com
2. Select record type: A
3. Enable all 5 DNS servers
4. Click "Compare DNS Servers"

# Verify
- [ ] UI stays responsive (can move window)
- [ ] Progress bar updates for each server
- [ ] Results display correctly on Results page
- [ ] Statistics show fastest/slowest/average
- [ ] Discrepancy detection works (test with domains returning different order)
- [ ] Export works (JSON, CSV, TXT)
- [ ] "New Comparison" button clears and returns to Setup page
- [ ] Multiple comparisons don't accumulate results
```

### Batch Lookup Testing

```bash
# Test with CSV file
domain,record_type
google.com,A
github.com,AAAA
gmail.com,MX

# Verify
- [ ] Import works correctly
- [ ] Progress tracking accurate
- [ ] Results display properly
- [ ] Export functionality works
- [ ] Cancellation works
```

## Documentation

### Code Documentation

```vala
/**
 * Performs an asynchronous DNS query for the specified domain.
 *
 * This method executes a DNS query using the embedded dig command
 * and parses the results into a structured format.
 *
 * @param domain The domain name to query (e.g., "example.com")
 * @param record_type The DNS record type to query (A, AAAA, MX, etc.)
 * @param dns_server Optional DNS server to use (null for system default)
 * @param reverse_lookup Enable reverse DNS lookup for IP addresses
 * @param trace_path Trace the delegation path from root servers
 * @param short_output Return minimal output format
 *
 * @return QueryResult containing parsed DNS records, or null on error
 *
 * @throws Error if the query fails or times out
 */
public async QueryResult? perform_query(
    string domain,
    RecordType record_type,
    string? dns_server = null,
    bool reverse_lookup = false,
    bool trace_path = false,
    bool short_output = false
) throws Error {
    // Implementation
}
```

### UI Documentation

Add comments in Blueprint files for complex structures:

```blp
// Two-page architecture for cleaner UX
// Page 1: Setup - Domain selection and server configuration
// Page 2: Results - Full-screen results display with statistics
Adw.ViewStack view_stack {
    Adw.ViewStackPage {
        name: "config";
        title: "Setup";
        // ...
    }
}
```

## OpenSpec Workflow

Digger uses OpenSpec for managing significant changes. If your contribution involves:

- Breaking changes
- New major features
- Architecture changes
- Performance/security work

Please follow the OpenSpec workflow:

1. **Read the OpenSpec documentation**
   ```bash
   cat openspec/AGENTS.md
   ```

2. **Create a proposal**
   ```bash
   openspec new your-change-name --title "Brief description"
   ```

3. **Follow the spec template**
   - Fill in problem statement
   - Describe proposed solution
   - List implementation tasks
   - Document testing strategy

4. **Get approval before coding**
   - Submit the spec for review
   - Discuss approach with maintainers
   - Iterate based on feedback

5. **Implement the approved spec**
   - Follow the implementation tasks
   - Keep tasks.md in sync
   - Reference the spec in commits

## Getting Help

### Communication Channels

- **GitHub Discussions**: Ask questions and discuss ideas at [Discussions](https://github.com/tobagin/digger/discussions)
- **Issue Tracker**: Report bugs or request features at [Issues](https://github.com/tobagin/digger/issues)
- **Documentation**: Check the [README](README.md) and inline code documentation

### Resources

- **Vala Documentation**: [Vala Tutorial](https://wiki.gnome.org/Projects/Vala/Tutorial)
- **GTK4 Documentation**: [GTK Docs](https://docs.gtk.org/gtk4/)
- **Libadwaita Documentation**: [Libadwaita Docs](https://gnome.pages.gitlab.gnome.org/libadwaita/)
- **Blueprint Documentation**: [Blueprint Compiler](https://jwestman.pages.gitlab.gnome.org/blueprint-compiler/)
- **GNOME HIG**: [Human Interface Guidelines](https://developer.gnome.org/hig/)

### Example Workflow

Here's a complete example of contributing a new feature:

```bash
# 1. Setup
git clone https://github.com/YOUR_USERNAME/digger.git
cd digger
git remote add upstream https://github.com/tobagin/digger.git

# 2. Create branch
git checkout -b feature/add-dns-over-tls

# 3. Build and test current version
./scripts/build.sh --dev --run

# 4. Make your changes
# - Edit src/services/SecureDns.vala
# - Update data/ui/dialogs/preferences-dialog.blp
# - Test thoroughly

# 5. Build and test your changes
./scripts/build.sh --dev --run

# 6. Commit
git add src/services/SecureDns.vala data/ui/dialogs/preferences-dialog.blp
git commit -m "feat: Add DNS-over-TLS support

Implemented DNS-over-TLS (DoT) as an alternative to DNS-over-HTTPS.
Uses GnuTLS for encrypted connections on port 853.

Added preferences UI for enabling/disabling DoT and selecting provider.

Modified files:
- src/services/SecureDns.vala
- data/ui/dialogs/preferences-dialog.blp

Fixes #123"

# 7. Push and create PR
git push origin feature/add-dns-over-tls
# Then create PR on GitHub
```

## Recognition

All contributors will be:
- Listed in the application's About dialog
- Credited in release notes
- Mentioned in CHANGELOG.md

Thank you for contributing to Digger! Your efforts help make DNS lookups better for everyone.

---

**Questions?** Open a [Discussion](https://github.com/tobagin/digger/discussions) or comment on an [Issue](https://github.com/tobagin/digger/issues).
