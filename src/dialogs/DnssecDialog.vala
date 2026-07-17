/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2025 tobagin
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
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/dnssec-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/dnssec-dialog.ui")]
#endif
    public class DnssecDialog : Adw.Dialog {
        [GtkChild]
        private unowned Adw.EntryRow input_entry;
        [GtkChild]
        private unowned Gtk.Box results_box;
        [GtkChild]
        private unowned Gtk.Label status_label;
        [GtkChild]
        private unowned Gtk.Spinner spinner;

        private DnssecValidator validator;

        public DnssecDialog (Gtk.Widget? parent) {
            validator = new DnssecValidator ();
        }

        [GtkCallback]
        private void on_check_clicked () {
            string domain = input_entry.text.strip ();
            if (domain.length == 0) {
                return;
            }
            run.begin (domain);
        }

        private async void run (string domain) {
            clear_results ();
            spinner.visible = true;
            spinner.start ();
            status_label.visible = true;
            status_label.label = ("Walking the chain of trust…");
            input_entry.sensitive = false;

            var links = yield validator.validate_chain (domain);

            bool all_secure = links.size > 0;
            foreach (var link in links) {
                if (!link.is_apex && !link.is_secure ()) {
                    all_secure = false;
                }
                results_box.append (create_link_row (link));
            }

            spinner.stop ();
            spinner.visible = false;
            if (links.size == 0) {
                status_label.label = ("Nothing to validate.");
            } else {
                status_label.label = all_secure
                    ? ("Unbroken chain of trust — DNSSEC secure.")
                    : ("Chain is incomplete — not fully secured by DNSSEC.");
            }
            input_entry.sensitive = true;
        }

        private Adw.ActionRow create_link_row (DnssecChainLink link) {
            var row = new Adw.ActionRow ();
            row.title = link.zone;

            var flags = new Gee.ArrayList<string> ();
            flags.add (link.has_dnskey ? "DNSKEY ✓" : "DNSKEY ✗");
            flags.add (link.has_ds ? "DS ✓" : "DS ✗");
            row.subtitle = "%s  •  %s".printf (link.status_label (), string.joinv ("   ", flags.to_array ()));

            var icon = new Gtk.Image () { icon_name = link.icon_name () };
            icon.add_css_class (link.is_secure () ? "success" : "warning");
            row.add_prefix (icon);
            return row;
        }

        private void clear_results () {
            var child = results_box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                results_box.remove (child);
                child = next;
            }
        }
    }
}
