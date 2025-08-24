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
        [GtkChild] private unowned Gtk.Button history_button;
        [GtkChild] private unowned Gtk.Popover history_popover;
        [GtkChild] private unowned Gtk.ListBox history_listbox;
        [GtkChild] private unowned Gtk.SearchEntry history_search_entry;
        [GtkChild] private unowned Gtk.Button clear_button;
        
        
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
            // Initialize the enhanced query form with DNS presets
            query_form.set_dns_presets (dns_presets);
            
            // Connect query history to enhanced form for autocomplete
            query_form.set_query_history (query_history);
            
            // Use custom symbolic icon with proper naming for theme support
            history_button.icon_name = Config.APP_ID + "-history-symbolic";
            
            // Connect button click to show popover manually
            history_button.clicked.connect (() => {
                history_popover.set_parent (history_button);
                history_popover.popup ();
            });
            
            // Fix popover focus issues
            history_popover.autohide = true;
            history_popover.can_focus = false;
            
            // Ensure history components are sensitive and enabled
            history_button.sensitive = true;
            history_popover.sensitive = true;
            history_listbox.sensitive = true;
            history_search_entry.sensitive = true;
            clear_button.sensitive = true;
            
            // Ensure result view shows welcome message initially
            result_view.clear_results ();
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
            
            // Connect to popover show signal to ensure widgets are enabled
            history_popover.show.connect (() => {
                debug ("Popover shown - forcing widget sensitivity");
                
                // Force enable immediately when shown
                Idle.add (() => {
                    force_enable_history_components ();
                    
                    // Additional debugging
                    debug ("SearchEntry sensitive: %s, can_focus: %s", 
                           history_search_entry.sensitive.to_string(),
                           history_search_entry.can_focus.to_string());
                    debug ("ListBox sensitive: %s, can_focus: %s", 
                           history_listbox.sensitive.to_string(),
                           history_listbox.can_focus.to_string());
                    debug ("Clear button sensitive: %s, can_focus: %s", 
                           clear_button.sensitive.to_string(),
                           clear_button.can_focus.to_string());
                    
                    // Allow natural focus flow instead of forcing focus
                    // history_search_entry.grab_focus ();
                    
                    return false;
                });
            });
            
            // Update history list initially
            update_history_list ();
            
            // Force enable history components after everything is connected
            force_enable_history_components ();
            
            // Also try after a short delay to ensure UI is fully loaded
            Timeout.add (100, () => {
                force_enable_history_components ();
                return false;
            });
        }
        
        private void force_enable_history_components () {
            // Force enable all history-related widgets
            history_button.set_sensitive (true);
            history_popover.set_sensitive (true);
            
            // Ensure popover handles focus correctly
            history_popover.autohide = true;
            history_popover.can_focus = false;
            
            // Enable the history box container
            var history_box = history_popover.get_child ();
            if (history_box != null) {
                history_box.set_sensitive (true);
                history_box.can_focus = true;
            }
            
            history_listbox.set_sensitive (true);
            history_search_entry.set_sensitive (true);
            clear_button.set_sensitive (true);
            
            // Also try setting can_focus to ensure they're interactive
            history_search_entry.can_focus = true;
            history_listbox.can_focus = true;
            clear_button.can_focus = true;
            
            // Enable the ListBox selection and activation
            history_listbox.selection_mode = Gtk.SelectionMode.SINGLE;
            history_listbox.activate_on_single_click = true;
            
            // Make sure all existing rows are also enabled
            var child = history_listbox.get_first_child ();
            while (child != null) {
                if (child is Gtk.ListBoxRow) {
                    var row = child as Gtk.ListBoxRow;
                    row.set_sensitive (true);
                    row.set_activatable (true);
                    row.set_selectable (true);
                    row.can_focus = true;
                }
                child = child.get_next_sibling ();
            }
            
            // Print debug info
            debug ("History button sensitive: %s", history_button.sensitive.to_string ());
            debug ("History popover sensitive: %s", history_popover.sensitive.to_string ());
            debug ("History search sensitive: %s", history_search_entry.sensitive.to_string ());
            debug ("History listbox sensitive: %s", history_listbox.sensitive.to_string ());
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
            query_form.set_reverse_lookup (false);
            query_form.set_trace_path (false);
            query_form.set_short_output (false);
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
            
            // Use the provided DNS server
            string? server = dns_server;
            if (server != null && server.length == 0) {
                server = null;
            }
            
            result_view.show_query_started (domain, record_type, server);

            var result = yield dns_query.perform_query (
                domain,
                record_type,
                server,
                query_form.get_reverse_lookup (),
                query_form.get_trace_path (),
                query_form.get_short_output ()
            );

            if (result != null) {
                result_view.show_result (result);
                query_history.add_query (result);
                
                // Auto-clear form if preference is enabled
                var settings = new GLib.Settings (Config.APP_ID);
                if (settings.get_boolean ("auto-clear-form")) {
                    query_form.clear_domain_only ();
                }
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
            
            // Force enable components after adding new rows
            force_enable_history_components ();
        }

        private Gtk.ListBoxRow create_history_row (QueryResult result) {
            var row = new Gtk.ListBoxRow ();
            row.selectable = true;
            row.activatable = true;
            row.sensitive = true;
            row.can_focus = true;
            
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

            string[] subtitle_array = subtitle_parts.to_array ();
            var subtitle_label = new Gtk.Label (string.joinv (" • ", subtitle_array)) {
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
            query_form.set_domain_from_history (result.domain);
            query_form.set_record_type (result.query_type);
            query_form.set_dns_server (result.dns_server);
            query_form.set_reverse_lookup (result.reverse_lookup);
            query_form.set_trace_path (result.trace_path);
            query_form.set_short_output (result.short_output);
        }
    }
}
