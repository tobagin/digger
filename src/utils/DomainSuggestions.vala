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
    /**
     * Represents a domain suggestion with metadata
     */
    public class DomainSuggestion : Object {
        public string domain { get; set; }
        public string description { get; set; }
        public int frequency { get; set; }
        public SuggestionType suggestion_type { get; set; }
        public DateTime? last_used { get; set; }
        
        public DomainSuggestion (string domain, SuggestionType suggestion_type, string description = "") {
            this.domain = domain;
            this.suggestion_type = suggestion_type;
            this.description = description;
            this.frequency = 1;
            this.last_used = new DateTime.now_local ();
        }
        
        public string get_display_text () {
            switch (suggestion_type) {
                case SuggestionType.HISTORY:
                    return @"$domain (from history)";
                case SuggestionType.COMMON_TLD:
                    return @"$domain (common TLD)";
                case SuggestionType.TYPO_CORRECTION:
                    return @"$domain (did you mean?)";
                case SuggestionType.POPULAR:
                    return @"$domain (popular)";
                default:
                    return domain;
            }
        }
        
        public string get_icon () {
            switch (suggestion_type) {
                case SuggestionType.HISTORY:
                    return "document-open-recent-symbolic";
                case SuggestionType.COMMON_TLD:
                    return "network-workgroup-symbolic";
                case SuggestionType.TYPO_CORRECTION:
                    return "edit-find-replace-symbolic";
                case SuggestionType.POPULAR:
                    return "starred-symbolic";
                default:
                    return "network-server-symbolic";
            }
        }
    }
    
    /**
     * Types of domain suggestions
     */
    public enum SuggestionType {
        HISTORY,      // From query history
        COMMON_TLD,   // Common TLD suggestions
        TYPO_CORRECTION,  // Suggested typo corrections
        POPULAR       // Popular domains
    }
    
    /**
     * Domain suggestion engine for autocomplete functionality
     */
    public class DomainSuggestionEngine : Object {
        private static DomainSuggestionEngine? instance = null;
        private Gee.HashMap<string, DomainSuggestion> domain_cache;
        private Gee.ArrayList<string> common_tlds;
        private Gee.ArrayList<string> popular_domains;
        private QueryHistory? query_history;
        
        // Configuration
        private int max_suggestions = 10;
        private int min_input_length = 2;
        private bool enable_typo_correction = true;
        
        private DomainSuggestionEngine () {
            domain_cache = new Gee.HashMap<string, DomainSuggestion> ();
            common_tlds = new Gee.ArrayList<string> ();
            popular_domains = new Gee.ArrayList<string> ();
            
            initialize_default_data ();
        }
        
        public static DomainSuggestionEngine get_instance () {
            if (instance == null) {
                instance = new DomainSuggestionEngine ();
            }
            return instance;
        }
        
        public void set_query_history (QueryHistory history) {
            query_history = history;
            update_cache_from_history ();
        }
        
        /**
         * Get domain suggestions based on input text
         */
        public Gee.List<DomainSuggestion> get_suggestions (string input) {
            var suggestions = new Gee.ArrayList<DomainSuggestion> ();
            
            if (input.length < min_input_length) {
                return suggestions;
            }
            
            string lower_input = input.down ().strip ();
            
            // 1. History-based suggestions
            add_history_suggestions (suggestions, lower_input);
            
            // 2. Common TLD suggestions
            add_tld_suggestions (suggestions, lower_input);
            
            // 3. Popular domain suggestions
            add_popular_suggestions (suggestions, lower_input);
            
            // 4. Typo correction suggestions
            if (enable_typo_correction) {
                add_typo_corrections (suggestions, lower_input);
            }
            
            // Sort by relevance and frequency
            suggestions.sort ((a, b) => {
                // Exact matches first
                bool a_exact = a.domain.down ().has_prefix (lower_input);
                bool b_exact = b.domain.down ().has_prefix (lower_input);
                
                if (a_exact && !b_exact) return -1;
                if (!a_exact && b_exact) return 1;
                
                // Then by frequency
                if (a.frequency != b.frequency) {
                    return b.frequency - a.frequency;
                }
                
                // Finally by recency
                if (a.last_used != null && b.last_used != null) {
                    return b.last_used.compare (a.last_used);
                }
                
                return 0;
            });
            
            // Limit results
            while (suggestions.size > max_suggestions) {
                suggestions.remove_at (suggestions.size - 1);
            }
            
            return suggestions;
        }
        
        /**
         * Record a domain usage to improve suggestions
         */
        public void record_domain_usage (string domain) {
            string normalized = normalize_domain (domain);
            
            if (domain_cache.has_key (normalized)) {
                var suggestion = domain_cache[normalized];
                suggestion.frequency++;
                suggestion.last_used = new DateTime.now_local ();
            } else {
                var suggestion = new DomainSuggestion (normalized, SuggestionType.HISTORY);
                domain_cache[normalized] = suggestion;
            }
        }
        
        /**
         * Check if a domain is valid
         */
        public bool is_valid_domain (string domain) {
            if (domain.length == 0 || domain.length > 253) {
                return false;
            }
            
            // Check for basic IP addresses
            if (is_ip_address (domain)) {
                return true;
            }
            
            // Basic domain validation
            try {
                var regex = new Regex ("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$");
                return regex.match (domain);
            } catch (RegexError e) {
                return false;
            }
        }
        
        /**
         * Get suggested corrections for potential typos
         */
        public Gee.List<string> get_typo_suggestions (string domain) {
            var suggestions = new Gee.ArrayList<string> ();
            
            // Check against common domains with edit distance
            foreach (var cached_domain in domain_cache.keys) {
                if (edit_distance (domain, cached_domain) <= 2) {
                    suggestions.add (cached_domain);
                }
            }
            
            return suggestions;
        }
        
        private void initialize_default_data () {
            // Common TLDs
            string[] tlds = {
                "com", "org", "net", "edu", "gov", "mil", "int",
                "co.uk", "org.uk", "ac.uk", "gov.uk",
                "de", "fr", "it", "es", "ru", "cn", "jp", "br", "in",
                "io", "ai", "dev", "app", "tech", "online", "site"
            };
            
            foreach (string tld in tlds) {
                common_tlds.add (tld);
            }
            
            // Popular domains for testing/examples
            string[] popular = {
                "google.com", "github.com", "stackoverflow.com",
                "wikipedia.org", "mozilla.org", "kernel.org",
                "example.com", "localhost", "127.0.0.1", "::1"
            };
            
            foreach (string domain in popular) {
                popular_domains.add (domain);
                var suggestion = new DomainSuggestion (domain, SuggestionType.POPULAR);
                domain_cache[domain] = suggestion;
            }
        }
        
        private void update_cache_from_history () {
            if (query_history == null) return;
            
            var history = query_history.get_history ();
            foreach (var result in history) {
                record_domain_usage (result.domain);
            }
        }
        
        private void add_history_suggestions (Gee.ArrayList<DomainSuggestion> suggestions, string input) {
            foreach (var cached_domain in domain_cache.keys) {
                var suggestion = domain_cache[cached_domain];
                if (suggestion.suggestion_type == SuggestionType.HISTORY &&
                    cached_domain.down ().contains (input)) {
                    suggestions.add (suggestion);
                }
            }
        }
        
        private void add_tld_suggestions (Gee.ArrayList<DomainSuggestion> suggestions, string input) {
            // If input doesn't contain a dot, suggest adding common TLDs
            if (!input.contains (".")) {
                foreach (string tld in common_tlds) {
                    string suggested_domain = @"$input.$tld";
                    if (is_valid_domain (suggested_domain)) {
                        var suggestion = new DomainSuggestion (suggested_domain, SuggestionType.COMMON_TLD);
                        suggestions.add (suggestion);
                    }
                }
            }
        }
        
        private void add_popular_suggestions (Gee.ArrayList<DomainSuggestion> suggestions, string input) {
            foreach (string domain in popular_domains) {
                if (domain.down ().contains (input)) {
                    var suggestion = domain_cache[domain];
                    if (suggestion != null) {
                        suggestions.add (suggestion);
                    }
                }
            }
        }
        
        private void add_typo_corrections (Gee.ArrayList<DomainSuggestion> suggestions, string input) {
            var corrections = get_typo_suggestions (input);
            foreach (string correction in corrections) {
                var suggestion = new DomainSuggestion (correction, SuggestionType.TYPO_CORRECTION);
                suggestions.add (suggestion);
            }
        }
        
        private string normalize_domain (string domain) {
            return domain.down ().strip ();
        }
        
        private bool is_ip_address (string input) {
            // Simple check for IPv4
            if (Regex.match_simple ("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", input)) {
                return true;
            }
            
            // Simple check for IPv6 (contains colons)
            if (input.contains (":")) {
                return true;
            }
            
            return false;
        }
        
        private int edit_distance (string a, string b) {
            int len_a = a.length;
            int len_b = b.length;
            
            if (len_a == 0) return len_b;
            if (len_b == 0) return len_a;
            
            int[,] matrix = new int[len_a + 1, len_b + 1];
            
            for (int i = 0; i <= len_a; i++) {
                matrix[i, 0] = i;
            }
            
            for (int j = 0; j <= len_b; j++) {
                matrix[0, j] = j;
            }
            
            for (int i = 1; i <= len_a; i++) {
                for (int j = 1; j <= len_b; j++) {
                    int cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
                    
                    matrix[i, j] = int.min (
                        int.min (
                            matrix[i - 1, j] + 1,      // deletion
                            matrix[i, j - 1] + 1       // insertion
                        ),
                        matrix[i - 1, j - 1] + cost     // substitution
                    );
                }
            }
            
            return matrix[len_a, len_b];
        }
    }
}
