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

        public string get_display_name () {
            return name;
        }
    }

    public class PresetManager : Object {
        private static PresetManager? instance = null;
        private Gee.ArrayList<QueryPreset> system_presets;
        private Gee.ArrayList<QueryPreset> user_presets;

        public signal void presets_updated ();

        public static PresetManager get_instance () {
            if (instance == null) {
                instance = new PresetManager ();
            }
            return instance;
        }

        private PresetManager () {
            system_presets = new Gee.ArrayList<QueryPreset> ();
            user_presets = new Gee.ArrayList<QueryPreset> ();

            initialize_default_presets ();
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

            // 7. Any Records - ANY record type (with note about deprecation)
            var any_preset = new QueryPreset (
                "Any Records",
                "Query ANY record type (note: deprecated by many DNS servers)",
                RecordType.ANY
            );
            any_preset.icon = "view-list-symbolic";
            any_preset.is_system_preset = true;
            system_presets.add (any_preset);
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
    }
}
