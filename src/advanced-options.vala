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
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/advanced-options.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/advanced-options.ui")]
#endif
    public class AdvancedOptions : Adw.ExpanderRow {
        [GtkChild] private unowned Gtk.Switch reverse_lookup_switch;
        [GtkChild] private unowned Gtk.Switch trace_path_switch;
        [GtkChild] private unowned Gtk.Switch short_output_switch;
        [GtkChild] private unowned Adw.EntryRow dns_server_entry;

        public bool reverse_lookup {
            get { return reverse_lookup_switch.active; }
            set { reverse_lookup_switch.active = value; }
        }

        public bool trace_path {
            get { return trace_path_switch.active; }
            set { trace_path_switch.active = value; }
        }

        public bool short_output {
            get { return short_output_switch.active; }
            set { short_output_switch.active = value; }
        }

        public string dns_server {
            get { 
                string server = dns_server_entry.text.strip ();
                return server.length > 0 ? server : "";
            }
            set { dns_server_entry.text = value ?? ""; }
        }

        construct {
            // Connect signals for real-time validation
            dns_server_entry.changed.connect (validate_dns_server);
            reverse_lookup_switch.notify["active"].connect (on_reverse_lookup_toggled);
        }

        private void validate_dns_server () {
            string server = dns_server_entry.text.strip ();
            
            if (server.length == 0) {
                dns_server_entry.remove_css_class ("error");
                return;
            }
            
            if (is_valid_dns_server (server)) {
                dns_server_entry.remove_css_class ("error");
            } else {
                dns_server_entry.add_css_class ("error");
            }
        }

        private void on_reverse_lookup_toggled () {
            // When reverse lookup is enabled, the domain field should expect an IP
            // This is handled in the main window
        }

        private bool is_valid_dns_server (string server) {
            // Check if it's a valid IP address (IPv4 or IPv6)
            if (is_valid_ipv4 (server) || is_valid_ipv6 (server)) {
                return true;
            }
            
            // Check if it's a valid hostname
            if (is_valid_hostname (server)) {
                return true;
            }
            
            return false;
        }

        private bool is_valid_ipv4 (string ip) {
            string[] parts = ip.split (".");
            if (parts.length != 4) {
                return false;
            }
            
            foreach (string part in parts) {
                int num = int.parse (part);
                if (num < 0 || num > 255) {
                    return false;
                }
            }
            
            return true;
        }

        private bool is_valid_ipv6 (string ip) {
            // Basic IPv6 validation - could be more comprehensive
            return ip.contains (":") && ip.length >= 3 && ip.length <= 45;
        }

        private bool is_valid_hostname (string hostname) {
            if (hostname.length == 0 || hostname.length > 253) {
                return false;
            }
            
            // Basic hostname validation
            try {
                return Regex.match_simple ("^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$", hostname) ||
                       Regex.match_simple ("^[a-zA-Z0-9]$", hostname);
            } catch (RegexError e) {
                return false;
            }
        }

        public void reset_to_defaults () {
            reverse_lookup_switch.active = false;
            trace_path_switch.active = false;
            short_output_switch.active = false;
            dns_server_entry.text = "";
        }

        public void apply_from_query_result (QueryResult result) {
            reverse_lookup = result.reverse_lookup;
            trace_path = result.trace_path;
            short_output = result.short_output;
            // Note: DNS server info is not stored in QueryResult currently
        }
    }
}
