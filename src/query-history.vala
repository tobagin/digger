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
    public class QueryHistory : Object {
        private const string HISTORY_FILE = "query-history.json";
        private const int MAX_HISTORY_SIZE = 100;
        
        private Gee.ArrayList<QueryResult> history;
        private string history_file_path;

        public signal void history_updated ();

        public QueryHistory () {
            history = new Gee.ArrayList<QueryResult> ();
            
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
            save_history ();
            history_updated ();
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
