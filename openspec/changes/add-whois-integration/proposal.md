# Proposal: Add WHOIS Integration

## Overview
Add WHOIS protocol integration to provide domain registration information alongside DNS lookup results. This natural complement to DNS queries enables users to research domain ownership, registration dates, and nameserver authority without leaving the application.

## Motivation
Users performing DNS lookups frequently need additional context about domain registration:
- Who owns/manages the domain
- When was it registered/expires
- Which registrar manages it
- What are the authoritative nameservers

Currently, users must switch to external tools or websites for this information, breaking their workflow.

## Proposed Changes

### New Capability: `whois-lookup`

**Core Functionality**:
- WHOIS protocol client via subprocess (similar to existing dig integration)
- Parse WHOIS output for common fields (registrar, dates, nameservers, contacts)
- Display WHOIS results in expandable section of results view
- Support TLD-specific WHOIS servers
- Cache WHOIS results (they change infrequently)
- Include WHOIS data in export formats

**Architecture**:
- New service class: `src/services/WhoisService.vala` (~300 lines)
- New widget: `src/widgets/WhoisResultView.vala` (~200 lines Blueprint/Vala)
- Extend `ExportManager` to include WHOIS data in exports
- Use existing async/signal patterns from `DnsQuery`

**Dependencies**:
- `whois` command (bundle in Flatpak manifest, similar to dig)
- No new library dependencies

## Impact Analysis

### User Impact
**High Value**:
- One-click access to domain registration information
- Streamlined research workflow
- Professional use case for domain investigation

### Technical Impact
**Low Risk**:
- Follows established subprocess pattern (`DnsQuery`)
- Isolated service, no changes to core DNS functionality
- Additive feature, no breaking changes

### Testing Scope
- Test common TLDs: .com, .org, .net, .io
- Test country-code TLDs: .uk, .de, .jp
- Test error handling: unregistered domains, WHOIS server timeouts
- Test privacy-protected WHOIS responses
- Flatpak integration testing

## Implementation Strategy

### Tasks (3-4 days)
1. Add `whois` to Flatpak manifest dependencies
2. Create `WhoisService` class with subprocess integration
3. Implement WHOIS output parser (start with common registrar formats)
4. Create `WhoisResultView` widget with expandable UI
5. Integrate WHOIS button/section into main results view
6. Extend `ExportManager` to include WHOIS in JSON/CSV/TXT formats
7. Add GSettings option to enable/disable WHOIS auto-lookup
8. Add loading state and error handling UI

### Sequencing
- Build service layer first (testable independently)
- Add UI integration second
- Export integration last

## Alternatives Considered

### Web API Integration
**Rejected**: External dependencies, rate limiting, potential costs, privacy concerns

### Embedded WHOIS Library
**Rejected**: No mature Vala WHOIS libraries available, subprocess approach proven with dig

## Migration Path
No migration needed - purely additive feature.

**Settings**:
- Add `auto-whois-lookup` boolean setting (default: false)
- Add `whois-cache-ttl` integer setting (default: 86400 seconds / 24 hours)

## Success Criteria
- [ ] WHOIS lookups successfully retrieve data for top 10 TLDs
- [ ] Results display within 3 seconds for cached, 10 seconds for fresh lookups
- [ ] Error states gracefully handled (timeouts, no WHOIS data, etc.)
- [ ] WHOIS data exports correctly in all formats
- [ ] Feature works in Flatpak sandbox
- [ ] No performance impact on DNS query execution

## Risks and Mitigations

**Risk**: WHOIS format variability across registrars
**Mitigation**: Parse common fields first, add registrar-specific parsers incrementally

**Risk**: WHOIS server rate limiting/blocking
**Mitigation**: Implement caching, configurable delays, manual server override

**Risk**: Privacy-protected WHOIS (GDPR)
**Mitigation**: Display "Privacy Protected" message when contact info redacted

## Out of Scope (Future)
- Historical WHOIS data tracking
- WHOIS change notifications
- Bulk WHOIS lookups (separate from batch DNS)
- RDAP protocol support (modern WHOIS alternative)
