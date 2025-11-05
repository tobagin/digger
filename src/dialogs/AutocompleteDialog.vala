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
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/autocomplete-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/autocomplete-dialog.ui")]
#endif
    public class AutocompleteDialog : Adw.Dialog {
        [GtkChild] public unowned Gtk.ListBox suggestion_listbox;

        construct {
            // Dialog is ready to use
        }
    }
}
