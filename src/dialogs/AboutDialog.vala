/*
 * Copyright (C) 2024-2026 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

namespace Digger {
    public class AboutDialog : GLib.Object {

        public static void show(Gtk.Window? parent) {
            var developers = new string[] { "Thiago Fernandes", null };
            var designers = new string[] { "Thiago Fernandes", null };
            var artists = new string[] { "Thiago Fernandes", "@oiimrosabel", null };

            string app_name = "Digger";
            string comments = "A modern DNS lookup tool with an intuitive GTK interface";
            if (Config.APP_ID.contains("Devel")) {
                app_name = "Digger (Development)";
                comments = "A modern DNS lookup tool with an intuitive GTK interface (Development Version)";
            }

            var about = new Adw.AboutDialog() {
                application_name = app_name,
                application_icon = Config.APP_ID,
                developer_name = "Thiago Fernandes",
                version = Config.VERSION,
                developers = developers,
                designers = designers,
                artists = artists,
                license_type = Gtk.License.GPL_3_0,
                website = "https://tobagin.github.io/apps/digger/",
                issue_url = "https://github.com/tobagin/Digger/issues",
                comments = comments
            };

        // Load and set release notes from metainfo
        load_release_notes(about);

        // Set copyright
        about.set_copyright("© 2025 Thiago Fernandes");

        // Add acknowledgement section
        var acknowledgements = new string[] {
            "The GNOME Project",
            "The GTK Project Team",
            "GTK Contributors",
            "LibAdwaita Contributors",
            "Vala Programming Language Team",
            "BIND Tools (dig) Team",
            null
        };
        about.add_acknowledgement_section("Special Thanks", acknowledgements);

        // Set translator credits
        about.set_translator_credits("Thiago Fernandes");

        // Add Source link
        about.add_link("Source", "https://github.com/tobagin/Digger");

        if (parent != null && !parent.in_destruction()) {
            about.present(parent);
        }
    }

    private static void load_release_notes(Adw.AboutDialog about) {
        try {
            string[] possible_paths = {
                Path.build_filename("/app/share/metainfo", @"$(Config.APP_ID).metainfo.xml"),
                Path.build_filename("/usr/share/metainfo", @"$(Config.APP_ID).metainfo.xml"),
                Path.build_filename(Environment.get_user_data_dir(), "metainfo", @"$(Config.APP_ID).metainfo.xml")
            };
            
            foreach (string metainfo_path in possible_paths) {
                var file = File.new_for_path(metainfo_path);
                
                if (file.query_exists()) {
                    uint8[] contents;
                    string etag_out;
                    file.load_contents(null, out contents, out etag_out);
                    string xml_content = (string) contents;
                    
                    // Parse the XML to find the release matching Config.VERSION
                    var parser = new Regex("<release version=\"%s\"[^>]*>(.*?)</release>".printf(Regex.escape_string(Config.VERSION)), 
                                           RegexCompileFlags.DOTALL | RegexCompileFlags.MULTILINE);
                    MatchInfo match_info;
                    
                    if (parser.match(xml_content, 0, out match_info)) {
                        string release_section = match_info.fetch(1);
                        
                        // Extract description content
                        var desc_parser = new Regex("<description>(.*?)</description>", 
                                                    RegexCompileFlags.DOTALL | RegexCompileFlags.MULTILINE);
                        MatchInfo desc_match;
                        
                        if (desc_parser.match(release_section, 0, out desc_match)) {
                            string release_notes = desc_match.fetch(1).strip();
                            about.set_release_notes(release_notes);
                            about.set_release_notes_version(Config.VERSION);
                        }
                    }
                    break;
                }
            }
        } catch (Error e) {
            // If we can't load release notes from metainfo, that's okay
            print("Warning: Could not load release notes from metainfo: %s\n", e.message);
        }
    }
    
    }
}