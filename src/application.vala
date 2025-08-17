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
                { "quit", quit }
            };
            add_action_entries (action_entries, this);

            set_accels_for_action ("app.quit", {"<primary>q"});
            set_accels_for_action ("win.new-query", {"<primary>l"});
            set_accels_for_action ("win.repeat-query", {"<primary>r"});
            set_accels_for_action ("win.clear-results", {"Escape"});
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
        }

        private void on_about_action () {
            string[] developers = { "tobagin https://github.com/tobagin" };
            
            string app_name = "Digger";
            string comments = "A modern DNS lookup tool with an intuitive GTK interface";
            
            if (app_id.contains ("Devel")) {
                app_name = "Digger (Development)";
                comments = "A modern DNS lookup tool with an intuitive GTK interface (Development Version)";
            }
            
            var about = new Adw.AboutDialog () {
                application_name = app_name,
                application_icon = app_id,
                developer_name = "tobagin",
                version = Config.VERSION,
                developers = developers,
                copyright = "© 2024 tobagin",
                license_type = Gtk.License.GPL_3_0,
                website = "https://github.com/tobagin/digger-vala",
                issue_url = "https://github.com/tobagin/digger-vala/issues",
                comments = comments
            };

            about.present (main_window);
        }

        private void on_preferences_action () {
            // TODO: Implement preferences dialog
            message ("Preferences dialog not yet implemented");
        }
    }
}
