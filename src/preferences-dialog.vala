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
        private unowned Adw.SpinRow query_history_limit_row;
        
        private GLib.Settings settings;
        private ThemeManager theme_manager;
        
        public PreferencesDialog(Gtk.Window parent) {
            Object();
            
            settings = new GLib.Settings(Config.APP_ID);
            
            theme_manager = ThemeManager.get_instance();
            
            setup_color_scheme();
            setup_dns_defaults();
            setup_output_settings();
            setup_history_settings();
            
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
            var string_list = new Gtk.StringList(null);
            string_list.append("A");
            string_list.append("AAAA");
            string_list.append("CNAME");
            string_list.append("MX");
            string_list.append("NS");
            string_list.append("PTR");
            string_list.append("SOA");
            string_list.append("TXT");
            string_list.append("SRV");
            string_list.append("CAA");
            
            default_record_type_row.model = string_list;
            default_record_type_row.notify["selected"].connect(on_default_record_type_changed);
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
            
            // Load default record type
            var default_record_type = settings.get_string("default-record-type");
            var record_types = new string[] {"A", "AAAA", "CNAME", "MX", "NS", "PTR", "SOA", "TXT", "SRV", "CAA"};
            for (int i = 0; i < record_types.length; i++) {
                if (record_types[i] == default_record_type) {
                    default_record_type_row.selected = i;
                    break;
                }
            }
            
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
            var record_types = new string[] {"A", "AAAA", "CNAME", "MX", "NS", "PTR", "SOA", "TXT", "SRV", "CAA"};
            if (default_record_type_row.selected < record_types.length) {
                var selected_type = record_types[default_record_type_row.selected];
                settings.set_string("default-record-type", selected_type);
            }
        }
        
        
        private void on_history_limit_changed() {
            settings.set_int("query-history-limit", (int)query_history_limit_row.value);
        }
    }
}