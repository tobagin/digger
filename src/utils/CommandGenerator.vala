/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
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
         * Escape special shell characters in strings
         * @param input The string to escape
         * @return Shell-safe string
         */
        private string shell_escape (string input) {
            // GLib's quoter is correct on every shell metacharacter, including
            // the single quote the previous hand-rolled check missed.
            return Shell.quote (input);
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
