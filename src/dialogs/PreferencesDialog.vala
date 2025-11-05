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
        private unowned Adw.SpinRow query_history_limit_row;
        
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
        private unowned Adw.SwitchRow compact_results_row;

        [GtkChild]
        private unowned Adw.SwitchRow enable_doh_row;

        [GtkChild]
        private unowned Adw.ComboRow doh_provider_row;

        [GtkChild]
        private unowned Adw.EntryRow custom_doh_row;

        [GtkChild]
        private unowned Adw.SwitchRow enable_dnssec_row;

        [GtkChild]
        private unowned Adw.SwitchRow show_dnssec_details_row;

        [GtkChild]
        private unowned Adw.SwitchRow auto_whois_lookup_row;

        [GtkChild]
        private unowned Adw.SpinRow whois_timeout_row;

        [GtkChild]
        private unowned Adw.SpinRow whois_cache_ttl_row;

        [GtkChild]
        private unowned Adw.ActionRow clear_whois_cache_row;

        private GLib.Settings settings;
        private ThemeManager theme_manager;
        private WhoisService? whois_service = null;
        
        public PreferencesDialog(Gtk.Window parent) {
            Object();
            
            settings = new GLib.Settings(Config.APP_ID);
            
            theme_manager = ThemeManager.get_instance();
            
            setup_color_scheme();
            setup_dns_defaults();
            setup_query_behavior();
            setup_display_options();
            setup_output_settings();
            setup_history_settings();
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
            var record_types = dns_presets.get_all_record_types ();
            
            // Sort by type name for consistent display (same as query form)
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
            // Set up switch row connections
            default_reverse_lookup_row.notify["active"].connect(on_default_reverse_lookup_changed);
            default_trace_path_row.notify["active"].connect(on_default_trace_path_changed);
            default_short_output_row.notify["active"].connect(on_default_short_output_changed);
            auto_clear_form_row.notify["active"].connect(on_auto_clear_form_changed);
            
            // Set up timeout spin row
            query_timeout_row.set_range(5, 60);
            query_timeout_row.notify["value"].connect(on_query_timeout_changed);
        }
        
        private void setup_display_options() {
            // Set up display option switch rows
            show_query_time_row.notify["active"].connect(on_show_query_time_changed);
            show_ttl_prominent_row.notify["active"].connect(on_show_ttl_prominent_changed);
            compact_results_row.notify["active"].connect(on_compact_results_changed);
        }
        
        private void setup_output_settings() {
            // Raw output toggle removed - raw output is available via button in results view
        }
        
        private void setup_history_settings() {
            query_history_limit_row.set_range(10, 1000);
            query_history_limit_row.notify["value"].connect(on_history_limit_changed);
        }
        
        private void load_settings() {
            // Load color scheme
            var color_scheme_str = settings.get_string("color-scheme");
            var color_scheme = ColorScheme.from_string(color_scheme_str);
            switch (color_scheme) {
                case ColorScheme.SYSTEM:
                    color_scheme_row.selected = 0;
                    break;
                case ColorScheme.LIGHT:
                    color_scheme_row.selected = 1;
                    break;
                case ColorScheme.DARK:
                    color_scheme_row.selected = 2;
                    break;
            }
            
            // Load default record type using same dynamic list as setup
            var default_record_type = settings.get_string("default-record-type");
            var presets_instance = DnsPresets.get_instance();
            var record_types = presets_instance.get_all_record_types ();
            
            // Sort by type name for consistent display (same as setup)
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
            
            // Load query behavior settings
            default_reverse_lookup_row.active = settings.get_boolean("default-reverse-lookup");
            default_trace_path_row.active = settings.get_boolean("default-trace-path");
            default_short_output_row.active = settings.get_boolean("default-short-output");
            auto_clear_form_row.active = settings.get_boolean("auto-clear-form");
            query_timeout_row.value = settings.get_int("query-timeout");
            
            // Load display option settings
            show_query_time_row.active = settings.get_boolean("show-query-time");
            show_ttl_prominent_row.active = settings.get_boolean("show-ttl-prominent");
            compact_results_row.active = settings.get_boolean("compact-results");
            
            // Load history settings
            query_history_limit_row.value = settings.get_int("query-history-limit");
        }
        
        private void on_color_scheme_changed() {
            ColorScheme scheme;
            switch (color_scheme_row.selected) {
                case 0:
                    scheme = ColorScheme.SYSTEM;
                    break;
                case 1:
                    scheme = ColorScheme.LIGHT;
                    break;
                case 2:
                    scheme = ColorScheme.DARK;
                    break;
                default:
                    scheme = ColorScheme.SYSTEM;
                    break;
            }
            
            theme_manager.set_color_scheme(scheme);
        }
        
        private void on_default_record_type_changed() {
            // Get dynamic record types using same logic as setup and load
            var dns_presets = DnsPresets.get_instance();
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
        
        private void on_default_reverse_lookup_changed() {
            settings.set_boolean("default-reverse-lookup", default_reverse_lookup_row.active);
        }
        
        private void on_default_trace_path_changed() {
            settings.set_boolean("default-trace-path", default_trace_path_row.active);
        }
        
        private void on_default_short_output_changed() {
            settings.set_boolean("default-short-output", default_short_output_row.active);
        }
        
        private void on_auto_clear_form_changed() {
            settings.set_boolean("auto-clear-form", auto_clear_form_row.active);
        }
        
        private void on_query_timeout_changed() {
            settings.set_int("query-timeout", (int)query_timeout_row.value);
        }
        
        private void on_show_query_time_changed() {
            settings.set_boolean("show-query-time", show_query_time_row.active);
        }
        
        private void on_show_ttl_prominent_changed() {
            settings.set_boolean("show-ttl-prominent", show_ttl_prominent_row.active);
        }
        
        private void on_compact_results_changed() {
            settings.set_boolean("compact-results", compact_results_row.active);
        }
        
        private void on_history_limit_changed() {
            settings.set_int("query-history-limit", (int)query_history_limit_row.value);
        }

        private void setup_advanced_settings() {
            if (enable_doh_row == null || enable_dnssec_row == null) {
                return;
            }

            var provider_list = new Gtk.StringList(null);
            provider_list.append("Cloudflare (1.1.1.1)");
            provider_list.append("Google (8.8.8.8)");
            provider_list.append("Quad9 (9.9.9.9)");
            provider_list.append("Custom");
            doh_provider_row.model = provider_list;

            enable_doh_row.active = settings.get_boolean("enable-doh");
            enable_dnssec_row.active = settings.get_boolean("enable-dnssec");
            show_dnssec_details_row.active = settings.get_boolean("show-dnssec-details");
            custom_doh_row.text = settings.get_string("custom-doh-endpoint");

            enable_doh_row.notify["active"].connect(() => {
                settings.set_boolean("enable-doh", enable_doh_row.active);
                doh_provider_row.sensitive = enable_doh_row.active;
            });

            enable_dnssec_row.notify["active"].connect(() => {
                settings.set_boolean("enable-dnssec", enable_dnssec_row.active);
            });

            show_dnssec_details_row.notify["active"].connect(() => {
                settings.set_boolean("show-dnssec-details", show_dnssec_details_row.active);
            });

            custom_doh_row.notify["text"].connect(() => {
                string endpoint = custom_doh_row.text.strip ();

                // SEC-006: Validate HTTPS-only for DoH endpoints
                if (endpoint.length > 0) {
                    // Auto-prepend https:// if no protocol specified
                    if (!endpoint.has_prefix ("http://") && !endpoint.has_prefix ("https://")) {
                        endpoint = "https://" + endpoint;
                        custom_doh_row.text = endpoint;
                    }

                    // Reject HTTP URLs with error indication
                    if (endpoint.has_prefix ("http://") && !endpoint.has_prefix ("https://")) {
                        custom_doh_row.add_css_class ("error");
                        custom_doh_row.tooltip_text = "DoH endpoints must use HTTPS for security";
                        return;
                    } else {
                        custom_doh_row.remove_css_class ("error");
                        custom_doh_row.tooltip_text = "Enter a custom DoH endpoint (HTTPS required)";
                    }
                }

                settings.set_string("custom-doh-endpoint", endpoint);
            });

            doh_provider_row.notify["selected"].connect(() => {
                custom_doh_row.visible = (doh_provider_row.selected == 3);
                var provider = "";
                switch (doh_provider_row.selected) {
                    case 0: provider = "cloudflare"; break;
                    case 1: provider = "google"; break;
                    case 2: provider = "quad9"; break;
                    case 3: provider = "custom"; break;
                }
                settings.set_string("doh-provider", provider);
            });

            var current_provider = settings.get_string("doh-provider");
            switch (current_provider) {
                case "cloudflare": doh_provider_row.selected = 0; break;
                case "google": doh_provider_row.selected = 1; break;
                case "quad9": doh_provider_row.selected = 2; break;
                case "custom": doh_provider_row.selected = 3; break;
                default: doh_provider_row.selected = 0; break;
            }

            doh_provider_row.sensitive = enable_doh_row.active;
            custom_doh_row.visible = (doh_provider_row.selected == 3);

            // WHOIS settings
            if (auto_whois_lookup_row != null && whois_timeout_row != null && whois_cache_ttl_row != null) {
                auto_whois_lookup_row.active = settings.get_boolean("auto-whois-lookup");
                whois_timeout_row.value = settings.get_int("whois-timeout");
                // Convert seconds to hours for display
                whois_cache_ttl_row.value = settings.get_int("whois-cache-ttl") / 3600.0;

                // Configure spin rows
                whois_timeout_row.adjustment = new Gtk.Adjustment (30, 5, 120, 5, 10, 0);
                whois_cache_ttl_row.adjustment = new Gtk.Adjustment (24, 1, 168, 1, 12, 0);

                auto_whois_lookup_row.notify["active"].connect(() => {
                    settings.set_boolean("auto-whois-lookup", auto_whois_lookup_row.active);
                });

                whois_timeout_row.notify["value"].connect(() => {
                    settings.set_int("whois-timeout", (int)whois_timeout_row.value);
                });

                whois_cache_ttl_row.notify["value"].connect(() => {
                    // Convert hours back to seconds
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

                    // Find parent window to show toast
                    var parent = this.get_root ();
                    if (parent is Adw.ApplicationWindow) {
                        var window = (Adw.ApplicationWindow) parent;
                        // Try to find toast overlay
                        var toast = new Adw.Toast ("WHOIS cache cleared") {
                            timeout = 2
                        };

                        // Show message
                        message ("WHOIS cache cleared successfully");
                    }
                }
            });

            dialog.present (this);
        }
    }
}