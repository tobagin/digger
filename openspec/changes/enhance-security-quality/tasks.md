# Implementation Tasks

## 1. Security Hardening

### 1.1 DNS Server Validation (SEC-001)
- [x] 1.1.1 Create `src/utils/ValidationUtils.vala` with validation helper methods
- [x] 1.1.2 Implement `is_valid_ipv4(string input)` method with regex pattern
- [x] 1.1.3 Implement `is_valid_ipv6(string input)` method supporting full and compressed formats
- [x] 1.1.4 Implement `is_valid_hostname(string input)` method per RFC 1123
- [x] 1.1.5 Add `validate_dns_server(string server)` method combining all checks
- [x] 1.1.6 Update `EnhancedQueryForm.vala:show_custom_dns_dialog()` to call validation
- [x] 1.1.7 Add user-friendly error messages for each validation failure type
- [x] 1.1.8 Test with valid IPv4, IPv6, hostnames and invalid inputs

### 1.2 Batch File Validation (SEC-002)
- [x] 1.2.1 Add file size check in `BatchLookupManager.vala:import_from_file()`
- [x] 1.2.2 Implement 10MB size limit with error message
- [x] 1.2.3 Add line count limit (10,000 lines) with warning
- [x] 1.2.4 Validate each domain field using `DnsQuery.is_valid_domain()`
- [x] 1.2.5 Validate DNS server fields using `ValidationUtils.validate_dns_server()`
- [x] 1.2.6 Sanitize input by trimming whitespace and checking for prohibited characters
- [x] 1.2.7 Track and report count of skipped invalid entries
- [x] 1.2.8 Add logging for invalid entries (security audit trail)
- [x] 1.2.9 Test with oversized files, malformed CSV, and injection attempts

### 1.3 Domain Validation Strengthening (SEC-003)
- [x] 1.3.1 Update regex in `DnsQuery.vala:is_valid_domain()` to prevent consecutive dots
- [x] 1.3.2 Add check for labels starting/ending with hyphen or dot
- [x] 1.3.3 Add per-label length validation (max 63 characters)
- [x] 1.3.4 Add check for empty labels
- [x] 1.3.5 Update error messages to be specific about validation failures
- [x] 1.3.6 Test with RFC test vectors for valid/invalid domains
- [x] 1.3.7 Test edge cases: IDN, punycode, single-label domains

### 1.4 DNS Response Boundary Checking (SEC-004)
- [x] 1.4.1 Add bounds checking before all array accesses in `DnsQuery.vala:parse_dig_output()`
- [x] 1.4.2 Wrap array access in `parse_answer_section()` with length checks
- [x] 1.4.3 Wrap array access in `parse_authority_section()` with length checks
- [x] 1.4.4 Wrap array access in `parse_additional_section()` with length checks
- [x] 1.4.5 Add logging for malformed response lines that are skipped
- [x] 1.4.6 Return partial results when some records fail to parse
- [x] 1.4.7 Test with crafted malformed dig output
- [x] 1.4.8 Test with truncated responses

### 1.5 DoH HTTPS Enforcement (SEC-006)
- [x] 1.5.1 Add `is_https_url(string url)` validation method
- [x] 1.5.2 Update `SecureDns.vala:set_doh_endpoint()` to validate HTTPS requirement
- [x] 1.5.3 Auto-prepend "https://" if no protocol specified
- [x] 1.5.4 Reject HTTP URLs with clear error message
- [x] 1.5.5 Update preferences dialog to show HTTPS requirement in placeholder text
- [x] 1.5.6 Test with HTTP, HTTPS, and protocol-less URLs

### 1.6 Error Message Sanitization (SEC-009)
- [x] 1.6.1 Create `sanitize_error_message(Error e)` helper method
- [x] 1.6.2 Update all error handlers in `DnsQuery.vala` to use sanitized messages
- [x] 1.6.3 Update error handlers in `FavoritesManager.vala` to hide paths
- [x] 1.6.4 Update error handlers in `QueryHistory.vala` to hide paths
- [x] 1.6.5 Update error handlers in `BatchLookupManager.vala` to hide system details
- [x] 1.6.6 Ensure full errors are logged using `critical()` or `warning()`
- [x] 1.6.7 Review all `query_failed` signal emissions for information leaks
- [x] 1.6.8 Test error messages don't reveal system paths or internal structure

## 2. Code Quality Improvements

### 2.1 Centralized Constants File
- [x] 2.1.1 Create `src/utils/Constants.vala` file
- [x] 2.1.2 Define timeout constants: `RELEASE_NOTES_DELAY_MS`, `UI_REFRESH_DELAY_MS`, `DROPDOWN_HIDE_DELAY_MS`
- [x] 2.1.3 Define size limit constants: `MAX_BATCH_FILE_SIZE_MB`, `MAX_BATCH_LINES`, `MAX_HISTORY_SIZE`
- [x] 2.1.4 Define batch operation constants: `PARALLEL_BATCH_SIZE`, `DEFAULT_QUERY_TIMEOUT`
- [x] 2.1.5 Define validation constants: `MAX_DOMAIN_LENGTH`, `MAX_LABEL_LENGTH`
- [x] 2.1.6 Add documentation comments for each constant
- [x] 2.1.7 Update all files using magic numbers to reference Constants
- [x] 2.1.8 Verify no raw numeric literals remain in timeout/limit calls

### 2.2 Null Safety After Type Casting
- [x] 2.2.1 Add null checks in `BatchLookupDialog.vala` list factory methods (lines 60-64, 81-83)
- [x] 2.2.2 Add null checks in `ComparisonDialog.vala` if similar patterns exist
- [x] 2.2.3 Search codebase for `as Gtk.` pattern and add null checks
- [x] 2.2.4 Add graceful handling (skip/log) for null cast results
- [x] 2.2.5 Test with missing or malformed widget hierarchies

### 2.3 Async Timeout Cancellation
- [x] 2.3.1 Add `private uint? timeout_id = null;` to `Window.vala`
- [x] 2.3.2 Implement timeout cancellation in `Window` destructor
- [x] 2.3.3 Update `Timeout.add()` calls to store and cancel previous timeouts
- [x] 2.3.4 Add similar pattern to `AutocompleteDropdown.vala`
- [x] 2.3.5 Verify timeouts are cancelled on widget destruction
- [x] 2.3.6 Test for memory leaks with repeated widget creation/destruction

### 2.4 Code Duplication Elimination
- [x] 2.4.1 Create `Utils.arraylist_to_array()` helper method
- [x] 2.4.2 Replace ArrayList→array conversion in `DnsQuery.vala` (3 occurrences)
- [x] 2.4.3 Create `ExportManager.render_section()` generic method
- [x] 2.4.4 Replace duplicate section rendering in answer/authority/additional sections
- [x] 2.4.5 Consolidate JSON/CSV escaping into shared utility
- [x] 2.4.6 Verify no duplicate conversion/rendering patterns remain
- [x] 2.4.7 Measure LOC reduction from deduplication

### 2.5 Enhanced Error Handling
- [x] 2.5.1 Add `error_occurred` signal to managers for UI notification
- [x] 2.5.2 Connect error signals to toast notifications in `Window.vala`
- [x] 2.5.3 Update `FavoritesManager.vala` to emit errors on save/load failure
- [x] 2.5.4 Update `QueryHistory.vala` to emit errors on persistence failure
- [x] 2.5.5 Add structured logging with context (operation, params)
- [x] 2.5.6 Differentiate transient vs. permanent error messaging
- [x] 2.5.7 Test error notification flow end-to-end
- [x] 2.5.8 Verify no silent failures remain in async operations

## 3. Performance Optimizations

### 3.1 Lazy Loading Query History
- [x] 3.1.1 Add `private bool history_loaded = false;` flag to `QueryHistory.vala`
- [x] 3.1.2 Remove `load_history()` call from constructor
- [x] 3.1.3 Add `ensure_loaded()` method that loads history if not loaded
- [x] 3.1.4 Call `ensure_loaded()` at start of all public methods
- [x] 3.1.5 Add loading indicator in history UI if load takes >100ms
- [x] 3.1.6 Benchmark startup time before and after change
- [x] 3.1.7 Verify 200-500ms startup time improvement
- [x] 3.1.8 Test history persistence still works correctly

### 3.2 Hash-Based Favorites Lookup
- [x] 3.2.1 Add `private Gee.HashMap<string, Favorite> favorites_map;` to `FavoritesManager.vala`
- [x] 3.2.2 Create `make_key(domain, type)` helper method
- [x] 3.2.3 Update `load_favorites()` to populate both list and map
- [x] 3.2.4 Update `is_favorite()` to use hash map lookup
- [x] 3.2.5 Update `get_favorite()` to use hash map lookup
- [x] 3.2.6 Update `add_favorite()` to update both structures
- [x] 3.2.7 Update `remove_favorite()` to update both structures
- [x] 3.2.8 Benchmark lookup performance before/after (should be 10x+ faster)

### 3.3 Cached Dig Availability Check
- [x] 3.3.1 Add `private static bool? dig_available_cache = null;` to `DnsQuery.vala`
- [x] 3.3.2 Make `check_dig_available()` async
- [x] 3.3.3 Check cache first, return immediately if available
- [x] 3.3.4 Perform async system call if cache empty
- [x] 3.3.5 Store result in cache for session lifetime
- [x] 3.3.6 Update all callers to use async version
- [x] 3.3.7 Verify no blocking `which` calls remain
- [x] 3.3.8 Test cache behavior across multiple queries

### 3.4 Batch Query Auto-Tuning (Optional/Future)
- [x] 3.4.1 Add `detect_optimal_batch_size()` method to `BatchLookupManager.vala`
- [x] 3.4.2 Query system CPU count using GLib
- [x] 3.4.3 Adjust batch size: 5 (default), 10 (high-end), 3 (errors detected)
- [x] 3.4.4 Add preference setting for manual override
- [x] 3.4.5 Log batch size adjustments for transparency
- [x] 3.4.6 Test performance with different batch sizes
- [x] 3.4.7 Benchmark improvement on multi-core systems

## 4. Testing & Validation

### 4.1 Security Testing
- [x] 4.1.1 Test DNS server validation with injection payloads
- [x] 4.1.2 Test batch file import with oversized files
- [x] 4.1.3 Test domain validation with RFC test vectors
- [x] 4.1.4 Test DNS response parsing with malformed data
- [x] 4.1.5 Test DoH endpoint validation with HTTP URLs
- [x] 4.1.6 Review all error messages for information disclosure
- [x] 4.1.7 Run security-focused penetration testing scenarios
- [x] 4.1.8 Document security test results

### 4.2 Code Quality Verification
- [x] 4.2.1 Verify all magic numbers replaced with constants
- [x] 4.2.2 Verify null checks after all type casts
- [x] 4.2.3 Verify timeout cancellation with memory profiling
- [x] 4.2.4 Verify code duplication reduced by >50%
- [x] 4.2.5 Verify error handling covers all async operations
- [x] 4.2.6 Run static analysis tools (if available for Vala)
- [x] 4.2.7 Code review for patterns adherence

### 4.3 Performance Benchmarking
- [x] 4.3.1 Benchmark startup time with lazy loading
- [x] 4.3.2 Benchmark favorites lookup with hash map
- [x] 4.3.3 Benchmark query initiation with dig cache
- [x] 4.3.4 Benchmark batch operations with auto-tuning
- [x] 4.3.5 Document performance improvements
- [x] 4.3.6 Verify no performance regressions in core flows
- [x] 4.3.7 Profile memory usage changes

### 4.4 Integration Testing
- [x] 4.4.1 Test complete DNS query flow with all changes
- [x] 4.4.2 Test batch lookup end-to-end with validation
- [x] 4.4.3 Test favorites management with hash map
- [x] 4.4.4 Test error scenarios and user feedback
- [x] 4.4.5 Test DoH queries with HTTPS enforcement
- [x] 4.4.6 Test history management with lazy loading
- [x] 4.4.7 Regression test existing functionality
- [x] 4.4.8 User acceptance testing with real-world scenarios

## 5. Documentation & Cleanup

### 5.1 Code Documentation
- [x] 5.1.1 Add docstrings to new validation methods
- [x] 5.1.2 Document constants in Constants.vala
- [x] 5.1.3 Update inline comments for modified methods
- [x] 5.1.4 Document error handling patterns
- [x] 5.1.5 Add security considerations comments

### 5.2 User Documentation
- [x] 5.2.1 Update README.md with security improvements
- [x] 5.2.2 Document new input validation requirements
- [x] 5.2.3 Add troubleshooting guide for validation errors
- [x] 5.2.4 Update CHANGELOG.md for v2.3.0 release

### 5.3 Cleanup
- [x] 5.3.1 Remove unused code from refactoring
- [x] 5.3.2 Remove commented-out old implementations
- [x] 5.3.3 Verify code style consistency
- [x] 5.3.4 Run linter/formatter if available
- [x] 5.3.5 Final code review before merge
