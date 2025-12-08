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
    public enum RecordType {
        A,
        AAAA,
        CNAME,
        MX,
        NS,
        PTR,
        TXT,
        SOA,
        SRV,
        DNSKEY,
        DS,
        RRSIG,
        NSEC,
        NSEC3,
        ANY;

        public string to_string () {
            switch (this) {
                case A: return "A";
                case AAAA: return "AAAA";
                case CNAME: return "CNAME";
                case MX: return "MX";
                case NS: return "NS";
                case PTR: return "PTR";
                case TXT: return "TXT";
                case SOA: return "SOA";
                case SRV: return "SRV";
                case DNSKEY: return "DNSKEY";
                case DS: return "DS";
                case RRSIG: return "RRSIG";
                case NSEC: return "NSEC";
                case NSEC3: return "NSEC3";
                case ANY: return "ANY";
                default: return "UNKNOWN";
            }
        }

        public static RecordType from_string (string type_str) {
            switch (type_str.up ()) {
                case "A": return A;
                case "AAAA": return AAAA;
                case "CNAME": return CNAME;
                case "MX": return MX;
                case "NS": return NS;
                case "PTR": return PTR;
                case "TXT": return TXT;
                case "SOA": return SOA;
                case "SRV": return SRV;
                case "DNSKEY": return DNSKEY;
                case "DS": return DS;
                case "RRSIG": return RRSIG;
                case "NSEC": return NSEC;
                case "NSEC3": return NSEC3;
                case "ANY": return ANY;
                default: return A; // Default fallback
            }
        }

        public int to_wire_type () {
            switch (this) {
                case A: return 1;
                case AAAA: return 28;
                case CNAME: return 5;
                case MX: return 15;
                case NS: return 2;
                case PTR: return 12;
                case TXT: return 16;
                case SOA: return 6;
                case SRV: return 33;
                case DNSKEY: return 48;
                case DS: return 43;
                case RRSIG: return 46;
                case NSEC: return 47;
                case NSEC3: return 50;
                case ANY: return 255;
                default: return 1;
            }
        }

        public static RecordType from_wire_type (int wire_type) {
            switch (wire_type) {
                case 1: return A;
                case 28: return AAAA;
                case 5: return CNAME;
                case 15: return MX;
                case 2: return NS;
                case 12: return PTR;
                case 16: return TXT;
                case 6: return SOA;
                case 33: return SRV;
                case 48: return DNSKEY;
                case 43: return DS;
                case 46: return RRSIG;
                case 47: return NSEC;
                case 50: return NSEC3;
                case 255: return ANY;
                default: return A;
            }
        }
    }

    public enum QueryStatus {
        SUCCESS,
        NXDOMAIN,
        SERVFAIL,
        REFUSED,
        TIMEOUT,
        NETWORK_ERROR,
        INVALID_DOMAIN,
        NO_DIG_COMMAND;

        public string to_string () {
            switch (this) {
                case SUCCESS: return "Success";
                case NXDOMAIN: return "NXDOMAIN - Domain not found";
                case SERVFAIL: return "SERVFAIL - Server failure";
                case REFUSED: return "REFUSED - Query refused";
                case TIMEOUT: return "Query timeout";
                case NETWORK_ERROR: return "Network error";
                case INVALID_DOMAIN: return "Invalid domain format";
                case NO_DIG_COMMAND: return "dig command not found";
                default: return "Unknown error";
            }
        }
    }

    public class DnsRecord : Object {
        public string name { get; set; }
        public RecordType record_type { get; set; }
        public int ttl { get; set; }
        public string value { get; set; }
        public int priority { get; set; default = -1; } // For MX records
        
        // RRSIG specific fields
        public string? rrsig_type_covered { get; set; }
        public string? rrsig_algorithm { get; set; }
        public string? rrsig_labels { get; set; }
        public string? rrsig_original_ttl { get; set; }
        public string? rrsig_expiration { get; set; }
        public string? rrsig_inception { get; set; }
        public string? rrsig_key_tag { get; set; }
        public string? rrsig_signer_name { get; set; }

        public DnsRecord (string name, RecordType record_type, int ttl, string value, int priority = -1) {
            this.name = name;
            this.record_type = record_type;
            this.ttl = ttl;
            this.value = value;
            this.priority = priority;
        }

        public string get_display_value () {
            if (record_type == RecordType.MX && priority >= 0) {
                return @"$priority $value";
            }
            return value;
        }

        public string get_copyable_value () {
            if (record_type == RecordType.MX && priority >= 0) {
                return @"$priority $value";
            }
            return value;
        }
    }

    public class WhoisData : Object {
        public string domain { get; set; }
        public string? registrar { get; set; }
        public string? created_date { get; set; }
        public string? updated_date { get; set; }
        public string? expires_date { get; set; }
        public Gee.ArrayList<string> nameservers { get; set; }
        public Gee.ArrayList<string> status { get; set; }
        public string? registrant_name { get; set; }
        public string? registrant_email { get; set; }
        public string? registrant_org { get; set; }
        public bool privacy_protected { get; set; default = false; }
        public string raw_output { get; set; }
        public DateTime timestamp { get; set; }
        public bool from_cache { get; set; default = false; }

        public WhoisData () {
            nameservers = new Gee.ArrayList<string> ();
            status = new Gee.ArrayList<string> ();
            timestamp = new DateTime.now_local ();
        }

        public bool has_parsed_data () {
            return registrar != null || created_date != null ||
                   nameservers.size > 0 || status.size > 0;
        }
    }

    public class QueryResult : Object {
        public string domain { get; set; }
        public RecordType query_type { get; set; }
        public string dns_server { get; set; }
        public double query_time_ms { get; set; }
        public QueryStatus status { get; set; }
        public DateTime timestamp { get; set; }

        // Result sections
        public Gee.ArrayList<DnsRecord> answer_section { get; set; }
        public Gee.ArrayList<DnsRecord> authority_section { get; set; }
        public Gee.ArrayList<DnsRecord> additional_section { get; set; }

        // Advanced options used
        public bool reverse_lookup { get; set; default = false; }
        public bool trace_path { get; set; default = false; }
        public bool short_output { get; set; default = false; }
        public bool request_dnssec { get; set; default = false; }

        // Raw dig output for debugging
        public string raw_output { get; set; }

        // WHOIS data
        public WhoisData? whois_data { get; set; default = null; }

        public QueryResult () {
            answer_section = new Gee.ArrayList<DnsRecord> ();
            authority_section = new Gee.ArrayList<DnsRecord> ();
            additional_section = new Gee.ArrayList<DnsRecord> ();
            timestamp = new DateTime.now_local ();
        }

        public bool has_results () {
            return answer_section.size > 0 || authority_section.size > 0 || additional_section.size > 0;
        }

        public string get_summary () {
            if (status != QueryStatus.SUCCESS) {
                return status.to_string ();
            }

            int total_records = answer_section.size + authority_section.size + additional_section.size;
            return @"$total_records record(s) found in $(@"%.2f".printf(query_time_ms))ms";
        }
    }
}
