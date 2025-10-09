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
        
        public Gee.ArrayList<DnsServer> get_dns_servers_by_category (string category) {
            var filtered = new Gee.ArrayList<DnsServer> ();
            foreach (var server in dns_servers) {
                if (server.category == category) {
                    filtered.add (server);
                }
            }
            return filtered;
        }
        
        public RecordTypeInfo? get_record_type_info (string type) {
            return record_types.get (type);
        }
        
        public Gee.Collection<RecordTypeInfo> get_all_record_types () {
            return record_types.values;
        }
        
        private void load_presets () {
            load_dns_servers ();
            load_record_types ();
        }
        
        private void load_dns_servers () {
            try {
                var file_path = get_data_file_path ("presets/dns-servers.json");
                if (!FileUtils.test (file_path, FileTest.EXISTS)) {
                    warning ("DNS servers preset file not found: %s", file_path);
                    load_default_dns_servers ();
                    return;
                }
                
                string content;
                FileUtils.get_contents (file_path, out content);
                
                var parser = new Json.Parser ();
                parser.load_from_data (content);
                
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                    warning ("Invalid JSON format in dns-servers.json");
                    load_default_dns_servers ();
                    return;
                }
                
                var root_obj = root.get_object ();
                var servers_array = root_obj.get_array_member ("dns_servers");
                
                if (servers_array != null) {
                    servers_array.foreach_element ((array, index, element) => {
                        var server_obj = element.get_object ();
                        var server = new DnsServer ();
                        
                        server.name = server_obj.get_string_member ("name");
                        server.primary = server_obj.get_string_member ("primary");
                        server.secondary = server_obj.get_string_member ("secondary");
                        server.description = server_obj.get_string_member ("description");
                        server.supports_dnssec = server_obj.get_boolean_member ("supports_dnssec");
                        server.category = server_obj.get_string_member ("category");
                        
                        dns_servers.add (server);
                    });
                }
            } catch (Error e) {
                warning ("Error loading DNS servers: %s", e.message);
                load_default_dns_servers ();
            }
        }
        
        private void load_record_types () {
            try {
                var file_path = get_data_file_path ("presets/record-types.json");
                if (!FileUtils.test (file_path, FileTest.EXISTS)) {
                    warning ("Record types preset file not found: %s", file_path);
                    load_default_record_types ();
                    return;
                }
                
                string content;
                FileUtils.get_contents (file_path, out content);
                
                var parser = new Json.Parser ();
                parser.load_from_data (content);
                
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                    warning ("Invalid JSON format in record-types.json");
                    load_default_record_types ();
                    return;
                }
                
                var root_obj = root.get_object ();
                var types_array = root_obj.get_array_member ("record_types");
                
                if (types_array != null) {
                    types_array.foreach_element ((array, index, element) => {
                        var type_obj = element.get_object ();
                        var record_type = new RecordTypeInfo ();
                        
                        record_type.record_type = type_obj.get_string_member ("type");
                        record_type.name = type_obj.get_string_member ("name");
                        record_type.description = type_obj.get_string_member ("description");
                        record_type.icon = type_obj.get_string_member ("icon");
                        record_type.color = type_obj.get_string_member ("color");
                        record_type.common_use = type_obj.get_string_member ("common_use");
                        
                        record_types.set (record_type.record_type, record_type);
                    });
                }
            } catch (Error e) {
                warning ("Error loading record types: %s", e.message);
                load_default_record_types ();
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
                "Pointer Record", "Text Record", "Start of Authority", "Service Record", "All Records"
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
