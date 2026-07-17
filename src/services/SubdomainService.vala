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
    public class SubdomainService : Object {
        // ponytail: fixed wordlist of common names, not a full brute-forcer.
        // A bundled wordlist file is the upgrade path if recon depth matters.
        private const string[] WORDLIST = {
            "www", "mail", "remote", "blog", "webmail", "server", "ns1", "ns2",
            "smtp", "secure", "vpn", "api", "dev", "staging", "test", "portal",
            "admin", "web", "cloud", "app", "m", "mobile", "cdn", "shop", "store",
            "ftp", "imap", "pop", "pop3", "mx", "mx1", "mx2", "email", "cpanel",
            "whm", "autodiscover", "autoconfig", "ns", "ns3", "ns4", "dns", "search",
            "git", "gitlab", "jenkins", "ci", "docs", "wiki", "help", "support",
            "status", "monitor", "grafana", "prometheus", "kibana", "jira",
            "confluence", "vpn2", "gateway", "proxy", "router", "firewall",
            "beta", "alpha", "demo", "sandbox", "preview", "next", "old", "new",
            "static", "assets", "img", "images", "media", "video", "files",
            "download", "downloads", "upload", "uploads", "backup", "db",
            "database", "sql", "mysql", "postgres", "redis", "cache", "queue",
            "auth", "login", "sso", "accounts", "account", "my", "dashboard",
            "panel", "console", "manage", "control", "internal", "intranet",
            "extranet", "partner", "partners", "customer", "client", "clients",
            "billing", "pay", "payment", "payments", "checkout", "order",
            "news", "events", "forum", "community", "chat", "talk", "meet",
            "conf", "webinar", "live", "stream", "tv", "radio", "music",
            "analytics", "stats", "metrics", "logs", "log", "trace", "apm",
            "smtp2", "relay", "edge", "origin", "lb", "node1", "node2", "k8s"
        };

        private const int CONCURRENCY = 12;

        private DnsQuery dns_query;

        public signal void found (string subdomain, string ip);
        public signal void progress (int done, int total);

        public SubdomainService () {
            dns_query = new DnsQuery ();
        }

        public async int enumerate (string domain, Cancellable? cancellable = null) {
            int total = WORDLIST.length;
            int done = 0;
            int live = 0;

            // Process in fixed-size batches to cap concurrent subprocesses.
            for (int start = 0; start < total; start += CONCURRENCY) {
                if (cancellable != null && cancellable.is_cancelled ()) {
                    break;
                }
                int end = int.min (start + CONCURRENCY, total);
                int pending = end - start;
                SourceFunc resume = enumerate.callback;

                for (int i = start; i < end; i++) {
                    string candidate = @"$(WORDLIST[i]).$domain";
                    probe.begin (candidate, (obj, res) => {
                        string? ip = probe.end (res);
                        done++;
                        if (ip != null) {
                            live++;
                            found (candidate, ip);
                        }
                        pending--;
                        if (pending == 0) {
                            Idle.add ((owned) resume);
                        }
                    });
                }
                if (pending > 0) {
                    yield;
                }
                progress (done, total);
            }

            return live;
        }

        private async string? probe (string candidate) {
            var result = yield dns_query.perform_query (candidate, RecordType.A);
            if (result != null && result.status == QueryStatus.SUCCESS &&
                result.answer_section.size > 0) {
                return result.answer_section[0].value;
            }
            return null;
        }
    }
}
