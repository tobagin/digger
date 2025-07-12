"""Widget for displaying and managing query history."""

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from typing import Optional

from gi.repository import Adw, GObject, Gtk

from ..backend.history import HistoryEntry, QueryHistory


class HistoryWidget(Adw.Window):
    """Window for displaying query history."""

    # Custom signals
    __gsignals__ = {
        "query-selected": (
            GObject.SignalFlags.RUN_FIRST,
            None,
            (str, str, str),  # domain, record_type, nameserver
        ),
    }

    def __init__(self, parent: Gtk.Window, history: QueryHistory):
        """Initialize the history window.

        Args:
            parent (Gtk.Window): Parent window.
            history (QueryHistory): Query history manager.
        """
        super().__init__()
        self.set_transient_for(parent)
        self.set_modal(True)
        self.set_default_size(600, 500)
        self.set_title("Query History")

        self.history = history

        # Build UI
        self._build_ui()
        self._load_history()

    def _build_ui(self):
        """Build the user interface."""
        # Create header bar
        header = Adw.HeaderBar()
        header.set_title_widget(Gtk.Label(label="Query History"))

        # Add clear button
        clear_button = Gtk.Button(label="Clear All")
        clear_button.add_css_class("destructive-action")
        clear_button.connect("clicked", self._on_clear_history)
        header.pack_end(clear_button)

        # Create main content
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        # Create search bar
        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_placeholder_text("Search history...")
        self.search_entry.connect("search-changed", self._on_search_changed)

        search_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        search_box.set_margin_top(12)
        search_box.set_margin_bottom(12)
        search_box.set_margin_start(12)
        search_box.set_margin_end(12)
        search_box.append(self.search_entry)

        # Create scrolled window for history list
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_vexpand(True)

        # Create history list
        self.history_list = Gtk.ListBox()
        self.history_list.set_selection_mode(Gtk.SelectionMode.NONE)
        self.history_list.add_css_class("boxed-list")
        self.history_list.set_margin_top(12)
        self.history_list.set_margin_bottom(12)
        self.history_list.set_margin_start(12)
        self.history_list.set_margin_end(12)

        scrolled.set_child(self.history_list)

        # Add widgets to main box
        main_box.append(search_box)
        main_box.append(scrolled)

        # Create toolbar view
        toolbar_view = Adw.ToolbarView()
        toolbar_view.add_top_bar(header)
        toolbar_view.set_content(main_box)

        # Set as window content
        self.set_content(toolbar_view)

    def _load_history(self, filter_query: Optional[str] = None):
        """Load history entries into the list.

        Args:
            filter_query (Optional[str]): Optional search query to filter entries.
        """
        # Clear existing entries
        child = self.history_list.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            self.history_list.remove(child)
            child = next_child

        # Get entries (filtered if needed)
        if filter_query:
            entries = self.history.search_history(filter_query)
        else:
            entries = self.history.get_entries()

        # Show empty state if no entries
        if not entries:
            self._show_empty_state(bool(filter_query))
            return

        # Add each entry to the list
        for i, entry in enumerate(entries):
            row = self._create_history_row(entry, i)
            self.history_list.append(row)

    def _show_empty_state(self, is_search: bool = False):
        """Show empty state when no history entries are found.

        Args:
            is_search (bool): Whether this is empty due to search or no history.
        """
        empty_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        empty_box.set_valign(Gtk.Align.CENTER)
        empty_box.set_margin_top(48)
        empty_box.set_margin_bottom(48)

        # Icon
        icon_name = "edit-find-symbolic" if is_search else "view-list-symbolic"
        icon = Gtk.Image.new_from_icon_name(icon_name)
        icon.set_pixel_size(64)
        icon.add_css_class("dim-label")
        empty_box.append(icon)

        # Title
        title_text = "No matching queries" if is_search else "No queries yet"
        title = Gtk.Label(label=title_text)
        title.add_css_class("title-2")
        title.add_css_class("dim-label")
        empty_box.append(title)

        # Subtitle
        subtitle_text = (
            "Try a different search term"
            if is_search
            else "Your DNS query history will appear here"
        )
        subtitle = Gtk.Label(label=subtitle_text)
        subtitle.add_css_class("dim-label")
        empty_box.append(subtitle)

        self.history_list.append(empty_box)

    def _create_history_row(self, entry: HistoryEntry, index: int) -> Gtk.Widget:
        """Create a row for a history entry.

        Args:
            entry (HistoryEntry): History entry to display.
            index (int): Index of the entry in the list.

        Returns:
            Gtk.Widget: Widget containing the history entry.
        """
        row = Adw.ActionRow()

        # Format the title
        nameserver_text = f" via {entry.nameserver}" if entry.nameserver else ""
        title = f"{entry.domain} ({entry.record_type.value}){nameserver_text}"
        row.set_title(title)

        # Format the subtitle with timestamp and status
        time_str = entry.timestamp.strftime("%Y-%m-%d %H:%M:%S")
        query_time_str = f" • {entry.query_time_ms}ms" if entry.query_time_ms else ""
        subtitle = f"{time_str} • {entry.status}{query_time_str}"
        row.set_subtitle(subtitle)

        # Add status icon
        if entry.status == "NOERROR":
            status_icon = Gtk.Image.new_from_icon_name("emblem-ok-symbolic")
            status_icon.add_css_class("success")
        else:
            status_icon = Gtk.Image.new_from_icon_name("dialog-warning-symbolic")
            status_icon.add_css_class("warning")

        row.add_prefix(status_icon)

        # Add action buttons
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)

        # Repeat query button
        repeat_button = Gtk.Button()
        repeat_button.set_icon_name("media-playback-start-symbolic")
        repeat_button.set_tooltip_text("Repeat this query")
        repeat_button.add_css_class("flat")
        repeat_button.connect("clicked", self._on_repeat_query, entry)
        button_box.append(repeat_button)

        # Delete button
        delete_button = Gtk.Button()
        delete_button.set_icon_name("user-trash-symbolic")
        delete_button.set_tooltip_text("Remove from history")
        delete_button.add_css_class("flat")
        delete_button.connect("clicked", self._on_delete_entry, index)
        button_box.append(delete_button)

        row.add_suffix(button_box)

        return row

    def _on_search_changed(self, search_entry: Gtk.SearchEntry):
        """Handle search entry text changes.

        Args:
            search_entry (Gtk.SearchEntry): The search entry widget.
        """
        query = search_entry.get_text().strip()
        self._load_history(query if query else None)

    def _on_repeat_query(self, button: Gtk.Button, entry: HistoryEntry):
        """Handle repeat query button click.

        Args:
            button (Gtk.Button): The button that was clicked.
            entry (HistoryEntry): The history entry to repeat.
        """
        nameserver = entry.nameserver or ""
        self.emit("query-selected", entry.domain, entry.record_type.value, nameserver)
        self.close()

    def _on_delete_entry(self, button: Gtk.Button, index: int):
        """Handle delete entry button click.

        Args:
            button (Gtk.Button): The button that was clicked.
            index (int): Index of the entry to delete.
        """
        # Show confirmation dialog
        dialog = Adw.MessageDialog(
            transient_for=self,
            heading="Remove from History?",
            body="This query will be permanently removed from your history.",
        )
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("remove", "Remove")
        dialog.set_response_appearance("remove", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.set_default_response("cancel")
        dialog.set_close_response("cancel")

        dialog.connect("response", self._on_delete_confirm, index)
        dialog.present()

    def _on_delete_confirm(self, dialog: Adw.MessageDialog, response: str, index: int):
        """Handle delete confirmation dialog response.

        Args:
            dialog (Adw.MessageDialog): The confirmation dialog.
            response (str): The user's response.
            index (int): Index of the entry to delete.
        """
        if response == "remove":
            if self.history.remove_entry(index):
                # Reload the history list
                current_search = self.search_entry.get_text().strip()
                self._load_history(current_search if current_search else None)

    def _on_clear_history(self, button: Gtk.Button):
        """Handle clear all history button click.

        Args:
            button (Gtk.Button): The button that was clicked.
        """
        # Show confirmation dialog
        dialog = Adw.MessageDialog(
            transient_for=self,
            heading="Clear All History?",
            body="This will permanently remove all queries from your history. "
            "This action cannot be undone.",
        )
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("clear", "Clear All")
        dialog.set_response_appearance("clear", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.set_default_response("cancel")
        dialog.set_close_response("cancel")

        dialog.connect("response", self._on_clear_confirm)
        dialog.present()

    def _on_clear_confirm(self, dialog: Adw.MessageDialog, response: str):
        """Handle clear all confirmation dialog response.

        Args:
            dialog (Adw.MessageDialog): The confirmation dialog.
            response (str): The user's response.
        """
        if response == "clear":
            self.history.clear_history()
            self._load_history()


class HistoryPopover(Gtk.Popover):
    """Compact popover for quick history access."""

    # Custom signals
    __gsignals__ = {
        "query-selected": (
            GObject.SignalFlags.RUN_FIRST,
            None,
            (str, str, str),  # domain, record_type, nameserver
        ),
    }

    def __init__(self, history: QueryHistory):
        """Initialize the history popover.

        Args:
            history (QueryHistory): Query history manager.
        """
        super().__init__()
        self.history = history
        self.set_position(Gtk.PositionType.BOTTOM)

        self._build_ui()
        self._load_recent_entries()

    def _build_ui(self):
        """Build the popover UI."""
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        main_box.set_margin_top(6)
        main_box.set_margin_bottom(6)
        main_box.set_margin_start(6)
        main_box.set_margin_end(6)

        # Title
        title = Gtk.Label(label="Recent Queries")
        title.add_css_class("heading")
        title.set_halign(Gtk.Align.START)
        main_box.append(title)

        # Separator
        separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        main_box.append(separator)

        # History list
        self.history_list = Gtk.ListBox()
        self.history_list.set_selection_mode(Gtk.SelectionMode.NONE)
        self.history_list.add_css_class("boxed-list")

        main_box.append(self.history_list)

        # View all button
        view_all_button = Gtk.Button(label="View All History...")
        view_all_button.add_css_class("flat")
        view_all_button.connect("clicked", self._on_view_all)
        main_box.append(view_all_button)

        self.set_child(main_box)

    def _load_recent_entries(self):
        """Load recent history entries."""
        # Clear existing entries
        child = self.history_list.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            self.history_list.remove(child)
            child = next_child

        # Get recent entries (limit to 5 for popover)
        entries = self.history.get_entries(limit=5)

        if not entries:
            # Show empty message
            empty_row = Adw.ActionRow()
            empty_row.set_title("No recent queries")
            empty_row.set_sensitive(False)
            self.history_list.append(empty_row)
            return

        # Add each entry
        for entry in entries:
            row = self._create_compact_row(entry)
            self.history_list.append(row)

    def _create_compact_row(self, entry: HistoryEntry) -> Gtk.Widget:
        """Create a compact row for popover display.

        Args:
            entry (HistoryEntry): History entry to display.

        Returns:
            Gtk.Widget: Compact row widget.
        """
        row = Adw.ActionRow()

        # Format title
        title = f"{entry.domain} ({entry.record_type.value})"
        row.set_title(title)

        # Format subtitle
        time_str = entry.timestamp.strftime("%H:%M")
        subtitle = f"{time_str} • {entry.status}"
        row.set_subtitle(subtitle)

        # Add status icon
        if entry.status == "NOERROR":
            icon = Gtk.Image.new_from_icon_name("emblem-ok-symbolic")
            icon.add_css_class("success")
        else:
            icon = Gtk.Image.new_from_icon_name("dialog-warning-symbolic")
            icon.add_css_class("warning")

        row.add_prefix(icon)

        # Make row clickable
        row.set_activatable(True)
        row.connect("activated", self._on_row_activated, entry)

        return row

    def _on_row_activated(self, row: Adw.ActionRow, entry: HistoryEntry):
        """Handle row activation (click).

        Args:
            row (Adw.ActionRow): The activated row.
            entry (HistoryEntry): The associated history entry.
        """
        nameserver = entry.nameserver or ""
        self.emit("query-selected", entry.domain, entry.record_type.value, nameserver)
        self.popdown()

    def _on_view_all(self, button: Gtk.Button):
        """Handle view all button click.

        Args:
            button (Gtk.Button): The button that was clicked.
        """
        # This signal will be handled by the main window to open the full history window
        self.popdown()

    def refresh(self):
        """Refresh the popover content."""
        self._load_recent_entries()