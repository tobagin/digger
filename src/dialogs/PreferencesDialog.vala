/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger {
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/preferences-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/preferences-dialog.ui")]
#endif
    public class PreferencesDialog : Adw.PreferencesDialog {
        [GtkChild]
        private unowned Adw.ComboRow color_scheme_row;
        
        [GtkChild]
        private unowned Adw.ComboRow default_record_type_row;
        
        [GtkChild]
        private unowned Adw.ComboRow default_dns_server_row;

        [GtkChild]
        private unowned Adw.SwitchRow default_reverse_lookup_row;
        
        [GtkChild]
        private unowned Adw.SwitchRow default_trace_path_row;
        
        [GtkChild]
        private unowned Adw.SwitchRow default_short_output_row;
        
        [GtkChild]
        private unowned Adw.SwitchRow auto_clear_form_row;
        
        [GtkChild]
        private unowned Adw.SpinRow query_timeout_row;
        
        [GtkChild]
        private unowned Adw.SwitchRow show_query_time_row;
        
        [GtkChild]
        private unowned Adw.SwitchRow show_ttl_prominent_row;

        [GtkChild]
        private unowned Adw.SwitchRow enable_dnssec_row;

        [GtkChild]
        private unowned Adw.SwitchRow auto_whois_lookup_row;

        [GtkChild]
        private unowned Adw.SpinRow whois_timeout_row;

        [GtkChild]
        private unowned Adw.SpinRow whois_cache_ttl_row;

        [GtkChild]
        private unowned Adw.ActionRow clear_whois_cache_row;

        private GLib.Settings settings;
        private WhoisService? whois_service = null;

        public PreferencesDialog(Gtk.Window parent) {
            Object();

            settings = new GLib.Settings(Config.APP_ID);

            setup_color_scheme();
            setup_dns_defaults();
            setup_query_behavior();
            setup_display_options();
            setup_advanced_settings();

            load_settings();
        }
        
        private void setup_color_scheme() {
            var string_list = new Gtk.StringList(null);
            string_list.append("Follow System");
            string_list.append("Light");
            string_list.append("Dark");
            
            color_scheme_row.model = string_list;
            color_scheme_row.notify["selected"].connect(on_color_scheme_changed);
        }
        
        private void setup_dns_defaults() {
            // Setup record type dropdown using same source as query form
            var string_list = new Gtk.StringList(null);
            var dns_presets = DnsPresets.get_instance();

            foreach (var record_type in dns_presets.get_sorted_record_types ()) {
                string_list.append(record_type.record_type);
            }
            
            default_record_type_row.model = string_list;
            default_record_type_row.notify["selected"].connect(on_default_record_type_changed);
            
            // Setup DNS server dropdown
            var dns_string_list = new Gtk.StringList(null);
            dns_string_list.append("System Default");
            
            // Add DNS servers from presets (reuse existing dns_presets)
            var dns_servers = dns_presets.get_dns_servers();
            foreach (var server in dns_servers) {
                dns_string_list.append(server.get_display_name());
            }
            
            default_dns_server_row.model = dns_string_list;
            default_dns_server_row.notify["selected"].connect(on_default_dns_server_changed);
        }
        
        private void setup_query_behavior() {
            settings.bind("default-reverse-lookup", default_reverse_lookup_row, "active", SettingsBindFlags.DEFAULT);
            settings.bind("default-trace-path", default_trace_path_row, "active", SettingsBindFlags.DEFAULT);
            settings.bind("default-short-output", default_short_output_row, "active", SettingsBindFlags.DEFAULT);
            settings.bind("auto-clear-form", auto_clear_form_row, "active", SettingsBindFlags.DEFAULT);

            query_timeout_row.set_range(5, 60);
            settings.bind("query-timeout", query_timeout_row, "value", SettingsBindFlags.DEFAULT);
        }

        private void setup_display_options() {
            settings.bind("show-query-time", show_query_time_row, "active", SettingsBindFlags.DEFAULT);
            settings.bind("show-ttl-prominent", show_ttl_prominent_row, "active", SettingsBindFlags.DEFAULT);
        }

        private const string[] COLOR_SCHEMES = { "system", "light", "dark" };

        private void load_settings() {
            var color_scheme_str = settings.get_string("color-scheme");
            for (int i = 0; i < COLOR_SCHEMES.length; i++) {
                if (COLOR_SCHEMES[i] == color_scheme_str) {
                    color_scheme_row.selected = i;
                    break;
                }
            }


            // Load default record type using same dynamic list as setup
            var default_record_type = settings.get_string("default-record-type");
            var presets_instance = DnsPresets.get_instance();
            var sorted_types = presets_instance.get_sorted_record_types ();

            for (int i = 0; i < sorted_types.size; i++) {
                if (sorted_types.get(i).record_type == default_record_type) {
                    default_record_type_row.selected = i;
                    break;
                }
            }
            
            // Load default DNS server
            var default_dns_server = settings.get_string("default-dns-server");
            int dns_server_index = 0; // Default to System Default
            
            if (default_dns_server != "") {
                var dns_servers = presets_instance.get_dns_servers();
                for (int i = 0; i < dns_servers.size; i++) {
                    var server = dns_servers.get(i);
                    if (server.primary == default_dns_server || server.name == default_dns_server) {
                        dns_server_index = i + 1; // +1 because System Default is at index 0
                        break;
                    }
                }
            }
            default_dns_server_row.selected = dns_server_index;
        }
        
        private void on_color_scheme_changed() {
            var scheme = COLOR_SCHEMES[uint.min (color_scheme_row.selected, COLOR_SCHEMES.length - 1)];
            UiUtils.apply_color_scheme (scheme);
            settings.set_string ("color-scheme", scheme);
        }
        
        private void on_default_record_type_changed() {
            // Get dynamic record types using same logic as setup and load
            var dns_presets = DnsPresets.get_instance();
            var sorted_types = dns_presets.get_sorted_record_types ();

            if (default_record_type_row.selected < sorted_types.size) {
                var selected_type = sorted_types.get((int)default_record_type_row.selected).record_type;
                settings.set_string("default-record-type", selected_type);
            }
        }
        
        
        private void on_default_dns_server_changed() {
            if (default_dns_server_row.selected == 0) {
                // System Default selected
                settings.set_string("default-dns-server", "");
            } else {
                // Get the selected DNS server
                var dns_presets = DnsPresets.get_instance();
                var dns_servers = dns_presets.get_dns_servers();
                int server_index = (int)default_dns_server_row.selected - 1; // -1 because System Default is at index 0
                
                if (server_index >= 0 && server_index < dns_servers.size) {
                    var server = dns_servers.get(server_index);
                    settings.set_string("default-dns-server", server.primary);
                }
            }
        }
        
        private void setup_advanced_settings() {
            if (enable_dnssec_row == null) {
                return;
            }

            settings.bind("enable-dnssec", enable_dnssec_row, "active", SettingsBindFlags.DEFAULT);

            // WHOIS settings
            if (auto_whois_lookup_row != null && whois_timeout_row != null && whois_cache_ttl_row != null) {
                // Configure spin rows before binding/loading values
                whois_timeout_row.adjustment = new Gtk.Adjustment (30, 5, 120, 5, 10, 0);
                whois_cache_ttl_row.adjustment = new Gtk.Adjustment (24, 1, 168, 1, 12, 0);

                settings.bind("auto-whois-lookup", auto_whois_lookup_row, "active", SettingsBindFlags.DEFAULT);
                settings.bind("whois-timeout", whois_timeout_row, "value", SettingsBindFlags.DEFAULT);

                // whois-cache-ttl is stored in seconds but displayed in hours,
                // so it needs a manual mapping instead of settings.bind
                whois_cache_ttl_row.value = settings.get_int("whois-cache-ttl") / 3600.0;
                whois_cache_ttl_row.notify["value"].connect(() => {
                    settings.set_int("whois-cache-ttl", (int)(whois_cache_ttl_row.value * 3600));
                });

                if (clear_whois_cache_row != null) {
                    clear_whois_cache_row.activated.connect(() => {
                        on_clear_whois_cache();
                    });
                }
            }
        }

        private void on_clear_whois_cache() {
            if (whois_service == null) {
                whois_service = new WhoisService ();
            }

            var dialog = new Adw.AlertDialog (
                "Clear WHOIS Cache?",
                "This will remove all cached WHOIS data. WHOIS lookups will fetch fresh data on next query."
            );

            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("clear", "Clear Cache");
            dialog.set_response_appearance ("clear", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response ("cancel");
            dialog.set_close_response ("cancel");

            dialog.response.connect ((response) => {
                if (response == "clear") {
                    whois_service.clear_cache ();
                    message ("WHOIS cache cleared successfully");
                }
            });

            dialog.present (this);
        }
    }
}