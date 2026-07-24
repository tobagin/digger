# Digger - Feature Roadmap & TODO List

This document outlines potential features and enhancements for Digger, organized by priority and implementation complexity.

---

## 🏆 High Priority Features (Most Impactful)

### 1. WHOIS Integration
**Impact**: High | **Effort**: Medium | **Status**: Completed ✅

Natural complement to DNS lookup, highly requested by users.

- [x] Integrate WHOIS protocol client
- [x] Create WHOIS result display widget
- [x] Add "WHOIS Lookup" button to main interface
- [x] Parse and format WHOIS data (registrar, dates, nameservers, contacts)
- [x] Support for different WHOIS servers per TLD
- [x] Cache WHOIS results (they change infrequently)
- [x] Add WHOIS to export formats

### 2. Export to dig Commands
**Impact**: Medium | **Effort**: Low | **Status**: Completed ✅

Educational feature helping users learn command-line equivalents.

- [x] Generate equivalent dig command syntax from current query
- [x] Include all advanced options in command
- [x] "Copy as dig command" button
- [x] Support for DoH curl commands
- [x] Command explanation tooltips
- [x] Batch command generation for batch lookups

---

## 💡 Quick Wins (Easy to Implement, High Value)

### Recent Domains Dropdown Enhancement
**Impact**: Low | **Effort**: Low | **Status**: Not Started

- [ ] Enhance autocomplete with visual recent domains list
- [ ] Show query count per domain
- [ ] Quick clear recent domains

### Query Templates & Macros
**Impact**: Medium | **Effort**: Medium | **Status**: Not Started

- [ ] Template creation UI
- [ ] Save complex query configurations
- [ ] Parameter substitution support
- [ ] Template library

### Keyboard Shortcut for Export
**Impact**: Low | **Effort**: Low | **Status**: Not Started

- [ ] Add Ctrl+E for quick export
- [ ] Export format selection dialog

---

## 🔒 DNS Security Tools

### DNS Leak Testing
**Impact**: Medium | **Effort**: Medium | **Status**: Not Started

- [ ] DNS leak detection algorithm
- [ ] Integration with leak testing services
- [ ] Visual leak test results
- [ ] Privacy recommendations

### DNS Hijacking Detection
**Impact**: Medium | **Effort**: Medium | **Status**: Not Started

- [ ] Baseline DNS response validation
- [ ] Tampering detection algorithms
- [ ] Multiple resolver verification
- [ ] Alert on suspicious responses

### Malware Domain Checking
**Impact**: High | **Effort**: Medium | **Status**: Not Started

- [ ] VirusTotal API integration
- [ ] Threat intelligence feed integration
- [ ] Reputation display in results
- [ ] Domain safety scoring
- [ ] Historical threat data

### DNS Tunneling Detection
**Impact**: Low | **Effort**: High | **Status**: Not Started

- [ ] Traffic pattern analysis
- [ ] Unusual query detection
- [ ] Entropy analysis of DNS queries
- [ ] Alert on potential tunneling activity

---

## 📊 Visualization & Analysis

### DNS Propagation Map
**Impact**: Medium | **Effort**: High | **Status**: Partially Completed (v2.8.0)

Basic propagation check across public resolvers shipped; geographic map still open.

- [x] Global DNS resolver network integration (8 public resolvers, parallel)
- [x] Consensus/disagreement detection across resolvers
- [ ] Geographic propagation visualization
- [ ] World map with resolver locations
- [ ] Propagation time estimates
- [ ] Export propagation reports

### Record Dependency Graph
**Impact**: Medium | **Effort**: Medium | **Status**: Not Started

- [ ] CNAME chain visualization
- [ ] NS delegation tree
- [ ] MX priority visualization
- [ ] Interactive graph navigation
- [ ] Export as SVG/PNG

### Geographic Query Routing Visualization
**Impact**: Low | **Effort**: High | **Status**: Not Started

- [ ] Map-based query path visualization
- [ ] Anycast routing display
- [ ] Latency heatmaps

### Timeline View for History
**Impact**: Low | **Effort**: Medium | **Status**: Not Started

- [ ] Calendar-based history view
- [ ] Query frequency heatmap
- [ ] Time-based filtering
- [ ] Export timeline data

---

## 🌐 Advanced DNSSEC Features

### DNSSEC Chain Visualization
**Impact**: Medium | **Effort**: High | **Status**: Partially Completed (v2.8.0)

Per-level chain-of-trust view shipped as a list; graphical diagram still open.

- [x] Trust chain visualization (root → TLD → domain), level-by-level
- [x] Signature validation status per level (DNSKEY/DS presence)
- [ ] Key relationship display
- [ ] Interactive chain exploration
- [ ] Export chain diagrams

### DNSSEC Debugging Tools
**Impact**: Medium | **Effort**: Medium | **Status**: Not Started

- [ ] Detailed validation failure breakdowns
- [ ] Key mismatch detection
- [ ] Expiration warnings
- [ ] Signature verification details

### Key Rollover Monitoring
**Impact**: Low | **Effort**: Medium | **Status**: Not Started

- [ ] DNSKEY expiration tracking
- [ ] Rollover schedule predictions
- [ ] Notification before key expiration

### TLSA/DANE Record Support
**Impact**: Low | **Effort**: Medium | **Status**: Not Started

- [ ] TLSA record querying
- [ ] Certificate validation via DANE
- [ ] TLSA record generator
- [ ] Certificate fingerprint verification

---

## 🖥️ DNS Cache Analysis

### Local DNS Cache Viewer
**Impact**: Medium | **Effort**: High | **Status**: Not Started

- [ ] System DNS cache inspection
- [ ] Cache entry listing
- [ ] TTL countdown display
- [ ] Cache size and statistics

### Cache Manipulation
**Impact**: Medium | **Effort**: Medium | **Status**: Not Started

- [ ] Flush entire DNS cache
- [ ] Flush specific cache entries
- [ ] Platform-specific cache commands (systemd-resolve, dscacheutil)

### Cache Statistics
**Impact**: Low | **Effort**: Medium | **Status**: Not Started

- [ ] Hit/miss rate tracking
- [ ] Most cached domains list
- [ ] Cache efficiency metrics

---

## 🌍 Domain Intelligence & Discovery

### Subdomain Enumeration
**Impact**: Medium | **Effort**: High | **Status**: Partially Completed (v2.8.0)

Wordlist-based discovery shipped; certificate-transparency and export still open.

- [x] Subdomain discovery algorithms
- [x] Common subdomain wordlist
- [x] DNS brute force (with bounded concurrency)
- [ ] Certificate transparency log integration
- [ ] Export discovered subdomains

### Domain Availability Checker
**Impact**: Low | **Effort**: Low | **Status**: Not Started

- [ ] Quick domain registration status check
- [ ] Bulk availability checking
- [ ] Suggest alternative domains

### DNS Zone Transfer Attempts
**Impact**: Low | **Effort**: Low | **Status**: Not Started

- [ ] AXFR zone transfer attempts
- [ ] Security misconfiguration detection
- [ ] Zone data display if successful
- [ ] Security recommendations

---

## 🔧 Developer Tools

### DNS Record Generator
**Impact**: Medium | **Effort**: Medium | **Status**: Not Started

- [ ] Interactive record creation wizard
- [ ] Syntax validation
- [ ] Common record templates
- [ ] Export as zone file entries

### TTL Calculator
**Impact**: Low | **Effort**: Low | **Status**: Not Started

- [ ] Optimal TTL recommendations
- [ ] TTL impact calculator
- [ ] Best practices guidance

### DNS Record Validator
**Impact**: Medium | **Effort**: Low | **Status**: Not Started

- [ ] Syntax validation before deployment
- [ ] RFC compliance checking
- [ ] Warning for common mistakes

### REST API Endpoint
**Impact**: Low | **Effort**: High | **Status**: Not Started

- [ ] Local REST API server
- [ ] Query endpoint (GET /query)
- [ ] History endpoint (GET /history)
- [ ] Favorites endpoint (GET /favorites)
- [ ] API documentation

---

## 📱 IPv6 Enhanced Features

### IPv6 Connectivity Testing
**Impact**: Medium | **Effort**: Low | **Status**: Not Started

- [ ] Verify IPv6 DNS resolution works
- [ ] IPv6 reachability testing
- [ ] Dual-stack capability detection

### Dual-Stack Comparison
**Impact**: Medium | **Effort**: Medium | **Status**: Not Started

- [ ] Compare IPv4 vs IPv6 responses side-by-side
- [ ] Performance comparison (latency)
- [ ] Detect inconsistencies between stacks

### IPv6 Reverse DNS Enhancement
**Impact**: Low | **Effort**: Low | **Status**: Not Started

- [ ] Enhanced PTR lookup for IPv6
- [ ] ip6.arpa domain generation
- [ ] IPv6 address format validation

---

## 🤝 Collaboration & Sharing

### Query Sharing
**Impact**: Low | **Effort**: Medium | **Status**: Not Started

- [ ] Generate shareable query links
- [ ] QR code generation for queries
- [ ] Import from shared links

### Report Generation
**Impact**: Medium | **Effort**: High | **Status**: Not Started

- [ ] Professional PDF report export
- [ ] DNS audit report templates
- [ ] Branding customization
- [ ] Multi-query reports

### Team Workspaces
**Impact**: Low | **Effort**: Very High | **Status**: Not Started

- [ ] Cloud-based shared favorites
- [ ] Shared query history
- [ ] Team member management
- [ ] Permission controls

---

## 📦 Import/Export Enhancements

### Import from Zone Files
**Impact**: Medium | **Effort**: Medium | **Status**: Not Started

- [ ] Parse BIND zone files
- [ ] Extract and query records
- [ ] Zone file validation
- [ ] Bulk import from zones

### Export to PowerDNS/BIND Format
**Impact**: Low | **Effort**: Medium | **Status**: Not Started

- [ ] Generate BIND zone file snippets
- [ ] PowerDNS configuration format
- [ ] Server-ready configuration output

### Cloud Storage Sync
**Impact**: Low | **Effort**: High | **Status**: Not Started

- [ ] Backup favorites to cloud (Nextcloud, Dropbox, etc.)
- [ ] Sync query history
- [ ] Conflict resolution

### Configuration Profiles
**Impact**: Low | **Effort**: Medium | **Status**: Not Started

- [ ] Export complete app settings
- [ ] Import settings from file
- [ ] Profile switching

---

## 📚 Educational Features

### DNS Learning Mode
**Impact**: Medium | **Effort**: Medium | **Status**: Not Started

- [ ] Explain record types in detail
- [ ] Interactive tooltips
- [ ] Contextual help system
- [ ] Link to DNS documentation

### Query Explainer
**Impact**: Medium | **Effort**: Low | **Status**: Not Started

- [ ] Break down query components
- [ ] Explain what each option does
- [ ] Show query flow diagram

### Best Practices Tips
**Impact**: Low | **Effort**: Low | **Status**: Not Started

- [ ] Suggest DNS configuration improvements
- [ ] Security recommendations
- [ ] Performance tips

### Interactive Tutorials
**Impact**: Low | **Effort**: High | **Status**: Not Started

- [ ] Guided tours for common tasks
- [ ] First-run tutorial
- [ ] Video/animation integration

---

## 📱 Mobile & Sync Features

### Cloud Sync Infrastructure
**Impact**: Low | **Effort**: Very High | **Status**: Not Started

- [ ] Cross-device sync backend
- [ ] Encryption for synced data
- [ ] Conflict resolution
- [ ] Sync status indicators

### Mobile Companion App
**Impact**: Low | **Effort**: Very High | **Status**: Not Started

- [ ] Android app development
- [ ] iOS app development
- [ ] Feature parity with desktop
- [ ] Mobile-optimized UI

### QR Code Import/Export
**Impact**: Low | **Effort**: Low | **Status**: Not Started

- [ ] Generate QR codes for queries
- [ ] QR code scanner integration
- [ ] Easy device-to-device transfer

---

## 🎨 UI/UX Enhancements

### Dark Mode Refinements
**Impact**: Low | **Effort**: Low | **Status**: Not Started

- [ ] Audit all custom icons for dark mode compatibility
- [ ] Ensure color contrast meets accessibility standards
- [ ] Test all dialogs in dark mode

### Accessibility Improvements
**Impact**: Medium | **Effort**: Medium | **Status**: Not Started

- [ ] Screen reader optimization
- [ ] Keyboard navigation enhancements
- [ ] High contrast mode support
- [ ] Font size scaling

### Custom Themes
**Impact**: Low | **Effort**: Medium | **Status**: Not Started

- [ ] User-defined color schemes
- [ ] Theme import/export
- [ ] Community theme sharing

---

## 🔧 Technical Improvements

### Performance Optimizations
**Impact**: Medium | **Effort**: Medium | **Status**: Ongoing

- [ ] Profile and optimize slow operations
- [ ] Reduce memory footprint
- [ ] Optimize large history/favorites lists
- [ ] Implement virtual scrolling for long lists

### Code Quality
**Impact**: Low | **Effort**: Ongoing | **Status**: Ongoing

- [x] Continuous integration (build on every push/PR)
- [ ] Increase test coverage
- [ ] Add unit tests for core services
- [ ] Integration testing framework
- [ ] Code documentation improvements

### Internationalization (i18n)
**Impact**: Medium | **Effort**: High | **Status**: Not Started

- [ ] Complete translation coverage
- [ ] Add more language translations
- [ ] RTL language support
- [ ] Community translation platform

---

## 📝 Documentation

### User Documentation
**Impact**: Medium | **Effort**: Medium | **Status**: In Progress

- [ ] Complete user manual
- [ ] Video tutorials
- [ ] FAQ section
- [ ] Troubleshooting guide

### Developer Documentation
**Impact**: Low | **Effort**: Medium | **Status**: Not Started

- [ ] Architecture documentation
- [ ] API documentation
- [ ] Contributing guidelines (enhanced)
- [ ] Code style guide

---

## 🗂️ Archive (Completed Features)

### ✅ v2.8.0 (2026-07-17)
- [x] DNS Propagation Check across 8 public resolvers with consensus detection
- [x] Subdomain Enumeration (wordlist-based, bounded concurrency)
- [x] DNSSEC Chain of Trust view (root → TLD → domain)
- [x] Domain Monitoring with change detection and desktop notifications
- [x] Security hardening: DoH parser out-of-bounds fix, input validation, export escaping, RFC 8484 DoH
- [x] Dead-code removal (~1,200 lines) and build CI on every push/PR
- [x] aarch64 deb/rpm release packages

### ✅ v2.7.0 – v2.7.1 (2026-06)
- [x] GNOME 50 runtime; bundled libuv 1.52.1 and whois 5.6.6
- [x] Default window height fix so the lookup button is fully visible

### ✅ v2.6.0 (2026-01-07)
- [x] DNS Blacklist (DNSBL) checking with parallel multi-provider queries
- [x] DNS Performance Monitoring with real-time latency graphs
- [x] WHOIS integration with caching and privacy-guard detection
- [x] Command export (dig / DoH curl)
- [x] Query presets
- [x] New application icons

### ✅ v2.3.0 (2025-10-20)
- [x] Two-page comparison dialog
- [x] Custom symbolic icons for server statistics
- [x] Semantic record type icons
- [x] Fixed UI freeze in comparison dialog
- [x] Set-based discrepancy detection

### ✅ v2.2.0 (2025-10-09)
- [x] Export Manager (JSON, CSV, TXT, Zone File)
- [x] Favorites System
- [x] Batch Lookup
- [x] Server Comparison
- [x] DNS-over-HTTPS support
- [x] DNSSEC validation

---

## 📊 Roadmap Summary

### Phase 1: Quick Wins (Q1 2025)
- Export to dig commands
- Query presets
- Keyboard shortcut enhancements
- WHOIS integration (start)

### Phase 2: Core Features (Q2-Q3 2025)
- WHOIS integration (complete)
- DNS Performance Monitoring
- DNSBL checking
- DNS Security tools (leak testing, hijacking detection)

### Phase 3: Advanced Features (Q4 2025)
- Domain monitoring & alerts
- DNSSEC visualization
- Performance analytics
- Report generation

### Phase 4: Platform Expansion (2026)
- Mobile companion apps
- Cloud sync infrastructure
- Team collaboration features
- REST API

---

## 🤝 Contributing

Interested in implementing any of these features? Check out [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to Digger.

---

## 📞 Feedback

Have ideas for features not listed here? Open an issue on GitHub or contact the maintainer!

**Last Updated**: 2026-07-24
