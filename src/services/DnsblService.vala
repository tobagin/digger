/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

using Gee;

namespace Digger {
    public enum DnsblStatus {
        CLEAN,
        LISTED,
        ERROR,
        CHECKING
    }

    public class DnsblResult : Object {
        public string provider { get; set; }
        public string provider_name { get; set; }
        public DnsblStatus status { get; set; }
        public string? return_code { get; set; }
        public string? error_message { get; set; }
        public DateTime timestamp { get; set; }

        public DnsblResult (string provider, string provider_name) {
            this.provider = provider;
            this.provider_name = provider_name;
            this.status = DnsblStatus.CHECKING;
            this.timestamp = new DateTime.now_local ();
        }
    }

    public class DnsblService : Object {
        private DnsQuery dns_query;
        
        // Common RBL providers
        // Format: hostname, display name
        private const string[,] DEFAULT_PROVIDERS = {
            { "zen.spamhaus.org", "Spamhaus ZEN" },
            { "bl.spamcop.net", "SpamCop" },
            { "b.barracudacentral.org", "Barracuda" },
            { "dnsbl.sorbs.net", "SORBS" },
            { "psbl.surriel.com", "PSBL" },
            { "ubl.unsubscore.com", "UBL" },
            { "cbl.abuseat.org", "CBL" }
        };

        construct {
            dns_query = new DnsQuery ();
        }

        public async ArrayList<DnsblResult> check_ip (string ip_address) {
            var results = new ArrayList<DnsblResult> ();
            string reversed_ip = reverse_ip (ip_address);
            
            if (reversed_ip == null) {
                // Return empty or error if IP is invalid
                return results;
            }

            // Create initial results for all providers
            for (int i = 0; i < DEFAULT_PROVIDERS.length[0]; i++) {
                results.add (new DnsblResult (DEFAULT_PROVIDERS[i, 0], DEFAULT_PROVIDERS[i, 1]));
            }

            // Process checks in parallel, resuming once every probe completes.
            int pending = results.size;
            SourceFunc resume = check_ip.callback;
            foreach (var result in results) {
                check_provider.begin (reversed_ip, result, (obj, res) => {
                    check_provider.end (res);
                    pending--;
                    if (pending == 0) {
                        Idle.add ((owned) resume);
                    }
                });
            }
            if (pending > 0) {
                yield;
            }

            return results;
        }

        private async void check_provider (string reversed_ip, DnsblResult result) {
            string lookup_domain = @"$reversed_ip.$(result.provider)";
            
            try {
                // Perform A record lookup
                var query_result = yield dns_query.perform_query (lookup_domain, RecordType.A);
                
                if (query_result.status == QueryStatus.NXDOMAIN) {
                    result.status = DnsblStatus.CLEAN;
                } else if (query_result.status == QueryStatus.SUCCESS && query_result.answer_section.size > 0) {
                    result.status = DnsblStatus.LISTED;
                    // Usually returns 127.0.0.x
                    if (query_result.answer_section.size > 0) {
                        result.return_code = query_result.answer_section[0].value;
                    }
                } else {
                    result.status = DnsblStatus.ERROR;
                    result.error_message = query_result.status.to_string ();
                }
            } catch (Error e) {
                result.status = DnsblStatus.ERROR;
                result.error_message = e.message;
            }
        }

        private string? reverse_ip (string ip) {
            // Simple IPv4 reverser
            // 1.2.3.4 -> 4.3.2.1
            var parts = ip.split (".");
            if (parts.length != 4) return null;
            
            return @"$(parts[3]).$(parts[2]).$(parts[1]).$(parts[0])";
        }
    }
}
