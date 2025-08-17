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
     * Enhanced history search widget with filtering and sorting options
     */
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/enhanced-history-search.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/enhanced-history-search.ui")]
#endif
    public class EnhancedHistorySearch : Gtk.Box {
        [GtkChild] private unowned Gtk.Label title_label;
        [GtkChild] private unowned Gtk.Box controls_box;
        [GtkChild] private unowned Gtk.SearchEntry search_entry;
        [GtkChild] private unowned Gtk.Box filter_sort_box;
        [GtkChild] private unowned Gtk.DropDown filter_dropdown;
        [GtkChild] private unowned Gtk.DropDown sort_dropdown;
        [GtkChild] private unowned Gtk.Label results_count_label;
        [GtkChild] private unowned Gtk.ScrolledWindow scrolled_window;
        [GtkChild] private unowned Gtk.ListBox results_listbox;
        [GtkChild] private unowned Gtk.Box actions_box;
        [GtkChild] private unowned Gtk.Button clear_button;
        
        private QueryHistory query_history;
        private Gee.ArrayList<QueryResult> current_results;
        
        public signal void result_selected (QueryResult result);
        public signal void history_cleared ();
        
        public EnhancedHistorySearch (QueryHistory history) {
            query_history = history;
            current_results = new Gee.ArrayList<QueryResult> ();
            
            connect_signals ();
            update_results ();
        }
        
        
        private void connect_signals () {
            search_entry.search_changed.connect (update_results);
            filter_dropdown.notify["selected"].connect (update_results);
            sort_dropdown.notify["selected"].connect (update_results);
            results_listbox.row_activated.connect (on_result_activated);
            clear_button.clicked.connect (on_clear_history);
            query_history.history_updated.connect (update_results);
        }
        
        private void update_results () {
            string search_text = search_entry.text.strip ();
            var filter_criteria = get_selected_filter_criteria ();
            
            // Get filtered results
            Gee.List<QueryResult> results;
            if (search_text.length > 0) {
                results = query_history.search_history_enhanced (search_text, filter_criteria);
            } else {
                results = query_history.get_history ();
            }
            
            // Convert to ArrayList for sorting
            current_results.clear ();
            current_results.add_all (results);
            
            // Sort results
            sort_results ();
            
            // Update UI
            populate_results_list ();
            update_results_count ();
        }
        
        private SearchCriteria get_selected_filter_criteria () {
            switch (filter_dropdown.selected) {
                case 1: return SearchCriteria.DOMAIN_ONLY;
                case 2: return SearchCriteria.RECORD_TYPE_ONLY;
                case 3: return SearchCriteria.DNS_SERVER_ONLY;
                default: return SearchCriteria.ALL;
            }
        }
        
        private void sort_results () {
            switch (sort_dropdown.selected) {
                case 0: // Most Recent
                    current_results.sort ((a, b) => {
                        return b.timestamp.compare (a.timestamp);
                    });
                    break;
                    
                case 1: // Oldest First
                    current_results.sort ((a, b) => {
                        return a.timestamp.compare (b.timestamp);
                    });
                    break;
                    
                case 2: // Domain A-Z
                    current_results.sort ((a, b) => {
                        return strcmp (a.domain, b.domain);
                    });
                    break;
                    
                case 3: // Domain Z-A
                    current_results.sort ((a, b) => {
                        return strcmp (b.domain, a.domain);
                    });
                    break;
                    
                case 4: // Most Frequent
                    current_results.sort ((a, b) => {
                        int freq_a = query_history.get_domain_frequency (a.domain);
                        int freq_b = query_history.get_domain_frequency (b.domain);
                        if (freq_a != freq_b) {
                            return freq_b - freq_a;
                        }
                        return b.timestamp.compare (a.timestamp);
                    });
                    break;
            }
        }
        
        private void populate_results_list () {
            // Clear existing results
            var child = results_listbox.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                results_listbox.remove (child);
                child = next;
            }
            
            // Add results or show empty state
            if (current_results.size == 0) {
                var placeholder_row = new Gtk.ListBoxRow () {
                    selectable = false
                };
                var placeholder_label = new Gtk.Label ("No queries found") {
                    margin_top = 24,
                    margin_bottom = 24
                };
                placeholder_label.add_css_class ("dim-label");
                placeholder_row.child = placeholder_label;
                results_listbox.append (placeholder_row);
            } else {
                foreach (var result in current_results) {
                    var row = create_result_row (result);
                    results_listbox.append (row);
                }
            }
        }
        
        private Gtk.ListBoxRow create_result_row (QueryResult result) {
            var row = new Gtk.ListBoxRow ();
            
            var main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 12,
                margin_end = 12
            };
            
            // Result status indicator
            var status_indicator = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                width_request = 4,
                height_request = 40,
                valign = Gtk.Align.CENTER
            };
            
            string status_class = "success";
            if (result.status != QueryStatus.SUCCESS) {
                status_class = "error";
            } else if (!result.has_results ()) {
                status_class = "warning";
            }
            status_indicator.add_css_class (status_class);
            main_box.append (status_indicator);
            
            // Main content
            var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3) {
                hexpand = true
            };
            
            // Title line: domain and record type
            var title_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            
            var domain_label = new Gtk.Label (result.domain) {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END,
                hexpand = true
            };
            domain_label.add_css_class ("heading");
            title_box.append (domain_label);
            
            var record_type_badge = new Gtk.Label (result.query_type.to_string ()) {
                width_request = 50,
                halign = Gtk.Align.CENTER
            };
            record_type_badge.add_css_class ("pill");
            record_type_badge.add_css_class ("accent");
            title_box.append (record_type_badge);
            
            content_box.append (title_box);
            
            // Subtitle line: timestamp, server, result summary
            var subtitle_parts = new Gee.ArrayList<string> ();
            subtitle_parts.add (result.timestamp.format ("%Y-%m-%d %H:%M:%S"));
            
            if (result.dns_server != "System default") {
                subtitle_parts.add (result.dns_server);
            }
            
            subtitle_parts.add (result.get_summary ());
            
            if (result.query_time_ms > 0) {
                subtitle_parts.add (@"$((int)result.query_time_ms)ms");
            }
            
            string[] subtitle_array = subtitle_parts.to_array ();
            var subtitle_label = new Gtk.Label (string.joinv (" • ", subtitle_array)) {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END
            };
            subtitle_label.add_css_class ("caption");
            subtitle_label.add_css_class ("dim-label");
            content_box.append (subtitle_label);
            
            main_box.append (content_box);
            
            // Frequency indicator
            int frequency = query_history.get_domain_frequency (result.domain);
            if (frequency > 1) {
                var freq_badge = new Gtk.Label (@"×$frequency") {
                    tooltip_text = @"Queried $frequency times"
                };
                freq_badge.add_css_class ("pill");
                freq_badge.add_css_class ("warning");
                main_box.append (freq_badge);
            }
            
            row.child = main_box;
            row.set_data ("query-result", result);
            return row;
        }
        
        private void update_results_count () {
            string count_text;
            if (current_results.size == 0) {
                count_text = "No results found";
            } else if (current_results.size == 1) {
                count_text = "1 result";
            } else {
                count_text = @"$(current_results.size) results";
            }
            
            string search_text = search_entry.text.strip ();
            if (search_text.length > 0) {
                count_text += @" for \"$search_text\"";
            }
            
            results_count_label.label = count_text;
        }
        
        private void on_result_activated (Gtk.ListBoxRow row) {
            var result = row.get_data<QueryResult> ("query-result");
            if (result != null) {
                result_selected (result);
            }
        }
        
        private void on_clear_history () {
            // Show confirmation dialog
            var dialog = new Adw.AlertDialog (
                "Clear History?",
                "This will permanently delete all query history. This action cannot be undone."
            );
            
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("clear", "Clear History");
            dialog.set_response_appearance ("clear", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response ("cancel");
            
            dialog.response.connect ((response) => {
                if (response == "clear") {
                    query_history.clear_history ();
                    history_cleared ();
                }
                dialog.destroy ();
            });
            
            dialog.present (get_root () as Gtk.Widget);
        }
        
        /**
         * Get the currently selected result
         */
        public QueryResult? get_selected_result () {
            var selected_row = results_listbox.get_selected_row ();
            if (selected_row != null) {
                return selected_row.get_data<QueryResult> ("query-result");
            }
            return null;
        }
        
        /**
         * Set focus to the search entry
         */
        public void focus_search () {
            search_entry.grab_focus ();
        }
        
        /**
         * Clear the search and show all results
         */
        public void clear_search () {
            search_entry.text = "";
            filter_dropdown.selected = 0;
            sort_dropdown.selected = 0;
        }
    }
}
