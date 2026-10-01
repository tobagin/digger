/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger.ValidationUtils {
    /**
     * Validates if a string is a valid IPv4 address
     *
     * @param input The string to validate
     * @return true if valid IPv4 address, false otherwise
     */
    public bool is_valid_ipv4 (string input) {
        if (input == null || input.length == 0) {
            return false;
        }

        var address = new GLib.InetAddress.from_string (input);
        return address != null && address.get_family () == GLib.SocketFamily.IPV4;
    }

    /**
     * Validates if a string is a valid IPv6 address
     * Supports full and compressed formats
     *
     * @param input The string to validate
     * @return true if valid IPv6 address, false otherwise
     */
    public bool is_valid_ipv6 (string input) {
        if (input == null || input.length == 0) {
            return false;
        }

        var address = new GLib.InetAddress.from_string (input);
        return address != null && address.get_family () == GLib.SocketFamily.IPV6;
    }

    /**
     * Validates if a string is a valid hostname per RFC 1123
     *
     * Requirements:
     * - Labels separated by dots
     * - Each label 1-63 characters
     * - Labels start and end with alphanumeric
     * - Labels can contain hyphens in the middle
     * - Total length <= 253 characters
     *
     * @param input The string to validate
     * @return true if valid hostname, false otherwise
     */
    public bool is_valid_hostname (string input) {
        if (input == null || input.length == 0 || input.length > Constants.MAX_DOMAIN_LENGTH) {
            return false;
        }

        // Remove trailing dot if present (allowed in FQDN)
        string hostname = input;
        if (hostname.has_suffix (".")) {
            hostname = hostname.substring (0, hostname.length - 1);
        }

        // Each label must be 1-63 characters
        foreach (string label in hostname.split (".")) {
            if (label.length == 0 || label.length > Constants.MAX_LABEL_LENGTH) {
                return false;
            }
        }

        // Labels are alphanumeric, may contain interior hyphens, dot-separated
        return Regex.match_simple (
            "^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$",
            hostname);
    }

    /**
     * Validates if a string is a valid DNS server address
     * Accepts IPv4, IPv6, or hostname
     *
     * @param server The DNS server address to validate
     * @return true if valid DNS server address, false otherwise
     */
    public bool validate_dns_server (string server) {
        if (server == null || server.length == 0) {
            return false;
        }

        string trimmed = server.strip ();

        if (trimmed.length == 0) {
            return false;
        }

        // Check if it's a valid IPv4, IPv6, or hostname
        return is_valid_ipv4 (trimmed) ||
               is_valid_ipv6 (trimmed) ||
               is_valid_hostname (trimmed);
    }

    /**
     * Strips URL components (scheme, path) from an input string,
     * returning just the host part. Non-URL input is returned trimmed.
     *
     * @param input The string to strip
     * @return the host portion of a URL, or the trimmed input
     */
    public string strip_url (string input) {
        string domain = input.strip ();

        if (domain.has_prefix ("http://") || domain.has_prefix ("https://")) {
            try {
                var uri = GLib.Uri.parse (domain, GLib.UriFlags.NONE);
                if (uri.get_host () != null) {
                    domain = uri.get_host ();
                }
            } catch (Error e) {
                // Fallback to manual stripping if Uri parsing fails
                int schema_end = domain.index_of ("://");
                if (schema_end != -1) {
                    domain = domain.substring (schema_end + 3);
                }
                int path_start = domain.index_of ("/");
                if (path_start != -1) {
                    domain = domain.substring (0, path_start);
                }
            }
        }

        return domain;
    }

    /**
     * Validates if a URL uses HTTPS protocol
     *
     * @param url The URL to validate
     * @return true if HTTPS, false otherwise
     */
    public bool is_https_url (string url) {
        if (url == null || url.length == 0) {
            return false;
        }

        string trimmed = url.strip ().down ();
        return trimmed.has_prefix ("https://");
    }

    /**
     * Sanitizes error messages for user display (SEC-009)
     * Removes sensitive information like file paths and system details
     *
     * @param error_message The original error message
     * @return Sanitized error message suitable for user display
     */
    public string sanitize_error_message (string error_message) {
        if (error_message == null || error_message.length == 0) {
            return "An error occurred";
        }

        string sanitized = error_message;

        // Remove file paths (common patterns)
        try {
            // Remove absolute paths starting with /
            var regex = new Regex ("/[a-zA-Z0-9/_.-]+");
            sanitized = regex.replace (sanitized, -1, 0, "[path]");

            // Remove Windows-style paths
            regex = new Regex ("[A-Z]:\\\\[a-zA-Z0-9\\\\._-]+");
            sanitized = regex.replace (sanitized, -1, 0, "[path]");

            // Remove home directory references
            sanitized = sanitized.replace (Environment.get_home_dir (), "[home]");
            sanitized = sanitized.replace ("~", "[home]");

            // Remove specific technical details
            sanitized = sanitized.replace ("GLib.", "");
            sanitized = sanitized.replace ("IOError.", "");
            sanitized = sanitized.replace ("FileError.", "");

        } catch (RegexError e) {
            // If regex fails, return generic message
            return "An error occurred. Check logs for details.";
        }

        // If message is now too short or generic, provide better context
        if (sanitized.length < 10) {
            return "Operation failed. Please try again.";
        }

        return sanitized;
    }
}
