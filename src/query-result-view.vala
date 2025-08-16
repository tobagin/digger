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
    public class QueryResultView : Gtk.Box {
        private Gtk.Label summary_label;
        private Gtk.ScrolledWindow scrolled_window;
        private Gtk.Box content_box;
        private QueryResult? current_result = null;

        public QueryResultView () {
            orientation = Gtk.Orientation.VERTICAL;
            spacing = 12;
            margin_top = 12;
            margin_bottom = 12;
            margin_start = 12;
            margin_end = 12;

            setup_ui ();
        }

        private void setup_ui () {
            // Summary label at the top
            summary_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                wrap = true,
                selectable = true
            };
            summary_label.add_css_class ("heading");
            append (summary_label);

            // Scrolled window for results
            scrolled_window = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                vexpand = true
            };

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            scrolled_window.child = content_box;
            
            append (scrolled_window);

            // Initially show welcome message
            show_welcome_message ();
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

        public void show_result (QueryResult result) {
            current_result = result;
            clear_content ();

            // Update summary
            summary_label.label = get_query_info (result);

            if (result.status != QueryStatus.SUCCESS) {
                show_error_message (result);
                return;
            }

            if (!result.has_results ()) {
                show_no_results_message (result);
                return;
            }

            // Show results sections
            if (result.answer_section.size > 0) {
                add_results_section ("Answer Section", result.answer_section);
            }

            if (result.authority_section.size > 0) {
                add_results_section ("Authority Section", result.authority_section);
            }

            if (result.additional_section.size > 0) {
                add_results_section ("Additional Section", result.additional_section);
            }
        }

        private string get_query_info (QueryResult result) {
            var info = new StringBuilder ();
            info.append (@"Query: $(result.domain) ($(result.query_type.to_string ()))");
            
            if (result.dns_server != "System default") {
                info.append (@" via $(result.dns_server)");
            }
            
            info.append (@" - $(result.get_summary ())");
            
            return info.str;
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
            
            var error_label = new Gtk.Label (result.status.to_string ()) {
                halign = Gtk.Align.CENTER,
                wrap = true
            };
            error_label.add_css_class ("dim-label");

            error_box.append (icon);
            error_box.append (title_label);
            error_box.append (error_label);
            
            content_box.append (error_box);
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
                wrap = true
            };
            info_label.add_css_class ("dim-label");

            no_results_box.append (icon);
            no_results_box.append (title_label);
            no_results_box.append (info_label);
            
            content_box.append (no_results_box);
        }

        private void add_results_section (string section_title, Gee.ArrayList<DnsRecord> records) {
            var section_group = new Adw.PreferencesGroup () {
                title = section_title,
                margin_start = 6,
                margin_end = 6
            };

            foreach (var record in records) {
                var record_row = create_record_row (record);
                section_group.add (record_row);
            }

            content_box.append (section_group);
        }

        private Adw.ActionRow create_record_row (DnsRecord record) {
            var row = new Adw.ActionRow () {
                title = record.name,
                subtitle = @"$(record.record_type.to_string ()) • TTL: $(record.ttl)s"
            };

            // Value label
            var value_label = new Gtk.Label (record.get_display_value ()) {
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER,
                selectable = true,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR
            };
            value_label.add_css_class ("monospace");
            
            // Copy button
            var copy_button = new Gtk.Button.from_icon_name ("edit-copy-symbolic") {
                valign = Gtk.Align.CENTER,
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

        private void copy_to_clipboard (string text) {
            var clipboard = Gdk.Display.get_default ().get_clipboard ();
            clipboard.set_text (text);
            
            // Show a brief toast notification
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
                var toast = new Adw.Toast ("Copied to clipboard");
                toast.timeout = 2;
                toast_overlay.add_toast (toast);
            }
        }

        public void clear_results () {
            current_result = null;
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
