"""Widget for displaying and managing query history using Blueprint UI."""

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from pathlib import Path
from typing import Optional

from gi.repository import Adw, GObject, Gtk

from ..backend.history import HistoryEntry, QueryHistory


@Gtk.Template(resource_path="/io/github/tobagin/digger/history_widget.ui")
class HistoryWidget(Adw.Dialog):
    """Dialog for displaying query history using Blueprint UI."""

    __gtype_name__ = "DiggerHistoryWidget"

    # Custom signals
    __gsignals__ = {
        "query-selected": (
            GObject.SignalFlags.RUN_FIRST,
            None,
            (str, str, str),  # domain, record_type, nameserver
        ),
        "history-modified": (
            GObject.SignalFlags.RUN_FIRST,
            None,
            (),
        ),
    }

    # Template widgets
    clear_button: Gtk.Button = Gtk.Template.Child()
    search_entry: Gtk.SearchEntry = Gtk.Template.Child()
    history_list: Gtk.ListBox = Gtk.Template.Child()

    def __init__(self, parent: Gtk.Window, history: QueryHistory):
        """Initialize the history dialog.

        Args:
            parent (Gtk.Window): Parent window.
            history (QueryHistory): Query history manager.
        """
        super().__init__()

        self.history = history
        self.parent_window = parent

        # Load history and update clear button state
        self._load_history()
        self._update_clear_button_state()

    @Gtk.Template.Callback()
    def on_clear_history(self, button):
        """Handle clear all history button click.

        Args:
            button (Gtk.Button): The button that was clicked.
        """
        self._on_clear_history(button)

    @Gtk.Template.Callback()
    def on_search_changed(self, search_entry):
        """Handle search entry text changes.

        Args:
            search_entry (Gtk.SearchEntry): The search entry widget.
        """
        self._on_search_changed(search_entry)

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
            self._update_clear_button_state()
            return

        # Add each entry to the list
        for i, entry in enumerate(entries):
            row = self._create_history_row(entry, i)
            self.history_list.append(row)
        
        # Update clear button state
        self._update_clear_button_state()

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
            status_icon = Gtk.Image.new_from_icon_name("io.github.tobagin.digger-success-symbolic")
            status_icon.set_icon_size(Gtk.IconSize.NORMAL)
            status_icon.add_css_class("success")
        else:
            status_icon = Gtk.Image.new_from_icon_name("io.github.tobagin.digger-error-symbolic")
            status_icon.set_icon_size(Gtk.IconSize.NORMAL)
            status_icon.add_css_class("warning")

        row.add_prefix(status_icon)

        # Add action buttons
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        button_box.set_valign(Gtk.Align.CENTER)

        # Repeat query button
        repeat_button = Gtk.Button()
        repeat_button.set_icon_name("media-playback-start-symbolic")
        repeat_button.set_tooltip_text("Repeat this query")
        repeat_button.add_css_class("flat")
        repeat_button.set_valign(Gtk.Align.CENTER)
        repeat_button.connect("clicked", self._on_repeat_query, entry)
        button_box.append(repeat_button)

        # Delete button
        delete_button = Gtk.Button()
        delete_button.set_icon_name("user-trash-symbolic")
        delete_button.set_tooltip_text("Remove from history")
        delete_button.add_css_class("flat")
        delete_button.set_valign(Gtk.Align.CENTER)
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
            transient_for=self.parent_window,
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
                self._update_clear_button_state()
                # Emit signal to refresh popover
                self.emit("history-modified")

    def _on_clear_history(self, button: Gtk.Button):
        """Handle clear all history button click.

        Args:
            button (Gtk.Button): The button that was clicked.
        """
        # Show confirmation dialog
        dialog = Adw.MessageDialog(
            transient_for=self.parent_window,
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
            self._update_clear_button_state()
            # Emit signal to refresh popover
            self.emit("history-modified")

    def _update_clear_button_state(self):
        """Update the clear button state based on whether there is history."""
        has_history = len(self.history.get_entries()) > 0
        self.clear_button.set_sensitive(has_history)


@Gtk.Template(resource_path="/io/github/tobagin/digger/history_popover.ui")
class HistoryPopover(Gtk.Popover):
    """Compact popover for quick history access using Blueprint UI."""

    __gtype_name__ = "DiggerHistoryPopover"

    # Custom signals
    __gsignals__ = {
        "query-selected": (
            GObject.SignalFlags.RUN_FIRST,
            None,
            (str, str, str),  # domain, record_type, nameserver
        ),
        "view-all-requested": (
            GObject.SignalFlags.RUN_FIRST,
            None,
            (),
        ),
    }

    # Template widgets
    main_box: Gtk.Box = Gtk.Template.Child()
    title: Gtk.Label = Gtk.Template.Child()
    history_list: Gtk.ListBox = Gtk.Template.Child()
    view_all_button: Gtk.Button = Gtk.Template.Child()

    def __init__(self, history: QueryHistory):
        """Initialize the history popover.

        Args:
            history (QueryHistory): Query history manager.
        """
        super().__init__()
        self.history = history

        self._load_recent_entries()

    @Gtk.Template.Callback()
    def on_view_all(self, button):
        """Handle view all button click.

        Args:
            button (Gtk.Button): The button that was clicked.
        """
        self._on_view_all(button)

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
            icon = Gtk.Image.new_from_icon_name("io.github.tobagin.digger-success-symbolic")
            icon.set_icon_size(Gtk.IconSize.NORMAL)
            icon.add_css_class("success")
        else:
            icon = Gtk.Image.new_from_icon_name("io.github.tobagin.digger-error-symbolic")
            icon.set_icon_size(Gtk.IconSize.NORMAL)
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
        self.emit("view-all-requested")
        self.popdown()

    def refresh(self):
        """Refresh the popover content."""
        self._load_recent_entries()