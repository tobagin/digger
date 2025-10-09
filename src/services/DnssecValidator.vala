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

    public class DnssecValidator : Object {
        private DnsQuery dns_query;

        public DnssecValidator () {
            dns_query = new DnsQuery ();
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

        public async DnssecValidationResult validate_with_dig (string domain, string? dns_server = null) {
            var result = new DnssecValidationResult ();

            try {
                string dig_output;
                string dig_errors;
                int exit_status;

                string[] dig_command;
                if (dns_server != null && dns_server.length > 0) {
                    dig_command = { "dig", @"@$dns_server", "+dnssec", "+multiline", domain };
                } else {
                    dig_command = { "dig", "+dnssec", "+multiline", domain };
                }

                Process.spawn_sync (
                    null,
                    dig_command,
                    null,
                    SpawnFlags.SEARCH_PATH,
                    null,
                    out dig_output,
                    out dig_errors,
                    out exit_status
                );

                if (exit_status != 0) {
                    result.status = DnssecStatus.UNKNOWN;
                    result.chain_of_trust.add (@"dig command failed: $dig_errors");
                    return result;
                }

                result.has_dnskey = dig_output.contains ("DNSKEY");
                result.has_ds = dig_output.contains ("DS");
                result.has_rrsig = dig_output.contains ("RRSIG");

                if (dig_output.contains ("; flags:") && dig_output.contains (" ad;")) {
                    result.status = DnssecStatus.SECURE;
                    result.chain_of_trust.add ("DNSSEC AD flag set: SECURE");
                } else if (result.has_dnskey || result.has_ds || result.has_rrsig) {
                    result.status = DnssecStatus.INDETERMINATE;
                    result.chain_of_trust.add ("DNSSEC records present but AD flag not set");
                } else {
                    result.status = DnssecStatus.INSECURE;
                    result.chain_of_trust.add ("No DNSSEC records found");
                }

                if (dig_output.contains ("status: SERVFAIL")) {
                    result.status = DnssecStatus.BOGUS;
                    result.chain_of_trust.add ("DNSSEC validation failed: BOGUS");
                }

                var lines = dig_output.split ("\n");
                foreach (var line in lines) {
                    if (line.contains ("DNSKEY") || line.contains ("DS") ||
                        line.contains ("RRSIG") || line.contains ("NSEC")) {
                        var trimmed = line.strip ();
                        if (trimmed.length > 0 && !trimmed.has_prefix (";")) {
                            result.chain_of_trust.add (trimmed);
                        }
                    }
                }

            } catch (Error e) {
                warning ("dig DNSSEC validation failed: %s", e.message);
                result.status = DnssecStatus.UNKNOWN;
                result.chain_of_trust.add (@"Validation error: $(e.message)");
            }

            return result;
        }

        public async DnssecValidationResult validate_with_delv (string domain, string? dns_server = null) {
            var result = new DnssecValidationResult ();

            try {
                string delv_output;
                string delv_errors;
                int exit_status;

                string[] delv_command;
                if (dns_server != null && dns_server.length > 0) {
                    delv_command = { "delv", @"@$dns_server", domain };
                } else {
                    delv_command = { "delv", domain };
                }

                Process.spawn_sync (
                    null,
                    delv_command,
                    null,
                    SpawnFlags.SEARCH_PATH,
                    null,
                    out delv_output,
                    out delv_errors,
                    out exit_status
                );

                if (exit_status != 0) {
                    result.status = DnssecStatus.UNKNOWN;
                    result.chain_of_trust.add (@"delv command failed: $delv_errors");
                    return result;
                }

                if (delv_output.contains ("fully validated")) {
                    result.status = DnssecStatus.SECURE;
                    result.chain_of_trust.add ("DNSSEC fully validated by delv: SECURE");
                    result.has_dnskey = true;
                    result.has_ds = true;
                    result.has_rrsig = true;
                } else if (delv_output.contains ("unsigned")) {
                    result.status = DnssecStatus.INSECURE;
                    result.chain_of_trust.add ("Zone is unsigned: INSECURE");
                } else if (delv_output.contains ("validation failed")) {
                    result.status = DnssecStatus.BOGUS;
                    result.chain_of_trust.add ("DNSSEC validation failed: BOGUS");
                } else {
                    result.status = DnssecStatus.INDETERMINATE;
                    result.chain_of_trust.add ("DNSSEC status indeterminate");
                }

                var lines = delv_output.split ("\n");
                foreach (var line in lines) {
                    var trimmed = line.strip ();
                    if (trimmed.length > 0) {
                        result.chain_of_trust.add (trimmed);
                    }
                }

            } catch (Error e) {
                warning ("delv DNSSEC validation failed: %s", e.message);
                result.status = DnssecStatus.UNKNOWN;
                result.chain_of_trust.add (@"Validation error: $(e.message)");
            }

            return result;
        }
    }
}
