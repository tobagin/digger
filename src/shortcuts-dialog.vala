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
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/shortcuts-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/shortcuts-dialog.ui")]
#endif
    public class ShortcutsDialog : Adw.Dialog {
        
        public ShortcutsDialog (Gtk.Window parent) {
            Object ();
        }
    }
}