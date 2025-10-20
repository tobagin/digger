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
        // View stack and navigation
        [GtkChild] private unowned Adw.ViewStack view_stack;
        [GtkChild] private unowned Gtk.Button back_button;
        [GtkChild] private unowned Gtk.Button new_comparison_button;

        // Configuration page widgets
        [GtkChild] private unowned Gtk.Button compare_button;
        [GtkChild] private unowned Gtk.Entry domain_entry;
        [GtkChild] private unowned Gtk.DropDown record_type_dropdown;
        [GtkChild] private unowned Gtk.Switch google_switch;
        [GtkChild] private unowned Gtk.Switch cloudflare_switch;
        [GtkChild] private unowned Gtk.Switch quad9_switch;
        [GtkChild] private unowned Gtk.Switch opendns_switch;
        [GtkChild] private unowned Gtk.Switch system_switch;

        // Results page widgets
        [GtkChild] private unowned Gtk.ProgressBar progress_bar;
        [GtkChild] private unowned Gtk.Box results_box;
        [GtkChild] private unowned Gtk.Label domain_label;
        [GtkChild] private unowned Adw.PreferencesGroup stats_group;
        [GtkChild] private unowned Adw.PreferencesGroup discrepancy_group;
        [GtkChild] private unowned Gtk.Box results_container;
        [GtkChild] private unowned Gtk.Button export_button;

        private ComparisonManager comparison_manager;
        private AutocompleteDropdown autocomplete_dropdown;
        private QueryHistory? query_history;
        private ComparisonResult? current_comparison_result;

        // Reusable rows - create once, update content
        private Adw.ActionRow fastest_row;
        private Adw.ActionRow slowest_row;
        private Adw.ActionRow avg_row;
        private Adw.ActionRow discrepancy_row;
        private bool stats_rows_added = false;
        private bool discrepancy_row_added = false;

        public ComparisonDialog () {
            comparison_manager = ComparisonManager.get_instance ();

            // Get query history from singleton if available
            query_history = null;

            // Create reusable rows once
            fastest_row = new Adw.ActionRow () {
                title = "Fastest Server"
            };
            var fastest_icon = new Gtk.Image.from_icon_name (Config.APP_ID + "-fastest-server-symbolic");
            fastest_row.add_prefix (fastest_icon);

            slowest_row = new Adw.ActionRow () {
                title = "Slowest Server"
            };
            var slowest_icon = new Gtk.Image.from_icon_name (Config.APP_ID + "-slowest-server-symbolic");
            slowest_row.add_prefix (slowest_icon);

            avg_row = new Adw.ActionRow () {
                title = "Average Query Time"
            };
            var avg_icon = new Gtk.Image.from_icon_name (Config.APP_ID + "-average-query-time-symbolic");
            avg_row.add_prefix (avg_icon);

            discrepancy_row = new Adw.ActionRow () {
                title = "Discrepancies Found",
                subtitle = "Different DNS servers returned different results"
            };
            var warning_icon = new Gtk.Image.from_icon_name ("dialog-warning-symbolic");
            warning_icon.add_css_class ("warning");
            discrepancy_row.add_prefix (warning_icon);
        }

        construct {
            // Initialize autocomplete dropdown with domain entry
            autocomplete_dropdown = new AutocompleteDropdown (domain_entry);

            setup_ui ();
            connect_signals ();
        }

        public void set_query_history (QueryHistory history) {
            query_history = history;
            if (autocomplete_dropdown != null) {
                autocomplete_dropdown.set_query_history (history);
            }
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
            compare_button.clicked.connect (perform_comparison);
            export_button.clicked.connect (export_results);
            back_button.clicked.connect (go_to_config_page);
            new_comparison_button.clicked.connect (go_to_config_page);

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

        private void go_to_config_page () {
            view_stack.visible_child_name = "config";
            clear_results_display ();
            results_box.visible = false;
            progress_bar.visible = false;
        }

        private void go_to_results_page () {
            view_stack.visible_child_name = "results";
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

            // IMPORTANT: Clear old results BEFORE switching pages!
            clear_results_display ();

            // Switch to results page and show progress
            go_to_results_page ();
            results_box.visible = false;
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
                results_box.visible = true;
                compare_button.sensitive = true;
            });
        }

        private void display_results (ComparisonResult result) {
            debug ("=== DISPLAYING RESULTS for %s (%d servers) ===",
                   result.domain, result.server_results.size);

            // Store result for exporting
            current_comparison_result = result;

            // Update domain label
            var record_type_str = result.record_type.to_string ();
            domain_label.label = @"$(result.domain) ($(record_type_str))";

            results_box.visible = true;

            var fastest = result.get_fastest_result ();
            var slowest = result.get_slowest_result ();
            var avg_time = result.get_average_query_time ();

            // Update fastest row content
            if (fastest != null) {
                var server_name = get_server_display_name (fastest.dns_server);
                fastest_row.subtitle = @"$(server_name) - $((int)fastest.query_time_ms)ms";
            } else {
                fastest_row.subtitle = "N/A";
            }

            // Update slowest row content
            if (slowest != null) {
                var server_name = get_server_display_name (slowest.dns_server);
                slowest_row.subtitle = @"$(server_name) - $((int)slowest.query_time_ms)ms";
            } else {
                slowest_row.subtitle = "N/A";
            }

            // Update average row content
            avg_row.subtitle = @"$((int)avg_time)ms";

            // Add rows to stats_group only once
            if (!stats_rows_added) {
                stats_group.add (fastest_row);
                stats_group.add (slowest_row);
                stats_group.add (avg_row);
                stats_rows_added = true;
            }

            // Show/hide discrepancy row based on results
            if (result.has_discrepancies ()) {
                if (!discrepancy_row_added) {
                    discrepancy_group.add (discrepancy_row);
                    discrepancy_row_added = true;
                }
                discrepancy_group.visible = true;
            } else {
                discrepancy_group.visible = false;
            }

            foreach (var server_result in result.server_results) {
                var server_name = get_server_display_name (server_result.dns_server);
                var server_group = new Adw.PreferencesGroup () {
                    title = server_name,
                    margin_start = 6,
                    margin_end = 6
                };

                if (server_result.status == QueryStatus.SUCCESS) {
                    var time_row = new Adw.ActionRow () {
                        title = "Query Time",
                        subtitle = @"$((int)server_result.query_time_ms)ms"
                    };
                    var time_icon = new Gtk.Image.from_icon_name (Config.APP_ID + "-query-time-symbolic");
                    time_row.add_prefix (time_icon);
                    server_group.add (time_row);

                    var count_row = new Adw.ActionRow () {
                        title = "Records Found",
                        subtitle = @"$(server_result.answer_section.size) answers"
                    };
                    // TODO: Create custom icon io.github.tobagin.digger-records-found-symbolic.svg
                    var count_icon = new Gtk.Image.from_icon_name ("folder-documents-symbolic");
                    count_row.add_prefix (count_icon);
                    server_group.add (count_row);

                    foreach (var record in server_result.answer_section) {
                        var record_row = new Adw.ActionRow () {
                            title = record.name,
                            subtitle = record.value
                        };

                        // Use icon instead of text label for record type
                        string icon_name = get_record_type_icon (record.record_type);
                        var type_icon = new Gtk.Image.from_icon_name (icon_name);
                        type_icon.tooltip_text = record.record_type.to_string ();
                        record_row.add_prefix (type_icon);

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
            debug ("=== CLEARING RESULTS DISPLAY ===");

            // Stats rows are reusable - no need to remove, just update content
            // Discrepancy row is reusable - just hide the group
            discrepancy_group.visible = false;

            // Only clear the server results (PreferencesGroups in results_container)
            var results_children = new Gee.ArrayList<Gtk.Widget> ();
            Gtk.Widget? child = results_container.get_first_child ();
            while (child != null) {
                results_children.add (child);
                child = child.get_next_sibling ();
            }
            foreach (var widget in results_children) {
                results_container.remove (widget);
            }
            debug ("  Cleared %d server result groups", results_children.size);

            debug ("=== DONE CLEARING ===");
        }

        private string get_server_display_name (string dns_server) {
            if (dns_server == null || dns_server.strip () == "") {
                return "System Default (localhost)";
            }
            return dns_server;
        }

        private string get_record_type_icon (RecordType record_type) {
            switch (record_type) {
                case RecordType.A:
                    return "network-wired-symbolic";  // IPv4
                case RecordType.AAAA:
                    return "network-wireless-symbolic";  // IPv6
                case RecordType.CNAME:
                    return "go-jump-symbolic";  // Alias/redirect
                case RecordType.MX:
                    return "mail-send-symbolic";  // Mail server
                case RecordType.NS:
                    return "network-server-symbolic";  // Name server
                case RecordType.TXT:
                    return "text-x-generic-symbolic";  // Text record
                case RecordType.SOA:
                    return "emblem-system-symbolic";  // Authority
                case RecordType.PTR:
                    return "go-previous-symbolic";  // Reverse lookup
                case RecordType.SRV:
                    return "preferences-system-symbolic";  // Service
                default:
                    return "text-x-generic-symbolic";  // Generic fallback
            }
        }

        private RecordType get_selected_record_type () {
            var selected_text = ((Gtk.StringList) record_type_dropdown.model).get_string (record_type_dropdown.selected);
            var type_code = selected_text.split (" - ")[0];
            return RecordType.from_string (type_code);
        }

        private void export_results () {
            if (current_comparison_result == null) {
                return;
            }

            // Create file chooser dialog
            var file_dialog = new Gtk.FileDialog () {
                title = "Export Comparison Results",
                modal = true
            };

            // Set up file filters
            var filter_json = new Gtk.FileFilter ();
            filter_json.set_filter_name ("JSON (*.json)");
            filter_json.add_pattern ("*.json");

            var filter_csv = new Gtk.FileFilter ();
            filter_csv.set_filter_name ("CSV (*.csv)");
            filter_csv.add_pattern ("*.csv");

            var filter_text = new Gtk.FileFilter ();
            filter_text.set_filter_name ("Plain Text (*.txt)");
            filter_text.add_pattern ("*.txt");

            var filter_all = new Gtk.FileFilter ();
            filter_all.set_filter_name ("All Files");
            filter_all.add_pattern ("*");

            var filter_list = new GLib.ListStore (typeof (Gtk.FileFilter));
            filter_list.append (filter_json);
            filter_list.append (filter_csv);
            filter_list.append (filter_text);
            filter_list.append (filter_all);

            file_dialog.filters = filter_list;
            file_dialog.default_filter = filter_json;

            // Set default filename: comparison.{domain}.{date}.json
            var domain = current_comparison_result.domain;
            var date = current_comparison_result.timestamp.format ("%Y-%m-%d");
            file_dialog.initial_name = @"comparison.$(domain).$(date).json";

            // Show save dialog
            file_dialog.save.begin (this.get_root () as Gtk.Window, null, (obj, res) => {
                try {
                    var file = file_dialog.save.end (res);
                    if (file != null) {
                        // Determine format based on file extension
                        var filename = file.get_basename ();
                        ExportFormat format = ExportFormat.JSON;

                        if (filename.has_suffix (".csv")) {
                            format = ExportFormat.CSV;
                        } else if (filename.has_suffix (".txt")) {
                            format = ExportFormat.TEXT;
                        }

                        // Export the results
                        var export_manager = ExportManager.get_instance ();
                        export_manager.export_multiple_results.begin (
                            current_comparison_result.server_results,
                            file,
                            format,
                            (obj2, res2) => {
                                bool success = export_manager.export_multiple_results.end (res2);
                                if (success) {
                                    // Show success message
                                    var success_dialog = new Adw.AlertDialog (
                                        "Export Successful",
                                        @"Comparison results have been exported to:\n$(file.get_path ())"
                                    );
                                    success_dialog.add_response ("ok", "OK");
                                    success_dialog.set_response_appearance ("ok", Adw.ResponseAppearance.SUGGESTED);
                                    success_dialog.present (this.get_root () as Gtk.Window);
                                } else {
                                    // Show error dialog
                                    var error_dialog = new Adw.AlertDialog (
                                        "Export Failed",
                                        "Could not export comparison results. Please check the file path and permissions."
                                    );
                                    error_dialog.add_response ("ok", "OK");
                                    error_dialog.set_response_appearance ("ok", Adw.ResponseAppearance.DESTRUCTIVE);
                                    error_dialog.present (this.get_root () as Gtk.Window);
                                }
                            }
                        );
                    }
                } catch (Error e) {
                    warning ("File dialog error: %s", e.message);
                }
            });
        }
    }
}
