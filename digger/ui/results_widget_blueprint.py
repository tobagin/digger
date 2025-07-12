"""Widget for displaying DNS query results using Blueprint UI."""

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    pass

from gi.repository import Adw, GObject, Gtk, Pango

from ..backend.models import DigResponse, DNSRecord, MXRecord


@Gtk.Template(resource_path="/io/github/tobagin/digger/results_widget.ui")
class ResultsWidget(Gtk.ScrolledWindow):
    """Widget for displaying DNS query results in a structured format using Blueprint UI."""

    __gtype_name__ = "DiggerResultsWidget"

    # Template widgets
    main_box: Gtk.Box = Gtk.Template.Child()

    def __init__(self):
        """Initialize the results widget."""
        super().__init__()

        # Initialize with empty state
        self._show_empty_state()

    def _show_empty_state(self):
        """Show empty state when no results are available."""
        self._clear_content()

        # Empty state container
        empty_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        empty_box.set_valign(Gtk.Align.CENTER)
        empty_box.set_halign(Gtk.Align.CENTER)
        empty_box.set_vexpand(True)

        # Icon
        icon = Gtk.Image.new_from_icon_name("network-workgroup-symbolic")
        icon.set_pixel_size(64)
        icon.add_css_class("dim-label")
        empty_box.append(icon)

        # Title
        title = Gtk.Label(label="No DNS queries yet")
        title.add_css_class("title-2")
        title.add_css_class("dim-label")
        empty_box.append(title)

        # Subtitle
        subtitle = Gtk.Label(label="Enter a domain name above to start")
        subtitle.add_css_class("dim-label")
        empty_box.append(subtitle)

        self.main_box.append(empty_box)

    def show_loading(self):
        """Show loading state during DNS query."""
        self._clear_content()

        # Loading container
        loading_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        loading_box.set_valign(Gtk.Align.CENTER)
        loading_box.set_halign(Gtk.Align.CENTER)
        loading_box.set_vexpand(True)

        # Spinner
        spinner = Gtk.Spinner()
        spinner.set_size_request(32, 32)
        spinner.start()
        loading_box.append(spinner)

        # Loading text
        loading_label = Gtk.Label(label="Looking up DNS records...")
        loading_label.add_css_class("dim-label")
        loading_box.append(loading_label)

        self.main_box.append(loading_box)

    def show_error(self, error_message: str):
        """Show error state with error message.

        Args:
            error_message (str): Error message to display.
        """
        self._clear_content()

        # Error container
        error_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        error_box.set_valign(Gtk.Align.CENTER)
        error_box.set_halign(Gtk.Align.CENTER)
        error_box.set_vexpand(True)

        # Error icon
        icon = Gtk.Image.new_from_icon_name("dialog-error-symbolic")
        icon.set_pixel_size(64)
        icon.add_css_class("error")
        error_box.append(icon)

        # Error title
        title = Gtk.Label(label="DNS Query Failed")
        title.add_css_class("title-2")
        error_box.append(title)

        # Error message
        message = Gtk.Label(label=error_message)
        message.set_wrap(True)
        message.set_wrap_mode(Pango.WrapMode.WORD_CHAR)
        message.set_max_width_chars(50)
        message.set_justify(Gtk.Justification.CENTER)
        message.add_css_class("dim-label")
        error_box.append(message)

        self.main_box.append(error_box)

    def show_response(self, response: DigResponse):
        """Show DNS response with structured results.

        Args:
            response (DigResponse): Parsed DNS response to display.
        """
        self._clear_content()

        # Create results container
        results_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)

        # Query information section
        query_info = self._create_query_info(response)
        results_box.append(query_info)

        # Handle different response statuses
        if response.status != "NOERROR":
            status_info = self._create_status_info(response)
            results_box.append(status_info)

        # Show record sections if they contain data
        if response.answer_section:
            answer_section = self._create_section(
                "Answer Section",
                response.answer_section,
                "These are the direct answers to your query",
            )
            results_box.append(answer_section)

        if response.authority_section:
            authority_section = self._create_section(
                "Authority Section",
                response.authority_section,
                "These are the authoritative name servers",
            )
            results_box.append(authority_section)

        if response.additional_section:
            additional_section = self._create_section(
                "Additional Section",
                response.additional_section,
                "These are additional records that may be helpful",
            )
            results_box.append(additional_section)

        # If no records found, show appropriate message
        if not response.has_answer and response.status == "NOERROR":
            no_records = self._create_no_records_message()
            results_box.append(no_records)

        self.main_box.append(results_box)

    def _create_query_info(self, response: DigResponse) -> Gtk.Widget:
        """Create query information section.

        Args:
            response (DigResponse): DNS response containing query info.

        Returns:
            Gtk.Widget: Widget containing query information.
        """
        group = Adw.PreferencesGroup()
        group.set_title("Query Information")

        # Domain queried
        domain_row = Adw.ActionRow()
        domain_row.set_title("Domain")
        domain_row.set_subtitle(response.query_domain)
        group.add(domain_row)

        # Record type
        type_row = Adw.ActionRow()
        type_row.set_title("Record Type")
        type_row.set_subtitle(response.query_type.value)
        group.add(type_row)

        # Server used
        if response.server:
            server_row = Adw.ActionRow()
            server_row.set_title("DNS Server")
            server_row.set_subtitle(response.server)
            group.add(server_row)

        # Query time
        if response.query_time_ms is not None:
            time_row = Adw.ActionRow()
            time_row.set_title("Query Time")
            time_row.set_subtitle(f"{response.query_time_ms} ms")
            group.add(time_row)

        # Status
        status_row = Adw.ActionRow()
        status_row.set_title("Status")
        status_row.set_subtitle(response.status)

        # Add status icon
        if response.status == "NOERROR":
            status_icon = Gtk.Image.new_from_icon_name("io.github.tobagin.digger-success-symbolic")
            status_icon.set_icon_size(Gtk.IconSize.NORMAL)
            status_icon.add_css_class("success")
        else:
            status_icon = Gtk.Image.new_from_icon_name("io.github.tobagin.digger-error-symbolic")
            status_icon.set_icon_size(Gtk.IconSize.NORMAL)
            status_icon.add_css_class("warning")

        status_row.add_suffix(status_icon)
        group.add(status_row)

        return group

    def _create_status_info(self, response: DigResponse) -> Gtk.Widget:
        """Create status information for non-NOERROR responses.

        Args:
            response (DigResponse): DNS response with status info.

        Returns:
            Gtk.Widget: Widget containing status information.
        """
        group = Adw.PreferencesGroup()
        group.set_title("Status Information")

        status_messages = {
            "NXDOMAIN": "The domain name does not exist",
            "SERVFAIL": "The server failed to complete the request",
            "REFUSED": "The server refused to answer the query",
            "NOTIMP": "The server does not support this type of query",
            "NODATA": "No data was returned for this query",
        }

        message = status_messages.get(response.status, f"Status: {response.status}")

        status_row = Adw.ActionRow()
        status_row.set_title(response.status)
        status_row.set_subtitle(message)

        # Add appropriate icon
        icon = Gtk.Image.new_from_icon_name("dialog-information-symbolic")
        icon.add_css_class("accent")
        status_row.add_suffix(icon)

        group.add(status_row)

        return group

    def _create_section(
        self, title: str, records: list[DNSRecord], description: str
    ) -> Gtk.Widget:
        """Create a collapsible section for DNS records.

        Args:
            title (str): Section title.
            records (List[DNSRecord]): List of DNS records to display.
            description (str): Section description.

        Returns:
            Gtk.Widget: Widget containing the section.
        """
        group = Adw.PreferencesGroup()
        group.set_title(title)
        group.set_description(description)

        # Create expander row for the section
        expander = Adw.ExpanderRow()
        expander.set_title(f"{title} ({len(records)} records)")
        expander.set_expanded(True)  # Expand by default

        # Add each record as a row
        for record in records:
            record_row = self._create_record_row(record)
            expander.add_row(record_row)

        group.add(expander)

        return group

    def _create_record_row(self, record: DNSRecord) -> Gtk.Widget:
        """Create a row for a single DNS record.

        Args:
            record (DNSRecord): DNS record to display.

        Returns:
            Gtk.Widget: Widget containing the record information.
        """
        row = Adw.ActionRow()

        # Set title based on record type
        if isinstance(record, MXRecord):
            row.set_title(f"{record.mail_server} (Priority: {record.priority})")
        else:
            row.set_title(record.value)

        # Set subtitle with record details
        subtitle = f"{record.name} • {record.record_type.value} • TTL: {record.ttl}s"
        row.set_subtitle(subtitle)

        # Add copy button
        copy_button = Gtk.Button()
        copy_button.set_icon_name("io.github.tobagin.digger-copy-symbolic")
        copy_button.set_valign(Gtk.Align.CENTER)
        copy_button.add_css_class("flat")
        copy_button.connect("clicked", self._on_copy_record, record)
        row.add_suffix(copy_button)

        return row

    def _create_no_records_message(self) -> Gtk.Widget:
        """Create message for when no records are found.

        Returns:
            Gtk.Widget: Widget containing the no records message.
        """
        group = Adw.PreferencesGroup()
        group.set_title("No Records Found")

        message_row = Adw.ActionRow()
        message_row.set_title("No DNS records were returned")
        message_row.set_subtitle(
            "The domain exists but has no records of the requested type"
        )

        icon = Gtk.Image.new_from_icon_name("dialog-information-symbolic")
        icon.add_css_class("dim-label")
        message_row.add_suffix(icon)

        group.add(message_row)

        return group

    def _on_copy_record(self, button: Gtk.Button, record: DNSRecord):
        """Handle copy button click for a record.

        Args:
            button (Gtk.Button): The copy button that was clicked.
            record (DNSRecord): The record to copy.
        """
        # Get the clipboard
        clipboard = button.get_clipboard()

        # Format the record for copying
        if isinstance(record, MXRecord):
            text = f"{record.priority} {record.mail_server}"
        else:
            text = record.value

        # Copy to clipboard
        clipboard.set(text)

        # Visual feedback (temporarily change icon)
        button.set_icon_name("emblem-ok-symbolic")
        GObject.timeout_add(1000, lambda: button.set_icon_name("edit-copy-symbolic"))

    def _clear_content(self):
        """Clear all content from the results widget."""
        child = self.main_box.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            self.main_box.remove(child)
            child = next_child