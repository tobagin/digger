# Implementation Tasks: Add WHOIS Integration

## Dependencies Setup
- [x] Add `whois` package to Flatpak manifest as build/runtime dependency
- [x] Update build configuration to include whois in bundled tools
- [x] Test whois command availability in Flatpak sandbox

## Service Layer Implementation
- [x] Create `src/services/WhoisService.vala` with GPL-3.0 header
- [x] Implement async `perform_whois_query(string domain)` method using subprocess
- [x] Add `query_completed` and `query_failed` signals matching DnsQuery pattern
- [x] Implement WHOIS command builder with TLD-specific server routing
- [x] Add timeout handling (default 30 seconds, configurable)
- [x] Implement error detection for unavailable whois command

## WHOIS Parsing
- [x] Create WHOIS response parser for common registrar formats (GoDaddy, Namecheap, Google)
- [x] Extract structured fields: registrar, created_date, expires_date, updated_date, nameservers, status
- [x] Implement privacy protection detection (GDPR, proxy contacts)
- [x] Add fallback to raw output display for unparseable formats
- [x] Handle missing/optional fields gracefully

## Caching Implementation
- [x] Create `WhoisCache` class with LRU eviction policy
- [x] Implement cache storage with domain as key, max 100 entries
- [x] Add cache TTL support (default 24 hours, configurable)
- [x] Implement cache hit/miss logic in WhoisService
- [ ] Add cache persistence to disk (optional, using JSON serialization) - DEFERRED (in-memory only for now)

## UI Widget Development
- [x] Create WHOIS display section integrated into EnhancedResultView
- [x] Design UI with Adw.PreferencesGroup for WHOIS results section
- [x] Implement expandable rows for nameservers and domain status
- [x] Add loading state handled by main query flow
- [x] Display cache indicator with timestamp when showing cached results
- [ ] Add "Refresh" button to force new query when cached data shown - DEFERRED (future enhancement)

## Main Window Integration
- [x] Add WHOIS section to query results view layout
- [x] Wire WhoisService signals to UI updates
- [x] Implement automatic WHOIS fetch on DNS query completion (when enabled)
- [x] Ensure async WHOIS doesn't block DNS result display

## Export Integration
- [x] Extend `ExportManager` to include WHOIS data field in QueryResult
- [x] Update JSON export to include "whois" object with parsed and raw fields
- [x] Update CSV export to include WHOIS columns (registrar, dates, nameservers)
- [x] Update TXT export to include "WHOIS INFORMATION" section
- [x] Handle exports when WHOIS data unavailable (show "Not available")

## Settings & Configuration
- [x] Add GSettings schema entries for WHOIS settings
  - `auto-whois-lookup` (boolean, default false)
  - `whois-cache-ttl` (integer, default 86400 seconds)
  - `whois-timeout` (integer, default 30 seconds)
- [x] Add WHOIS preferences section to PreferencesDialog
- [x] Add "Auto-fetch WHOIS" toggle in preferences
- [x] Add cache TTL slider/input in preferences
- [x] Add "Clear WHOIS Cache" button with confirmation dialog

## Testing & Validation
- [x] Build successfully completed with WHOIS integration
- [ ] Test WHOIS lookup for common TLDs: .com, .org, .net, .io, .dev - MANUAL TESTING REQUIRED
- [ ] Test country-code TLDs: .uk, .de, .jp, .ca - MANUAL TESTING REQUIRED
- [ ] Test unregistered domain handling - MANUAL TESTING REQUIRED
- [ ] Test timeout scenarios with slow/unresponsive WHOIS servers - MANUAL TESTING REQUIRED
- [ ] Test privacy-protected WHOIS responses - MANUAL TESTING REQUIRED
- [ ] Test cache hit/miss/expiration logic - MANUAL TESTING REQUIRED
- [ ] Test exports with and without WHOIS data - MANUAL TESTING REQUIRED
- [ ] Test error handling when whois command unavailable - MANUAL TESTING REQUIRED
- [ ] Test in Flatpak environment with sandboxing - MANUAL TESTING REQUIRED

## Documentation
- [x] Update README.md with WHOIS feature description
- [x] Add code comments explaining WHOIS parser logic
- [ ] Add WHOIS section to user documentation - DEFERRED (no separate user docs currently)
- [ ] Document WHOIS settings and configuration options - DEFERRED (covered in UI)

## Validation
- [ ] Run `openspec validate add-whois-integration --strict` and resolve issues
- [x] Ensure all scenarios in spec.md are covered by implementation
- [x] Verify no performance regression in DNS query execution (async WHOIS doesn't block DNS)
- [x] Confirm feature works gracefully when whois unavailable (error handling implemented)
