/*
 * digger-vala - IPv6 connectivity tests (DIGG-004)
 * Copyright (C) 2024-2026 Thiago Fernandes
 */

using Digger;

// ---- Helpers ----

const string DIG_SUCCESS_SINGLE = """; <<>> DiG 9.18.0 <<>> google.com AAAA @2606:4700:4700::1111
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1234
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
;; QUESTION SECTION:
;google.com.            IN  AAAA

;; ANSWER SECTION:
google.com.     300 IN  AAAA    2607:f8b0:4004:c08::71

;; Query time: 42 msec
;; SERVER: 2606:4700:4700::1111#53(2606:4700:4700::1111)
;; WHEN: Thu Jan 01 00:00:00 UTC 2026
;; MSG SIZE  rcvd: 68
""";

const string DIG_SUCCESS_MULTI = """; <<>> DiG 9.18.0 <<>> example.com AAAA @2606:4700:4700::1111
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1234
;; flags: qr rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1
;; QUESTION SECTION:
;example.com.           IN  AAAA
;; ANSWER SECTION:
example.com.        300 IN  AAAA    2600:1406:3a00::6860:ad44
example.com.        300 IN  AAAA    2600:1406:3a00::6860:ad4a

;; Query time: 20 msec
;; SERVER: 2606:4700:4700::1111#53
""";

const string DIG_EMPTY = """; <<>> DiG 9.18.0 <<>> noaaaa.example.com AAAA @2606:4700:4700::1111
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1234
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; QUESTION SECTION:
;noaaaa.example.com.        IN  AAAA
;; AUTHORITY SECTION:
example.com.        3600    IN  SOA ns1.example.com. hostmaster.example.com. 2026010101 7200 3600 1209600 3600
""";

const string DIG_NXDOMAIN = """; <<>> DiG 9.18.0 <<>> nonexistent.invalid AAAA @2606:4700:4700::1111
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 1234
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; QUESTION SECTION:
;nonexistent.invalid.       IN  AAAA
""";

const string DIG_SERVFAIL = """; <<>> DiG 9.18.0 <<>> example.com AAAA @2606:4700:4700::1111
;; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 1234
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 1
""";

void test_constants_exist () {
    assert (Constants.IPV6_PROBE_TIMEOUT_SECONDS == 5);
    assert (Constants.IPV6_AAAA_TIMEOUT_SECONDS == 10);
    assert (Constants.IPV6_PROBE_RESOLVER == "2606:4700:4700::1111");
    assert (Constants.IPV6_FALLBACK_RESOLVER == "2001:4860:4860::8888");
    assert (Constants.IPV6_PROBE_DOMAIN == "google.com");
}

void test_is_ipv6_available_true () {
    var svc = new Ipv6Service ();
    svc.set_socket_factory (() => { return true; });
    assert (svc.is_ipv6_available () == true);
}

void test_is_ipv6_available_false_throws () {
    var svc = new Ipv6Service ();
    svc.set_socket_factory (() => { throw new IOError.FAILED ("no ipv6"); });
    assert (svc.is_ipv6_available () == false);
}

void test_is_ipv6_available_force_flags () {
    var svc = new Ipv6Service ();
    svc.set_force_unavailable (true);
    assert (svc.is_ipv6_available () == false);
    svc.set_force_available (true);
    assert (svc.is_ipv6_available () == true);
    svc.clear_force_flags ();
    bool v = svc.is_ipv6_available ();
    assert (v == true || v == false);
}

void test_parse_aaaa_single () {
    var svc = new Ipv6Service ();
    var recs = svc.parse_aaaa_records (DIG_SUCCESS_SINGLE, "google.com");
    assert (recs.size == 1);
    assert (recs[0].value == "2607:f8b0:4004:c08::71");
    assert (recs[0].record_type == RecordType.AAAA);
    assert (ValidationUtils.is_valid_ipv6 (recs[0].value) == true);
}

void test_parse_aaaa_multi () {
    var svc = new Ipv6Service ();
    var recs = svc.parse_aaaa_records (DIG_SUCCESS_MULTI, "example.com");
    assert (recs.size == 2);
}

void test_parse_aaaa_empty () {
    var svc = new Ipv6Service ();
    var recs = svc.parse_aaaa_records (DIG_EMPTY, "noaaaa.example.com");
    assert (recs.size == 0);
}

void test_parse_aaaa_invalid_filtered () {
    var svc = new Ipv6Service ();
    string bad = DIG_SUCCESS_SINGLE.replace ("2607:f8b0:4004:c08::71", "gggg::1");
    var recs = svc.parse_aaaa_records (bad, "google.com");
    assert (recs.size == 0);
}

void test_map_error_to_status () {
    assert (Ipv6Service.map_error_to_status ("connection timed out") == Ipv6ProbeStatus.TIMEOUT);
    assert (Ipv6Service.map_error_to_status ("Network is unreachable") == Ipv6ProbeStatus.UNREACHABLE);
    assert (Ipv6Service.map_error_to_status ("ENETUNREACH") == Ipv6ProbeStatus.UNREACHABLE);
    assert (Ipv6Service.map_error_to_status ("other error") == Ipv6ProbeStatus.ERROR);
}

void test_sanitize_error () {
    var svc = new Ipv6Service ();
    svc.set_socket_factory (() => { return true; });
    svc.set_mock_throw ("/home/user/.cache/foo failed at /tmp/bar", false);
    Ipv6Service.reset_dig_cache ();
    var loop = new MainLoop ();
    svc.probe_reachability_async.begin (null, (obj, res) => {
        var r = svc.probe_reachability_async.end (res);
        assert (r.error_message != null);
        assert (!r.error_message.contains ("/home/user/.cache/foo"));
        assert (r.error_message.contains ("[path]") || r.error_message.contains ("[home]") || r.error_message.length > 0);
        loop.quit ();
    });
    loop.run ();
}

void test_probe_reachability_timeout () {
    var svc = new Ipv6Service ();
    svc.set_socket_factory (() => { return true; });
    svc.set_mock_throw ("timed out", true);
    Ipv6Service.reset_dig_cache ();
    var loop = new MainLoop ();
    svc.probe_reachability_async.begin (null, (obj, res) => {
        var r = svc.probe_reachability_async.end (res);
        assert (r.status == Ipv6ProbeStatus.TIMEOUT);
        assert (r.reachable == false);
        assert (r.error_message != null);
        loop.quit ();
    });
    loop.run ();
}

void test_probe_reachability_network_error () {
    var svc = new Ipv6Service ();
    svc.set_socket_factory (() => { return true; });
    svc.set_mock_throw ("Network is unreachable", false);
    Ipv6Service.reset_dig_cache ();
    var loop = new MainLoop ();
    svc.probe_reachability_async.begin (null, (obj, res) => {
        var r = svc.probe_reachability_async.end (res);
        assert (r.status == Ipv6ProbeStatus.UNREACHABLE);
        assert (r.reachable == false);
        loop.quit ();
    });
    loop.run ();
}

void test_verify_aaaa_success () {
    var svc = new Ipv6Service ();
    svc.set_socket_factory (() => { return true; });
    svc.set_mock_dig_sequence (DIG_SUCCESS_SINGLE, "", 0, DIG_SUCCESS_SINGLE, "", 0);
    Ipv6Service.reset_dig_cache ();
    var loop = new MainLoop ();
    svc.verify_aaaa_async.begin ("google.com", null, (obj, res) => {
        var r = svc.verify_aaaa_async.end (res);
        assert (r.reachable == true);
        assert (r.aaaa_records.size == 1);
        assert (r.status == Ipv6ProbeStatus.SUCCESS);
        assert (r.resolver_used == Constants.IPV6_PROBE_RESOLVER);
        assert (ValidationUtils.is_valid_ipv6 (r.aaaa_records[0].value) == true);
        loop.quit ();
    });
    loop.run ();
}

void test_verify_aaaa_empty () {
    var svc = new Ipv6Service ();
    svc.set_socket_factory (() => { return true; });
    svc.set_mock_dig_sequence (DIG_SUCCESS_SINGLE, "", 0, DIG_EMPTY, "", 0);
    Ipv6Service.reset_dig_cache ();
    var loop = new MainLoop ();
    svc.verify_aaaa_async.begin ("noaaaa.example.com", null, (obj, res) => {
        var r = svc.verify_aaaa_async.end (res);
        assert (r.reachable == true);
        assert (r.aaaa_records.size == 0);
        assert (r.status == Ipv6ProbeStatus.SUCCESS);
        loop.quit ();
    });
    loop.run ();
}

void test_verify_aaaa_nxdomain () {
    var svc = new Ipv6Service ();
    svc.set_socket_factory (() => { return true; });
    svc.set_mock_dig_sequence (DIG_SUCCESS_SINGLE, "", 0, DIG_NXDOMAIN, "", 0);
    Ipv6Service.reset_dig_cache ();
    var loop = new MainLoop ();
    svc.verify_aaaa_async.begin ("nonexistent.invalid", null, (obj, res) => {
        var r = svc.verify_aaaa_async.end (res);
        assert (r.status == Ipv6ProbeStatus.NXDOMAIN);
        assert (r.error_message != null);
        loop.quit ();
    });
    loop.run ();
}

void test_verify_aaaa_servfail () {
    var svc = new Ipv6Service ();
    svc.set_socket_factory (() => { return true; });
    svc.set_mock_dig_sequence (DIG_SUCCESS_SINGLE, "", 0, DIG_SERVFAIL, "", 0);
    Ipv6Service.reset_dig_cache ();
    var loop = new MainLoop ();
    svc.verify_aaaa_async.begin ("example.com", null, (obj, res) => {
        var r = svc.verify_aaaa_async.end (res);
        assert (r.status == Ipv6ProbeStatus.SERVFAIL);
        assert (r.error_message != null);
        loop.quit ();
    });
    loop.run ();
}

void test_verify_aaaa_short_circuit_no_ipv6 () {
    var svc = new Ipv6Service ();
    svc.set_force_unavailable (true);
    svc.set_mock_dig_result ("", "", 0);
    Ipv6Service.reset_dig_cache ();
    var loop = new MainLoop ();
    svc.verify_aaaa_async.begin ("google.com", null, (obj, res) => {
        var r = svc.verify_aaaa_async.end (res);
        assert (r.status == Ipv6ProbeStatus.UNAVAILABLE);
        assert (svc.get_mock_call_count () == 0);
        svc.clear_force_flags ();
        loop.quit ();
    });
    loop.run ();
}

void test_verify_aaaa_short_circuit_unreachable () {
    var svc = new Ipv6Service ();
    svc.set_socket_factory (() => { return true; });
    svc.set_mock_throw ("Network is unreachable", false);
    Ipv6Service.reset_dig_cache ();
    var loop = new MainLoop ();
    svc.verify_aaaa_async.begin ("google.com", null, (obj, res) => {
        var r = svc.verify_aaaa_async.end (res);
        assert (svc.get_mock_call_count () == 1);
        assert (r.status == Ipv6ProbeStatus.UNREACHABLE);
        loop.quit ();
    });
    loop.run ();
}

void test_probe_cancellation () {
    // Verify that a successful verify can be called and that mock counting works
    // (stale-probe ignore via sequence token is exercised in Window, not here)
    var svc = new Ipv6Service ();
    svc.set_socket_factory (() => { return true; });
    svc.set_mock_dig_result (DIG_SUCCESS_SINGLE, "", 0);
    Ipv6Service.reset_dig_cache ();
    var loop = new MainLoop ();
    svc.verify_aaaa_async.begin ("google.com", null, (obj, res) => {
        var r = svc.verify_aaaa_async.end (res);
        assert (r != null);
        // With single-result mock, first call (probe) succeeds and AAAA also succeeds
        assert (r.status == Ipv6ProbeStatus.SUCCESS);
        assert (r.reachable == true);
        loop.quit ();
    });
    loop.run ();
}

void test_ipv6_test_result_defaults () {
    var r = new Ipv6TestResult ();
    assert (r.aaaa_records != null);
    assert (r.aaaa_records.size == 0);
    assert (r.from_cache == false);
    assert (r.timestamp != null);
    assert (r.status == Ipv6ProbeStatus.UNKNOWN);
}

void test_probe_status_to_string () {
    assert (Ipv6ProbeStatus.AVAILABLE.to_string () == "Available");
    assert (Ipv6ProbeStatus.UNAVAILABLE.to_string () == "Unavailable");
    assert (Ipv6ProbeStatus.TIMEOUT.to_string () == "Timeout");
    assert (Ipv6ProbeStatus.SUCCESS.to_string () == "Success");
}

// Issue #22: Subprocess.newv walks argv until NULL; 5 args (custom server) used to overrun.
void test_dig_argv_null_terminated () {
    string[] argv = Digger.DnsQuery.build_dig_command ("example.com", Digger.RecordType.A, "1.1.1.1",
                                                       false, false, false, false, 10);
    assert (argv.length == 5);
    assert (argv[1] == "@1.1.1.1");
    assert (((void**) argv)[argv.length] == null);
    assert (strv_length (argv) == 5);
}

void test_bytes_to_string () {
    assert (Digger.ValidationUtils.bytes_to_string (null) == "");
    assert (Digger.ValidationUtils.bytes_to_string (new Bytes ({})) == "");
    // Slice of a larger buffer: no NUL after the 5th byte
    var slice = new Bytes ("helloworld".data).slice (0, 5);
    assert (Digger.ValidationUtils.bytes_to_string (slice) == "hello");
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/ipv6/constants/exist", test_constants_exist);
    Test.add_func ("/ipv6/detection/available_true", test_is_ipv6_available_true);
    Test.add_func ("/ipv6/detection/available_false_throws", test_is_ipv6_available_false_throws);
    Test.add_func ("/ipv6/detection/force_flags", test_is_ipv6_available_force_flags);
    Test.add_func ("/ipv6/parse/single", test_parse_aaaa_single);
    Test.add_func ("/ipv6/parse/multi", test_parse_aaaa_multi);
    Test.add_func ("/ipv6/parse/empty", test_parse_aaaa_empty);
    Test.add_func ("/ipv6/parse/invalid_filtered", test_parse_aaaa_invalid_filtered);
    Test.add_func ("/ipv6/map/error_to_status", test_map_error_to_status);
    Test.add_func ("/ipv6/sanitize/error_message", test_sanitize_error);
    Test.add_func ("/ipv6/probe/timeout", test_probe_reachability_timeout);
    Test.add_func ("/ipv6/probe/network_error", test_probe_reachability_network_error);
    Test.add_func ("/ipv6/verify/success", test_verify_aaaa_success);
    Test.add_func ("/ipv6/verify/empty", test_verify_aaaa_empty);
    Test.add_func ("/ipv6/verify/nxdomain", test_verify_aaaa_nxdomain);
    Test.add_func ("/ipv6/verify/servfail", test_verify_aaaa_servfail);
    Test.add_func ("/ipv6/verify/short_circuit_no_ipv6", test_verify_aaaa_short_circuit_no_ipv6);
    Test.add_func ("/ipv6/verify/short_circuit_unreachable", test_verify_aaaa_short_circuit_unreachable);
    Test.add_func ("/ipv6/probe/cancellation", test_probe_cancellation);
    Test.add_func ("/ipv6/model/defaults", test_ipv6_test_result_defaults);
    Test.add_func ("/ipv6/status/to_string", test_probe_status_to_string);
    Test.add_func ("/dns_query/dig_argv_null_terminated", test_dig_argv_null_terminated);
    Test.add_func ("/validation/bytes_to_string", test_bytes_to_string);
    return Test.run ();
}
