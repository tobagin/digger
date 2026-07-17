/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2025 tobagin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger {
    public class MonitorWatch : Object {
        public string domain { get; set; }
        public RecordType record_type { get; set; }
        public string last_signature { get; set; default = ""; }
        public string last_checked { get; set; default = ""; }
        public bool changed { get; set; default = false; }

        public MonitorWatch (string domain, RecordType record_type) {
            this.domain = domain;
            this.record_type = record_type;
        }

        public string key () {
            return @"$domain|$(record_type.to_string ())";
        }
    }

    /**
     * Watches domains for record changes while the app is running.
     * ponytail: in-process only — no background daemon. Checks pause when the
     * app is closed; a systemd/cron helper is the upgrade path if always-on
     * monitoring is needed.
     */
    public class MonitorService : Object {
        private const string MONITORS_FILE = "monitors.json";

        private static MonitorService? instance = null;

        private Gee.ArrayList<MonitorWatch> watches;
        private DnsQuery dns_query;
        private GLib.Settings settings;
        private string file_path;
        private uint timer_id = 0;

        public signal void list_updated ();
        public signal void watch_changed (MonitorWatch watch);

        public static MonitorService get_instance () {
            if (instance == null) {
                instance = new MonitorService ();
            }
            return instance;
        }

        construct {
            watches = new Gee.ArrayList<MonitorWatch> ();
            dns_query = new DnsQuery ();
            settings = new GLib.Settings (Config.APP_ID);

            string dir = Path.build_filename (Environment.get_user_data_dir (), "digger");
            file_path = Path.build_filename (dir, MONITORS_FILE);
            load ();
            reschedule ();
        }

        public Gee.List<MonitorWatch> get_watches () {
            return watches.read_only_view;
        }

        public bool add_watch (string domain, RecordType record_type) {
            var watch = new MonitorWatch (domain, record_type);
            foreach (var existing in watches) {
                if (existing.key () == watch.key ()) {
                    return false;  // already watching
                }
            }
            watches.add (watch);
            save ();
            list_updated ();
            check_one.begin (watch);
            return true;
        }

        public void remove_watch (MonitorWatch watch) {
            watches.remove (watch);
            save ();
            list_updated ();
        }

        public async void check_all () {
            foreach (var watch in watches) {
                yield check_one (watch);
            }
        }

        private async void check_one (MonitorWatch watch) {
            var result = yield dns_query.perform_query (watch.domain, watch.record_type);
            watch.last_checked = new DateTime.now_local ().format ("%Y-%m-%d %H:%M");
            if (result == null || result.status != QueryStatus.SUCCESS) {
                list_updated ();
                return;
            }

            var values = new Gee.ArrayList<string> ();
            foreach (var record in result.answer_section) {
                values.add (record.value);
            }
            values.sort ();
            string signature = string.joinv (",", values.to_array ());

            bool first_seen = (watch.last_signature == "");
            if (!first_seen && signature != watch.last_signature) {
                watch.changed = true;
                notify_change (watch, watch.last_signature, signature);
                watch_changed (watch);
            }
            watch.last_signature = signature;
            save ();
            list_updated ();
        }

        private void notify_change (MonitorWatch watch, string old_sig, string new_sig) {
            var app = GLib.Application.get_default ();
            if (app == null) {
                return;
            }
            var notification = new GLib.Notification (("DNS record changed"));
            notification.set_body (
                ("%s (%s)\nwas: %s\nnow: %s").printf (
                    watch.domain, watch.record_type.to_string (),
                    old_sig == "" ? ("(none)") : old_sig,
                    new_sig == "" ? ("(none)") : new_sig));
            app.send_notification (null, notification);
        }

        private void reschedule () {
            if (timer_id > 0) {
                Source.remove (timer_id);
                timer_id = 0;
            }
            int minutes = settings.get_int ("monitor-interval-minutes");
            if (minutes < 1) {
                minutes = 30;
            }
            timer_id = Timeout.add_seconds (minutes * 60, () => {
                check_all.begin ();
                return Source.CONTINUE;
            });
        }

        private void load () {
            try {
                var file = File.new_for_path (file_path);
                if (!file.query_exists ()) {
                    return;
                }
                uint8[] contents;
                file.load_contents (null, out contents, null);

                var parser = new Json.Parser ();
                parser.load_from_data ((string) contents);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.ARRAY) {
                    return;
                }
                foreach (var element in root.get_array ().get_elements ()) {
                    var obj = element.get_object ();
                    var watch = new MonitorWatch (
                        obj.get_string_member ("domain"),
                        RecordType.from_string (obj.get_string_member ("record_type")));
                    if (obj.has_member ("last_signature")) {
                        watch.last_signature = obj.get_string_member ("last_signature");
                    }
                    if (obj.has_member ("last_checked")) {
                        watch.last_checked = obj.get_string_member ("last_checked");
                    }
                    watches.add (watch);
                }
            } catch (Error e) {
                warning ("Failed to load monitors: %s", e.message);
            }
        }

        private void save () {
            try {
                var builder = new Json.Builder ();
                builder.begin_array ();
                foreach (var watch in watches) {
                    builder.begin_object ();
                    builder.set_member_name ("domain");
                    builder.add_string_value (watch.domain);
                    builder.set_member_name ("record_type");
                    builder.add_string_value (watch.record_type.to_string ());
                    builder.set_member_name ("last_signature");
                    builder.add_string_value (watch.last_signature);
                    builder.set_member_name ("last_checked");
                    builder.add_string_value (watch.last_checked);
                    builder.end_object ();
                }
                builder.end_array ();

                var generator = new Json.Generator ();
                generator.set_root (builder.get_root ());
                generator.pretty = true;
                var file = File.new_for_path (file_path);
                file.replace_contents (generator.to_data (null).data, null, false,
                                       FileCreateFlags.NONE, null, null);
            } catch (Error e) {
                warning ("Failed to save monitors: %s", e.message);
            }
        }
    }
}
