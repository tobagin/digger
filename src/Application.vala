/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

// External function declarations for GResource
extern GLib.Resource digger_get_resource ();

namespace Digger {
    public class Application : Adw.Application {
        private Window? main_window = null;
        private QueryHistory query_history;
        private uint release_notes_timeout_id = 0;

        public Application () {
            Object (
                application_id: Config.APP_ID,
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }

        construct {
            // Register resources
            register_resources ();
            
            ActionEntry[] action_entries = {
                { "about", on_about_action },
                { "preferences", on_preferences_action },
                { "shortcuts", on_shortcuts_action },
                { "dnsbl-check", on_dnsbl_check_action },
                { "performance-monitor", on_performance_monitor_action },
                { "propagation-check", on_propagation_check_action },
                { "subdomain-scan", on_subdomain_scan_action },
                { "dnssec-chain", on_dnssec_chain_action },
                { "domain-monitor", on_domain_monitor_action },
                { "quit", quit }
            };
            add_action_entries (action_entries, this);

            string[,] accels = {
                { "app.quit", "<primary>q" },
                { "win.new-query", "<primary>l" },
                { "win.repeat-query", "<primary>r" },
                { "win.clear-results", "Escape" },
                { "app.shortcuts", "<primary>question" },
                { "app.about", "F1" },
                { "app.preferences", "<primary>comma" },
                { "win.batch-lookup", "<primary>b" },
                { "win.compare-servers", "<primary>m" },
                { "app.dnsbl-check", "<primary><shift>b" },
                { "app.performance-monitor", "<primary><shift>p" },
                { "app.propagation-check", "<primary><shift>g" },
                { "app.subdomain-scan", "<primary><shift>e" },
                { "app.dnssec-chain", "<primary><shift>k" },
                { "app.domain-monitor", "<primary><shift>w" }
            };
            for (int i = 0; i < accels.length[0]; i++) {
                string[] accel = { accels[i, 1] };
                set_accels_for_action (accels[i, 0], accel);
            }
        }
        
        private void register_resources () {
            var resource = digger_get_resource ();
            GLib.resources_register (resource);
        }

        public override void activate () {
            base.activate ();

            if (main_window == null) {
                query_history = new QueryHistory ();
                main_window = new Window (this, query_history);
                // Start watching persisted domains for the session.
                MonitorService.get_instance ();
            }

            main_window.present ();

            // Show release notes if this is a new version
            if (should_show_release_notes ()) {
                // Small delay to ensure main window is fully presented
                release_notes_timeout_id = Timeout.add (Constants.RELEASE_NOTES_DELAY_MS, () => {
                    show_about_with_release_notes ();
                    release_notes_timeout_id = 0;
                    return false;
                });
            }
        }

        private bool should_show_release_notes () {
            var settings = new Settings (Config.APP_ID);
            string last_version = settings.get_string ("last-version-shown");
            string current_version = Config.VERSION;

            // Show if this is the first run (empty last version) or version has changed
            if (last_version == "" || last_version != current_version) {
                settings.set_string ("last-version-shown", current_version);
                return true;
            }

            return false;
        }

        private void show_about_with_release_notes () {
            AboutDialog.show (main_window);
        }

        private void on_about_action () {
            AboutDialog.show (main_window);
        }

        private void on_preferences_action () {
            var preferences_dialog = new PreferencesDialog (main_window);
            preferences_dialog.present (main_window);
        }

        private void on_shortcuts_action () {
            ShortcutsDialog.present (main_window);
        }

        private void on_dnsbl_check_action () {
            var dnsbl_dialog = new DnsblDialog (main_window);
            dnsbl_dialog.present (main_window);
        }

        private void on_performance_monitor_action () {
            var perf_dialog = new PerformanceDialog (main_window);
            perf_dialog.present (main_window);
        }

        private void on_propagation_check_action () {
            var dialog = new PropagationDialog (main_window);
            dialog.present (main_window);
        }

        private void on_subdomain_scan_action () {
            var dialog = new SubdomainDialog (main_window);
            dialog.present (main_window);
        }

        private void on_dnssec_chain_action () {
            var dialog = new DnssecDialog (main_window);
            dialog.present (main_window);
        }

        private void on_domain_monitor_action () {
            var dialog = new MonitorDialog (main_window);
            dialog.present (main_window);
        }
    }
}
