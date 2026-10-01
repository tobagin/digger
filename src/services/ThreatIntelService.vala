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

    public class ThreatIntelService : Object {
        private const string VT_DOMAIN_ENDPOINT = "https://www.virustotal.com/api/v3/domains/";
        private const string VT_IP_ENDPOINT = "https://www.virustotal.com/api/v3/ip_addresses/";
        private const string DBL_SUFFIX = ".dbl.spamhaus.org";

        private Soup.Session session;
        private ThreatIntelCache cache;
        private GLib.Settings? settings;
        private DateTime? _cooldown_until = null;

        public signal void check_completed (ThreatIntelData data);
        public signal void check_failed (string error_message);

        public ThreatIntelService (GLib.Settings? injected_settings = null, int? cache_ttl_override = null, int? cache_max_override = null) {
            settings = injected_settings;
            // Only create GSettings if not injected and no test overrides provided
            // (tests pass explicit TTL/max to avoid needing a compiled schema)
            if (settings == null && cache_ttl_override == null && cache_max_override == null) {
                try {
                    settings = new GLib.Settings (Config.APP_ID);
                } catch (Error e) {
                    warning ("ThreatIntelService: failed to create GSettings: %s", e.message);
                }
            }

            int ttl = cache_ttl_override ?? (settings != null ? settings.get_int ("threat-intel-cache-ttl") : Constants.THREAT_INTEL_CACHE_TTL_SECONDS);
            int max_entries = cache_max_override ?? Constants.THREAT_INTEL_CACHE_MAX_ENTRIES;
            cache = new ThreatIntelCache (null, ttl, max_entries);

            session = new Soup.Session ();
            session.timeout = Constants.VT_QUERY_TIMEOUT_SECONDS;
            session.user_agent = "Digger/" + Config.VERSION;
        }

        // Test-visible: allow tests to manipulate cooldown
        public DateTime? cooldown_until {
            get { return _cooldown_until; }
            set { _cooldown_until = value; }
        }

        public bool is_rate_limited () {
            if (_cooldown_until == null) return false;
            return new DateTime.now_local ().compare (_cooldown_until) < 0;
        }

        // --- Pure static scoring helpers (tested) ---

        public static int compute_vt_score (int malicious, int suspicious) {
            int raw = 100 - 25 * malicious - 10 * suspicious;
            if (raw < 0) raw = 0;
            if (raw > 100) raw = 100;
            return raw;
        }

        public static ThreatLevel compute_vt_level (int malicious, int suspicious) {
            if (malicious >= 3) return ThreatLevel.MALICIOUS;
            if (malicious >= 1 || suspicious >= 2) return ThreatLevel.SUSPICIOUS;
            return ThreatLevel.SAFE;
        }

        public struct DblInterpretation {
            public ThreatLevel level;
            public int score;
            public string? category;
            public string? error;
        }

        public static DblInterpretation interpret_dbl_code (string? code) {
            DblInterpretation r = DblInterpretation ();
            if (code == null) {
                r.level = ThreatLevel.SAFE;
                r.score = 100;
                r.category = null;
                r.error = null;
                return r;
            }
            string c = code.strip ();
            // Public resolver block
            if (c.has_prefix ("127.255.255.")) {
                r.level = ThreatLevel.ERROR;
                r.score = -1;
                r.category = null;
                r.error = "Spamhaus blocks queries via public resolvers";
                return r;
            }
            switch (c) {
                case "127.0.1.4":
                    r.level = ThreatLevel.MALICIOUS; r.score = 0; r.category = "phish"; break;
                case "127.0.1.5":
                    r.level = ThreatLevel.MALICIOUS; r.score = 0; r.category = "malware"; break;
                case "127.0.1.6":
                    r.level = ThreatLevel.MALICIOUS; r.score = 0; r.category = "botnet C&C"; break;
                case "127.0.1.2":
                    r.level = ThreatLevel.SUSPICIOUS; r.score = 40; r.category = "spam"; break;
                case "127.0.1.102":
                    r.level = ThreatLevel.SUSPICIOUS; r.score = 40; r.category = "abused legit"; break;
                default:
                    r.level = ThreatLevel.ERROR; r.score = -1; r.category = null;
                    r.error = "Unknown DBL return code: " + c;
                    break;
            }
            return r;
        }

        public struct AggregateResult {
            public ThreatLevel level;
            public int score;
        }

        public static AggregateResult aggregate_scores (bool has_vt, ThreatLevel vt_level, int vt_score, bool has_dbl, ThreatLevel dbl_level, int dbl_score) {
            AggregateResult r = AggregateResult ();
            // Collect valid components (non-ERROR, non-UNKNOWN without data)
            bool vt_valid = has_vt && vt_level != ThreatLevel.ERROR && vt_level != ThreatLevel.UNKNOWN;
            bool dbl_valid = has_dbl && dbl_level != ThreatLevel.ERROR && dbl_level != ThreatLevel.UNKNOWN;

            // Check if we have any ERROR signals that should propagate when no valid data
            bool has_any = has_vt || has_dbl;

            if (!vt_valid && !dbl_valid) {
                // If we had an ERROR or RATE_LIMITED, propagate it
                if (has_vt && (vt_level == ThreatLevel.ERROR || vt_level == ThreatLevel.RATE_LIMITED)) {
                    r.level = vt_level;
                    r.score = -1;
                    return r;
                }
                if (has_dbl && dbl_level == ThreatLevel.ERROR) {
                    r.level = ThreatLevel.ERROR;
                    r.score = -1;
                    return r;
                }
                // No data at all
                if (!has_any) {
                    r.level = ThreatLevel.UNKNOWN;
                    r.score = -1;
                    return r;
                }
                // Only UNKNOWN components
                r.level = ThreatLevel.UNKNOWN;
                r.score = -1;
                return r;
            }

            // Worst-of level
            ThreatLevel worst = ThreatLevel.SAFE;
            int min_score = 101;
            if (vt_valid) {
                worst = worst_of (worst, vt_level);
                if (vt_score >= 0 && vt_score < min_score) min_score = vt_score;
            }
            if (dbl_valid) {
                worst = worst_of (worst, dbl_level);
                if (dbl_score >= 0 && dbl_score < min_score) min_score = dbl_score;
            }
            r.level = worst;
            r.score = (min_score == 101) ? -1 : min_score;
            return r;
        }

        private static ThreatLevel worst_of (ThreatLevel a, ThreatLevel b) {
            return rank (a) >= rank (b) ? a : b;
        }

        private static int rank (ThreatLevel l) {
            switch (l) {
                case ThreatLevel.MALICIOUS: return 3;
                case ThreatLevel.SUSPICIOUS: return 2;
                case ThreatLevel.SAFE: return 1;
                case ThreatLevel.UNKNOWN: return 0;
                default: return 0;
            }
        }

        // --- JSON parsing (public static for tests) ---

        public static bool parse_virustotal_response (string json, ThreatIntelData data) {
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (json, -1);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) return false;
                var root_obj = root.get_object ();
                if (!root_obj.has_member ("data")) return false;
                var data_node = root_obj.get_member ("data");
                if (data_node == null || data_node.get_node_type () != Json.NodeType.OBJECT) return false;
                var data_obj = data_node.get_object ();
                if (!data_obj.has_member ("attributes")) return false;
                var attr_node = data_obj.get_member ("attributes");
                if (attr_node == null || attr_node.get_node_type () != Json.NodeType.OBJECT) return false;
                var attrs = attr_node.get_object ();

                // last_analysis_stats
                if (attrs.has_member ("last_analysis_stats")) {
                    var stats_node = attrs.get_member ("last_analysis_stats");
                    if (stats_node != null && stats_node.get_node_type () == Json.NodeType.OBJECT) {
                        var stats = stats_node.get_object ();
                        if (stats.has_member ("harmless")) data.vt_harmless = (int) stats.get_int_member ("harmless");
                        if (stats.has_member ("malicious")) data.vt_malicious = (int) stats.get_int_member ("malicious");
                        if (stats.has_member ("suspicious")) data.vt_suspicious = (int) stats.get_int_member ("suspicious");
                        if (stats.has_member ("undetected")) data.vt_undetected = (int) stats.get_int_member ("undetected");
                        if (stats.has_member ("timeout")) data.vt_timeout = (int) stats.get_int_member ("timeout");
                    }
                }

                // reputation
                if (attrs.has_member ("reputation")) {
                    var rep_node = attrs.get_member ("reputation");
                    if (rep_node != null && rep_node.get_node_type () == Json.NodeType.VALUE) {
                        data.vt_reputation = (int) rep_node.get_int ();
                    }
                }

                // total_votes
                if (attrs.has_member ("total_votes")) {
                    var votes_node = attrs.get_member ("total_votes");
                    if (votes_node != null && votes_node.get_node_type () == Json.NodeType.OBJECT) {
                        var votes = votes_node.get_object ();
                        if (votes.has_member ("harmless")) data.vt_votes_harmless = (int) votes.get_int_member ("harmless");
                        if (votes.has_member ("malicious")) data.vt_votes_malicious = (int) votes.get_int_member ("malicious");
                    }
                }

                // categories
                if (attrs.has_member ("categories")) {
                    var cat_node = attrs.get_member ("categories");
                    if (cat_node != null && cat_node.get_node_type () == Json.NodeType.OBJECT) {
                        var cats = cat_node.get_object ();
                        var seen = new Gee.HashSet<string> ();
                        foreach (string key in cats.get_members ()) {
                            var val_node = cats.get_member (key);
                            if (val_node != null && val_node.get_node_type () == Json.NodeType.VALUE) {
                                string cat_val = val_node.get_string ();
                                if (cat_val != null && cat_val.length > 0 && !seen.contains (cat_val)) {
                                    seen.add (cat_val);
                                    if (data.vt_categories.size < 10) {
                                        data.vt_categories.add (cat_val);
                                    }
                                }
                            }
                        }
                    }
                }

                // dates (unix epoch seconds)
                if (attrs.has_member ("first_submission_date")) {
                    var n = attrs.get_member ("first_submission_date");
                    if (n != null && n.get_node_type () == Json.NodeType.VALUE) {
                        int64 epoch = n.get_int ();
                        if (epoch > 0) data.vt_first_seen = new DateTime.from_unix_local (epoch);
                    }
                }
                if (attrs.has_member ("last_submission_date")) {
                    var n = attrs.get_member ("last_submission_date");
                    if (n != null && n.get_node_type () == Json.NodeType.VALUE) {
                        int64 epoch = n.get_int ();
                        if (epoch > 0) data.vt_last_seen = new DateTime.from_unix_local (epoch);
                    }
                }
                if (attrs.has_member ("last_analysis_date")) {
                    var n = attrs.get_member ("last_analysis_date");
                    if (n != null && n.get_node_type () == Json.NodeType.VALUE) {
                        int64 epoch = n.get_int ();
                        if (epoch > 0) data.vt_last_analyzed = new DateTime.from_unix_local (epoch);
                    }
                }

                // last_analysis_results -> collect malicious/suspicious
                if (attrs.has_member ("last_analysis_results")) {
                    var lar_node = attrs.get_member ("last_analysis_results");
                    if (lar_node != null && lar_node.get_node_type () == Json.NodeType.OBJECT) {
                        var lar = lar_node.get_object ();
                        foreach (string engine in lar.get_members ()) {
                            if (data.vt_detections.size >= 50) break;
                            var eng_node = lar.get_member (engine);
                            if (eng_node == null || eng_node.get_node_type () != Json.NodeType.OBJECT) continue;
                            var eng_obj = eng_node.get_object ();
                            string cat = "";
                            if (eng_obj.has_member ("category")) {
                                var c = eng_obj.get_member ("category");
                                if (c != null && c.get_node_type () == Json.NodeType.VALUE) {
                                    cat = c.get_string () ?? "";
                                }
                            }
                            if (cat == "malicious" || cat == "suspicious") {
                                string result_str = "";
                                if (eng_obj.has_member ("result")) {
                                    var r = eng_obj.get_member ("result");
                                    if (r != null && r.get_node_type () == Json.NodeType.VALUE) {
                                        result_str = r.get_string () ?? cat;
                                    }
                                }
                                if (result_str.length == 0) result_str = cat;
                                data.vt_detections.add (engine + ": " + result_str);
                            }
                        }
                    }
                }

                // Compute VT level/score
                data.safety_score = compute_vt_score (data.vt_malicious, data.vt_suspicious);
                data.level = compute_vt_level (data.vt_malicious, data.vt_suspicious);

                return true;
            } catch (Error e) {
                debug ("ThreatIntelService: JSON parse error: %s", e.message);
                return false;
            }
        }

        // --- Main async check ---

        public async ThreatIntelData? perform_check (string target) {
            string t = target.strip ();
            if (t.length == 0) {
                check_failed ("Empty target");
                return null;
            }

            bool is_ip = ValidationUtils.is_valid_ipv4 (t) || ValidationUtils.is_valid_ipv6 (t);
            bool is_host = ValidationUtils.is_valid_hostname (t);

            if (!is_ip && !is_host) {
                var err = new ThreatIntelData ();
                err.target = t;
                err.is_ip = false;
                err.level = ThreatLevel.ERROR;
                err.error_message = "Invalid domain or IP format";
                err.safety_score = -1;
                check_failed (err.error_message);
                return err;
            }

            // Check cache
            var cached = cache.get (t);
            if (cached != null) {
                cached.from_cache = true;
                check_completed (cached);
                return cached;
            }

            var data = new ThreatIntelData ();
            data.target = t;
            data.is_ip = is_ip;

            bool has_vt = false;
            ThreatLevel vt_level = ThreatLevel.UNKNOWN;
            int vt_score = -1;
            string? vt_error = null;

            bool has_dbl = false;
            ThreatLevel dbl_level = ThreatLevel.UNKNOWN;
            int dbl_score = -1;

            // VirusTotal check
            string? api_key = null;
            if (settings != null) {
                string k = settings.get_string ("virustotal-api-key");
                if (k != null && k.strip ().length > 0) api_key = k.strip ();
            }

            if (api_key != null) {
                if (is_rate_limited ()) {
                    has_vt = true;
                    vt_level = ThreatLevel.RATE_LIMITED;
                    vt_error = "Rate limited — try again later";
                    data.level = ThreatLevel.RATE_LIMITED;
                    data.error_message = vt_error;
                    data.safety_score = -1;
                } else {
                    var vt_result = yield perform_vt_query (t, is_ip, api_key, data);
                    has_vt = vt_result.has_vt;
                    vt_level = vt_result.level;
                    vt_score = vt_result.score;
                    vt_error = vt_result.error;
                }
            } else {
                // No key: VT skipped, not an error
                has_vt = false;
            }

            // DBL check (hostnames only)
            if (!is_ip) {
                var dbl_result = yield perform_dbl_query (t);
                has_dbl = true;
                dbl_level = dbl_result.level;
                dbl_score = dbl_result.score;
                data.dbl_listed = (dbl_level == ThreatLevel.MALICIOUS || dbl_level == ThreatLevel.SUSPICIOUS);
                data.dbl_return_code = dbl_result.code;
                data.dbl_category = dbl_result.category;
                data.dbl_error = dbl_result.error;
            }

            // Aggregate
            // If VT was rate-limited, propagate that
            if (has_vt && vt_level == ThreatLevel.RATE_LIMITED) {
                data.level = ThreatLevel.RATE_LIMITED;
                data.safety_score = -1;
                if (vt_error != null) data.error_message = vt_error;
                // Still set VT fields already populated
            } else if (has_vt && vt_level == ThreatLevel.ERROR) {
                // VT error: if DBL has valid data, aggregate with DBL, otherwise ERROR
                if (has_dbl && dbl_level != ThreatLevel.ERROR && dbl_level != ThreatLevel.UNKNOWN) {
                    var agg = aggregate_scores (false, ThreatLevel.UNKNOWN, -1, true, dbl_level, dbl_score);
                    data.level = agg.level;
                    data.safety_score = agg.score;
                    // Keep vt error_message for display
                    if (vt_error != null) data.error_message = vt_error;
                } else {
                    data.level = ThreatLevel.ERROR;
                    data.safety_score = -1;
                    if (vt_error != null) data.error_message = vt_error;
                }
            } else if (has_vt && vt_level == ThreatLevel.UNKNOWN && !has_dbl) {
                // VT 404 alone, no DBL (shouldn't happen for hostnames but for IPs)
                data.level = ThreatLevel.UNKNOWN;
                data.safety_score = -1;
                // preserve vt error_message if any ("no VirusTotal data...")
            } else {
                // Normal aggregation
                // For VT UNKNOWN (404), don't count as has_vt for aggregation
                bool vt_for_agg = has_vt && vt_level != ThreatLevel.UNKNOWN && vt_level != ThreatLevel.ERROR && vt_level != ThreatLevel.RATE_LIMITED;
                // Also handle the case where VT was 404 but DBL is valid -> use DBL only
                if (has_vt && vt_level == ThreatLevel.UNKNOWN) vt_for_agg = false;
                var agg = aggregate_scores (vt_for_agg, vt_level, vt_score, has_dbl, dbl_level, dbl_score);
                // Special: if VT was UNKNOWN and DBL not valid, overall UNKNOWN
                if (!vt_for_agg && (!has_dbl || dbl_level == ThreatLevel.ERROR || dbl_level == ThreatLevel.UNKNOWN)) {
                    // Check if both are UNKNOWN
                    if (has_vt && vt_level == ThreatLevel.UNKNOWN && (!has_dbl || dbl_level == ThreatLevel.UNKNOWN)) {
                        data.level = ThreatLevel.UNKNOWN;
                        data.safety_score = -1;
                    } else if (vt_for_agg || (has_dbl && dbl_level != ThreatLevel.ERROR && dbl_level != ThreatLevel.UNKNOWN)) {
                        data.level = agg.level;
                        data.safety_score = agg.score;
                    } else {
                        // Fallback to aggregation result
                        data.level = agg.level;
                        data.safety_score = agg.score;
                    }
                } else {
                    data.level = agg.level;
                    data.safety_score = agg.score;
                }
                // If VT had UNKNOWN message, keep it as error_message only if no other verdict
                if (data.level == ThreatLevel.UNKNOWN && vt_error != null && data.error_message == null) {
                    data.error_message = vt_error;
                }
            }

            // Override: if VT succeeded, VT level/score already set; aggregation refined overall
            // Need to ensure VT fields are reflected: if VT succeeded, data.safety_score from VT, then aggregate may lower it
            // Actually data.safety_score was set by parse; aggregation overwrites with min. That's correct.

            // Caching: cache SUCCESS and UNKNOWN (404), never ERROR/RATE_LIMITED
            if (data.level == ThreatLevel.SAFE || data.level == ThreatLevel.SUSPICIOUS ||
                data.level == ThreatLevel.MALICIOUS || data.level == ThreatLevel.UNKNOWN) {
                cache.put (t, data);
            }

            if (data.level == ThreatLevel.ERROR || data.level == ThreatLevel.RATE_LIMITED) {
                check_failed (data.error_message ?? "Threat check failed");
            } else {
                check_completed (data);
            }
            return data;
        }

        private struct VtQueryResult {
            bool has_vt;
            ThreatLevel level;
            int score;
            string? error;
        }

        private async VtQueryResult perform_vt_query (string target, bool is_ip, string api_key, ThreatIntelData data) {
            VtQueryResult r = VtQueryResult ();
            r.has_vt = true;

            string endpoint = is_ip ? VT_IP_ENDPOINT : VT_DOMAIN_ENDPOINT;
            // Belt-and-braces escaping
            string escaped = Uri.escape_string (target, null, true);
            string url = endpoint + escaped;

            // HTTPS-only enforcement
            if (!ValidationUtils.is_https_url (url)) {
                r.level = ThreatLevel.ERROR;
                r.score = -1;
                r.error = "Invalid VT endpoint URL";
                data.level = ThreatLevel.ERROR;
                data.error_message = r.error;
                return r;
            }

            try {
                var message = new Soup.Message ("GET", url);
                message.request_headers.append ("x-apikey", api_key);

                var bytes = yield session.send_and_read_async (message, Priority.DEFAULT, null);
                uint status = message.status_code;

                if (status == 200) {
                    string json = (string) bytes.get_data ();
                    bool ok = parse_virustotal_response (json, data);
                    if (!ok) {
                        r.level = ThreatLevel.ERROR;
                        r.score = -1;
                        r.error = "Failed to parse VirusTotal response";
                        data.level = ThreatLevel.ERROR;
                        data.error_message = r.error;
                        data.safety_score = -1;
                        return r;
                    }
                    r.level = data.level;
                    r.score = data.safety_score;
                    r.error = null;
                    return r;
                } else if (status == 404) {
                    r.level = ThreatLevel.UNKNOWN;
                    r.score = -1;
                    r.error = "no VirusTotal data for this domain";
                    // Set data to UNKNOWN but preserve message
                    data.level = ThreatLevel.UNKNOWN;
                    data.safety_score = -1;
                    data.error_message = r.error;
                    return r;
                } else if (status == 401) {
                    r.level = ThreatLevel.ERROR;
                    r.score = -1;
                    r.error = "invalid API key";
                    data.level = ThreatLevel.ERROR;
                    data.error_message = r.error;
                    data.safety_score = -1;
                    return r;
                } else if (status == 429) {
                    // Rate limited
                    int retry_after = 60;
                    string? ra = message.response_headers.get_one ("Retry-After");
                    if (ra != null) {
                        int parsed = int.parse (ra.strip ());
                        if (parsed > 0) retry_after = parsed;
                    }
                    if (retry_after > 300) retry_after = 300;
                    if (retry_after < 1) retry_after = 60;
                    _cooldown_until = new DateTime.now_local ().add_seconds (retry_after);
                    r.level = ThreatLevel.RATE_LIMITED;
                    r.score = -1;
                    r.error = "Rate limited — try again later";
                    data.level = ThreatLevel.RATE_LIMITED;
                    data.error_message = r.error;
                    data.safety_score = -1;
                    return r;
                } else {
                    r.level = ThreatLevel.ERROR;
                    r.score = -1;
                    r.error = "VirusTotal error: HTTP %u".printf (status);
                    data.level = ThreatLevel.ERROR;
                    data.error_message = r.error;
                    data.safety_score = -1;
                    return r;
                }
            } catch (Error e) {
                r.level = ThreatLevel.ERROR;
                r.score = -1;
                r.error = "Network error: " + e.message;
                data.level = ThreatLevel.ERROR;
                data.error_message = r.error;
                data.safety_score = -1;
                return r;
            }
        }

        private struct DblQueryResult {
            ThreatLevel level;
            int score;
            string? code;
            string? category;
            string? error;
        }

        private async DblQueryResult perform_dbl_query (string domain) {
            DblQueryResult r = DblQueryResult ();
            string query_domain = domain + DBL_SUFFIX;

            try {
                var dns_query = new DnsQuery ();
                var result = yield dns_query.perform_query (query_domain, RecordType.A, "", false, false, false, false);
                if (result == null || result.status != QueryStatus.SUCCESS || result.answer_section.size == 0) {
                    // No record => not listed => SAFE
                    var interp = interpret_dbl_code (null);
                    r.level = interp.level;
                    r.score = interp.score;
                    r.code = null;
                    r.category = null;
                    r.error = null;
                    return r;
                }
                // Should have an A record with the DBL code
                string? code = null;
                foreach (var rec in result.answer_section) {
                    if (rec.record_type == RecordType.A) {
                        code = rec.value.strip ();
                        break;
                    }
                }
                if (code == null) {
                    var interp = interpret_dbl_code (null);
                    r.level = interp.level;
                    r.score = interp.score;
                    return r;
                }
                var interp2 = interpret_dbl_code (code);
                r.level = interp2.level;
                r.score = interp2.score;
                r.code = code;
                r.category = interp2.category;
                r.error = interp2.error;
                return r;
            } catch (Error e) {
                // Network error for DBL should not fail overall check; treat as no DBL data
                r.level = ThreatLevel.UNKNOWN;
                r.score = -1;
                r.code = null;
                r.category = null;
                r.error = null;
                return r;
            }
        }

        public void clear_cache () {
            cache.clear ();
        }
    }

    public class ThreatIntelCache : Object {
        private class CacheEntry {
            public ThreatIntelData data;
            public DateTime expires_at;
            public CacheEntry (ThreatIntelData data, DateTime expires_at) {
                this.data = data;
                this.expires_at = expires_at;
            }
            public bool is_expired () {
                return new DateTime.now_local ().compare (expires_at) >= 0;
            }
        }

        private Gee.HashMap<string, CacheEntry> cache_map;
        private Gee.ArrayList<string> access_order;
        private int ttl_seconds;
        private int max_entries;

        public ThreatIntelCache (GLib.Settings? settings, int ttl_seconds_override = Constants.THREAT_INTEL_CACHE_TTL_SECONDS, int max_entries_override = Constants.THREAT_INTEL_CACHE_MAX_ENTRIES) {
            cache_map = new Gee.HashMap<string, CacheEntry> ();
            access_order = new Gee.ArrayList<string> ();
            if (settings != null) {
                ttl_seconds = settings.get_int ("threat-intel-cache-ttl");
            } else {
                ttl_seconds = ttl_seconds_override;
            }
            max_entries = max_entries_override;
        }

        public new ThreatIntelData? get (string target) {
            string key = target.down ();
            if (!cache_map.has_key (key)) return null;
            var entry = cache_map.get (key);
            if (entry.is_expired ()) {
                cache_map.unset (key);
                access_order.remove (key);
                return null;
            }
            access_order.remove (key);
            access_order.add (key);
            return entry.data;
        }

        public void put (string target, ThreatIntelData data) {
            string key = target.down ();
            var expires_at = new DateTime.now_local ().add_seconds (ttl_seconds);
            var entry = new CacheEntry (data, expires_at);
            if (cache_map.has_key (key)) {
                access_order.remove (key);
            }
            while (access_order.size >= max_entries) {
                string oldest = access_order.get (0);
                cache_map.unset (oldest);
                access_order.remove_at (0);
            }
            cache_map.set (key, entry);
            access_order.add (key);
        }

        public void clear () {
            cache_map.clear ();
            access_order.clear ();
        }
    }
}
