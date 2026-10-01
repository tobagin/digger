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

    /**
     * Maximum DNS record data length for display
     * Truncates very long records to prevent UI issues
     */
    public const int MAX_RECORD_DATA_DISPLAY_LENGTH = 64;

    // ==================== Validation Constants ====================

    // Minimum expected fields in dig output record (name, TTL, class, type, value)
    public const int MIN_DNS_RECORD_FIELDS = 5;

    /**
     * Minimum expected fields for basic parsing
     * name, TTL, class, type
     */
    public const int MIN_DNS_RECORD_FIELDS_BASIC = 4;

    /**
     * Maximum TXT chunk length per RFC 1035 section 3.3.14 (255 bytes)
     */
    public const int MAX_TXT_CHUNK_LENGTH = 255;

    // ==================== File I/O Constants ====================

    // Maximum file size in bytes (computed from MB constant)
    public const int MAX_BATCH_FILE_SIZE_BYTES = MAX_BATCH_FILE_SIZE_MB * 1024 * 1024;

    // ==================== Threat Intelligence Constants ====================

    /**
     * VirusTotal API query timeout in seconds
     */
    public const int VT_QUERY_TIMEOUT_SECONDS = 30;

    /**
     * Default threat intel cache TTL in seconds (1 hour)
     */
    public const int THREAT_INTEL_CACHE_TTL_SECONDS = 3600;

    /**
     * Maximum threat intel cache entries
     */
    public const int THREAT_INTEL_CACHE_MAX_ENTRIES = 100;

    // ==================== IPv6 Connectivity Testing Constants (DIGG-004) ====================

    /**
     * IPv6 probe timeout in seconds (snappy to keep UI responsive)
     */
    public const int IPV6_PROBE_TIMEOUT_SECONDS = 5;

    /**
     * IPv6 AAAA query timeout in seconds
     */
    public const int IPV6_AAAA_TIMEOUT_SECONDS = 10;

    /**
     * Default IPv6 resolver for probe (Cloudflare)
     */
    public const string IPV6_PROBE_RESOLVER = "2606:4700:4700::1111";

    /**
     * Fallback IPv6 resolver (Google)
     */
    public const string IPV6_FALLBACK_RESOLVER = "2001:4860:4860::8888";

    /**
     * Domain used for IPv6 reachability probe
     */
    public const string IPV6_PROBE_DOMAIN = "google.com";

    /**
     * IPv6 cache TTL in seconds (10 minutes)
     */
    public const int IPV6_CACHE_TTL_SECONDS = 600;

    /**
     * Maximum IPv6 cache entries
     */
    public const int IPV6_CACHE_MAX_ENTRIES = 50;
}
