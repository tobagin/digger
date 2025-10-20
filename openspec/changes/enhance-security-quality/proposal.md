# Phase 1: Critical Security Hardening and Code Quality Baseline

## Why

Based on comprehensive codebase analysis (see `CODEBASE_ANALYSIS.md` and `SECURITY_ANALYSIS.md`), Digger has **13 security vulnerabilities** (1 Critical, 3 High, 5 Medium, 4 Low) and **42 code quality issues** that need to be addressed before the application is production-ready. The analysis identified command injection risks, insufficient input validation, error message information disclosure, and code maintainability concerns that impact security, stability, and user trust.

This proposal addresses the most critical Phase 1 (P0) improvements to establish a secure and maintainable foundation for future enhancements.

## What Changes

### Security Hardening (Critical)
- **SEC-001**: Implement strict DNS server validation (IPv4, IPv6, hostname) in custom DNS input
- **SEC-002**: Add comprehensive batch file validation with size limits and field sanitization
- **SEC-003**: Strengthen domain validation regex for RFC 1123/1035 compliance
- **SEC-004**: Enhance DNS response parsing boundary checking
- **SEC-006**: Enforce HTTPS-only for DoH endpoints
- **SEC-009**: Sanitize error messages to prevent information disclosure

### Code Quality Improvements
- Extract duplicated code patterns (ArrayList→array conversion, section rendering)
- Add null safety checks after type casting
- Create centralized constants file for magic numbers
- Implement proper async timeout cancellation
- Enhance error handling with user-facing notifications

### Performance Optimizations (Quick Wins)
- Lazy-load query history on first access (reduce startup time)
- Implement hash-based favorites lookup (O(n) → O(1))
- Cache dig availability check (eliminate repeated system calls)

## Impact

### Affected Specifications
- **security-validation** (NEW): Input validation, DNS server validation, DoH security
- **code-quality** (NEW): Error handling, null safety, code organization
- **performance** (NEW): Caching strategies, lookup optimization

### Affected Code
- `src/widgets/EnhancedQueryForm.vala` - DNS server validation
- `src/managers/BatchLookupManager.vala` - File import validation
- `src/services/DnsQuery.vala` - Domain validation, error handling, parsing
- `src/services/SecureDns.vala` - DoH HTTPS enforcement
- `src/managers/FavoritesManager.vala` - Hash-based lookup
- `src/services/QueryHistory.vala` - Lazy loading
- `src/utils/Constants.vala` (NEW) - Centralized constants
- `src/dialogs/Window.vala` - Timeout cancellation
- `src/utils/ThemeManager.vala` - Error handling

### Breaking Changes
None - all changes are internal improvements maintaining existing APIs

### Estimated Effort
**Total: 40 hours**
- Security fixes: 8 hours
- Code quality: 17 hours
- Performance: 5 hours
- Testing & validation: 10 hours

### Dependencies
None - this is the foundation for future changes

### Risks
- Regex changes may affect edge-case domains (mitigated by comprehensive testing)
- Stricter validation may reject previously accepted inputs (acceptable security trade-off)

### Success Metrics
- ✅ Zero critical/high security vulnerabilities
- ✅ All magic numbers eliminated
- ✅ 50% reduction in code duplication
- ✅ Startup time improved by 200-500ms
- ✅ Favorites lookup 10x faster
