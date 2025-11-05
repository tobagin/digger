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
     * Autocomplete dropdown widget for domain suggestions
     */
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/autocomplete-dropdown.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/autocomplete-dropdown.ui")]
#endif
    public class AutocompleteDropdown : Gtk.Popover {
        [GtkChild] private unowned Gtk.Box main_box;
        [GtkChild] private unowned Gtk.ScrolledWindow scrolled_window;
        [GtkChild] private unowned Gtk.ListBox suggestion_listbox;

        private Gtk.Entry target_entry;
        private DomainSuggestionEngine suggestion_engine;
        private Gee.ArrayList<DomainSuggestion> current_suggestions;
        private int selected_index = -1;
        private bool showing_suggestions = false;
        private bool suggestions_enabled = true;

        // Timeout cancellation support
        private uint hide_timeout_id = 0;

        public signal void suggestion_selected (string domain);

        public AutocompleteDropdown (Gtk.Entry entry) {
            target_entry = entry;
            suggestion_engine = DomainSuggestionEngine.get_instance ();
            current_suggestions = new Gee.ArrayList<DomainSuggestion> ();

            connect_signals ();
        }
        
        private void connect_signals () {
            // Connect to target entry events
            target_entry.changed.connect (on_entry_changed);
            
            // Set up key event controller
            var key_controller = new Gtk.EventControllerKey ();
            key_controller.key_pressed.connect (on_entry_key_pressed);
            target_entry.add_controller (key_controller);
            
            // Set up focus controller
            var focus_controller = new Gtk.EventControllerFocus ();
            focus_controller.leave.connect (on_entry_focus_out);
            target_entry.add_controller (focus_controller);
            
            // Connect to listbox events
            suggestion_listbox.row_activated.connect (on_suggestion_activated);
            suggestion_listbox.row_selected.connect (on_suggestion_selected);
        }
        
        private void on_entry_changed () {
            if (!suggestions_enabled) {
                return;
            }
            
            string text = target_entry.text.strip ();
            
            if (text.length < 2) {
                hide_suggestions ();
                return;
            }
            
            update_suggestions (text);
        }
        
        private bool on_entry_key_pressed (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (!showing_suggestions) {
                return false;
            }
            
            switch (keyval) {
                case Gdk.Key.Down:
                    navigate_suggestions (1);
                    return true;
                    
                case Gdk.Key.Up:
                    navigate_suggestions (-1);
                    return true;
                    
                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                    if (selected_index >= 0 && selected_index < current_suggestions.size) {
                        apply_suggestion (current_suggestions[selected_index]);
                        // Ensure popover is hidden immediately
                        hide_suggestions ();
                        return true;
                    }
                    // If no suggestion is selected, hide the popover and let the normal Enter handling proceed
                    hide_suggestions ();
                    return false;
                    
                case Gdk.Key.Escape:
                    hide_suggestions ();
                    return true;
                    
                case Gdk.Key.Tab:
                    if (selected_index >= 0 && selected_index < current_suggestions.size) {
                        apply_suggestion (current_suggestions[selected_index]);
                        return true;
                    }
                    break;
            }
            
            return false;
        }
        
        private void on_entry_focus_out () {
            // Cancel any existing timeout
            if (hide_timeout_id > 0) {
                Source.remove (hide_timeout_id);
                hide_timeout_id = 0;
            }

            // Delay hiding to allow for mouse clicks on suggestions
            hide_timeout_id = Timeout.add (Constants.DROPDOWN_HIDE_DELAY_MS, () => {
                // Only hide if we're still showing suggestions and don't have focus
                if (showing_suggestions && !target_entry.has_focus) {
                    hide_suggestions ();
                }
                hide_timeout_id = 0;
                return false;
            });
        }

        ~AutocompleteDropdown () {
            // Cancel timeout on destruction
            if (hide_timeout_id > 0) {
                Source.remove (hide_timeout_id);
                hide_timeout_id = 0;
            }
        }
        
        private void on_suggestion_activated (Gtk.ListBoxRow row) {
            int index = row.get_index ();
            if (index >= 0 && index < current_suggestions.size) {
                apply_suggestion (current_suggestions[index]);
                hide_suggestions ();
            }
        }
        
        private void on_suggestion_selected (Gtk.ListBoxRow? row) {
            if (row != null) {
                selected_index = row.get_index ();
            }
        }
        
        private void update_suggestions (string text) {
            var suggestions = suggestion_engine.get_suggestions (text);
            current_suggestions.clear ();
            current_suggestions.add_all (suggestions);
            
            // Clear existing suggestions
            var child = suggestion_listbox.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                suggestion_listbox.remove (child);
                child = next;
            }
            
            // Add new suggestions
            if (suggestions.size > 0) {
                foreach (var suggestion in suggestions) {
                    var row = create_suggestion_row (suggestion);
                    suggestion_listbox.append (row);
                }
                show_suggestions ();
            } else {
                hide_suggestions ();
            }
            
            selected_index = -1;
        }
        
        private Gtk.ListBoxRow create_suggestion_row (DomainSuggestion suggestion) {
            var row = new Gtk.ListBoxRow ();
            
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 12,
                margin_end = 12
            };
            
            // Icon
            var icon = new Gtk.Image.from_icon_name (suggestion.get_icon ()) {
                pixel_size = 16
            };
            box.append (icon);
            
            // Domain text
            var domain_label = new Gtk.Label (suggestion.domain) {
                halign = Gtk.Align.START,
                hexpand = true,
                ellipsize = Pango.EllipsizeMode.END
            };
            domain_label.add_css_class ("body");
            box.append (domain_label);
            
            // Type badge
            var type_badge = create_type_badge (suggestion);
            box.append (type_badge);
            
            row.child = box;
            return row;
        }
        
        private Gtk.Widget create_type_badge (DomainSuggestion suggestion) {
            string badge_text = "";
            string badge_class = "";
            
            switch (suggestion.suggestion_type) {
                case SuggestionType.HISTORY:
                    badge_text = "History";
                    badge_class = "accent";
                    break;
                case SuggestionType.COMMON_TLD:
                    badge_text = "TLD";
                    badge_class = "success";
                    break;
                case SuggestionType.TYPO_CORRECTION:
                    badge_text = "Fix";
                    badge_class = "warning";
                    break;
                case SuggestionType.POPULAR:
                    badge_text = "Popular";
                    badge_class = "accent";
                    break;
            }
            
            var badge = new Gtk.Label (badge_text) {
                halign = Gtk.Align.CENTER,
                width_request = 60
            };
            badge.add_css_class ("pill");
            badge.add_css_class (badge_class);
            
            return badge;
        }
        
        private void navigate_suggestions (int direction) {
            if (current_suggestions.size == 0) return;
            
            int new_index = selected_index + direction;
            
            // Wrap around
            if (new_index < 0) {
                new_index = current_suggestions.size - 1;
            } else if (new_index >= current_suggestions.size) {
                new_index = 0;
            }
            
            selected_index = new_index;
            
            // Update listbox selection
            var row = suggestion_listbox.get_row_at_index (selected_index);
            if (row != null) {
                suggestion_listbox.select_row (row);
                
                // Ensure the row is visible
                var adjustment = suggestion_listbox.get_parent () as Gtk.ScrolledWindow;
                if (adjustment != null) {
                    var row_allocation = Graphene.Rect ();
                    row.compute_bounds (suggestion_listbox, out row_allocation);
                    
                    var scrolled_window = adjustment as Gtk.ScrolledWindow;
                    scrolled_window.get_vadjustment ().clamp_page (
                        row_allocation.get_y (),
                        row_allocation.get_y () + row_allocation.get_height ()
                    );
                }
            }
        }
        
        private void apply_suggestion (DomainSuggestion suggestion) {
            target_entry.text = suggestion.domain;
            target_entry.set_position (-1); // Move cursor to end
            
            // Record usage for improved suggestions
            suggestion_engine.record_domain_usage (suggestion.domain);
            
            // Emit signal before hiding to ensure proper order
            suggestion_selected (suggestion.domain);
        }
        
        private void show_suggestions () {
            if (!showing_suggestions) {
                showing_suggestions = true;
                if (get_parent () == null) {
                    set_parent (target_entry);
                }
                popup ();
            }
        }

        private void hide_suggestions () {
            if (showing_suggestions) {
                showing_suggestions = false;
                popdown ();
                selected_index = -1;
            }
        }
        
        /**
         * Set the query history for improved suggestions
         */
        public void set_query_history (QueryHistory history) {
            suggestion_engine.set_query_history (history);
        }
        
        /**
         * Manually trigger suggestions update
         */
        public void trigger_suggestions () {
            string text = target_entry.text.strip ();
            if (text.length >= 2) {
                update_suggestions (text);
            }
        }
        
        /**
         * Clear current suggestions and hide dropdown
         */
        public void clear_suggestions () {
            current_suggestions.clear ();
            hide_suggestions ();
        }
        
        /**
         * Temporarily disable autocomplete suggestions
         */
        public void disable_suggestions () {
            suggestions_enabled = false;
            hide_suggestions ();
        }
        
        /**
         * Re-enable autocomplete suggestions
         */
        public void enable_suggestions () {
            suggestions_enabled = true;
        }
        
        /**
         * Set domain text without triggering autocomplete
         */
        public void set_domain_without_autocomplete (string domain) {
            disable_suggestions ();
            target_entry.text = domain;
            target_entry.set_position (-1);
            enable_suggestions ();
        }
    }
}
