/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

using Digger;

void test_compute_vt_score_clean () {
    int score = ThreatIntelService.compute_vt_score (0, 0);
    assert (score == 100);
    var level = ThreatIntelService.compute_vt_level (0, 0);
    assert (level == ThreatLevel.SAFE);
}

void test_compute_vt_score_one_malicious () {
    int score = ThreatIntelService.compute_vt_score (1, 0);
    assert (score == 75);
    var level = ThreatIntelService.compute_vt_level (1, 0);
    assert (level == ThreatLevel.SUSPICIOUS);
}

void test_compute_vt_score_three_malicious () {
    int score = ThreatIntelService.compute_vt_score (3, 0);
    assert (score == 25);
    var level = ThreatIntelService.compute_vt_level (3, 0);
    assert (level == ThreatLevel.MALICIOUS);
}

void test_compute_vt_score_clamped () {
    int score = ThreatIntelService.compute_vt_score (10, 0);
    assert (score == 0);
    var level = ThreatIntelService.compute_vt_level (10, 0);
    assert (level == ThreatLevel.MALICIOUS);
}

void test_compute_vt_score_suspicious_only () {
    int score = ThreatIntelService.compute_vt_score (0, 2);
    assert (score == 80);
    var level = ThreatIntelService.compute_vt_level (0, 2);
    assert (level == ThreatLevel.SUSPICIOUS);
}

void test_compute_vt_score_one_suspicious () {
    int score = ThreatIntelService.compute_vt_score (0, 1);
    assert (score == 90);
    var level = ThreatIntelService.compute_vt_level (0, 1);
    assert (level == ThreatLevel.SAFE);
}

void test_interpret_dbl_null () {
    var r = ThreatIntelService.interpret_dbl_code (null);
    assert (r.level == ThreatLevel.SAFE);
    assert (r.score == 100);
}

void test_interpret_dbl_malware () {
    var r = ThreatIntelService.interpret_dbl_code ("127.0.1.5");
    assert (r.level == ThreatLevel.MALICIOUS);
    assert (r.score == 0);
    assert (r.category == "malware");
}

void test_interpret_dbl_phish () {
    var r = ThreatIntelService.interpret_dbl_code ("127.0.1.4");
    assert (r.level == ThreatLevel.MALICIOUS);
    assert (r.score == 0);
}

void test_interpret_dbl_botnet () {
    var r = ThreatIntelService.interpret_dbl_code ("127.0.1.6");
    assert (r.level == ThreatLevel.MALICIOUS);
    assert (r.score == 0);
}

void test_interpret_dbl_spam () {
    var r = ThreatIntelService.interpret_dbl_code ("127.0.1.2");
    assert (r.level == ThreatLevel.SUSPICIOUS);
    assert (r.score == 40);
    assert (r.category == "spam");
}

void test_interpret_dbl_abused () {
    var r = ThreatIntelService.interpret_dbl_code ("127.0.1.102");
    assert (r.level == ThreatLevel.SUSPICIOUS);
    assert (r.score == 40);
}

void test_interpret_dbl_block () {
    var r = ThreatIntelService.interpret_dbl_code ("127.255.255.254");
    assert (r.level == ThreatLevel.ERROR);
    assert (r.error != null);
    assert (r.error.contains ("public resolvers"));
}

void test_interpret_dbl_block_other () {
    var r = ThreatIntelService.interpret_dbl_code ("127.255.255.1");
    assert (r.level == ThreatLevel.ERROR);
}

void test_interpret_dbl_unknown () {
    var r = ThreatIntelService.interpret_dbl_code ("127.0.1.99");
    assert (r.level == ThreatLevel.ERROR);
}

void test_aggregate_worst_of () {
    var r = ThreatIntelService.aggregate_scores (true, ThreatLevel.MALICIOUS, 0, true, ThreatLevel.SAFE, 100);
    assert (r.level == ThreatLevel.MALICIOUS);
    assert (r.score == 0);
}

void test_aggregate_min_score () {
    var r = ThreatIntelService.aggregate_scores (true, ThreatLevel.SAFE, 80, true, ThreatLevel.SUSPICIOUS, 40);
    assert (r.level == ThreatLevel.SUSPICIOUS);
    assert (r.score == 40);
}

void test_aggregate_no_data () {
    var r = ThreatIntelService.aggregate_scores (false, ThreatLevel.UNKNOWN, -1, false, ThreatLevel.UNKNOWN, -1);
    assert (r.level == ThreatLevel.UNKNOWN);
    assert (r.score == -1);
}

void test_aggregate_vt_only () {
    var r = ThreatIntelService.aggregate_scores (true, ThreatLevel.SAFE, 100, false, ThreatLevel.UNKNOWN, -1);
    assert (r.level == ThreatLevel.SAFE);
    assert (r.score == 100);
}

void test_aggregate_dbl_only () {
    var r = ThreatIntelService.aggregate_scores (false, ThreatLevel.UNKNOWN, -1, true, ThreatLevel.MALICIOUS, 0);
    assert (r.level == ThreatLevel.MALICIOUS);
    assert (r.score == 0);
}

void test_verdict_label () {
    var d = new ThreatIntelData ();
    d.level = ThreatLevel.MALICIOUS; assert (d.get_verdict_label () == "Malicious");
    d.level = ThreatLevel.SUSPICIOUS; assert (d.get_verdict_label () == "Suspicious");
    d.level = ThreatLevel.SAFE; assert (d.get_verdict_label () == "Clean");
    d.level = ThreatLevel.UNKNOWN; assert (d.get_verdict_label () == "Unknown");
    d.level = ThreatLevel.RATE_LIMITED; assert (d.get_verdict_label () == "Rate limited");
    d.level = ThreatLevel.ERROR; assert (d.get_verdict_label () == "Error");
}

void test_verdict_css_class () {
    var d = new ThreatIntelData ();
    d.level = ThreatLevel.MALICIOUS; assert (d.get_verdict_css_class () == "error");
    d.level = ThreatLevel.SUSPICIOUS; assert (d.get_verdict_css_class () == "warning");
    d.level = ThreatLevel.SAFE; assert (d.get_verdict_css_class () == "success");
    d.level = ThreatLevel.UNKNOWN; assert (d.get_verdict_css_class () == "");
    d.level = ThreatLevel.RATE_LIMITED; assert (d.get_verdict_css_class () == "warning");
    d.level = ThreatLevel.ERROR; assert (d.get_verdict_css_class () == "error");
}

void test_threat_data_defaults () {
    var d = new ThreatIntelData ();
    assert (d.level == ThreatLevel.UNKNOWN);
    assert (d.safety_score == -1);
    assert (d.from_cache == false);
    assert (d.dbl_listed == false);
    assert (d.vt_categories != null);
    assert (d.vt_detections != null);
    assert (d.vt_categories.size == 0);
    assert (d.vt_detections.size == 0);
}

// Parsing tests

void test_parse_clean_fixture () {
    string json = """{"data":{"attributes":{"last_analysis_stats":{"harmless":70,"malicious":0,"suspicious":0,"undetected":10,"timeout":0},"reputation":5,"total_votes":{"harmless":10,"malicious":0},"categories":{"alpha":"search engine","beta":"search engine"},"first_submission_date":1609459200,"last_submission_date":1700000000,"last_analysis_date":1700003600,"last_analysis_results":{"EngineA":{"category":"harmless","result":"clean"},"EngineB":{"category":"undetected","result":"unrated"}}}}}""";
    var data = new ThreatIntelData ();
    bool ok = ThreatIntelService.parse_virustotal_response (json, data);
    assert (ok == true);
    assert (data.vt_malicious == 0);
    assert (data.vt_harmless == 70);
    assert (data.level == ThreatLevel.SAFE);
    assert (data.safety_score == 100);
    assert (data.vt_reputation == 5);
    assert (data.vt_votes_harmless == 10);
    assert (data.vt_first_seen != null);
    assert (data.vt_last_seen != null);
    assert (data.vt_last_analyzed != null);
    // categories deduped: both alpha and beta map to "search engine" -> 1 entry
    assert (data.vt_categories.size == 1);
    // no malicious/suspicious engines -> no detections
    assert (data.vt_detections.size == 0);
}

void test_parse_malicious_fixture () {
    string json = """{"data":{"attributes":{"last_analysis_stats":{"harmless":60,"malicious":5,"suspicious":1,"undetected":5,"timeout":0},"reputation":-12,"total_votes":{"harmless":2,"malicious":8},"categories":{"cat1":"malware"},"first_submission_date":1609459200,"last_submission_date":1700000000,"last_analysis_date":1700003600,"last_analysis_results":{"EngineX":{"category":"malicious","result":"phishing"},"EngineY":{"category":"harmless","result":"clean"},"EngineZ":{"category":"suspicious","result":"suspicious site"}}}}}""";
    var data = new ThreatIntelData ();
    bool ok = ThreatIntelService.parse_virustotal_response (json, data);
    assert (ok == true);
    assert (data.vt_malicious == 5);
    assert (data.vt_suspicious == 1);
    assert (data.level == ThreatLevel.MALICIOUS);
    // score = 100 - 5*25 - 1*10 = -35 -> clamped 0
    assert (data.safety_score == 0);
    assert (data.vt_reputation == -12);
    assert (data.vt_votes_malicious == 8);
    // detections: EngineX and EngineZ
    assert (data.vt_detections.size == 2);
    bool found_phishing = false;
    foreach (string det in data.vt_detections) {
        if (det.contains ("phishing")) found_phishing = true;
    }
    assert (found_phishing == true);
}

void test_parse_missing_fields () {
    string json = """{"data":{"attributes":{"last_analysis_stats":{"harmless":1,"malicious":0,"suspicious":0,"undetected":0,"timeout":0}}}}""";
    var data = new ThreatIntelData ();
    bool ok = ThreatIntelService.parse_virustotal_response (json, data);
    assert (ok == true);
    assert (data.vt_malicious == 0);
    assert (data.level == ThreatLevel.SAFE);
    assert (data.vt_reputation == null);
    assert (data.vt_first_seen == null);
}

void test_parse_malformed_json () {
    string json = """{ not valid json """;
    var data = new ThreatIntelData ();
    bool ok = ThreatIntelService.parse_virustotal_response (json, data);
    assert (ok == false);
}

void test_parse_empty_json () {
    string json = """{}""";
    var data = new ThreatIntelData ();
    bool ok = ThreatIntelService.parse_virustotal_response (json, data);
    assert (ok == false);
}

// Cache tests

void test_cache_put_get () {
    var cache = new ThreatIntelCache (null, 3600, 100);
    var d = new ThreatIntelData ();
    d.target = "example.com";
    d.level = ThreatLevel.SAFE;
    d.safety_score = 100;
    cache.put ("example.com", d);
    var got = cache.get ("example.com");
    assert (got != null);
    assert (got.level == ThreatLevel.SAFE);
    // case-insensitive key
    var got2 = cache.get ("EXAMPLE.COM");
    assert (got2 != null);
}

void test_cache_from_cache_flag () {
    // This tests the service level from_cache, but cache itself doesn't set it
    var cache = new ThreatIntelCache (null, 3600, 100);
    var d = new ThreatIntelData ();
    d.target = "example.com";
    cache.put ("example.com", d);
    var got = cache.get ("example.com");
    assert (got != null);
    assert (got.target == "example.com");
}

void test_cache_ttl_expiry () {
    var cache = new ThreatIntelCache (null, 0, 100);
    var d = new ThreatIntelData ();
    d.target = "example.com";
    cache.put ("example.com", d);
    // TTL 0 means immediately expired
    // Need a tiny delay to ensure now > expires_at
    Thread.usleep (10000);
    var got = cache.get ("example.com");
    assert (got == null);
}

void test_cache_lru_eviction () {
    var cache = new ThreatIntelCache (null, 3600, 2);
    var d1 = new ThreatIntelData (); d1.target = "a.com";
    var d2 = new ThreatIntelData (); d2.target = "b.com";
    var d3 = new ThreatIntelData (); d3.target = "c.com";
    cache.put ("a.com", d1);
    cache.put ("b.com", d2);
    cache.put ("c.com", d3);
    assert (cache.get ("a.com") == null);
    assert (cache.get ("b.com") != null);
    assert (cache.get ("c.com") != null);
}

void test_rate_limit_cooldown () {
    var svc = new ThreatIntelService (null, 3600, 100);
    assert (svc.is_rate_limited () == false);
    svc.cooldown_until = new DateTime.now_local ().add_seconds (60);
    assert (svc.is_rate_limited () == true);
    svc.cooldown_until = new DateTime.now_local ().add_seconds (-60);
    assert (svc.is_rate_limited () == false);
    svc.cooldown_until = null;
    assert (svc.is_rate_limited () == false);
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/threat/compute_vt_score/clean", test_compute_vt_score_clean);
    Test.add_func ("/threat/compute_vt_score/one_malicious", test_compute_vt_score_one_malicious);
    Test.add_func ("/threat/compute_vt_score/three_malicious", test_compute_vt_score_three_malicious);
    Test.add_func ("/threat/compute_vt_score/clamped", test_compute_vt_score_clamped);
    Test.add_func ("/threat/compute_vt_score/suspicious_only", test_compute_vt_score_suspicious_only);
    Test.add_func ("/threat/compute_vt_score/one_suspicious", test_compute_vt_score_one_suspicious);
    Test.add_func ("/threat/interpret_dbl/null", test_interpret_dbl_null);
    Test.add_func ("/threat/interpret_dbl/malware", test_interpret_dbl_malware);
    Test.add_func ("/threat/interpret_dbl/phish", test_interpret_dbl_phish);
    Test.add_func ("/threat/interpret_dbl/botnet", test_interpret_dbl_botnet);
    Test.add_func ("/threat/interpret_dbl/spam", test_interpret_dbl_spam);
    Test.add_func ("/threat/interpret_dbl/abused", test_interpret_dbl_abused);
    Test.add_func ("/threat/interpret_dbl/block", test_interpret_dbl_block);
    Test.add_func ("/threat/interpret_dbl/block_other", test_interpret_dbl_block_other);
    Test.add_func ("/threat/interpret_dbl/unknown", test_interpret_dbl_unknown);
    Test.add_func ("/threat/aggregate/worst_of", test_aggregate_worst_of);
    Test.add_func ("/threat/aggregate/min_score", test_aggregate_min_score);
    Test.add_func ("/threat/aggregate/no_data", test_aggregate_no_data);
    Test.add_func ("/threat/aggregate/vt_only", test_aggregate_vt_only);
    Test.add_func ("/threat/aggregate/dbl_only", test_aggregate_dbl_only);
    Test.add_func ("/threat/display/verdict_label", test_verdict_label);
    Test.add_func ("/threat/display/verdict_css_class", test_verdict_css_class);
    Test.add_func ("/threat/display/defaults", test_threat_data_defaults);
    Test.add_func ("/threat/parse/clean_fixture", test_parse_clean_fixture);
    Test.add_func ("/threat/parse/malicious_fixture", test_parse_malicious_fixture);
    Test.add_func ("/threat/parse/missing_fields", test_parse_missing_fields);
    Test.add_func ("/threat/parse/malformed_json", test_parse_malformed_json);
    Test.add_func ("/threat/parse/empty_json", test_parse_empty_json);
    Test.add_func ("/threat/cache/put_get", test_cache_put_get);
    Test.add_func ("/threat/cache/from_cache_flag", test_cache_from_cache_flag);
    Test.add_func ("/threat/cache/ttl_expiry", test_cache_ttl_expiry);
    Test.add_func ("/threat/cache/lru_eviction", test_cache_lru_eviction);
    Test.add_func ("/threat/rate_limit/cooldown", test_rate_limit_cooldown);

    return Test.run ();
}
