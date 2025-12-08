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
    public class DnsQuery : Object {
        private const string DIG_COMMAND = "dig";
        private const int DEFAULT_TIMEOUT = Constants.DEFAULT_QUERY_TIMEOUT_SECONDS;

        // Cached dig availability check (SEC-003 Performance)
        private static bool? dig_available_cache = null;

        private GLib.Settings settings;
        
        public signal void query_completed (QueryResult result);
        public signal void query_failed (string error_message);
        
        public DnsQuery () {
            settings = new GLib.Settings (Config.APP_ID);
        }

        public async QueryResult? perform_query (string domain, RecordType record_type, 
                                                string? dns_server = null,
                                                bool reverse_lookup = false,
                                                bool trace_path = false,
                                                bool short_output = false,
                                                bool request_dnssec = false) {
            
            if (!is_valid_domain (domain) && !reverse_lookup) {
                var result = new QueryResult ();
                result.domain = domain;
                result.query_type = record_type;
                result.status = QueryStatus.INVALID_DOMAIN;
                query_failed ("Invalid domain format");
                return result;
            }

            // Check if dig command exists (with caching)
            if (!yield check_dig_available_async ()) {
                var result = new QueryResult ();
                result.domain = domain;
                result.query_type = record_type;
                result.status = QueryStatus.NO_DIG_COMMAND;
                query_failed ("dig command not found. Please install dnsutils package.");
                return result;
            }

            var result = new QueryResult ();
            result.domain = domain;
            result.query_type = record_type;
            result.dns_server = dns_server ?? "System default";
            result.reverse_lookup = reverse_lookup;
            result.trace_path = trace_path;
            result.short_output = short_output;
            result.request_dnssec = request_dnssec;

            var timer = new Timer ();
            timer.start ();

            try {
                string[] command_args = build_dig_command (domain, record_type, dns_server, 
                                                         reverse_lookup, trace_path, short_output, request_dnssec);
                
                string standard_output;
                string standard_error;
                int exit_status;

                bool success = yield run_command_async (command_args, out standard_output, 
                                                      out standard_error, out exit_status);

                timer.stop ();
                result.query_time_ms = timer.elapsed () * 1000;
                result.raw_output = standard_output;

                if (!success) {
                    result.status = QueryStatus.NETWORK_ERROR;
                    // SEC-009: Log full error, but send sanitized message to signal
                    critical ("Command execution failed: %s", standard_error);
                    query_failed ("Query execution failed. Please check your network connection.");
                    return result;
                }

                if (exit_status != 0) {
                    result.status = parse_dig_error (standard_output, standard_error);
                    if (result.status == QueryStatus.SUCCESS) {
                        result.status = QueryStatus.SERVFAIL; // Fallback
                    }
                    // SEC-009: Log full error details
                    critical ("Query failed with exit code %d: %s", exit_status, standard_error);
                    query_failed ("DNS query failed. The domain may not exist or the server is unreachable.");
                    return result;
                }

                // Parse dig output
                parse_dig_output (standard_output, result);
                query_completed (result);
                return result;

            } catch (Error e) {
                timer.stop ();
                result.query_time_ms = timer.elapsed () * 1000;
                result.status = QueryStatus.NETWORK_ERROR;
                // SEC-009: Log full error, send sanitized message
                critical ("Error executing query for %s: %s", domain, e.message);
                query_failed (ValidationUtils.get_user_friendly_error (e));
                return result;
            }
        }

        private string[] build_dig_command (string domain, RecordType record_type, string? dns_server,
                                          bool reverse_lookup, bool trace_path, bool short_output, bool request_dnssec) {
            var args = new Gee.ArrayList<string> ();
            args.add (DIG_COMMAND);

            // Add DNS server if specified
            if (dns_server != null && dns_server.length > 0) {
                args.add (@"@$dns_server");
            }

            // Add domain
            args.add (domain);

            // Add record type
            if (!reverse_lookup) {
                args.add (record_type.to_string ());
            }

            // Add options
            if (reverse_lookup) {
                args.add ("-x");
            }

            if (trace_path) {
                args.add ("+trace");
            }

            if (short_output) {
                args.add ("+short");
            }

            if (request_dnssec) {
                args.add ("+dnssec");
                args.add ("+nocrypto");
            }

            // Timeout from settings
            var timeout_seconds = (settings != null) ? settings.get_int ("query-timeout") : 10;
            args.add (@"+time=$timeout_seconds");

            // Convert to string array safely
            string[] result_args = new string[args.size];
            for (int i = 0; i < args.size; i++) {
                result_args[i] = args[i];
            }
            return result_args;
        }

        private async bool run_command_async (string[] command_args, out string standard_output,
                                            out string standard_error, out int exit_status) throws Error {
            Subprocess process = new Subprocess.newv (command_args, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);

            Bytes stdout_bytes, stderr_bytes;
            yield process.communicate_async (null, null, out stdout_bytes, out stderr_bytes);
            standard_output = (string) stdout_bytes.get_data();
            standard_error = (string) stderr_bytes.get_data();
            exit_status = process.get_exit_status ();

            return true;
        }

        /**
         * Synchronous version for use in background threads
         * This blocks but that's OK since it runs in a separate thread
         */
        private bool run_command_sync (string[] command_args, out string standard_output,
                                       out string standard_error, out int exit_status) throws Error {
            Process.spawn_sync (null, command_args, null,
                              SpawnFlags.SEARCH_PATH,
                              null,
                              out standard_output,
                              out standard_error,
                              out exit_status);
            return true;
        }

        /**
         * Synchronous query for use in background threads
         * Does NOT use async/yield so it can run in a thread without event loop
         */
        public QueryResult? perform_query_sync (string domain, RecordType record_type,
                                                string? dns_server = null,
                                                bool reverse_lookup = false,
                                                bool trace_path = false,
                                                bool short_output = false,
                                                bool request_dnssec = false) {
            var result = new QueryResult ();
            result.domain = domain;
            result.query_type = record_type;
            result.dns_server = dns_server ?? "System default";
            result.reverse_lookup = reverse_lookup;
            result.trace_path = trace_path;
            result.short_output = short_output;
            result.request_dnssec = request_dnssec;

            var timer = new Timer ();
            timer.start ();

            try {
                string[] command_args = build_dig_command (domain, record_type, dns_server,
                                                         reverse_lookup, trace_path, short_output, request_dnssec);

                string standard_output;
                string standard_error;
                int exit_status;

                bool success = run_command_sync (command_args, out standard_output,
                                                out standard_error, out exit_status);

                timer.stop ();
                result.query_time_ms = timer.elapsed () * 1000;
                result.raw_output = standard_output;

                if (!success) {
                    result.status = QueryStatus.NETWORK_ERROR;
                    return result;
                }

                if (exit_status != 0) {
                    result.status = QueryStatus.NETWORK_ERROR;
                    return result;
                }

                parse_dig_output (standard_output, result);
                return result;

            } catch (Error e) {
                timer.stop ();
                result.query_time_ms = timer.elapsed () * 1000;
                result.status = QueryStatus.NETWORK_ERROR;
                warning ("Error executing sync query for %s: %s", domain, e.message);
                return result;
            }
        }

        private void parse_dig_output (string output, QueryResult result) {
            result.status = QueryStatus.SUCCESS;
            
            if (result.short_output) {
                parse_short_output (output, result);
                return;
            }

            var lines = output.split ("\n");
            ParseSection current_section = ParseSection.NONE;
            bool has_section_headers = output.contains ("ANSWER SECTION") || 
                                      output.contains ("AUTHORITY SECTION") || 
                                      output.contains ("ADDITIONAL SECTION");

            foreach (string line in lines) {
                string trimmed_line = line.strip ();
                
                if (trimmed_line.length == 0) {
                    continue;
                }

                // Parse header status (e.g., "status: NXDOMAIN")
                if (trimmed_line.has_prefix (";;") && trimmed_line.contains ("->>HEADER<<-")) {
                    parse_header_status (trimmed_line, result);
                    continue;
                }

                // Handle query time and other stats
                if (trimmed_line.has_prefix (";;") && trimmed_line.contains ("Query time:")) {
                    parse_query_time (trimmed_line, result);
                    continue;
                }

                if (has_section_headers) {
                    // Check for section headers first (before skipping comments)
                    if (trimmed_line.contains ("ANSWER SECTION")) {
                        current_section = ParseSection.ANSWER;
                        continue;
                    } else if (trimmed_line.contains ("AUTHORITY SECTION")) {
                        current_section = ParseSection.AUTHORITY;
                        continue;
                    } else if (trimmed_line.contains ("ADDITIONAL SECTION")) {
                        current_section = ParseSection.ADDITIONAL;
                        continue;
                    }
                    
                    // Skip other comment lines when we have section headers
                    if (trimmed_line.has_prefix (";")) {
                        continue;
                    }
                } else {
                    // Without section headers, assume all DNS records are answers
                    // unless they contain stats info
                    if (trimmed_line.has_prefix (";;")) {
                        continue; // Skip stats lines
                    }
                    current_section = ParseSection.ANSWER;
                }

                // Parse DNS records
                var record = parse_dns_record_line (trimmed_line);
                if (record != null) {
                    switch (current_section) {
                        case ParseSection.ANSWER:
                            result.answer_section.add (record);
                            break;
                        case ParseSection.AUTHORITY:
                            result.authority_section.add (record);
                            break;
                        case ParseSection.ADDITIONAL:
                            result.additional_section.add (record);
                            break;
                        case ParseSection.NONE:
                            // Default section - add to answer
                            result.answer_section.add (record);
                            break;
                    }
                }
            }
        }

        private void parse_short_output (string output, QueryResult result) {
            var lines = output.split ("\n");
            foreach (string line in lines) {
                string trimmed_line = line.strip ();
                if (trimmed_line.length > 0) {
                    var record = new DnsRecord (result.domain, result.query_type, 0, trimmed_line);
                    result.answer_section.add (record);
                }
            }
        }

        private DnsRecord? parse_dns_record_line (string line) {
            var parts = line.split_set (" \t");
            var clean_parts = new Gee.ArrayList<string> ();

            // Remove empty parts
            foreach (string part in parts) {
                if (part.strip ().length > 0) {
                    clean_parts.add (part.strip ());
                }
            }

            // SEC-004: Enhanced bounds checking - minimum 5 fields expected:
            // name, TTL, class (IN), type, value
            if (clean_parts.size < Constants.MIN_DNS_RECORD_FIELDS) {
                if (clean_parts.size > 0) {
                    warning ("Skipping malformed DNS record line (insufficient fields): %s", line);
                }
                return null;
            }

            // SEC-004: Safe array access with bounds checking
            string name = clean_parts[0];
            string ttl_str = clean_parts[1];
            // clean_parts[2] is typically class (IN, CH, etc.) - skip it
            string type_str = clean_parts[3];

            int ttl = int.parse (ttl_str);
            RecordType record_type = RecordType.from_string (type_str);

            // SEC-004: Get the value (everything after the record type) with bounds check
            var value_parts = new Gee.ArrayList<string> ();
            if (clean_parts.size > 4) {
                for (int i = 4; i < clean_parts.size; i++) {
                    value_parts.add (clean_parts[i]);
                }
            }

            // Convert to string array safely
            string[] value_array = new string[value_parts.size];
            for (int i = 0; i < value_parts.size; i++) {
                value_array[i] = value_parts[i];
            }
            string value = string.joinv (" ", value_array);

            // SEC-004: Handle MX records specially for priority with bounds checking
            int priority = -1;
            if (record_type == RecordType.MX) {
                if (clean_parts.size >= 5) {
                    priority = int.parse (clean_parts[4]);
                    value_parts.clear ();

                    // SEC-004: Bounds check before accessing index 5
                    if (clean_parts.size >= 6) {
                        for (int i = 5; i < clean_parts.size; i++) {
                            value_parts.add (clean_parts[i]);
                        }
                        // Convert to string array safely
                        string[] mx_value_array = new string[value_parts.size];
                        for (int i = 0; i < value_parts.size; i++) {
                            mx_value_array[i] = value_parts[i];
                        }
                        value = string.joinv (" ", mx_value_array);
                    } else {
                        // Malformed MX record - has priority but no hostname
                        warning ("Skipping malformed MX record (missing hostname): %s", line);
                        return null;
                    }
                } else {
                    // Malformed MX record - no value at all
                    warning ("Skipping malformed MX record (no priority/value): %s", line);
                    return null;
                }
            }

            var record = new DnsRecord (name, record_type, ttl, value, priority);

            // Parse RRSIG specific fields
            if (record_type == RecordType.RRSIG && value_parts.size >= 8) {
                record.rrsig_type_covered = value_parts[0];
                record.rrsig_algorithm = value_parts[1];
                record.rrsig_labels = value_parts[2];
                record.rrsig_original_ttl = value_parts[3];
                record.rrsig_expiration = value_parts[4];
                record.rrsig_inception = value_parts[5];
                record.rrsig_key_tag = value_parts[6];
                record.rrsig_signer_name = value_parts[7];
                // Signature is in value_parts[8] and onwards
            }

            return record;
        }

        private void parse_header_status (string line, QueryResult result) {
            // Example: ";; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 49919"
            if (line.contains ("status:")) {
                var parts = line.split ("status:");
                if (parts.length >= 2) {
                    var status_part = parts[1].strip ();
                    var status_components = status_part.split (",");
                    if (status_components.length >= 1) {
                        string status = status_components[0].strip ().down ();
                        
                        switch (status) {
                            case "nxdomain":
                                result.status = QueryStatus.NXDOMAIN;
                                break;
                            case "servfail":
                                result.status = QueryStatus.SERVFAIL;
                                break;
                            case "noerror":
                                result.status = QueryStatus.SUCCESS;
                                break;
                            case "refused":
                                result.status = QueryStatus.REFUSED;
                                break;
                            case "formerr":
                                result.status = QueryStatus.NETWORK_ERROR;
                                break;
                            case "notimpl":
                                result.status = QueryStatus.NETWORK_ERROR;
                                break;
                            default:
                                // Keep existing status if unknown
                                break;
                        }
                    }
                }
            }
        }

        private void parse_query_time (string line, QueryResult result) {
            // Example: ";; Query time: 23 msec"
            var parts = line.split (":");
            if (parts.length >= 2) {
                var time_part = parts[1].strip ();
                var time_parts = time_part.split (" ");
                if (time_parts.length >= 1) {
                    result.query_time_ms = double.parse (time_parts[0]);
                }
            }
        }

        private QueryStatus parse_dig_error (string stdout, string stderr) {
            string combined = stdout + " " + stderr;
            string lower_combined = combined.down ();

            if (lower_combined.contains ("nxdomain")) {
                return QueryStatus.NXDOMAIN;
            } else if (lower_combined.contains ("servfail")) {
                return QueryStatus.SERVFAIL;
            } else if (lower_combined.contains ("timeout") || lower_combined.contains ("timed out")) {
                return QueryStatus.TIMEOUT;
            } else {
                return QueryStatus.NETWORK_ERROR;
            }
        }

        /**
         * Checks if dig command is available with session-level caching
         * Performance: Eliminates repeated 'which' system calls
         */
        private async bool check_dig_available_async () {
            // Check cache first - O(1) return if already checked
            if (dig_available_cache != null) {
                return dig_available_cache;
            }

            // Perform async check if cache is empty
            try {
                string standard_output;
                string standard_error;
                int exit_status;

                yield run_command_async ({"which", DIG_COMMAND},
                                        out standard_output,
                                        out standard_error,
                                        out exit_status);

                // Cache the result for session lifetime
                dig_available_cache = (exit_status == 0);

                if (dig_available_cache) {
                    message ("dig command found and cached");
                } else {
                    warning ("dig command not found");
                }

                return dig_available_cache;
            } catch (Error e) {
                // Cache negative result
                dig_available_cache = false;
                warning ("Error checking dig availability: %s", e.message);
                return false;
            }
        }

        /**
         * Legacy synchronous wrapper (deprecated, use async version)
         */
        private bool check_dig_available () {
            if (dig_available_cache != null) {
                return dig_available_cache;
            }

            try {
                string standard_output;
                int exit_status;

                Process.spawn_command_line_sync ("which " + DIG_COMMAND,
                                               out standard_output,
                                               null,
                                               out exit_status);
                dig_available_cache = (exit_status == 0);
                return dig_available_cache;
            } catch (SpawnError e) {
                dig_available_cache = false;
                return false;
            }
        }

        private bool is_valid_domain (string domain) {
            // SEC-003: Strengthened domain validation per RFC 1123/1035
            if (domain.length == 0 || domain.length > Constants.MAX_DOMAIN_LENGTH) {
                return false;
            }

            // SEC-003: Check for consecutive dots (not allowed)
            if (domain.contains ("..")) {
                return false;
            }

            // SEC-003: Check for starting/ending with dot or hyphen (not allowed per RFC)
            if (domain.has_prefix (".") || domain.has_suffix (".") ||
                domain.has_prefix ("-") || domain.has_suffix ("-")) {
                return false;
            }

            // Split into labels and validate each
            string[] labels = domain.split (".");

            // SEC-003: Empty labels not allowed
            if (labels.length == 0) {
                return false;
            }

            foreach (string label in labels) {
                // SEC-003: Empty labels not allowed
                if (label.length == 0) {
                    return false;
                }

                // SEC-003: Per-label length validation (max 63 characters per RFC 1035)
                if (label.length > Constants.MAX_LABEL_LENGTH) {
                    return false;
                }

                // SEC-003: Labels must start and end with alphanumeric character
                unichar first = label.get_char (0);
                unichar last = label.get_char (label.length - 1);

                if (!first.isalnum () || !last.isalnum ()) {
                    return false;
                }

                // Check label contains only valid characters (alphanumeric and hyphen)
                for (int i = 0; i < label.length; i++) {
                    unichar c = label.get_char (i);
                    if (!c.isalnum () && c != '-') {
                        return false;
                    }
                }
            }

            // Basic format validation with improved regex
            try {
                return Regex.match_simple ("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$", domain) ||
                       Regex.match_simple ("^[a-zA-Z0-9]$", domain);
            } catch (RegexError e) {
                return false;
            }
        }

        private enum ParseSection {
            NONE,
            ANSWER,
            AUTHORITY,
            ADDITIONAL
        }
    }
}
