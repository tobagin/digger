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

            // First check: different number of records
            int first_count = server_results[0].answer_section.size;
            foreach (var result in server_results) {
                if (result.answer_section.size != first_count) {
                    return true;
                }
            }

            // Second check: compare sets of values (order-independent)
            // Create a set of "record_type:value" strings for the first server
            var first_set = new Gee.HashSet<string> ();
            foreach (var record in server_results[0].answer_section) {
                first_set.add (@"$(record.record_type):$(record.value)");
            }

            // Compare each other server's set with the first
            foreach (var result in server_results) {
                var result_set = new Gee.HashSet<string> ();
                foreach (var record in result.answer_section) {
                    result_set.add (@"$(record.record_type):$(record.value)");
                }

                // Check if sets are equal (same records, regardless of order)
                if (result_set.size != first_set.size) {
                    return true;
                }

                foreach (var item in first_set) {
                    if (!result_set.contains (item)) {
                        return true;  // First set has something result set doesn't
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
            comparison_progress (0, dns_servers.size);

            // Sequential execution with explicit yields to keep UI responsive
            // This is slower than parallel, but guarantees the UI never freezes
            for (int i = 0; i < dns_servers.size; i++) {
                var server = dns_servers[i];

                // Perform async query (doesn't block main thread)
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

                // Update progress after each query
                comparison_progress (i + 1, dns_servers.size);

                // CRITICAL: Explicit yield to GTK main loop
                // This forces UI event processing between queries
                // Without this, even async queries can appear to freeze the UI
                if (i < dns_servers.size - 1) {  // Don't yield after last query
                    Timeout.add (50, () => {
                        compare_servers.callback ();
                        return false;
                    });
                    yield;
                }
            }

            comparison_completed (comparison);
            return comparison;
        }
    }
}
