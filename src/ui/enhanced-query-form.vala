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
    public class EnhancedQueryForm : Adw.PreferencesGroup {
        private Gtk.Entry domain_entry;
        private Gtk.DropDown record_type_dropdown;
        private Gtk.Button query_button;
        private Gtk.MenuButton dns_server_button;
        private Gtk.Box quick_presets_box;
        private Adw.EntryRow custom_dns_entry;
        
        private DnsPresets dns_presets;
        private QueryHistory query_history;
        private string current_dns_server = "";
        
        public signal void query_requested (string domain, RecordType record_type, string? dns_server);
        
        public bool query_in_progress { 
            get { return !query_button.sensitive; }
            set { 
                query_button.sensitive = !value;
                domain_entry.sensitive = !value;
                record_type_dropdown.sensitive = !value;
                dns_server_button.sensitive = !value;
                
                if (value) {
                    query_button.label = "Querying...";
                } else {
                    query_button.label = "Look up DNS records";
                }
            }
        }
        
        public EnhancedQueryForm (DnsPresets presets) {
            dns_presets = presets;
            
            title = "DNS Query";
            description = "Enter a domain or IP address to look up DNS records";
            margin_top = 12;
            margin_start = 12;
            margin_end = 12;
            margin_bottom = 6;
            
            setup_ui ();
            connect_signals ();
        }
        
        public void set_query_history (QueryHistory history) {
            query_history = history;
            setup_domain_suggestions ();
        }
        
        private void setup_ui () {
            // Domain input row with smart suggestions
            var domain_row = new Adw.ActionRow () {
                title = "Domain or IP Address"
            };
            
            domain_entry = new Gtk.Entry () {
                placeholder_text = "example.com or 8.8.8.8",
                hexpand = true,
                input_purpose = Gtk.InputPurpose.URL
            };
            
            // Add quick paste button
            var paste_button = new Gtk.Button.from_icon_name ("edit-paste-symbolic") {
                tooltip_text = "Paste from clipboard",
                valign = Gtk.Align.CENTER
            };
            paste_button.add_css_class ("flat");
            paste_button.clicked.connect (paste_from_clipboard);
            
            var domain_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            domain_box.append (domain_entry);
            domain_box.append (paste_button);
            domain_row.add_suffix (domain_box);
            
            add (domain_row);
            
            // Record type dropdown with enhanced display
            var record_type_row = new Adw.ActionRow () {
                title = "Record Type"
            };
            
            setup_record_type_dropdown ();
            record_type_row.add_suffix (record_type_dropdown);
            add (record_type_row);
            
            // DNS Server selection row
            var dns_server_row = new Adw.ActionRow () {
                title = "DNS Server",
                subtitle = "System default"
            };
            
            setup_dns_server_button ();
            dns_server_row.add_suffix (dns_server_button);
            add (dns_server_row);
            
            // Quick preset buttons
            setup_quick_presets ();
            if (quick_presets_box.get_first_child () != null) {
                var presets_row = new Adw.ActionRow () {
                    title = "Quick Presets"
                };
                presets_row.add_suffix (quick_presets_box);
                add (presets_row);
            }
            
            // Query button row
            var button_row = new Adw.ActionRow ();
            query_button = new Gtk.Button.with_label ("Look up DNS records") {
                hexpand = true
            };
            query_button.add_css_class ("suggested-action");
            button_row.add_suffix (query_button);
            add (button_row);
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
            
            record_type_dropdown = new Gtk.DropDown (model, null) {
                selected = 0, // Default to first item (A record)
                tooltip_text = "Select the type of DNS record to query"
            };
            
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
        
        private void setup_dns_server_button () {
            dns_server_button = new Gtk.MenuButton () {
                icon_name = "network-server-symbolic",
                tooltip_text = "Select DNS server"
            };
            
            var popover = new Gtk.Popover () {
                position = Gtk.PositionType.BOTTOM
            };
            dns_server_button.popover = popover;
            
            var popover_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };
            
            // System default option
            var system_button = new Gtk.Button.with_label ("System Default") {
                hexpand = true
            };
            system_button.clicked.connect (() => {
                set_dns_server_internal ("", "System default");
                popover.popdown ();
            });
            popover_box.append (system_button);
            
            // Separator
            popover_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            
            // DNS server presets grouped by category
            var categories = new Gee.HashSet<string> ();
            foreach (var server in dns_presets.get_dns_servers ()) {
                categories.add (server.category);
            }
            
            foreach (string category in categories) {
                var category_label = new Gtk.Label (category.up ()) {
                    halign = Gtk.Align.START,
                    margin_top = 6
                };
                category_label.add_css_class ("heading");
                popover_box.append (category_label);
                
                var servers = dns_presets.get_dns_servers_by_category (category);
                foreach (var server in servers) {
                    var server_button = new Gtk.Button.with_label (server.get_display_name ()) {
                        hexpand = true,
                        tooltip_text = server.get_tooltip_text ()
                    };
                    
                    server_button.clicked.connect (() => {
                        set_dns_server_internal (server.primary, server.get_display_name ());
                        popover.popdown ();
                    });
                    
                    popover_box.append (server_button);
                }
            }
            
            // Custom DNS server entry
            popover_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            
            var custom_label = new Gtk.Label ("CUSTOM") {
                halign = Gtk.Align.START,
                margin_top = 6
            };
            custom_label.add_css_class ("heading");
            popover_box.append (custom_label);
            
            custom_dns_entry = new Adw.EntryRow () {
                title = "Custom DNS Server"
            };
            custom_dns_entry.apply.connect (() => {
                var custom_server = custom_dns_entry.text.strip ();
                if (custom_server.length > 0) {
                    set_dns_server_internal (custom_server, @"Custom ($custom_server)");
                    popover.popdown ();
                }
            });
            popover_box.append (custom_dns_entry);
            
            popover.child = popover_box;
        }
        
        private void setup_quick_presets () {
            quick_presets_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            
            // Add Google DNS preset
            add_quick_preset_button ("Google", "8.8.8.8");
            
            // Add Cloudflare DNS preset
            add_quick_preset_button ("Cloudflare", "1.1.1.1");
            
            // Add Quad9 DNS preset
            add_quick_preset_button ("Quad9", "9.9.9.9");
        }
        
        private void add_quick_preset_button (string name, string ip) {
            var preset_button = new Gtk.Button.with_label (name) {
                tooltip_text = @"Use $name DNS ($ip)"
            };
            preset_button.add_css_class ("pill");
            preset_button.clicked.connect (() => {
                set_dns_server_internal (ip, @"$name ($ip)");
            });
            quick_presets_box.append (preset_button);
        }
        
        private void setup_domain_suggestions () {
            if (query_history == null) return;
            
            // TODO: Implement domain autocomplete based on query history
            // This would require a more sophisticated completion system
        }
        
        private void connect_signals () {
            domain_entry.activate.connect (on_query_requested);
            query_button.clicked.connect (on_query_requested);
            
            // Real-time validation
            domain_entry.changed.connect (validate_input);
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
        
        private void set_dns_server_internal (string server, string display_name) {
            current_dns_server = server;
            
            // Update the DNS server row subtitle
            var dns_server_row = get_first_child () as Adw.ActionRow;
            while (dns_server_row != null) {
                if (dns_server_row.title == "DNS Server") {
                    dns_server_row.subtitle = display_name;
                    break;
                }
                dns_server_row = dns_server_row.get_next_sibling () as Adw.ActionRow;
            }
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
            set_dns_server_internal (server, server.length > 0 ? @"Custom ($server)" : "System default");
        }
        
        public void focus_domain_entry () {
            domain_entry.grab_focus ();
        }
        
        public void clear_form () {
            domain_entry.text = "";
            record_type_dropdown.selected = 0;
            set_dns_server_internal ("", "System default");
            validate_input ();
        }
        
        public void trigger_query () {
            on_query_requested ();
        }
    }
}
