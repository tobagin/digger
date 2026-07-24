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
    public enum DnssecStatus {
        UNKNOWN,
        SECURE,
        INSECURE,
        BOGUS,
        INDETERMINATE;

        public string to_string () {
            switch (this) {
                case UNKNOWN: return "Unknown";
                case SECURE: return "Secure";
                case INSECURE: return "Insecure";
                case BOGUS: return "Bogus";
                case INDETERMINATE: return "Indeterminate";
                default: return "Unknown";
            }
        }

        public string get_icon_name () {
            switch (this) {
                case SECURE: return "security-high-symbolic";
                case INSECURE: return "security-low-symbolic";
                case BOGUS: return "dialog-error-symbolic";
                case INDETERMINATE: return "dialog-question-symbolic";
                default: return "dialog-information-symbolic";
            }
        }
    }

    public class DnssecValidationResult : Object {
        public DnssecStatus status { get; set; default = DnssecStatus.UNKNOWN; }
        public bool has_dnskey { get; set; default = false; }
        public bool has_ds { get; set; default = false; }
        public bool has_rrsig { get; set; default = false; }
        public Gee.ArrayList<string> chain_of_trust { get; set; }

        public DnssecValidationResult () {
            chain_of_trust = new Gee.ArrayList<string> ();
        }

        public bool is_dnssec_enabled () {
            return has_dnskey || has_ds || has_rrsig;
        }

        public string get_summary () {
            if (!is_dnssec_enabled ()) {
                return "DNSSEC: Not enabled";
            }
            return @"DNSSEC: $(status.to_string ())";
        }
    }

    public class DnssecChainLink : Object {
        public string zone { get; set; }
        public bool has_dnskey { get; set; }
        public bool has_ds { get; set; }
        public bool is_apex { get; set; }  // full queried domain (leaf of the chain)

        public DnssecChainLink (string zone) {
            this.zone = zone;
        }

        // A link is trusted when the zone is signed (DNSKEY) and the parent
        // vouches for it (DS) — except the root/TLD apex where DS lives above.
        public bool is_secure () {
            return has_dnskey && has_ds;
        }

        public string status_label () {
            if (is_secure ()) return "Signed & delegated";
            if (has_dnskey && !has_ds) return "Signed, no delegation (DS)";
            if (!has_dnskey && has_ds) return "Delegation present, zone unsigned";
            return "Unsigned";
        }

        public string icon_name () {
            if (is_secure ()) return "security-high-symbolic";
            if (has_dnskey || has_ds) return "security-low-symbolic";
            return "security-medium-symbolic";
        }
    }

    public class DnssecValidator : Object {
        private DnsQuery dns_query;

        public DnssecValidator () {
            dns_query = new DnsQuery ();
        }

        // Builds the chain of trust from the TLD down to the full domain,
        // querying DNSKEY (zone signed?) and DS (parent delegation?) per level.
        public async Gee.List<DnssecChainLink> validate_chain (string domain, string? dns_server = null) {
            var links = new Gee.ArrayList<DnssecChainLink> ();
            string trimmed = domain.strip ();
            if (trimmed.has_suffix (".")) {
                trimmed = trimmed.substring (0, trimmed.length - 1);
            }
            var labels = trimmed.split (".");
            if (labels.length == 0 || trimmed.length == 0) {
                return links;
            }

            // Progressive suffixes: "com", "example.com", "www.example.com".
            for (int i = labels.length - 1; i >= 0; i--) {
                var slice = labels[i:labels.length];
                string zone = string.joinv (".", slice);
                var link = new DnssecChainLink (zone);
                link.is_apex = (i == 0);

                var dnskey = yield dns_query.perform_query (zone, RecordType.DNSKEY, dns_server);
                if (dnskey != null && dnskey.status == QueryStatus.SUCCESS) {
                    link.has_dnskey = dnskey.answer_section.size > 0;
                }

                var ds = yield dns_query.perform_query (zone, RecordType.DS, dns_server);
                if (ds != null && ds.status == QueryStatus.SUCCESS) {
                    link.has_ds = ds.answer_section.size > 0;
                }

                links.add (link);
            }

            return links;
        }

        public async DnssecValidationResult validate_domain (string domain, string? dns_server = null) {
            var result = new DnssecValidationResult ();

            try {
                var dnskey_result = yield dns_query.perform_query (
                    domain,
                    RecordType.DNSKEY,
                    dns_server,
                    false,
                    false,
                    false
                );

                if (dnskey_result != null && dnskey_result.status == QueryStatus.SUCCESS) {
                    result.has_dnskey = dnskey_result.answer_section.size > 0;
                    if (result.has_dnskey) {
                        result.chain_of_trust.add (@"DNSKEY records found for $domain");
                    }
                }

                var ds_result = yield dns_query.perform_query (
                    domain,
                    RecordType.DS,
                    dns_server,
                    false,
                    false,
                    false
                );

                if (ds_result != null && ds_result.status == QueryStatus.SUCCESS) {
                    result.has_ds = ds_result.answer_section.size > 0;
                    if (result.has_ds) {
                        result.chain_of_trust.add (@"DS records found for $domain");
                    }
                }

                var rrsig_result = yield dns_query.perform_query (
                    domain,
                    RecordType.RRSIG,
                    dns_server,
                    false,
                    false,
                    false
                );

                if (rrsig_result != null && rrsig_result.status == QueryStatus.SUCCESS) {
                    result.has_rrsig = rrsig_result.answer_section.size > 0;
                    if (result.has_rrsig) {
                        result.chain_of_trust.add (@"RRSIG records found for $domain");
                    }
                }

                if (result.has_dnskey && result.has_ds && result.has_rrsig) {
                    result.status = DnssecStatus.SECURE;
                    result.chain_of_trust.add ("DNSSEC validation: SECURE");
                } else if (result.has_dnskey || result.has_ds || result.has_rrsig) {
                    result.status = DnssecStatus.INDETERMINATE;
                    result.chain_of_trust.add ("DNSSEC validation: INDETERMINATE (incomplete chain)");
                } else {
                    result.status = DnssecStatus.INSECURE;
                    result.chain_of_trust.add ("DNSSEC validation: INSECURE (no DNSSEC records)");
                }

            } catch (Error e) {
                warning ("DNSSEC validation failed: %s", e.message);
                result.status = DnssecStatus.UNKNOWN;
                result.chain_of_trust.add (@"DNSSEC validation error: $(e.message)");
            }

            return result;
        }
    }
}
