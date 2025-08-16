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
                case "ANY": return ANY;
                default: return A; // Default fallback
            }
        }
    }

    public enum QueryStatus {
        SUCCESS,
        NXDOMAIN,
        SERVFAIL,
        TIMEOUT,
        NETWORK_ERROR,
        INVALID_DOMAIN,
        NO_DIG_COMMAND;

        public string to_string () {
            switch (this) {
                case SUCCESS: return "Success";
                case NXDOMAIN: return "NXDOMAIN - Domain not found";
                case SERVFAIL: return "SERVFAIL - Server failure";
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

        // Raw dig output for debugging
        public string raw_output { get; set; }

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
