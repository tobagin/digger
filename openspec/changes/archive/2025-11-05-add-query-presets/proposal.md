# Proposal: Add Query Presets

## Overview
Add pre-configured query templates that allow users to quickly execute common DNS lookup patterns with a single click. Users can use default presets for typical scenarios and create custom presets for their specific workflows.

## Motivation
Users frequently perform the same types of DNS queries with similar configurations:
- "Check if mail is configured" (MX records)
- "Verify DNSSEC" (DNSKEY + DS records with validation)
- "Find authoritative nameservers" (NS records)
- "Check SPF/DMARC" (TXT records for specific subdomains)
- "Reverse IP lookup" (PTR records)

Currently, users must manually configure domain, record type, and advanced options each time. This is repetitive and error-prone for common tasks.

## Proposed Changes

### New Capability: `query-presets`

**Core Functionality**:
- Pre-configured query templates with name, description, and parameters
- Default system presets for common scenarios (5-7 built-in)
- User-defined custom preset creation
- Preset management UI (create, edit, delete, reorder)
- Quick access via dropdown menu or keyboard shortcuts
- GSettings persistence for user presets

**Default Presets**:
1. **Check Mail Servers** - MX records query
2. **Verify DNSSEC** - DNSKEY + DS records with DNSSEC validation
3. **Find Nameservers** - NS records query
4. **Check SPF Record** - TXT records for domain (SPF detection)
5. **Reverse IP Lookup** - PTR record template (user enters IP)
6. **Trace Resolution Path** - A record with +trace enabled
7. **All Records** - ANY record type (with deprecation note)

**Architecture**:
- New manager class: `src/managers/PresetManager.vala` (~250 lines)
- Preset data model: Simple struct or class with name, description, record type, options
- GSettings integration for user preset storage (JSON serialization)
- UI widget: Preset dropdown in main query form
- Preset management dialog: Create/edit/delete interface

**Dependencies**:
- No new dependencies (uses existing GSettings and GTK)

## Impact Analysis

### User Impact
**Medium-High Value**:
- Significant time savings for repetitive queries
- Reduced configuration errors
- Onboarding benefit (new users learn common query patterns)
- Power user efficiency gains

### Technical Impact
**Low Risk**:
- Self-contained manager class following established patterns
- GSettings storage matches existing preferences approach
- UI integration is additive, no changes to core query logic

### Testing Scope
- Test all default presets execute correctly
- Test custom preset creation, editing, deletion
- Test preset persistence across app restarts
- Test preset dropdown UI and keyboard navigation
- Test preset application to query form (all fields populated correctly)

## Implementation Strategy

### Tasks (3-4 days)
1. Create `PresetManager` class with preset storage and retrieval
2. Define default preset configurations
3. Implement GSettings schema for user preset storage (JSON array)
4. Create preset data model (struct/class)
5. Add preset dropdown widget to main query form
6. Create preset management dialog (create/edit/delete UI)
7. Implement preset application logic (populate query form from preset)
8. Add keyboard shortcuts for favorite presets (Ctrl+1, Ctrl+2, etc.)
9. Add preset reordering functionality (drag-and-drop or up/down buttons)

### Sequencing
- Build PresetManager and data model first (testable independently)
- Implement default presets
- Add UI dropdown integration
- Build management dialog last

## Alternatives Considered

### File-Based Preset Storage
**Rejected**: GSettings provides better integration with existing preferences system, automatic validation, and simpler API.

### Query History as Presets
**Rejected**: History is passive (what was done), presets are active (what should be done). Different use cases.

### Template Variables
**Considered but deferred**: Allow presets to have variables like `${domain}` for substitution. Adds complexity; implement basic presets first, add variables in future if needed.

## Migration Path
No migration needed - purely additive feature.

**Settings Schema**:
- Add `user-presets` key storing JSON array of preset objects
- Each preset: `{name, description, record_type, dns_server, reverse_lookup, trace_path, dnssec, short_output}`

## Success Criteria
- [ ] Default presets available immediately after installation
- [ ] Users can create custom presets via management dialog
- [ ] Presets persist across application restarts
- [ ] Preset selection populates query form correctly with all parameters
- [ ] Keyboard shortcuts (Ctrl+1-9) trigger first 9 presets
- [ ] Preset dropdown is accessible via keyboard navigation
- [ ] No performance impact on query execution

## Examples

### Example Preset: "Check Mail Servers"
```json
{
  "name": "Check Mail Servers",
  "description": "Query MX records to verify mail server configuration",
  "record_type": "MX",
  "dns_server": null,
  "reverse_lookup": false,
  "trace_path": false,
  "dnssec": false,
  "short_output": false,
  "icon": "mail-icon"
}
```

### Example Preset: "Verify DNSSEC"
```json
{
  "name": "Verify DNSSEC",
  "description": "Check DNSKEY and DS records with validation",
  "record_type": "DNSKEY",
  "dns_server": null,
  "reverse_lookup": false,
  "trace_path": false,
  "dnssec": true,
  "short_output": false,
  "icon": "security-icon"
}
```

### Example User Preset: "Check CDN (Cloudflare)"
```json
{
  "name": "Check CDN (Cloudflare)",
  "description": "Verify if domain is using Cloudflare CDN",
  "record_type": "A",
  "dns_server": "1.1.1.1",
  "reverse_lookup": false,
  "trace_path": false,
  "dnssec": false,
  "short_output": false,
  "icon": "network-icon"
}
```

## User Workflow

### Using a Preset
1. User clicks preset dropdown in query form
2. Selects "Check Mail Servers"
3. Record type automatically changes to MX
4. All other options set according to preset
5. User enters domain and clicks Query

### Creating a Custom Preset
1. User configures a complex query (specific server, DNSSEC, etc.)
2. Clicks "Save as Preset" button
3. Enters preset name and description
4. Preset saved to GSettings
5. Preset appears in dropdown immediately

### Managing Presets
1. User opens Preferences → Presets tab
2. Sees list of user-created presets
3. Can edit, delete, or reorder presets
4. Can reset to default presets
5. Changes persist immediately

## Risks and Mitigations

**Risk**: Preset parameter conflicts with current query state
**Mitigation**: Clearly indicate when preset is applied (UI feedback), allow easy revert

**Risk**: Too many presets cluttering dropdown
**Mitigation**: Separate default vs user presets with divider, support search/filter in dropdown

**Risk**: Preset format changes in future versions
**Mitigation**: Version preset JSON schema, implement migration logic in GSettings loader

## Out of Scope (Future)
- Preset sharing/import/export (separate feature)
- Template variables for dynamic substitution
- Preset categories/folders
- Cloud sync of presets
- Preset usage statistics/favorites
