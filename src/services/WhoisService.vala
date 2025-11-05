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
    public class WhoisService : Object {
        private const string WHOIS_COMMAND = "whois";
        private const int DEFAULT_TIMEOUT = 30;

        // Cached whois availability check
        private static bool? whois_available_cache = null;

        private GLib.Settings settings;
        private WhoisCache cache;

        public signal void query_completed (WhoisData result);
        public signal void query_failed (string error_message);

        public WhoisService () {
            settings = new GLib.Settings (Config.APP_ID);
            cache = new WhoisCache ();
        }

        public async WhoisData? perform_whois_query (string domain) {
            // Check cache first
            var cached_data = cache.get (domain);
            if (cached_data != null) {
                cached_data.from_cache = true;
                query_completed (cached_data);
                return cached_data;
            }

            // Check if whois command exists
            if (!yield check_whois_available_async ()) {
                query_failed ("whois command not found. Please install whois package.");
                return null;
            }

            var result = new WhoisData ();
            result.domain = domain;

            try {
                string[] command_args = build_whois_command (domain);

                string standard_output;
                string standard_error;
                int exit_status;

                bool success = yield run_command_async (command_args, out standard_output,
                                                      out standard_error, out exit_status);

                result.raw_output = standard_output;

                if (!success || exit_status != 0) {
                    critical ("WHOIS query failed for %s: %s", domain, standard_error);
                    query_failed ("WHOIS query failed. The domain may not be registered or WHOIS server is unavailable.");
                    return result;
                }

                // Parse WHOIS output
                parse_whois_output (standard_output, result);

                // Cache the result
                cache.put (domain, result);

                query_completed (result);
                return result;

            } catch (Error e) {
                critical ("Error executing WHOIS query for %s: %s", domain, e.message);
                query_failed ("WHOIS query execution error: " + e.message);
                return result;
            }
        }

        private string[] build_whois_command (string domain) {
            var args = new Gee.ArrayList<string> ();
            args.add (WHOIS_COMMAND);
            args.add (domain);

            // Convert to string array
            string[] result_args = new string[args.size];
            for (int i = 0; i < args.size; i++) {
                result_args[i] = args[i];
            }
            return result_args;
        }

        private async bool run_command_async (string[] command_args, out string standard_output,
                                            out string standard_error, out int exit_status) throws Error {
            Subprocess process = new Subprocess.newv (command_args, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);

            // Get timeout from settings
            var timeout_seconds = (settings != null) ? settings.get_int ("whois-timeout") : DEFAULT_TIMEOUT;

            Bytes stdout_bytes, stderr_bytes;

            // Create a timeout source
            var timeout_source = new TimeoutSource.seconds (timeout_seconds);
            var cancellable = new Cancellable ();

            timeout_source.set_callback (() => {
                cancellable.cancel ();
                return Source.REMOVE;
            });
            timeout_source.attach (MainContext.default ());

            try {
                yield process.communicate_async (null, cancellable, out stdout_bytes, out stderr_bytes);
                timeout_source.destroy ();
            } catch (Error e) {
                timeout_source.destroy ();
                if (e is IOError.CANCELLED) {
                    throw new IOError.TIMED_OUT ("WHOIS query timed out after %d seconds", timeout_seconds);
                }
                throw e;
            }

            standard_output = (string) stdout_bytes.get_data();
            standard_error = (string) stderr_bytes.get_data();
            exit_status = process.get_exit_status ();

            return true;
        }

        private void parse_whois_output (string output, WhoisData result) {
            var lines = output.split ("\n");

            foreach (string line in lines) {
                string trimmed_line = line.strip ();

                if (trimmed_line.length == 0) {
                    continue;
                }

                // Skip comment lines
                if (trimmed_line.has_prefix ("%") || trimmed_line.has_prefix ("#")) {
                    continue;
                }

                // Check for privacy protection indicators
                if (trimmed_line.down ().contains ("privacy") ||
                    trimmed_line.down ().contains ("redacted") ||
                    trimmed_line.down ().contains ("data protected")) {
                    result.privacy_protected = true;
                }

                // Parse common WHOIS fields (case-insensitive)
                string lower_line = trimmed_line.down ();

                // Registrar
                if (result.registrar == null &&
                    (lower_line.has_prefix ("registrar:") ||
                     lower_line.has_prefix ("registrar name:"))) {
                    result.registrar = extract_field_value (trimmed_line);
                }

                // Creation date
                if (result.created_date == null &&
                    (lower_line.has_prefix ("creation date:") ||
                     lower_line.has_prefix ("created:") ||
                     lower_line.has_prefix ("registered:"))) {
                    result.created_date = extract_field_value (trimmed_line);
                }

                // Updated date
                if (result.updated_date == null &&
                    (lower_line.has_prefix ("updated date:") ||
                     lower_line.has_prefix ("last updated:") ||
                     lower_line.has_prefix ("modified:"))) {
                    result.updated_date = extract_field_value (trimmed_line);
                }

                // Expiry date
                if (result.expires_date == null &&
                    (lower_line.has_prefix ("registry expiry date:") ||
                     lower_line.has_prefix ("registrar registration expiration date:") ||
                     lower_line.has_prefix ("expiration date:") ||
                     lower_line.has_prefix ("expires:"))) {
                    result.expires_date = extract_field_value (trimmed_line);
                }

                // Nameservers
                if (lower_line.has_prefix ("name server:") ||
                    lower_line.has_prefix ("nserver:") ||
                    lower_line.has_prefix ("nameserver:")) {
                    string ns = extract_field_value (trimmed_line);
                    if (ns != null && ns.length > 0 && !result.nameservers.contains (ns.down ())) {
                        result.nameservers.add (ns.down ());
                    }
                }

                // Domain status
                if (lower_line.has_prefix ("domain status:") ||
                    lower_line.has_prefix ("status:")) {
                    string status = extract_field_value (trimmed_line);
                    if (status != null && status.length > 0 && !result.status.contains (status)) {
                        result.status.add (status);
                    }
                }

                // Registrant information (often redacted, but try anyway)
                if (result.registrant_name == null &&
                    (lower_line.has_prefix ("registrant name:") ||
                     lower_line.has_prefix ("registrant:"))) {
                    result.registrant_name = extract_field_value (trimmed_line);
                }

                if (result.registrant_org == null &&
                    (lower_line.has_prefix ("registrant organization:") ||
                     lower_line.has_prefix ("registrant org:"))) {
                    result.registrant_org = extract_field_value (trimmed_line);
                }

                if (result.registrant_email == null &&
                    lower_line.has_prefix ("registrant email:")) {
                    result.registrant_email = extract_field_value (trimmed_line);
                }
            }
        }

        private string? extract_field_value (string line) {
            var parts = line.split (":", 2);
            if (parts.length >= 2) {
                string value = parts[1].strip ();
                if (value.length > 0) {
                    return value;
                }
            }
            return null;
        }

        private async bool check_whois_available_async () {
            // Check cache first
            if (whois_available_cache != null) {
                return whois_available_cache;
            }

            // Perform async check
            try {
                string standard_output;
                string standard_error;
                int exit_status;

                yield run_command_async ({"which", WHOIS_COMMAND},
                                        out standard_output,
                                        out standard_error,
                                        out exit_status);

                // Cache the result
                whois_available_cache = (exit_status == 0);

                if (whois_available_cache) {
                    message ("whois command found and cached");
                } else {
                    warning ("whois command not found");
                }

                return whois_available_cache;
            } catch (Error e) {
                whois_available_cache = false;
                warning ("Error checking whois availability: %s", e.message);
                return false;
            }
        }

        public void clear_cache () {
            cache.clear ();
        }
    }

    public class WhoisCache : Object {
        private const int MAX_CACHE_SIZE = 100;
        private const int DEFAULT_TTL_SECONDS = 86400; // 24 hours

        private class CacheEntry {
            public WhoisData data;
            public DateTime expires_at;

            public CacheEntry (WhoisData data, DateTime expires_at) {
                this.data = data;
                this.expires_at = expires_at;
            }

            public bool is_expired () {
                return new DateTime.now_local ().compare (expires_at) >= 0;
            }
        }

        private Gee.HashMap<string, CacheEntry> cache_map;
        private Gee.ArrayList<string> access_order; // For LRU eviction
        private GLib.Settings settings;

        public WhoisCache () {
            cache_map = new Gee.HashMap<string, CacheEntry> ();
            access_order = new Gee.ArrayList<string> ();
            settings = new GLib.Settings (Config.APP_ID);
        }

        public WhoisData? get (string domain) {
            string key = domain.down ();

            if (!cache_map.has_key (key)) {
                return null;
            }

            var entry = cache_map.get (key);

            // Check if expired
            if (entry.is_expired ()) {
                cache_map.unset (key);
                access_order.remove (key);
                return null;
            }

            // Update access order (move to end for LRU)
            access_order.remove (key);
            access_order.add (key);

            return entry.data;
        }

        public void put (string domain, WhoisData data) {
            string key = domain.down ();

            // Get TTL from settings
            var ttl_seconds = settings.get_int ("whois-cache-ttl");
            var expires_at = new DateTime.now_local ().add_seconds (ttl_seconds);

            var entry = new CacheEntry (data, expires_at);

            // Remove old entry if exists
            if (cache_map.has_key (key)) {
                access_order.remove (key);
            }

            // Evict oldest if at max size
            while (access_order.size >= MAX_CACHE_SIZE) {
                string oldest = access_order.get (0);
                cache_map.unset (oldest);
                access_order.remove_at (0);
            }

            // Add new entry
            cache_map.set (key, entry);
            access_order.add (key);
        }

        public void clear () {
            cache_map.clear ();
            access_order.clear ();
        }
    }
}
