/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024-2026 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger {
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/window.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/window.ui")]
#endif
    public class Window : Adw.ApplicationWindow {
        [GtkChild] private unowned Adw.ToastOverlay toast_overlay;
        [GtkChild] private unowned EnhancedQueryForm query_form;
        [GtkChild] private unowned EnhancedResultView result_view;
        [GtkChild] private unowned Gtk.Button history_button;
        [GtkChild] private unowned Gtk.Popover history_popover;
        [GtkChild] private unowned Gtk.ListBox history_listbox;
        [GtkChild] private unowned Gtk.SearchEntry history_search_entry;
        [GtkChild] private unowned Gtk.Button clear_button;
        
        
        private DnsQuery dns_query;
        private WhoisService whois_service;
        private ThreatIntelService threat_service;
        private Ipv6Service ipv6_service;
        private int ipv6_request_seq = 0;
        private Cancellable? ipv6_cancellable = null;
        private QueryHistory query_history;
        private bool query_in_progress = false;

        // Mobile bottom sheet support
        private HistoryDialog? history_dialog = null;
        private bool is_mobile_width = false;

        public Window (Gtk.Application app, QueryHistory history) {
            Object (application: app);
            query_history = history;

            UiUtils.apply_color_scheme (new GLib.Settings (Config.APP_ID).get_string ("color-scheme"));

            setup_ui ();
            setup_actions ();
            connect_signals ();

            dns_query = new DnsQuery ();
            dns_query.query_failed.connect (on_query_failed);

            whois_service = new WhoisService ();
            whois_service.query_completed.connect (on_whois_completed);
            whois_service.query_failed.connect (on_whois_failed);

            threat_service = new ThreatIntelService ();
            threat_service.check_completed.connect (on_threat_completed);
            threat_service.check_failed.connect (on_threat_failed);

            ipv6_service = Ipv6Service.get_instance ();
            ipv6_service.probe_completed.connect (on_ipv6_completed);
            ipv6_service.probe_failed.connect (on_ipv6_failed);

            // Connect error signals from managers (SEC-009: Enhanced Error Handling)
            var favorites_manager = FavoritesManager.get_instance ();
            favorites_manager.error_occurred.connect ((error_message) => {
                warning ("FavoritesManager error: %s", error_message);
                show_error_toast (error_message);
            });
            var template_manager = TemplateManager.get_instance ();
            template_manager.error_occurred.connect ((error_message) => {
                warning ("TemplateManager error: %s", error_message);
                show_error_toast (error_message);
            });
        }

        /**
         * Check if window is at mobile width (<768px) and update flag
         */
        private void check_mobile_width () {
            int width = this.get_width ();
            is_mobile_width = (width > 0 && width < 768);
            debug ("Window width: %d, is_mobile: %s", width, is_mobile_width.to_string ());
        }

        /**
         * Show history - uses dialog on mobile, popover on desktop
         */
        private void show_history () {
            check_mobile_width (); // Update mobile state

            if (is_mobile_width) {
                // Show as dialog (bottom sheet) on mobile
                if (history_dialog == null) {
                    history_dialog = new HistoryDialog ();
                    setup_history_dialog ();
                }
                history_dialog.present (this);
            } else {
                // Show as popover on desktop
                history_popover.set_parent (history_button);
                history_popover.popup ();
            }
        }

        /**
         * Setup history dialog with functionality (mobile version)
         */
        private void setup_history_dialog () {
            if (history_dialog == null) return;

            // Wire up search - share the query history search functionality
            history_dialog.history_search_entry.search_changed.connect (() => {
                // Populate dialog's listbox based on search
                populate_history_listbox (history_dialog.history_listbox, history_dialog.history_search_entry.text);
            });

            // Wire up list selection
            history_dialog.history_listbox.row_activated.connect ((row) => {
                // Same logic as popover selection - find and apply history item
                var index = row.get_index ();
                apply_history_item_at_index (index, history_dialog.history_listbox);
                history_dialog.close ();
            });

            // Wire up clear button
            history_dialog.clear_button.clicked.connect (() => {
                clear_history ();
                history_dialog.close ();
            });

            // Initial population
            populate_history_listbox (history_dialog.history_listbox, "");
        }

        /**
         * Populate a history listbox (shared between dialog and popover)
         */
        private void populate_history_listbox (Gtk.ListBox listbox, string search_text) {
            UiUtils.clear_children (listbox);

            // Get filtered history
            var history_items = query_history.get_history ();
            foreach (var item in history_items) {
                string record_type_str = item.query_type.to_string ();
                if (search_text != "" && !item.domain.down ().contains (search_text.down ()) &&
                    !record_type_str.down ().contains (search_text.down ())) {
                    continue;
                }

                var row = create_history_row (item);
                listbox.append (row);
            }
        }

        /**
         * Apply history item at given index from listbox
         */
        private void apply_history_item_at_index (int index, Gtk.ListBox listbox) {
            var row = listbox.get_row_at_index (index);
            if (row != null) {
                // Extract history data and apply to query form
                var history_items = query_history.get_history ();
                if (index >= 0 && index < history_items.size) {
                    var item = history_items[index];
                    query_form.set_domain (item.domain);
                    query_form.set_record_type (item.query_type);
                    query_form.set_dns_server (item.dns_server);
                }
            }
        }

        /**
         * Clear all history
         */
        private void clear_history () {
            query_history.clear_history ();
            update_history_list ();
            if (history_dialog != null) {
                populate_history_listbox (history_dialog.history_listbox, "");
            }
        }

        private void setup_ui () {
            // Connect query history to enhanced form for autocomplete
            query_form.set_query_history (query_history);

            // Use custom symbolic icon with proper naming for theme support
            history_button.icon_name = Config.APP_ID + "-history-symbolic";

            // Connect button click to show popover or dialog based on width
            history_button.clicked.connect (show_history);

            // Monitor window width changes for mobile detection
            this.notify["default-width"].connect (check_mobile_width);
            check_mobile_width ();

            // Fix popover focus issues
            history_popover.autohide = true;
            history_popover.can_focus = false;

            // Ensure result view shows welcome message initially
            result_view.clear_results ();
        }

        private void setup_actions () {
            var action_group = new SimpleActionGroup ();

            var new_query_action = new SimpleAction ("new-query", null);
            new_query_action.activate.connect (focus_domain_entry);
            action_group.add_action (new_query_action);

            var repeat_query_action = new SimpleAction ("repeat-query", null);
            repeat_query_action.activate.connect (repeat_last_query);
            action_group.add_action (repeat_query_action);

            var clear_results_action = new SimpleAction ("clear-results", null);
            clear_results_action.activate.connect (clear_results);
            action_group.add_action (clear_results_action);

            var batch_lookup_action = new SimpleAction ("batch-lookup", null);
            batch_lookup_action.activate.connect (show_batch_lookup_dialog);
            action_group.add_action (batch_lookup_action);

            var compare_servers_action = new SimpleAction ("compare-servers", null);
            compare_servers_action.activate.connect (show_comparison_dialog);
            action_group.add_action (compare_servers_action);

            var templates_action = new SimpleAction ("templates", null);
            templates_action.activate.connect (show_template_library);
            action_group.add_action (templates_action);

            var save_template_action = new SimpleAction ("save-template", null);
            save_template_action.activate.connect (show_save_template);
            action_group.add_action (save_template_action);

            insert_action_group ("win", action_group);
        }

        private void connect_signals () {
            query_form.query_requested.connect (on_query_requested);
            
            history_search_entry.search_changed.connect (update_history_list);
            history_listbox.row_activated.connect (on_history_item_selected);
            clear_button.clicked.connect (on_clear_history);
            
            query_history.history_updated.connect (update_history_list);

            // Update history list initially
            update_history_list ();
        }

        private void on_clear_history () {
            query_history.clear_history ();
            history_popover.popdown ();
        }

        private void focus_domain_entry () {
            query_form.focus_domain_entry ();
        }

        private void repeat_last_query () {
            var last_query = query_history.get_last_query ();
            if (last_query != null) {
                apply_query_settings (last_query);
                // Trigger query through the form's signal
                query_form.trigger_query ();
            }
        }

        private void clear_results () {
            result_view.clear_results ();
            query_form.clear_form ();
            query_form.set_reverse_lookup (false);
            query_form.set_trace_path (false);
            query_form.set_short_output (false);
            query_form.set_request_dnssec (false);
            query_form.focus_domain_entry ();
        }

        private void on_query_requested (string domain, RecordType record_type, string? dns_server, bool request_dnssec) {
            if (!query_in_progress) {
                perform_query_with_params.begin (domain, record_type, dns_server, request_dnssec);
            }
        }

        private async void perform_query_with_params (string domain, RecordType record_type, string? dns_server, bool request_dnssec) {
            if (domain.length == 0) {
                show_toast ("Please enter a domain name or IP address");
                return;
            }

            query_in_progress = true;
            
            // Use the provided DNS server
            string? server = dns_server;
            if (server != null && server.length == 0) {
                server = null;
            }
            
            result_view.show_query_started (domain, record_type, server);
            result_view.show_detailed_ttl = query_form.get_show_detailed_ttl ();

            var result = yield dns_query.perform_query (
                domain,
                record_type,
                server,
                query_form.get_reverse_lookup (),
                query_form.get_trace_path (),
                query_form.get_short_output (),
                request_dnssec
            );

            if (result != null) {
                // Check if auto-WHOIS lookup is enabled
                var settings = new GLib.Settings (Config.APP_ID);
                if (settings.get_boolean ("auto-whois-lookup")) {
                    // Fetch WHOIS data asynchronously (don't block on it)
                    fetch_whois_data.begin (result);
                }
                if (settings.get_boolean ("threat-intel-enabled")) {
                    fetch_threat_data.begin (result);
                }

                result_view.show_result (result);
                query_history.add_query (result);

                // Start non-blocking IPv6 probe (does not hold query_in_progress)
                result_view.show_ipv6_testing ();
                fetch_ipv6_data.begin (result, ++ipv6_request_seq);

                // Auto-clear form if preference is enabled
                if (settings.get_boolean ("auto-clear-form")) {
                    query_form.clear_domain_only ();
                }
            }

            query_in_progress = false;
        }

        private async void fetch_whois_data (QueryResult result) {
            var whois_data = yield whois_service.perform_whois_query (result.domain);
            if (whois_data != null) {
                result.whois_data = whois_data;
                // Refresh the result view to show WHOIS data
                result_view.show_result (result);
            }
        }

        private void on_whois_completed (WhoisData whois_data) {
            // WHOIS data is handled in fetch_whois_data
            debug ("WHOIS query completed for %s", whois_data.domain);
        }

        private void on_whois_failed (string error_message) {
            // Silently log WHOIS failures - they're optional
            debug ("WHOIS query failed: %s", error_message);
        }

        private async void fetch_threat_data (QueryResult result) {
            var threat_data = yield threat_service.perform_check (result.domain);
            if (threat_data != null) {
                result.threat_intel_data = threat_data;
                result_view.show_result (result);
            }
        }

        private void on_threat_completed (ThreatIntelData data) {
            debug ("Threat check completed for %s: %s", data.target, data.get_verdict_label ());
        }

        private void on_threat_failed (string error_message) {
            debug ("Threat check failed: %s", error_message);
        }

        private async void fetch_ipv6_data (QueryResult result, int seq) {
            // Cancel previous probe if any
            if (ipv6_cancellable != null) {
                ipv6_cancellable.cancel ();
            }
            ipv6_cancellable = new Cancellable ();
            var ipv6_result = yield ipv6_service.verify_aaaa_async (result.domain, ipv6_cancellable);
            // Stale check via sequence token
            if (seq != ipv6_request_seq) {
                debug ("IPv6 probe stale (seq %d != %d), ignoring", seq, ipv6_request_seq);
                return;
            }
            if (ipv6_cancellable != null && ipv6_cancellable.is_cancelled ()) {
                debug ("IPv6 probe cancelled for %s", result.domain);
                return;
            }
            if (ipv6_result != null) {
                ipv6_service.probe_completed (ipv6_result);
                result_view.show_ipv6_result (ipv6_result);
            }
        }

        private void on_ipv6_completed (Ipv6TestResult data) {
            debug ("IPv6 probe completed: available=%s reachable=%s status=%s", data.ipv6_available.to_string (), (data.reachable != null ? data.reachable.to_string () : "null"), data.status.to_string ());
        }

        private void on_ipv6_failed (string error_message) {
            debug ("IPv6 probe failed: %s", error_message);
        }

        private void on_query_failed (string error_message) {
            show_toast (error_message);
        }


        private void show_toast (string message) {
            var toast = new Adw.Toast (message);
            toast.timeout = 3;
            toast_overlay.add_toast (toast);
        }

        /**
         * Shows an error toast with extended timeout for important error messages (SEC-009)
         */
        private void show_error_toast (string message) {
            var toast = new Adw.Toast (message);
            toast.timeout = Constants.ERROR_TOAST_TIMEOUT_SECONDS;
            toast.priority = Adw.ToastPriority.HIGH;
            toast_overlay.add_toast (toast);
        }

        private void update_history_list () {
            UiUtils.clear_children (history_listbox);

            // Get filtered history
            var history_items = history_search_entry.text.length > 0 
                ? query_history.search_history (history_search_entry.text)
                : query_history.get_history ();

            if (history_items.size == 0) {
                var placeholder_row = new Gtk.ListBoxRow () {
                    selectable = false
                };
                var placeholder_label = new Gtk.Label ("No queries in history") {
                    margin_top = 12,
                    margin_bottom = 12
                };
                placeholder_label.add_css_class ("dim-label");
                placeholder_row.child = placeholder_label;
                history_listbox.append (placeholder_row);
                return;
            }

            foreach (var result in history_items) {
                var row = create_history_row (result);
                history_listbox.append (row);
            }
        }

        private Gtk.ListBoxRow create_history_row (QueryResult result) {
            var row = new Gtk.ListBoxRow ();
            row.selectable = true;
            row.activatable = true;

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3) {
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 6,
                margin_end = 6
            };

            var title_label = new Gtk.Label (@"$(result.domain) ($(result.query_type.to_string ()))") {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END
            };
            title_label.add_css_class ("body");

            var subtitle_parts = new Gee.ArrayList<string> ();
            subtitle_parts.add (result.timestamp.format ("%H:%M:%S"));
            
            if (result.dns_server != "System default") {
                subtitle_parts.add (result.dns_server);
            }
            
            subtitle_parts.add (result.get_summary ());

            string[] subtitle_array = subtitle_parts.to_array ();
            var subtitle_label = new Gtk.Label (string.joinv (" • ", subtitle_array)) {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END
            };
            subtitle_label.add_css_class ("caption");
            subtitle_label.add_css_class ("dim-label");

            box.append (title_label);
            box.append (subtitle_label);
            row.child = box;

            row.set_data ("query-result", result);
            return row;
        }

        private void on_history_item_selected (Gtk.ListBoxRow row) {
            var result = row.get_data<QueryResult> ("query-result");
            if (result != null) {
                apply_query_settings (result);
                result_view.show_result (result);
                history_popover.popdown ();
            }
        }

        private void apply_query_settings (QueryResult result) {
            query_form.set_domain_from_history (result.domain);
            query_form.set_record_type (result.query_type);
            query_form.set_dns_server (result.dns_server);
            query_form.set_reverse_lookup (result.reverse_lookup);
            query_form.set_trace_path (result.trace_path);
            query_form.set_short_output (result.short_output);
            query_form.set_request_dnssec (result.request_dnssec);
        }

        private void show_batch_lookup_dialog () {
            var dialog = new BatchLookupDialog ();
            dialog.present (this);
        }

        private void show_comparison_dialog () {
            var dialog = new ComparisonDialog ();
            dialog.set_query_history (query_history);
            dialog.present (this);
        }

        private void show_template_library () {
            var dialog = new TemplateLibraryDialog ();
            dialog.template_selected.connect ((t) => {
                var tm = TemplateManager.get_instance ();
                var values = new Gee.HashMap<string,string> ();
                foreach (var e in t.param_defaults.entries) values[e.key]=e.value;
                query_form.apply_template (t, values);
                if (tm.has_unresolved_placeholders (query_form.get_domain ())) {
                    show_error_toast ("Template has unresolved placeholders — please edit domain");
                }
            });
            dialog.present (this);
        }

        private void show_save_template () {
            var domain = query_form.get_domain ();
            if (domain.length==0) { show_error_toast ("Enter a domain before saving as template"); return; }
            var t = query_form.create_template_from_current (domain);
            var dialog = new TemplateDialog.with_initial (t);
            dialog.present (this);
        }
    }
}
