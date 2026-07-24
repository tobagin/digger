/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger.UiUtils {
    /**
     * Apply a "system"/"light"/"dark" color scheme string to the app style manager.
     */
    public void apply_color_scheme (string scheme) {
        Adw.StyleManager.get_default ().color_scheme = scheme == "light"
            ? Adw.ColorScheme.FORCE_LIGHT
            : scheme == "dark" ? Adw.ColorScheme.FORCE_DARK : Adw.ColorScheme.DEFAULT;
    }

    /**
     * Remove all children from a Gtk.Box or Gtk.ListBox container
     */
    public void clear_children (Gtk.Widget parent) {
        var child = parent.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            if (parent is Gtk.ListBox) {
                ((Gtk.ListBox) parent).remove (child);
            } else if (parent is Gtk.Box) {
                ((Gtk.Box) parent).remove (child);
            } else {
                child.unparent ();
            }
            child = next;
        }
    }

    /**
     * Show a toast on the nearest ancestor Adw.ToastOverlay of the given widget.
     * Does nothing if no overlay is found.
     */
    public void show_toast (Gtk.Widget origin, string message, int timeout = Constants.TOAST_TIMEOUT_SECONDS) {
        var parent = origin.get_parent ();
        while (parent != null && !(parent is Adw.ToastOverlay)) {
            parent = parent.get_parent ();
        }

        if (parent is Adw.ToastOverlay) {
            var toast = new Adw.Toast (message) {
                timeout = timeout
            };
            ((Adw.ToastOverlay) parent).add_toast (toast);
        }
    }

    /**
     * Build a Gtk.FileDialog with the given title, optional initial file name
     * and file filters. filter_names and filter_patterns are parallel arrays;
     * a patterns entry may contain multiple patterns separated by ";".
     * The first filter becomes the default filter.
     */
    public Gtk.FileDialog create_file_dialog (string title, string? initial_name,
                                              string[] filter_names, string[] filter_patterns) {
        var dialog = new Gtk.FileDialog () {
            title = title,
            modal = true
        };

        if (initial_name != null) {
            dialog.initial_name = initial_name;
        }

        var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
        for (int i = 0; i < filter_names.length; i++) {
            var filter = new Gtk.FileFilter ();
            filter.set_filter_name (filter_names[i]);
            foreach (var pattern in filter_patterns[i].split (";")) {
                filter.add_pattern (pattern);
            }
            filters.append (filter);
        }
        dialog.filters = filters;

        if (filters.get_n_items () > 0) {
            dialog.default_filter = (Gtk.FileFilter) filters.get_item (0);
        }

        return dialog;
    }

    /**
     * Build the common 6-entry record type model used by batch and comparison dialogs
     */
    public Gtk.StringList create_common_record_type_model () {
        var model = new Gtk.StringList (null);
        model.append ("A - IPv4 Address");
        model.append ("AAAA - IPv6 Address");
        model.append ("MX - Mail Exchange");
        model.append ("TXT - Text Record");
        model.append ("NS - Name Server");
        model.append ("CNAME - Canonical Name");
        return model;
    }

    /**
     * Read the selected record type from a dropdown whose model entries
     * follow the "CODE - Description" convention
     */
    public RecordType get_selected_record_type (Gtk.DropDown dropdown) {
        var selected_text = ((Gtk.StringList) dropdown.model).get_string (dropdown.selected);
        return RecordType.from_string (selected_text.split (" - ")[0]);
    }
}
