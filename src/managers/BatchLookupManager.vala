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
    public class BatchLookupTask : Object {
        public string domain { get; set; }
        public RecordType record_type { get; set; }
        public string? dns_server { get; set; }
        public QueryResult? result { get; set; default = null; }
        public bool completed { get; set; default = false; }
        public bool failed { get; set; default = false; }
        public string? error_message { get; set; default = null; }

        public BatchLookupTask (string domain, RecordType record_type, string? dns_server = null) {
            this.domain = domain;
            this.record_type = record_type;
            this.dns_server = dns_server;
        }
    }

    public class BatchLookupManager : Object {
        private static BatchLookupManager? instance = null;
        private DnsQuery dns_query;
        private Gee.ArrayList<BatchLookupTask> tasks;
        private bool is_running = false;
        private uint completed_count = 0;
        private uint total_count = 0;
        private Cancellable? cancellable = null;

        public signal void progress_updated (uint completed, uint total);
        public signal void task_completed (BatchLookupTask task);
        public signal void batch_completed (Gee.ArrayList<BatchLookupTask> results);
        public signal void batch_error (string error_message);

        private BatchLookupManager () {
            dns_query = new DnsQuery ();
            tasks = new Gee.ArrayList<BatchLookupTask> ();
        }

        public static BatchLookupManager get_instance () {
            if (instance == null) {
                instance = new BatchLookupManager ();
            }
            return instance;
        }

        public void add_task (BatchLookupTask task) {
            tasks.add (task);
        }

        public void clear_tasks () {
            tasks.clear ();
            completed_count = 0;
            total_count = 0;
        }

        public async bool import_from_file (File file, RecordType default_record_type, string? default_dns_server = null) {
            // Using centralized constants (SEC-002)
            const int MAX_FILE_SIZE_BYTES = Constants.MAX_BATCH_FILE_SIZE_BYTES;
            const int MAX_LINE_COUNT = Constants.MAX_BATCH_LINES;

            try {
                // SEC-002: Check file size before loading
                FileInfo file_info = yield file.query_info_async (
                    FileAttribute.STANDARD_SIZE,
                    FileQueryInfoFlags.NONE,
                    Priority.DEFAULT,
                    null
                );

                int64 file_size = file_info.get_size ();
                if (file_size > MAX_FILE_SIZE_BYTES) {
                    string size_mb = "%.1f".printf ((double)file_size / (1024 * 1024));
                    batch_error ("File too large: %s MB (maximum %d MB)".printf (size_mb, Constants.MAX_BATCH_FILE_SIZE_MB));
                    return false;
                }

                uint8[] contents;
                yield file.load_contents_async (null, out contents, null);
                string text = (string) contents;

                var lines = text.split ("\n");

                // SEC-002: Check line count
                if (lines.length > MAX_LINE_COUNT) {
                    batch_error ("Too many lines: %u (maximum %d)".printf (lines.length, Constants.MAX_BATCH_LINES));
                    return false;
                }

                uint skipped_count = 0;
                uint processed_count = 0;
                uint line_number = 0;

                foreach (var line in lines) {
                    line_number++;
                    var trimmed = line.strip ();

                    // Skip empty lines and comments
                    if (trimmed.length == 0 || trimmed.has_prefix ("#")) {
                        continue;
                    }

                    var parts = trimmed.split (",");
                    if (parts.length == 0) {
                        continue;
                    }

                    // SEC-002: Sanitize and validate domain field
                    string domain = parts[0].strip ();

                    // Check for prohibited characters (SEC-002)
                    if (domain.contains (";") || domain.contains ("|") ||
                        domain.contains ("&") || domain.contains ("`") ||
                        domain.contains ("$") || domain.contains ("(") ||
                        domain.contains (")")) {
                        warning ("Line %u: Skipped domain with prohibited characters: %s", line_number, domain);
                        skipped_count++;
                        continue;
                    }

                    // Validate domain format (SEC-002)
                    if (!is_valid_batch_domain (domain)) {
                        warning ("Line %u: Skipped invalid domain: %s", line_number, domain);
                        skipped_count++;
                        continue;
                    }

                    RecordType record_type = default_record_type;
                    string? dns_server = default_dns_server;

                    // Validate record type field
                    if (parts.length > 1) {
                        string record_type_str = parts[1].strip ();
                        if (record_type_str.length > 0) {
                            record_type = RecordType.from_string (record_type_str);
                        }
                    }

                    // SEC-002: Validate DNS server field
                    if (parts.length > 2) {
                        string dns_server_str = parts[2].strip ();
                        if (dns_server_str.length > 0) {
                            // Check for prohibited characters
                            if (dns_server_str.contains (";") || dns_server_str.contains ("|") ||
                                dns_server_str.contains ("&") || dns_server_str.contains ("`")) {
                                warning ("Line %u: Skipped entry with invalid DNS server: %s", line_number, dns_server_str);
                                skipped_count++;
                                continue;
                            }

                            // Validate DNS server format
                            if (!ValidationUtils.validate_dns_server (dns_server_str)) {
                                warning ("Line %u: Skipped entry with invalid DNS server format: %s", line_number, dns_server_str);
                                skipped_count++;
                                continue;
                            }

                            dns_server = dns_server_str;
                        }
                    }

                    var task = new BatchLookupTask (domain, record_type, dns_server);
                    add_task (task);
                    processed_count++;
                }

                // Report statistics
                if (skipped_count > 0) {
                    message ("Batch import: processed %u entries, skipped %u invalid entries", processed_count, skipped_count);
                }

                if (processed_count == 0) {
                    batch_error ("No valid entries found in file");
                    return false;
                }

                return true;
            } catch (Error e) {
                // SEC-009: Sanitize error message (don't expose full path)
                critical ("Failed to import batch file %s: %s", file.get_basename (), e.message);
                batch_error ("Failed to import file. Please check the file format.");
                return false;
            }
        }

        // SEC-002: Domain validation helper for batch import
        private bool is_valid_batch_domain (string domain) {
            return ValidationUtils.is_valid_hostname (domain) ||
                   ValidationUtils.is_valid_ipv4 (domain);
        }

        public async void execute_batch (bool parallel = false, bool reverse_lookup = false,
                                        bool trace_path = false, bool short_output = false) {
            if (is_running) {
                warning ("Batch lookup already in progress");
                return;
            }

            if (tasks.size == 0) {
                batch_error ("No tasks to execute");
                return;
            }

            is_running = true;
            completed_count = 0;
            total_count = tasks.size;
            cancellable = new Cancellable ();

            progress_updated (0, total_count);

            if (parallel) {
                yield execute_parallel (reverse_lookup, trace_path, short_output);
            } else {
                yield execute_sequential (reverse_lookup, trace_path, short_output);
            }

            is_running = false;

            if (!cancellable.is_cancelled ()) {
                batch_completed (tasks);
            }
        }

        private async void execute_sequential (bool reverse_lookup, bool trace_path, bool short_output) {
            foreach (var task in tasks) {
                if (cancellable.is_cancelled ()) {
                    break;
                }

                yield execute_task (task, reverse_lookup, trace_path, short_output);
                completed_count++;
                progress_updated (completed_count, total_count);
                task_completed (task);

                Timeout.add (Constants.BATCH_SEQUENTIAL_DELAY_MS, () => {
                    execute_sequential.callback ();
                    return false;
                });
                yield;
            }
        }

        private async void execute_parallel (bool reverse_lookup, bool trace_path, bool short_output) {
            int current_index = 0;

            while (current_index < tasks.size && !cancellable.is_cancelled ()) {
                var batch_end = int.min (current_index + Constants.PARALLEL_BATCH_SIZE, tasks.size);
                var parallel_tasks = new Gee.ArrayList<BatchLookupTask> ();

                for (int i = current_index; i < batch_end; i++) {
                    parallel_tasks.add (tasks[i]);
                }

                foreach (var task in parallel_tasks) {
                    execute_task.begin (task, reverse_lookup, trace_path, short_output, (obj, res) => {
                        execute_task.end (res);
                        completed_count++;
                        progress_updated (completed_count, total_count);
                        task_completed (task);
                    });
                }

                while (completed_count < batch_end && !cancellable.is_cancelled ()) {
                    Timeout.add (Constants.BATCH_SEQUENTIAL_DELAY_MS, () => {
                        execute_parallel.callback ();
                        return false;
                    });
                    yield;
                }

                current_index = batch_end;
            }
        }

        private async void execute_task (BatchLookupTask task, bool reverse_lookup, bool trace_path, bool short_output) {
            try {
                var result = yield dns_query.perform_query (
                    task.domain,
                    task.record_type,
                    task.dns_server,
                    reverse_lookup,
                    trace_path,
                    short_output
                );

                if (result != null) {
                    task.result = result;
                    task.completed = true;

                    if (result.status != QueryStatus.SUCCESS) {
                        task.failed = true;
                        task.error_message = result.status.to_string ();
                    }
                } else {
                    task.completed = true;
                    task.failed = true;
                    task.error_message = "Query returned no result";
                }
            } catch (Error e) {
                task.completed = true;
                task.failed = true;
                task.error_message = e.message;
            }
        }

        public Gee.ArrayList<BatchLookupTask> get_tasks () {
            return tasks;
        }
    }
}
