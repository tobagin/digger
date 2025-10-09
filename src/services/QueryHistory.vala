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
     * Search criteria for enhanced history search
     */
    public enum SearchCriteria {
        ALL,
        DOMAIN_ONLY,
        RECORD_TYPE_ONLY,
        DNS_SERVER_ONLY
    }
    
    /**
     * Helper class for domain frequency tracking
     */
    public class DomainFrequencyPair {
        public string domain;
        public int frequency;
        
        public DomainFrequencyPair (string domain, int frequency) {
            this.domain = domain;
            this.frequency = frequency;
        }
    }
    public class QueryHistory : Object {
        private const string HISTORY_FILE = "query-history.json";
        private const int MAX_HISTORY_SIZE = 100;
        
        private Gee.ArrayList<QueryResult> history;
        private string history_file_path;
        private Gee.HashMap<string, int> domain_frequency;
        private Gee.HashMap<string, DateTime> domain_last_used;

        public signal void history_updated ();

        public QueryHistory () {
            history = new Gee.ArrayList<QueryResult> ();
            domain_frequency = new Gee.HashMap<string, int> ();
            domain_last_used = new Gee.HashMap<string, DateTime> ();
            
            // Get user data directory
            string user_data_dir = Environment.get_user_data_dir ();
            string app_data_dir = Path.build_filename (user_data_dir, "digger");
            
            // Create directory if it doesn't exist
            try {
                File dir = File.new_for_path (app_data_dir);
                if (!dir.query_exists ()) {
                    dir.make_directory_with_parents ();
                }
            } catch (Error e) {
                warning (@"Failed to create data directory: $(e.message)");
            }
            
            history_file_path = Path.build_filename (app_data_dir, HISTORY_FILE);
            load_history ();
        }

        public void add_query (QueryResult result) {
            // Add to beginning of history
            history.insert (0, result);
            
            // Update domain frequency tracking
            update_domain_frequency (result.domain);
            
            // Limit history size
            while (history.size > MAX_HISTORY_SIZE) {
                history.remove_at (history.size - 1);
            }
            
            save_history ();
            history_updated ();
        }

        public QueryResult? get_last_query () {
            if (history.size > 0) {
                return history[0];
            }
            return null;
        }

        public Gee.List<QueryResult> get_history () {
            return history.read_only_view;
        }

        public Gee.List<QueryResult> search_history (string query) {
            var results = new Gee.ArrayList<QueryResult> ();
            string lower_query = query.down ();
            
            foreach (var result in history) {
                if (result.domain.down ().contains (lower_query) ||
                    result.query_type.to_string ().down ().contains (lower_query) ||
                    result.dns_server.down ().contains (lower_query)) {
                    results.add (result);
                }
            }
            
            return results;
        }

        public void clear_history () {
            history.clear ();
            domain_frequency.clear ();
            domain_last_used.clear ();
            save_history ();
            history_updated ();
        }
        
        /**
         * Get domains sorted by frequency of use
         */
        public Gee.List<string> get_frequent_domains (int limit = 10) {
            var domains = new Gee.ArrayList<string> ();
            
            // Convert to list of pairs for sorting
            var domain_pairs = new Gee.ArrayList<DomainFrequencyPair> ();
            foreach (var entry in domain_frequency.entries) {
                domain_pairs.add (new DomainFrequencyPair (entry.key, entry.value));
            }
            
            // Sort by frequency (descending)
            domain_pairs.sort ((a, b) => {
                if (a.frequency != b.frequency) {
                    return b.frequency - a.frequency;
                }
                
                // If frequencies are equal, sort by recency
                var a_time = domain_last_used.get (a.domain);
                var b_time = domain_last_used.get (b.domain);
                if (a_time != null && b_time != null) {
                    return b_time.compare (a_time);
                }
                
                return 0;
            });
            
            // Extract domains up to limit
            for (int i = 0; i < int.min (domain_pairs.size, limit); i++) {
                domains.add (domain_pairs[i].domain);
            }
            
            return domains;
        }
        
        /**
         * Get domain suggestions based on partial input
         */
        public Gee.List<string> get_domain_suggestions (string partial, int limit = 5) {
            var suggestions = new Gee.ArrayList<string> ();
            string lower_partial = partial.down ();
            
            // Get all domains that match the partial input
            var matching_domains = new Gee.ArrayList<DomainFrequencyPair> ();
            foreach (var entry in domain_frequency.entries) {
                if (entry.key.down ().has_prefix (lower_partial) || 
                    entry.key.down ().contains (lower_partial)) {
                    matching_domains.add (new DomainFrequencyPair (entry.key, entry.value));
                }
            }
            
            // Sort by frequency and recency
            matching_domains.sort ((a, b) => {
                // Prefer exact prefix matches
                bool a_prefix = a.domain.down ().has_prefix (lower_partial);
                bool b_prefix = b.domain.down ().has_prefix (lower_partial);
                
                if (a_prefix && !b_prefix) return -1;
                if (!a_prefix && b_prefix) return 1;
                
                // Then by frequency
                if (a.frequency != b.frequency) {
                    return b.frequency - a.frequency;
                }
                
                // Finally by recency
                var a_time = domain_last_used.get (a.domain);
                var b_time = domain_last_used.get (b.domain);
                if (a_time != null && b_time != null) {
                    return b_time.compare (a_time);
                }
                
                return 0;
            });
            
            // Extract domains up to limit
            for (int i = 0; i < int.min (matching_domains.size, limit); i++) {
                suggestions.add (matching_domains[i].domain);
            }
            
            return suggestions;
        }
        
        /**
         * Get enhanced search results with multiple criteria
         */
        public Gee.List<QueryResult> search_history_enhanced (string query, SearchCriteria criteria = SearchCriteria.ALL) {
            var results = new Gee.ArrayList<QueryResult> ();
            string lower_query = query.down ();
            
            foreach (var result in history) {
                bool matches = false;
                
                switch (criteria) {
                    case SearchCriteria.DOMAIN_ONLY:
                        matches = result.domain.down ().contains (lower_query);
                        break;
                    
                    case SearchCriteria.RECORD_TYPE_ONLY:
                        matches = result.query_type.to_string ().down ().contains (lower_query);
                        break;
                    
                    case SearchCriteria.DNS_SERVER_ONLY:
                        matches = result.dns_server.down ().contains (lower_query);
                        break;
                    
                    case SearchCriteria.ALL:
                    default:
                        matches = result.domain.down ().contains (lower_query) ||
                                 result.query_type.to_string ().down ().contains (lower_query) ||
                                 result.dns_server.down ().contains (lower_query);
                        break;
                }
                
                if (matches) {
                    results.add (result);
                }
            }
            
            return results;
        }
        
        /**
         * Get domain frequency for a specific domain
         */
        public int get_domain_frequency (string domain) {
            return domain_frequency.has_key (domain) ? domain_frequency.get (domain) : 0;
        }
        
        /**
         * Update domain frequency tracking
         */
        private void update_domain_frequency (string domain) {
            string normalized_domain = domain.down ().strip ();
            
            // Update frequency count
            int current_count = domain_frequency.has_key (normalized_domain) ? domain_frequency.get (normalized_domain) : 0;
            domain_frequency.set (normalized_domain, current_count + 1);
            
            // Update last used time
            domain_last_used.set (normalized_domain, new DateTime.now_local ());
        }

        private void load_history () {
            try {
                File file = File.new_for_path (history_file_path);
                if (!file.query_exists ()) {
                    return;
                }

                uint8[] contents;
                file.load_contents (null, out contents, null);
                string json_content = (string) contents;

                Json.Parser parser = new Json.Parser ();
                parser.load_from_data (json_content);
                
                Json.Node root = parser.get_root ();
                if (root.get_node_type () != Json.NodeType.ARRAY) {
                    return;
                }

                Json.Array array = root.get_array ();
                foreach (var element in array.get_elements ()) {
                    var result = parse_query_result_from_json (element);
                    if (result != null) {
                        history.add (result);
                    }
                }

            } catch (Error e) {
                warning (@"Failed to load history: $(e.message)");
            }
        }

        private void save_history () {
            try {
                Json.Builder builder = new Json.Builder ();
                builder.begin_array ();

                foreach (var result in history) {
                    serialize_query_result_to_json (builder, result);
                }

                builder.end_array ();

                Json.Generator generator = new Json.Generator ();
                Json.Node root = builder.get_root ();
                generator.set_root (root);
                generator.pretty = true;

                string json_content = generator.to_data (null);
                File file = File.new_for_path (history_file_path);
                file.replace_contents (json_content.data, null, false, FileCreateFlags.NONE, null, null);

            } catch (Error e) {
                warning (@"Failed to save history: $(e.message)");
            }
        }

        private QueryResult? parse_query_result_from_json (Json.Node node) {
            if (node.get_node_type () != Json.NodeType.OBJECT) {
                return null;
            }

            try {
                Json.Object obj = node.get_object ();
                var result = new QueryResult ();

                result.domain = obj.get_string_member ("domain");
                result.query_type = RecordType.from_string (obj.get_string_member ("query_type"));
                result.dns_server = obj.get_string_member ("dns_server");
                result.query_time_ms = obj.get_double_member ("query_time_ms");
                result.status = (QueryStatus) obj.get_int_member ("status");
                
                // Parse timestamp
                string timestamp_str = obj.get_string_member ("timestamp");
                result.timestamp = new DateTime.from_iso8601 (timestamp_str, null);

                // Parse advanced options
                if (obj.has_member ("reverse_lookup")) {
                    result.reverse_lookup = obj.get_boolean_member ("reverse_lookup");
                }
                if (obj.has_member ("trace_path")) {
                    result.trace_path = obj.get_boolean_member ("trace_path");
                }
                if (obj.has_member ("short_output")) {
                    result.short_output = obj.get_boolean_member ("short_output");
                }

                // Parse DNS records sections
                if (obj.has_member ("answer_section")) {
                    parse_dns_records_array (obj.get_array_member ("answer_section"), result.answer_section);
                }
                if (obj.has_member ("authority_section")) {
                    parse_dns_records_array (obj.get_array_member ("authority_section"), result.authority_section);
                }
                if (obj.has_member ("additional_section")) {
                    parse_dns_records_array (obj.get_array_member ("additional_section"), result.additional_section);
                }

                return result;

            } catch (Error e) {
                warning (@"Failed to parse query result from JSON: $(e.message)");
                return null;
            }
        }

        private void parse_dns_records_array (Json.Array array, Gee.ArrayList<DnsRecord> records) {
            foreach (var element in array.get_elements ()) {
                if (element.get_node_type () == Json.NodeType.OBJECT) {
                    Json.Object record_obj = element.get_object ();
                    
                    string name = record_obj.get_string_member ("name");
                    RecordType record_type = RecordType.from_string (record_obj.get_string_member ("type"));
                    int ttl = (int) record_obj.get_int_member ("ttl");
                    string value = record_obj.get_string_member ("value");
                    int priority = record_obj.has_member ("priority") ? (int) record_obj.get_int_member ("priority") : -1;
                    
                    var record = new DnsRecord (name, record_type, ttl, value, priority);
                    records.add (record);
                }
            }
        }

        private void serialize_query_result_to_json (Json.Builder builder, QueryResult result) {
            builder.begin_object ();
            
            builder.set_member_name ("domain");
            builder.add_string_value (result.domain);
            
            builder.set_member_name ("query_type");
            builder.add_string_value (result.query_type.to_string ());
            
            builder.set_member_name ("dns_server");
            builder.add_string_value (result.dns_server);
            
            builder.set_member_name ("query_time_ms");
            builder.add_double_value (result.query_time_ms);
            
            builder.set_member_name ("status");
            builder.add_int_value ((int) result.status);
            
            builder.set_member_name ("timestamp");
            builder.add_string_value (result.timestamp.to_string ());
            
            // Advanced options
            builder.set_member_name ("reverse_lookup");
            builder.add_boolean_value (result.reverse_lookup);
            
            builder.set_member_name ("trace_path");
            builder.add_boolean_value (result.trace_path);
            
            builder.set_member_name ("short_output");
            builder.add_boolean_value (result.short_output);
            
            // DNS record sections
            serialize_dns_records_array (builder, "answer_section", result.answer_section);
            serialize_dns_records_array (builder, "authority_section", result.authority_section);
            serialize_dns_records_array (builder, "additional_section", result.additional_section);
            
            builder.end_object ();
        }

        private void serialize_dns_records_array (Json.Builder builder, string member_name, Gee.ArrayList<DnsRecord> records) {
            builder.set_member_name (member_name);
            builder.begin_array ();
            
            foreach (var record in records) {
                builder.begin_object ();
                
                builder.set_member_name ("name");
                builder.add_string_value (record.name);
                
                builder.set_member_name ("type");
                builder.add_string_value (record.record_type.to_string ());
                
                builder.set_member_name ("ttl");
                builder.add_int_value (record.ttl);
                
                builder.set_member_name ("value");
                builder.add_string_value (record.value);
                
                if (record.priority >= 0) {
                    builder.set_member_name ("priority");
                    builder.add_int_value (record.priority);
                }
                
                builder.end_object ();
            }
            
            builder.end_array ();
        }
    }
}
