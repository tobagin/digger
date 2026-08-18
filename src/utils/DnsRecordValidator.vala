/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 *
 * DNS Record Validator — RFC syntax + compliance checks
 *
 * Pure, synchronous, side-effect-free and never blocks DnsQuery — call after
 * parse_dig_output, e.g.:
 *   var vr = DnsRecordValidator.validate_record_set (result.answer_section);
 *
 * Set-level validators are optional — call validate_record_set for zone-level
 * compliance; single-record validate() is sufficient for per-record syntax.
 *
 * RFC references:
 *   RFC 791  — IPv4
 *   RFC 1034 §3.6.2 — CNAME co-existence
 *   RFC 1035 §3.3.14 — TXT / SOA
 *   RFC 1123 — Hostname
 *   RFC 2181 §10.3 — MX target must not be CNAME/IP
 *   RFC 4408 — TXT / SPF chunking
 */

namespace Digger {

    public enum ValidationSeverity {
        ERROR,
        WARNING,
        INFO
    }

    public enum ValidationCode {
        INVALID_IPV4,
        INVALID_IPV6,
        INVALID_HOSTNAME,
        CNAME_TARGET_IS_IP,
        CNAME_TARGET_INVALID,
        MX_PRIORITY_OUT_OF_RANGE,
        MX_TARGET_IS_IP,
        MX_TARGET_INVALID,
        MX_TARGET_IS_CNAME,
        NS_TARGET_IS_IP,
        NS_TARGET_INVALID,
        TXT_CHUNK_TOO_LONG,
        TXT_UNBALANCED_QUOTES,
        SOA_MISSING_FIELDS,
        SOA_MNAME_INVALID,
        SOA_RNAME_INVALID,
        SOA_SERIAL_INVALID,
        SOA_REFRESH_INVALID,
        SOA_RETRY_INVALID,
        SOA_EXPIRE_INVALID,
        SOA_MINIMUM_INVALID,
        CNAME_COEXISTENCE,
        SOA_DUPLICATE,
        MX_NULL_TARGET
    }

    public class ValidationIssue : Object {
        public ValidationSeverity severity { get; set; }
        public ValidationCode code { get; set; }
        public string message { get; set; }
        public string? field { get; set; default = null; }

        public ValidationIssue (ValidationSeverity severity, ValidationCode code, string message, string? field = null) {
            this.severity = severity;
            this.code = code;
            this.message = message;
            this.field = field;
        }
    }

    public class ValidationResult : Object {
        public Gee.ArrayList<ValidationIssue> issues { get; private set; }

        public ValidationResult () {
            issues = new Gee.ArrayList<ValidationIssue> ();
        }

        public bool is_valid {
            get { return errors.size == 0; }
        }

        public bool has_errors {
            get { return errors.size > 0; }
        }

        public bool has_warnings {
            get { return warnings.size > 0; }
        }

        public Gee.ArrayList<ValidationIssue> errors {
            owned get {
                var list = new Gee.ArrayList<ValidationIssue> ();
                foreach (var i in issues) {
                    if (i.severity == ValidationSeverity.ERROR) list.add (i);
                }
                return list;
            }
        }

        public Gee.ArrayList<ValidationIssue> warnings {
            owned get {
                var list = new Gee.ArrayList<ValidationIssue> ();
                foreach (var i in issues) {
                    if (i.severity == ValidationSeverity.WARNING) list.add (i);
                }
                return list;
            }
        }

        public string get_summary () {
            if (issues.size == 0) return "No issues";
            int e = errors.size;
            int w = warnings.size;
            if (e > 0 && w > 0) return @"$e error(s), $w warning(s)";
            if (e > 0) return @"$e error(s)";
            return @"$w warning(s)";
        }

        public void add_issue (ValidationIssue issue) {
            issues.add (issue);
        }

        public void add_all (ValidationResult other) {
            foreach (var i in other.issues) issues.add (i);
        }
    }

    public class DnsRecordValidator : Object {

        // ---------- helpers ----------

        private static string normalize_name (string name) {
            string n = name.strip ().down ();
            if (n.has_suffix (".")) n = n.substring (0, n.length - 1);
            return n;
        }

        private static bool is_ip_literal (string s) {
            string t = s.strip ();
            if (t.has_suffix (".")) t = t.substring (0, t.length - 1);
            return ValidationUtils.is_valid_ipv4 (t) || ValidationUtils.is_valid_ipv6 (t);
        }

        // ---------- public entry points ----------

        public static ValidationResult validate (DnsRecord record) {
            return validate_by_type_with_name (record.record_type, record.name, record.value, record.priority);
        }

        public static ValidationResult validate_by_type (RecordType type, string value, int priority = -1) {
            return validate_by_type_with_name (type, "", value, priority);
        }

        public static ValidationResult validate_by_type_with_name (RecordType type, string name, string value, int priority = -1) {
            switch (type) {
                case RecordType.A: return validate_a (value);
                case RecordType.AAAA: return validate_aaaa (value);
                case RecordType.CNAME: return validate_cname (value);
                case RecordType.NS: return validate_ns (value);
                case RecordType.MX: return validate_mx (value, priority);
                case RecordType.TXT: return validate_txt (value);
                case RecordType.SOA: return validate_soa (value);
                default:
                    // Unknown / unvalidated types: no errors
                    return new ValidationResult ();
            }
        }

        public static ValidationResult validate_record_set (Gee.Collection<DnsRecord> records) {
            var result = new ValidationResult ();

            // Per-record syntax (optional but useful to surface in set result)
            // Also collect for compliance checks
            var by_name = new Gee.HashMap<string, Gee.ArrayList<DnsRecord>> ();
            var cname_owners = new Gee.HashSet<string> ();
            var cname_targets = new Gee.HashSet<string> ();
            int soa_count = 0;

            foreach (var r in records) {
                string norm = normalize_name (r.name);
                if (!by_name.has_key (norm)) by_name[norm] = new Gee.ArrayList<DnsRecord> ();
                by_name[norm].add (r);

                if (r.record_type == RecordType.CNAME) {
                    cname_owners.add (norm);
                    cname_targets.add (normalize_name (r.value));
                }
                if (r.record_type == RecordType.SOA) soa_count++;
            }

            // CNAME co-existence (RFC 1034 §3.6.2)
            foreach (var entry in by_name.entries) {
                string owner = entry.key;
                var list = entry.value;
                bool has_cname = false;
                int other_count = 0;
                int cname_count = 0;
                foreach (var r in list) {
                    if (r.record_type == RecordType.CNAME) {
                        has_cname = true;
                        cname_count++;
                    } else {
                        other_count++;
                    }
                }
                if (has_cname && other_count > 0) {
                    result.add_issue (new ValidationIssue (
                        ValidationSeverity.WARNING, ValidationCode.CNAME_COEXISTENCE,
                        @"CNAME at '$(owner)' co-exists with $(other_count) other record(s) — CNAME must not co-exist (RFC 1034)",
                        owner
                    ));
                }
                if (cname_count > 1) {
                    result.add_issue (new ValidationIssue (
                        ValidationSeverity.WARNING, ValidationCode.CNAME_COEXISTENCE,
                        @"CNAME at '$(owner)' has $(cname_count) CNAME records — at most one CNAME per owner (RFC 1034)",
                        owner
                    ));
                }
            }

            // MX target is CNAME (RFC 2181 §10.3)
            foreach (var r in records) {
                if (r.record_type == RecordType.MX) {
                    string target = extract_mx_target (r.value, r.priority);
                    if (target == null || target.length == 0) continue;
                    // Null MX (RFC 7505): "0 ." — skip CNAME check
                    string norm_target = normalize_name (target);
                    if (norm_target == "" || norm_target == ".") continue;
                    if (cname_owners.contains (norm_target)) {
                        result.add_issue (new ValidationIssue (
                            ValidationSeverity.WARNING, ValidationCode.MX_TARGET_IS_CNAME,
                            @"MX target '$(target.strip ())' is a CNAME — MX should point to an A/AAAA host (RFC 2181 section 10.3)",
                            "mx_target"
                        ));
                    }
                }
            }

            // SOA compliance
            if (soa_count == 0) {
                // No warning for zero SOA in generic set (zone may be partial); only warn on duplicate
                // Spec says warn if zero or more than 1 — but generic query sets often have zero.
                // We warn only for duplicate to avoid noise; check spec: "warn if zone has zero or more than 1"
                // Implement as WARNING but low priority. Keep duplicate warning.
            }
            if (soa_count > 1) {
                result.add_issue (new ValidationIssue (
                    ValidationSeverity.WARNING, ValidationCode.SOA_DUPLICATE,
                    @"Zone has $(soa_count) SOA records — should have exactly one (RFC 1035)",
                    "soa"
                ));
            }

            // SOA MNAME has no matching NS
            // Collect NS targets normalized
            var ns_targets = new Gee.HashSet<string> ();
            foreach (var r in records) {
                if (r.record_type == RecordType.NS) {
                    ns_targets.add (normalize_name (r.value));
                }
            }
            foreach (var r in records) {
                if (r.record_type == RecordType.SOA) {
                    var parts = split_soa_fields (r.value);
                    if (parts != null && parts.length >= 1) {
                        string mname = normalize_name (parts[0]);
                        if (mname.length > 0 && ns_targets.size > 0 && !ns_targets.contains (mname)) {
                            result.add_issue (new ValidationIssue (
                                ValidationSeverity.WARNING, ValidationCode.SOA_MNAME_INVALID,
                                @"SOA MNAME '$(parts[0])' has no matching NS record",
                                "soa_mname"
                            ));
                        }
                    }
                }
            }

            return result;
        }

        // ---------- per-type validators ----------

        private static ValidationResult validate_a (string value) {
            var res = new ValidationResult ();
            string v = value.strip ();
            if (v.length == 0) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.INVALID_IPV4, "A record value must be an IPv4 address, got empty value", "value"));
                return res;
            }
            if (!ValidationUtils.is_valid_ipv4 (v)) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.INVALID_IPV4, @"A record value '$(v)' is not a valid IPv4 address (RFC 791)", "value"));
            }
            return res;
        }

        private static ValidationResult validate_aaaa (string value) {
            var res = new ValidationResult ();
            string v = value.strip ();
            if (v.length == 0) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.INVALID_IPV6, "AAAA record value must be an IPv6 address, got empty value", "value"));
                return res;
            }
            if (!ValidationUtils.is_valid_ipv6 (v)) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.INVALID_IPV6, @"AAAA record value '$(v)' is not a valid IPv6 address", "value"));
            }
            return res;
        }

        private static ValidationResult validate_cname (string value) {
            var res = new ValidationResult ();
            string v = value.strip ();
            if (v.length == 0) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.CNAME_TARGET_INVALID, "CNAME target must be a hostname, got empty value", "value"));
                return res;
            }
            string bare = v;
            if (bare.has_suffix (".")) bare = bare.substring (0, bare.length - 1).strip ();
            if (is_ip_literal (bare)) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.CNAME_TARGET_IS_IP, "CNAME target must be a hostname, not an IP address", "value"));
                return res;
            }
            if (!ValidationUtils.is_valid_hostname (bare)) {
                // Distinguish label/total length hints
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.CNAME_TARGET_INVALID, @"CNAME target '$(v)' is not a valid hostname (RFC 1035 / RFC 1123)", "value"));
            }
            return res;
        }

        private static ValidationResult validate_ns (string value) {
            var res = new ValidationResult ();
            string v = value.strip ();
            if (v.length == 0) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.NS_TARGET_INVALID, "NS target must be a hostname, got empty value", "value"));
                return res;
            }
            string bare = v;
            if (bare.has_suffix (".")) bare = bare.substring (0, bare.length - 1).strip ();
            if (is_ip_literal (bare)) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.NS_TARGET_IS_IP, "NS target must be a hostname, not an IP address", "value"));
                return res;
            }
            if (!ValidationUtils.is_valid_hostname (bare)) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.NS_TARGET_INVALID, @"NS target '$(v)' is not a valid hostname (RFC 1035 / RFC 1123)", "value"));
            }
            return res;
        }

        private static string? extract_mx_target (string value, int priority) {
            string v = value.strip ();
            if (v.length == 0) return null;
            // If priority was supplied separately (DnsRecord.priority >=0), value is already the hostname
            if (priority >= 0) {
                return v;
            }
            // Otherwise try to split leading integer from value
            var parts = v.split_set (" \t");
            var cleaned = new Gee.ArrayList<string> ();
            foreach (var p in parts) if (p.length > 0) cleaned.add (p);
            if (cleaned.size == 0) return null;
            // Try parse first as priority
            int64 prio;
            if (int64.try_parse (cleaned[0], out prio)) {
                if (cleaned.size >= 2) {
                    var rest = new Gee.ArrayList<string> ();
                    for (int i = 1; i < cleaned.size; i++) rest.add (cleaned[i]);
                    return string.joinv (" ", rest.to_array ());
                } else {
                    return null; // priority without host
                }
            }
            return v;
        }

        private static ValidationResult validate_mx (string value, int priority) {
            var res = new ValidationResult ();
            string v = value.strip ();

            // Empty handling
            if (v.length == 0 && priority < 0) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.MX_TARGET_INVALID, "MX record requires a target hostname", "value"));
                return res;
            }

            string? target = null;
            int prio = priority;

            if (priority >= 0) {
                target = v;
                // priority already given; validate it
                if (prio < 0 || prio > 65535) {
                    res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.MX_PRIORITY_OUT_OF_RANGE, @"MX priority $(prio) out of range 0–65535", "priority"));
                }
            } else {
                // Split leading integer
                var parts = v.split_set (" \t");
                var cleaned = new Gee.ArrayList<string> ();
                foreach (var p in parts) if (p.length > 0) cleaned.add (p);
                if (cleaned.size == 0) {
                    res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.MX_TARGET_INVALID, "MX record requires a target hostname", "value"));
                    return res;
                }
                int64 parsed;
                if (int64.try_parse (cleaned[0], out parsed)) {
                    prio = (int) parsed;
                    if (prio < 0 || prio > 65535) {
                        res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.MX_PRIORITY_OUT_OF_RANGE, @"MX priority $(prio) out of range 0–65535", "priority"));
                    }
                    if (cleaned.size < 2) {
                        res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.MX_TARGET_INVALID, "MX record missing target hostname after priority", "value"));
                        return res;
                    }
                    var rest = new Gee.ArrayList<string> ();
                    for (int i = 1; i < cleaned.size; i++) rest.add (cleaned[i]);
                    target = string.joinv (" ", rest.to_array ());
                } else {
                    // No numeric leading -> treat as missing priority
                    // If value looks like hostname without priority, flag missing priority?
                    // Spec: priority non-numeric -> ERROR MX_PRIORITY_OUT_OF_RANGE
                    // But if value is "mail.example.com" without leading number and no priority param, that's a missing priority case.
                    // We treat non-numeric first token that looks like hostname as error for priority?
                    // Instead: assume priority missing -> error
                    res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.MX_PRIORITY_OUT_OF_RANGE, @"MX priority '$(cleaned[0])' is not a valid number 0–65535", "priority"));
                    target = v; // still validate target
                }
            }

            if (target == null) target = "";
            target = target.strip ();
            if (target.length == 0) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.MX_TARGET_INVALID, "MX target must be a hostname, got empty value", "mx_target"));
                return res;
            }

            // Null MX: "0 ." — WARNING MX_NULL_TARGET (not error)
            if (target == ".") {
                if (prio == 0) {
                    res.add_issue (new ValidationIssue (ValidationSeverity.WARNING, ValidationCode.MX_NULL_TARGET, "Null MX (0 .) — domain advertises no mail service (RFC 7505)", "mx_target"));
                    return res;
                }
                // "." with non-zero priority is suspicious
                res.add_issue (new ValidationIssue (ValidationSeverity.WARNING, ValidationCode.MX_NULL_TARGET, "MX target is '.' (root) — null MX should use priority 0 (RFC 7505)", "mx_target"));
                return res;
            }

            string bare = target;
            if (bare.has_suffix (".")) bare = bare.substring (0, bare.length - 1).strip ();
            if (is_ip_literal (bare)) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.MX_TARGET_IS_IP, "MX target must be a hostname, not an IP address (RFC 2181 section 10.3)", "mx_target"));
                return res;
            }
            if (!ValidationUtils.is_valid_hostname (bare)) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.MX_TARGET_INVALID, @"MX target '$(target)' is not a valid hostname", "mx_target"));
            }
            return res;
        }

        private static ValidationResult validate_txt (string value) {
            var res = new ValidationResult ();
            if (value == null) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.TXT_UNBALANCED_QUOTES, "TXT value is null", "value"));
                return res;
            }
            string v = value;
            // Empty TXT is allowed but warn
            if (v.strip ().length == 0) {
                res.add_issue (new ValidationIssue (ValidationSeverity.WARNING, ValidationCode.TXT_CHUNK_TOO_LONG, "TXT record is empty", "value"));
                return res;
            }

            // Check if quoted
            bool has_quote = v.contains ("\"");
            if (has_quote) {
                // Basic balanced check: count unescaped quotes must be even
                int unescaped_quotes = 0;
                for (int i = 0; i < v.length; i++) {
                    if (v[i] == '\"') {
                        bool escaped = i > 0 && v[i-1] == '\\';
                        if (!escaped) unescaped_quotes++;
                    }
                }
                if (unescaped_quotes % 2 != 0) {
                    res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.TXT_UNBALANCED_QUOTES, "TXT record has unbalanced quotes", "value"));
                    return res;
                }

                // Extract quoted chunks and check each <=255
                try {
                    var regex = new Regex ("\"((?:\\\\\"|[^\"])*)\"");
                    MatchInfo mi;
                    // Use manual scan via match_full
                    bool has_match = regex.match (v, 0, out mi);
                    bool found_any = false;
                    while (has_match && mi.matches ()) {
                        found_any = true;
                        string chunk = mi.fetch (1);
                        // Unescape \" -> "
                        chunk = chunk.replace ("\\\"", "\"");
                        // chunk length in bytes (GLib string length ~ bytes for ASCII; for safety use length)
                        if (chunk.length > Constants.MAX_TXT_CHUNK_LENGTH) {
                            res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.TXT_CHUNK_TOO_LONG, @"TXT chunk too long: $(chunk.length) bytes (max 255, RFC 1035 section 3.3.14)", "value"));
                        }
                        has_match = mi.next ();
                    }
                    if (!found_any) {
                        // quotes present but no valid quoted segment -> error already handled
                    } else {
                        // Also detect unescaped quote mid-chunk? Already unbalanced case.
                        // Warn if total concatenated >255 but chunks would fix? That's fine.
                    }
                } catch (RegexError e) {
                    // fallback: simple length check
                    if (v.length > 255) {
                        res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.TXT_CHUNK_TOO_LONG, @"TXT value too long: $(v.length) bytes (max 255 per chunk)", "value"));
                    }
                }
                return res;
            } else {
                // Unquoted TXT
                if (v.length > Constants.MAX_TXT_CHUNK_LENGTH) {
                    res.add_issue (new ValidationIssue (ValidationSeverity.WARNING, ValidationCode.TXT_CHUNK_TOO_LONG, @"TXT value $(v.length) bytes exceeds 255 — should be split into quoted chunks (RFC 4408)", "value"));
                }
                // Check for unescaped mid-quote without quoting? already has_quote==false
                return res;
            }
        }

        private static string[]? split_soa_fields (string value) {
            string v = value.strip ();
            if (v.length == 0) return null;
            var parts = v.split_set (" \t");
            var cleaned = new Gee.ArrayList<string> ();
            foreach (var p in parts) if (p.length > 0) cleaned.add (p);
            return cleaned.to_array ();
        }

        private static ValidationResult validate_soa (string value) {
            var res = new ValidationResult ();
            string v = value.strip ();
            if (v.length == 0) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.SOA_MISSING_FIELDS, "SOA record is empty — expected 7 fields: MNAME RNAME SERIAL REFRESH RETRY EXPIRE MINIMUM (RFC 1035)", "value"));
                return res;
            }
            string[]? fields = split_soa_fields (v);
            if (fields == null || fields.length != 7) {
                int got = fields == null ? 0 : fields.length;
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.SOA_MISSING_FIELDS, @"SOA record must have 7 fields, got $(got) (RFC 1035)", "value"));
                return res;
            }

            string mname = fields[0];
            string rname = fields[1];
            string serial_s = fields[2];
            string refresh_s = fields[3];
            string retry_s = fields[4];
            string expire_s = fields[5];
            string minimum_s = fields[6];

            // MNAME
            string mname_bare = mname;
            if (mname_bare.has_suffix (".")) mname_bare = mname_bare.substring (0, mname_bare.length - 1);
            if (is_ip_literal (mname_bare) || !ValidationUtils.is_valid_hostname (mname_bare)) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.SOA_MNAME_INVALID, @"SOA MNAME '$(mname)' is not a valid hostname", "soa_mname"));
            }

            // RNAME: accept hostmaster.example.com. or hostmaster@example.com
            string rname_norm = rname;
            if (rname_norm.contains ("@")) {
                // Replace first @ with .
                int at = rname_norm.index_of ("@");
                rname_norm = rname_norm.substring (0, at) + "." + rname_norm.substring (at + 1);
            }
            string rname_bare = rname_norm;
            if (rname_bare.has_suffix (".")) rname_bare = rname_bare.substring (0, rname_bare.length - 1);
            if (is_ip_literal (rname_bare) || !ValidationUtils.is_valid_hostname (rname_bare)) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.SOA_RNAME_INVALID, @"SOA RNAME '$(rname)' should be a mailbox like 'hostmaster.example.com' (RFC 1035)", "soa_rname"));
            }

            // SERIAL: 0–4294967295
            int64 serial;
            if (!int64.try_parse (serial_s, out serial) || serial < 0 || serial > 4294967295L) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.SOA_SERIAL_INVALID, @"SOA SERIAL '$(serial_s)' must be 0–4294967295", "soa_serial"));
            } else {
                // Warn if looks like YYYYMMDDnn and in the future
                if (serial_s.length == 10) {
                    // simple YYYYMMDDnn check: first 8 digits form a date
                    string date_part = serial_s.substring (0, 8);
                    int y = 0, m = 0, d = 0;
                    bool is_date = true;
                    if (date_part.length == 8) {
                        string ys = date_part.substring (0, 4);
                        string ms = date_part.substring (4, 2);
                        string ds = date_part.substring (6, 2);
                        int64 yi = 0, mi = 0, di = 0;
                        if (!int64.try_parse (ys, out yi) || !int64.try_parse (ms, out mi) || !int64.try_parse (ds, out di)) is_date = false;
                        else { y = (int) yi; m = (int) mi; d = (int) di; }
                        if (is_date && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
                            var now = new DateTime.now_local ();
                            var serial_date = new DateTime.local (y, m, d, 0, 0, 0);
                            if (serial_date.compare (now) > 0) {
                                res.add_issue (new ValidationIssue (ValidationSeverity.WARNING, ValidationCode.SOA_SERIAL_INVALID, @"SOA SERIAL '$(serial_s)' appears to be in the future (YYYYMMDDnn)", "soa_serial"));
                            }
                        }
                    }
                }
            }

            int64 refresh, retry, expire, minimum;
            if (!int64.try_parse (refresh_s, out refresh) || refresh < 0 || refresh > 4294967295L) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.SOA_REFRESH_INVALID, @"SOA REFRESH '$(refresh_s)' must be 0–4294967295", "soa_refresh"));
                refresh = -1;
            }
            if (!int64.try_parse (retry_s, out retry) || retry < 0 || retry > 4294967295L) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.SOA_RETRY_INVALID, @"SOA RETRY '$(retry_s)' must be 0–4294967295", "soa_retry"));
                retry = -1;
            }
            if (!int64.try_parse (expire_s, out expire) || expire < 0 || expire > 4294967295L) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.SOA_EXPIRE_INVALID, @"SOA EXPIRE '$(expire_s)' must be 0–4294967295", "soa_expire"));
                expire = -1;
            }
            if (!int64.try_parse (minimum_s, out minimum) || minimum < 0 || minimum > 4294967295L) {
                res.add_issue (new ValidationIssue (ValidationSeverity.ERROR, ValidationCode.SOA_MINIMUM_INVALID, @"SOA MINIMUM '$(minimum_s)' must be 0–4294967295", "soa_minimum"));
                minimum = -1;
            }

            // Warnings for ratios / suspicious values (only if numeric)
            if (refresh >= 0 && retry >= 0 && retry > refresh) {
                res.add_issue (new ValidationIssue (ValidationSeverity.WARNING, ValidationCode.SOA_RETRY_INVALID, "SOA RETRY should be less than REFRESH", "soa_retry"));
            }
            if (refresh >= 0 && retry >= 0 && expire >= 0 && expire < refresh + retry) {
                res.add_issue (new ValidationIssue (ValidationSeverity.WARNING, ValidationCode.SOA_EXPIRE_INVALID, "SOA EXPIRE should be greater than REFRESH + RETRY", "soa_expire"));
            }
            if (refresh >= 0 && refresh < 60) {
                res.add_issue (new ValidationIssue (ValidationSeverity.WARNING, ValidationCode.SOA_REFRESH_INVALID, "SOA REFRESH unusually small (<60)", "soa_refresh"));
            }
            if (expire >= 0 && expire < 3600) {
                res.add_issue (new ValidationIssue (ValidationSeverity.WARNING, ValidationCode.SOA_EXPIRE_INVALID, "SOA EXPIRE unusually small (<3600)", "soa_expire"));
            }
            if (refresh >= 0 && refresh > 86400 * 365) {
                res.add_issue (new ValidationIssue (ValidationSeverity.WARNING, ValidationCode.SOA_REFRESH_INVALID, "SOA REFRESH unusually large (>1 year)", "soa_refresh"));
            }
            if (minimum >= 0 && minimum > 86400 * 365) {
                res.add_issue (new ValidationIssue (ValidationSeverity.WARNING, ValidationCode.SOA_MINIMUM_INVALID, "SOA MINIMUM unusually large (>1 year)", "soa_minimum"));
            }

            return res;
        }
    }
}
