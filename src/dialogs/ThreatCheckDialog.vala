/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

using Gtk;
using Adw;

namespace Digger {
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/threat-check-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/threat-check-dialog.ui")]
#endif
    public class ThreatCheckDialog : Adw.Dialog {
        [GtkChild]
        private unowned Adw.EntryRow input_entry;

        [GtkChild]
        private unowned Gtk.Box results_box;

        [GtkChild]
        private unowned Gtk.Label status_label;

        [GtkChild]
        private unowned Gtk.Spinner spinner;

        private ThreatIntelService threat_service;

        public ThreatCheckDialog (Gtk.Widget? parent) {
            threat_service = new ThreatIntelService ();
        }

        [GtkCallback]
        private void on_check_clicked () {
            string input = input_entry.text.strip ();
            if (input.length == 0) return;
            perform_check.begin (input);
        }

        private async void perform_check (string target) {
            spinner.visible = true;
            spinner.start ();
            status_label.visible = true;
            status_label.label = "Checking threat intelligence...";
            input_entry.sensitive = false;

            var child = results_box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                results_box.remove (child);
                child = next;
            }

            var data = yield threat_service.perform_check (target);

            if (data == null) {
                var err_group = new Adw.PreferencesGroup ();
                var err_row = new Adw.ActionRow ();
                err_row.title = "Error";
                err_row.subtitle = "Invalid input or check failed";
                err_group.add (err_row);
                results_box.append (err_group);
            } else {
                var group = build_result_group (data);
                results_box.append (group);
            }

            spinner.stop ();
            spinner.visible = false;
            status_label.visible = false;
            input_entry.sensitive = true;
        }

        private Adw.PreferencesGroup build_result_group (ThreatIntelData data) {
            var group = new Adw.PreferencesGroup ();
            group.title = "Threat Intelligence";
            if (data.from_cache) {
                group.description = "Cached data";
            } else {
                group.description = "Fresh data";
            }

            var verdict_row = new Adw.ActionRow ();
            verdict_row.title = data.get_verdict_label ();
            if (data.safety_score >= 0) {
                verdict_row.subtitle = "Safety score: %d/100".printf (data.safety_score);
            } else if (data.error_message != null) {
                verdict_row.subtitle = data.error_message;
            } else {
                verdict_row.subtitle = "No threat data available";
            }
            string css = data.get_verdict_css_class ();
            if (css.length > 0) {
                verdict_row.add_css_class (css);
            }
            group.add (verdict_row);

            if (data.level == ThreatLevel.RATE_LIMITED) {
                var rl_row = new Adw.ActionRow ();
                rl_row.title = "Rate limited";
                rl_row.subtitle = data.error_message ?? "VirusTotal rate limit reached - try again later";
                group.add (rl_row);
            } else if (data.level == ThreatLevel.ERROR) {
                var err_row = new Adw.ActionRow ();
                err_row.title = "Error";
                err_row.subtitle = data.error_message ?? "Check failed";
                group.add (err_row);
            } else if (data.level == ThreatLevel.UNKNOWN && data.error_message != null) {
                var unk_row = new Adw.ActionRow ();
                unk_row.title = "Unknown";
                unk_row.subtitle = data.error_message;
                group.add (unk_row);
            }

            if (data.vt_malicious == 0 && data.vt_harmless == 0 && data.vt_suspicious == 0 && data.vt_reputation == null) {
                if (data.level == ThreatLevel.UNKNOWN) {
                    var hint_row = new Adw.ActionRow ();
                    hint_row.title = "VirusTotal API key not configured";
                    hint_row.subtitle = "Configure your key in Preferences, or rely on Spamhaus DBL (keyless). Get a key at https://www.virustotal.com/gui/my-apikey";
                    hint_row.activatable = true;
                    hint_row.activated.connect (() => {
                        var root = this.get_root ();
                        if (root is Gtk.Window) {
                            Gtk.show_uri ((Gtk.Window) root, "https://www.virustotal.com/gui/my-apikey", Gdk.CURRENT_TIME);
                        }
                    });
                    group.add (hint_row);
                }
            }

            bool has_vt_data = (data.vt_harmless > 0 || data.vt_malicious > 0 || data.vt_suspicious > 0 || data.vt_undetected > 0 || data.vt_reputation != null);
            if (has_vt_data) {
                var vt_counts_row = new Adw.ActionRow ();
                vt_counts_row.title = "VirusTotal detections";
                vt_counts_row.subtitle = "Harmless: %d, Malicious: %d, Suspicious: %d, Undetected: %d".printf (data.vt_harmless, data.vt_malicious, data.vt_suspicious, data.vt_undetected);
                group.add (vt_counts_row);

                if (data.vt_reputation != null) {
                    var rep_row = new Adw.ActionRow ();
                    rep_row.title = "Community reputation";
                    string votes_str = "";
                    if (data.vt_votes_harmless != null || data.vt_votes_malicious != null) {
                        int vh = data.vt_votes_harmless ?? 0;
                        int vm = data.vt_votes_malicious ?? 0;
                        votes_str = " (votes: %d harmless, %d malicious)".printf (vh, vm);
                    }
                    rep_row.subtitle = @"$(data.vt_reputation)$(votes_str)";
                    group.add (rep_row);
                }

                if (data.vt_categories.size > 0) {
                    var cat_row = new Adw.ActionRow ();
                    cat_row.title = "Categories";
                    var cat_str = string.joinv (", ", data.vt_categories.to_array ());
                    cat_row.subtitle = cat_str;
                    group.add (cat_row);
                }

                if (data.vt_first_seen != null) {
                    var fs_row = new Adw.ActionRow ();
                    fs_row.title = "First seen";
                    fs_row.subtitle = data.vt_first_seen.format ("%Y-%m-%d %H:%M:%S");
                    group.add (fs_row);
                }
                if (data.vt_last_seen != null) {
                    var ls_row = new Adw.ActionRow ();
                    ls_row.title = "Last seen";
                    ls_row.subtitle = data.vt_last_seen.format ("%Y-%m-%d %H:%M:%S");
                    group.add (ls_row);
                }
                if (data.vt_last_analyzed != null) {
                    var la_row = new Adw.ActionRow ();
                    la_row.title = "Last analyzed";
                    la_row.subtitle = data.vt_last_analyzed.format ("%Y-%m-%d %H:%M:%S");
                    group.add (la_row);
                }

                if (data.vt_detections.size > 0) {
                    var expander = new Adw.ExpanderRow ();
                    expander.title = "Detections (%d)".printf (data.vt_detections.size);
                    foreach (string det in data.vt_detections) {
                        var det_row = new Adw.ActionRow ();
                        det_row.title = det;
                        expander.add_row (det_row);
                    }
                    group.add (expander);
                }
            }

            var dbl_row = new Adw.ActionRow ();
            if (data.is_ip) {
                dbl_row.title = "Spamhaus DBL";
                dbl_row.subtitle = "Not applicable for IP addresses";
            } else if (data.dbl_error != null) {
                dbl_row.title = "Spamhaus DBL";
                dbl_row.subtitle = data.dbl_error;
            } else if (data.dbl_listed) {
                dbl_row.title = "Spamhaus DBL";
                string cat = data.dbl_category ?? "listed";
                string code = data.dbl_return_code ?? "";
                dbl_row.subtitle = "Listed (%s)".printf (cat) + (code.length > 0 ? " - " + code : "");
            } else {
                dbl_row.title = "Spamhaus DBL";
                dbl_row.subtitle = "Not listed";
            }
            group.add (dbl_row);

            return group;
        }
    }
}
