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
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/enhanced-result-view.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/enhanced-result-view.ui")]
#endif
    public class EnhancedResultView : Gtk.Box {
        [GtkChild] private unowned Gtk.Label summary_label;
        [GtkChild] private unowned Gtk.Box content_box;
        [GtkChild] private unowned Gtk.ProgressBar progress_bar;
        [GtkChild] private unowned Gtk.Box buttons_box;
        [GtkChild] private unowned Gtk.Button export_button;
        [GtkChild] private unowned Gtk.Button copy_command_button;
        [GtkChild] private unowned Gtk.Button raw_output_button;
        [GtkChild] private unowned Gtk.Button clear_button;
        
        private QueryResult? current_result = null;
        
        private DnsPresets dns_presets;
        private GLib.Settings settings;
        
        public EnhancedResultView () {
            settings = new GLib.Settings (Config.APP_ID);
            dns_presets = DnsPresets.get_instance ();
            print (@"EnhancedResultView: dns_presets is $(dns_presets != null ? "not null" : "null")\n");
        }
        
        construct {
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
            
            // Add DNSSEC validation status if enabled
            if (settings != null && settings.get_boolean ("enable-dnssec")) {
                add_dnssec_validation (current_result.domain);
            }

            // Add WHOIS information if available
            if (current_result.whois_data != null) {
                add_whois_section (current_result.whois_data);
            }

            // Add query statistics
            add_query_statistics (current_result);
        }
        
        private void show_export_dialog () {
            var file_dialog = new Gtk.FileDialog () {
                title = "Export DNS Query Results",
                modal = true
            };

            var filter_json = new Gtk.FileFilter ();
            filter_json.set_filter_name ("JSON (*.json)");
            filter_json.add_pattern ("*.json");

            var filter_csv = new Gtk.FileFilter ();
            filter_csv.set_filter_name ("CSV (*.csv)");
            filter_csv.add_pattern ("*.csv");

            var filter_txt = new Gtk.FileFilter ();
            filter_txt.set_filter_name ("Plain Text (*.txt)");
            filter_txt.add_pattern ("*.txt");

            var filter_zone = new Gtk.FileFilter ();
            filter_zone.set_filter_name ("DNS Zone File (*.zone)");
            filter_zone.add_pattern ("*.zone");

            var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters.append (filter_json);
            filters.append (filter_csv);
            filters.append (filter_txt);
            filters.append (filter_zone);
            file_dialog.filters = filters;
            file_dialog.default_filter = filter_json;

            var suggested_name = @"$(current_result.domain)-$(current_result.query_type.to_string ()).json";
            file_dialog.initial_name = suggested_name;

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
                show_export_success_toast ();
            } else {
                show_export_error_toast ();
            }
        }

        private void show_export_success_toast () {
            var parent = get_parent ();
            while (parent != null && !(parent is Adw.ToastOverlay)) {
                parent = parent.get_parent ();
            }

            if (parent is Adw.ToastOverlay) {
                var toast_overlay = (Adw.ToastOverlay) parent;
                var toast = new Adw.Toast ("Results exported successfully") {
                    timeout = 3
                };
                toast_overlay.add_toast (toast);
            }
        }

        private void show_export_error_toast () {
            var parent = get_parent ();
            while (parent != null && !(parent is Adw.ToastOverlay)) {
                parent = parent.get_parent ();
            }

            if (parent is Adw.ToastOverlay) {
                var toast_overlay = (Adw.ToastOverlay) parent;
                var toast = new Adw.Toast ("Failed to export results") {
                    timeout = 3
                };
                toast_overlay.add_toast (toast);
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
        
        private void show_welcome_message () {
            clear_content ();
            
            var welcome_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                valign = Gtk.Align.CENTER,
                halign = Gtk.Align.CENTER
            };
            
            var icon = new Gtk.Image.from_icon_name ("network-workgroup-symbolic") {
                pixel_size = 64
            };
            icon.add_css_class ("dim-label");
            
            var title_label = new Gtk.Label ("DNS Lookup Tool") {
                halign = Gtk.Align.CENTER
            };
            title_label.add_css_class ("title-1");
            
            var subtitle_label = new Gtk.Label ("Enter a domain name and select a record type to begin") {
                halign = Gtk.Align.CENTER
            };
            subtitle_label.add_css_class ("dim-label");
            
            welcome_box.append (icon);
            welcome_box.append (title_label);
            welcome_box.append (subtitle_label);
            
            content_box.append (welcome_box);
            summary_label.label = "";
        }
        
        private void show_error_message (QueryResult result) {
            var error_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                valign = Gtk.Align.CENTER,
                halign = Gtk.Align.CENTER
            };
            
            var icon = new Gtk.Image.from_icon_name ("dialog-error-symbolic") {
                pixel_size = 64
            };
            icon.add_css_class ("error");
            
            var title_label = new Gtk.Label ("Query Failed") {
                halign = Gtk.Align.CENTER
            };
            title_label.add_css_class ("title-2");
            
            var error_label = new Gtk.Label (get_error_description (result.status)) {
                halign = Gtk.Align.CENTER,
                wrap = true,
                justify = Gtk.Justification.CENTER
            };
            error_label.add_css_class ("dim-label");
            
            error_box.append (icon);
            error_box.append (title_label);
            error_box.append (error_label);
            
            content_box.append (error_box);
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
            var no_results_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                valign = Gtk.Align.CENTER,
                halign = Gtk.Align.CENTER
            };
            
            var icon = new Gtk.Image.from_icon_name ("dialog-information-symbolic") {
                pixel_size = 64
            };
            icon.add_css_class ("dim-label");
            
            var title_label = new Gtk.Label ("No Records Found") {
                halign = Gtk.Align.CENTER
            };
            title_label.add_css_class ("title-2");
            
            var info_label = new Gtk.Label ("The query completed successfully but returned no DNS records") {
                halign = Gtk.Align.CENTER,
                wrap = true,
                justify = Gtk.Justification.CENTER
            };
            info_label.add_css_class ("dim-label");
            
            no_results_box.append (icon);
            no_results_box.append (title_label);
            no_results_box.append (info_label);
            
            content_box.append (no_results_box);
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
            if (settings != null && settings.get_boolean ("show-ttl-prominent")) {
                row.subtitle = @"TTL: $(record.ttl)s";
            } else {
                row.subtitle = record.value;
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
            var copy_button = new Gtk.Button.from_icon_name ("edit-copy-symbolic") {
                valign = Gtk.Align.CENTER,
                halign = Gtk.Align.CENTER,
                tooltip_text = "Copy to clipboard"
            };
            copy_button.add_css_class ("flat");
            copy_button.clicked.connect (() => {
                copy_to_clipboard (record.get_copyable_value ());
            });
            
            row.add_suffix (value_label);
            row.add_suffix (copy_button);
            row.activatable_widget = copy_button;
            
            return row;
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
            
            show_copy_toast ();
        }
        
        private void show_copy_toast () {
            // Find the parent AdwToastOverlay if available
            var parent = get_parent ();
            while (parent != null && !(parent is Adw.ToastOverlay)) {
                parent = parent.get_parent ();
            }

            if (parent is Adw.ToastOverlay) {
                var toast_overlay = (Adw.ToastOverlay) parent;
                var toast = new Adw.Toast ("Copied to clipboard") {
                    timeout = 2
                };
                toast_overlay.add_toast (toast);
            }
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
                var copy_button = new Gtk.Button.from_icon_name ("edit-copy-symbolic") {
                    valign = Gtk.Align.CENTER,
                    tooltip_text = "Copy to clipboard"
                };
                copy_button.add_css_class ("flat");
                copy_button.clicked.connect (() => {
                    copy_to_clipboard (whois.registrar);
                });
                registrar_row.add_suffix (copy_button);
                whois_group.add (registrar_row);
            }

            // Created date
            if (whois.created_date != null) {
                var created_row = new Adw.ActionRow () {
                    title = "Created",
                    subtitle = whois.created_date
                };
                whois_group.add (created_row);
            }

            // Updated date
            if (whois.updated_date != null) {
                var updated_row = new Adw.ActionRow () {
                    title = "Last Updated",
                    subtitle = whois.updated_date
                };
                whois_group.add (updated_row);
            }

            // Expires date
            if (whois.expires_date != null) {
                var expires_row = new Adw.ActionRow () {
                    title = "Expires",
                    subtitle = whois.expires_date
                };
                whois_group.add (expires_row);
            }

            // Nameservers
            if (whois.nameservers.size > 0) {
                var ns_expander = new Adw.ExpanderRow () {
                    title = "Nameservers",
                    subtitle = @"$(whois.nameservers.size) server(s)"
                };

                foreach (var ns in whois.nameservers) {
                    var ns_row = new Adw.ActionRow () {
                        title = ns
                    };
                    ns_row.add_css_class ("monospace");
                    var copy_button = new Gtk.Button.from_icon_name ("edit-copy-symbolic") {
                        valign = Gtk.Align.CENTER,
                        tooltip_text = "Copy to clipboard"
                    };
                    copy_button.add_css_class ("flat");
                    copy_button.clicked.connect (() => {
                        copy_to_clipboard (ns);
                    });
                    ns_row.add_suffix (copy_button);
                    ns_expander.add_row (ns_row);
                }

                whois_group.add (ns_expander);
            }

            // Domain status
            if (whois.status.size > 0) {
                var status_expander = new Adw.ExpanderRow () {
                    title = "Domain Status",
                    subtitle = @"$(whois.status.size) status code(s)"
                };

                foreach (var status in whois.status) {
                    var status_row = new Adw.ActionRow () {
                        title = status
                    };
                    status_expander.add_row (status_row);
                }

                whois_group.add (status_expander);
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

            show_command_copy_toast ();
        }

        private void show_command_copy_toast () {
            // Find the parent AdwToastOverlay if available
            var parent = get_parent ();
            while (parent != null && !(parent is Adw.ToastOverlay)) {
                parent = parent.get_parent ();
            }

            if (parent is Adw.ToastOverlay) {
                var toast_overlay = (Adw.ToastOverlay) parent;
                var toast = new Adw.Toast ("Command copied to clipboard") {
                    timeout = 2
                };
                toast_overlay.add_toast (toast);
            }
        }

        public void clear_results () {
            current_result = null;
            progress_bar.visible = false;

            // Hide action buttons when clearing results
            export_button.visible = false;
            copy_command_button.visible = false;
            raw_output_button.visible = false;
            clear_button.visible = false;

            show_welcome_message ();
        }
        
        private void clear_content () {
            var child = content_box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                content_box.remove (child);
                child = next;
            }
        }
    }
}
