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
    public class ShortcutsDialog {

        public static void present (Gtk.Window parent) {
#if DEVELOPMENT
            var builder = new Gtk.Builder.from_resource ("/io/github/tobagin/digger/Devel/shortcuts-dialog.ui");
#else
            var builder = new Gtk.Builder.from_resource ("/io/github/tobagin/digger/shortcuts-dialog.ui");
#endif
            var dialog = builder.get_object ("shortcuts_dialog") as Adw.ShortcutsDialog;
            dialog.present (parent);
        }
    }
}