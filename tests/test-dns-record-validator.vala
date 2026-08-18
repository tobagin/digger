/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 */

using Digger;

// Helpers
private string long_label (int len) {
    var sb = new StringBuilder ();
    for (int i = 0; i < len; i++) sb.append_c ('a');
    return sb.str;
}

private string repeat_char (string c, int n) {
    var sb = new StringBuilder ();
    for (int i = 0; i < n; i++) sb.append (c);
    return sb.str;
}

// ---------- A ----------
void test_a_valid_1() { var r = DnsRecordValidator.validate_by_type (RecordType.A, "1.1.1.1"); assert (r.is_valid); assert (r.errors.size == 0); }
void test_a_valid_2() { var r = DnsRecordValidator.validate_by_type (RecordType.A, "192.168.0.1"); assert (r.is_valid); }
void test_a_valid_zero() { var r = DnsRecordValidator.validate_by_type (RecordType.A, "0.0.0.0"); assert (r.is_valid); }
void test_a_valid_broadcast() { var r = DnsRecordValidator.validate_by_type (RecordType.A, "255.255.255.255"); assert (r.is_valid); }
void test_a_invalid_256() { var r = DnsRecordValidator.validate_by_type (RecordType.A, "256.0.0.1"); assert (!r.is_valid); assert (r.errors.size == 1); assert (r.errors[0].code == ValidationCode.INVALID_IPV4); }
void test_a_invalid_short() { var r = DnsRecordValidator.validate_by_type (RecordType.A, "1.2.3"); assert (!r.is_valid); assert (r.errors[0].code == ValidationCode.INVALID_IPV4); }
void test_a_invalid_long() { var r = DnsRecordValidator.validate_by_type (RecordType.A, "1.2.3.4.5"); assert (!r.is_valid); }
void test_a_invalid_hostname() { var r = DnsRecordValidator.validate_by_type (RecordType.A, "example.com"); assert (!r.is_valid); assert (r.errors[0].code == ValidationCode.INVALID_IPV4); }
void test_a_invalid_empty() { var r = DnsRecordValidator.validate_by_type (RecordType.A, ""); assert (!r.is_valid); }
void test_a_invalid_trailing_space_value() { var r = DnsRecordValidator.validate_by_type (RecordType.A, "1.2.3.4 "); assert (r.is_valid); // stripped, should be valid
}
void test_a_reject_trailing_chars() { var r = DnsRecordValidator.validate_by_type (RecordType.A, "1.2.3.4abc"); assert (!r.is_valid); }

// ---------- AAAA ----------
void test_aaaa_valid_compressed() { var r = DnsRecordValidator.validate_by_type (RecordType.AAAA, "2001:db8::1"); assert (r.is_valid); }
void test_aaaa_valid_loopback() { var r = DnsRecordValidator.validate_by_type (RecordType.AAAA, "::1"); assert (r.is_valid); }
void test_aaaa_valid_unspecified() { var r = DnsRecordValidator.validate_by_type (RecordType.AAAA, "::"); assert (r.is_valid); }
void test_aaaa_valid_full() { var r = DnsRecordValidator.validate_by_type (RecordType.AAAA, "2001:0db8:85a3:0000:0000:8a2e:0370:7334"); assert (r.is_valid); }
void test_aaaa_valid_mapped() { var r = DnsRecordValidator.validate_by_type (RecordType.AAAA, "::ffff:192.0.2.1"); assert (r.is_valid); }
void test_aaaa_invalid_gggg() { var r = DnsRecordValidator.validate_by_type (RecordType.AAAA, "gggg::1"); assert (!r.is_valid); assert (r.errors[0].code == ValidationCode.INVALID_IPV6); }
void test_aaaa_invalid_too_many() { var r = DnsRecordValidator.validate_by_type (RecordType.AAAA, "1:2:3:4:5:6:7:8:9"); assert (!r.is_valid); }
void test_aaaa_invalid_triple_colon() { var r = DnsRecordValidator.validate_by_type (RecordType.AAAA, "2001:db8:::1"); assert (!r.is_valid); }
void test_aaaa_invalid_v4() { var r = DnsRecordValidator.validate_by_type (RecordType.AAAA, "192.168.1.1"); assert (!r.is_valid); }

// ---------- CNAME ----------
void test_cname_valid_fqdn() { var r = DnsRecordValidator.validate_by_type (RecordType.CNAME, "example.com."); assert (r.is_valid); }
void test_cname_valid_sub() { var r = DnsRecordValidator.validate_by_type (RecordType.CNAME, "sub.example.com"); assert (r.is_valid); }
void test_cname_valid_hyphen() { var r = DnsRecordValidator.validate_by_type (RecordType.CNAME, "a-b.example.co.uk"); assert (r.is_valid); }
void test_cname_invalid_ip() { var r = DnsRecordValidator.validate_by_type (RecordType.CNAME, "192.168.1.1"); assert (!r.is_valid); assert (r.errors[0].code == ValidationCode.CNAME_TARGET_IS_IP); assert (r.errors[0].message.contains ("IP")); }
void test_cname_invalid_double_dot() { var r = DnsRecordValidator.validate_by_type (RecordType.CNAME, "bad..hostname"); assert (!r.is_valid); assert (r.errors[0].code == ValidationCode.CNAME_TARGET_INVALID); }
void test_cname_invalid_leading_hyphen() { var r = DnsRecordValidator.validate_by_type (RecordType.CNAME, "-bad.example.com"); assert (!r.is_valid); }
void test_cname_invalid_long_label() { var r = DnsRecordValidator.validate_by_type (RecordType.CNAME, long_label (64) + ".example.com"); assert (!r.is_valid); }
void test_cname_invalid_empty() { var r = DnsRecordValidator.validate_by_type (RecordType.CNAME, ""); assert (!r.is_valid); }
void test_cname_invalid_total_too_long() {
    // Build >253 total
    string label = long_label (63);
    string domain = label + "." + label + "." + label + "." + label + ".com"; // 63*4 +4 dots +3 =259
    var r = DnsRecordValidator.validate_by_type (RecordType.CNAME, domain);
    assert (!r.is_valid);
}

// ---------- NS ----------
void test_ns_valid_1() { var r = DnsRecordValidator.validate_by_type (RecordType.NS, "ns1.example.com."); assert (r.is_valid); }
void test_ns_valid_2() { var r = DnsRecordValidator.validate_by_type (RecordType.NS, "ns2.example.net"); assert (r.is_valid); }
void test_ns_invalid_ip() { var r = DnsRecordValidator.validate_by_type (RecordType.NS, "10.0.0.1"); assert (!r.is_valid); assert (r.errors[0].code == ValidationCode.NS_TARGET_IS_IP); }
void test_ns_invalid_double_dot() { var r = DnsRecordValidator.validate_by_type (RecordType.NS, "ns1..example.com"); assert (!r.is_valid); }
void test_ns_invalid_empty() { var r = DnsRecordValidator.validate_by_type (RecordType.NS, ""); assert (!r.is_valid); }

// ---------- MX ----------
void test_mx_valid_with_priority_param() { var r = DnsRecordValidator.validate_by_type (RecordType.MX, "mail.example.com.", 10); assert (r.is_valid); }
void test_mx_valid_inline_priority() { var r = DnsRecordValidator.validate_by_type (RecordType.MX, "10 mail.example.com."); assert (r.is_valid); }
void test_mx_valid_null_mx() {
    var r = DnsRecordValidator.validate_by_type (RecordType.MX, "0 .");
    // null MX is warning not error
    assert (r.is_valid);
    assert (r.warnings.size == 1);
    assert (r.warnings[0].code == ValidationCode.MX_NULL_TARGET);
    assert (r.warnings[0].message.contains ("Null MX"));
}
void test_mx_valid_20() { var r = DnsRecordValidator.validate_by_type (RecordType.MX, "20 mx1.example.net"); assert (r.is_valid); }
void test_mx_invalid_priority_out_of_range_high() { var r = DnsRecordValidator.validate_by_type (RecordType.MX, "70000 mail.example.com."); assert (!r.is_valid); assert (r.errors[0].code == ValidationCode.MX_PRIORITY_OUT_OF_RANGE); }
void test_mx_invalid_priority_negative() { var r = DnsRecordValidator.validate_by_type (RecordType.MX, "mail.example.com.", -1); // fallback treats as missing priority? Actually priority -1 means parse value without priority param; value is hostname without priority -> should error priority
    // When priority=-1 and value is just hostname, validator tries to parse leading int and fails -> error
    assert (!r.is_valid);
}
void test_mx_invalid_priority_non_numeric() { var r = DnsRecordValidator.validate_by_type (RecordType.MX, "abc mail.example.com."); assert (!r.is_valid); }
void test_mx_invalid_target_ip() { var r = DnsRecordValidator.validate_by_type (RecordType.MX, "10 192.168.1.1"); assert (!r.is_valid); assert (r.errors[0].code == ValidationCode.MX_TARGET_IS_IP); }
void test_mx_invalid_target_bad_host() { var r = DnsRecordValidator.validate_by_type (RecordType.MX, "10 bad..host"); assert (!r.is_valid); assert (r.errors[0].code == ValidationCode.MX_TARGET_INVALID); }
void test_mx_invalid_missing_target() { var r = DnsRecordValidator.validate_by_type (RecordType.MX, "10"); assert (!r.is_valid); }
void test_mx_warning_target_is_cname_set() {
    var records = new Gee.ArrayList<DnsRecord> ();
    records.add (new DnsRecord ("example.com", RecordType.MX, 3600, "mail.example.com", 10));
    records.add (new DnsRecord ("mail.example.com", RecordType.CNAME, 3600, "other.example.com"));
    var r = DnsRecordValidator.validate_record_set (records);
    bool found = false;
    foreach (var w in r.warnings) if (w.code == ValidationCode.MX_TARGET_IS_CNAME) found = true;
    assert (found);
    assert (r.warnings[0].message.contains ("MX target"));
    assert (r.is_valid); // warnings don't invalidate
}

// ---------- TXT ----------
void test_txt_valid_empty_quoted() { var r = DnsRecordValidator.validate_by_type (RecordType.TXT, "\"\""); assert (r.is_valid); }
void test_txt_valid_hello() { var r = DnsRecordValidator.validate_by_type (RecordType.TXT, "\"hello world\""); assert (r.is_valid); }
void test_txt_valid_multi_chunk() { var r = DnsRecordValidator.validate_by_type (RecordType.TXT, "\"a\" \"b\""); assert (r.is_valid); }
void test_txt_valid_255() {
    string chunk = repeat_char ("a", 255);
    var r = DnsRecordValidator.validate_by_type (RecordType.TXT, "\"" + chunk + "\"");
    assert (r.is_valid);
}
void test_txt_invalid_256() {
    string chunk = repeat_char ("a", 256);
    var r = DnsRecordValidator.validate_by_type (RecordType.TXT, "\"" + chunk + "\"");
    assert (!r.is_valid);
    assert (r.errors[0].code == ValidationCode.TXT_CHUNK_TOO_LONG);
    assert (r.errors[0].message.contains ("255"));
}
void test_txt_invalid_unbalanced() { var r = DnsRecordValidator.validate_by_type (RecordType.TXT, "\"hello"); assert (!r.is_valid); assert (r.errors[0].code == ValidationCode.TXT_UNBALANCED_QUOTES); }
void test_txt_warn_unquoted_long() {
    string v = repeat_char ("a", 300);
    var r = DnsRecordValidator.validate_by_type (RecordType.TXT, v);
    // unquoted long should be warning TXT_CHUNK_TOO_LONG, still is_valid
    assert (r.is_valid);
    assert (r.warnings.size >= 1);
    assert (r.warnings[0].code == ValidationCode.TXT_CHUNK_TOO_LONG);
    assert (r.warnings[0].message.contains ("TXT"));
}

// ---------- SOA ----------
void test_soa_valid() {
    var r = DnsRecordValidator.validate_by_type (RecordType.SOA, "ns1.example.com. hostmaster.example.com. 2024010101 7200 3600 1209600 300");
    assert (r.is_valid);
}
void test_soa_valid_rname_with_at() {
    var r = DnsRecordValidator.validate_by_type (RecordType.SOA, "ns1.example.com. hostmaster@example.com 2024010101 7200 3600 1209600 300");
    assert (r.is_valid);
}
void test_soa_valid_trailing_dots() {
    var r = DnsRecordValidator.validate_by_type (RecordType.SOA, "ns1.example.com. hostmaster.example.com. 1 3600 900 604800 86400");
    assert (r.is_valid);
}
void test_soa_invalid_missing_fields() {
    var r = DnsRecordValidator.validate_by_type (RecordType.SOA, "ns1.example.com. hostmaster.example.com. 2024010101 7200 3600 1209600");
    assert (!r.is_valid);
    assert (r.errors[0].code == ValidationCode.SOA_MISSING_FIELDS);
    assert (r.errors[0].message.contains ("SOA"));
}
void test_soa_invalid_mname_ip() {
    var r = DnsRecordValidator.validate_by_type (RecordType.SOA, "192.168.1.1 hostmaster.example.com. 2024010101 7200 3600 1209600 300");
    assert (!r.is_valid);
    assert (r.errors[0].code == ValidationCode.SOA_MNAME_INVALID);
}
void test_soa_invalid_serial_negative() {
    var r = DnsRecordValidator.validate_by_type (RecordType.SOA, "ns1.example.com. hostmaster.example.com. -1 7200 3600 1209600 300");
    assert (!r.is_valid);
    assert (r.errors[0].code == ValidationCode.SOA_SERIAL_INVALID);
}
void test_soa_invalid_serial_overflow() {
    var r = DnsRecordValidator.validate_by_type (RecordType.SOA, "ns1.example.com. hostmaster.example.com. 4294967296 7200 3600 1209600 300");
    assert (!r.is_valid);
    assert (r.errors[0].code == ValidationCode.SOA_SERIAL_INVALID);
}
void test_soa_invalid_refresh_non_numeric() {
    var r = DnsRecordValidator.validate_by_type (RecordType.SOA, "ns1.example.com. hostmaster.example.com. 2024010101 abc 3600 1209600 300");
    assert (!r.is_valid);
    assert (r.errors[0].code == ValidationCode.SOA_REFRESH_INVALID);
}
void test_soa_warn_retry_greater_refresh() {
    var r = DnsRecordValidator.validate_by_type (RecordType.SOA, "ns1.example.com. hostmaster.example.com. 2024010101 3600 7200 1209600 300");
    assert (r.is_valid);
    bool found = false;
    foreach (var w in r.warnings) if (w.message.contains ("RETRY")) found = true;
    assert (found);
}
void test_soa_warn_expire_small() {
    var r = DnsRecordValidator.validate_by_type (RecordType.SOA, "ns1.example.com. hostmaster.example.com. 2024010101 7200 3600 1000 300");
    bool found = false;
    foreach (var w in r.warnings) if (w.code == ValidationCode.SOA_EXPIRE_INVALID) found = true;
    assert (found);
}
void test_soa_warn_serial_future() {
    // 2099010101 is far future
    var r = DnsRecordValidator.validate_by_type (RecordType.SOA, "ns1.example.com. hostmaster.example.com. 2099010101 7200 3600 1209600 300");
    bool found = false;
    foreach (var w in r.warnings) if (w.code == ValidationCode.SOA_SERIAL_INVALID) found = true;
    assert (found);
    assert (r.is_valid);
}

// ---------- set-level ----------
void test_set_cname_coexistence() {
    var records = new Gee.ArrayList<DnsRecord> ();
    records.add (new DnsRecord ("example.com", RecordType.CNAME, 3600, "foo.example.com"));
    records.add (new DnsRecord ("example.com", RecordType.A, 3600, "1.2.3.4"));
    var r = DnsRecordValidator.validate_record_set (records);
    assert (r.warnings.size >= 1);
    assert (r.warnings[0].code == ValidationCode.CNAME_COEXISTENCE);
    assert (r.warnings[0].message.contains ("CNAME"));
    assert (r.warnings[0].message.contains ("RFC 1034"));
    assert (r.is_valid);
}
void test_set_cname_duplicate() {
    var records = new Gee.ArrayList<DnsRecord> ();
    records.add (new DnsRecord ("example.com", RecordType.CNAME, 3600, "foo.example.com"));
    records.add (new DnsRecord ("example.com", RecordType.CNAME, 3600, "bar.example.com"));
    var r = DnsRecordValidator.validate_record_set (records);
    bool found = false;
    foreach (var w in r.warnings) if (w.code == ValidationCode.CNAME_COEXISTENCE) found = true;
    assert (found);
}
void test_set_no_cname_warning_distinct_owners() {
    var records = new Gee.ArrayList<DnsRecord> ();
    records.add (new DnsRecord ("a.example.com", RecordType.CNAME, 3600, "foo.example.com"));
    records.add (new DnsRecord ("b.example.com", RecordType.A, 3600, "1.2.3.4"));
    var r = DnsRecordValidator.validate_record_set (records);
    foreach (var w in r.warnings) assert (w.code != ValidationCode.CNAME_COEXISTENCE);
}
void test_set_soa_duplicate() {
    var records = new Gee.ArrayList<DnsRecord> ();
    records.add (new DnsRecord ("example.com", RecordType.SOA, 3600, "ns1.example.com. hostmaster.example.com. 1 7200 3600 1209600 300"));
    records.add (new DnsRecord ("example.com", RecordType.SOA, 3600, "ns1.example.com. hostmaster.example.com. 2 7200 3600 1209600 300"));
    var r = DnsRecordValidator.validate_record_set (records);
    bool found = false;
    foreach (var w in r.warnings) if (w.code == ValidationCode.SOA_DUPLICATE) found = true;
    assert (found);
    assert (r.warnings[0].message.contains ("SOA"));
}
void test_set_mx_target_is_cname() {
    var records = new Gee.ArrayList<DnsRecord> ();
    records.add (new DnsRecord ("example.com", RecordType.MX, 3600, "mail.example.com", 10));
    records.add (new DnsRecord ("mail.example.com", RecordType.CNAME, 3600, "other.example.com"));
    var r = DnsRecordValidator.validate_record_set (records);
    bool found = false;
    foreach (var w in r.warnings) if (w.code == ValidationCode.MX_TARGET_IS_CNAME) found = true;
    assert (found);
}
void test_is_valid_semantics_warnings_not_invalid() {
    var r = DnsRecordValidator.validate_by_type (RecordType.MX, "0 .");
    assert (r.is_valid);
    assert (r.has_warnings);
    assert (!r.has_errors);
}
void test_is_valid_semantics_errors_invalid() {
    var r = DnsRecordValidator.validate_by_type (RecordType.A, "999.999.999.999");
    assert (!r.is_valid);
    assert (r.has_errors);
}
void test_validate_dispatch_via_record() {
    var rec = new DnsRecord ("example.com", RecordType.A, 3600, "1.1.1.1");
    var r = DnsRecordValidator.validate (rec);
    assert (r.is_valid);
    rec.value = "999.999.999.999";
    var r2 = DnsRecordValidator.validate (rec);
    assert (!r2.is_valid);
}

int main (string[] args) {
    Test.init (ref args);
    // A
    Test.add_func ("/validator/a/valid_1", test_a_valid_1);
    Test.add_func ("/validator/a/valid_2", test_a_valid_2);
    Test.add_func ("/validator/a/valid_zero", test_a_valid_zero);
    Test.add_func ("/validator/a/valid_broadcast", test_a_valid_broadcast);
    Test.add_func ("/validator/a/invalid_256", test_a_invalid_256);
    Test.add_func ("/validator/a/invalid_short", test_a_invalid_short);
    Test.add_func ("/validator/a/invalid_long", test_a_invalid_long);
    Test.add_func ("/validator/a/invalid_hostname", test_a_invalid_hostname);
    Test.add_func ("/validator/a/invalid_empty", test_a_invalid_empty);
    Test.add_func ("/validator/a/trailing_space", test_a_invalid_trailing_space_value);
    Test.add_func ("/validator/a/reject_trailing_chars", test_a_reject_trailing_chars);
    // AAAA
    Test.add_func ("/validator/aaaa/valid_compressed", test_aaaa_valid_compressed);
    Test.add_func ("/validator/aaaa/valid_loopback", test_aaaa_valid_loopback);
    Test.add_func ("/validator/aaaa/valid_unspecified", test_aaaa_valid_unspecified);
    Test.add_func ("/validator/aaaa/valid_full", test_aaaa_valid_full);
    Test.add_func ("/validator/aaaa/valid_mapped", test_aaaa_valid_mapped);
    Test.add_func ("/validator/aaaa/invalid_gggg", test_aaaa_invalid_gggg);
    Test.add_func ("/validator/aaaa/invalid_too_many", test_aaaa_invalid_too_many);
    Test.add_func ("/validator/aaaa/invalid_triple_colon", test_aaaa_invalid_triple_colon);
    Test.add_func ("/validator/aaaa/invalid_v4", test_aaaa_invalid_v4);
    // CNAME
    Test.add_func ("/validator/cname/valid_fqdn", test_cname_valid_fqdn);
    Test.add_func ("/validator/cname/valid_sub", test_cname_valid_sub);
    Test.add_func ("/validator/cname/valid_hyphen", test_cname_valid_hyphen);
    Test.add_func ("/validator/cname/invalid_ip", test_cname_invalid_ip);
    Test.add_func ("/validator/cname/invalid_double_dot", test_cname_invalid_double_dot);
    Test.add_func ("/validator/cname/invalid_leading_hyphen", test_cname_invalid_leading_hyphen);
    Test.add_func ("/validator/cname/invalid_long_label", test_cname_invalid_long_label);
    Test.add_func ("/validator/cname/invalid_empty", test_cname_invalid_empty);
    Test.add_func ("/validator/cname/invalid_total_too_long", test_cname_invalid_total_too_long);
    // NS
    Test.add_func ("/validator/ns/valid_1", test_ns_valid_1);
    Test.add_func ("/validator/ns/valid_2", test_ns_valid_2);
    Test.add_func ("/validator/ns/invalid_ip", test_ns_invalid_ip);
    Test.add_func ("/validator/ns/invalid_double_dot", test_ns_invalid_double_dot);
    Test.add_func ("/validator/ns/invalid_empty", test_ns_invalid_empty);
    // MX
    Test.add_func ("/validator/mx/valid_with_priority_param", test_mx_valid_with_priority_param);
    Test.add_func ("/validator/mx/valid_inline_priority", test_mx_valid_inline_priority);
    Test.add_func ("/validator/mx/valid_null", test_mx_valid_null_mx);
    Test.add_func ("/validator/mx/valid_20", test_mx_valid_20);
    Test.add_func ("/validator/mx/invalid_priority_high", test_mx_invalid_priority_out_of_range_high);
    Test.add_func ("/validator/mx/invalid_priority_negative", test_mx_invalid_priority_negative);
    Test.add_func ("/validator/mx/invalid_priority_nan", test_mx_invalid_priority_non_numeric);
    Test.add_func ("/validator/mx/invalid_target_ip", test_mx_invalid_target_ip);
    Test.add_func ("/validator/mx/invalid_target_bad", test_mx_invalid_target_bad_host);
    Test.add_func ("/validator/mx/invalid_missing_target", test_mx_invalid_missing_target);
    Test.add_func ("/validator/mx/warn_target_is_cname_set", test_mx_warning_target_is_cname_set);
    // TXT
    Test.add_func ("/validator/txt/valid_empty_quoted", test_txt_valid_empty_quoted);
    Test.add_func ("/validator/txt/valid_hello", test_txt_valid_hello);
    Test.add_func ("/validator/txt/valid_multi_chunk", test_txt_valid_multi_chunk);
    Test.add_func ("/validator/txt/valid_255", test_txt_valid_255);
    Test.add_func ("/validator/txt/invalid_256", test_txt_invalid_256);
    Test.add_func ("/validator/txt/invalid_unbalanced", test_txt_invalid_unbalanced);
    Test.add_func ("/validator/txt/warn_unquoted_long", test_txt_warn_unquoted_long);
    // SOA
    Test.add_func ("/validator/soa/valid", test_soa_valid);
    Test.add_func ("/validator/soa/valid_rname_at", test_soa_valid_rname_with_at);
    Test.add_func ("/validator/soa/valid_trailing", test_soa_valid_trailing_dots);
    Test.add_func ("/validator/soa/invalid_missing", test_soa_invalid_missing_fields);
    Test.add_func ("/validator/soa/invalid_mname_ip", test_soa_invalid_mname_ip);
    Test.add_func ("/validator/soa/invalid_serial_neg", test_soa_invalid_serial_negative);
    Test.add_func ("/validator/soa/invalid_serial_overflow", test_soa_invalid_serial_overflow);
    Test.add_func ("/validator/soa/invalid_refresh_nan", test_soa_invalid_refresh_non_numeric);
    Test.add_func ("/validator/soa/warn_retry_gt_refresh", test_soa_warn_retry_greater_refresh);
    Test.add_func ("/validator/soa/warn_expire_small", test_soa_warn_expire_small);
    Test.add_func ("/validator/soa/warn_serial_future", test_soa_warn_serial_future);
    // set
    Test.add_func ("/validator/set/cname_coexistence", test_set_cname_coexistence);
    Test.add_func ("/validator/set/cname_duplicate", test_set_cname_duplicate);
    Test.add_func ("/validator/set/no_cname_distinct", test_set_no_cname_warning_distinct_owners);
    Test.add_func ("/validator/set/soa_duplicate", test_set_soa_duplicate);
    Test.add_func ("/validator/set/mx_target_cname", test_set_mx_target_is_cname);
    Test.add_func ("/validator/set/is_valid_warnings", test_is_valid_semantics_warnings_not_invalid);
    Test.add_func ("/validator/set/is_valid_errors", test_is_valid_semantics_errors_invalid);
    Test.add_func ("/validator/set/dispatch_via_record", test_validate_dispatch_via_record);
    return Test.run ();
}
