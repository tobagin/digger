"""Main application window for Digger DNS lookup tool."""

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from typing import Optional

from gi.repository import Adw, Gio, GLib, Gtk

from ..backend.dig_executor import DigExecutor
from ..backend.dig_parser import DigParser
from .query_widget import QueryWidget
from .results_widget import ResultsWidget


class MainWindow(Adw.ApplicationWindow):
    """Main application window for Digger."""

    def __init__(self, app: Adw.Application):
        """Initialize the main window.

        Args:
            app (Adw.Application): The application instance.
        """
        super().__init__(application=app)

        # Window properties
        self.set_default_size(800, 600)
        self.set_title("Digger - DNS Lookup Tool")
        self.set_icon_name("io.github.tobagin.digger")

        # Initialize backend components
        self.executor = DigExecutor()
        self.parser = DigParser()

        # Track current query state
        self._current_query = None

        # Build the UI
        self._build_ui()

        # Setup keyboard shortcuts
        self._setup_shortcuts()

        # Check dig availability after UI is built
        GLib.idle_add(self._check_dig_availability)

    def _build_ui(self):
        """Build the main user interface."""
        # Create header bar
        header = Adw.HeaderBar()
        header.set_title_widget(Gtk.Label(label="Digger"))

        # Add menu button
        menu_button = Gtk.MenuButton()
        menu_button.set_icon_name("open-menu-symbolic")
        menu_button.set_direction(Gtk.ArrowType.DOWN)

        # Create menu
        menu_model = Gio.Menu()
        menu_model.append("About Digger", "app.about")
        menu_model.append("Quit", "app.quit")
        menu_button.set_menu_model(menu_model)

        header.pack_end(menu_button)

        # Create main content area
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        # Create query widget
        self.query_widget = QueryWidget()
        self.query_widget.connect("query-submitted", self._on_query_submitted)

        # Create separator
        separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        separator.add_css_class("spacer")

        # Create results widget
        self.results_widget = ResultsWidget()

        # Add widgets to main box
        main_box.append(self.query_widget)
        main_box.append(separator)
        main_box.append(self.results_widget)

        # Create toolbar view
        toolbar_view = Adw.ToolbarView()
        toolbar_view.add_top_bar(header)
        toolbar_view.set_content(main_box)

        # Set as window content
        self.set_content(toolbar_view)

    def _setup_shortcuts(self):
        """Setup keyboard shortcuts."""
        # Create shortcut controller
        shortcut_controller = Gtk.ShortcutController()

        # Ctrl+L - Focus domain entry
        focus_shortcut = Gtk.Shortcut.new(
            Gtk.ShortcutTrigger.parse_string("<Control>l"),
            Gtk.CallbackAction.new(self._on_focus_domain_shortcut),
        )
        shortcut_controller.add_shortcut(focus_shortcut)

        # Ctrl+R - Repeat last query
        repeat_shortcut = Gtk.Shortcut.new(
            Gtk.ShortcutTrigger.parse_string("<Control>r"),
            Gtk.CallbackAction.new(self._on_repeat_query_shortcut),
        )
        shortcut_controller.add_shortcut(repeat_shortcut)

        # Escape - Clear results
        clear_shortcut = Gtk.Shortcut.new(
            Gtk.ShortcutTrigger.parse_string("Escape"),
            Gtk.CallbackAction.new(self._on_clear_results_shortcut),
        )
        shortcut_controller.add_shortcut(clear_shortcut)

        # Add controller to window
        self.add_controller(shortcut_controller)

    def _on_focus_domain_shortcut(self, widget, args):
        """Handle focus domain shortcut (Ctrl+L).

        Args:
            widget: The widget that triggered the shortcut.
            args: Additional arguments.
        """
        self.query_widget.focus_domain_entry()
        return True

    def _on_repeat_query_shortcut(self, widget, args):
        """Handle repeat query shortcut (Ctrl+R).

        Args:
            widget: The widget that triggered the shortcut.
            args: Additional arguments.
        """
        if self._current_query:
            domain, record_type, nameserver = self._current_query
            self._execute_query(domain, record_type, nameserver)
        return True

    def _on_clear_results_shortcut(self, widget, args):
        """Handle clear results shortcut (Escape).

        Args:
            widget: The widget that triggered the shortcut.
            args: Additional arguments.
        """
        self.results_widget._show_empty_state()
        return True

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

        # Execute dig command in background
        self.executor.execute_dig(
            domain=domain,
            record_type=record_type,
            nameserver=nameserver,
            callback=self._on_dig_complete,
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
        else:
            # Parse and show results
            try:
                if self._current_query:
                    domain, record_type, _ = self._current_query
                    response = self.parser.parse(output, domain, record_type)
                    self.results_widget.show_response(response)
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

    def do_close_request(self):
        """Handle window close request."""
        # Allow the window to close
        return False
