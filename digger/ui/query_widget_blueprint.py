"""Widget for DNS query input controls using Blueprint UI."""

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from pathlib import Path
from typing import Optional

from gi.repository import Adw, GObject, Gtk

from ..backend.models import RecordType


@Gtk.Template(resource_path="/io/github/tobagin/digger/query_widget.ui")
class QueryWidget(Gtk.Box):
    """Widget for DNS query input and submission using Blueprint UI."""

    __gtype_name__ = "DiggerQueryWidget"

    __gsignals__ = {
        "query-submitted": (GObject.SignalFlags.RUN_FIRST, None, (str, str, str))
    }

    # Template widgets
    query_group: Adw.PreferencesGroup = Gtk.Template.Child()
    domain_entry: Adw.EntryRow = Gtk.Template.Child()
    type_combo: Adw.ComboRow = Gtk.Template.Child()
    type_model: Gtk.StringList = Gtk.Template.Child()
    server_entry: Adw.EntryRow = Gtk.Template.Child()
    advanced_options: Adw.ExpanderRow = Gtk.Template.Child()
    reverse_switch: Gtk.Switch = Gtk.Template.Child()
    trace_switch: Gtk.Switch = Gtk.Template.Child()
    short_switch: Gtk.Switch = Gtk.Template.Child()
    button_box: Gtk.Box = Gtk.Template.Child()
    lookup_button: Gtk.Button = Gtk.Template.Child()
    clear_button: Gtk.Button = Gtk.Template.Child()

    def __init__(self):
        """Initialize the query widget."""
        super().__init__()

        # Populate record type model
        for record_type in RecordType:
            self.type_model.append(record_type.value)

        self.type_combo.set_selected(0)  # Default to A record

        # Set initial focus to domain entry
        self.domain_entry.grab_focus()

    @Gtk.Template.Callback()
    def on_entry_activate(self, widget):
        """Handle Enter key press in entry fields.

        Args:
            widget: The entry widget that was activated.
        """
        self._submit_query()

    @Gtk.Template.Callback()
    def on_domain_changed(self, entry):
        """Handle domain entry text changes for validation.

        Args:
            entry: The entry widget whose text changed.
        """
        domain = entry.get_text().strip()

        # Simple validation - enable/disable lookup button
        is_valid = len(domain) > 0 and self._is_valid_domain_format(domain)
        self.lookup_button.set_sensitive(is_valid)

        # Update CSS classes for visual feedback
        if domain and not is_valid:
            entry.add_css_class("error")
        else:
            entry.remove_css_class("error")

    @Gtk.Template.Callback()
    def on_lookup_clicked(self, button):
        """Handle lookup button click.

        Args:
            button: The button widget that was clicked.
        """
        self._submit_query()

    @Gtk.Template.Callback()
    def on_clear_clicked(self, button):
        """Handle clear button click.

        Args:
            button: The button widget that was clicked.
        """
        self.clear_inputs()

    def _is_valid_domain_format(self, domain: str) -> bool:
        """Basic domain format validation.

        Args:
            domain (str): Domain name to validate.

        Returns:
            bool: True if domain format appears valid.
        """
        if not domain or len(domain) > 253:
            return False

        # Check for basic domain format
        import re

        pattern = r"^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$"
        return re.match(pattern, domain) is not None

    def _submit_query(self):
        """Submit the DNS query with current form values."""
        domain = self.domain_entry.get_text().strip()
        if not domain:
            self._show_validation_error("Domain name is required")
            return

        if not self._is_valid_domain_format(domain):
            self._show_validation_error("Please enter a valid domain name")
            return

        # Get selected record type
        selected_index = self.type_combo.get_selected()
        record_type = list(RecordType)[selected_index].value

        # Get nameserver (optional)
        nameserver = self.server_entry.get_text().strip()

        # Emit signal with query parameters
        self.emit("query-submitted", domain, record_type, nameserver)

    def _show_validation_error(self, message: str):
        """Show validation error to user.

        Args:
            message (str): Error message to display.
        """
        # For now, just focus the domain entry
        # In a full implementation, this could show a toast or inline message
        self.domain_entry.grab_focus()
        print(f"Validation error: {message}")  # Temporary debug output

    def get_domain(self) -> str:
        """Get the current domain value.

        Returns:
            str: Current domain name from the entry.
        """
        return self.domain_entry.get_text().strip()

    def get_record_type(self) -> str:
        """Get the selected record type.

        Returns:
            str: Selected DNS record type.
        """
        selected_index = self.type_combo.get_selected()
        return list(RecordType)[selected_index].value

    def get_nameserver(self) -> Optional[str]:
        """Get the nameserver value if specified.

        Returns:
            Optional[str]: Nameserver address or None if not specified.
        """
        server = self.server_entry.get_text().strip()
        return server if server else None

    def get_advanced_options(self) -> dict:
        """Get the advanced options state.

        Returns:
            dict: Dictionary with advanced options state.
        """
        return {
            "reverse_lookup": self.reverse_switch.get_active(),
            "trace": self.trace_switch.get_active(),
            "short": self.short_switch.get_active(),
        }

    def set_domain(self, domain: str):
        """Set the domain name in the entry.

        Args:
            domain (str): Domain name to set.
        """
        self.domain_entry.set_text(domain)

    def set_record_type(self, record_type: str):
        """Set the selected record type.

        Args:
            record_type (str): Record type to select.
        """
        try:
            record_types = list(RecordType)
            for i, rt in enumerate(record_types):
                if rt.value == record_type.upper():
                    self.type_combo.set_selected(i)
                    break
        except (ValueError, IndexError):
            pass  # Invalid record type, keep current selection

    def set_nameserver(self, nameserver: Optional[str]):
        """Set the nameserver in the entry.

        Args:
            nameserver (Optional[str]): Nameserver address to set.
        """
        self.server_entry.set_text(nameserver or "")

    def set_advanced_options(self, options: dict):
        """Set the advanced options state.

        Args:
            options (dict): Dictionary with advanced options state.
        """
        self.reverse_switch.set_active(options.get("reverse_lookup", False))
        self.trace_switch.set_active(options.get("trace", False))
        self.short_switch.set_active(options.get("short", False))

    def set_query_params(self, domain: str, record_type: str, nameserver: str):
        """Set all query parameters at once.

        Args:
            domain (str): Domain name to set.
            record_type (str): Record type to select.
            nameserver (str): Nameserver address to set.
        """
        self.set_domain(domain)
        self.set_record_type(record_type)
        self.set_nameserver(nameserver if nameserver else None)

    def clear_inputs(self):
        """Clear all input fields."""
        self.domain_entry.set_text("")
        self.server_entry.set_text("")
        self.type_combo.set_selected(0)  # Reset to A record
        self.reverse_switch.set_active(False)
        self.trace_switch.set_active(False)
        self.short_switch.set_active(False)
        self.domain_entry.grab_focus()

    def set_loading_state(self, loading: bool):
        """Set the loading state of the widget.

        Args:
            loading (bool): True to show loading state, False otherwise.
        """
        self.lookup_button.set_sensitive(not loading)
        self.domain_entry.set_sensitive(not loading)
        self.server_entry.set_sensitive(not loading)
        self.type_combo.set_sensitive(not loading)

        if loading:
            self.lookup_button.set_label("Looking up...")
        else:
            self.lookup_button.set_label("Lookup")

    def focus_domain_entry(self):
        """Focus the domain entry field."""
        self.domain_entry.grab_focus()