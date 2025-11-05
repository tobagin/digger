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
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/history-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/history-dialog.ui")]
#endif
    public class HistoryDialog : Adw.Dialog {
        [GtkChild] public unowned Gtk.SearchEntry history_search_entry;
        [GtkChild] public unowned Gtk.ListBox history_listbox;
        [GtkChild] public unowned Gtk.Button clear_button;

        construct {
            // Dialog is ready to use
        }
    }
}
