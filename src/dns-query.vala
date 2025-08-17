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
        private const int DEFAULT_TIMEOUT = 10; // seconds
        
        public signal void query_completed (QueryResult result);
        public signal void query_failed (string error_message);

        public async QueryResult? perform_query (string domain, RecordType record_type, 
                                                string? dns_server = null,
                                                bool reverse_lookup = false,
                                                bool trace_path = false,
                                                bool short_output = false) {
            
            if (!is_valid_domain (domain) && !reverse_lookup) {
                var result = new QueryResult ();
                result.domain = domain;
                result.query_type = record_type;
                result.status = QueryStatus.INVALID_DOMAIN;
                query_failed ("Invalid domain format");
                return result;
            }

            // Check if dig command exists
            if (!check_dig_available ()) {
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

            var timer = new Timer ();
            timer.start ();

            try {
                string[] command_args = build_dig_command (domain, record_type, dns_server, 
                                                         reverse_lookup, trace_path, short_output);
                
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
                    query_failed (@"Command execution failed: $standard_error");
                    return result;
                }

                if (exit_status != 0) {
                    result.status = parse_dig_error (standard_output, standard_error);
                    if (result.status == QueryStatus.SUCCESS) {
                        result.status = QueryStatus.SERVFAIL; // Fallback
                    }
                    query_failed (@"Query failed with exit code $exit_status");
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
                query_failed (@"Error executing query: $(e.message)");
                return result;
            }
        }

        private string[] build_dig_command (string domain, RecordType record_type, string? dns_server,
                                          bool reverse_lookup, bool trace_path, bool short_output) {
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

            // Timeout
            args.add (@"+time=$DEFAULT_TIMEOUT");

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

            if (clean_parts.size < 4) {
                return null;
            }

            string name = clean_parts[0];
            string ttl_str = clean_parts[1];
            string type_str = clean_parts[3];
            
            int ttl = int.parse (ttl_str);
            RecordType record_type = RecordType.from_string (type_str);

            // Get the value (everything after the record type)
            var value_parts = new Gee.ArrayList<string> ();
            for (int i = 4; i < clean_parts.size; i++) {
                value_parts.add (clean_parts[i]);
            }
            // Convert to string array safely
            string[] value_array = new string[value_parts.size];
            for (int i = 0; i < value_parts.size; i++) {
                value_array[i] = value_parts[i];
            }
            string value = string.joinv (" ", value_array);

            // Handle MX records specially for priority
            int priority = -1;
            if (record_type == RecordType.MX && clean_parts.size >= 5) {
                priority = int.parse (clean_parts[4]);
                if (clean_parts.size >= 6) {
                    value_parts.clear ();
                    for (int i = 5; i < clean_parts.size; i++) {
                        value_parts.add (clean_parts[i]);
                    }
                    // Convert to string array safely
                    string[] mx_value_array = new string[value_parts.size];
                    for (int i = 0; i < value_parts.size; i++) {
                        mx_value_array[i] = value_parts[i];
                    }
                    value = string.joinv (" ", mx_value_array);
                }
            }

            return new DnsRecord (name, record_type, ttl, value, priority);
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

        private bool check_dig_available () {
            try {
                string standard_output;
                int exit_status;
                
                Process.spawn_command_line_sync ("which " + DIG_COMMAND, 
                                               out standard_output, 
                                               null, 
                                               out exit_status);
                return exit_status == 0;
            } catch (SpawnError e) {
                return false;
            }
        }

        private bool is_valid_domain (string domain) {
            // Basic domain validation
            if (domain.length == 0 || domain.length > 253) {
                return false;
            }

            // Check for valid characters and format
            return Regex.match_simple ("^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$", domain) ||
                   Regex.match_simple ("^[a-zA-Z0-9]$", domain);
        }

        private enum ParseSection {
            NONE,
            ANSWER,
            AUTHORITY,
            ADDITIONAL
        }
    }
}
