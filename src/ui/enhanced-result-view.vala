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
        [GtkChild] private unowned Gtk.ScrolledWindow scrolled_window;
        [GtkChild] private unowned Gtk.Box content_box;
        [GtkChild] private unowned Gtk.ProgressBar progress_bar;
        [GtkChild] private unowned Gtk.Box buttons_box;
        [GtkChild] private unowned Gtk.Button raw_output_button;
        [GtkChild] private unowned Gtk.Button clear_button;
        
        private QueryResult? current_result = null;
        
        private DnsPresets dns_presets;
        
        public EnhancedResultView () {
            dns_presets = DnsPresets.get_instance ();
            print (@"EnhancedResultView: dns_presets is $(dns_presets != null ? "not null" : "null")\n");
        }
        
        construct {
            setup_ui ();
        }
        
        private void setup_ui () {
            // Debug: Check if buttons are found
            print (@"raw_output_button is $(raw_output_button != null ? "not null" : "null")\n");
            print (@"clear_button is $(clear_button != null ? "not null" : "null")\n");
            print (@"buttons_box is $(buttons_box != null ? "not null" : "null")\n");
            
            if (raw_output_button != null) {
                // Connect raw output button
                raw_output_button.clicked.connect (() => {
                    print ("Raw output button clicked\n");
                    if (current_result != null) {
                        print ("Showing raw output dialog\n");
                        show_raw_output_dialog ();
                    } else {
                        print ("No current result\n");
                    }
                });
                print ("Raw output button signal connected\n");
            } else {
                print ("ERROR: raw_output_button is null, cannot connect signal\n");
            }
            
            if (clear_button != null) {
                // Connect clear button
                clear_button.clicked.connect (() => {
                    print ("Clear button clicked\n");
                    clear_results ();
                });
                print ("Clear button signal connected\n");
            } else {
                print ("ERROR: clear_button is null, cannot connect signal\n");
            }
            
            // Initially show welcome message
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
            
            // Add query statistics
            add_query_statistics (current_result);
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
            
            if (result.query_time_ms > 0) {
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
            row.subtitle = @"TTL: $(record.ttl)s";
            
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
            
            // Query time
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
        
        public void clear_results () {
            current_result = null;
            progress_bar.visible = false;
            
            // Hide action buttons when clearing results
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
