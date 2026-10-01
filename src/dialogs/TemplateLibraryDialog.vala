/*
 * digger-vala - Template library dialog
 * Copyright (C) 2024-2026 Thiago Fernandes
 */
namespace Digger {
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/template-library-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/template-library-dialog.ui")]
#endif
    public class TemplateLibraryDialog : Adw.Dialog {
        [GtkChild] private unowned Gtk.SearchEntry search_entry;
        [GtkChild] private unowned Gtk.ListBox listbox;
        [GtkChild] private unowned Gtk.Label empty_label;
        [GtkChild] private unowned Gtk.Button close_button;

        public signal void template_selected (QueryTemplate template);

        private TemplateManager tm;

        public TemplateLibraryDialog () { Object (); tm = TemplateManager.get_instance (); }

        public override void constructed () {
            base.constructed ();
            close_button.clicked.connect (() => close ());
            search_entry.search_changed.connect (refresh);
            listbox.row_activated.connect (on_row_activated);
            tm.templates_updated.connect (refresh);
            // Adw.Dialog self-destructs on close; drop the singleton handler so a
            // closed dialog is not kept alive and refreshed forever.
            closed.connect (() => tm.templates_updated.disconnect (refresh));
            refresh ();
        }

        private void refresh () {
            // clear
            var child = listbox.get_first_child ();
            while (child != null) { var n=child.get_next_sibling (); listbox.remove (child); child=n; }
            var q = search_entry.text.down ().strip ();
            var all = tm.get_all ();
            int count=0;
            foreach (var t in all) {
                if (q.length>0 && !t.name.down ().contains (q) && !t.domain_template.down ().contains (q) && !t.description.down ().contains (q)) continue;
                var row = create_row (t);
                listbox.append (row);
                count++;
            }
            empty_label.visible = count==0;
            listbox.visible = count>0;
        }

        private Gtk.ListBoxRow create_row (QueryTemplate t) {
            var row = new Gtk.ListBoxRow ();
            row.set_data ("template", t);
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            box.margin_top=8; box.margin_bottom=8; box.margin_start=12; box.margin_end=12;
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            vbox.hexpand=true;
            var title = new Gtk.Label (t.name);
            title.halign=Gtk.Align.START; title.add_css_class ("heading");
            var sub = new Gtk.Label (t.get_summary ());
            sub.halign=Gtk.Align.START; sub.add_css_class ("dim-label");
            sub.wrap=true; sub.wrap_mode=Pango.WrapMode.WORD_CHAR;
            vbox.append (title); vbox.append (sub);
            box.append (vbox);
            var apply_btn = new Gtk.Button.with_label ("Apply");
            apply_btn.valign=Gtk.Align.CENTER; apply_btn.add_css_class ("suggested-action");
            apply_btn.clicked.connect (() => { handle_apply (t); });
            var del_btn = new Gtk.Button.from_icon_name ("user-trash-symbolic");
            del_btn.valign=Gtk.Align.CENTER; del_btn.add_css_class ("destructive-action");
            del_btn.tooltip_text="Delete template";
            del_btn.clicked.connect (() => confirm_delete (t));
            box.append (apply_btn); box.append (del_btn);
            row.set_child (box);
            return row;
        }

        private void on_row_activated (Gtk.ListBoxRow row) {
            var t = row.get_data<QueryTemplate> ("template");
            if (t != null) handle_apply (t);
        }

        private void handle_apply (QueryTemplate t) {
            var placeholders = tm.extract_placeholders (t.domain_template);
            if (placeholders.size>0) {
                // Check if any placeholder missing default/value - show param prompt
                var values = new Gee.HashMap<string,string> ();
                bool need_prompt = false;
                foreach (var ph in placeholders) {
                    if (!t.param_defaults.has_key (ph) || t.param_defaults[ph].length==0) { need_prompt=true; break; }
                }
                if (need_prompt) {
                    show_param_prompt (t, placeholders);
                    return;
                }
                foreach (var e in t.param_defaults.entries) values[e.key]=e.value;
                template_selected (t);
                // Emit with values via substitute? Window will handle substitution
                close ();
                return;
            }
            template_selected (t);
            close ();
        }

        private void show_param_prompt (QueryTemplate t, Gee.ArrayList<string> placeholders) {
            var dialog = new Adw.AlertDialog ("Template Parameters", null);
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            box.margin_top=12; box.margin_start=12; box.margin_end=12;
            // NOTE: Adw.EntryRow implements Gtk.Editable but is NOT a Gtk.Entry;
            // store the editable interface, not a Gtk.Entry cast.
            var entries = new Gee.HashMap<string,Gtk.Editable> ();
            foreach (var ph in placeholders) {
                var row = new Adw.EntryRow ();
                row.title = ph;
                row.text = t.param_defaults.has_key (ph) ? t.param_defaults[ph] : "";
                box.append (row);
                entries[ph] = row;
            }
            dialog.set_extra_child (box);
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("apply", "Apply");
            dialog.set_response_appearance ("apply", Adw.ResponseAppearance.SUGGESTED);
            dialog.response.connect ((resp) => {
                if (resp=="apply") {
                    foreach (var ph in placeholders) {
                        var txt = entries[ph].text.strip ();
                        if (txt.length > 0) t.param_defaults[ph] = txt;
                        else t.param_defaults.unset (ph);
                    }
                    template_selected (t);
                    close ();
                }
            });
            dialog.present (this);
        }

        private void confirm_delete (QueryTemplate t) {
            var d = new Adw.AlertDialog (@"Delete '$(t.name)'?", "This cannot be undone.");
            d.add_response ("cancel", "Cancel");
            d.add_response ("delete", "Delete");
            d.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            d.response.connect ((resp) => {
                if (resp=="delete") { tm.delete_template (t); tm.flush (); }
            });
            d.present (this);
        }
    }
}
