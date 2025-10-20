/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024 tobagin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger.Constants {
    // ==================== Timeout Values (milliseconds) ====================

    /**
     * Delay before showing release notes on startup
     * Used to ensure UI is fully loaded before displaying dialog
     */
    public const int RELEASE_NOTES_DELAY_MS = 500;

    /**
     * UI refresh delay for smooth transitions
     * Used in various UI update operations
     */
    public const int UI_REFRESH_DELAY_MS = 100;

    /**
     * Autocomplete dropdown hide delay
     * Allows user to move mouse without dropdown disappearing
     */
    public const int DROPDOWN_HIDE_DELAY_MS = 150;

    /**
     * Delay between sequential batch operations
     * Prevents overwhelming the system with too many requests
     */
    public const int BATCH_SEQUENTIAL_DELAY_MS = 100;

    /**
     * Default DNS query timeout in seconds
     * Maximum time to wait for a DNS response
     */
    public const int DEFAULT_QUERY_TIMEOUT_SECONDS = 10;

    /**
     * DoH (DNS-over-HTTPS) query timeout in seconds
     * Timeout for HTTPS-based DNS queries
     */
    public const int DOH_QUERY_TIMEOUT_SECONDS = 30;

    /**
     * Toast notification display duration in seconds
     * How long success/info toasts are shown to the user
     */
    public const int TOAST_TIMEOUT_SECONDS = 2;

    /**
     * Error toast display duration in seconds (SEC-009)
     * Longer timeout for error messages so users can read them
     */
    public const int ERROR_TOAST_TIMEOUT_SECONDS = 5;

    // ==================== Size Limits ====================

    /**
     * Maximum batch file size in megabytes (SEC-002)
     * Prevents memory exhaustion from oversized batch files
     */
    public const int MAX_BATCH_FILE_SIZE_MB = 10;

    /**
     * Maximum number of lines in a batch file (SEC-002)
     * Prevents excessive processing time
     */
    public const int MAX_BATCH_LINES = 10000;

    /**
     * Maximum query history size
     * Number of queries to keep in history
     */
    public const int MAX_HISTORY_SIZE = 100;

    /**
     * Maximum domain length per RFC 1035 (SEC-003)
     * Total length of a fully-qualified domain name
     */
    public const int MAX_DOMAIN_LENGTH = 253;

    /**
     * Maximum label length per RFC 1035 (SEC-003)
     * Maximum length of a single label in a domain name
     */
    public const int MAX_LABEL_LENGTH = 63;

    // ==================== Performance Tuning ====================

    /**
     * Parallel batch size
     * Number of DNS queries to execute in parallel
     */
    public const int PARALLEL_BATCH_SIZE = 5;

    /**
     * High-end system parallel batch size
     * Used when system has sufficient resources
     */
    public const int PARALLEL_BATCH_SIZE_HIGH = 10;

    /**
     * Low-end/error-recovery parallel batch size
     * Used when errors are detected or system is constrained
     */
    public const int PARALLEL_BATCH_SIZE_LOW = 3;

    // ==================== DNS Protocol Constants ====================

    /**
     * Minimum DNS packet size in bytes
     * Used for validation in DoH response parsing
     */
    public const int MIN_DNS_PACKET_SIZE = 12;

    /**
     * Maximum DNS record data length for display
     * Truncates very long records to prevent UI issues
     */
    public const int MAX_RECORD_DATA_DISPLAY_LENGTH = 64;

    // ==================== Validation Constants ====================

    /**
     * Minimum expected fields in dig output record
     * name, TTL, class, type, value
     */
    public const int MIN_DNS_RECORD_FIELDS = 5;

    /**
     * Minimum expected fields for basic parsing
     * name, TTL, class, type
     */
    public const int MIN_DNS_RECORD_FIELDS_BASIC = 4;

    // ==================== File I/O Constants ====================

    /**
     * Maximum file size in bytes (computed from MB constant)
     * Used for actual file size validation
     */
    public const int MAX_BATCH_FILE_SIZE_BYTES = MAX_BATCH_FILE_SIZE_MB * 1024 * 1024;
}
