# whois-lookup Specification

## Purpose
TBD - created by archiving change add-whois-integration. Update Purpose after archive.
## Requirements
### Requirement: WHOIS Query Execution
The system SHALL execute WHOIS queries for domains using the whois command-line tool via subprocess.

#### Scenario: Successful WHOIS lookup for .com domain
- **WHEN** user requests WHOIS information for a registered .com domain (e.g., "google.com")
- **THEN** the system executes a whois subprocess command
- **AND** returns parsed registration data within 10 seconds
- **AND** displays registrar name, registration date, expiration date, and nameservers

#### Scenario: WHOIS lookup for unregistered domain
- **WHEN** user requests WHOIS information for an unregistered domain
- **THEN** the system executes the WHOIS query
- **AND** displays "Domain not registered" or equivalent message
- **AND** does not show an error state

#### Scenario: WHOIS server timeout
- **WHEN** WHOIS server does not respond within configured timeout (default 30 seconds)
- **THEN** the system displays a timeout error message
- **AND** suggests trying again or checking network connectivity
- **AND** does not freeze the UI during the timeout period

#### Scenario: WHOIS command not available
- **WHEN** whois command is not found in the system
- **THEN** the system displays an informative error message
- **AND** suggests how to install whois (or notes it should be bundled in Flatpak)
- **AND** disables WHOIS functionality gracefully

### Requirement: TLD-Specific WHOIS Server Support
The system SHALL route WHOIS queries to appropriate TLD-specific WHOIS servers based on domain extension.

#### Scenario: Country-code TLD routing
- **WHEN** user queries WHOIS for a country-code domain (e.g., "example.co.uk")
- **THEN** the system automatically routes to the appropriate ccTLD WHOIS server
- **AND** parses responses according to that registry's format

#### Scenario: Generic TLD routing
- **WHEN** user queries WHOIS for gTLD (e.g., .com, .org, .net)
- **THEN** the system uses standard WHOIS servers for those TLDs
- **AND** follows referral chains if registry redirects to registrar WHOIS

#### Scenario: Unknown TLD fallback
- **WHEN** user queries WHOIS for an unknown or new TLD
- **THEN** the system attempts a default WHOIS query
- **AND** displays whatever information is returned
- **AND** indicates if format parsing was limited

### Requirement: WHOIS Data Parsing
The system SHALL parse WHOIS responses to extract common registration fields in a structured format.

#### Scenario: Parse common WHOIS fields
- **WHEN** WHOIS response is received from major registrars (GoDaddy, Namecheap, Google Domains, etc.)
- **THEN** the system extracts at minimum: registrar name, creation date, expiration date, updated date, nameservers, status
- **AND** displays extracted fields in a structured, readable format
- **AND** handles missing fields gracefully (shows "Not available" or equivalent)

#### Scenario: Privacy-protected WHOIS
- **WHEN** WHOIS response contains GDPR privacy protection or proxy contact information
- **THEN** the system recognizes privacy protection patterns
- **AND** displays "Privacy Protected" for redacted contact fields
- **AND** still shows non-private information (dates, registrar, nameservers)

#### Scenario: Unparseable WHOIS format
- **WHEN** WHOIS response is in an unrecognized or unusual format
- **THEN** the system falls back to displaying raw WHOIS output
- **AND** indicates parsing was not possible
- **AND** allows user to view full raw response

### Requirement: WHOIS Result Display
The system SHALL display WHOIS information in an expandable section of the query results view.

#### Scenario: WHOIS results in collapsible section
- **WHEN** WHOIS data is successfully retrieved
- **THEN** results appear in an expandable "WHOIS Information" section
- **AND** section is collapsed by default (to not overwhelm DNS results)
- **AND** user can click to expand and view full WHOIS details

#### Scenario: WHOIS loading state
- **WHEN** WHOIS query is in progress
- **THEN** WHOIS section shows a loading spinner or progress indicator
- **AND** displays "Fetching WHOIS data..." message
- **AND** does not block DNS query results from displaying

#### Scenario: WHOIS error state display
- **WHEN** WHOIS query fails or times out
- **THEN** WHOIS section displays error message with reason
- **AND** provides "Retry" button to attempt query again
- **AND** does not affect DNS query results display

### Requirement: WHOIS Caching
The system SHALL cache WHOIS results to reduce redundant queries and improve performance.

#### Scenario: Cache hit for recent WHOIS query
- **WHEN** user performs WHOIS lookup for a domain queried within cache TTL (default 24 hours)
- **THEN** cached result is displayed immediately
- **AND** UI indicates result is from cache with timestamp
- **AND** provides "Refresh" option to force new query

#### Scenario: Cache expiration
- **WHEN** user performs WHOIS lookup for a domain with expired cache entry
- **THEN** fresh WHOIS query is executed
- **AND** new result replaces cached entry
- **AND** cache timestamp is updated

#### Scenario: Cache storage limit
- **WHEN** WHOIS cache exceeds configured size limit (default 100 entries)
- **THEN** oldest entries are removed (LRU eviction)
- **AND** cache operations do not impact application performance

### Requirement: WHOIS Export Integration
The system SHALL include WHOIS data in query result exports when available.

#### Scenario: Export with WHOIS data in JSON format
- **WHEN** user exports query results to JSON and WHOIS data is available
- **THEN** JSON includes a "whois" object with parsed fields
- **AND** includes both parsed fields and raw WHOIS output

#### Scenario: Export with WHOIS data in CSV format
- **WHEN** user exports query results to CSV and WHOIS data is available
- **THEN** CSV includes WHOIS columns: registrar, registration_date, expiration_date, nameservers
- **AND** multi-value fields (nameservers) are semicolon-separated

#### Scenario: Export with WHOIS data in TXT format
- **WHEN** user exports query results to TXT and WHOIS data is available
- **THEN** TXT includes a "WHOIS INFORMATION" section
- **AND** displays key fields in readable format
- **AND** optionally includes full raw WHOIS output

#### Scenario: Export without WHOIS data
- **WHEN** user exports query results and WHOIS data was not fetched or failed
- **THEN** export indicates WHOIS data is not available
- **AND** does not include empty WHOIS sections in output

### Requirement: WHOIS Configuration Settings
The system SHALL provide user configuration options for WHOIS functionality via GSettings.

#### Scenario: Enable/disable automatic WHOIS lookup
- **WHEN** user enables "Auto-fetch WHOIS" setting
- **THEN** WHOIS query executes automatically whenever DNS query completes successfully
- **WHEN** user disables "Auto-fetch WHOIS" setting
- **THEN** WHOIS query only executes when user explicitly clicks "WHOIS Lookup" button

#### Scenario: Configure WHOIS cache TTL
- **WHEN** user sets WHOIS cache TTL to custom value (e.g., 7 days)
- **THEN** cached WHOIS results remain valid for configured duration
- **AND** setting persists across application restarts

#### Scenario: Clear WHOIS cache
- **WHEN** user clicks "Clear WHOIS Cache" button in preferences
- **THEN** all cached WHOIS entries are deleted
- **AND** confirmation message displays number of entries cleared
- **AND** subsequent WHOIS queries fetch fresh data

