# Design Document: Security Hardening and Code Quality Baseline

## Context

Digger is a production DNS lookup application with ~8,000 LOC that currently has:
- **13 security vulnerabilities** identified through comprehensive analysis
- **42 code quality issues** affecting maintainability
- **Performance inefficiencies** in startup and lookup operations

This change addresses Phase 1 (P0) critical issues to establish a secure foundation before adding new features. The codebase is well-architected with clean separation of concerns, making this primarily a targeted improvement effort rather than a major refactoring.

### Stakeholders
- **Users**: Require secure, reliable DNS tool without vulnerabilities
- **Developers**: Need maintainable, well-organized codebase
- **Security**: Must pass security audits before production use
- **Distributors**: Flathub requires secure applications

### Constraints
- **No Breaking Changes**: Maintain all existing APIs and user workflows
- **Vala Language**: Must work within Vala's limitations (no reflection, limited metaprogramming)
- **GTK4/libadwaita**: Must follow GNOME HIG and libadwaita patterns
- **Flatpak Sandboxing**: Changes must work within sandbox restrictions
- **Performance**: Cannot degrade query performance (10-200ms target)

## Goals / Non-Goals

### Goals
1. **Security**: Eliminate all critical (1) and high (3) security vulnerabilities
2. **Reliability**: Fix code quality issues causing potential crashes
3. **Performance**: Achieve 200-500ms startup time improvement
4. **Maintainability**: Reduce code duplication by >50%
5. **Foundation**: Enable future feature development on secure base

### Non-Goals
1. **Major Refactoring**: Not changing overall architecture or patterns
2. **New Features**: Not adding DNS features (WHOIS, benchmarks, etc.)
3. **UI Changes**: Not modifying user interface or workflows
4. **Testing Infrastructure**: Not adding unit testing framework (future work)
5. **I18n/L10n**: Not adding internationalization support

## Decisions

### Decision 1: Input Validation Strategy
**Choice**: Create centralized validation utilities in `ValidationUtils.vala`

**Rationale**:
- Validation logic reused across multiple components (query form, batch import, settings)
- Single source of truth for security-critical validation rules
- Easier to test and audit validation logic
- Consistent error messages and behavior

**Alternatives Considered**:
- **Inline validation**: Rejected - leads to duplication and inconsistency
- **Per-component validation**: Rejected - harder to maintain and audit
- **Third-party validation library**: Rejected - no mature Vala libraries available

**Implementation**:
```vala
namespace Digger.ValidationUtils {
    public bool is_valid_ipv4 (string input);
    public bool is_valid_ipv6 (string input);
    public bool is_valid_hostname (string input);
    public bool validate_dns_server (string server);
}
```

### Decision 2: Error Message Sanitization Approach
**Choice**: Sanitize at display layer, log full details

**Rationale**:
- Users need actionable error messages, not system internals
- Developers/admins need full details for debugging
- GLib logging system provides structured, filterable logs
- Separation of concerns: display layer vs. logging layer

**Pattern**:
```vala
try {
    // ... operation
} catch (Error e) {
    critical ("Failed to save favorites to %s: %s", file_path, e.message);  // Full logging
    error_occurred ("Failed to save favorites. Please check disk space.");  // User message
}
```

**Alternatives Considered**:
- **Full error disclosure**: Rejected - security risk
- **Generic errors only**: Rejected - poor developer experience
- **Error codes**: Rejected - adds complexity without clear benefit

### Decision 3: Performance Optimization - Lazy Loading
**Choice**: Lazy-load query history on first access

**Rationale**:
- History loading (JSON parsing, file I/O) takes 200-500ms on cold start
- Many users don't access history immediately
- Async loading on first access provides better perceived performance
- Write-through caching ensures data consistency

**Trade-offs**:
- **Pros**: Faster startup, better perceived performance
- **Cons**: First history access slightly slower, added complexity

**Implementation Pattern**:
```vala
public class QueryHistory {
    private bool history_loaded = false;
    private async void ensure_loaded () {
        if (!history_loaded) {
            yield load_history_from_disk ();
            history_loaded = true;
        }
    }

    public async Gee.List<Query> get_history () {
        yield ensure_loaded ();
        return history_list;
    }
}
```

**Alternatives Considered**:
- **Background loading**: Rejected - complexity without clear benefit
- **Partial loading**: Rejected - complicates state management
- **Eager loading**: Current approach - predictable but slower

### Decision 4: Favorites Lookup Optimization
**Choice**: Maintain both HashMap (for lookups) and ArrayList (for display)

**Rationale**:
- Current linear search is O(n), becomes noticeable with 50+ favorites
- HashMap provides O(1) lookups for `is_favorite()` checks
- ArrayList still needed for ordered display in UI
- Dual data structure overhead is negligible (<1KB for typical use)

**Synchronization Strategy**:
```vala
private Gee.ArrayList<Favorite> favorites_list;  // For display
private Gee.HashMap<string, Favorite> favorites_map;  // For lookups

private string make_key (string domain, RecordType type) {
    return @"$domain:$(type.to_string())";
}

public void add_favorite (Favorite fav) {
    var key = make_key (fav.domain, fav.record_type);
    if (!favorites_map.has_key (key)) {
        favorites_list.add (fav);
        favorites_map[key] = fav;
        save_favorites.begin ();
    }
}
```

**Alternatives Considered**:
- **HashMap only**: Rejected - loses ordering for UI display
- **LinkedHashMap**: Rejected - not available in libgee 0.8
- **Keep linear search**: Rejected - poor performance at scale

### Decision 5: Constants Organization
**Choice**: Single `Constants.vala` file with categorized constants

**Rationale**:
- Simple, discoverable location for all constants
- Vala doesn't support nested namespaces well
- Category comments provide organization without complexity
- Easy to grep and refactor

**Structure**:
```vala
namespace Digger.Constants {
    // Timeout values (milliseconds)
    public const int RELEASE_NOTES_DELAY_MS = 500;
    public const int UI_REFRESH_DELAY_MS = 100;
    public const int DROPDOWN_HIDE_DELAY_MS = 150;

    // Size limits
    public const int MAX_BATCH_FILE_SIZE_MB = 10;
    public const int MAX_BATCH_LINES = 10000;
    public const int MAX_HISTORY_SIZE = 100;

    // Performance tuning
    public const int PARALLEL_BATCH_SIZE = 5;
    public const int DEFAULT_QUERY_TIMEOUT = 10;

    // Validation limits
    public const int MAX_DOMAIN_LENGTH = 253;
    public const int MAX_LABEL_LENGTH = 63;
}
```

**Alternatives Considered**:
- **Multiple constant files**: Rejected - increases file count, harder to find
- **Class-level constants**: Current approach - poor discoverability
- **Configuration file**: Rejected - overkill for compile-time constants

### Decision 6: Bounds Checking Strategy
**Choice**: Defensive checks before all array access in DNS parsing

**Rationale**:
- dig output format can vary (different versions, locales)
- Malformed or unexpected responses should not crash app
- Performance impact negligible (array length checks are cheap)
- Partial results better than total failure

**Pattern**:
```vala
var parts = line.split_set (" \t");
if (parts.length >= 5) {  // Minimum expected fields
    var name = parts[0];
    var ttl = int.parse (parts[1]);
    // ... use parts[2], parts[3], parts[4] safely
} else {
    warning ("Skipping malformed DNS record line: %s", line);
}
```

**Alternatives Considered**:
- **Try-catch for out-of-bounds**: Rejected - exceptions are for exceptional cases
- **Optimistic parsing**: Current approach - crashes on malformed input
- **Binary DNS parsing**: Future work - major refactoring effort

## Risks / Trade-offs

### Risk 1: Stricter Validation Rejects Previously Accepted Input
**Impact**: Medium
**Probability**: Low
**Mitigation**:
- Comprehensive testing with edge cases before release
- Clear error messages explaining what's expected
- Monitor user feedback in first release
- Can relax specific validations if too strict in practice

**Rollback Plan**: Revert validation regex to previous patterns while keeping other improvements

### Risk 2: Lazy Loading Complexity
**Impact**: Low
**Probability**: Medium
**Mitigation**:
- Thorough testing of first-access scenario
- Loading indicator for user feedback
- Fallback to eager loading if issues discovered

**Rollback Plan**: Remove `ensure_loaded()` calls, add `load_history()` back to constructor

### Risk 3: Dual Data Structure Synchronization Bugs
**Impact**: Medium (favorites out of sync)
**Probability**: Low
**Mitigation**:
- Encapsulate all add/remove operations
- Comprehensive testing of favorites CRUD
- Assert map and list sizes match in debug builds

**Rollback Plan**: Keep only ArrayList, accept O(n) lookup performance

### Risk 4: Performance Regression from Added Checks
**Impact**: Low
**Probability**: Very Low
**Mitigation**:
- Benchmark critical paths before and after
- Validation checks are simple (regex, bounds) - minimal overhead
- Query execution time (network) dwarfs validation time

**Rollback Plan**: Profile and optimize specific validation bottlenecks

### Risk 5: Incomplete Error Sanitization
**Impact**: Low (some info leakage remains)
**Probability**: Medium
**Mitigation**:
- Systematic review of all error handlers
- Security-focused testing of error paths
- Grep for common leak patterns (file paths, stack traces)

**Rollback Plan**: Iterate and improve in subsequent releases

## Migration Plan

### Phase 1: Security Hardening (Week 1)
**Steps**:
1. Create `ValidationUtils.vala` with all validation methods
2. Update `EnhancedQueryForm.vala` with DNS server validation
3. Update `BatchLookupManager.vala` with file validation
4. Update `DnsQuery.vala` with domain validation and bounds checking
5. Update `SecureDns.vala` with HTTPS enforcement
6. Sanitize error messages across all files

**Validation**:
- Security testing with injection payloads
- Verify all critical/high vulnerabilities resolved
- No crashes on malformed input

**Rollback**: Git revert security commits if critical bugs found

### Phase 2: Code Quality (Week 2)
**Steps**:
1. Create `Constants.vala` file
2. Refactor all magic numbers to constants
3. Add null checks after type casts
4. Implement timeout cancellation
5. Extract duplicated code patterns

**Validation**:
- Code review for patterns adherence
- No magic numbers remain
- Memory leak testing

**Rollback**: Cherry-pick revert individual changes if issues found

### Phase 3: Performance (Week 2-3)
**Steps**:
1. Implement lazy loading for query history
2. Add hash-based favorites lookup
3. Cache dig availability check
4. Benchmark all changes

**Validation**:
- Startup time benchmark (target: 200-500ms improvement)
- Favorites lookup benchmark (target: 10x improvement)
- No functional regressions

**Rollback**: Revert performance changes, keep security/quality improvements

### Phase 4: Testing & Release (Week 3)
**Steps**:
1. Comprehensive integration testing
2. Security audit verification
3. Performance benchmarking
4. Documentation updates
5. CHANGELOG.md for v2.3.0
6. Tag and release

**Validation**:
- All acceptance criteria met
- No known security issues
- Performance targets achieved

### Data Migration
**None required** - all changes are code-level, no data format changes

### Backward Compatibility
**Fully maintained** - no API or behavior changes from user perspective

## Open Questions

### Q1: Should we add automated security testing?
**Context**: Manual security testing is time-consuming and error-prone
**Options**:
- Add security-focused test cases to future unit testing framework
- Use external security scanning tools (if available for Vala/Flatpak)
- Rely on manual testing and code review

**Decision Required By**: Phase 4 (can punt to future work)

### Q2: Should batch size auto-tuning be in Phase 1?
**Context**: Listed as optional/future in tasks.md
**Recommendation**: Defer to Phase 2 - not critical, adds complexity
**Decision**: Mark as P1 (next phase) unless implementation is trivial

### Q3: Should we version the validation rules?
**Context**: Future Digger versions may need different validation strictness
**Recommendation**: Not needed for v2.3.0, consider for v3.0+
**Decision**: YAGNI - add versioning when actual need arises

## Implementation Notes

### Testing Strategy
**Security Testing**:
- Injection payloads for DNS servers: `"8.8.8.8; rm -rf /"`, `"../../etc/passwd"`
- Batch file attacks: Oversized files, malformed CSV, command injection
- Domain validation: RFC 1123/1035 test vectors, edge cases
- Error message review: Grep for file paths, exception messages in UI

**Performance Testing**:
- Startup time: Average of 10 cold starts with time measurement
- Favorites lookup: Benchmark with 100, 500, 1000 favorites
- Dig cache: Measure system call count before/after

**Regression Testing**:
- All existing DNS query types still work
- Batch lookup functionality unchanged
- Favorites add/remove/check still work
- History persistence still works

### Code Review Checklist
- [ ] All magic numbers replaced with named constants
- [ ] Null checks after all type casts
- [ ] Bounds checks before all array access in DNS parsing
- [ ] Error messages sanitized (no paths, no exceptions)
- [ ] Timeouts cancellable on widget destruction
- [ ] Validation applied to all user inputs
- [ ] Performance benchmarks documented
- [ ] No new compiler warnings
- [ ] Code style consistent with project

### Success Metrics
**Security**:
- ✅ 0 critical vulnerabilities (down from 1)
- ✅ 0 high vulnerabilities (down from 3)
- ✅ Security audit passes

**Code Quality**:
- ✅ 0 magic numbers in timeout/limit code
- ✅ >50% reduction in duplicated code (LOC metric)
- ✅ 0 null-safety warnings from type casts

**Performance**:
- ✅ Startup time < 1 second (200-500ms improvement)
- ✅ Favorites lookup 10x faster (benchmarked)
- ✅ 0 blocking operations in UI thread

**Reliability**:
- ✅ 0 crashes on malformed DNS responses
- ✅ 0 crashes on invalid user inputs
- ✅ All async errors handled or reported

## Appendix

### Related Documents
- `/CODEBASE_ANALYSIS.md` - Comprehensive analysis findings
- `/SECURITY_ANALYSIS.md` - Detailed security vulnerabilities
- `/SECURITY_QUICK_FIX_GUIDE.md` - Code-level remediation guide
- `openspec/project.md` - Project conventions

### References
- RFC 1123 - Requirements for Internet Hosts
- RFC 1035 - Domain Names - Implementation and Specification
- OWASP Input Validation Cheat Sheet
- GTK4 Documentation - Async patterns
- libgee Documentation - Collection types

### Revision History
- 2025-10-20: Initial design document (v1.0)
