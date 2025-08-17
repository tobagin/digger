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
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/window.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/window.ui")]
#endif
    public class Window : Adw.ApplicationWindow {
        [GtkChild] private unowned Adw.ToastOverlay toast_overlay;
        [GtkChild] private unowned EnhancedQueryForm query_form;
        [GtkChild] private unowned EnhancedResultView result_view;
        [GtkChild] private unowned Gtk.MenuButton history_button;
        [GtkChild] private unowned Gtk.Popover history_popover;
        [GtkChild] private unowned Gtk.ListBox history_listbox;
        [GtkChild] private unowned Gtk.SearchEntry history_search_entry;
        [GtkChild] private unowned Gtk.Button clear_button;
        
        private AdvancedOptions advanced_options;
        
        private DnsQuery dns_query;
        private QueryHistory query_history;
        private DnsPresets dns_presets;
        private ThemeManager theme_manager;
        private bool query_in_progress = false;

        public Window (Gtk.Application app, QueryHistory history) {
            Object (application: app);
            query_history = history;
            
            // Initialize enhanced components
            dns_presets = DnsPresets.get_instance ();
            theme_manager = ThemeManager.get_instance ();
            
            setup_ui ();
            setup_actions ();
            connect_signals ();
            
            dns_query = new DnsQuery ();
            dns_query.query_completed.connect (on_query_completed);
            dns_query.query_failed.connect (on_query_failed);
        }

        private void setup_ui () {
            // Connect query history to enhanced form for autocomplete
            query_form.set_query_history (query_history);
            
            // Get advanced options from the form (they should be embedded in the blueprint)
            advanced_options = query_form.get_advanced_options ();
        }

        private void setup_actions () {
            var action_group = new SimpleActionGroup ();
            
            var new_query_action = new SimpleAction ("new-query", null);
            new_query_action.activate.connect (focus_domain_entry);
            action_group.add_action (new_query_action);
            
            var repeat_query_action = new SimpleAction ("repeat-query", null);
            repeat_query_action.activate.connect (repeat_last_query);
            action_group.add_action (repeat_query_action);
            
            var clear_results_action = new SimpleAction ("clear-results", null);
            clear_results_action.activate.connect (clear_results);
            action_group.add_action (clear_results_action);

            insert_action_group ("win", action_group);
        }

        private void connect_signals () {
            query_form.query_requested.connect (on_query_requested);
            
            history_search_entry.search_changed.connect (update_history_list);
            history_listbox.row_activated.connect (on_history_item_selected);
            clear_button.clicked.connect (on_clear_history);
            
            query_history.history_updated.connect (update_history_list);
            
            // Update history list initially
            update_history_list ();
        }
        
        private void on_clear_history () {
            query_history.clear_history ();
            history_popover.popdown ();
        }

        private void focus_domain_entry () {
            query_form.focus_domain_entry ();
        }

        private void repeat_last_query () {
            var last_query = query_history.get_last_query ();
            if (last_query != null) {
                apply_query_settings (last_query);
                // Trigger query through the form's signal
                query_form.trigger_query ();
            }
        }

        private void clear_results () {
            result_view.clear_results ();
            query_form.clear_form ();
            advanced_options.reset_to_defaults ();
            query_form.focus_domain_entry ();
        }

        private void on_query_requested (string domain, RecordType record_type, string? dns_server) {
            if (!query_in_progress) {
                perform_query_with_params.begin (domain, record_type, dns_server);
            }
        }

        private async void perform_query_with_params (string domain, RecordType record_type, string? dns_server) {
            if (domain.length == 0) {
                show_toast ("Please enter a domain name or IP address");
                return;
            }

            query_in_progress = true;
            
            // Get advanced options
            string? server = dns_server;
            if (server == "System default") {
                server = advanced_options.dns_server;
            }
            if (server != null && server.length == 0) {
                server = null;
            }
            
            result_view.show_query_started (domain, record_type, server);

            try {
                var result = yield dns_query.perform_query (
                    domain,
                    record_type,
                    server,
                    advanced_options.reverse_lookup,
                    advanced_options.trace_path,
                    advanced_options.short_output
                );

                if (result != null) {
                    result_view.show_result (result);
                    query_history.add_query (result);
                }

            } catch (Error e) {
                show_toast (@"Query failed: $(e.message)");
                result_view.clear_results ();
            }

            query_in_progress = false;
        }

        private void on_query_completed (QueryResult result) {
            // This is handled in perform_query now
        }

        private void on_query_failed (string error_message) {
            show_toast (error_message);
        }


        private void show_toast (string message) {
            var toast = new Adw.Toast (message);
            toast.timeout = 3;
            toast_overlay.add_toast (toast);
        }

        private void update_history_list () {
            // Clear existing items
            var child = history_listbox.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                history_listbox.remove (child);
                child = next;
            }

            // Get filtered history
            var history_items = history_search_entry.text.length > 0 
                ? query_history.search_history (history_search_entry.text)
                : query_history.get_history ();

            if (history_items.size == 0) {
                var placeholder_row = new Gtk.ListBoxRow () {
                    selectable = false
                };
                var placeholder_label = new Gtk.Label ("No queries in history") {
                    margin_top = 12,
                    margin_bottom = 12
                };
                placeholder_label.add_css_class ("dim-label");
                placeholder_row.child = placeholder_label;
                history_listbox.append (placeholder_row);
                return;
            }

            foreach (var result in history_items) {
                var row = create_history_row (result);
                history_listbox.append (row);
            }
        }

        private Gtk.ListBoxRow create_history_row (QueryResult result) {
            var row = new Gtk.ListBoxRow ();
            
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3) {
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 6,
                margin_end = 6
            };

            var title_label = new Gtk.Label (@"$(result.domain) ($(result.query_type.to_string ()))") {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END
            };
            title_label.add_css_class ("body");

            var subtitle_parts = new Gee.ArrayList<string> ();
            subtitle_parts.add (result.timestamp.format ("%H:%M:%S"));
            
            if (result.dns_server != "System default") {
                subtitle_parts.add (result.dns_server);
            }
            
            subtitle_parts.add (result.get_summary ());

            var subtitle_label = new Gtk.Label (string.joinv (" • ", subtitle_parts.to_array ())) {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END
            };
            subtitle_label.add_css_class ("caption");
            subtitle_label.add_css_class ("dim-label");

            box.append (title_label);
            box.append (subtitle_label);
            row.child = box;

            row.set_data ("query-result", result);
            return row;
        }

        private void on_history_item_selected (Gtk.ListBoxRow row) {
            var result = row.get_data<QueryResult> ("query-result");
            if (result != null) {
                apply_query_settings (result);
                result_view.show_result (result);
                history_popover.popdown ();
            }
        }

        private void apply_query_settings (QueryResult result) {
            query_form.set_domain (result.domain);
            query_form.set_record_type (result.query_type);
            query_form.set_dns_server (result.dns_server);
            advanced_options.apply_from_query_result (result);
        }
    }
}
