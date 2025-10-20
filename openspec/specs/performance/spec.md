# performance Specification

## Purpose
TBD - created by archiving change enhance-security-quality. Update Purpose after archive.
## Requirements
### Requirement: Lazy Loading Query History
The system SHALL defer loading query history from disk until first access to improve startup time.

#### Scenario: Application starts without loading history
- **WHEN** application launches
- **THEN** query history is not loaded from disk immediately
- **AND** history data structures remain empty until first access

#### Scenario: History loaded on first UI access
- **WHEN** user opens history view or performs first query
- **THEN** history is loaded asynchronously from disk
- **AND** a loading indicator is shown if loading takes >100ms

#### Scenario: Startup time improvement measured
- **WHEN** startup time is benchmarked with lazy loading enabled
- **THEN** startup time is reduced by 200-500ms compared to eager loading
- **AND** subsequent history access incurs the one-time loading cost

#### Scenario: History write-through caching
- **WHEN** new queries are added to history after lazy loading
- **THEN** they are both cached in memory and persisted to disk
- **AND** subsequent reads use the in-memory cache

### Requirement: Hash-Based Favorites Lookup
The system SHALL use hash-based data structures for O(1) favorites lookup operations.

#### Scenario: Favorites stored in HashMap
- **WHEN** favorites are loaded from disk
- **THEN** they are stored in a `Gee.HashMap<string, Favorite>` with composite key
- **AND** the key format is `"domain:record_type"` (e.g., `"example.com:A"`)

#### Scenario: Favorite lookup in constant time
- **WHEN** checking if a domain+type combination is favorited
- **THEN** a hash map lookup is performed (O(1) complexity)
- **AND** no linear search through favorites list occurs

#### Scenario: Favorite addition without duplicate check loop
- **WHEN** adding a new favorite
- **THEN** the hash map is checked for existence in O(1)
- **AND** if absent, the favorite is added to both map and persistent storage

#### Scenario: Favorites list view synchronized
- **WHEN** displaying favorites in the UI
- **THEN** the hash map values are converted to a list for display
- **AND** both data structures are kept in sync on add/remove operations

### Requirement: Cached Dig Availability Check
The system SHALL cache the result of dig command availability checking to eliminate repeated system calls.

#### Scenario: First dig check performs system call
- **WHEN** first DNS query is initiated
- **THEN** a system call checks for dig command availability
- **AND** the result (true/false) is stored in a static variable

#### Scenario: Subsequent dig checks use cache
- **WHEN** additional DNS queries are initiated
- **THEN** the cached dig availability result is used
- **AND** no additional `which dig` system calls are made

#### Scenario: Async dig availability check
- **WHEN** checking dig availability
- **THEN** the check is performed asynchronously
- **AND** the UI is not blocked during the check

#### Scenario: Dig availability cache invalidation
- **WHEN** dig availability changes during application lifetime (rare)
- **THEN** a manual cache refresh mechanism is available (e.g., application restart)
- **AND** the cached value persists for the application session

### Requirement: Batch Query Auto-Tuning
The system SHALL automatically determine optimal parallel batch size based on system resources.

#### Scenario: Default batch size for moderate systems
- **WHEN** batch operations start without specific tuning
- **THEN** a conservative default batch size of 5 is used
- **AND** performance is monitored during execution

#### Scenario: Batch size increased for powerful systems
- **WHEN** system has high CPU count (>8 cores) and abundant memory
- **THEN** batch size can be increased up to 10 for faster processing
- **AND** the adjustment is logged for user visibility

#### Scenario: Batch size reduced on errors
- **WHEN** batch queries experience high failure rates or timeouts
- **THEN** batch size is dynamically reduced to improve reliability
- **AND** the user is notified of the adjustment

#### Scenario: User override of batch size
- **WHEN** user manually sets batch size in preferences
- **THEN** the manual setting overrides auto-tuning
- **AND** the custom value is respected and persisted

