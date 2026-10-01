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
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/enhanced-result-view.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/enhanced-result-view.ui")]
#endif
    public class EnhancedResultView : Gtk.Box {
        [GtkChild] private unowned Gtk.Label summary_label;
        [GtkChild] private unowned Gtk.Box content_box;
        [GtkChild] private unowned Gtk.ProgressBar progress_bar;
        [GtkChild] private unowned Gtk.Button export_button;
        [GtkChild] private unowned Gtk.Button copy_command_button;
        [GtkChild] private unowned Gtk.Button raw_output_button;
        [GtkChild] private unowned Gtk.Button clear_button;
        
        private QueryResult? current_result = null;
        private Ipv6TestResult? current_ipv6_result = null;
        private Ipv6Service ipv6_service;
        
        private DnsPresets dns_presets;
        private GLib.Settings settings;
        
        public bool show_detailed_ttl { get; set; default = false; }

        construct {
            settings = new GLib.Settings (Config.APP_ID);
            dns_presets = DnsPresets.get_instance ();
            ipv6_service = Ipv6Service.get_instance ();
            setup_ui ();
        }
        
        private void setup_ui () {
            if (export_button != null) {
                export_button.clicked.connect (() => {
                    if (current_result != null) {
                        show_export_dialog ();
                    }
                });
            }

            if (copy_command_button != null) {
                copy_command_button.clicked.connect (() => {
                    if (current_result != null) {
                        copy_dig_command_to_clipboard ();
                    }
                });
            }

            if (raw_output_button != null) {
                raw_output_button.clicked.connect (() => {
                    if (current_result != null) {
                        show_raw_output_dialog ();
                    }
                });
            }

            if (clear_button != null) {
                clear_button.clicked.connect (() => {
                    clear_results ();
                });
            }

            show_welcome_message ();
        }
        
        public void show_query_started (string domain, RecordType record_type, string? dns_server) {
            clear_content ();
            
            var server_text = dns_server ?? "system default";
            progress_bar.text = @"Querying $domain ($(record_type.to_string ())) via $server_text...";
            progress_bar.visible = true;
            progress_bar.pulse ();
            
            // Pulse the progress bar
            Timeout.add (100, () => {
                if (progress_bar.visible) {
                    progress_bar.pulse ();
                    return true;
                }
                return false;
            });
        }
        
        public void show_result (QueryResult result) {
            current_result = result;
            progress_bar.visible = false;

            // Show action buttons when we have a result
            export_button.visible = true;
            copy_command_button.visible = true;
            raw_output_button.visible = true;
            clear_button.visible = true;

            refresh_display ();
        }
        
        private void refresh_display () {
            if (current_result == null) return;
            
            clear_content ();
            
            // Update summary
            summary_label.label = get_query_info (current_result);
            
            
            if (current_result.status != QueryStatus.SUCCESS) {
                show_error_message (current_result);
                return;
            }
            
            if (!current_result.has_results ()) {
                show_no_results_message (current_result);
                return;
            }
            
            // Show enhanced results sections
            if (current_result.answer_section.size > 0) {
                add_enhanced_results_section ("Answer Section", current_result.answer_section, "success");
            }
            
            if (current_result.authority_section.size > 0) {
                add_enhanced_results_section ("Authority Section", current_result.authority_section, "warning");
            }
            
            if (current_result.additional_section.size > 0) {
                add_enhanced_results_section ("Additional Section", current_result.additional_section, "info");
            }

            // DNS Record Validator is opt-in and never blocks DnsQuery — call after parse_dig_output
            // e.g. var vr = DnsRecordValidator.validate_record_set (result.answer_section);
            // Rendered via show_validation() below when provided.
            if (current_result.answer_section.size > 0) {
                var vr = DnsRecordValidator.validate_record_set (current_result.answer_section);
                show_validation (vr);
            }
            
            // Add DNSSEC validation status if enabled
            if (settings != null && settings.get_boolean ("enable-dnssec")) {
                add_dnssec_validation (current_result.domain);
            }

            // Add WHOIS information if available
            if (current_result.whois_data != null) {
                add_whois_section (current_result.whois_data);
            }

            // Add Threat Intelligence if available
            if (current_result.threat_intel_data != null) {
                add_threat_section (current_result.threat_intel_data);
            }

            // Add IPv6 connectivity if available (non-blocking, guard null)
            if (current_ipv6_result != null) {
                add_ipv6_section (current_ipv6_result);
            }

            // Add query statistics
            add_query_statistics (current_result);
        }
        
        private void show_export_dialog () {
            var file_dialog = UiUtils.create_file_dialog (
                "Export DNS Query Results",
                @"$(current_result.domain)-$(current_result.query_type.to_string ()).json",
                { "JSON (*.json)", "CSV (*.csv)", "Plain Text (*.txt)", "DNS Zone File (*.zone)" },
                { "*.json", "*.csv", "*.txt", "*.zone" }
            );

            file_dialog.save.begin (this.get_root () as Gtk.Window, null, (obj, res) => {
                try {
                    var file = file_dialog.save.end (res);
                    if (file != null) {
                        export_result_to_file.begin (file);
                    }
                } catch (Error e) {
                    if (!(e is Gtk.DialogError.DISMISSED)) {
                        warning ("Export file selection error: %s", e.message);
                    }
                }
            });
        }

        private async void export_result_to_file (File file) {
            var file_path = file.get_path ();
            ExportFormat format = ExportFormat.JSON;

            if (file_path.has_suffix (".csv")) {
                format = ExportFormat.CSV;
            } else if (file_path.has_suffix (".txt")) {
                format = ExportFormat.TEXT;
            } else if (file_path.has_suffix (".zone")) {
                format = ExportFormat.ZONE_FILE;
            }

            var export_manager = ExportManager.get_instance ();
            var success = yield export_manager.export_result (current_result, file, format);

            if (success) {
                UiUtils.show_toast (this, "Results exported successfully", 3);
            } else {
                UiUtils.show_toast (this, "Failed to export results", 3);
            }
        }

        private void show_raw_output_dialog () {
            var dialog = new Adw.AlertDialog (
                "Raw dig Output",
                current_result.raw_output ?? "No raw output available"
            );

            dialog.add_response ("copy", "Copy");
            dialog.add_response ("close", "Close");
            dialog.set_response_appearance ("copy", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response ("close");

            dialog.response.connect ((response) => {
                if (response == "copy") {
                    var clipboard = this.get_clipboard ();
                    clipboard.set_text (current_result.raw_output ?? "");
                }
            });

            dialog.present (this.get_root () as Gtk.Window);
        }
        
        private string get_query_info (QueryResult result) {
            var info = new StringBuilder ();
            info.append (@"Query: $(result.domain) ($(result.query_type.to_string ()))");
            
            if (result.dns_server != "System default") {
                info.append (@" via $(result.dns_server)");
            }
            
            info.append (@" - $(result.get_summary ())");
            
            if (result.query_time_ms > 0 && settings != null && settings.get_boolean ("show-query-time")) {
                info.append (@" ($((int)result.query_time_ms)ms)");
            }
            
            return info.str;
        }
        
        private void add_status_page (string icon_name, string title, string description) {
            var status_page = new Adw.StatusPage () {
                icon_name = icon_name,
                title = title,
                description = description,
                vexpand = true
            };
            content_box.append (status_page);
        }

        private void show_welcome_message () {
            clear_content ();

            add_status_page ("network-workgroup-symbolic",
                             "DNS Lookup Tool",
                             "Enter a domain name and select a record type to begin");
            summary_label.label = "";
        }
        
        private void show_error_message (QueryResult result) {
            add_status_page ("dialog-error-symbolic",
                             "Query Failed",
                             get_error_description (result.status));
        }
        
        private string get_error_description (QueryStatus status) {
            switch (status) {
                case QueryStatus.NXDOMAIN:
                    return "The domain does not exist or cannot be found.";
                case QueryStatus.SERVFAIL:
                    return "The DNS server encountered an error while processing the query.";
                case QueryStatus.REFUSED:
                    return "The DNS server refused to process the query.";
                case QueryStatus.TIMEOUT:
                    return "The query timed out. The DNS server may be unreachable.";
                case QueryStatus.NETWORK_ERROR:
                    return "A network error occurred while performing the query.";
                case QueryStatus.INVALID_DOMAIN:
                    return "The provided domain name is not valid.";
                case QueryStatus.NO_DIG_COMMAND:
                    return "The 'dig' command is not available. Please install dnsutils.";
                default:
                    return "An unknown error occurred.";
            }
        }
        
        private void show_no_results_message (QueryResult result) {
            add_status_page ("dialog-information-symbolic",
                             "No Records Found",
                             "The query completed successfully but returned no DNS records");
        }
        
        private void add_enhanced_results_section (string section_title, Gee.ArrayList<DnsRecord> records, string style_class) {
            var section_group = new Adw.PreferencesGroup () {
                title = section_title,
                margin_start = 6,
                margin_end = 6
            };
            
            foreach (var record in records) {
                var record_row = create_enhanced_record_row (record, style_class);
                section_group.add (record_row);
            }
            
            content_box.append (section_group);
        }
        
        private Adw.ActionRow create_enhanced_record_row (DnsRecord record, string style_class) {
            var row = new Adw.ActionRow ();
            
            // Get record type information for enhanced display
            RecordTypeInfo? type_info = null;
            if (dns_presets != null) {
                type_info = dns_presets.get_record_type_info (record.record_type.to_string ());
            }
            
            // Create colored record type badge
            var type_badge = new Gtk.Label (record.record_type.to_string ()) {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                width_request = 60
            };
            type_badge.add_css_class ("pill");
            type_badge.add_css_class (style_class);
            
            // Record name and TTL
            row.title = record.name;
            
            if (record.record_type == RecordType.RRSIG && record.rrsig_type_covered != null) {
                string exp_date = format_rrsig_date (record.rrsig_expiration);
                row.subtitle = @"Covers $(record.rrsig_type_covered) • Expires $exp_date • Tag $(record.rrsig_key_tag) • Alg $(record.rrsig_algorithm)";
            } else if (settings != null && settings.get_boolean ("show-ttl-prominent")) {
                row.subtitle = @"TTL: $(record.ttl)s";
            } else {
                row.subtitle = record.value;
            }

            if (show_detailed_ttl) {
                string ttl_text = @"TTL: $(record.ttl)s";

                var ttl_label = new Gtk.Label (ttl_text);
                ttl_label.add_css_class ("caption");
                ttl_label.add_css_class ("dim-label");
                ttl_label.margin_end = 6;
                row.add_suffix (ttl_label);
            }
            
            // Add record type icon if available
            if (type_info != null) {
                var type_icon = new Gtk.Image.from_icon_name (type_info.icon) {
                    pixel_size = 16
                };
                row.add_prefix (type_icon);
                row.tooltip_text = type_info.get_tooltip_text ();
            }
            
            row.add_prefix (type_badge);
            
            // Value display
            var value_label = new Gtk.Label (record.get_display_value ()) {
                halign = Gtk.Align.END,
                selectable = true,
                wrap = false,
                ellipsize = Pango.EllipsizeMode.END,
                max_width_chars = 80
            };
            value_label.add_css_class ("monospace");

            // Copy button
            var copy_button = make_copy_button (record.get_display_value ());

            row.add_suffix (value_label);
            row.add_suffix (copy_button);
            row.activatable_widget = copy_button;
            
            return row;
        }
        
        /**
         * Optional validation banner — additive only, never blocks query path.
         * DNS Record Validator is pure, synchronous, side-effect-free.
         */
        public void show_validation (ValidationResult vr) {
            if (vr == null || vr.issues.size == 0) return;
            var group = new Adw.PreferencesGroup () {
                title = "DNS Validation",
                description = vr.get_summary (),
                margin_start = 6,
                margin_end = 6,
                margin_top = 12
            };
            foreach (var issue in vr.issues) {
                string icon_name = issue.severity == ValidationSeverity.ERROR ? "dialog-error-symbolic" : "dialog-warning-symbolic";
                var row = new Adw.ActionRow () {
                    title = issue.message,
                    subtitle = @"$(issue.code.to_string ()) • $(issue.severity.to_string ())"
                };
                var icon = new Gtk.Image.from_icon_name (icon_name) { pixel_size = 16 };
                row.add_prefix (icon);
                if (issue.severity == ValidationSeverity.ERROR) row.add_css_class ("error");
                else row.add_css_class ("warning");
                group.add (row);
            }
            content_box.append (group);
        }

        private void add_query_statistics (QueryResult result) {
            var stats_group = new Adw.PreferencesGroup () {
                title = "Query Statistics",
                margin_start = 6,
                margin_end = 6,
                margin_top = 12,
                margin_bottom = 12
            };
            
            // Query time (only if preference is enabled)
            if (settings != null && settings.get_boolean ("show-query-time")) {
                var time_row = new Adw.ActionRow () {
                    title = "Query Time",
                    subtitle = "Time taken to complete the DNS query"
                };
                var time_label = new Gtk.Label (@"$((int)result.query_time_ms) ms") {
                    halign = Gtk.Align.END
                };
                time_label.add_css_class ("monospace");
                time_row.add_suffix (time_label);
                stats_group.add (time_row);
            }
            
            // Record counts
            var total_records = result.answer_section.size + result.authority_section.size + result.additional_section.size;
            var count_row = new Adw.ActionRow () {
                title = "Total Records",
                subtitle = @"Answer: $(result.answer_section.size), Authority: $(result.authority_section.size), Additional: $(result.additional_section.size)"
            };
            var count_label = new Gtk.Label (total_records.to_string ()) {
                halign = Gtk.Align.END
            };
            count_label.add_css_class ("monospace");
            count_row.add_suffix (count_label);
            stats_group.add (count_row);
            
            content_box.append (stats_group);
        }
        
        private void copy_to_clipboard (string text) {
            var clipboard = Gdk.Display.get_default ().get_clipboard ();
            clipboard.set_text (text);

            UiUtils.show_toast (this, "Copied to clipboard");
        }

        /**
         * Create a flat copy button that copies the given text to the clipboard
         */
        private Gtk.Button make_copy_button (string text_to_copy) {
            var copy_button = new Gtk.Button.from_icon_name ("edit-copy-symbolic") {
                valign = Gtk.Align.CENTER,
                halign = Gtk.Align.CENTER,
                tooltip_text = "Copy to clipboard"
            };
            copy_button.add_css_class ("flat");
            copy_button.clicked.connect (() => {
                copy_to_clipboard (text_to_copy);
            });
            return copy_button;
        }

        /**
         * Create an expander row containing one ActionRow per item
         */
        private Adw.ExpanderRow make_expander_row (string title, string subtitle,
                                                   Gee.Collection<string> items, bool monospace_with_copy) {
            var expander = new Adw.ExpanderRow () {
                title = title,
                subtitle = subtitle
            };

            foreach (var item in items) {
                var row = new Adw.ActionRow () {
                    title = item
                };
                if (monospace_with_copy) {
                    row.add_css_class ("monospace");
                    row.add_suffix (make_copy_button (item));
                }
                expander.add_row (row);
            }

            return expander;
        }

        private void add_whois_section (WhoisData whois) {
            var whois_group = new Adw.PreferencesGroup () {
                title = "WHOIS Information",
                description = whois.from_cache ? "Cached data" : "Fresh data",
                margin_start = 6,
                margin_end = 6,
                margin_top = 12,
                margin_bottom = 12
            };

            // Registrar
            if (whois.registrar != null) {
                var registrar_row = new Adw.ActionRow () {
                    title = "Registrar",
                    subtitle = whois.registrar
                };
                registrar_row.add_suffix (make_copy_button (whois.registrar));
                whois_group.add (registrar_row);
            }

            // Date fields
            string?[,] date_fields = {
                { "Created", whois.created_date },
                { "Last Updated", whois.updated_date },
                { "Expires", whois.expires_date }
            };
            for (int i = 0; i < date_fields.length[0]; i++) {
                if (date_fields[i, 1] != null) {
                    whois_group.add (new Adw.ActionRow () {
                        title = (!) date_fields[i, 0],
                        subtitle = (!) date_fields[i, 1]
                    });
                }
            }

            // Nameservers (with copy buttons) and domain status
            if (whois.nameservers.size > 0) {
                whois_group.add (make_expander_row ("Nameservers",
                    @"$(whois.nameservers.size) server(s)", whois.nameservers, true));
            }

            if (whois.status.size > 0) {
                whois_group.add (make_expander_row ("Domain Status",
                    @"$(whois.status.size) status code(s)", whois.status, false));
            }

            // Privacy protection notice
            if (whois.privacy_protected) {
                var privacy_row = new Adw.ActionRow () {
                    title = "Privacy Protection",
                    subtitle = "Contact information is redacted"
                };
                var icon = new Gtk.Image.from_icon_name ("security-high-symbolic") {
                    pixel_size = 24
                };
                privacy_row.add_suffix (icon);
                whois_group.add (privacy_row);
            }

            // Show message if no parsed data available
            if (!whois.has_parsed_data ()) {
                var no_data_row = new Adw.ActionRow () {
                    title = "Limited Information",
                    subtitle = "WHOIS data could not be parsed or is unavailable for this domain"
                };
                whois_group.add (no_data_row);
            }

            content_box.append (whois_group);
        }

        private void add_threat_section (ThreatIntelData threat) {
            var threat_group = new Adw.PreferencesGroup () {
                title = "Threat Intelligence",
                description = threat.from_cache ? "Cached data" : "Fresh data",
                margin_start = 6,
                margin_end = 6,
                margin_top = 12,
                margin_bottom = 12
            };

            var verdict_row = new Adw.ActionRow () {
                title = threat.get_verdict_label ()
            };
            if (threat.safety_score >= 0) {
                verdict_row.subtitle = "Safety score: %d/100".printf (threat.safety_score);
            } else if (threat.error_message != null) {
                verdict_row.subtitle = threat.error_message;
            } else {
                verdict_row.subtitle = "No threat data available";
            }
            string css = threat.get_verdict_css_class ();
            if (css.length > 0) verdict_row.add_css_class (css);
            threat_group.add (verdict_row);

            if (threat.level == ThreatLevel.ERROR || threat.level == ThreatLevel.RATE_LIMITED) {
                var err_row = new Adw.ActionRow () {
                    title = threat.level == ThreatLevel.RATE_LIMITED ? "Rate limited" : "Error",
                    subtitle = threat.error_message ?? "Check failed"
                };
                threat_group.add (err_row);
            }

            bool has_vt = (threat.vt_harmless > 0 || threat.vt_malicious > 0 || threat.vt_suspicious > 0 || threat.vt_undetected > 0 || threat.vt_reputation != null);
            if (has_vt) {
                var vt_row = new Adw.ActionRow () {
                    title = "VirusTotal detections",
                    subtitle = "Harmless: %d, Malicious: %d, Suspicious: %d, Undetected: %d".printf (threat.vt_harmless, threat.vt_malicious, threat.vt_suspicious, threat.vt_undetected)
                };
                threat_group.add (vt_row);

                if (threat.vt_reputation != null) {
                    var rep_row = new Adw.ActionRow () {
                        title = "Community reputation"
                    };
                    string votes = "";
                    if (threat.vt_votes_harmless != null || threat.vt_votes_malicious != null) {
                        votes = " (votes: %d harmless, %d malicious)".printf (threat.vt_votes_harmless ?? 0, threat.vt_votes_malicious ?? 0);
                    }
                    rep_row.subtitle = @"$(threat.vt_reputation)$(votes)";
                    var copy_btn = new Gtk.Button.from_icon_name ("edit-copy-symbolic") { valign = Gtk.Align.CENTER };
                    copy_btn.add_css_class ("flat");
                    copy_btn.tooltip_text = "Copy to clipboard";
                    string rep_val = @"$(threat.vt_reputation)";
                    copy_btn.clicked.connect (() => copy_to_clipboard (rep_val));
                    rep_row.add_suffix (copy_btn);
                    threat_group.add (rep_row);
                }

                if (threat.vt_categories.size > 0) {
                    var cat_row = new Adw.ActionRow () {
                        title = "Categories",
                        subtitle = string.joinv (", ", threat.vt_categories.to_array ())
                    };
                    threat_group.add (cat_row);
                }

                if (threat.vt_first_seen != null) {
                    var fs_row = new Adw.ActionRow () { title = "First seen", subtitle = threat.vt_first_seen.format ("%Y-%m-%d %H:%M:%S") };
                    threat_group.add (fs_row);
                }
                if (threat.vt_last_seen != null) {
                    var ls_row = new Adw.ActionRow () { title = "Last seen", subtitle = threat.vt_last_seen.format ("%Y-%m-%d %H:%M:%S") };
                    threat_group.add (ls_row);
                }
                if (threat.vt_last_analyzed != null) {
                    var la_row = new Adw.ActionRow () { title = "Last analyzed", subtitle = threat.vt_last_analyzed.format ("%Y-%m-%d %H:%M:%S") };
                    threat_group.add (la_row);
                }

                if (threat.vt_detections.size > 0) {
                    var exp = new Adw.ExpanderRow () { title = "Detections (%d)".printf (threat.vt_detections.size) };
                    foreach (string det in threat.vt_detections) {
                        var det_row = new Adw.ActionRow () { title = det };
                        string det_copy = det;
                        var cbtn = new Gtk.Button.from_icon_name ("edit-copy-symbolic") { valign = Gtk.Align.CENTER };
                        cbtn.add_css_class ("flat");
                        cbtn.clicked.connect (() => copy_to_clipboard (det_copy));
                        det_row.add_suffix (cbtn);
                        exp.add_row (det_row);
                    }
                    threat_group.add (exp);
                }
            }

            var dbl_row = new Adw.ActionRow ();
            if (threat.is_ip) {
                dbl_row.title = "Spamhaus DBL";
                dbl_row.subtitle = "Not applicable for IP addresses";
            } else if (threat.dbl_error != null) {
                dbl_row.title = "Spamhaus DBL";
                dbl_row.subtitle = threat.dbl_error;
            } else if (threat.dbl_listed) {
                dbl_row.title = "Spamhaus DBL";
                dbl_row.subtitle = "Listed (%s)".printf (threat.dbl_category ?? "listed") + (threat.dbl_return_code != null ? " - " + threat.dbl_return_code : "");
            } else {
                dbl_row.title = "Spamhaus DBL";
                dbl_row.subtitle = "Not listed";
            }
            threat_group.add (dbl_row);

            content_box.append (threat_group);
        }

        private void add_dnssec_validation (string domain) {
            var dnssec_group = new Adw.PreferencesGroup () {
                title = "DNSSEC Validation",
                margin_start = 6,
                margin_end = 6,
                margin_top = 12,
                margin_bottom = 12
            };

            var status_row = new Adw.ActionRow () {
                title = "Validation Status",
                subtitle = "Checking DNSSEC..."
            };

            var spinner = new Gtk.Spinner () {
                spinning = true
            };
            status_row.add_suffix (spinner);

            dnssec_group.add (status_row);
            content_box.append (dnssec_group);

            var validator = new DnssecValidator ();
            validator.validate_domain.begin (domain, null, (obj, res) => {
                try {
                    var result = validator.validate_domain.end (res);

                    status_row.remove (spinner);

                    var icon = new Gtk.Image.from_icon_name (result.status.get_icon_name ()) {
                        pixel_size = 24
                    };

                    status_row.subtitle = result.get_summary ();
                    status_row.add_suffix (icon);

                    if (result.is_dnssec_enabled ()) {
                        var details_expander = new Adw.ExpanderRow () {
                            title = "Chain of Trust"
                        };

                        foreach (var entry in result.chain_of_trust) {
                            var entry_row = new Adw.ActionRow () {
                                title = entry
                            };
                            entry_row.add_css_class ("monospace");
                            details_expander.add_row (entry_row);
                        }

                        dnssec_group.add (details_expander);
                    }
                } catch (Error e) {
                    warning ("DNSSEC validation error: %s", e.message);
                    status_row.remove (spinner);
                    status_row.subtitle = "Validation failed";
                }
            });
        }
        
        private void copy_dig_command_to_clipboard () {
            var export_manager = ExportManager.get_instance ();
            string command = export_manager.export_as_dig_command (current_result);

            var clipboard = this.get_clipboard ();
            clipboard.set_text (command);

            UiUtils.show_toast (this, "Command copied to clipboard");
        }

        public void show_ipv6_result (Ipv6TestResult result) {
            current_ipv6_result = result;
            // Re-render if a main result is already shown; otherwise just store for next refresh
            if (current_result != null) {
                refresh_display ();
            }
        }

        public void show_ipv6_testing () {
            var testing = new Ipv6TestResult ();
            testing.status = Ipv6ProbeStatus.UNKNOWN;
            testing.ipv6_available = false;
            testing.error_message = "Testing IPv6 reachability...";
            current_ipv6_result = testing;
            if (current_result != null) {
                refresh_display ();
            }
        }

        public void clear_ipv6_result () {
            current_ipv6_result = null;
        }

        private void add_ipv6_section (Ipv6TestResult ipv6) {
            // Guard: never render empty shell — if UNKNOWN and no message, skip
            if (ipv6 == null) return;

            var ipv6_group = new Adw.PreferencesGroup () {
                title = "IPv6 Connectivity",
                description = ipv6.from_cache ? "Cached" : null,
                margin_start = 6,
                margin_end = 6,
                margin_top = 12,
                margin_bottom = 12
            };

            bool is_testing = (ipv6.status == Ipv6ProbeStatus.UNKNOWN && ipv6.error_message != null && ipv6.error_message.contains ("Testing"));

            if (is_testing) {
                var testing_row = new Adw.ActionRow () {
                    title = "Testing IPv6 reachability...",
                    subtitle = "Probing via " + ipv6.resolver_used
                };
                var spinner = new Gtk.Spinner () {
                    spinning = true,
                    valign = Gtk.Align.CENTER
                };
                spinner.set_size_request (44, 44);
                testing_row.add_suffix (spinner);
                var icon = new Gtk.Image.from_icon_name ("network-workgroup-symbolic") { pixel_size = 16 };
                testing_row.add_prefix (icon);
                ipv6_group.add (testing_row);
                content_box.append (ipv6_group);
                return;
            }

            // Row 1: Capability
            var cap_title = ipv6.ipv6_available ? "IPv6 Available" : "IPv6 Unavailable";
            var cap_subtitle = ipv6.ipv6_available ? "System supports IPv6" : (ipv6.error_message ?? "No IPv6 stack detected");
            var cap_row = new Adw.ActionRow () {
                title = cap_title,
                subtitle = cap_subtitle
            };
            var cap_icon = new Gtk.Image.from_icon_name ("network-workgroup-symbolic") { pixel_size = 16 };
            cap_row.add_prefix (cap_icon);
            if (ipv6.ipv6_available) cap_row.add_css_class ("success"); else cap_row.add_css_class ("error");
            ipv6_group.add (cap_row);

            // Row 2: Reachability
            if (ipv6.ipv6_available) {
                string reach_title;
                string reach_subtitle;
                string reach_class = "";
                if (ipv6.reachable == true) {
                    reach_title = "Reachable";
                    reach_subtitle = "%d ms via %s".printf (ipv6.probe_latency_ms, ipv6.resolver_used);
                    reach_class = "success";
                } else if (ipv6.reachable == false) {
                    if (ipv6.status == Ipv6ProbeStatus.TIMEOUT) {
                        reach_title = "Timeout";
                        reach_subtitle = ipv6.error_message ?? "Probe timed out";
                        reach_class = "warning";
                    } else if (ipv6.status == Ipv6ProbeStatus.UNREACHABLE) {
                        reach_title = "Unreachable";
                        reach_subtitle = ipv6.error_message ?? "No route to IPv6 resolver";
                        reach_class = "error";
                    } else {
                        reach_title = ipv6.status.to_string ();
                        reach_subtitle = ipv6.error_message ?? "Probe failed";
                        reach_class = "error";
                    }
                } else {
                    reach_title = "Not tested";
                    reach_subtitle = ipv6.error_message ?? "";
                }
                var reach_row = new Adw.ActionRow () {
                    title = reach_title,
                    subtitle = reach_subtitle
                };
                if (reach_class.length > 0) reach_row.add_css_class (reach_class);
                ipv6_group.add (reach_row);
            }

            // Row 3: Resolver response / error
            if (ipv6.status == Ipv6ProbeStatus.NXDOMAIN || ipv6.status == Ipv6ProbeStatus.SERVFAIL) {
                var err_row = new Adw.ActionRow () {
                    title = ipv6.status.to_string (),
                    subtitle = ipv6.error_message ?? "Resolver error"
                };
                err_row.add_css_class ("error");
                ipv6_group.add (err_row);
            } else if (ipv6.status == Ipv6ProbeStatus.ERROR && ipv6.error_message != null) {
                var err_row = new Adw.ActionRow () {
                    title = "Error",
                    subtitle = ipv6.error_message
                };
                err_row.add_css_class ("error");
                ipv6_group.add (err_row);
            }

            // Row 4: AAAA records (reuse pattern similar to enhanced results)
            if (ipv6.aaaa_records != null && ipv6.aaaa_records.size > 0) {
                var aaaa_expander = new Adw.ExpanderRow () {
                    title = "AAAA Records",
                    subtitle = @"$(ipv6.aaaa_records.size) record(s) via $(ipv6.resolver_used)"
                };
                foreach (var rec in ipv6.aaaa_records) {
                    string display_val = rec.value;
                    if (display_val.length > Constants.MAX_RECORD_DATA_DISPLAY_LENGTH) {
                        display_val = display_val.substring (0, Constants.MAX_RECORD_DATA_DISPLAY_LENGTH) + "...";
                    }
                    var rec_row = new Adw.ActionRow () {
                        title = rec.name,
                        subtitle = display_val
                    };
                    rec_row.add_css_class ("monospace");
                    var label = new Gtk.Label (display_val) {
                        selectable = true,
                        halign = Gtk.Align.END,
                        ellipsize = Pango.EllipsizeMode.END,
                        max_width_chars = 40
                    };
                    label.add_css_class ("monospace");
                    var copy_button = new Gtk.Button.from_icon_name ("edit-copy-symbolic") {
                        valign = Gtk.Align.CENTER,
                        tooltip_text = "Copy to clipboard"
                    };
                    copy_button.add_css_class ("flat");
                    string copy_val = rec.value;
                    copy_button.clicked.connect (() => { copy_to_clipboard (copy_val); });
                    rec_row.add_suffix (label);
                    rec_row.add_suffix (copy_button);
                    aaaa_expander.add_row (rec_row);
                }
                ipv6_group.add (aaaa_expander);
            } else if (ipv6.reachable == true && ipv6.status == Ipv6ProbeStatus.SUCCESS) {
                var no_aaaa_row = new Adw.ActionRow () {
                    title = "No AAAA records",
                    subtitle = @"No IPv6 addresses for this domain (via $(ipv6.resolver_used))"
                };
                ipv6_group.add (no_aaaa_row);
            }

            content_box.append (ipv6_group);
        }

        public void clear_results () {
            current_result = null;
            current_ipv6_result = null;
            progress_bar.visible = false;

            // Hide action buttons when clearing results
            export_button.visible = false;
            copy_command_button.visible = false;
            raw_output_button.visible = false;
            clear_button.visible = false;

            show_welcome_message ();
        }
        
        private void clear_content () {
            UiUtils.clear_children (content_box);
        }

        private string format_rrsig_date (string? date_str) {
            if (date_str == null || date_str.length < 14) return date_str ?? "";

            // Format: YYYYMMDDHHmmss
            // Return: YYYY-MM-DD HH:mm:ss
            string year = date_str.substring (0, 4);
            string month = date_str.substring (4, 2);
            string day = date_str.substring (6, 2);
            string hour = date_str.substring (8, 2);
            string minute = date_str.substring (10, 2);
            string second = date_str.substring (12, 2);

            return @"$year-$month-$day $hour:$minute:$second";
        }
    }
}
