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
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/subdomain-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/subdomain-dialog.ui")]
#endif
    public class SubdomainDialog : Adw.Dialog {
        [GtkChild]
        private unowned Adw.EntryRow input_entry;
        [GtkChild]
        private unowned Gtk.Box results_box;
        [GtkChild]
        private unowned Gtk.Label status_label;
        [GtkChild]
        private unowned Gtk.ProgressBar progress_bar;
        [GtkChild]
        private unowned Gtk.Button check_button;

        private SubdomainService service;
        private int found_count = 0;

        public SubdomainDialog (Gtk.Widget? parent) {
            service = new SubdomainService ();
            service.found.connect (on_found);
            service.progress.connect (on_progress);
        }

        [GtkCallback]
        private void on_check_clicked () {
            string domain = input_entry.text.strip ();
            if (domain.length == 0 || !ValidationUtils.is_valid_hostname (domain)) {
                status_label.visible = true;
                status_label.label = ("Enter a valid domain.");
                return;
            }
            run.begin (domain);
        }

        private async void run (string domain) {
            clear_results ();
            found_count = 0;
            progress_bar.visible = true;
            progress_bar.fraction = 0.0;
            status_label.visible = true;
            status_label.label = ("Scanning common subdomains…");
            input_entry.sensitive = false;
            check_button.sensitive = false;

            int live = yield service.enumerate (domain);

            progress_bar.visible = false;
            input_entry.sensitive = true;
            check_button.sensitive = true;
            status_label.label = (live == 0)
                ? ("No live subdomains found.")
                : ("Found %d live subdomain(s).").printf (live);
        }

        private void on_found (string subdomain, string ip) {
            var row = new Adw.ActionRow ();
            row.title = subdomain;
            row.subtitle = ip;
            var icon = new Gtk.Image () { icon_name = "network-server-symbolic" };
            row.add_prefix (icon);
            results_box.append (row);
        }

        private void on_progress (int done, int total) {
            progress_bar.fraction = total > 0 ? (double) done / total : 0.0;
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
