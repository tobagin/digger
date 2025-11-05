# Proposal: Add Export to dig Commands

## Overview
Add the ability to generate equivalent command-line syntax (dig commands and DoH curl commands) from GUI query parameters. This educational feature helps users transition from GUI to CLI tools and understand the underlying commands being executed.

## Motivation
Users who learn DNS concepts through Digger's GUI may want to:
- Understand what command-line equivalent would produce the same results
- Transition to using `dig` directly in scripts or SSH sessions
- Share query configurations with CLI-only users
- Learn command-line DNS tools in a low-stakes environment

Currently, there's no way to see or copy the equivalent dig command that would produce the same query as the GUI configuration.

## Proposed Changes

### New Capability: `command-export`

**Core Functionality**:
- Generate dig command syntax from current query parameters
- Include all advanced options (record type, server, DNSSEC, trace, DoH, etc.)
- Generate curl syntax for DoH queries
- "Copy as dig command" button in results view
- Support batch command generation for batch lookups
- Command syntax explanation tooltips (educational)

**Architecture**:
- Extend `ExportManager` with command generation methods
- Add utility class `CommandGenerator` in `src/utils/`
- Add UI button/menu item in results view
- Use GTK clipboard integration for copy functionality

**Dependencies**:
- No new dependencies (uses existing dig command syntax knowledge)

## Impact Analysis

### User Impact
**Medium Value**:
- Educational benefit for learning CLI tools
- Enables sharing queries with CLI users
- Supports script automation workflows

### Technical Impact
**Very Low Risk**:
- Pure utility function, no state changes
- Extends existing `ExportManager` pattern
- Simple string generation logic
- No subprocess execution or file I/O

### Testing Scope
- Verify generated dig commands match GUI parameters
- Test all record types (A, AAAA, MX, TXT, etc.)
- Test advanced options (DNSSEC, trace, custom server, DoH)
- Test DoH curl command generation
- Validate command syntax with actual dig execution
- Test batch command generation

## Implementation Strategy

### Tasks (2-3 days)
1. Create `src/utils/CommandGenerator.vala` class
2. Implement `generate_dig_command()` method for standard queries
3. Implement `generate_doh_curl_command()` for DoH queries
4. Add command generation to `ExportManager`
5. Add "Copy as dig Command" button to results view
6. Implement clipboard copy functionality
7. Add toast notification on successful copy
8. Support batch command generation (outputs shell script)
9. Add optional command explanation tooltips

### Sequencing
- Build CommandGenerator utility first (unit testable)
- Integrate with ExportManager
- Add UI integration last

## Alternatives Considered

### Show Generated Command Always
**Rejected**: Clutters UI for users who don't care about CLI equivalents. Opt-in button is cleaner.

### Include in Standard Export Formats
**Rejected**: Command generation is distinct from data export. Separate feature is clearer.

## Migration Path
No migration needed - purely additive feature.

**No new settings required** - functionality is straightforward enough to not need configuration.

## Success Criteria
- [ ] Generated dig commands execute successfully and produce equivalent results
- [ ] All query parameters correctly translated to dig flags
- [ ] DoH queries generate valid curl commands
- [ ] Batch lookups export as executable shell scripts
- [ ] Command copied to clipboard on button click
- [ ] Toast notification confirms successful copy

## Examples

### Simple Query
**GUI**: Query google.com, A record, default server
**Generated**: `dig google.com A`

### Advanced Query
**GUI**: Query example.org, MX record, 1.1.1.1 server, DNSSEC enabled
**Generated**: `dig @1.1.1.1 example.org MX +dnssec`

### DoH Query
**GUI**: Query cloudflare.com, AAAA record, Cloudflare DoH
**Generated**:
```bash
curl -H 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=cloudflare.com&type=AAAA'
```

### Batch Export
**GUI**: Batch lookup of 3 domains
**Generated**:
```bash
#!/bin/bash
dig example.com A
dig google.com MX
dig cloudflare.com AAAA
```

## Risks and Mitigations

**Risk**: Generated commands don't match GUI behavior exactly
**Mitigation**: Comprehensive test suite comparing outputs, regression testing

**Risk**: DoH curl syntax becomes outdated
**Mitigation**: Use well-documented RFC 8484 wire format or dns-json format

## Out of Scope (Future)
- Reverse translation (import dig commands to GUI)
- Command history/templates
- Command explanation in detail (just basic tooltips for now)
- Support for other DNS tools (nslookup, host, etc.)
