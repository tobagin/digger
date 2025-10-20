/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024 tobagin
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

        try {
            // IPv4 pattern: 0-255.0-255.0-255.0-255
            var regex = new Regex ("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$");
            return regex.match (input);
        } catch (RegexError e) {
            warning ("IPv4 validation regex error: %s", e.message);
            return false;
        }
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

        try {
            // IPv6 full format: 8 groups of 4 hex digits separated by colons
            // Also supports compressed format with :: for consecutive zeros
            // Simplified regex that covers most common IPv6 formats
            var regex = new Regex ("^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$");
            return regex.match (input);
        } catch (RegexError e) {
            warning ("IPv6 validation regex error: %s", e.message);
            return false;
        }
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

        // Check for consecutive dots (not allowed)
        if (hostname.contains ("..")) {
            return false;
        }

        // Split into labels and validate each
        string[] labels = hostname.split (".");
        if (labels.length == 0) {
            return false;
        }

        foreach (string label in labels) {
            // Each label must be 1-63 characters
            if (label.length == 0 || label.length > Constants.MAX_LABEL_LENGTH) {
                return false;
            }

            // Label must start and end with alphanumeric
            unichar first = label.get_char (0);
            unichar last = label.get_char (label.length - 1);

            if (!first.isalnum () || !last.isalnum ()) {
                return false;
            }

            // Label can only contain alphanumeric and hyphens
            try {
                var regex = new Regex ("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$");
                if (!regex.match (label)) {
                    return false;
                }
            } catch (RegexError e) {
                warning ("Hostname label validation regex error: %s", e.message);
                return false;
            }
        }

        return true;
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
     * Gets a user-friendly error message for DNS server validation failures
     *
     * @param server The invalid DNS server string
     * @return User-friendly error message
     */
    public string get_dns_server_error_message (string server) {
        if (server == null || server.strip ().length == 0) {
            return "DNS server address cannot be empty";
        }

        string trimmed = server.strip ();

        // Check for common mistakes
        if (trimmed.contains (" ")) {
            return "DNS server address cannot contain spaces";
        }

        if (trimmed.contains ("/") || trimmed.contains ("\\")) {
            return "DNS server address cannot contain slashes";
        }

        // Check if it might be an IPv4 with invalid octets
        if (trimmed.contains (".") && !trimmed.contains (":")) {
            var parts = trimmed.split (".");
            if (parts.length == 4) {
                foreach (string part in parts) {
                    int octet = int.parse (part);
                    if (octet < 0 || octet > 255) {
                        return "Invalid IPv4 address: octets must be 0-255";
                    }
                }
                return "Invalid IPv4 address format";
            }
            // Might be a hostname with dots
            return "Invalid hostname format. Must follow RFC 1123 rules:\n• Labels 1-63 characters\n• Start/end with letter or digit\n• Can contain hyphens in the middle";
        }

        // Check if it might be an IPv6
        if (trimmed.contains (":")) {
            return "Invalid IPv6 address format";
        }

        // Generic hostname error
        return "Invalid DNS server address.\nAccepted formats:\n• IPv4: 8.8.8.8\n• IPv6: 2001:4860:4860::8888\n• Hostname: dns.example.com";
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

    /**
     * Gets a user-friendly error message from an Error object (SEC-009)
     *
     * @param error The GLib.Error object
     * @return User-friendly error message
     */
    public string get_user_friendly_error (Error error) {
        // Common error patterns with user-friendly replacements
        string message = error.message;

        if (message.contains ("Permission denied") || message.contains ("EACCES")) {
            return "Permission denied. Please check file permissions.";
        }

        if (message.contains ("No such file") || message.contains ("ENOENT")) {
            return "File not found. Please check the file path.";
        }

        if (message.contains ("Disk quota") || message.contains ("EDQUOT")) {
            return "Not enough disk space available.";
        }

        if (message.contains ("Connection refused") || message.contains ("ECONNREFUSED")) {
            return "Connection refused. Please check your network connection.";
        }

        if (message.contains ("Network unreachable") || message.contains ("ENETUNREACH")) {
            return "Network unreachable. Please check your internet connection.";
        }

        if (message.contains ("Timeout") || message.contains ("ETIMEDOUT")) {
            return "Operation timed out. Please try again.";
        }

        // Fallback to sanitized version
        return sanitize_error_message (message);
    }
}
