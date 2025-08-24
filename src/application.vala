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
        private bool should_show_release_notes_on_current_run = false;

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

            // Show About dialog with release notes if this is a new version
            if (should_show_release_notes ()) {
                should_show_release_notes_on_current_run = true;
                // Small delay to ensure main window is fully presented
                Timeout.add (100, () => {
                    on_about_action ();
                    should_show_release_notes_on_current_run = false;
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

        private void on_about_action () {
            string[] developers = { "Thiago Fernandes" };
            string[] designers = { "Thiago Fernandes" };
            string[] artists = { "Thiago Fernandes" };
            
            string app_name = "Digger";
            string comments = "A modern DNS lookup tool with an intuitive GTK interface";
            
            if (app_id.contains ("Devel")) {
                app_name = "Digger (Development)";
                comments = "A modern DNS lookup tool with an intuitive GTK interface (Development Version)";
            }

            var about = new Adw.AboutDialog () {
                application_name = app_name,
                application_icon = app_id,
                developer_name = "The Digger Team",
                version = Config.VERSION,
                developers = developers,
                designers = designers,
                artists = artists,
                license_type = Gtk.License.GPL_3_0,
                website = "https://tobagin.github.io/apps/digger/",
                issue_url = "https://github.com/tobagin/Digger/issues",
                //support_url = "https://github.com/tobagin/Digger/discussions",
                comments = comments
            };

            // Load and set release notes from appdata
            try {
                var appdata_path = Path.build_filename (Config.DATADIR, "metainfo", "%s.metainfo.xml".printf (app_id));
                var file = File.new_for_path (appdata_path);
                
                if (file.query_exists ()) {
                    uint8[] contents;
                    file.load_contents (null, out contents, null);
                    string xml_content = (string) contents;
                    
                    // Parse the XML to find the release matching Config.VERSION
                    var parser = new Regex ("<release version=\"%s\"[^>]*>(.*?)</release>".printf (Regex.escape_string (Config.VERSION)), 
                                           RegexCompileFlags.DOTALL | RegexCompileFlags.MULTILINE);
                    MatchInfo match_info;
                    
                    if (parser.match (xml_content, 0, out match_info)) {
                        string release_section = match_info.fetch (1);
                        
                        // Extract description content
                        var desc_parser = new Regex ("<description>(.*?)</description>", 
                                                    RegexCompileFlags.DOTALL | RegexCompileFlags.MULTILINE);
                        MatchInfo desc_match;
                        
                        if (desc_parser.match (release_section, 0, out desc_match)) {
                            string release_notes = desc_match.fetch (1).strip ();
                            about.set_release_notes (release_notes);
                            about.set_release_notes_version (Config.VERSION);
                        }
                    }
                }
            } catch (Error e) {
                // If we can't load release notes from appdata, that's okay
                warning ("Could not load release notes from appdata: %s", e.message);
            }

            // Set copyright
            about.set_copyright ("© 2025 Thiago Fernandes");

            // Add acknowledgement section
            about.add_acknowledgement_section (
                "Special Thanks",
                {
                    "The GNOME Project",
                    "The GTK Project Team",
                    "GTK Contributors",
                    "LibAdwaita Contributors", 
                    "Vala Programming Language Team",
                    "BIND Tools (dig) Team"
                }
            );

            // Add translator credits
            about.set_translator_credits ("Thiago Fernandes");
            
            // Add Source link
            about.add_link ("Source", "https://github.com/tobagin/Digger");
            
            about.present (main_window);
        }

        private void on_preferences_action () {
            var preferences_dialog = new PreferencesDialog (main_window);
            preferences_dialog.present (main_window);
        }

        private void on_shortcuts_action () {
            var shortcuts_dialog = new ShortcutsDialog (main_window);
            shortcuts_dialog.present (main_window);
        }
    }
}
