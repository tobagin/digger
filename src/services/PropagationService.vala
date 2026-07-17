/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2025 tobagin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger {
    public class PropagationProbe : Object {
        public string resolver_name { get; set; }
        public string resolver_ip { get; set; }
        public Gee.ArrayList<string> values { get; set; }
        public QueryStatus status { get; set; }
        public bool agrees { get; set; default = true; }

        public PropagationProbe (string name, string ip) {
            resolver_name = name;
            resolver_ip = ip;
            values = new Gee.ArrayList<string> ();
            status = QueryStatus.SUCCESS;
        }

        // Sorted, comma-joined answer values — the key we compare for consensus.
        public string signature () {
            var copy = new Gee.ArrayList<string> ();
            copy.add_all (values);
            copy.sort ();
            return string.joinv (",", copy.to_array ());
        }
    }

    public class PropagationService : Object {
        // name, IPv4 — well-known public resolvers.
        private const string[,] RESOLVERS = {
            { "Google", "8.8.8.8" },
            { "Cloudflare", "1.1.1.1" },
            { "Quad9", "9.9.9.9" },
            { "OpenDNS", "208.67.222.222" },
            { "Level3", "4.2.2.1" },
            { "DNS.WATCH", "84.200.69.80" },
            { "Comodo Secure", "8.26.56.26" },
            { "AdGuard", "94.140.14.14" }
        };

        private DnsQuery dns_query;

        public PropagationService () {
            // Own instance so probes don't drive the main window's signals.
            dns_query = new DnsQuery ();
        }

        public async Gee.List<PropagationProbe> check (string domain, RecordType record_type) {
            var probes = new Gee.ArrayList<PropagationProbe> ();
            for (int i = 0; i < RESOLVERS.length[0]; i++) {
                probes.add (new PropagationProbe (RESOLVERS[i, 0], RESOLVERS[i, 1]));
            }

            int pending = probes.size;
            SourceFunc resume = check.callback;
            foreach (var probe in probes) {
                probe_one.begin (domain, record_type, probe, (obj, res) => {
                    probe_one.end (res);
                    pending--;
                    if (pending == 0) {
                        Idle.add ((owned) resume);
                    }
                });
            }
            if (pending > 0) {
                yield;
            }

            compute_consensus (probes);
            return probes;
        }

        private async void probe_one (string domain, RecordType record_type, PropagationProbe probe) {
            var result = yield dns_query.perform_query (domain, record_type, probe.resolver_ip);
            if (result == null) {
                probe.status = QueryStatus.NETWORK_ERROR;
                return;
            }
            probe.status = result.status;
            foreach (var record in result.answer_section) {
                probe.values.add (record.value);
            }
        }

        // The most common answer signature among successful probes is the
        // consensus; probes that differ are flagged (stale / split-horizon).
        private void compute_consensus (Gee.List<PropagationProbe> probes) {
            var counts = new Gee.HashMap<string, int> ();
            foreach (var probe in probes) {
                if (probe.status != QueryStatus.SUCCESS || probe.values.size == 0) {
                    continue;
                }
                string sig = probe.signature ();
                counts.set (sig, (counts.has_key (sig) ? counts.get (sig) : 0) + 1);
            }

            string majority = "";
            int best = 0;
            foreach (var entry in counts.entries) {
                if (entry.value > best) {
                    best = entry.value;
                    majority = entry.key;
                }
            }

            foreach (var probe in probes) {
                if (probe.status != QueryStatus.SUCCESS || probe.values.size == 0) {
                    probe.agrees = false;
                } else {
                    probe.agrees = (probe.signature () == majority);
                }
            }
        }
    }
}
