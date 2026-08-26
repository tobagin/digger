/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 */

namespace Digger {

    public class QueryTemplate : Object {
        public string name { get; set; }
        public string description { get; set; default = ""; }
        public string domain_template { get; set; }
        public RecordType record_type { get; set; default = RecordType.A; }
        public string? dns_server { get; set; default = null; }
        public bool reverse_lookup { get; set; default = false; }
        public bool trace_path { get; set; default = false; }
        public bool short_output { get; set; default = false; }
        public bool dnssec { get; set; default = false; }
        public DateTime created { get; set; }
        public Gee.HashMap<string,string> param_defaults { get; set; }

        public QueryTemplate (string name, string domain_template, RecordType record_type = RecordType.A) {
            this.name = name;
            this.domain_template = domain_template;
            this.record_type = record_type;
            this.created = new DateTime.now_local ();
            this.param_defaults = new Gee.HashMap<string,string> ();
        }

        public QueryTemplate.from_json (Json.Object obj) {
            this.name = obj.get_string_member ("name");
            this.description = obj.has_member ("description") ? obj.get_string_member ("description") : "";
            this.domain_template = obj.has_member ("domainTemplate") ? obj.get_string_member ("domainTemplate") : (obj.has_member ("domain_template") ? obj.get_string_member ("domain_template") : "");
            this.record_type = RecordType.from_string (obj.has_member ("recordType") ? obj.get_string_member ("recordType") : "A");
            this.dns_server = obj.has_member ("dnsServer") && !obj.get_null_member ("dnsServer") ? obj.get_string_member ("dnsServer") : null;
            this.reverse_lookup = obj.has_member ("reverseLookup") ? obj.get_boolean_member ("reverseLookup") : false;
            this.trace_path = obj.has_member ("tracePath") ? obj.get_boolean_member ("tracePath") : false;
            this.short_output = obj.has_member ("shortOutput") ? obj.get_boolean_member ("shortOutput") : false;
            this.dnssec = obj.has_member ("dnssec") ? obj.get_boolean_member ("dnssec") : false;
            if (obj.has_member ("created")) {
                this.created = new DateTime.from_unix_local (obj.get_int_member ("created"));
            } else {
                this.created = new DateTime.now_local ();
            }
            this.param_defaults = new Gee.HashMap<string,string> ();
            if (obj.has_member ("paramDefaults")) {
                var pd = obj.get_object_member ("paramDefaults");
                foreach (var k in pd.get_members ()) {
                    param_defaults[k] = pd.get_string_member (k);
                }
            }
        }

        public Json.Object to_json () {
            var obj = new Json.Object ();
            obj.set_string_member ("name", name);
            obj.set_string_member ("description", description);
            obj.set_string_member ("domainTemplate", domain_template);
            obj.set_string_member ("recordType", record_type.to_string ());
            if (dns_server != null && dns_server.length > 0) obj.set_string_member ("dnsServer", dns_server); else obj.set_null_member ("dnsServer");
            obj.set_boolean_member ("reverseLookup", reverse_lookup);
            obj.set_boolean_member ("tracePath", trace_path);
            obj.set_boolean_member ("shortOutput", short_output);
            obj.set_boolean_member ("dnssec", dnssec);
            obj.set_int_member ("created", created.to_unix ());
            var pd = new Json.Object ();
            foreach (var e in param_defaults.entries) pd.set_string_member (e.key, e.value);
            obj.set_object_member ("paramDefaults", pd);
            return obj;
        }

        public string get_display_name () { return name; }
        public string get_summary () {
            var parts = new Gee.ArrayList<string> ();
            parts.add (record_type.to_string ());
            parts.add (domain_template);
            if (dns_server != null && dns_server.length > 0) parts.add (@"Server: $dns_server");
            if (dnssec) parts.add ("DNSSEC");
            if (trace_path) parts.add ("Trace");
            return string.joinv (", ", parts.to_array ());
        }
    }

    // Persistence strategy: file-backed JSON at XDG_DATA_DIR/digger/templates.json
    // (chosen over GSettings to mirror FavoritesManager pattern, allow larger payloads,
    // and keep template library independent of the gschema; see commit for rationale).
    public class TemplateManager : Object {
        private static TemplateManager? instance = null;
        private Gee.ArrayList<QueryTemplate> templates;
        private Gee.HashMap<string, QueryTemplate> templates_map;
        private File templates_file;
        private uint save_debounce_id = 0;

        public signal void templates_updated ();
        public signal void error_occurred (string error_message);

        public static TemplateManager get_instance () {
            if (instance == null) instance = new TemplateManager ();
            return instance;
        }

        // For tests: create isolated instance with custom file
        public TemplateManager.with_file (File file) {
            templates = new Gee.ArrayList<QueryTemplate> ();
            templates_map = new Gee.HashMap<string, QueryTemplate> ();
            templates_file = file;
            load_sync ();
        }

        private TemplateManager () {
            templates = new Gee.ArrayList<QueryTemplate> ();
            templates_map = new Gee.HashMap<string, QueryTemplate> ();
            var data_dir = File.new_for_path (Environment.get_user_data_dir ()).get_child ("digger");
            try { if (!data_dir.query_exists ()) data_dir.make_directory_with_parents (); } catch (Error e) {
                critical ("Failed to create data dir: %s", e.message);
            }
            templates_file = data_dir.get_child ("templates.json");
            load_sync ();
        }

        private string normalize (string name) { return name.strip ().down (); }

        private void load_sync () {
            if (!templates_file.query_exists ()) return;
            try {
                uint8[] contents;
                string etag;
                templates_file.load_contents (null, out contents, out etag);
                var parser = new Json.Parser ();
                parser.load_from_data ((string) contents);
                var root = parser.get_root ();
                if (root != null && root.get_node_type () == Json.NodeType.ARRAY) {
                    var arr = root.get_array ();
                    templates.clear (); templates_map.clear ();
                    arr.foreach_element ((a, i, node) => {
                        if (node.get_node_type () != Json.NodeType.OBJECT) {
                            warning ("Skipping non-object template at index %u", i);
                            return;
                        }
                        try {
                            var t = new QueryTemplate.from_json (node.get_object ());
                            if (t.name.strip ().length == 0) { message ("Skipping template with empty name at %u", i); return; }
                            var key = normalize (t.name);
                            if (templates_map.has_key (key)) { message ("Skipping duplicate template name '%s' at %u", t.name, i); return; }
                            templates.add (t);
                            templates_map[key] = t;
                        } catch (Error e) {
                            warning ("Failed to parse template at index %u: %s", i, e.message);
                        }
                    });
                }
            } catch (Error e) {
                critical ("Failed to load templates from %s: %s", templates_file.get_path (), e.message);
                error_occurred ("Failed to load templates");
            }
        }

        public async void load_async () { load_sync (); }

        private void save_sync () {
            try {
                var gen = new Json.Generator ();
                var root = new Json.Node (Json.NodeType.ARRAY);
                var arr = new Json.Array ();
                foreach (var t in templates) {
                    var n = new Json.Node (Json.NodeType.OBJECT);
                    n.set_object (t.to_json ());
                    arr.add_element (n);
                }
                root.set_array (arr);
                gen.set_root (root);
                gen.set_pretty (true);
                string data = gen.to_data (null);
                // ensure dir exists
                var parent = templates_file.get_parent ();
                if (!parent.query_exists ()) parent.make_directory_with_parents ();
                string? new_etag;
                templates_file.replace_contents (data.data, null, false, FileCreateFlags.REPLACE_DESTINATION, out new_etag, null);
            } catch (Error e) {
                critical ("Failed to save templates: %s", e.message);
                error_occurred ("Failed to save templates");
            }
        }

        private void schedule_save () {
            if (save_debounce_id != 0) Source.remove (save_debounce_id);
            save_debounce_id = Timeout.add (100, () => {
                save_debounce_id = 0;
                save_sync ();
                return Source.REMOVE;
            });
        }

        public void flush () {
            if (save_debounce_id != 0) { Source.remove (save_debounce_id); save_debounce_id = 0; }
            save_sync ();
        }

        public Gee.ArrayList<QueryTemplate> get_all () { return templates; }
        public QueryTemplate? get_by_name (string name) {
            var k = normalize (name);
            return templates_map.has_key (k) ? templates_map[k] : null;
        }

        public bool validate_template (QueryTemplate t) {
            if (t.name.strip ().length == 0) return false;
            return true;
        }

        public bool add_template (QueryTemplate t) {
            if (t.name.strip ().length == 0) { error_occurred ("Template name cannot be empty"); return false; }
            if (get_by_name (t.name) != null) { error_occurred (@"A template named '$(t.name.strip())' already exists"); return false; }
            t.name = t.name.strip ();
            templates.add (t);
            templates_map[normalize (t.name)] = t;
            schedule_save ();
            templates_updated ();
            return true;
        }

        public bool update_template (QueryTemplate t, string? new_name = null) {
            int idx = -1;
            for (int i=0;i<templates.size;i++) if (templates.get(i)==t) { idx=i; break; }
            if (idx < 0) { error_occurred ("Template not found"); return false; }
            if (new_name != null && normalize (new_name) != normalize (t.name)) {
                if (new_name.strip ().length == 0) { error_occurred ("Template name cannot be empty"); return false; }
                if (get_by_name (new_name) != null) { error_occurred (@"A template named '$(new_name.strip())' already exists"); return false; }
                templates_map.unset (normalize (t.name));
                t.name = new_name.strip ();
                templates_map[normalize (t.name)] = t;
            }
            schedule_save ();
            templates_updated ();
            return true;
        }

        public bool delete_template (QueryTemplate t) {
            bool removed = templates.remove (t);
            if (removed) {
                templates_map.unset (normalize (t.name));
                schedule_save ();
                templates_updated ();
            }
            return removed;
        }

        public void clear_all () {
            templates.clear (); templates_map.clear ();
            schedule_save ();
            templates_updated ();
        }

        // For tests: synchronous clear+save
        public void clear_all_sync () {
            templates.clear (); templates_map.clear ();
            save_sync ();
            templates_updated ();
        }

        // ---- Substitution ----
        // Policy: missing value keeps literal {{key}} and caller can detect via has_unresolved_placeholders
        // Keys: alphanumeric + underscore, dot, hyphen; whitespace tolerated inside braces
        private static Regex? placeholder_regex = null;
        private static Regex get_regex () {
            if (placeholder_regex == null) {
                try { placeholder_regex = new Regex ("\\{\\{\\s*([A-Za-z0-9_\\.-]+)\\s*\\}\\}"); }
                catch (Error e) { critical ("Regex failed: %s", e.message); }
            }
            return placeholder_regex;
        }

        public Gee.ArrayList<string> extract_placeholders (string template) {
            var result = new Gee.ArrayList<string> ();
            var seen = new Gee.HashSet<string> ();
            try {
                var re = get_regex ();
                MatchInfo mi;
                if (re.match (template, 0, out mi)) {
                    do {
                        var key = mi.fetch (1);
                        if (!seen.contains (key)) { seen.add (key); result.add (key); }
                    } while (mi.next ());
                }
            } catch (Error e) { warning ("extract_placeholders: %s", e.message); }
            return result;
        }

        public string substitute_parameters (string template, Gee.HashMap<string,string> values) {
            if (template.length == 0) return template;
            try {
                var re = get_regex ();
                // Use eval callback to replace only known keys; keep literal for missing
                return re.replace_eval (template, -1, 0, 0, (mi, res) => {
                    var key = mi.fetch (1);
                    var full = mi.fetch (0);
                    if (values.has_key (key)) {
                        var v = values[key].strip ();
                        res.append (v);
                    } else {
                        res.append (full);
                    }
                    return false;
                });
            } catch (Error e) {
                warning ("substitute_parameters: %s", e.message);
                return template;
            }
        }

        public bool has_unresolved_placeholders (string text) {
            try {
                var re = get_regex ();
                MatchInfo mi;
                return re.match (text, 0, out mi);
            } catch (Error e) { return false; }
        }

        public string substitute_template (QueryTemplate t, Gee.HashMap<string,string> values) {
            // Merge param_defaults as fallback (values override defaults); last-wins for duplicate supplied keys already in map
            var merged = new Gee.HashMap<string,string> ();
            foreach (var e in t.param_defaults.entries) merged[e.key] = e.value;
            foreach (var e in values.entries) merged[e.key] = e.value;
            return substitute_parameters (t.domain_template, merged);
        }

        public bool validate_substituted_domain (string domain) {
            return ValidationUtils.is_valid_hostname (domain);
        }

        // Test helpers
        public File get_file () { return templates_file; }
        public void reload_sync () { load_sync (); }
    }
}
