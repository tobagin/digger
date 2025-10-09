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
        public signal void batch_cancelled ();
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

        public void add_tasks (Gee.ArrayList<BatchLookupTask> new_tasks) {
            tasks.add_all (new_tasks);
        }

        public void clear_tasks () {
            tasks.clear ();
            completed_count = 0;
            total_count = 0;
        }

        public async bool import_from_file (File file, RecordType default_record_type, string? default_dns_server = null) {
            try {
                uint8[] contents;
                yield file.load_contents_async (null, out contents, null);
                string text = (string) contents;

                var lines = text.split ("\n");
                foreach (var line in lines) {
                    var trimmed = line.strip ();
                    if (trimmed.length > 0 && !trimmed.has_prefix ("#")) {
                        var parts = trimmed.split (",");
                        string domain = parts[0].strip ();

                        RecordType record_type = default_record_type;
                        string? dns_server = default_dns_server;

                        if (parts.length > 1) {
                            record_type = RecordType.from_string (parts[1].strip ());
                        }
                        if (parts.length > 2 && parts[2].strip ().length > 0) {
                            dns_server = parts[2].strip ();
                        }

                        var task = new BatchLookupTask (domain, record_type, dns_server);
                        add_task (task);
                    }
                }

                return true;
            } catch (Error e) {
                warning ("Failed to import batch file: %s", e.message);
                batch_error ("Failed to import file: %s".printf (e.message));
                return false;
            }
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
            } else {
                batch_cancelled ();
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

                Timeout.add (100, () => {
                    execute_sequential.callback ();
                    return false;
                });
                yield;
            }
        }

        private async void execute_parallel (bool reverse_lookup, bool trace_path, bool short_output) {
            int batch_size = 5;
            int current_index = 0;

            while (current_index < tasks.size && !cancellable.is_cancelled ()) {
                var batch_end = int.min (current_index + batch_size, tasks.size);
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
                    Timeout.add (100, () => {
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

        public void cancel_batch () {
            if (cancellable != null) {
                cancellable.cancel ();
            }
        }

        public bool get_is_running () {
            return is_running;
        }

        public uint get_completed_count () {
            return completed_count;
        }

        public uint get_total_count () {
            return total_count;
        }

        public Gee.ArrayList<BatchLookupTask> get_tasks () {
            return tasks;
        }

        public Gee.ArrayList<BatchLookupTask> get_successful_tasks () {
            var successful = new Gee.ArrayList<BatchLookupTask> ();
            foreach (var task in tasks) {
                if (task.completed && !task.failed) {
                    successful.add (task);
                }
            }
            return successful;
        }

        public Gee.ArrayList<BatchLookupTask> get_failed_tasks () {
            var failed = new Gee.ArrayList<BatchLookupTask> ();
            foreach (var task in tasks) {
                if (task.failed) {
                    failed.add (task);
                }
            }
            return failed;
        }
    }
}
