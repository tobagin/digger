"""Settings dialog for Digger DNS lookup tool using Blueprint UI."""

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

import json
import os
from pathlib import Path
from typing import Any, Dict, Optional

from gi.repository import Adw, GObject, Gtk

from ..backend.history import QueryHistory


class SettingsManager:
    """Manages application settings storage and retrieval."""

    def __init__(self):
        """Initialize the settings manager."""
        self.config_dir = Path.home() / ".config" / "digger"
        self.config_file = self.config_dir / "settings.json"
        self._settings = self._load_settings()

    def _load_settings(self) -> Dict[str, Any]:
        """Load settings from file.
        
        Returns:
            Dict[str, Any]: Settings dictionary with defaults applied.
        """
        defaults = {
            "theme": "follow-system",  # follow-system, light, dark
            "auto_cleanup_enabled": False,
            "cleanup_days": 30,
            "save_queries": True,
            "default_record_type": "A",
            "confirm_clear": True,
            "history_limit": 1000,
            "query_timeout": 10,
        }

        if not self.config_file.exists():
            return defaults

        try:
            with open(self.config_file, "r", encoding="utf-8") as f:
                loaded_settings = json.load(f)
                # Merge with defaults to ensure all keys exist
                defaults.update(loaded_settings)
                return defaults
        except (json.JSONDecodeError, IOError):
            return defaults

    def _save_settings(self):
        """Save current settings to file."""
        try:
            self.config_dir.mkdir(parents=True, exist_ok=True)
            with open(self.config_file, "w", encoding="utf-8") as f:
                json.dump(self._settings, f, indent=2)
        except IOError:
            pass  # Fail silently

    def get(self, key: str, default: Any = None) -> Any:
        """Get a setting value.
        
        Args:
            key (str): Setting key.
            default (Any): Default value if key doesn't exist.
            
        Returns:
            Any: Setting value.
        """
        return self._settings.get(key, default)

    def set(self, key: str, value: Any):
        """Set a setting value.
        
        Args:
            key (str): Setting key.
            value (Any): Setting value.
        """
        self._settings[key] = value
        self._save_settings()

    def get_all(self) -> Dict[str, Any]:
        """Get all settings.
        
        Returns:
            Dict[str, Any]: All settings.
        """
        return self._settings.copy()


@Gtk.Template(resource_path="/io/github/tobagin/digger/settings_dialog.ui")
class SettingsDialog(Adw.PreferencesDialog):
    """Settings preferences dialog for Digger using Blueprint UI."""

    __gtype_name__ = "DiggerSettingsDialog"

    # Template widgets
    theme_row: Adw.ComboRow = Gtk.Template.Child()
    auto_cleanup_row: Adw.SwitchRow = Gtk.Template.Child()
    cleanup_days_row: Adw.SpinRow = Gtk.Template.Child()
    save_queries_row: Adw.SwitchRow = Gtk.Template.Child()
    default_record_type_row: Adw.ComboRow = Gtk.Template.Child()
    confirm_clear_row: Adw.SwitchRow = Gtk.Template.Child()
    history_limit_row: Adw.SpinRow = Gtk.Template.Child()
    timeout_row: Adw.SpinRow = Gtk.Template.Child()

    def __init__(self, parent: Gtk.Window, history: Optional[QueryHistory] = None):
        """Initialize the settings dialog.

        Args:
            parent (Gtk.Window): Parent window.
            history (Optional[QueryHistory]): Query history manager for cleanup operations.
        """
        super().__init__()
        
        self.history = history
        self.settings = SettingsManager()

        # Load current settings into UI
        self._load_current_settings()

        # Connect signals
        self._connect_signals()

    def _load_current_settings(self):
        """Load current settings into the UI widgets."""
        # Theme setting
        theme_value = self.settings.get("theme", "follow-system")
        theme_index = {"follow-system": 0, "dark": 1, "light": 2}.get(theme_value, 0)
        self.theme_row.set_selected(theme_index)

        # Auto-cleanup settings
        auto_cleanup = self.settings.get("auto_cleanup_enabled", False)
        self.auto_cleanup_row.set_active(auto_cleanup)
        self.cleanup_days_row.set_sensitive(auto_cleanup)
        self.cleanup_days_row.set_value(self.settings.get("cleanup_days", 30))

        # Query behavior settings
        self.save_queries_row.set_active(self.settings.get("save_queries", True))
        
        # Default record type
        record_type = self.settings.get("default_record_type", "A")
        record_types = ["A", "AAAA", "CNAME", "MX", "NS", "PTR", "SOA", "TXT"]
        record_index = record_types.index(record_type) if record_type in record_types else 0
        self.default_record_type_row.set_selected(record_index)

        self.confirm_clear_row.set_active(self.settings.get("confirm_clear", True))

        # Advanced settings
        self.history_limit_row.set_value(self.settings.get("history_limit", 1000))
        self.timeout_row.set_value(self.settings.get("query_timeout", 10))

    def _connect_signals(self):
        """Connect widget signals to handlers."""
        # Theme selection
        self.theme_row.connect("notify::selected", self._on_theme_changed)

        # Auto-cleanup settings
        self.auto_cleanup_row.connect("notify::active", self._on_auto_cleanup_toggled)
        self.cleanup_days_row.connect("notify::value", self._on_cleanup_days_changed)

        # Query behavior
        self.save_queries_row.connect("notify::active", self._on_save_queries_toggled)
        self.default_record_type_row.connect("notify::selected", self._on_default_record_type_changed)
        self.confirm_clear_row.connect("notify::active", self._on_confirm_clear_toggled)

        # Advanced settings
        self.history_limit_row.connect("notify::value", self._on_history_limit_changed)
        self.timeout_row.connect("notify::value", self._on_timeout_changed)

    def _on_theme_changed(self, combo_row: Adw.ComboRow, pspec: GObject.ParamSpec):
        """Handle theme selection change.
        
        Args:
            combo_row (Adw.ComboRow): The combo row widget.
            pspec (GObject.ParamSpec): Parameter specification.
        """
        selected = combo_row.get_selected()
        theme_values = ["follow-system", "dark", "light"]
        if 0 <= selected < len(theme_values):
            theme = theme_values[selected]
            self.settings.set("theme", theme)
            self._apply_theme(theme)

    def _apply_theme(self, theme: str):
        """Apply the selected theme.
        
        Args:
            theme (str): Theme to apply ("follow-system", "light", "dark").
        """
        style_manager = Adw.StyleManager.get_default()
        
        if theme == "light":
            style_manager.set_color_scheme(Adw.ColorScheme.FORCE_LIGHT)
        elif theme == "dark":
            style_manager.set_color_scheme(Adw.ColorScheme.FORCE_DARK)
        else:  # follow-system
            style_manager.set_color_scheme(Adw.ColorScheme.DEFAULT)

    def _on_auto_cleanup_toggled(self, switch_row: Adw.SwitchRow, pspec: GObject.ParamSpec):
        """Handle auto-cleanup toggle.
        
        Args:
            switch_row (Adw.SwitchRow): The switch row widget.
            pspec (GObject.ParamSpec): Parameter specification.
        """
        enabled = switch_row.get_active()
        self.settings.set("auto_cleanup_enabled", enabled)
        self.cleanup_days_row.set_sensitive(enabled)

        # If enabling auto-cleanup and we have history, run cleanup now
        if enabled and self.history:
            self._run_auto_cleanup()

    def _on_cleanup_days_changed(self, spin_row: Adw.SpinRow, pspec: GObject.ParamSpec):
        """Handle cleanup days value change.
        
        Args:
            spin_row (Adw.SpinRow): The spin row widget.
            pspec (GObject.ParamSpec): Parameter specification.
        """
        days = int(spin_row.get_value())
        self.settings.set("cleanup_days", days)

    def _on_save_queries_toggled(self, switch_row: Adw.SwitchRow, pspec: GObject.ParamSpec):
        """Handle save queries toggle.
        
        Args:
            switch_row (Adw.SwitchRow): The switch row widget.
            pspec (GObject.ParamSpec): Parameter specification.
        """
        enabled = switch_row.get_active()
        self.settings.set("save_queries", enabled)

    def _on_default_record_type_changed(self, combo_row: Adw.ComboRow, pspec: GObject.ParamSpec):
        """Handle default record type change.
        
        Args:
            combo_row (Adw.ComboRow): The combo row widget.
            pspec (GObject.ParamSpec): Parameter specification.
        """
        selected = combo_row.get_selected()
        record_types = ["A", "AAAA", "CNAME", "MX", "NS", "PTR", "SOA", "TXT"]
        if 0 <= selected < len(record_types):
            record_type = record_types[selected]
            self.settings.set("default_record_type", record_type)

    def _on_confirm_clear_toggled(self, switch_row: Adw.SwitchRow, pspec: GObject.ParamSpec):
        """Handle confirm clear toggle.
        
        Args:
            switch_row (Adw.SwitchRow): The switch row widget.
            pspec (GObject.ParamSpec): Parameter specification.
        """
        enabled = switch_row.get_active()
        self.settings.set("confirm_clear", enabled)

    def _on_history_limit_changed(self, spin_row: Adw.SpinRow, pspec: GObject.ParamSpec):
        """Handle history limit change.
        
        Args:
            spin_row (Adw.SpinRow): The spin row widget.
            pspec (GObject.ParamSpec): Parameter specification.
        """
        limit = int(spin_row.get_value())
        self.settings.set("history_limit", limit)

        # If we have history, enforce the new limit
        if self.history and limit > 0:
            self._enforce_history_limit(limit)

    def _on_timeout_changed(self, spin_row: Adw.SpinRow, pspec: GObject.ParamSpec):
        """Handle timeout change.
        
        Args:
            spin_row (Adw.SpinRow): The spin row widget.
            pspec (GObject.ParamSpec): Parameter specification.
        """
        timeout = int(spin_row.get_value())
        self.settings.set("query_timeout", timeout)

    def _run_auto_cleanup(self):
        """Run auto-cleanup based on current settings."""
        if not self.history:
            return

        cleanup_days = self.settings.get("cleanup_days", 30)
        
        # Use the history's cleanup method if available
        if hasattr(self.history, 'cleanup_old_entries'):
            self.history.cleanup_old_entries(cleanup_days)

    def _enforce_history_limit(self, limit: int):
        """Enforce history limit by removing excess entries.
        
        Args:
            limit (int): Maximum number of entries to keep.
        """
        if not self.history:
            return

        # Use the history's limit enforcement method if available
        if hasattr(self.history, 'enforce_limit'):
            self.history.enforce_limit(limit)

    def get_settings_manager(self) -> SettingsManager:
        """Get the settings manager instance.
        
        Returns:
            SettingsManager: Settings manager instance.
        """
        return self.settings