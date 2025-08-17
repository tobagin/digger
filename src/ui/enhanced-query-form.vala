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
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/enhanced-query-form.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/enhanced-query-form.ui")]
#endif
    public class EnhancedQueryForm : Adw.PreferencesGroup {
        [GtkChild] private unowned Gtk.Entry domain_entry;
        [GtkChild] private unowned Gtk.DropDown record_type_dropdown;
        [GtkChild] private unowned Gtk.Button query_button;
        [GtkChild] private unowned Gtk.Button paste_button;
        [GtkChild] private unowned Gtk.DropDown dns_server_dropdown;
        [GtkChild] private unowned Gtk.Box quick_presets_box;
        [GtkChild] private unowned Gtk.Switch reverse_lookup_switch;
        [GtkChild] private unowned Gtk.Switch trace_path_switch;
        [GtkChild] private unowned Gtk.Switch short_output_switch;
        
        private AutocompleteDropdown autocomplete_dropdown;
        
        private DnsPresets dns_presets;
        private QueryHistory query_history;
        private string current_dns_server = "";
        private bool signals_connected = false;
        private bool _query_in_progress = false;
        
        public signal void query_requested (string domain, RecordType record_type, string? dns_server);
        
        public bool query_in_progress { 
            get { return _query_in_progress; }
            set { 
                _query_in_progress = value;
                domain_entry.sensitive = !value;
                record_type_dropdown.sensitive = !value;
                dns_server_dropdown.sensitive = !value;
                
                if (value) {
                    query_button.label = "Querying...";
                    query_button.sensitive = false;
                } else {
                    query_button.label = "Look up DNS records";
                    // Re-validate to set correct button state
                    validate_input ();
                }
            }
        }
        
        public EnhancedQueryForm () {
            // dns_presets will be set via set_dns_presets() after construction
        }
        
        construct {
            // This runs after the template is applied
            // Initialize the button to disabled state initially
            query_button.sensitive = false;
            
            if (dns_presets != null) {
                setup_ui ();
                connect_signals ();
            }
        }
        
        public void set_dns_presets (DnsPresets presets) {
            dns_presets = presets;
            setup_ui ();
            if (!signals_connected) {
                connect_signals ();
                signals_connected = true;
                // Initial validation after signals are connected
                validate_input ();
            }
        }
        
        public void set_query_history (QueryHistory history) {
            query_history = history;
            
            // Connect autocomplete to query history
            autocomplete_dropdown.set_query_history (history);
            
            setup_domain_suggestions ();
        }
        
        private void setup_ui () {
            if (dns_presets == null) {
                return; // Cannot setup UI without presets
            }
            
            // Initialize autocomplete dropdown with domain entry from template
            if (autocomplete_dropdown == null) {
                autocomplete_dropdown = new AutocompleteDropdown (domain_entry);
            }
            
            setup_record_type_dropdown ();
            setup_dns_server_dropdown ();
            setup_quick_presets ();
        }
        
        private void setup_record_type_dropdown () {
            var model = new Gtk.StringList (null);
            var record_types = dns_presets.get_all_record_types ();
            
            // Sort by type name for consistent display
            var sorted_types = new Gee.ArrayList<RecordTypeInfo> ();
            sorted_types.add_all (record_types);
            sorted_types.sort ((a, b) => {
                // Put common types first
                string[] common_order = {"A", "AAAA", "CNAME", "MX", "NS", "TXT"};
                int pos_a = -1, pos_b = -1;
                for (int i = 0; i < common_order.length; i++) {
                    if (a.record_type == common_order[i]) pos_a = i;
                    if (b.record_type == common_order[i]) pos_b = i;
                }
                
                if (pos_a >= 0 && pos_b >= 0) return pos_a - pos_b;
                if (pos_a >= 0) return -1;
                if (pos_b >= 0) return 1;
                return strcmp (a.record_type, b.record_type);
            });
            
            foreach (var record_type in sorted_types) {
                model.append (record_type.get_display_name ());
            }
            
            // Set up the dropdown model (template widget is already created)
            record_type_dropdown.model = model;
            record_type_dropdown.selected = 0; // Default to first item (A record)
            
            // Add tooltips based on selection
            record_type_dropdown.notify["selected"].connect (() => {
                var selected_name = model.get_string (record_type_dropdown.selected);
                var type_code = selected_name.split (" - ")[0];
                var info = dns_presets.get_record_type_info (type_code);
                if (info != null) {
                    record_type_dropdown.tooltip_text = info.get_tooltip_text ();
                }
            });
        }
        
        private void setup_dns_server_dropdown () {
            var model = new Gtk.StringList (null);
            var dns_servers = new Gee.ArrayList<DnsServer> ();
            
            // Add system default as first option
            model.append ("System Default");
            
            // Add all DNS servers from presets
            var all_servers = dns_presets.get_dns_servers ();
            foreach (var server in all_servers) {
                dns_servers.add (server);
                model.append (server.get_display_name ());
            }
            
            // Add custom option
            model.append ("Custom DNS Server...");
            
            dns_server_dropdown.model = model;
            dns_server_dropdown.selected = 0; // Default to System Default
            
            // Store the dns_servers list for quick access
            dns_server_dropdown.set_data ("dns_servers", dns_servers);
            
            // Add tooltips and handle selection changes
            dns_server_dropdown.notify["selected"].connect (() => {
                var selected_index = dns_server_dropdown.selected;
                var selected_text = model.get_string (selected_index);
                
                if (selected_index == 0) {
                    // System Default
                    current_dns_server = "";
                    dns_server_dropdown.tooltip_text = "Use system default DNS server";
                } else if (selected_index == model.get_n_items () - 1) {
                    // Custom DNS Server option
                    show_custom_dns_dialog ();
                } else {
                    // Preset DNS server
                    var server = dns_servers.get ((int)(selected_index - 1));
                    current_dns_server = server.primary;
                    dns_server_dropdown.tooltip_text = server.get_tooltip_text ();
                }
            });
        }
        
        private void setup_quick_presets () {
            // Clear any existing preset buttons first
            var child = quick_presets_box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                quick_presets_box.remove (child);
                child = next;
            }
            
            // quick_presets_box is from template, just add buttons to it
            
            // Add Google DNS preset
            add_quick_preset_button ("Google", "8.8.8.8");
            
            // Add Cloudflare DNS preset
            add_quick_preset_button ("Cloudflare", "1.1.1.1");
            
            // Add Quad9 DNS preset
            add_quick_preset_button ("Quad9", "9.9.9.9");
        }
        
        private void add_quick_preset_button (string name, string ip) {
            var preset_button = new Gtk.Button.with_label (name) {
                tooltip_text = @"Use $name DNS ($ip)",
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            // preset_button.add_css_class ("pill");
            preset_button.clicked.connect (() => {
                set_dns_server_by_ip (ip);
            });
            quick_presets_box.append (preset_button);
        }
        
        private void setup_domain_suggestions () {
            if (query_history == null) return;
            
            // Autocomplete system is already set up through the AutocompleteDropdown
            // The dropdown will automatically use the query history for suggestions
        }
        
        private void connect_signals () {
            paste_button.clicked.connect (paste_from_clipboard);
            domain_entry.activate.connect (on_query_requested);
            query_button.clicked.connect (on_query_requested);
            
            // Real-time validation
            domain_entry.changed.connect (validate_input);
            
            // Connect autocomplete signals if dropdown exists
            if (autocomplete_dropdown != null) {
                autocomplete_dropdown.suggestion_selected.connect (on_autocomplete_selected);
            }
        }
        
        public bool get_reverse_lookup () {
            return reverse_lookup_switch.active;
        }
        
        public bool get_trace_path () {
            return trace_path_switch.active;
        }
        
        public bool get_short_output () {
            return short_output_switch.active;
        }
        
        public void set_reverse_lookup (bool value) {
            reverse_lookup_switch.active = value;
        }
        
        public void set_trace_path (bool value) {
            trace_path_switch.active = value;
        }
        
        public void set_short_output (bool value) {
            short_output_switch.active = value;
        }
        
        private void validate_input () {
            string domain = domain_entry.text.strip ();
            bool is_valid = domain.length > 0;
            
            // Basic domain/IP validation
            if (domain.length > 0) {
                is_valid = is_valid_domain_or_ip (domain);
            }
            
            query_button.sensitive = is_valid && !query_in_progress;
            
            if (!is_valid && domain.length > 0) {
                domain_entry.add_css_class ("error");
            } else {
                domain_entry.remove_css_class ("error");
            }
        }
        
        private bool is_valid_domain_or_ip (string input) {
            // Basic validation - could be more comprehensive
            if (input.length == 0 || input.length > 253) {
                return false;
            }
            
            // Check for valid characters
            try {
                return Regex.match_simple ("^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$", input) ||
                       Regex.match_simple ("^[a-zA-Z0-9]$", input) ||
                       Regex.match_simple ("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", input) ||
                       input.contains (":");  // Basic IPv6 check
            } catch (RegexError e) {
                return false;
            }
        }
        
        private void set_dns_server_by_ip (string ip) {
            var model = dns_server_dropdown.model as Gtk.StringList;
            var dns_servers = dns_server_dropdown.get_data<Gee.ArrayList<DnsServer>> ("dns_servers");
            
            // Look for the server by IP in our list
            for (int i = 0; i < dns_servers.size; i++) {
                var server = dns_servers.get (i);
                if (server.primary == ip) {
                    // Found it, select this item (add 1 for system default offset)
                    dns_server_dropdown.selected = (uint)(i + 1);
                    return;
                }
            }
        }
        
        private void show_custom_dns_dialog () {
            var dialog = new Adw.AlertDialog ("Custom DNS Server", "Enter a custom DNS server address:");
            
            var entry = new Gtk.Entry () {
                placeholder_text = "e.g., 1.1.1.1 or dns.example.com"
            };
            
            dialog.set_extra_child (entry);
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("ok", "OK");
            dialog.set_response_appearance ("ok", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response ("ok");
            
            var window = get_root () as Gtk.Window;
            
            dialog.response.connect_after ((response) => {
                if (response == "ok") {
                    var custom_server = entry.text.strip ();
                    if (custom_server.length > 0) {
                        // Add custom server to the model
                        add_custom_dns_server (custom_server);
                    } else {
                        // Go back to system default if empty
                        dns_server_dropdown.selected = 0;
                    }
                } else {
                    // Cancel - go back to previous selection or system default
                    dns_server_dropdown.selected = 0;
                }
            });
            
            dialog.present (window);
        }
        
        private void add_custom_dns_server (string server_ip) {
            var model = dns_server_dropdown.model as Gtk.StringList;
            var dns_servers = dns_server_dropdown.get_data<Gee.ArrayList<DnsServer>> ("dns_servers");
            
            // Create a custom DNS server entry
            var custom_server = new DnsServer ();
            custom_server.name = "Custom";
            custom_server.primary = server_ip;
            custom_server.description = @"Custom DNS server ($server_ip)";
            custom_server.category = "custom";
            
            // Check if this custom server already exists
            for (int i = 0; i < dns_servers.size; i++) {
                var existing = dns_servers.get (i);
                if (existing.category == "custom" && existing.primary == server_ip) {
                    // Already exists, just select it
                    dns_server_dropdown.selected = (uint)(i + 1);
                    return;
                }
            }
            
            // Remove old custom servers from the model and list
            for (int i = dns_servers.size - 1; i >= 0; i--) {
                var existing = dns_servers.get (i);
                if (existing.category == "custom") {
                    dns_servers.remove_at (i);
                    model.remove (i + 1); // +1 for system default offset
                }
            }
            
            // Add the new custom server
            var last_index = model.get_n_items () - 1;
            dns_servers.add (custom_server);
            
            // Get the "Custom DNS Server..." option and remove it temporarily
            var custom_option_text = model.get_string (last_index);
            model.remove (last_index);
            
            // Add the new server, then re-add the "Custom DNS Server..." option
            model.append (custom_server.get_display_name ());
            model.append (custom_option_text);
            
            // Select the new custom server
            dns_server_dropdown.selected = (uint)last_index;
            current_dns_server = server_ip;
        }
        
        private void paste_from_clipboard () {
            var clipboard = Gdk.Display.get_default ().get_clipboard ();
            clipboard.read_text_async.begin (null, (obj, result) => {
                try {
                    string? text = clipboard.read_text_async.end (result);
                    if (text != null && text.strip ().length > 0) {
                        domain_entry.text = text.strip ();
                        validate_input ();
                    }
                } catch (Error e) {
                    warning ("Error pasting from clipboard: %s", e.message);
                }
            });
        }
        
        private void on_query_requested () {
            if (query_in_progress) return;
            
            string domain = domain_entry.text.strip ();
            if (domain.length == 0) return;
            
            var selected_text = ((Gtk.StringList) record_type_dropdown.model).get_string (record_type_dropdown.selected);
            string record_type_str = selected_text.split (" - ")[0];
            RecordType record_type = RecordType.from_string (record_type_str);
            
            string? dns_server = current_dns_server.length > 0 ? current_dns_server : null;
            
            query_requested (domain, record_type, dns_server);
        }
        
        public string get_domain () {
            return domain_entry.text.strip ();
        }
        
        public void set_domain (string domain) {
            domain_entry.text = domain;
            validate_input ();
        }
        
        public void set_domain_from_history (string domain) {
            if (autocomplete_dropdown != null) {
                autocomplete_dropdown.set_domain_without_autocomplete (domain);
            } else {
                domain_entry.text = domain;
            }
            validate_input ();
        }
        
        public RecordType get_record_type () {
            var selected_text = ((Gtk.StringList) record_type_dropdown.model).get_string (record_type_dropdown.selected);
            string record_type_str = selected_text.split (" - ")[0];
            return RecordType.from_string (record_type_str);
        }
        
        public void set_record_type (RecordType record_type) {
            var model = (Gtk.StringList) record_type_dropdown.model;
            for (uint i = 0; i < model.get_n_items (); i++) {
                string item_text = model.get_string (i);
                string item_type = item_text.split (" - ")[0];
                if (item_type == record_type.to_string ()) {
                    record_type_dropdown.selected = i;
                    break;
                }
            }
        }
        
        public string? get_dns_server () {
            return current_dns_server.length > 0 ? current_dns_server : null;
        }
        
        public void set_dns_server (string server) {
            if (server.length == 0) {
                dns_server_dropdown.selected = 0; // System default
            } else {
                set_dns_server_by_ip (server);
            }
        }
        
        public void focus_domain_entry () {
            domain_entry.grab_focus ();
        }
        
        public void clear_form () {
            domain_entry.text = "";
            record_type_dropdown.selected = 0;
            dns_server_dropdown.selected = 0; // System default
            validate_input ();
        }
        
        public void trigger_query () {
            on_query_requested ();
        }
        
        /**
         * Handle autocomplete suggestion selection
         */
        private void on_autocomplete_selected (string domain) {
            // The domain is already set in the entry by the autocomplete dropdown
            // Just validate the input
            validate_input ();
            
            // Optionally trigger query immediately if user preference is set
            // For now, just focus remains on the domain entry for user confirmation
        }
        
        /**
         * Show autocomplete suggestions programmatically
         */
        public void show_suggestions () {
            autocomplete_dropdown.trigger_suggestions ();
        }
        
        /**
         * Hide autocomplete suggestions
         */
        public void hide_suggestions () {
            autocomplete_dropdown.clear_suggestions ();
        }
    }
}
