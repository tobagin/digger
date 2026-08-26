/*
 * digger-vala - Template creation/edit dialog
 * Copyright (C) 2024-2026 Thiago Fernandes
 */
namespace Digger {
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/template-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/template-dialog.ui")]
#endif
    public class TemplateDialog : Adw.Dialog {
        [GtkChild] private unowned Adw.EntryRow name_row;
        [GtkChild] private unowned Adw.EntryRow description_row;
        [GtkChild] private unowned Adw.EntryRow domain_template_row;
        [GtkChild] private unowned Gtk.DropDown record_type_dropdown;
        [GtkChild] private unowned Gtk.DropDown dns_server_dropdown;
        [GtkChild] private unowned Adw.SwitchRow reverse_row;
        [GtkChild] private unowned Adw.SwitchRow trace_row;
        [GtkChild] private unowned Adw.SwitchRow short_row;
        [GtkChild] private unowned Adw.SwitchRow dnssec_row;
        [GtkChild] private unowned Gtk.Label error_label;
        [GtkChild] private unowned Gtk.Button save_button;
        [GtkChild] private unowned Gtk.Button cancel_button;

        private DnsPresets dns_presets;
        private QueryTemplate? editing_template = null;
        private TemplateManager tm;

        public signal void template_saved (QueryTemplate template);

        public TemplateDialog (QueryTemplate? existing = null) {
            Object ();
            tm = TemplateManager.get_instance ();
            dns_presets = DnsPresets.get_instance ();
            editing_template = existing;
            // NOTE: constructed() runs inside g_object_new, i.e. BEFORE the body
            // above assigns these fields, so population must happen here.
            if (editing_template != null) populate_from_template (editing_template);
            validate ();
        }

        public TemplateDialog.with_initial (QueryTemplate initial) {
            Object ();
            tm = TemplateManager.get_instance ();
            dns_presets = DnsPresets.get_instance ();
            editing_template = null;
            // Store initial values to populate after constructed
            _initial_template = initial;
            populate_from_template (_initial_template);
            validate ();
        }

        private QueryTemplate? _initial_template = null;

        public override void constructed () {
            base.constructed ();
            setup_dropdowns ();
            cancel_button.clicked.connect (() => close ());
            save_button.clicked.connect (on_save);
            name_row.notify["text"].connect (validate);
            domain_template_row.notify["text"].connect (validate);
        }

        private void setup_dropdowns () {
            // record type
            var rt_model = new Gtk.StringList (null);
            var infos = new Gee.ArrayList<RecordTypeInfo> ();
            infos.add_all (DnsPresets.get_instance ().get_all_record_types ());
            infos.sort ((a,b) => strcmp (a.record_type, b.record_type));
            foreach (var i in infos) rt_model.append (i.get_display_name ());
            record_type_dropdown.model = rt_model;
            // dns server
            var ds_model = new Gtk.StringList (null);
            ds_model.append ("System Default");
            foreach (var s in DnsPresets.get_instance ().get_dns_servers ()) ds_model.append (s.get_display_name ());
            dns_server_dropdown.model = ds_model;
        }

        private void populate_from_template (QueryTemplate t) {
            name_row.text = t.name;
            description_row.text = t.description;
            domain_template_row.text = t.domain_template;
            // record type select
            var rt_model = record_type_dropdown.model as Gtk.StringList;
            for (uint i=0;i<rt_model.get_n_items ();i++) {
                if ((rt_model.get_string (i).split (" - ")[0]) == t.record_type.to_string ()) { record_type_dropdown.selected = i; break; }
            }
            if (t.dns_server != null && t.dns_server.length>0) {
                var ds_model = dns_server_dropdown.model as Gtk.StringList;
                for (uint i=0;i<ds_model.get_n_items ();i++) {
                    if (ds_model.get_string (i).contains (t.dns_server)) { dns_server_dropdown.selected = i; break; }
                }
            }
            reverse_row.active = t.reverse_lookup;
            trace_row.active = t.trace_path;
            short_row.active = t.short_output;
            dnssec_row.active = t.dnssec;
        }

        private void validate () {
            bool name_ok = name_row.text.strip ().length > 0;
            bool domain_ok = domain_template_row.text.strip ().length > 0;
            save_button.sensitive = name_ok && domain_ok;
            if (!name_ok) error_label.label = "Name is required";
            else if (!domain_ok) error_label.label = "Domain template is required";
            else error_label.label = "";
        }

        private RecordType get_selected_record_type () {
            var m = record_type_dropdown.model as Gtk.StringList;
            var s = m.get_string (record_type_dropdown.selected);
            return RecordType.from_string (s.split (" - ")[0]);
        }

        private string? get_selected_dns_server () {
            if (dns_server_dropdown.selected == 0) return null;
            var servers = DnsPresets.get_instance ().get_dns_servers ();
            int idx = (int)dns_server_dropdown.selected - 1;
            if (idx >=0 && idx < servers.size) return servers.get (idx).primary;
            return null;
        }

        private void on_save () {
            var name = name_row.text.strip ();
            var domain_tmpl = domain_template_row.text.strip ();
            if (name.length==0 || domain_tmpl.length==0) return;
            if (editing_template != null) {
                // update in place
                bool is_rename = name != editing_template.name;
                if (is_rename) {
                    // check duplicate via manager
                    if (tm.get_by_name (name) != null && tm.get_by_name (name) != editing_template) {
                        error_label.label = @"A template named '$name' already exists";
                        return;
                    }
                }
                editing_template.description = description_row.text;
                editing_template.domain_template = domain_tmpl;
                editing_template.record_type = get_selected_record_type ();
                editing_template.dns_server = get_selected_dns_server ();
                editing_template.reverse_lookup = reverse_row.active;
                editing_template.trace_path = trace_row.active;
                editing_template.short_output = short_row.active;
                editing_template.dnssec = dnssec_row.active;
                // auto param defaults from placeholders
                var holders = tm.extract_placeholders (domain_tmpl);
                foreach (var h in holders) if (!editing_template.param_defaults.has_key (h)) editing_template.param_defaults[h] = "";
                if (!tm.update_template (editing_template, is_rename ? name : null)) {
                    error_label.label = "Failed to update template";
                    return;
                }
                tm.flush ();
                template_saved (editing_template);
            } else {
                var t = new QueryTemplate (name, domain_tmpl, get_selected_record_type ());
                t.description = description_row.text;
                t.dns_server = get_selected_dns_server ();
                t.reverse_lookup = reverse_row.active;
                t.trace_path = trace_row.active;
                t.short_output = short_row.active;
                t.dnssec = dnssec_row.active;
                var holders = tm.extract_placeholders (domain_tmpl);
                foreach (var h in holders) t.param_defaults[h] = "";
                if (!tm.add_template (t)) {
                    error_label.label = @"A template named '$name' already exists";
                    return;
                }
                tm.flush ();
                template_saved (t);
            }
            close ();
        }
    }
}
