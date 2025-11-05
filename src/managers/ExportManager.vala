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
    public enum ExportFormat {
        JSON,
        CSV,
        TEXT,
        ZONE_FILE;

        public string to_string () {
            switch (this) {
                case JSON: return "JSON";
                case CSV: return "CSV";
                case TEXT: return "Plain Text";
                case ZONE_FILE: return "DNS Zone File";
                default: return "Unknown";
            }
        }

        public string get_extension () {
            switch (this) {
                case JSON: return "json";
                case CSV: return "csv";
                case TEXT: return "txt";
                case ZONE_FILE: return "zone";
                default: return "txt";
            }
        }

        public string get_mime_type () {
            switch (this) {
                case JSON: return "application/json";
                case CSV: return "text/csv";
                case TEXT: return "text/plain";
                case ZONE_FILE: return "text/dns";
                default: return "text/plain";
            }
        }
    }

    public class ExportManager : Object {
        private static ExportManager? instance = null;
        private CommandGenerator command_generator;

        public static ExportManager get_instance () {
            if (instance == null) {
                instance = new ExportManager ();
            }
            return instance;
        }

        construct {
            command_generator = CommandGenerator.get_instance ();
        }

        public async bool export_result (QueryResult result, File file, ExportFormat format) {
            try {
                string content = generate_export_content (result, format);
                yield file.replace_contents_async (
                    content.data,
                    null,
                    false,
                    FileCreateFlags.REPLACE_DESTINATION,
                    null,
                    null
                );
                return true;
            } catch (Error e) {
                warning ("Export failed: %s", e.message);
                return false;
            }
        }

        public async bool export_multiple_results (Gee.ArrayList<QueryResult> results,
                                                   File file, ExportFormat format) {
            try {
                string content = generate_multiple_export_content (results, format);
                yield file.replace_contents_async (
                    content.data,
                    null,
                    false,
                    FileCreateFlags.REPLACE_DESTINATION,
                    null,
                    null
                );
                return true;
            } catch (Error e) {
                warning ("Export failed: %s", e.message);
                return false;
            }
        }

        private string generate_export_content (QueryResult result, ExportFormat format) {
            switch (format) {
                case ExportFormat.JSON:
                    return generate_json (result);
                case ExportFormat.CSV:
                    return generate_csv (result);
                case ExportFormat.TEXT:
                    return generate_text (result);
                case ExportFormat.ZONE_FILE:
                    return generate_zone_file (result);
                default:
                    return generate_text (result);
            }
        }

        private string generate_multiple_export_content (Gee.ArrayList<QueryResult> results,
                                                        ExportFormat format) {
            var builder = new StringBuilder ();

            switch (format) {
                case ExportFormat.JSON:
                    builder.append ("[\n");
                    for (int i = 0; i < results.size; i++) {
                        builder.append ("  ");
                        builder.append (generate_json (results[i]));
                        if (i < results.size - 1) {
                            builder.append (",");
                        }
                        builder.append ("\n");
                    }
                    builder.append ("]\n");
                    break;

                case ExportFormat.CSV:
                    builder.append ("Domain,Record Type,Status,Query Time (ms),DNS Server,Timestamp,Record Name,TTL,Type,Value,WHOIS Registrar,WHOIS Created,WHOIS Expires\n");
                    foreach (var result in results) {
                        builder.append (generate_csv_rows (result));
                    }
                    break;

                case ExportFormat.TEXT:
                    for (int i = 0; i < results.size; i++) {
                        builder.append (generate_text (results[i]));
                        if (i < results.size - 1) {
                            builder.append ("\n" + string.nfill (80, '=') + "\n\n");
                        }
                    }
                    break;

                case ExportFormat.ZONE_FILE:
                    foreach (var result in results) {
                        builder.append (generate_zone_file (result));
                        builder.append ("\n");
                    }
                    break;
            }

            return builder.str;
        }

        private string generate_json (QueryResult result) {
            var builder = new StringBuilder ();
            builder.append ("{\n");
            builder.append_printf ("  \"domain\": \"%s\",\n", escape_json_string (result.domain));
            builder.append_printf ("  \"recordType\": \"%s\",\n", result.query_type.to_string ());
            builder.append_printf ("  \"status\": \"%s\",\n", result.status.to_string ());
            builder.append_printf ("  \"queryTimeMs\": %.2f,\n", result.query_time_ms);
            builder.append_printf ("  \"dnsServer\": \"%s\",\n", escape_json_string (result.dns_server));
            builder.append_printf ("  \"timestamp\": \"%s\",\n", result.timestamp.format ("%Y-%m-%d %H:%M:%S"));

            builder.append ("  \"answerSection\": [\n");
            append_records_json (builder, result.answer_section);
            builder.append ("  ],\n");

            builder.append ("  \"authoritySection\": [\n");
            append_records_json (builder, result.authority_section);
            builder.append ("  ],\n");

            builder.append ("  \"additionalSection\": [\n");
            append_records_json (builder, result.additional_section);
            builder.append ("  ]");

            // Add WHOIS data if available
            if (result.whois_data != null) {
                builder.append (",\n");
                append_whois_json (builder, result.whois_data);
            }

            builder.append ("\n}");
            return builder.str;
        }

        private void append_whois_json (StringBuilder builder, WhoisData whois) {
            builder.append ("  \"whois\": {\n");
            builder.append_printf ("    \"domain\": \"%s\",\n", escape_json_string (whois.domain));

            if (whois.registrar != null) {
                builder.append_printf ("    \"registrar\": \"%s\",\n", escape_json_string (whois.registrar));
            }

            if (whois.created_date != null) {
                builder.append_printf ("    \"createdDate\": \"%s\",\n", escape_json_string (whois.created_date));
            }

            if (whois.updated_date != null) {
                builder.append_printf ("    \"updatedDate\": \"%s\",\n", escape_json_string (whois.updated_date));
            }

            if (whois.expires_date != null) {
                builder.append_printf ("    \"expiresDate\": \"%s\",\n", escape_json_string (whois.expires_date));
            }

            builder.append_printf ("    \"privacyProtected\": %s,\n", whois.privacy_protected ? "true" : "false");
            builder.append_printf ("    \"fromCache\": %s,\n", whois.from_cache ? "true" : "false");

            if (whois.nameservers.size > 0) {
                builder.append ("    \"nameservers\": [\n");
                for (int i = 0; i < whois.nameservers.size; i++) {
                    builder.append_printf ("      \"%s\"", escape_json_string (whois.nameservers[i]));
                    if (i < whois.nameservers.size - 1) {
                        builder.append (",");
                    }
                    builder.append ("\n");
                }
                builder.append ("    ],\n");
            }

            if (whois.status.size > 0) {
                builder.append ("    \"status\": [\n");
                for (int i = 0; i < whois.status.size; i++) {
                    builder.append_printf ("      \"%s\"", escape_json_string (whois.status[i]));
                    if (i < whois.status.size - 1) {
                        builder.append (",");
                    }
                    builder.append ("\n");
                }
                builder.append ("    ],\n");
            }

            builder.append_printf ("    \"timestamp\": \"%s\"\n", whois.timestamp.format ("%Y-%m-%d %H:%M:%S"));
            builder.append ("  }");
        }

        private void append_records_json (StringBuilder builder, Gee.ArrayList<DnsRecord> records) {
            for (int i = 0; i < records.size; i++) {
                var record = records[i];
                builder.append ("    {\n");
                builder.append_printf ("      \"name\": \"%s\",\n", escape_json_string (record.name));
                builder.append_printf ("      \"ttl\": %d,\n", record.ttl);
                builder.append_printf ("      \"type\": \"%s\",\n", record.record_type.to_string ());
                builder.append_printf ("      \"value\": \"%s\"", escape_json_string (record.value));
                if (record.priority >= 0) {
                    builder.append_printf (",\n      \"priority\": %d\n", record.priority);
                } else {
                    builder.append ("\n");
                }
                builder.append ("    }");
                if (i < records.size - 1) {
                    builder.append (",");
                }
                builder.append ("\n");
            }
        }

        private string generate_csv (QueryResult result) {
            var builder = new StringBuilder ();
            builder.append ("Domain,Record Type,Status,Query Time (ms),DNS Server,Timestamp,Record Name,TTL,Type,Value,WHOIS Registrar,WHOIS Created,WHOIS Expires\n");
            builder.append (generate_csv_rows (result));
            return builder.str;
        }

        private string generate_csv_rows (QueryResult result) {
            var builder = new StringBuilder ();

            // WHOIS fields for CSV
            string whois_registrar = result.whois_data != null && result.whois_data.registrar != null ?
                                      result.whois_data.registrar : "N/A";
            string whois_created = result.whois_data != null && result.whois_data.created_date != null ?
                                    result.whois_data.created_date : "N/A";
            string whois_expires = result.whois_data != null && result.whois_data.expires_date != null ?
                                    result.whois_data.expires_date : "N/A";

            var base_info = @"\"$(escape_csv (result.domain))\",\"$(result.query_type.to_string ())\",\"$(result.status.to_string ())\",\"$(result.query_time_ms)\",\"$(escape_csv (result.dns_server))\",\"$(result.timestamp.format ("%Y-%m-%d %H:%M:%S"))\"";

            foreach (var record in result.answer_section) {
                builder.append (base_info);
                builder.append_printf (",\"%s\",%d,\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n",
                    escape_csv (record.name),
                    record.ttl,
                    record.record_type.to_string (),
                    escape_csv (record.value),
                    escape_csv (whois_registrar),
                    escape_csv (whois_created),
                    escape_csv (whois_expires));
            }

            return builder.str;
        }

        private string generate_text (QueryResult result) {
            var builder = new StringBuilder ();
            builder.append_printf ("DNS Query Results\n");
            builder.append_printf ("================\n\n");
            builder.append_printf ("Domain: %s\n", result.domain);
            builder.append_printf ("Record Type: %s\n", result.query_type.to_string ());
            builder.append_printf ("Status: %s\n", result.status.to_string ());
            builder.append_printf ("Query Time: %.2f ms\n", result.query_time_ms);
            builder.append_printf ("DNS Server: %s\n", result.dns_server);
            builder.append_printf ("Timestamp: %s\n\n", result.timestamp.format ("%Y-%m-%d %H:%M:%S"));

            if (result.answer_section.size > 0) {
                builder.append ("Answer Section:\n");
                builder.append (string.nfill (60, '-') + "\n");
                foreach (var record in result.answer_section) {
                    builder.append_printf ("%-30s %6d IN %-8s %s\n",
                        record.name, record.ttl, record.record_type.to_string (), record.value);
                }
                builder.append ("\n");
            }

            if (result.authority_section.size > 0) {
                builder.append ("Authority Section:\n");
                builder.append (string.nfill (60, '-') + "\n");
                foreach (var record in result.authority_section) {
                    builder.append_printf ("%-30s %6d IN %-8s %s\n",
                        record.name, record.ttl, record.record_type.to_string (), record.value);
                }
                builder.append ("\n");
            }

            if (result.additional_section.size > 0) {
                builder.append ("Additional Section:\n");
                builder.append (string.nfill (60, '-') + "\n");
                foreach (var record in result.additional_section) {
                    builder.append_printf ("%-30s %6d IN %-8s %s\n",
                        record.name, record.ttl, record.record_type.to_string (), record.value);
                }
                builder.append ("\n");
            }

            // Add WHOIS information if available
            if (result.whois_data != null) {
                append_whois_text (builder, result.whois_data);
            }

            return builder.str;
        }

        private void append_whois_text (StringBuilder builder, WhoisData whois) {
            builder.append ("WHOIS Information");
            if (whois.from_cache) {
                builder.append (" (Cached)");
            }
            builder.append ("\n");
            builder.append (string.nfill (60, '=') + "\n\n");

            if (whois.registrar != null) {
                builder.append_printf ("Registrar: %s\n", whois.registrar);
            }

            if (whois.created_date != null) {
                builder.append_printf ("Created: %s\n", whois.created_date);
            }

            if (whois.updated_date != null) {
                builder.append_printf ("Updated: %s\n", whois.updated_date);
            }

            if (whois.expires_date != null) {
                builder.append_printf ("Expires: %s\n", whois.expires_date);
            }

            if (whois.nameservers.size > 0) {
                builder.append ("\nNameservers:\n");
                foreach (var ns in whois.nameservers) {
                    builder.append_printf ("  - %s\n", ns);
                }
            }

            if (whois.status.size > 0) {
                builder.append ("\nDomain Status:\n");
                foreach (var status in whois.status) {
                    builder.append_printf ("  - %s\n", status);
                }
            }

            if (whois.privacy_protected) {
                builder.append ("\nPrivacy: Protected (contact information redacted)\n");
            }

            builder.append ("\n");
        }

        private string generate_zone_file (QueryResult result) {
            var builder = new StringBuilder ();
            builder.append_printf ("; Zone file for %s\n", result.domain);
            builder.append_printf ("; Generated by Digger on %s\n",
                result.timestamp.format ("%Y-%m-%d %H:%M:%S"));
            builder.append_printf ("; Query type: %s\n\n", result.query_type.to_string ());

            foreach (var record in result.answer_section) {
                builder.append_printf ("%-30s %6d IN %-8s %s\n",
                    record.name, record.ttl, record.record_type.to_string (), record.value);
            }

            return builder.str;
        }

        private string escape_json_string (string str) {
            return str.replace ("\\", "\\\\")
                     .replace ("\"", "\\\"")
                     .replace ("\n", "\\n")
                     .replace ("\r", "\\r")
                     .replace ("\t", "\\t");
        }

        private string escape_csv (string str) {
            if (str.contains (",") || str.contains ("\"") || str.contains ("\n")) {
                return str.replace ("\"", "\"\"");
            }
            return str;
        }

        /**
         * Generate dig command from query result
         * @param result The query result to convert to a dig command
         * @return The equivalent dig command string
         */
        public string export_as_dig_command (QueryResult result) {
            if (result.reverse_lookup) {
                return command_generator.generate_reverse_dig_command (
                    result.domain,
                    result.dns_server
                );
            } else {
                return command_generator.generate_dig_command (result);
            }
        }

        /**
         * Generate DoH curl command from query result
         * @param result The query result
         * @param doh_endpoint The DoH endpoint URL or preset name
         * @return The equivalent curl command string
         */
        public string export_as_doh_curl (QueryResult result, string doh_endpoint) {
            string endpoint_url = command_generator.get_doh_endpoint_from_preset (doh_endpoint);
            bool use_dnssec = command_generator.has_dnssec_records (result);

            return command_generator.generate_doh_curl_command (
                result.domain,
                result.query_type,
                endpoint_url,
                use_dnssec
            );
        }

        /**
         * Generate batch script from multiple query results
         * @param results List of query results
         * @param file Output file for the script
         * @param include_comments Whether to include explanatory comments
         * @return Success status
         */
        public async bool export_batch_commands (Gee.ArrayList<QueryResult> results,
                                                 File file, bool include_comments = true) {
            try {
                string content = command_generator.generate_batch_script (results, include_comments);
                yield file.replace_contents_async (
                    content.data,
                    null,
                    false,
                    FileCreateFlags.REPLACE_DESTINATION,
                    null,
                    null
                );

                // Set executable permissions on Unix-like systems
                try {
                    FileInfo info = file.query_info (FileAttribute.UNIX_MODE, FileQueryInfoFlags.NONE);
                    uint32 mode = info.get_attribute_uint32 (FileAttribute.UNIX_MODE);
                    mode |= 0x0040 | 0x0008 | 0x0001; // Add execute permissions (user, group, others)
                    info.set_attribute_uint32 (FileAttribute.UNIX_MODE, mode);
                    file.set_attributes_from_info (info, FileQueryInfoFlags.NONE);
                } catch (Error e) {
                    // Non-critical error, continue anyway
                    debug ("Could not set executable permissions: %s", e.message);
                }

                return true;
            } catch (Error e) {
                warning ("Batch export failed: %s", e.message);
                return false;
            }
        }
    }
}
