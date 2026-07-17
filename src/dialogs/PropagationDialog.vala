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
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/propagation-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/propagation-dialog.ui")]
#endif
    public class PropagationDialog : Adw.Dialog {
        [GtkChild]
        private unowned Adw.EntryRow input_entry;
        [GtkChild]
        private unowned Gtk.DropDown record_type_dropdown;
        [GtkChild]
        private unowned Gtk.Box results_box;
        [GtkChild]
        private unowned Gtk.Label status_label;
        [GtkChild]
        private unowned Gtk.Spinner spinner;

        private const string[] RECORD_TYPES = { "A", "AAAA", "CNAME", "MX", "NS", "TXT" };
        private PropagationService service;

        public PropagationDialog (Gtk.Widget? parent) {
            service = new PropagationService ();
            record_type_dropdown.model = new Gtk.StringList (RECORD_TYPES);
        }

        [GtkCallback]
        private void on_check_clicked () {
            string domain = input_entry.text.strip ();
            if (domain.length == 0) {
                return;
            }
            var record_type = RecordType.from_string (RECORD_TYPES[record_type_dropdown.selected]);
            run_check.begin (domain, record_type);
        }

        private async void run_check (string domain, RecordType record_type) {
            clear_results ();
            spinner.visible = true;
            spinner.start ();
            status_label.visible = true;
            status_label.label = ("Querying public resolvers…");
            input_entry.sensitive = false;

            var probes = yield service.check (domain, record_type);

            int agreeing = 0;
            foreach (var probe in probes) {
                if (probe.agrees) {
                    agreeing++;
                }
                results_box.append (create_probe_row (probe));
            }

            spinner.stop ();
            spinner.visible = false;
            status_label.label = (agreeing == probes.size)
                ? ("All resolvers agree — fully propagated.")
                : ("%d of %d resolvers agree.").printf (agreeing, probes.size);
            input_entry.sensitive = true;
        }

        private Adw.ActionRow create_probe_row (PropagationProbe probe) {
            var row = new Adw.ActionRow ();
            row.title = probe.resolver_name;

            string subtitle;
            if (probe.status != QueryStatus.SUCCESS) {
                subtitle = probe.status.to_string ();
            } else if (probe.values.size == 0) {
                subtitle = ("No records");
            } else {
                subtitle = string.joinv ("\n", probe.values.to_array ());
            }
            row.subtitle = "%s  •  %s".printf (probe.resolver_ip, subtitle);

            var icon = new Gtk.Image ();
            if (probe.status != QueryStatus.SUCCESS) {
                icon.icon_name = "dialog-warning-symbolic";
                icon.add_css_class ("warning");
            } else if (probe.agrees) {
                icon.icon_name = "emblem-ok-symbolic";
                icon.add_css_class ("success");
            } else {
                icon.icon_name = "dialog-warning-symbolic";
                icon.add_css_class ("error");
            }
            row.add_suffix (icon);
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
