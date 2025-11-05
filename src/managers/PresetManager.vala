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
    public class QueryPreset : Object {
        public string name { get; set; }
        public string description { get; set; }
        public RecordType record_type { get; set; }
        public string? dns_server { get; set; default = null; }
        public bool reverse_lookup { get; set; default = false; }
        public bool trace_path { get; set; default = false; }
        public bool dnssec { get; set; default = false; }
        public bool short_output { get; set; default = false; }
        public string? icon { get; set; default = null; }
        public bool is_system_preset { get; set; default = false; }

        public QueryPreset (string name, string description, RecordType record_type) {
            this.name = name;
            this.description = description;
            this.record_type = record_type;
        }

        public QueryPreset.from_json (Json.Object obj) {
            this.name = obj.get_string_member ("name");
            this.description = obj.has_member ("description") ? obj.get_string_member ("description") : "";
            this.record_type = RecordType.from_string (
                obj.has_member ("recordType") ? obj.get_string_member ("recordType") : "A"
            );
            this.dns_server = obj.has_member ("dnsServer") && !obj.get_null_member ("dnsServer")
                ? obj.get_string_member ("dnsServer") : null;
            this.reverse_lookup = obj.has_member ("reverseLookup") ? obj.get_boolean_member ("reverseLookup") : false;
            this.trace_path = obj.has_member ("tracePath") ? obj.get_boolean_member ("tracePath") : false;
            this.dnssec = obj.has_member ("dnssec") ? obj.get_boolean_member ("dnssec") : false;
            this.short_output = obj.has_member ("shortOutput") ? obj.get_boolean_member ("shortOutput") : false;
            this.icon = obj.has_member ("icon") ? obj.get_string_member ("icon") : null;
            this.is_system_preset = obj.has_member ("isSystemPreset") ? obj.get_boolean_member ("isSystemPreset") : false;
        }

        public Json.Object to_json () {
            var obj = new Json.Object ();
            obj.set_string_member ("name", name);
            obj.set_string_member ("description", description);
            obj.set_string_member ("recordType", record_type.to_string ());

            if (dns_server != null && dns_server.length > 0) {
                obj.set_string_member ("dnsServer", dns_server);
            } else {
                obj.set_null_member ("dnsServer");
            }

            obj.set_boolean_member ("reverseLookup", reverse_lookup);
            obj.set_boolean_member ("tracePath", trace_path);
            obj.set_boolean_member ("dnssec", dnssec);
            obj.set_boolean_member ("shortOutput", short_output);

            if (icon != null && icon.length > 0) {
                obj.set_string_member ("icon", icon);
            }

            obj.set_boolean_member ("isSystemPreset", is_system_preset);
            return obj;
        }

        public string get_display_name () {
            return name;
        }

        public string get_summary () {
            var parts = new Gee.ArrayList<string> ();
            parts.add (record_type.to_string ());

            if (dnssec) {
                parts.add ("DNSSEC");
            }
            if (trace_path) {
                parts.add ("Trace");
            }
            if (reverse_lookup) {
                parts.add ("Reverse");
            }
            if (dns_server != null && dns_server.length > 0) {
                parts.add (@"Server: $dns_server");
            }

            return string.joinv (", ", parts.to_array ());
        }
    }

    public class PresetManager : Object {
        private static PresetManager? instance = null;
        private Gee.ArrayList<QueryPreset> system_presets;
        private Gee.ArrayList<QueryPreset> user_presets;
        private GLib.Settings settings;

        public signal void presets_updated ();
        public signal void error_occurred (string error_message);

        public static PresetManager get_instance () {
            if (instance == null) {
                instance = new PresetManager ();
            }
            return instance;
        }

        private PresetManager () {
            system_presets = new Gee.ArrayList<QueryPreset> ();
            user_presets = new Gee.ArrayList<QueryPreset> ();
            settings = new GLib.Settings (Config.APP_ID);

            initialize_default_presets ();
            load_user_presets ();
        }

        private void initialize_default_presets () {
            // 1. Check Mail Servers - MX records
            var mail_preset = new QueryPreset (
                "Check Mail Servers",
                "Query MX records to verify mail server configuration",
                RecordType.MX
            );
            mail_preset.icon = "mail-send-symbolic";
            mail_preset.is_system_preset = true;
            system_presets.add (mail_preset);

            // 2. Verify DNSSEC - DNSKEY with DNSSEC validation
            var dnssec_preset = new QueryPreset (
                "Verify DNSSEC",
                "Check DNSKEY and DS records with validation",
                RecordType.DNSKEY
            );
            dnssec_preset.dnssec = true;
            dnssec_preset.icon = "security-high-symbolic";
            dnssec_preset.is_system_preset = true;
            system_presets.add (dnssec_preset);

            // 3. Find Nameservers - NS records
            var ns_preset = new QueryPreset (
                "Find Nameservers",
                "Query NS records to find authoritative nameservers",
                RecordType.NS
            );
            ns_preset.icon = "network-server-symbolic";
            ns_preset.is_system_preset = true;
            system_presets.add (ns_preset);

            // 4. Check SPF Record - TXT records
            var spf_preset = new QueryPreset (
                "Check SPF Record",
                "Query TXT records to check SPF/DMARC email policies",
                RecordType.TXT
            );
            spf_preset.icon = "mail-inbox-symbolic";
            spf_preset.is_system_preset = true;
            system_presets.add (spf_preset);

            // 5. Reverse IP Lookup - PTR records
            var ptr_preset = new QueryPreset (
                "Reverse IP Lookup",
                "Perform reverse DNS lookup (PTR record) for an IP address",
                RecordType.PTR
            );
            ptr_preset.reverse_lookup = true;
            ptr_preset.icon = "view-refresh-symbolic";
            ptr_preset.is_system_preset = true;
            system_presets.add (ptr_preset);

            // 6. Trace Resolution Path - A record with trace
            var trace_preset = new QueryPreset (
                "Trace Resolution Path",
                "Show full DNS resolution path from root servers",
                RecordType.A
            );
            trace_preset.trace_path = true;
            trace_preset.icon = "route-symbolic";
            trace_preset.is_system_preset = true;
            system_presets.add (trace_preset);

            // 7. All Records - ANY record type (with note about deprecation)
            var any_preset = new QueryPreset (
                "All Records",
                "Query ANY record type (note: deprecated by many DNS servers)",
                RecordType.ANY
            );
            any_preset.icon = "view-list-symbolic";
            any_preset.is_system_preset = true;
            system_presets.add (any_preset);
        }

        private void load_user_presets () {
            try {
                var presets_json = settings.get_string ("user-presets");
                if (presets_json.length == 0) {
                    return;
                }

                var parser = new Json.Parser ();
                parser.load_from_data (presets_json);

                var root = parser.get_root ();
                if (root != null && root.get_node_type () == Json.NodeType.ARRAY) {
                    var array = root.get_array ();
                    user_presets.clear ();

                    array.foreach_element ((arr, index, node) => {
                        if (node.get_node_type () == Json.NodeType.OBJECT) {
                            try {
                                var preset = new QueryPreset.from_json (node.get_object ());
                                user_presets.add (preset);
                            } catch (Error e) {
                                warning ("Failed to parse preset at index %u: %s", index, e.message);
                            }
                        }
                    });
                }
            } catch (Error e) {
                critical ("Failed to load user presets: %s", e.message);
                error_occurred ("Failed to load custom presets");
            }
        }

        private void save_user_presets () {
            try {
                var generator = new Json.Generator ();
                var root = new Json.Node (Json.NodeType.ARRAY);
                var array = new Json.Array ();

                foreach (var preset in user_presets) {
                    var node = new Json.Node (Json.NodeType.OBJECT);
                    node.set_object (preset.to_json ());
                    array.add_element (node);
                }

                root.set_array (array);
                generator.set_root (root);
                generator.set_pretty (false);

                string json_data = generator.to_data (null);
                settings.set_string ("user-presets", json_data);
            } catch (Error e) {
                critical ("Failed to save user presets: %s", e.message);
                error_occurred ("Failed to save custom presets");
            }
        }

        public Gee.ArrayList<QueryPreset> get_all_presets () {
            var all_presets = new Gee.ArrayList<QueryPreset> ();
            all_presets.add_all (system_presets);
            all_presets.add_all (user_presets);
            return all_presets;
        }

        public Gee.ArrayList<QueryPreset> get_system_presets () {
            return system_presets;
        }

        public Gee.ArrayList<QueryPreset> get_user_presets () {
            return user_presets;
        }

        public QueryPreset? get_preset_by_name (string name) {
            foreach (var preset in system_presets) {
                if (preset.name == name) {
                    return preset;
                }
            }
            foreach (var preset in user_presets) {
                if (preset.name == name) {
                    return preset;
                }
            }
            return null;
        }

        public bool add_preset (QueryPreset preset) {
            // Validate preset name uniqueness
            if (get_preset_by_name (preset.name) != null) {
                error_occurred (@"A preset named '$(preset.name)' already exists");
                return false;
            }

            // Validate preset name is not empty
            if (preset.name.strip ().length == 0) {
                error_occurred ("Preset name cannot be empty");
                return false;
            }

            user_presets.add (preset);
            save_user_presets ();
            presets_updated ();
            return true;
        }

        public bool update_preset (QueryPreset preset, string? new_name = null) {
            // Find the preset in user presets (can't update system presets)
            int index = -1;
            for (int i = 0; i < user_presets.size; i++) {
                if (user_presets.get (i) == preset) {
                    index = i;
                    break;
                }
            }

            if (index < 0) {
                error_occurred ("Preset not found or is a system preset");
                return false;
            }

            // If renaming, check for uniqueness
            if (new_name != null && new_name != preset.name) {
                if (get_preset_by_name (new_name) != null) {
                    error_occurred (@"A preset named '$new_name' already exists");
                    return false;
                }
                preset.name = new_name;
            }

            save_user_presets ();
            presets_updated ();
            return true;
        }

        public bool delete_preset (QueryPreset preset) {
            // Cannot delete system presets
            if (preset.is_system_preset) {
                error_occurred ("Cannot delete system presets");
                return false;
            }

            bool removed = user_presets.remove (preset);
            if (removed) {
                save_user_presets ();
                presets_updated ();
            }
            return removed;
        }

        public void reorder_presets (int old_index, int new_index) {
            if (old_index < 0 || old_index >= user_presets.size ||
                new_index < 0 || new_index >= user_presets.size) {
                return;
            }

            var preset = user_presets.get (old_index);
            user_presets.remove_at (old_index);
            user_presets.insert (new_index, preset);

            save_user_presets ();
            presets_updated ();
        }

        public bool validate_preset (QueryPreset preset) {
            if (preset.name.strip ().length == 0) {
                return false;
            }
            // Additional validation can be added here
            return true;
        }

        public void reset_to_defaults () {
            user_presets.clear ();
            save_user_presets ();
            presets_updated ();
        }
    }
}
