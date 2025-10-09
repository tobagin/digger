/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024 tobagin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

// External function declarations for GResource
extern GLib.Resource digger_get_resource ();

namespace Digger {
    public class Application : Adw.Application {
        private Window? main_window = null;
        private QueryHistory query_history;
        private string app_id;

        public Application () {
            // Detect if we're running as development version by checking data files
            string detected_app_id = detect_app_id ();
            
            Object (
                application_id: detected_app_id,
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
            
            app_id = detected_app_id;
        }
        
        private static string detect_app_id () {
            // Check if development desktop file exists
            string devel_desktop = Path.build_filename (Environment.get_user_data_dir (), 
                                                        "applications", 
                                                        "io.github.tobagin.digger.Devel.desktop");
            if (FileUtils.test (devel_desktop, FileTest.EXISTS)) {
                return "io.github.tobagin.digger.Devel";
            }
            
            // Check system directories for development version
            string[] system_dirs = {"/app/share", "/usr/share", "/usr/local/share"};
            foreach (string dir in system_dirs) {
                string devel_file = Path.build_filename (dir, "applications", "io.github.tobagin.digger.Devel.desktop");
                if (FileUtils.test (devel_file, FileTest.EXISTS)) {
                    return "io.github.tobagin.digger.Devel";
                }
            }
            
            return Config.APP_ID;
        }

        construct {
            // Register resources
            register_resources ();
            
            ActionEntry[] action_entries = {
                { "about", on_about_action },
                { "preferences", on_preferences_action },
                { "shortcuts", on_shortcuts_action },
                { "quit", quit }
            };
            add_action_entries (action_entries, this);

            string[] quit_accels = {"<primary>q"};
            set_accels_for_action ("app.quit", quit_accels);
            string[] new_query_accels = {"<primary>l"};
            set_accels_for_action ("win.new-query", new_query_accels);
            string[] repeat_query_accels = {"<primary>r"};
            set_accels_for_action ("win.repeat-query", repeat_query_accels);
            string[] clear_results_accels = {"Escape"};
            set_accels_for_action ("win.clear-results", clear_results_accels);
            string[] shortcuts_accels = {"<primary>question"};
            set_accels_for_action ("app.shortcuts", shortcuts_accels);
            string[] about_accels = {"F1"};
            set_accels_for_action ("app.about", about_accels);
            string[] preferences_accels = {"<primary>comma"};
            set_accels_for_action ("app.preferences", preferences_accels);
            string[] batch_lookup_accels = {"<primary>b"};
            set_accels_for_action ("win.batch-lookup", batch_lookup_accels);
            string[] compare_servers_accels = {"<primary>m"};
            set_accels_for_action ("win.compare-servers", compare_servers_accels);
        }
        
        private void register_resources () {
            var resource = digger_get_resource ();
            GLib.resources_register (resource);
        }

        public override void activate () {
            base.activate ();

            if (main_window == null) {
                query_history = new QueryHistory ();
                main_window = new Window (this, query_history);
            }

            main_window.present ();

            // Show release notes if this is a new version
            if (should_show_release_notes ()) {
                // Small delay to ensure main window is fully presented
                Timeout.add (500, () => {
                    show_about_with_release_notes ();
                    return false;
                });
            }
        }
        
        private bool should_show_release_notes () {
            var settings = new Settings (app_id);
            string last_version = settings.get_string ("last-version-shown");
            string current_version = Config.VERSION;

            // Show if this is the first run (empty last version) or version has changed
            if (last_version == "" || last_version != current_version) {
                settings.set_string ("last-version-shown", current_version);
                return true;
            }

            return false;
        }

        private void show_about_with_release_notes () {
            AboutDialog.show_with_release_notes (main_window);
        }

        private void on_about_action () {
            AboutDialog.show (main_window);
        }

        private void on_preferences_action () {
            var preferences_dialog = new PreferencesDialog (main_window);
            preferences_dialog.present (main_window);
        }

        private void on_shortcuts_action () {
            ShortcutsDialog.present (main_window);
        }
    }
}
