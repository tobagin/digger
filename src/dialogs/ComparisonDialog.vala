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
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/comparison-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/comparison-dialog.ui")]
#endif
    public class ComparisonDialog : Adw.Dialog {
        [GtkChild] private unowned Gtk.Button close_button;
        [GtkChild] private unowned Gtk.Button compare_button;
        [GtkChild] private unowned Gtk.Entry domain_entry;
        [GtkChild] private unowned Gtk.DropDown record_type_dropdown;
        [GtkChild] private unowned Gtk.Switch google_switch;
        [GtkChild] private unowned Gtk.Switch cloudflare_switch;
        [GtkChild] private unowned Gtk.Switch quad9_switch;
        [GtkChild] private unowned Gtk.Switch opendns_switch;
        [GtkChild] private unowned Gtk.Switch system_switch;
        [GtkChild] private unowned Gtk.ProgressBar progress_bar;
        [GtkChild] private unowned Gtk.Box results_box;
        [GtkChild] private unowned Adw.PreferencesGroup stats_group;
        [GtkChild] private unowned Adw.PreferencesGroup discrepancy_group;
        [GtkChild] private unowned Gtk.Box results_container;
        [GtkChild] private unowned Gtk.Button export_button;

        private ComparisonManager comparison_manager;

        public ComparisonDialog () {
            comparison_manager = ComparisonManager.get_instance ();
        }

        construct {
            setup_ui ();
            connect_signals ();
        }

        private void setup_ui () {
            var model = new Gtk.StringList (null);
            model.append ("A - IPv4 Address");
            model.append ("AAAA - IPv6 Address");
            model.append ("MX - Mail Exchange");
            model.append ("TXT - Text Record");
            model.append ("NS - Name Server");
            model.append ("CNAME - Canonical Name");
            record_type_dropdown.model = model;
            record_type_dropdown.selected = 0;
        }

        private void connect_signals () {
            close_button.clicked.connect (() => close ());
            compare_button.clicked.connect (perform_comparison);
            export_button.clicked.connect (export_results);

            domain_entry.changed.connect (validate_input);
            google_switch.notify["active"].connect (validate_input);
            cloudflare_switch.notify["active"].connect (validate_input);
            quad9_switch.notify["active"].connect (validate_input);
            opendns_switch.notify["active"].connect (validate_input);
            system_switch.notify["active"].connect (validate_input);

            validate_input ();
        }

        private void validate_input () {
            var domain = domain_entry.text.strip ();
            var servers_selected = google_switch.active || cloudflare_switch.active ||
                                 quad9_switch.active || opendns_switch.active ||
                                 system_switch.active;

            var server_count = 0;
            if (google_switch.active) server_count++;
            if (cloudflare_switch.active) server_count++;
            if (quad9_switch.active) server_count++;
            if (opendns_switch.active) server_count++;
            if (system_switch.active) server_count++;

            compare_button.sensitive = domain.length > 0 && server_count >= 2;
        }

        private void perform_comparison () {
            var domain = domain_entry.text.strip ();
            if (domain.length == 0) return;

            var record_type = get_selected_record_type ();
            var servers = new Gee.ArrayList<string> ();

            if (google_switch.active) servers.add ("8.8.8.8");
            if (cloudflare_switch.active) servers.add ("1.1.1.1");
            if (quad9_switch.active) servers.add ("9.9.9.9");
            if (opendns_switch.active) servers.add ("208.67.222.222");
            if (system_switch.active) servers.add ("");

            if (servers.size < 2) return;

            progress_bar.visible = true;
            progress_bar.pulse ();
            compare_button.sensitive = false;

            Timeout.add (100, () => {
                if (progress_bar.visible) {
                    progress_bar.pulse ();
                    return true;
                }
                return false;
            });

            comparison_manager.set_servers (servers);
            comparison_manager.compare_servers.begin (domain, record_type, false, false, false, (obj, res) => {
                try {
                    var result = comparison_manager.compare_servers.end (res);
                    if (result != null) {
                        display_results (result);
                    }
                } catch (Error e) {
                    warning ("Comparison error: %s", e.message);
                }

                progress_bar.visible = false;
                compare_button.sensitive = true;
            });
        }

        private void display_results (ComparisonResult result) {
            clear_results_display ();

            results_box.visible = true;

            var fastest = result.get_fastest_result ();
            var slowest = result.get_slowest_result ();
            var avg_time = result.get_average_query_time ();

            var fastest_row = new Adw.ActionRow () {
                title = "Fastest Server"
            };
            if (fastest != null) {
                fastest_row.subtitle = @"$(fastest.dns_server) - $((int)fastest.query_time_ms)ms";
                var icon = new Gtk.Image.from_icon_name ("emblem-default-symbolic");
                fastest_row.add_prefix (icon);
            }
            stats_group.add (fastest_row);

            var slowest_row = new Adw.ActionRow () {
                title = "Slowest Server"
            };
            if (slowest != null) {
                slowest_row.subtitle = @"$(slowest.dns_server) - $((int)slowest.query_time_ms)ms";
            }
            stats_group.add (slowest_row);

            var avg_row = new Adw.ActionRow () {
                title = "Average Query Time",
                subtitle = @"$((int)avg_time)ms"
            };
            stats_group.add (avg_row);

            if (result.has_discrepancies ()) {
                discrepancy_group.visible = true;
                var warning_row = new Adw.ActionRow () {
                    title = "Discrepancies Found",
                    subtitle = "Different DNS servers returned different results"
                };
                var icon = new Gtk.Image.from_icon_name ("dialog-warning-symbolic");
                icon.add_css_class ("warning");
                warning_row.add_prefix (icon);
                discrepancy_group.add (warning_row);
            }

            foreach (var server_result in result.server_results) {
                var server_group = new Adw.PreferencesGroup () {
                    title = server_result.dns_server,
                    margin_start = 6,
                    margin_end = 6
                };

                if (server_result.status == QueryStatus.SUCCESS) {
                    var time_row = new Adw.ActionRow () {
                        title = "Query Time",
                        subtitle = @"$((int)server_result.query_time_ms)ms"
                    };
                    server_group.add (time_row);

                    var count_row = new Adw.ActionRow () {
                        title = "Records Found",
                        subtitle = @"$(server_result.answer_section.size) answers"
                    };
                    server_group.add (count_row);

                    foreach (var record in server_result.answer_section) {
                        var record_row = new Adw.ActionRow () {
                            title = record.name,
                            subtitle = record.value
                        };

                        var type_label = new Gtk.Label (record.record_type.to_string ()) {
                            width_request = 60,
                            halign = Gtk.Align.CENTER
                        };
                        type_label.add_css_class ("pill");
                        type_label.add_css_class ("success");
                        record_row.add_prefix (type_label);

                        server_group.add (record_row);
                    }
                } else {
                    var error_row = new Adw.ActionRow () {
                        title = "Query Failed",
                        subtitle = server_result.status.to_string ()
                    };
                    var icon = new Gtk.Image.from_icon_name ("dialog-error-symbolic");
                    error_row.add_prefix (icon);
                    server_group.add (error_row);
                }

                results_container.append (server_group);
            }
        }

        private void clear_results_display () {
            while (stats_group.get_first_child () != null) {
                var child = stats_group.get_first_child ();
                stats_group.remove (child);
            }

            while (discrepancy_group.get_first_child () != null) {
                var child = discrepancy_group.get_first_child ();
                discrepancy_group.remove (child);
            }

            while (results_container.get_first_child () != null) {
                var child = results_container.get_first_child ();
                results_container.remove (child);
            }

            discrepancy_group.visible = false;
        }

        private RecordType get_selected_record_type () {
            var selected_text = ((Gtk.StringList) record_type_dropdown.model).get_string (record_type_dropdown.selected);
            var type_code = selected_text.split (" - ")[0];
            return RecordType.from_string (type_code);
        }

        private void export_results () {
        }
    }
}
