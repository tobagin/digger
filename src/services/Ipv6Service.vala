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

    /**
     * Probe status for IPv6 connectivity testing (DIGG-004)
     */
    public enum Ipv6ProbeStatus {
        UNKNOWN,
        AVAILABLE,
        UNAVAILABLE,
        REACHABLE,
        UNREACHABLE,
        TIMEOUT,
        ERROR,
        SUCCESS,
        NXDOMAIN,
        SERVFAIL;

        public string to_string () {
            switch (this) {
                case UNKNOWN: return "Unknown";
                case AVAILABLE: return "Available";
                case UNAVAILABLE: return "Unavailable";
                case REACHABLE: return "Reachable";
                case UNREACHABLE: return "Unreachable";
                case TIMEOUT: return "Timeout";
                case ERROR: return "Error";
                case SUCCESS: return "Success";
                case NXDOMAIN: return "NXDOMAIN";
                case SERVFAIL: return "SERVFAIL";
                default: return "Unknown";
            }
        }
    }

    /**
     * Result model for IPv6 connectivity testing.
     * Co-located with service per ThreatIntelData pattern in ThreatIntelService.vala
     */
    public class Ipv6TestResult : Object {
        public bool ipv6_available { get; set; default = false; }
        public bool? reachable = null;
        public int probe_latency_ms { get; set; default = 0; }
        public Gee.ArrayList<DnsRecord> aaaa_records { get; set; }
        public string resolver_used { get; set; default = Constants.IPV6_PROBE_RESOLVER; }
        public string? error_message { get; set; default = null; }
        public Ipv6ProbeStatus status { get; set; default = Ipv6ProbeStatus.UNKNOWN; }
        public DateTime timestamp { get; set; }
        public bool from_cache { get; set; default = false; }

        public Ipv6TestResult () {
            aaaa_records = new Gee.ArrayList<DnsRecord> ();
            timestamp = new DateTime.now_local ();
        }
    }

    /**
     * Delegate for injectable socket factory (testability)
     */
    public delegate bool Ipv6SocketFactory () throws GLib.Error;

    public class Ipv6Service : Object {
        private static Ipv6Service? instance = null;

        public static Ipv6Service get_instance () {
            if (instance == null) {
                instance = new Ipv6Service ();
            }
            return instance;
        }

        public signal void probe_completed (Ipv6TestResult result);
        public signal void probe_failed (string error_message);

        // Test injection points
        private Ipv6SocketFactory? socket_factory = null;
        private string? mock_stdout = null;
        private string? mock_stderr = null;
        private int mock_exit = 0;
        private string? mock_throw_msg = null;
        private bool mock_throw_is_timeout = false;
        private int mock_call_count = 0;
        // Sequence mock: for two-call scenario (probe + AAAA), hold two results
        private string? mock_stdout2 = null;
        private string? mock_stderr2 = null;
        private int mock_exit2 = 0;
        private bool use_sequence = false;
        private bool force_available = false;
        private bool force_unavailable = false;
        private bool has_force_available = false;
        private bool has_force_unavailable = false;

        // Cached dig availability
        private static bool? dig_available_cache = null;

        public Ipv6Service () {
        }

        // ---- Test injection helpers ----

        public void set_socket_factory (owned Ipv6SocketFactory? factory) {
            socket_factory = (owned) factory;
        }

        public void set_mock_dig_result (string stdout_text, string stderr_text, int exit_status) {
            mock_stdout = stdout_text;
            mock_stderr = stderr_text;
            mock_exit = exit_status;
            mock_throw_msg = null;
            use_sequence = false;
        }

        public void set_mock_dig_sequence (string stdout1, string stderr1, int exit1, string stdout2, string stderr2, int exit2) {
            mock_stdout = stdout1;
            mock_stderr = stderr1;
            mock_exit = exit1;
            mock_stdout2 = stdout2;
            mock_stderr2 = stderr2;
            mock_exit2 = exit2;
            mock_throw_msg = null;
            use_sequence = true;
            mock_call_count = 0;
        }

        public void set_mock_throw (string msg, bool is_timeout = false) {
            mock_throw_msg = msg;
            mock_throw_is_timeout = is_timeout;
            mock_stdout = null;
        }

        public void clear_mock () {
            mock_stdout = null;
            mock_stderr = null;
            mock_throw_msg = null;
            use_sequence = false;
            mock_call_count = 0;
        }

        public int get_mock_call_count () { return mock_call_count; }

        public void set_force_available (bool available) {
            force_available = available;
            has_force_available = true;
            has_force_unavailable = false;
        }

        public void set_force_unavailable (bool unavailable) {
            force_unavailable = unavailable;
            has_force_unavailable = true;
            has_force_available = false;
        }

        public void clear_force_flags () {
            has_force_available = false;
            has_force_unavailable = false;
            force_available = false;
            force_unavailable = false;
        }

        public static void reset_dig_cache () {
            dig_available_cache = null;
        }

        // ---- Dual-stack detection ----

        /**
         * Synchronous, exception-safe, no network I/O, <50ms.
         * Returns true if IPv6 stack is available.
         */
        public bool is_ipv6_available () {
            if (has_force_available && force_available) return true;
            if (has_force_unavailable && force_unavailable) return false;

            if (socket_factory != null) {
                try {
                    return socket_factory ();
                } catch (GLib.Error e) {
                    return false;
                }
            }

            try {
                var socket = new Socket (SocketFamily.IPV6, SocketType.DATAGRAM, SocketProtocol.DEFAULT);
                // Socket created successfully means IPv6 stack available
                try { socket.close (); } catch (Error e) {}
                return true;
            } catch (GLib.Error e) {
                return false;
            }
        }

        // ---- Dig availability ----

        private async bool check_dig_available_async () {
            if (dig_available_cache != null) return dig_available_cache;

            if (mock_stdout != null || mock_throw_msg != null || use_sequence) {
                // When mock is injected, assume dig is available for testing
                dig_available_cache = true;
                return true;
            }

            try {
                string stdout_text;
                string stderr_text;
                int exit_status;
                // Use which/dig check via Subprocess
                string[] args = {"which", "dig"};
                var proc = new Subprocess.newv (args, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                Bytes stdout_bytes, stderr_bytes;
                yield proc.communicate_async (null, null, out stdout_bytes, out stderr_bytes);
                stdout_text = ValidationUtils.bytes_to_string (stdout_bytes);
                dig_available_cache = proc.get_exit_status () == 0;
                return dig_available_cache;
            } catch (Error e) {
                dig_available_cache = false;
                return false;
            }
        }

        // ---- Internal dig execution ----

        private async bool run_dig_async (string[] args, out string stdout_text, out string stderr_text, out int exit_status) throws GLib.Error {
            if (mock_throw_msg != null) {
                mock_call_count++;
                if (mock_throw_is_timeout) {
                    throw new IOError.TIMED_OUT (mock_throw_msg);
                } else {
                    throw new IOError.FAILED (mock_throw_msg);
                }
            }
            if (mock_stdout != null || use_sequence) {
                mock_call_count++;
                if (use_sequence) {
                    if (mock_call_count == 1) {
                        stdout_text = mock_stdout;
                        stderr_text = mock_stderr;
                        exit_status = mock_exit;
                    } else {
                        stdout_text = mock_stdout2;
                        stderr_text = mock_stderr2;
                        exit_status = mock_exit2;
                    }
                } else {
                    stdout_text = mock_stdout;
                    stderr_text = mock_stderr;
                    exit_status = mock_exit;
                }
                return true;
            }

            var proc = new Subprocess.newv (args, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            Bytes stdout_bytes, stderr_bytes;
            yield proc.communicate_async (null, null, out stdout_bytes, out stderr_bytes);
            stdout_text = ValidationUtils.bytes_to_string (stdout_bytes);
            stderr_text = ValidationUtils.bytes_to_string (stderr_bytes);
            exit_status = proc.get_exit_status ();
            return true;
        }

        // ---- Reachability probe ----

        public async Ipv6TestResult probe_reachability_async (Cancellable? cancellable = null) {
            var result = new Ipv6TestResult ();
            result.ipv6_available = is_ipv6_available ();
            result.resolver_used = Constants.IPV6_PROBE_RESOLVER;
            result.timestamp = new DateTime.now_local ();

            if (!result.ipv6_available) {
                result.status = Ipv6ProbeStatus.UNAVAILABLE;
                result.reachable = false;
                result.error_message = ValidationUtils.sanitize_error_message ("IPv6 not available on this system");
                return result;
            }

            if (!yield check_dig_available_async ()) {
                result.status = Ipv6ProbeStatus.ERROR;
                result.reachable = null;
                result.error_message = ValidationUtils.sanitize_error_message ("dig command not found");
                return result;
            }

            var timer = new Timer ();
            timer.start ();

            try {
                string[] args = {
                    "dig", "-6",
                    "+time=%d".printf (Constants.IPV6_PROBE_TIMEOUT_SECONDS),
                    "+tries=1",
                    Constants.IPV6_PROBE_DOMAIN, "AAAA",
                    "@" + Constants.IPV6_PROBE_RESOLVER
                };

                string stdout_text;
                string stderr_text;
                int exit_status;

                if (cancellable != null && cancellable.is_cancelled ()) {
                    result.status = Ipv6ProbeStatus.TIMEOUT;
                    result.error_message = ValidationUtils.sanitize_error_message ("Probe cancelled");
                    return result;
                }

                bool ok = yield run_dig_async (args, out stdout_text, out stderr_text, out exit_status);

                timer.stop ();
                result.probe_latency_ms = (int) (timer.elapsed () * 1000);

                if (!ok) {
                    result.status = Ipv6ProbeStatus.ERROR;
                    result.reachable = false;
                    result.error_message = ValidationUtils.sanitize_error_message (stderr_text ?? "Probe failed");
                    return result;
                }

                // Check cancellable after network
                if (cancellable != null && cancellable.is_cancelled ()) {
                    result.status = Ipv6ProbeStatus.TIMEOUT;
                    result.error_message = ValidationUtils.sanitize_error_message ("Probe cancelled");
                    return result;
                }

                if (exit_status == 9 || (stderr_text != null && stderr_text.contains ("timed out")) || (stdout_text != null && stdout_text.contains ("connection timed out"))) {
                    result.status = Ipv6ProbeStatus.TIMEOUT;
                    result.reachable = false;
                    result.error_message = ValidationUtils.sanitize_error_message ("IPv6 probe timed out");
                    return result;
                }

                if (stderr_text != null && (stderr_text.contains ("Network is unreachable") || stderr_text.contains ("ENETUNREACH"))) {
                    result.status = Ipv6ProbeStatus.UNREACHABLE;
                    result.reachable = false;
                    result.error_message = ValidationUtils.sanitize_error_message (stderr_text);
                    return result;
                }

                // Parse output for success - if we got any answer, it's reachable
                if (stdout_text != null && stdout_text.contains ("ANSWER:")) {
                    result.reachable = true;
                    result.status = Ipv6ProbeStatus.REACHABLE;
                    return result;
                }

                // Check header status
                var header_status = parse_header_status (stdout_text);
                switch (header_status) {
                    case "NXDOMAIN":
                        result.status = Ipv6ProbeStatus.NXDOMAIN;
                        result.reachable = true; // resolver reachable but domain not found
                        result.error_message = ValidationUtils.sanitize_error_message ("Domain not found");
                        return result;
                    case "SERVFAIL":
                        result.status = Ipv6ProbeStatus.SERVFAIL;
                        result.reachable = false;
                        result.error_message = ValidationUtils.sanitize_error_message ("Server failure");
                        return result;
                    default:
                        break;
                }

                if (exit_status != 0) {
                    result.status = Ipv6ProbeStatus.UNREACHABLE;
                    result.reachable = false;
                    result.error_message = ValidationUtils.sanitize_error_message (stderr_text ?? "Probe failed with exit %d".printf (exit_status));
                    return result;
                }

                result.reachable = true;
                result.status = Ipv6ProbeStatus.REACHABLE;
                return result;

            } catch (GLib.Error e) {
                timer.stop ();
                result.probe_latency_ms = (int) (timer.elapsed () * 1000);
                string msg = e.message ?? "Probe error";
                if (msg.contains ("timed out") || msg.contains ("TIMEOUT") || e is IOError.TIMED_OUT) {
                    result.status = Ipv6ProbeStatus.TIMEOUT;
                    result.reachable = false;
                } else if (msg.contains ("Network is unreachable") || msg.contains ("ENETUNREACH")) {
                    result.status = Ipv6ProbeStatus.UNREACHABLE;
                    result.reachable = false;
                } else {
                    result.status = Ipv6ProbeStatus.ERROR;
                    result.reachable = false;
                }
                result.error_message = ValidationUtils.sanitize_error_message (msg);
                return result;
            }
        }

        // ---- AAAA verification ----

        public async Ipv6TestResult verify_aaaa_async (string domain, Cancellable? cancellable = null) {
            var result = new Ipv6TestResult ();
            result.ipv6_available = is_ipv6_available ();
            result.resolver_used = Constants.IPV6_PROBE_RESOLVER;
            result.timestamp = new DateTime.now_local ();

            if (!result.ipv6_available) {
                result.status = Ipv6ProbeStatus.UNAVAILABLE;
                result.reachable = false;
                result.error_message = ValidationUtils.sanitize_error_message ("IPv6 not available on this system");
                return result;
            }

            // Probe reachability first
            var probe = yield probe_reachability_async (cancellable);
            if (probe.status == Ipv6ProbeStatus.TIMEOUT) {
                result.probe_latency_ms = probe.probe_latency_ms;
                result.status = Ipv6ProbeStatus.TIMEOUT;
                result.reachable = false;
                result.error_message = probe.error_message;
                return result;
            }
            if (probe.status == Ipv6ProbeStatus.UNREACHABLE || probe.status == Ipv6ProbeStatus.ERROR) {
                if (probe.status == Ipv6ProbeStatus.ERROR && probe.error_message != null && probe.error_message.contains ("dig")) {
                    result.status = Ipv6ProbeStatus.ERROR;
                    result.reachable = null;
                    result.error_message = probe.error_message;
                    return result;
                }
                result.probe_latency_ms = probe.probe_latency_ms;
                result.status = probe.status;
                result.reachable = false;
                result.error_message = probe.error_message;
                return result;
            }

            if (!yield check_dig_available_async ()) {
                result.status = Ipv6ProbeStatus.ERROR;
                result.reachable = null;
                result.error_message = ValidationUtils.sanitize_error_message ("dig command not found");
                return result;
            }

            var timer = new Timer ();
            timer.start ();

            try {
                if (cancellable != null && cancellable.is_cancelled ()) {
                    result.status = Ipv6ProbeStatus.TIMEOUT;
                    result.error_message = ValidationUtils.sanitize_error_message ("Probe cancelled");
                    return result;
                }

                string[] args = {
                    "dig", "-6",
                    "+time=%d".printf (Constants.IPV6_AAAA_TIMEOUT_SECONDS),
                    "+tries=1",
                    domain, "AAAA",
                    "@" + Constants.IPV6_PROBE_RESOLVER
                };

                string stdout_text;
                string stderr_text;
                int exit_status;
                bool ok = yield run_dig_async (args, out stdout_text, out stderr_text, out exit_status);

                timer.stop ();
                result.probe_latency_ms = (int) (timer.elapsed () * 1000);

                if (cancellable != null && cancellable.is_cancelled ()) {
                    result.status = Ipv6ProbeStatus.TIMEOUT;
                    result.error_message = ValidationUtils.sanitize_error_message ("Probe cancelled");
                    return result;
                }

                if (!ok) {
                    result.status = Ipv6ProbeStatus.ERROR;
                    result.reachable = false;
                    result.error_message = ValidationUtils.sanitize_error_message (stderr_text ?? "AAAA query failed");
                    return result;
                }

                if (exit_status == 9 || (stderr_text != null && stderr_text.contains ("timed out"))) {
                    result.status = Ipv6ProbeStatus.TIMEOUT;
                    result.reachable = false;
                    result.error_message = ValidationUtils.sanitize_error_message ("AAAA query timed out");
                    return result;
                }

                // Check header status first
                var header_status = parse_header_status (stdout_text);
                if (header_status == "NXDOMAIN") {
                    result.status = Ipv6ProbeStatus.NXDOMAIN;
                    result.reachable = true;
                    result.error_message = ValidationUtils.sanitize_error_message ("Domain not found: " + domain);
                    return result;
                }
                if (header_status == "SERVFAIL") {
                    result.status = Ipv6ProbeStatus.SERVFAIL;
                    result.reachable = true;
                    result.error_message = ValidationUtils.sanitize_error_message ("Server failure for " + domain);
                    return result;
                }

                // Parse AAAA records from answer section
                var records = parse_aaaa_records (stdout_text, domain);
                result.aaaa_records = records;
                result.reachable = true;

                if (records.size > 0) {
                    result.status = Ipv6ProbeStatus.SUCCESS;
                } else {
                    // NOERROR but zero answers - empty
                    result.status = Ipv6ProbeStatus.SUCCESS;
                    // Keep reachable true, but status SUCCESS with empty list distinguishes empty vs populated
                }
                return result;

            } catch (GLib.Error e) {
                timer.stop ();
                result.probe_latency_ms = (int) (timer.elapsed () * 1000);
                string msg = e.message ?? "AAAA verification error";
                if (msg.contains ("timed out") || e is IOError.TIMED_OUT) {
                    result.status = Ipv6ProbeStatus.TIMEOUT;
                    result.reachable = false;
                } else {
                    result.status = Ipv6ProbeStatus.ERROR;
                    result.reachable = false;
                }
                result.error_message = ValidationUtils.sanitize_error_message (msg);
                return result;
            }
        }

        // ---- Helpers ----

        private string parse_header_status (string? output) {
            if (output == null) return "NOERROR";
            // Look for "status: NXDOMAIN" etc in dig output header
            try {
                var regex = new Regex ("status:\\s*(\\w+)", RegexCompileFlags.CASELESS);
                MatchInfo match;
                if (regex.match (output, 0, out match)) {
                    return match.fetch (1).up ();
                }
            } catch (RegexError e) {}
            return "NOERROR";
        }

        /**
         * Minimal AAAA parser — extracts answer section AAAA records.
         * Citing src/services/DnsQuery.vala:parse_dig_output for pattern.
         */
        public Gee.ArrayList<DnsRecord> parse_aaaa_records (string? output, string domain) {
            var records = new Gee.ArrayList<DnsRecord> ();
            if (output == null) return records;

            bool in_answer = false;
            string[] lines = output.split ("\n");
            foreach (string line in lines) {
                string trimmed = line.strip ();
                if (trimmed.has_prefix (";; ANSWER SECTION:")) {
                    in_answer = true;
                    continue;
                }
                if (trimmed.has_prefix (";;") && in_answer) {
                    // End of answer section
                    in_answer = false;
                    continue;
                }
                if (!in_answer) continue;
                if (trimmed.length == 0 || trimmed.has_prefix (";")) continue;

                // Expected: name TTL IN AAAA value — handle tabs and spaces
                string normalized = trimmed.replace ("\t", " ");
                string[] raw = normalized.split (" ");
                var filtered = new Gee.ArrayList<string> ();
                foreach (string p in raw) {
                    if (p.strip ().length > 0) filtered.add (p.strip ());
                }
                if (filtered.size < 5) continue;
                string[] parts = new string[filtered.size];
                for (int i = 0; i < filtered.size; i++) parts[i] = filtered[i];

                // Try tab-split first, fallback to space-split
                // After split, look for AAAA type token
                int aaaa_idx = -1;
                for (int i = 0; i < parts.length; i++) {
                    if (parts[i].strip ().up () == "AAAA") {
                        aaaa_idx = i;
                        break;
                    }
                }
                if (aaaa_idx < 0) continue;
                if (aaaa_idx + 1 >= parts.length) continue;

                string value = parts[aaaa_idx + 1].strip ();
                // Filter via is_valid_ipv6
                if (!ValidationUtils.is_valid_ipv6 (value)) continue;

                string name = parts[0].strip ();
                int ttl = 0;
                // TTL is usually at index 1
                if (parts.length > 1) {
                    int.try_parse (parts[1].strip (), out ttl);
                }

                var rec = new DnsRecord (name, RecordType.AAAA, ttl, value);
                records.add (rec);
            }
            return records;
        }

        // Synchronous helper for tests (pure logic)
        public static Ipv6ProbeStatus map_error_to_status (string error_msg) {
            if (error_msg.contains ("timed out") || error_msg.contains ("TIMEOUT")) return Ipv6ProbeStatus.TIMEOUT;
            if (error_msg.contains ("Network is unreachable") || error_msg.contains ("ENETUNREACH")) return Ipv6ProbeStatus.UNREACHABLE;
            return Ipv6ProbeStatus.ERROR;
        }
    }
}
