"""Main application window for Digger DNS lookup tool using Blueprint UI."""

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from pathlib import Path
from typing import Optional

from gi.repository import Adw, Gio, GLib, Gtk

from ..backend.dig_executor import DigExecutor
from ..backend.dig_parser import DigParser
from ..backend.history import QueryHistory
from .history_widget_blueprint import HistoryPopover, HistoryWidget
from .query_widget_blueprint import QueryWidget
from .results_widget_blueprint import ResultsWidget
from .settings_dialog import SettingsDialog


@Gtk.Template(resource_path="/io/github/tobagin/digger/main_window.ui")
class MainWindow(Adw.ApplicationWindow):
    """Main application window for Digger using Blueprint UI."""

    __gtype_name__ = "DiggerMainWindow"

    # Template widgets
    header_bar: Adw.HeaderBar = Gtk.Template.Child()
    history_button: Gtk.MenuButton = Gtk.Template.Child()
    menu_button: Gtk.MenuButton = Gtk.Template.Child()
    main_box: Gtk.Box = Gtk.Template.Child()
    query_widget: QueryWidget = Gtk.Template.Child()
    results_widget: ResultsWidget = Gtk.Template.Child()
    shortcut_controller: Gtk.ShortcutController = Gtk.Template.Child()

    def __init__(self, app: Adw.Application):
        """Initialize the main window.

        Args:
            app (Adw.Application): The application instance.
        """
        super().__init__(application=app)

        # Initialize backend components
        self.executor = DigExecutor()
        self.parser = DigParser()
        self.history = QueryHistory()

        # Track current query state
        self._current_query = None

        # Setup history popover
        self.history_popover = HistoryPopover(self.history)
        self.history_popover.connect("query-selected", self._on_history_query_selected)
        self.history_popover.connect("view-all-requested", self._on_view_all_requested)
        self.history_button.set_popover(self.history_popover)

        # Setup actions
        self._setup_actions()

        # Connect query widget signal
        self.query_widget.connect("query-submitted", self._on_query_submitted)

        # Check dig availability after UI is built
        GLib.idle_add(self._check_dig_availability)

    def _setup_actions(self):
        """Setup window actions."""
        # View history action
        view_history_action = Gio.SimpleAction(name="view-history")
        view_history_action.connect("activate", self._on_view_history_action)
        self.add_action(view_history_action)

        # Focus domain action
        focus_domain_action = Gio.SimpleAction(name="focus-domain")
        focus_domain_action.connect("activate", self._on_focus_domain_action)
        self.add_action(focus_domain_action)

        # Repeat query action
        repeat_query_action = Gio.SimpleAction(name="repeat-query")
        repeat_query_action.connect("activate", self._on_repeat_query_action)
        self.add_action(repeat_query_action)

        # Clear results action
        clear_results_action = Gio.SimpleAction(name="clear-results")
        clear_results_action.connect("activate", self._on_clear_results_action)
        self.add_action(clear_results_action)

        # Settings action
        settings_action = Gio.SimpleAction(name="settings")
        settings_action.connect("activate", self._on_settings_action)
        self.add_action(settings_action)

    def _on_focus_domain_action(self, action: Gio.SimpleAction, parameter):
        """Handle focus domain action (Ctrl+L).

        Args:
            action (Gio.SimpleAction): The action that was activated.
            parameter: Action parameter (unused).
        """
        self.query_widget.focus_domain_entry()

    def _on_repeat_query_action(self, action: Gio.SimpleAction, parameter):
        """Handle repeat query action (Ctrl+R).

        Args:
            action (Gio.SimpleAction): The action that was activated.
            parameter: Action parameter (unused).
        """
        if self._current_query:
            domain, record_type, nameserver = self._current_query
            self._execute_query(domain, record_type, nameserver)

    def _on_clear_results_action(self, action: Gio.SimpleAction, parameter):
        """Handle clear results action (Escape).

        Args:
            action (Gio.SimpleAction): The action that was activated.
            parameter: Action parameter (unused).
        """
        self.results_widget._show_empty_state()

    def _check_dig_availability(self):
        """Check if dig command is available and show warning if not."""
        if not self.executor.check_dig_available():
            self._show_dig_missing_dialog()
        return False  # Don't repeat

    def _show_dig_missing_dialog(self):
        """Show dialog when dig command is not available."""
        dialog = Adw.MessageDialog(
            transient_for=self,
            heading="dig Command Not Found",
            body="The 'dig' command is required but not installed on your system.\n\n"
            "Please install it using your package manager:\n"
            "• Ubuntu/Debian: sudo apt install dnsutils\n"
            "• Fedora: sudo dnf install bind-utils\n"
            "• Arch: sudo pacman -S bind-tools\n"
            "• Alpine: sudo apk add bind-tools",
        )
        dialog.add_response("ok", "OK")
        dialog.set_default_response("ok")
        dialog.set_close_response("ok")
        dialog.present()

    @Gtk.Template.Callback()
    def on_query_submitted(
        self, widget: QueryWidget, domain: str, record_type: str, nameserver: str
    ):
        """Handle query submission from query widget.

        Args:
            widget (QueryWidget): The query widget that emitted the signal.
            domain (str): Domain name to query.
            record_type (str): DNS record type.
            nameserver (str): DNS server to use (empty string if not specified).
        """
        self._on_query_submitted(widget, domain, record_type, nameserver)

    def _on_query_submitted(
        self, widget: QueryWidget, domain: str, record_type: str, nameserver: str
    ):
        """Handle query submission from query widget.

        Args:
            widget (QueryWidget): The query widget that emitted the signal.
            domain (str): Domain name to query.
            record_type (str): DNS record type.
            nameserver (str): DNS server to use (empty string if not specified).
        """
        # Convert empty string to None for nameserver
        nameserver = nameserver if nameserver else None

        # Store current query for repeat functionality
        self._current_query = (domain, record_type, nameserver)

        # Execute the query
        self._execute_query(domain, record_type, nameserver)

    def _execute_query(self, domain: str, record_type: str, nameserver: Optional[str]):
        """Execute DNS query with given parameters.

        Args:
            domain (str): Domain name to query.
            record_type (str): DNS record type.
            nameserver (Optional[str]): DNS server to use.
        """
        # Validate domain using parser
        if not self.parser.validate_domain(domain):
            self.results_widget.show_error("Invalid domain name format")
            return

        # Check if dig is available
        if not self.executor.check_dig_available():
            self.results_widget.show_error("dig command is not available")
            return

        # Show loading state
        self.results_widget.show_loading()
        self.query_widget.set_loading_state(True)

        # Get advanced options from query widget
        advanced_options = self.query_widget.get_advanced_options()

        # Execute dig command in background
        self.executor.execute_dig(
            domain=domain,
            record_type=record_type,
            nameserver=nameserver,
            callback=self._on_dig_complete,
            reverse_lookup=advanced_options.get("reverse_lookup", False),
            trace=advanced_options.get("trace", False),
            short=advanced_options.get("short", False),
        )

    def _on_dig_complete(self, output: str, error: Optional[Exception]):
        """Handle dig command completion.

        Args:
            output (str): Dig command output.
            error (Optional[Exception]): Any error that occurred.
        """
        # This runs in background thread, so use idle_add for UI updates
        GLib.idle_add(self._update_results, output, error)

    def _update_results(self, output: str, error: Optional[Exception]) -> bool:
        """Update UI with results (runs in main thread).

        Args:
            output (str): Dig command output.
            error (Optional[Exception]): Any error that occurred.

        Returns:
            bool: False to prevent repeat (GLib.idle_add requirement).
        """
        # Reset loading state
        self.query_widget.set_loading_state(False)

        if error:
            # Show error
            error_msg = str(error)
            if "not available" in error_msg:
                error_msg = "dig command is not installed or not available"
            elif "timed out" in error_msg.lower():
                error_msg = "DNS query timed out. Please try again or use a different DNS server."
            elif "failed" in error_msg.lower():
                error_msg = "DNS query failed. Please check your network connection."

            self.results_widget.show_error(error_msg)

            # Add failed query to history
            if self._current_query:
                domain, record_type, nameserver = self._current_query
                from ..backend.models import RecordType
                try:
                    record_type_enum = RecordType(record_type)
                    self.history.add_entry(
                        domain=domain,
                        record_type=record_type_enum,
                        nameserver=nameserver,
                        status="FAILED",
                        query_time_ms=None,
                    )
                    self.history_popover.refresh()
                except ValueError:
                    pass  # Invalid record type, skip history entry
        else:
            # Parse and show results
            try:
                if self._current_query:
                    domain, record_type, nameserver = self._current_query
                    response = self.parser.parse(output, domain, record_type)
                    self.results_widget.show_response(response)

                    # Add successful query to history
                    from ..backend.models import RecordType
                    try:
                        record_type_enum = RecordType(record_type)
                        self.history.add_entry(
                            domain=domain,
                            record_type=record_type_enum,
                            nameserver=nameserver,
                            status=response.status,
                            query_time_ms=response.query_time_ms,
                        )
                        self.history_popover.refresh()
                    except ValueError:
                        pass  # Invalid record type, skip history entry
                else:
                    self.results_widget.show_error("Query information not available")
            except Exception as e:
                self.results_widget.show_error(
                    f"Failed to parse DNS response: {str(e)}"
                )

        return False  # Don't repeat

    def get_system_info(self) -> dict:
        """Get system information for debugging.

        Returns:
            dict: System information.
        """
        return {
            "window_size": self.get_default_size(),
            "dig_available": self.executor.check_dig_available(),
            "executor_info": self.executor.get_system_info(),
            "supported_record_types": self.parser.get_supported_record_types(),
        }

    def _on_view_history_action(self, action: Gio.SimpleAction, parameter):
        """Handle view history action.

        Args:
            action (Gio.SimpleAction): The action that was activated.
            parameter: Action parameter (unused).
        """
        history_window = HistoryWidget(self, self.history)
        history_window.connect("query-selected", self._on_history_query_selected)
        history_window.connect("history-modified", self._on_history_modified)
        history_window.present(self)

    def _on_history_query_selected(
        self, widget, domain: str, record_type: str, nameserver: str
    ):
        """Handle query selection from history.

        Args:
            widget: The widget that emitted the signal.
            domain (str): Domain name to query.
            record_type (str): DNS record type.
            nameserver (str): DNS server to use.
        """
        # Update the query widget with the selected query
        self.query_widget.set_query_params(domain, record_type, nameserver)

        # Execute the query
        nameserver_param = nameserver if nameserver else None
        self._current_query = (domain, record_type, nameserver_param)
        self._execute_query(domain, record_type, nameserver_param)

    def _on_view_all_requested(self, popover):
        """Handle view all history request from popover.

        Args:
            popover: The popover that emitted the signal.
        """
        self._on_view_history_action(None, None)

    def _on_history_modified(self, widget):
        """Handle history modification signal.

        Args:
            widget: The widget that emitted the signal.
        """
        # Refresh the history popover
        self.history_popover.refresh()

    def _on_settings_action(self, action: Gio.SimpleAction, parameter):
        """Handle settings action.

        Args:
            action (Gio.SimpleAction): The action that was activated.
            parameter: Action parameter (unused).
        """
        settings_dialog = SettingsDialog(self, self.history)
        settings_dialog.present(self)

    def do_close_request(self):
        """Handle window close request."""
        # Allow the window to close
        return False