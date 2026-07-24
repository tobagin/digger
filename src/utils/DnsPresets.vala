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
    public class DnsServer : Object {
        public string name { get; set; }
        public string primary { get; set; }
        public string secondary { get; set; }
        public string description { get; set; }
        public bool supports_dnssec { get; set; }
        public string category { get; set; }
        
        public string get_display_name () {
            return @"$name ($primary)";
        }
        
        public string get_tooltip_text () {
            var tooltip = new StringBuilder ();
            tooltip.append (description);
            if (secondary != null && secondary.length > 0) {
                tooltip.append (@"\nSecondary: $secondary");
            }
            if (supports_dnssec) {
                tooltip.append ("\nSupports DNSSEC");
            }
            return tooltip.str;
        }
    }
    
    public class RecordTypeInfo : Object {
        public string record_type { get; set; }
        public string name { get; set; }
        public string description { get; set; }
        public string icon { get; set; }
        public string color { get; set; }
        public string common_use { get; set; }
        
        public string get_display_name () {
            return @"$record_type - $name";
        }
        
        public string get_tooltip_text () {
            return @"$description\n\nCommon use: $common_use";
        }
    }
    
    public class DnsPresets : Object {
        private static DnsPresets? instance = null;
        private Gee.ArrayList<DnsServer> dns_servers;
        private Gee.HashMap<string, RecordTypeInfo> record_types;
        
        private DnsPresets () {
            dns_servers = new Gee.ArrayList<DnsServer> ();
            record_types = new Gee.HashMap<string, RecordTypeInfo> ();
            load_presets ();
        }
        
        public static DnsPresets get_instance () {
            if (instance == null) {
                instance = new DnsPresets ();
            }
            return instance;
        }
        
        public Gee.ArrayList<DnsServer> get_dns_servers () {
            return dns_servers;
        }

        public RecordTypeInfo? get_record_type_info (string type) {
            return record_types.get (type);
        }
        
        public Gee.Collection<RecordTypeInfo> get_all_record_types () {
            return record_types.values;
        }

        /**
         * Comparator putting common record types (A, AAAA, CNAME, MX, NS, TXT)
         * first, then the rest alphabetically
         */
        public static int compare_record_types (RecordTypeInfo a, RecordTypeInfo b) {
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
        }

        /**
         * All record types sorted for consistent display (common types first)
         */
        public Gee.ArrayList<RecordTypeInfo> get_sorted_record_types () {
            var sorted_types = new Gee.ArrayList<RecordTypeInfo> ();
            sorted_types.add_all (record_types.values);
            sorted_types.sort ((a, b) => compare_record_types (a, b));
            return sorted_types;
        }
        
        private delegate void ElementParser (Json.Object obj);
        private delegate void FallbackLoader ();

        private void load_presets () {
            load_preset_file ("presets/dns-servers.json", "dns_servers", (server_obj) => {
                var server = new DnsServer ();

                server.name = server_obj.get_string_member ("name");
                server.primary = server_obj.get_string_member ("primary");
                server.secondary = server_obj.get_string_member ("secondary");
                server.description = server_obj.get_string_member ("description");
                server.supports_dnssec = server_obj.get_boolean_member ("supports_dnssec");
                server.category = server_obj.get_string_member ("category");

                dns_servers.add (server);
            }, load_default_dns_servers);

            load_preset_file ("presets/record-types.json", "record_types", (type_obj) => {
                var record_type = new RecordTypeInfo ();

                record_type.record_type = type_obj.get_string_member ("type");
                record_type.name = type_obj.get_string_member ("name");
                record_type.description = type_obj.get_string_member ("description");
                record_type.icon = type_obj.get_string_member ("icon");
                record_type.color = type_obj.get_string_member ("color");
                record_type.common_use = type_obj.get_string_member ("common_use");

                record_types.set (record_type.record_type, record_type);
            }, load_default_record_types);
        }

        private void load_preset_file (string relative_path, string array_member,
                                       ElementParser parse_element, FallbackLoader load_defaults) {
            try {
                var file_path = get_data_file_path (relative_path);
                if (!FileUtils.test (file_path, FileTest.EXISTS)) {
                    warning ("Preset file not found: %s", file_path);
                    load_defaults ();
                    return;
                }

                string content;
                FileUtils.get_contents (file_path, out content);

                var parser = new Json.Parser ();
                parser.load_from_data (content);

                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                    warning ("Invalid JSON format in %s", relative_path);
                    load_defaults ();
                    return;
                }

                var elements_array = root.get_object ().get_array_member (array_member);
                if (elements_array != null) {
                    foreach (var element in elements_array.get_elements ()) {
                        parse_element (element.get_object ());
                    }
                }
            } catch (Error e) {
                warning ("Error loading %s: %s", relative_path, e.message);
                load_defaults ();
            }
        }
        
        private string get_data_file_path (string relative_path) {
            // Try different locations for the data files
            string[] possible_paths = {
                Path.build_filename (Environment.get_current_dir (), "data", relative_path),
                Path.build_filename ("/app/share/digger", relative_path),
                Path.build_filename (Environment.get_user_data_dir (), "digger", relative_path),
                Path.build_filename ("/usr/share/digger", relative_path)
            };
            
            foreach (string path in possible_paths) {
                if (FileUtils.test (path, FileTest.EXISTS)) {
                    return path;
                }
            }
            
            // Return the first path as fallback
            return possible_paths[0];
        }
        
        private void load_default_dns_servers () {
            // Fallback DNS servers if JSON file is not available
            var google = new DnsServer ();
            google.name = "Google Public DNS";
            google.primary = "8.8.8.8";
            google.secondary = "8.8.4.4";
            google.description = "Fast and reliable DNS service by Google";
            google.supports_dnssec = true;
            google.category = "public";
            dns_servers.add (google);
            
            var cloudflare = new DnsServer ();
            cloudflare.name = "Cloudflare DNS";
            cloudflare.primary = "1.1.1.1";
            cloudflare.secondary = "1.0.0.1";
            cloudflare.description = "Privacy-focused DNS service by Cloudflare";
            cloudflare.supports_dnssec = true;
            cloudflare.category = "public";
            dns_servers.add (cloudflare);
            
            var quad9 = new DnsServer ();
            quad9.name = "Quad9 DNS";
            quad9.primary = "9.9.9.9";
            quad9.secondary = "149.112.112.112";
            quad9.description = "Security-focused DNS with malware blocking";
            quad9.supports_dnssec = true;
            quad9.category = "security";
            dns_servers.add (quad9);
        }
        
        private void load_default_record_types () {
            // Fallback record types if JSON file is not available
            string[] types = {"A", "AAAA", "CNAME", "MX", "NS", "PTR", "TXT", "SOA", "SRV", "ANY"};
            string[] names = {
                "IPv4 Address", "IPv6 Address", "Canonical Name", "Mail Exchange", "Name Server",
                "Pointer Record", "Text Record", "Start of Authority", "Service Record", "Any Records"
            };
            
            for (int i = 0; i < types.length; i++) {
                var record_type = new RecordTypeInfo ();
                record_type.record_type = types[i];
                record_type.name = names[i];
                record_type.description = "DNS record type";
                record_type.icon = "network-workgroup-symbolic";
                record_type.color = "#3584e4";
                record_type.common_use = "General DNS usage";
                record_types.set (record_type.record_type, record_type);
            }
        }
    }
}
