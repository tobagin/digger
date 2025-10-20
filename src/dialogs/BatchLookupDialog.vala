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
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/batch-lookup-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/batch-lookup-dialog.ui")]
#endif
    public class BatchLookupDialog : Adw.Dialog {
        [GtkChild] private unowned Gtk.Button execute_button;
        [GtkChild] private unowned Gtk.Button import_button;
        [GtkChild] private unowned Gtk.Button manual_button;
        [GtkChild] private unowned Gtk.DropDown record_type_dropdown;
        [GtkChild] private unowned Gtk.DropDown dns_server_dropdown;
        [GtkChild] private unowned Gtk.Switch parallel_switch;
        [GtkChild] private unowned Gtk.Label domains_label;
        [GtkChild] private unowned Gtk.ListView domains_list;
        [GtkChild] private unowned Gtk.ProgressBar progress_bar;
        [GtkChild] private unowned Gtk.Box results_box;
        [GtkChild] private unowned Gtk.ListView results_list;
        [GtkChild] private unowned Gtk.Button export_results_button;
        [GtkChild] private unowned Gtk.Button clear_results_button;

        private BatchLookupManager batch_manager;
        private DnsPresets dns_presets;
        private Gtk.StringList domains_model;
        private GLib.ListStore results_model;

        public BatchLookupDialog () {
            batch_manager = BatchLookupManager.get_instance ();
            dns_presets = DnsPresets.get_instance ();
        }

        construct {
            setup_ui ();
            connect_signals ();
        }

        private void setup_ui () {
            domains_model = new Gtk.StringList (null);
            domains_list.model = new Gtk.SingleSelection (domains_model);

            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((list_item) => {
                var item = list_item as Gtk.ListItem;
                if (item == null) {
                    warning ("Null list item in factory setup");
                    return;
                }
                item.child = new Gtk.Label ("") {
                    halign = Gtk.Align.START,
                    xalign = 0
                };
            });
            factory.bind.connect ((list_item) => {
                var item = list_item as Gtk.ListItem;
                if (item == null) {
                    warning ("Null list item in factory bind");
                    return;
                }
                var label = item.child as Gtk.Label;
                var string_object = item.item as Gtk.StringObject;

                // Null safety for type casts
                if (label == null || string_object == null) {
                    warning ("Null label or string_object in factory bind");
                    return;
                }

                label.label = string_object.string;
            });
            domains_list.factory = factory;

            setup_record_type_dropdown ();
            setup_dns_server_dropdown ();

            results_model = new GLib.ListStore (typeof (BatchLookupTask));
            results_list.model = new Gtk.SingleSelection (results_model);

            var results_factory = new Gtk.SignalListItemFactory ();
            results_factory.setup.connect ((list_item) => {
                var item = list_item as Gtk.ListItem;
                if (item == null) {
                    warning ("Null list item in results factory setup");
                    return;
                }
                var row = new Adw.ActionRow ();
                item.child = row;
            });
            results_factory.bind.connect ((list_item) => {
                var item = list_item as Gtk.ListItem;
                if (item == null) {
                    warning ("Null list item in results factory bind");
                    return;
                }
                var row = item.child as Adw.ActionRow;
                var task = item.item as BatchLookupTask;

                // Null safety for type casts
                if (row == null || task == null) {
                    warning ("Null row or task in results factory bind");
                    return;
                }

                row.title = task.domain;
                if (task.completed) {
                    if (task.failed) {
                        row.subtitle = task.error_message ?? "Failed";
                        var icon = new Gtk.Image.from_icon_name ("dialog-error-symbolic");
                        row.add_prefix (icon);
                    } else {
                        var count = task.result != null ? task.result.answer_section.size : 0;
                        row.subtitle = @"$count records";
                        var icon = new Gtk.Image.from_icon_name ("emblem-ok-symbolic");
                        row.add_prefix (icon);
                    }
                } else {
                    row.subtitle = "Pending...";
                    var spinner = new Gtk.Spinner () {
                        spinning = true
                    };
                    row.add_prefix (spinner);
                }
            });
            results_list.factory = results_factory;
        }

        private void setup_record_type_dropdown () {
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

        private void setup_dns_server_dropdown () {
            var model = new Gtk.StringList (null);
            model.append ("System Default");
            model.append ("Google (8.8.8.8)");
            model.append ("Cloudflare (1.1.1.1)");
            model.append ("Quad9 (9.9.9.9)");
            dns_server_dropdown.model = model;
            dns_server_dropdown.selected = 0;
        }

        private void connect_signals () {
            execute_button.clicked.connect (execute_batch);
            import_button.clicked.connect (import_from_file);
            manual_button.clicked.connect (show_manual_entry_dialog);
            export_results_button.clicked.connect (export_results);
            clear_results_button.clicked.connect (clear_results);

            batch_manager.task_completed.connect (on_task_completed);
        }

        private void import_from_file () {
            var file_dialog = new Gtk.FileDialog () {
                title = "Import Domains",
                modal = true
            };

            var filter = new Gtk.FileFilter ();
            filter.set_filter_name ("Text and CSV files");
            filter.add_pattern ("*.txt");
            filter.add_pattern ("*.csv");

            var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters.append (filter);
            file_dialog.filters = filters;

            file_dialog.open.begin (this as Gtk.Window, null, (obj, res) => {
                try {
                    var file = file_dialog.open.end (res);
                    if (file != null) {
                        import_domains_from_file.begin (file);
                    }
                } catch (Error e) {
                    if (!(e is Gtk.DialogError.DISMISSED)) {
                        warning ("File selection error: %s", e.message);
                    }
                }
            });
        }

        private async void import_domains_from_file (File file) {
            try {
                var record_type = get_selected_record_type ();
                var dns_server = get_selected_dns_server ();
                var success = yield batch_manager.import_from_file (file, record_type, dns_server);
                if (success) {
                    var tasks = batch_manager.get_tasks ();
                    foreach (var task in tasks) {
                        domains_model.append (task.domain);
                    }
                    update_domains_count ();
                }
            } catch (Error e) {
                warning ("Failed to import domains: %s", e.message);
            }
        }

        private void show_manual_entry_dialog () {
            var dialog = new Adw.AlertDialog ("Add Domains Manually", "Enter domain names, one per line:");

            var text_view = new Gtk.TextView () {
                height_request = 200,
                accepts_tab = false
            };
            text_view.buffer.text = "";

            var scrolled = new Gtk.ScrolledWindow () {
                child = text_view,
                hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC
            };

            dialog.set_extra_child (scrolled);
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("add", "Add");
            dialog.set_response_appearance ("add", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response ("add");

            dialog.response.connect ((response) => {
                if (response == "add") {
                    var text = text_view.buffer.text.strip ();
                    if (text.length > 0) {
                        var lines = text.split ("\n");
                        foreach (var line in lines) {
                            var domain = line.strip ();
                            if (domain.length > 0) {
                                domains_model.append (domain);
                            }
                        }
                        update_domains_count ();
                    }
                }
            });

            dialog.present (this);
        }

        private void update_domains_count () {
            domains_label.label = @"Domains to Query ($(domains_model.get_n_items ()))";
            execute_button.sensitive = domains_model.get_n_items () > 0;
        }

        private void execute_batch () {
            if (domains_model.get_n_items () == 0) {
                return;
            }

            var record_type = get_selected_record_type ();
            var dns_server = get_selected_dns_server ();
            var parallel = parallel_switch.active;

            batch_manager.clear_tasks ();

            for (uint i = 0; i < domains_model.get_n_items (); i++) {
                var domain = domains_model.get_string (i);
                var task = new BatchLookupTask (domain, record_type);
                task.dns_server = dns_server;
                batch_manager.add_task (task);
            }

            results_model.remove_all ();
            results_box.visible = true;
            progress_bar.visible = true;
            progress_bar.fraction = 0;
            execute_button.sensitive = false;
            import_button.sensitive = false;
            manual_button.sensitive = false;

            batch_manager.execute_batch.begin (parallel, false, false, false, (obj, res) => {
                try {
                    batch_manager.execute_batch.end (res);
                } catch (Error e) {
                    warning ("Batch execution error: %s", e.message);
                }

                progress_bar.visible = false;
                execute_button.sensitive = true;
                import_button.sensitive = true;
                manual_button.sensitive = true;
            });
        }

        private void on_task_completed (BatchLookupTask task) {
            results_model.append (task);

            var completed = 0;
            var total = 0;
            for (uint i = 0; i < results_model.get_n_items (); i++) {
                var t = results_model.get_item (i) as BatchLookupTask;
                if (t.completed) completed++;
                total++;
            }
            progress_bar.fraction = (double) completed / total;
            progress_bar.text = @"$completed / $total completed";
        }

        private RecordType get_selected_record_type () {
            var selected_text = ((Gtk.StringList) record_type_dropdown.model).get_string (record_type_dropdown.selected);
            var type_code = selected_text.split (" - ")[0];
            return RecordType.from_string (type_code);
        }

        private string? get_selected_dns_server () {
            var selected = dns_server_dropdown.selected;
            if (selected == 0) return null;

            var text = ((Gtk.StringList) dns_server_dropdown.model).get_string (selected);
            if (text.contains ("8.8.8.8")) return "8.8.8.8";
            if (text.contains ("1.1.1.1")) return "1.1.1.1";
            if (text.contains ("9.9.9.9")) return "9.9.9.9";
            return null;
        }

        private void export_results () {
            var file_dialog = new Gtk.FileDialog () {
                title = "Export Batch Results",
                modal = true,
                initial_name = "batch-results.json"
            };

            var filter_json = new Gtk.FileFilter ();
            filter_json.set_filter_name ("JSON (*.json)");
            filter_json.add_pattern ("*.json");

            var filter_csv = new Gtk.FileFilter ();
            filter_csv.set_filter_name ("CSV (*.csv)");
            filter_csv.add_pattern ("*.csv");

            var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters.append (filter_json);
            filters.append (filter_csv);
            file_dialog.filters = filters;

            file_dialog.save.begin (this as Gtk.Window, null, (obj, res) => {
                try {
                    var file = file_dialog.save.end (res);
                    if (file != null) {
                        export_batch_results.begin (file);
                    }
                } catch (Error e) {
                    if (!(e is Gtk.DialogError.DISMISSED)) {
                        warning ("Export file selection error: %s", e.message);
                    }
                }
            });
        }

        private async void export_batch_results (File file) {
            var file_path = file.get_path ();
            var format = file_path.has_suffix (".csv") ? ExportFormat.CSV : ExportFormat.JSON;

            var export_manager = ExportManager.get_instance ();

            for (uint i = 0; i < results_model.get_n_items (); i++) {
                var task = results_model.get_item (i) as BatchLookupTask;
                if (task.result != null) {
                    var result_file = File.new_for_path (file_path);
                    yield export_manager.export_result (task.result, result_file, format);
                }
            }
        }

        private void clear_results () {
            results_model.remove_all ();
            results_box.visible = false;
        }
    }
}
