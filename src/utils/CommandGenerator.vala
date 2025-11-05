/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024 tobagin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger {
    /**
     * Utility class for generating command-line equivalents of DNS queries
     * Supports dig commands and DoH curl commands
     */
    public class CommandGenerator : Object {
        private static CommandGenerator? instance = null;

        public static CommandGenerator get_instance () {
            if (instance == null) {
                instance = new CommandGenerator ();
            }
            return instance;
        }

        /**
         * Generate a dig command from query parameters
         * @param result The query result containing all parameters
         * @return The equivalent dig command string
         */
        public string generate_dig_command (QueryResult result) {
            var builder = new StringBuilder ();
            builder.append ("dig");

            // Add server specification if not default
            if (result.dns_server != "" && !is_default_server (result.dns_server)) {
                builder.append_printf (" @%s", shell_escape (result.dns_server));
            }

            // Add domain (with proper escaping)
            builder.append_printf (" %s", shell_escape (result.domain));

            // Add record type
            builder.append_printf (" %s", result.query_type.to_string ());

            // Add flags for advanced options
            if (result.trace_path) {
                builder.append (" +trace");
            }

            if (result.short_output) {
                builder.append (" +short");
            }

            // Check for DNSSEC - we need to infer this from the presence of DNSSEC records
            if (has_dnssec_records (result)) {
                builder.append (" +dnssec");
            }

            return builder.str;
        }

        /**
         * Generate a dig command for reverse DNS lookup
         * @param ip_address The IP address to lookup
         * @param dns_server Optional DNS server
         * @return The equivalent dig -x command string
         */
        public string generate_reverse_dig_command (string ip_address, string? dns_server = null) {
            var builder = new StringBuilder ();
            builder.append ("dig");

            if (dns_server != null && dns_server != "" && !is_default_server (dns_server)) {
                builder.append_printf (" @%s", shell_escape (dns_server));
            }

            builder.append_printf (" -x %s", shell_escape (ip_address));

            return builder.str;
        }

        /**
         * Generate a curl command for DoH (DNS over HTTPS) queries
         * @param domain The domain to query
         * @param record_type The DNS record type
         * @param doh_endpoint The DoH endpoint URL
         * @param use_dnssec Whether to request DNSSEC validation
         * @return The equivalent curl command string
         */
        public string generate_doh_curl_command (string domain, RecordType record_type,
                                                  string doh_endpoint, bool use_dnssec = false) {
            var builder = new StringBuilder ();

            // Multi-line format with backslashes
            builder.append ("curl -H 'accept: application/dns-json' \\\n");

            // Build the URL with query parameters
            string url = build_doh_url (doh_endpoint, domain, record_type, use_dnssec);
            builder.append_printf ("  '%s'", url);

            return builder.str;
        }

        /**
         * Generate DoH endpoint URL based on preset name
         * @param preset_name Name like "Cloudflare", "Google", "Quad9"
         * @return The DoH endpoint URL
         */
        public string get_doh_endpoint_from_preset (string preset_name) {
            switch (preset_name.down ()) {
                case "cloudflare":
                case "cloudflare-doh":
                    return "https://cloudflare-dns.com/dns-query";
                case "google":
                case "google-doh":
                    return "https://dns.google/resolve";
                case "quad9":
                case "quad9-doh":
                    return "https://dns.quad9.net/dns-query";
                default:
                    return preset_name; // Assume it's a custom URL
            }
        }

        /**
         * Generate a batch shell script with multiple dig commands
         * @param results List of query results to export
         * @param include_comments Whether to add explanatory comments
         * @return A shell script with all commands
         */
        public string generate_batch_script (Gee.ArrayList<QueryResult> results,
                                             bool include_comments = true) {
            var builder = new StringBuilder ();
            builder.append ("#!/bin/bash\n");

            if (include_comments) {
                builder.append ("# DNS Query Batch Script\n");
                builder.append ("# Generated by Digger\n");
                builder.append_printf ("# Date: %s\n\n",
                    new DateTime.now_local ().format ("%Y-%m-%d %H:%M:%S"));
            }

            foreach (var result in results) {
                if (include_comments) {
                    builder.append_printf ("# Query: %s (%s)\n",
                        result.domain, result.query_type.to_string ());
                }

                builder.append (generate_dig_command (result));
                builder.append ("\n\n");
            }

            return builder.str;
        }

        /**
         * Escape special shell characters in strings
         * @param input The string to escape
         * @return Shell-safe string
         */
        private string shell_escape (string input) {
            // Check if escaping is needed
            if (!needs_escaping (input)) {
                return input;
            }

            // Simple quote wrapping for strings with special characters
            return @"'$(input.replace ("'", "'\\''"))'";
        }

        /**
         * Check if a string needs shell escaping
         */
        private bool needs_escaping (string input) {
            return input.contains (" ") ||
                   input.contains ("$") ||
                   input.contains ("`") ||
                   input.contains ("\"") ||
                   input.contains ("\\") ||
                   input.contains ("!") ||
                   input.contains (";") ||
                   input.contains ("&") ||
                   input.contains ("|") ||
                   input.contains (">") ||
                   input.contains ("<") ||
                   input.contains ("*") ||
                   input.contains ("?") ||
                   input.contains ("[") ||
                   input.contains ("]") ||
                   input.contains ("(") ||
                   input.contains (")");
        }

        /**
         * Build DoH query URL with parameters
         */
        private string build_doh_url (string endpoint, string domain,
                                     RecordType record_type, bool use_dnssec) {
            var builder = new StringBuilder ();
            builder.append (endpoint);

            // Add query separator
            builder.append (endpoint.contains ("?") ? "&" : "?");

            // Add name parameter
            builder.append_printf ("name=%s", Uri.escape_string (domain));

            // Add type parameter (use wire type number)
            builder.append_printf ("&type=%d", record_type.to_wire_type ());

            // Add DNSSEC flag if requested
            if (use_dnssec) {
                builder.append ("&do=1");
            }

            return builder.str;
        }

        /**
         * Check if DNS server is a default/system server
         */
        private bool is_default_server (string server) {
            // Common indicators of default/system resolver
            return server == "127.0.0.53" ||
                   server == "127.0.0.1" ||
                   server.contains ("systemd-resolved") ||
                   server == "";
        }

        /**
         * Check if query result contains DNSSEC records
         */
        public bool has_dnssec_records (QueryResult result) {
            // Check all sections for DNSSEC-specific record types
            foreach (var record in result.answer_section) {
                if (is_dnssec_record_type (record.record_type)) {
                    return true;
                }
            }

            foreach (var record in result.authority_section) {
                if (is_dnssec_record_type (record.record_type)) {
                    return true;
                }
            }

            foreach (var record in result.additional_section) {
                if (is_dnssec_record_type (record.record_type)) {
                    return true;
                }
            }

            return false;
        }

        /**
         * Check if a record type is DNSSEC-related
         */
        private bool is_dnssec_record_type (RecordType type) {
            return type == RecordType.DNSKEY ||
                   type == RecordType.DS ||
                   type == RecordType.RRSIG ||
                   type == RecordType.NSEC ||
                   type == RecordType.NSEC3;
        }
    }
}
