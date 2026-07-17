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
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/monitor-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/monitor-dialog.ui")]
#endif
    public class MonitorDialog : Adw.Dialog {
        [GtkChild]
        private unowned Adw.EntryRow input_entry;
        [GtkChild]
        private unowned Gtk.DropDown record_type_dropdown;
        [GtkChild]
        private unowned Adw.PreferencesGroup watches_group;
        [GtkChild]
        private unowned Gtk.Label status_label;

        private const string[] RECORD_TYPES = { "A", "AAAA", "CNAME", "MX", "NS", "TXT" };
        private MonitorService service;
        private Gee.ArrayList<Gtk.Widget> rows;

        public MonitorDialog (Gtk.Widget? parent) {
            service = MonitorService.get_instance ();
            rows = new Gee.ArrayList<Gtk.Widget> ();
            record_type_dropdown.model = new Gtk.StringList (RECORD_TYPES);
            service.list_updated.connect (rebuild_list);
            rebuild_list ();
        }

        [GtkCallback]
        private void on_add_clicked () {
            string domain = input_entry.text.strip ();
            if (domain.length == 0 || !ValidationUtils.is_valid_hostname (domain)) {
                show_status (("Enter a valid domain."));
                return;
            }
            var record_type = RecordType.from_string (RECORD_TYPES[record_type_dropdown.selected]);
            if (service.add_watch (domain, record_type)) {
                input_entry.text = "";
                show_status (("Now watching %s.").printf (domain));
            } else {
                show_status (("Already watching that domain and type."));
            }
        }

        [GtkCallback]
        private void on_check_now () {
            show_status (("Checking all watched domains…"));
            service.check_all.begin ((obj, res) => {
                service.check_all.end (res);
                show_status (("Check complete."));
            });
        }

        private void rebuild_list () {
            foreach (var row in rows) {
                watches_group.remove (row);
            }
            rows.clear ();

            foreach (var watch in service.get_watches ()) {
                var row = new Adw.ActionRow ();
                row.title = "%s  (%s)".printf (watch.domain, watch.record_type.to_string ());
                string subtitle = watch.last_signature == ""
                    ? ("Not checked yet")
                    : watch.last_signature;
                if (watch.last_checked != "") {
                    subtitle += "  •  " + watch.last_checked;
                }
                row.subtitle = subtitle;

                if (watch.changed) {
                    var badge = new Gtk.Image () { icon_name = "dialog-warning-symbolic" };
                    badge.add_css_class ("warning");
                    badge.tooltip_text = ("Changed since last check");
                    row.add_prefix (badge);
                }

                var remove_button = new Gtk.Button.from_icon_name ("user-trash-symbolic");
                remove_button.valign = Gtk.Align.CENTER;
                remove_button.add_css_class ("flat");
                remove_button.tooltip_text = ("Stop watching");
                var captured = watch;
                remove_button.clicked.connect (() => {
                    service.remove_watch (captured);
                });
                row.add_suffix (remove_button);

                watches_group.add (row);
                rows.add (row);
            }
        }

        private void show_status (string message) {
            status_label.label = message;
            status_label.visible = true;
        }
    }
}
