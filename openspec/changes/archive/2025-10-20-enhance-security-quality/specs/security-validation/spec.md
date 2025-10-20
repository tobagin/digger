# Security Validation Specification

## ADDED Requirements

### Requirement: DNS Server Input Validation
The system SHALL validate all custom DNS server inputs before accepting them for use in DNS queries.

#### Scenario: Valid IPv4 DNS server accepted
- **WHEN** user enters a valid IPv4 address (e.g., "8.8.8.8", "1.1.1.1")
- **THEN** the DNS server is accepted and used for subsequent queries

#### Scenario: Valid IPv6 DNS server accepted
- **WHEN** user enters a valid IPv6 address (e.g., "2001:4860:4860::8888", "::1")
- **THEN** the DNS server is accepted and used for subsequent queries

#### Scenario: Valid hostname DNS server accepted
- **WHEN** user enters a valid hostname (e.g., "dns.google.com", "one.one.one.one")
- **THEN** the DNS server is accepted and resolved for use in queries

#### Scenario: Invalid DNS server rejected
- **WHEN** user enters invalid input (e.g., "8.8.8.256", "invalid..server", ""; DROP TABLE;")
- **THEN** an error message is displayed explaining the acceptable formats
- **AND** the custom DNS server is not added to the list

#### Scenario: Empty DNS server rejected
- **WHEN** user enters an empty or whitespace-only string
- **THEN** an error message is displayed
- **AND** the custom DNS dialog remains open for correction

### Requirement: Batch File Input Validation
The system SHALL validate all batch file imports with size limits, format checks, and field sanitization.

#### Scenario: Valid batch file imported successfully
- **WHEN** user imports a CSV/TXT file under 10MB with valid domains
- **THEN** all domains are parsed and added to the batch queue
- **AND** the number of imported domains is displayed

#### Scenario: Oversized batch file rejected
- **WHEN** user attempts to import a file larger than 10MB
- **THEN** an error message is displayed indicating the size limit
- **AND** the file is not processed

#### Scenario: Batch file with invalid domains filtered
- **WHEN** user imports a file containing a mix of valid and invalid domains
- **THEN** only valid domains are added to the batch queue
- **AND** a warning is displayed showing the count of skipped invalid entries
- **AND** invalid entries are logged for review

#### Scenario: Batch file line count limit enforced
- **WHEN** user imports a file with more than 10,000 lines
- **THEN** only the first 10,000 valid entries are processed
- **AND** a warning is displayed about the limit

#### Scenario: Malicious batch file content sanitized
- **WHEN** user imports a file containing special shell characters or command injection attempts
- **THEN** each field is sanitized by trimming and validating against allowed patterns
- **AND** entries with prohibited characters are rejected with warning

### Requirement: Domain Validation Strengthening
The system SHALL validate domain names according to RFC 1123 and RFC 1035 specifications.

#### Scenario: Valid domains accepted
- **WHEN** user enters valid domains (e.g., "example.com", "sub.domain.co.uk", "a.b.c.d.e.com")
- **THEN** the domains pass validation and queries proceed

#### Scenario: Consecutive dots rejected
- **WHEN** user enters a domain with consecutive dots (e.g., "example..com", "invalid...domain")
- **THEN** the domain is rejected with an error message
- **AND** the query does not proceed

#### Scenario: Invalid start/end characters rejected
- **WHEN** user enters a domain starting or ending with hyphen or dot (e.g., "-example.com", "example.com-", ".example.com")
- **THEN** the domain is rejected with an error message

#### Scenario: Labels exceeding 63 characters rejected
- **WHEN** user enters a domain with any label longer than 63 characters
- **THEN** the domain is rejected with an error message explaining the label length limit

#### Scenario: Empty labels rejected
- **WHEN** user enters a domain with empty labels (e.g., "example..com")
- **THEN** the domain is rejected

### Requirement: DNS Response Boundary Checking
The system SHALL perform bounds checking on all array accesses when parsing DNS responses.

#### Scenario: Malformed DNS response with short array handled safely
- **WHEN** dig returns a response line with fewer fields than expected
- **THEN** the parser checks array bounds before accessing each field
- **AND** incomplete records are skipped with a warning logged
- **AND** the application does not crash

#### Scenario: DNS response with unexpected format logged
- **WHEN** dig returns output that doesn't match expected patterns
- **THEN** each parsing operation validates array indices before access
- **AND** parsing errors are logged with the problematic line
- **AND** the query returns with partial results if any valid records were found

#### Scenario: Buffer overflow protection in record parsing
- **WHEN** parsing DNS record values from dig output
- **THEN** all string slicing operations check bounds
- **AND** values exceeding maximum lengths are truncated with warning

### Requirement: DoH HTTPS Enforcement
The system SHALL enforce HTTPS-only connections for DNS-over-HTTPS endpoints.

#### Scenario: HTTPS DoH endpoint accepted
- **WHEN** user enters or selects an HTTPS DoH endpoint (e.g., "https://cloudflare-dns.com/dns-query")
- **THEN** the endpoint is accepted and used for DoH queries

#### Scenario: HTTP DoH endpoint rejected
- **WHEN** user enters an HTTP (non-HTTPS) DoH endpoint
- **THEN** an error message is displayed requiring HTTPS
- **AND** the endpoint is not saved to settings

#### Scenario: DoH endpoint without protocol prefix validated
- **WHEN** user enters a DoH endpoint without "http://" or "https://" prefix
- **THEN** "https://" is automatically prepended
- **AND** the endpoint is validated and accepted

#### Scenario: Invalid DoH endpoint URL rejected
- **WHEN** user enters a malformed URL as DoH endpoint
- **THEN** an error message is displayed
- **AND** the current DoH setting remains unchanged

### Requirement: Error Message Sanitization
The system SHALL sanitize all error messages to prevent information disclosure about system internals.

#### Scenario: Generic error message for file operations
- **WHEN** a file operation fails (e.g., history save, favorites load)
- **THEN** the user sees a generic message like "Failed to save favorites. Please try again."
- **AND** specific system paths and error details are only logged (not displayed)

#### Scenario: Network error without sensitive details
- **WHEN** a DNS query fails due to network issues
- **THEN** the user sees "Network error: Unable to reach DNS server"
- **AND** internal exception messages and stack traces are not displayed

#### Scenario: Validation error with actionable guidance
- **WHEN** input validation fails
- **THEN** the user sees a message explaining what format is expected
- **AND** no system paths or internal variable names are exposed

#### Scenario: Detailed errors logged for debugging
- **WHEN** any error occurs
- **THEN** full error details (paths, exceptions, stack traces) are logged using GLib logging
- **AND** only sanitized user-friendly messages are displayed in the UI
