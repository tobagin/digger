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
    public class Window : Adw.ApplicationWindow {
        private Adw.ToastOverlay toast_overlay;
        private Gtk.Entry domain_entry;
        private Gtk.DropDown record_type_dropdown;
        private Gtk.Button query_button;
        private AdvancedOptions advanced_options;
        private QueryResultView result_view;
        private Gtk.Button history_button;
        private Gtk.Popover history_popover;
        private Gtk.ListBox history_listbox;
        private Gtk.SearchEntry history_search_entry;
        
        private DnsQuery dns_query;
        private QueryHistory query_history;
        private bool query_in_progress = false;

        public Window (Gtk.Application app, QueryHistory history) {
            Object (application: app);
            query_history = history;
            
            setup_ui ();
            setup_actions ();
            connect_signals ();
            
            dns_query = new DnsQuery ();
            dns_query.query_completed.connect (on_query_completed);
            dns_query.query_failed.connect (on_query_failed);
        }

        private void setup_ui () {
            title = "Digger";
            default_width = 900;
            default_height = 700;

            // Main toast overlay
            toast_overlay = new Adw.ToastOverlay ();
            content = toast_overlay;

            // Header bar
            var header_bar = new Adw.HeaderBar ();
            
            // History button in header
            history_button = new Gtk.Button.from_icon_name ("document-open-recent-symbolic") {
                tooltip_text = "Query History"
            };
            header_bar.pack_start (history_button);

            // Menu button
            var menu_button = new Gtk.MenuButton () {
                icon_name = "open-menu-symbolic",
                menu_model = create_menu_model ()
            };
            header_bar.pack_end (menu_button);

            // Main content
            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            toast_overlay.child = main_box;
            
            // Add header bar
            main_box.append (header_bar);

            // Query form in header area
            var query_form_group = new Adw.PreferencesGroup () {
                margin_top = 12,
                margin_start = 12,
                margin_end = 12,
                margin_bottom = 6
            };

            // Domain input row
            var domain_row = new Adw.ActionRow () {
                title = "Domain or IP Address"
            };
            
            domain_entry = new Gtk.Entry () {
                placeholder_text = "example.com",
                hexpand = true,
                input_purpose = Gtk.InputPurpose.URL
            };
            domain_row.add_suffix (domain_entry);

            // Record type dropdown row
            var record_type_row = new Adw.ActionRow () {
                title = "Record Type"
            };

            var record_type_model = new Gtk.StringList (null);
            record_type_model.append ("A");
            record_type_model.append ("AAAA");
            record_type_model.append ("CNAME");
            record_type_model.append ("MX");
            record_type_model.append ("NS");
            record_type_model.append ("PTR");
            record_type_model.append ("TXT");
            record_type_model.append ("SOA");
            record_type_model.append ("SRV");
            record_type_model.append ("ANY");

            record_type_dropdown = new Gtk.DropDown (record_type_model, null) {
                selected = 0 // Default to A record
            };
            record_type_row.add_suffix (record_type_dropdown);

            // Advanced options
            advanced_options = new AdvancedOptions ();

            // Query button row
            var button_row = new Adw.ActionRow ();
            query_button = new Gtk.Button.with_label ("Look up DNS records") {
                hexpand = true
            };
            query_button.add_css_class ("suggested-action");
            button_row.add_suffix (query_button);

            query_form_group.add (domain_row);
            query_form_group.add (record_type_row);
            query_form_group.add (advanced_options);
            query_form_group.add (button_row);

            main_box.append (query_form_group);

            // Separator
            var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            main_box.append (separator);

            // Results view
            result_view = new QueryResultView ();
            main_box.append (result_view);

            // Setup history popover
            setup_history_popover ();
        }

        private void setup_history_popover () {
            history_popover = new Gtk.Popover () {
                position = Gtk.PositionType.BOTTOM,
                width_request = 400,
                height_request = 500
            };
            history_button.popover = history_popover;

            var history_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };

            // Title
            var history_title = new Gtk.Label ("Query History") {
                halign = Gtk.Align.START
            };
            history_title.add_css_class ("heading");
            history_box.append (history_title);

            // Search entry
            history_search_entry = new Gtk.SearchEntry () {
                placeholder_text = "Search history..."
            };
            history_box.append (history_search_entry);

            // History list
            var scrolled_window = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                vexpand = true
            };

            history_listbox = new Gtk.ListBox ();
            history_listbox.add_css_class ("boxed-list");
            scrolled_window.child = history_listbox;
            history_box.append (scrolled_window);

            // Clear history button
            var clear_button = new Gtk.Button.with_label ("Clear History") {
                halign = Gtk.Align.CENTER
            };
            clear_button.add_css_class ("destructive-action");
            clear_button.clicked.connect (() => {
                query_history.clear_history ();
                history_popover.popdown ();
            });
            history_box.append (clear_button);

            history_popover.child = history_box;
        }

        private GLib.MenuModel create_menu_model () {
            var menu = new GLib.Menu ();
            menu.append ("About Digger", "app.about");
            menu.append ("Preferences", "app.preferences");
            return menu;
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
            domain_entry.activate.connect (on_query_button_clicked);
            query_button.clicked.connect (on_query_button_clicked);
            
            history_search_entry.search_changed.connect (update_history_list);
            history_listbox.row_activated.connect (on_history_item_selected);
            
            query_history.history_updated.connect (update_history_list);
            
            // Update history list initially
            update_history_list ();
        }

        private void focus_domain_entry () {
            domain_entry.grab_focus ();
        }

        private void repeat_last_query () {
            var last_query = query_history.get_last_query ();
            if (last_query != null) {
                apply_query_settings (last_query);
                perform_query ();
            }
        }

        private void clear_results () {
            result_view.clear_results ();
            domain_entry.text = "";
            advanced_options.reset_to_defaults ();
            domain_entry.grab_focus ();
        }

        private void on_query_button_clicked () {
            if (!query_in_progress) {
                perform_query ();
            }
        }

        private async void perform_query () {
            string domain = domain_entry.text.strip ();
            if (domain.length == 0) {
                show_toast ("Please enter a domain name or IP address");
                return;
            }

            query_in_progress = true;
            update_query_button_state ();

            // Get selected record type
            uint selected_index = record_type_dropdown.selected;
            RecordType record_type = (RecordType) selected_index;

            // Get advanced options
            string? dns_server = advanced_options.dns_server;
            if (dns_server != null && dns_server.length == 0) {
                dns_server = null;
            }

            try {
                var result = yield dns_query.perform_query (
                    domain,
                    record_type,
                    dns_server,
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
            }

            query_in_progress = false;
            update_query_button_state ();
        }

        private void on_query_completed (QueryResult result) {
            // This is handled in perform_query now
        }

        private void on_query_failed (string error_message) {
            show_toast (error_message);
        }

        private void update_query_button_state () {
            if (query_in_progress) {
                query_button.label = "Looking up...";
                query_button.sensitive = false;
            } else {
                query_button.label = "Look up DNS records";
                query_button.sensitive = true;
            }
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
            domain_entry.text = result.domain;
            record_type_dropdown.selected = (uint) result.query_type;
            advanced_options.apply_from_query_result (result);
        }
    }
}
