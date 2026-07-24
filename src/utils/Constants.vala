/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger.Constants {
    // ==================== Timeout Values (milliseconds) ====================

    // Delay before showing release notes on startup
    public const int RELEASE_NOTES_DELAY_MS = 500;

    // Autocomplete dropdown hide delay
    public const int DROPDOWN_HIDE_DELAY_MS = 150;

    // Delay between sequential batch operations
    public const int BATCH_SEQUENTIAL_DELAY_MS = 100;

    // Default DNS query timeout in seconds
    public const int DEFAULT_QUERY_TIMEOUT_SECONDS = 10;

    // Toast notification display duration in seconds
    public const int TOAST_TIMEOUT_SECONDS = 2;

    // Error toast display duration in seconds (SEC-009)
    public const int ERROR_TOAST_TIMEOUT_SECONDS = 5;

    // ==================== Size Limits ====================

    // Maximum batch file size in megabytes (SEC-002)
    public const int MAX_BATCH_FILE_SIZE_MB = 10;

    // Maximum number of lines in a batch file (SEC-002)
    public const int MAX_BATCH_LINES = 10000;

    // Maximum domain length per RFC 1035 (SEC-003)
    public const int MAX_DOMAIN_LENGTH = 253;

    // Maximum label length per RFC 1035 (SEC-003)
    public const int MAX_LABEL_LENGTH = 63;

    // ==================== Performance Tuning ====================

    // Number of DNS queries to execute in parallel
    public const int PARALLEL_BATCH_SIZE = 5;

    // ==================== Validation Constants ====================

    // Minimum expected fields in dig output record (name, TTL, class, type, value)
    public const int MIN_DNS_RECORD_FIELDS = 5;

    // ==================== File I/O Constants ====================

    // Maximum file size in bytes (computed from MB constant)
    public const int MAX_BATCH_FILE_SIZE_BYTES = MAX_BATCH_FILE_SIZE_MB * 1024 * 1024;
}
