# command-export Specification

## Purpose
TBD - created by archiving change add-command-export. Update Purpose after archive.
## Requirements
### Requirement: Standard dig Command Generation
The system SHALL generate valid dig command syntax from current query parameters.

#### Scenario: Simple query command generation
- **WHEN** user performs a basic query (domain: "example.com", type: A, default server)
- **AND** clicks "Copy as dig command"
- **THEN** the generated command is `dig example.com A`
- **AND** command is copied to system clipboard

#### Scenario: Query with custom DNS server
- **WHEN** user performs query with custom server (domain: "google.com", type: MX, server: "1.1.1.1")
- **AND** requests command export
- **THEN** the generated command is `dig @1.1.1.1 google.com MX`

#### Scenario: Query with DNSSEC enabled
- **WHEN** user performs query with DNSSEC validation enabled
- **AND** requests command export
- **THEN** the generated command includes `+dnssec` flag
- **EXAMPLE**: `dig @8.8.8.8 example.org MX +dnssec`

#### Scenario: Query with trace enabled
- **WHEN** user performs query with trace path enabled
- **AND** requests command export
- **THEN** the generated command includes `+trace` flag
- **EXAMPLE**: `dig example.com A +trace`

#### Scenario: Query with short output enabled
- **WHEN** user performs query with short output option enabled
- **AND** requests command export
- **THEN** the generated command includes `+short` flag
- **EXAMPLE**: `dig example.com A +short`

#### Scenario: Reverse DNS lookup command
- **WHEN** user performs reverse DNS lookup for IP address "8.8.8.8"
- **AND** requests command export
- **THEN** the generated command is `dig -x 8.8.8.8`

#### Scenario: Multiple advanced options combined
- **WHEN** user performs query with multiple options (custom server, DNSSEC, specific record type)
- **AND** requests command export
- **THEN** all options are correctly combined in dig syntax
- **EXAMPLE**: `dig @1.1.1.1 example.com TXT +dnssec +noall +answer`

### Requirement: DoH curl Command Generation
The system SHALL generate valid curl commands for DNS-over-HTTPS queries.

#### Scenario: DoH query with Cloudflare
- **WHEN** user performs DoH query using Cloudflare resolver (domain: "example.com", type: A)
- **AND** requests command export
- **THEN** the generated curl command uses Cloudflare DoH endpoint
- **AND** includes proper headers and query parameters
- **EXAMPLE**: `curl -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=example.com&type=A'`

#### Scenario: DoH query with Google
- **WHEN** user performs DoH query using Google resolver
- **AND** requests command export
- **THEN** the generated curl command uses Google DoH endpoint
- **EXAMPLE**: `curl -H 'accept: application/dns-json' 'https://dns.google/resolve?name=example.com&type=A'`

#### Scenario: DoH query with DNSSEC
- **WHEN** user performs DoH query with DNSSEC validation enabled
- **AND** requests command export
- **THEN** the generated curl command includes `&do=1` parameter for DNSSEC
- **EXAMPLE**: `curl -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=example.org&type=AAAA&do=1'`

#### Scenario: DoH query with custom endpoint
- **WHEN** user performs DoH query using custom DoH endpoint URL
- **AND** requests command export
- **THEN** the generated curl command uses the custom endpoint
- **AND** includes standard dns-json format headers

### Requirement: Clipboard Integration
The system SHALL copy generated commands to the system clipboard for easy pasting.

#### Scenario: Successful clipboard copy
- **WHEN** user clicks "Copy as dig command" button
- **THEN** the generated command is copied to system clipboard
- **AND** a toast notification displays "Command copied to clipboard"
- **AND** user can paste command into terminal immediately

#### Scenario: Clipboard copy failure handling
- **WHEN** clipboard operation fails (e.g., permissions issue, no clipboard available)
- **THEN** an error toast displays "Failed to copy to clipboard"
- **AND** generated command is displayed in a text dialog as fallback
- **AND** user can manually select and copy the text

#### Scenario: Command display without copy
- **WHEN** user views generated command in display mode
- **THEN** command is shown in monospace font in a dialog
- **AND** dialog includes "Copy" button for clipboard operation
- **AND** dialog is selectable for manual copy

### Requirement: Batch Command Export
The system SHALL generate shell scripts containing commands for all queries in batch lookups.

#### Scenario: Batch lookup command export
- **WHEN** user performs batch lookup of multiple domains (e.g., "example.com", "google.com", "cloudflare.com")
- **AND** requests command export for batch
- **THEN** the generated output is a shell script with one dig command per domain
- **AND** script includes shebang (`#!/bin/bash`)
- **AND** each command uses the same parameters configured for batch

#### Scenario: Batch export with different record types
- **WHEN** batch lookup includes mixed record types per domain
- **AND** requests command export
- **THEN** each command reflects the specific record type for that domain
- **EXAMPLE**:
  ```bash
  #!/bin/bash
  dig example.com A
  dig google.com MX
  dig cloudflare.com AAAA
  ```

#### Scenario: Batch export file save
- **WHEN** user exports batch commands to file
- **THEN** file is saved with `.sh` extension
- **AND** file has executable permissions (chmod +x)
- **AND** success notification displays save location

### Requirement: Command Syntax Validation
The system SHALL ensure generated commands are valid and executable.

#### Scenario: Generated command executes successfully
- **WHEN** user copies generated dig command
- **AND** pastes and executes it in a terminal
- **THEN** the command produces equivalent results to the GUI query
- **AND** no syntax errors occur

#### Scenario: Special character escaping
- **WHEN** domain contains special characters that need shell escaping
- **AND** command is generated
- **THEN** special characters are properly escaped or quoted
- **EXAMPLE**: Domain with underscore: `dig "_dmarc.example.com" TXT`

#### Scenario: Command syntax for ANY record type
- **WHEN** user queries ANY record type (legacy, rarely supported)
- **AND** requests command export
- **THEN** the generated command is `dig example.com ANY`
- **AND** warning is included that ANY queries are deprecated

### Requirement: Command Explanation
The system SHALL provide optional explanations of command syntax for educational purposes.

#### Scenario: Command flag explanation tooltip
- **WHEN** user hovers over generated command in display dialog
- **AND** command contains flags like `+dnssec`, `+trace`, `+short`
- **THEN** tooltip explains what each flag does
- **EXAMPLE**: "+dnssec - Request and validate DNSSEC signatures"

#### Scenario: Server specification explanation
- **WHEN** generated command includes `@server` syntax
- **AND** user views command explanation
- **THEN** explanation notes "@ specifies custom DNS server to query"

#### Scenario: Show equivalent GUI action
- **WHEN** user views command explanation
- **THEN** explanation maps command flags to GUI options
- **EXAMPLE**: "+trace → Enable 'Trace Path' option in Advanced settings"

### Requirement: UI Integration
The system SHALL provide accessible UI controls for command export functionality.

#### Scenario: Copy button in results view
- **WHEN** query results are displayed
- **THEN** a "Copy as dig command" button is visible in the results header or toolbar
- **AND** button is enabled for successful queries
- **AND** button is disabled if no query has been performed

#### Scenario: Export menu option
- **WHEN** user opens the Export menu
- **THEN** "Export as dig command" option is available
- **AND** option is grayed out if no query results exist

#### Scenario: Keyboard shortcut
- **WHEN** user presses Ctrl+Shift+C (or equivalent) in results view
- **THEN** command is generated and copied to clipboard
- **AND** shortcut is documented in shortcuts dialog

#### Scenario: Context menu integration
- **WHEN** user right-clicks on query results
- **THEN** context menu includes "Copy as dig command" option
- **AND** selecting option copies command to clipboard

### Requirement: Command Format Options
The system SHALL provide options for different command output formats.

#### Scenario: Concise vs verbose command format
- **WHEN** user requests command export in concise mode
- **THEN** only essential flags are included (minimal syntax)
- **WHEN** user requests verbose mode
- **THEN** all explicit flags are included (e.g., `+noall +answer` for clean output)

#### Scenario: Multi-line curl command formatting
- **WHEN** DoH curl command is generated with long URLs
- **THEN** command is formatted with line continuations (`\`) for readability
- **EXAMPLE**:
  ```bash
  curl -H 'accept: application/dns-json' \
    'https://cloudflare-dns.com/dns-query?name=example.com&type=A'
  ```

#### Scenario: Commented command export
- **WHEN** user exports batch commands with comments enabled
- **THEN** shell script includes comment before each command explaining the query
- **EXAMPLE**:
  ```bash
  #!/bin/bash
  # Query A record for example.com
  dig example.com A
  ```

