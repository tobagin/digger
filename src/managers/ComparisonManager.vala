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
    public class ComparisonResult : Object {
        public string domain { get; set; }
        public RecordType record_type { get; set; }
        public Gee.ArrayList<QueryResult> server_results { get; set; }
        public DateTime timestamp { get; set; }

        public ComparisonResult (string domain, RecordType record_type) {
            this.domain = domain;
            this.record_type = record_type;
            this.server_results = new Gee.ArrayList<QueryResult> ();
            this.timestamp = new DateTime.now_local ();
        }

        public void add_result (QueryResult result) {
            server_results.add (result);
        }

        public bool has_discrepancies () {
            if (server_results.size < 2) {
                return false;
            }

            int first_count = server_results[0].answer_section.size;
            foreach (var result in server_results) {
                if (result.answer_section.size != first_count) {
                    return true;
                }
            }

            for (int i = 0; i < first_count; i++) {
                var first_record = server_results[0].answer_section[i];
                foreach (var result in server_results) {
                    if (i >= result.answer_section.size) {
                        return true;
                    }

                    var record = result.answer_section[i];
                    if (record.value != first_record.value ||
                        record.record_type != first_record.record_type) {
                        return true;
                    }
                }
            }

            return false;
        }

        public Gee.HashSet<string> get_unique_values () {
            var values = new Gee.HashSet<string> ();
            foreach (var result in server_results) {
                foreach (var record in result.answer_section) {
                    values.add (record.value);
                }
            }
            return values;
        }

        public QueryResult? get_fastest_result () {
            if (server_results.size == 0) {
                return null;
            }

            QueryResult? fastest = null;
            double fastest_time = double.MAX;

            foreach (var result in server_results) {
                if (result.status == QueryStatus.SUCCESS && result.query_time_ms < fastest_time) {
                    fastest = result;
                    fastest_time = result.query_time_ms;
                }
            }

            return fastest;
        }

        public QueryResult? get_slowest_result () {
            if (server_results.size == 0) {
                return null;
            }

            QueryResult? slowest = null;
            double slowest_time = 0;

            foreach (var result in server_results) {
                if (result.status == QueryStatus.SUCCESS && result.query_time_ms > slowest_time) {
                    slowest = result;
                    slowest_time = result.query_time_ms;
                }
            }

            return slowest;
        }

        public double get_average_query_time () {
            if (server_results.size == 0) {
                return 0;
            }

            double total = 0;
            int count = 0;

            foreach (var result in server_results) {
                if (result.status == QueryStatus.SUCCESS) {
                    total += result.query_time_ms;
                    count++;
                }
            }

            return count > 0 ? total / count : 0;
        }
    }

    public class ComparisonManager : Object {
        private static ComparisonManager? instance = null;
        private DnsQuery dns_query;
        private Gee.ArrayList<string> dns_servers;

        public signal void comparison_progress (uint completed, uint total);
        public signal void comparison_completed (ComparisonResult result);
        public signal void comparison_error (string error_message);

        private ComparisonManager () {
            dns_query = new DnsQuery ();
            dns_servers = new Gee.ArrayList<string> ();
            add_default_servers ();
        }

        public static ComparisonManager get_instance () {
            if (instance == null) {
                instance = new ComparisonManager ();
            }
            return instance;
        }

        private void add_default_servers () {
            dns_servers.add ("8.8.8.8");
            dns_servers.add ("1.1.1.1");
            dns_servers.add ("9.9.9.9");
        }

        public void set_servers (Gee.ArrayList<string> servers) {
            dns_servers.clear ();
            dns_servers.add_all (servers);
        }

        public void add_server (string server) {
            if (!dns_servers.contains (server)) {
                dns_servers.add (server);
            }
        }

        public void remove_server (string server) {
            dns_servers.remove (server);
        }

        public Gee.ArrayList<string> get_servers () {
            return dns_servers;
        }

        public async ComparisonResult? compare_servers (string domain, RecordType record_type,
                                                        bool reverse_lookup = false,
                                                        bool trace_path = false,
                                                        bool short_output = false) {
            if (dns_servers.size == 0) {
                comparison_error ("No DNS servers configured for comparison");
                return null;
            }

            var comparison = new ComparisonResult (domain, record_type);
            uint completed = 0;
            uint total = dns_servers.size;

            comparison_progress (0, total);

            foreach (var server in dns_servers) {
                try {
                    var result = yield dns_query.perform_query (
                        domain,
                        record_type,
                        server,
                        reverse_lookup,
                        trace_path,
                        short_output
                    );

                    if (result != null) {
                        comparison.add_result (result);
                    }
                } catch (Error e) {
                    warning ("Comparison query failed for server %s: %s", server, e.message);
                }

                completed++;
                comparison_progress (completed, total);
            }

            comparison_completed (comparison);
            return comparison;
        }
    }
}
