#!/usr/bin/env python3
"""Digger - GTK4 DNS Lookup Tool."""

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

import sys
from pathlib import Path

from gi.repository import Adw, Gio, Gtk

# Add parent directory to path for imports when running directly
if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).parent.parent))

from digger.ui.main_window_blueprint import MainWindow


class DiggerApplication(Adw.Application):
    """Main application class for Digger DNS lookup tool."""

    def __init__(self):
        """Initialize the application."""
        super().__init__(
            application_id="io.github.tobagin.digger",
            flags=Gio.ApplicationFlags.DEFAULT_FLAGS,
        )

        # Setup actions
        self._setup_actions()

        # Connect signals
        self.connect("activate", self._on_activate)
        self.connect("startup", self._on_startup)

    def _setup_actions(self):
        """Setup application actions."""
        # About action
        about_action = Gio.SimpleAction.new("about", None)
        about_action.connect("activate", self._on_about_action)
        self.add_action(about_action)

        # Quit action
        quit_action = Gio.SimpleAction.new("quit", None)
        quit_action.connect("activate", self._on_quit_action)
        self.add_action(quit_action)

        # Set keyboard shortcuts
        self.set_accels_for_action("app.quit", ["<Control>q"])

    def _load_resources(self):
        """Load GResource files for development builds."""
        # Check if resources are already loaded (e.g., by the launcher script)
        try:
            # Try to access a known resource to see if it's already loaded
            from gi.repository import Gio
            Gio.resources_get_info("/io/github/tobagin/digger/main_window.ui", Gio.ResourceLookupFlags.NONE)
            print("GResource already loaded by launcher script")
            return
        except:
            pass  # Resources not loaded, continue with manual loading
        
        try:
            # Try multiple possible locations for the GResource file
            possible_paths = [
                # Development build (manual compilation)
                Path(__file__).parent / "ui" / "digger.gresource",
                # Meson build (installed location)
                Path(__file__).parent / "digger-resources.gresource",
                # System installed location
                Path("/app/share/io.github.tobagin.digger/digger-resources.gresource"),
            ]
            
            resource_loaded = False
            for resource_path in possible_paths:
                if resource_path.exists():
                    resource = Gio.Resource.load(str(resource_path))
                    resource._register()
                    print(f"Loaded GResource: {resource_path}")
                    resource_loaded = True
                    break
            
            if not resource_loaded:
                print("Warning: GResource file not found in any expected location")
                print("Tried paths:")
                for path in possible_paths:
                    print(f"  - {path}")
                print("UI may not load correctly.")
        except Exception as e:
            print(f"Error loading GResource: {e}")
            print("UI may not load correctly.")

    def _on_startup(self, app):
        """Handle application startup.

        Args:
            app: The application instance.
        """
        # Initialize LibAdwaita
        Adw.init()

        # Load GResource
        self._load_resources()

        # Set application icon
        Gtk.Window.set_default_icon_name("io.github.tobagin.digger")

    def _on_activate(self, app):
        """Handle application activation.

        Args:
            app: The application instance.
        """
        # Get or create main window
        win = self.props.active_window
        if not win:
            win = MainWindow(self)

        # Present the window
        win.present()

    def _on_about_action(self, action, param):
        """Handle about action.

        Args:
            action: The action that was triggered.
            param: Action parameters.
        """
        # Get the active window
        win = self.props.active_window

        # Create about dialog
        about_dialog = Adw.AboutWindow(
            transient_for=win,
            application_name="Digger",
            application_icon="io.github.tobagin.digger",
            version="1.0.1",
            developer_name="Thiago Fernandes",
            copyright="© 2025 Thiago Fernandes",
            license_type=Gtk.License.GPL_3_0,
            website="https://github.com/tobagin/digger",
            support_url="https://github.com/tobagin/digger/discussions",
            issue_url="https://github.com/tobagin/digger/issues",
            developers=["Thiago Fernandes <thiago@example.com>"],
            designers=["Thiago Fernandes"],
            artists=["Thiago Fernandes"],
            documenters=["Thiago Fernandes"],
            comments="A modern DNS lookup tool built with GTK4 and LibAdwaita.\n\n"
                    "Digger provides an intuitive interface for performing DNS queries, "
                    "supporting all common record types including A, AAAA, MX, TXT, NS, "
                    "CNAME, and SOA records. Built following GNOME Human Interface Guidelines "
                    "for a native desktop experience.\n\n"
                    "Features:\n"
                    "• Support for all major DNS record types\n"
                    "• Query history with search and management\n"
                    "• Advanced dig options (reverse DNS, trace, short output)\n"
                    "• Custom nameserver configuration\n"
                    "• Copy-to-clipboard for DNS records\n"
                    "• Modern Blueprint-based UI architecture\n"
                    "• Responsive GTK4/LibAdwaita interface\n"
                    "• Comprehensive error handling\n"
                    "• Keyboard shortcuts for power users",
        )

        # Present the dialog
        about_dialog.present()

    def _on_quit_action(self, action, param):
        """Handle quit action.

        Args:
            action: The action that was triggered.
            param: Action parameters.
        """
        # Get all windows and close them
        for window in self.get_windows():
            window.close()

        # Quit the application
        self.quit()

    def do_shutdown(self):
        """Handle application shutdown."""
        # Perform cleanup if needed
        Adw.Application.do_shutdown(self)


def main():
    """Application entry point."""
    # Create application instance
    app = DiggerApplication()

    # Run the application
    try:
        exit_code = app.run(sys.argv)
        return exit_code
    except KeyboardInterrupt:
        print("\nInterrupted by user")
        return 130  # Standard exit code for SIGINT
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
