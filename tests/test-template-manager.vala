using Digger;

private File tmp_file () {
    var dir = Environment.get_tmp_dir ();
    var path = Path.build_filename (dir, "digger-test-%d.json".printf (Random.int_range (0, int.MAX)));
    return File.new_for_path (path);
}

private QueryTemplate make_template (string name, string domain_tmpl="example.com", RecordType rt=RecordType.A) {
    var t = new QueryTemplate (name, domain_tmpl, rt);
    t.description="desc";
    return t;
}

// CRUD
void test_create_valid () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    assert (m.add_template (make_template ("t1")));
    assert (m.get_by_name ("t1") != null);
    try { f.delete (); } catch (Error e) {}
}
void test_duplicate_rejected () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    assert (m.add_template (make_template ("dup")));
    assert (!m.add_template (make_template ("dup")));
    assert (!m.add_template (make_template ("DUP")));
    try { f.delete (); } catch (Error e) {}
}
void test_empty_name_rejected () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    assert (!m.add_template (make_template ("")));
    assert (!m.add_template (make_template ("   ")));
    try { f.delete (); } catch (Error e) {}
}
void test_load_returns_saved () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var t = make_template ("loadme", "{{a}}.example.com", RecordType.MX); t.dns_server="1.1.1.1";
    assert (m.add_template (t)); m.flush ();
    var m2 = new TemplateManager.with_file (f);
    var g = m2.get_by_name ("loadme");
    assert (g != null); assert (g.domain_template=="{{a}}.example.com"); assert (g.dns_server=="1.1.1.1");
    try { f.delete (); } catch (Error e) {}
}
void test_update_rename_uniqueness () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var a = make_template ("a"); var b = make_template ("b");
    assert (m.add_template (a)); assert (m.add_template (b));
    assert (!m.update_template (a, "b"));
    assert (m.update_template (a, "c"));
    assert (m.get_by_name ("c") != null);
    try { f.delete (); } catch (Error e) {}
}
void test_delete_removes () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var t = make_template ("del");
    assert (m.add_template (t)); m.flush (); assert (m.delete_template (t)); m.flush ();
    var m2 = new TemplateManager.with_file (f);
    assert (m2.get_by_name ("del")==null);
    try { f.delete (); } catch (Error e) {}
}
void test_delete_nonexistent_noop () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var t = make_template ("x");
    assert (!m.delete_template (t));
    try { f.delete (); } catch (Error e) {}
}
void test_corrupt_skips_bad () {
    var f = tmp_file ();
    string bad = "[{\"name\":\"good\",\"domainTemplate\":\"a.com\",\"recordType\":\"A\"},{\"name\":\"\",\"domainTemplate\":\"bad\"},{\"name\":\"good2\",\"domainTemplate\":\"b.com\",\"recordType\":\"A\"}]";
    try { string e; f.replace_contents (bad.data, null, false, FileCreateFlags.REPLACE_DESTINATION, out e, null); } catch (Error e) {}
    var m = new TemplateManager.with_file (f);
    assert (m.get_all ().size==2);
    assert (m.get_by_name ("good")!=null);
    assert (m.get_by_name ("good2")!=null);
    try { f.delete (); } catch (Error e) {}
}
void test_persistence_roundtrip () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    assert (m.add_template (make_template ("rt1", "foo.{{x}}.com"))); m.flush ();
    var m2 = new TemplateManager.with_file (f);
    assert (m2.get_all ().size==1);
    try { f.delete (); } catch (Error e) {}
}

// Substitution
void test_sub_single () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["domain"]="example";
    assert (m.substitute_parameters ("www.{{domain}}.com", vals)=="www.example.com");
    try { f.delete (); } catch (Error e) {}
}
void test_sub_two () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["a"]="foo"; vals["b"]="bar";
    assert (m.substitute_parameters ("{{a}}-{{b}}", vals)=="foo-bar");
    try { f.delete (); } catch (Error e) {}
}
void test_sub_whitespace () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["domain"]="x";
    assert (m.substitute_parameters ("{{ domain }}", vals)=="x");
    assert (m.substitute_parameters ("{{  domain   }}", vals)=="x");
    try { f.delete (); } catch (Error e) {}
}
void test_sub_missing_keeps () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>();
    var res = m.substitute_parameters ("{{missing}}.com", vals);
    assert (res.contains ("{{missing}}"));
    assert (m.has_unresolved_placeholders (res));
    try { f.delete (); } catch (Error e) {}
}
void test_sub_duplicate_twice () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["x"]="1";
    assert (m.substitute_parameters ("{{x}}-{{x}}", vals)=="1-1");
    try { f.delete (); } catch (Error e) {}
}
void test_sub_no_placeholder_identity () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["a"]="b";
    assert (m.substitute_parameters ("example.com", vals)=="example.com");
    try { f.delete (); } catch (Error e) {}
}
void test_sub_empty_map_keeps () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>();
    var res = m.substitute_parameters ("{{a}}.com", vals);
    assert (res.contains ("{{a}}"));
    try { f.delete (); } catch (Error e) {}
}
void test_sub_hyphen_underscore_dot_keys () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["my-key"]="1"; vals["my_key"]="2"; vals["my.key"]="3";
    assert (m.substitute_parameters ("{{my-key}}", vals)=="1");
    assert (m.substitute_parameters ("{{my_key}}", vals)=="2");
    assert (m.substitute_parameters ("{{my.key}}", vals)=="3");
    try { f.delete (); } catch (Error e) {}
}
void test_sub_long_domain () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["a"]=string.nfill (300,'x');
    var res = m.substitute_parameters ("{{a}}.com", vals);
    assert (res.length>253);
    try { f.delete (); } catch (Error e) {}
}
void test_sub_malformed_not_substituted () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["a"]="1";
    // single brace should not substitute
    assert (m.substitute_parameters ("{a}", vals)=="{a}");
    assert (m.substitute_parameters ("{{a}", vals)=="{{a}");
    assert (m.substitute_parameters ("{{a }", vals)=="{{a }");
    assert (m.substitute_parameters ("a}}", vals)=="a}}");
    try { f.delete (); } catch (Error e) {}
}
void test_sub_adjacent () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["a"]="foo"; vals["b"]="bar";
    assert (m.substitute_parameters ("{{a}}{{b}}", vals)=="foobar");
    try { f.delete (); } catch (Error e) {}
}
void test_sub_value_trimmed () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["domain"]="  example  ";
    assert (m.substitute_parameters ("www.{{domain}}.com", vals)=="www.example.com");
    try { f.delete (); } catch (Error e) {}
}
void test_sub_keys_case_sensitive () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["Domain"]="UPPER";
    // lower case key should not match upper case entry
    assert (m.substitute_parameters ("{{domain}}.com", vals)=="{{domain}}.com");
    assert (m.substitute_parameters ("{{Domain}}.com", vals)=="UPPER.com");
    try { f.delete (); } catch (Error e) {}
}
void test_sub_empty_template () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["a"]="1";
    assert (m.substitute_parameters ("", vals)=="");
    try { f.delete (); } catch (Error e) {}
}
void test_sub_boundary_placeholder () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var vals = new Gee.HashMap<string,string>(); vals["a"]="solo";
    assert (m.substitute_parameters ("{{a}}", vals)=="solo");
    try { f.delete (); } catch (Error e) {}
}
void test_extract_placeholders () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var list = m.extract_placeholders ("{{a}}.{{b}} and {{a}}");
    assert (list.size==2);
    assert (list.contains ("a")); assert (list.contains ("b"));
    try { f.delete (); } catch (Error e) {}
}
void test_apply_correctness () {
    var f = tmp_file (); var m = new TemplateManager.with_file (f);
    var t = new QueryTemplate ("tpl", "{{subdomain}}.example.com", RecordType.MX);
    t.dns_server="1.1.1.1";
    var vals = new Gee.HashMap<string,string>(); vals["subdomain"]="mail";
    var dom = m.substitute_template (t, vals);
    assert (dom=="mail.example.com");
    assert (ValidationUtils.is_valid_hostname (dom));
    // invalid substitution should fail validation
    vals["subdomain"]="bad..host";
    var dom2 = m.substitute_template (t, vals);
    assert (!ValidationUtils.is_valid_hostname (dom2));
    try { f.delete (); } catch (Error e) {}
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/template/crud/create_valid", test_create_valid);
    Test.add_func ("/template/crud/duplicate_rejected", test_duplicate_rejected);
    Test.add_func ("/template/crud/empty_name_rejected", test_empty_name_rejected);
    Test.add_func ("/template/crud/load_returns_saved", test_load_returns_saved);
    Test.add_func ("/template/crud/update_rename", test_update_rename_uniqueness);
    Test.add_func ("/template/crud/delete_removes", test_delete_removes);
    Test.add_func ("/template/crud/delete_noop", test_delete_nonexistent_noop);
    Test.add_func ("/template/crud/corrupt_skips", test_corrupt_skips_bad);
    Test.add_func ("/template/crud/roundtrip", test_persistence_roundtrip);
    Test.add_func ("/template/sub/single", test_sub_single);
    Test.add_func ("/template/sub/two", test_sub_two);
    Test.add_func ("/template/sub/whitespace", test_sub_whitespace);
    Test.add_func ("/template/sub/missing_keeps", test_sub_missing_keeps);
    Test.add_func ("/template/sub/duplicate", test_sub_duplicate_twice);
    Test.add_func ("/template/sub/no_placeholder", test_sub_no_placeholder_identity);
    Test.add_func ("/template/sub/empty_map", test_sub_empty_map_keeps);
    Test.add_func ("/template/sub/keys", test_sub_hyphen_underscore_dot_keys);
    Test.add_func ("/template/sub/long_domain", test_sub_long_domain);
    Test.add_func ("/template/sub/malformed", test_sub_malformed_not_substituted);
    Test.add_func ("/template/sub/adjacent", test_sub_adjacent);
    Test.add_func ("/template/sub/trimmed", test_sub_value_trimmed);
    Test.add_func ("/template/sub/case_sensitive", test_sub_keys_case_sensitive);
    Test.add_func ("/template/sub/empty_template", test_sub_empty_template);
    Test.add_func ("/template/sub/boundary", test_sub_boundary_placeholder);
    Test.add_func ("/template/sub/extract", test_extract_placeholders);
    Test.add_func ("/template/sub/apply_correctness", test_apply_correctness);
    return Test.run ();
}
