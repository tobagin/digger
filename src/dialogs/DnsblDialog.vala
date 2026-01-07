/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024 tobagin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

using Gtk;
using Adw;
using Gee;

namespace Digger {
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/dnsbl-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/dnsbl-dialog.ui")]
#endif
    public class DnsblDialog : Adw.Dialog {
        [GtkChild]
        private unowned Adw.EntryRow input_entry;
        
        [GtkChild]
        private unowned Gtk.Box results_box;
        
        [GtkChild]
        private unowned Gtk.Label status_label;
        
        [GtkChild]
        private unowned Gtk.Spinner spinner;

        private DnsblService dnsbl_service;
        
        public DnsblDialog (Gtk.Widget? parent) {
            dnsbl_service = DnsblService.get_instance ();
        }

        [GtkCallback]
        private void on_check_clicked () {
            string input = input_entry.text.strip ();
            if (input.length == 0) return;

            // TODO: If input is a domain, resolve to IP first? 
            // For now, assume IP or let service handle basic validation
            
            perform_check.begin (input);
        }

        private async void perform_check (string ip) {
            spinner.visible = true;
            spinner.start ();
            status_label.visible = true;
            status_label.label = "Checking blacklists...";
            input_entry.sensitive = false;
            
            // Clear previous results
            var child = results_box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                results_box.remove (child);
                child = next;
            }

            // Start check
            var results = yield dnsbl_service.check_ip (ip);

            // Populate results
            foreach (var result in results) {
                var row = create_result_row (result);
                results_box.append (row);
            }

            spinner.stop ();
            spinner.visible = false;
            status_label.visible = false;
            input_entry.sensitive = true;
        }

        private Adw.ActionRow create_result_row (DnsblResult result) {
            var row = new Adw.ActionRow ();
            row.title = result.provider_name;
            row.subtitle = result.provider;

            string icon_name;
            string status_text;
            string style_class;

            switch (result.status) {
                case DnsblStatus.CLEAN:
                    icon_name = "security-high-symbolic";
                    status_text = "Clean";
                    style_class = "success";
                    break;
                case DnsblStatus.LISTED:
                    icon_name = "dialog-warning-symbolic";
                    status_text = "Listed" + (result.return_code != null ? @" ($(result.return_code))" : "");
                    style_class = "error";
                    break;
                case DnsblStatus.ERROR:
                    icon_name = "dialog-error-symbolic";
                    status_text = "Error";
                    style_class = "error";
                    break;
                default:
                    icon_name = "process-working-symbolic";
                    status_text = "Unknown";
                    style_class = "dim-label";
                    break;
            }

            var icon = new Gtk.Image.from_icon_name (icon_name);
            icon.add_css_class (style_class);
            
            var label = new Gtk.Label (status_text);
            label.add_css_class (style_class);
            label.valign = Gtk.Align.CENTER;

            row.add_suffix (label);
            row.add_prefix (icon);

            return row;
        }
    }
}
