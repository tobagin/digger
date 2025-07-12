"""Query history management for Digger DNS lookup tool."""

import json
import os
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Optional

from .models import RecordType


@dataclass
class HistoryEntry:
    """Represents a single query history entry."""

    domain: str
    record_type: RecordType
    nameserver: Optional[str]
    timestamp: datetime
    status: str
    query_time_ms: Optional[int]

    @classmethod
    def from_dict(cls, data: dict) -> "HistoryEntry":
        """Create HistoryEntry from dictionary.

        Args:
            data (dict): Dictionary containing entry data.

        Returns:
            HistoryEntry: Created history entry.
        """
        return cls(
            domain=data["domain"],
            record_type=RecordType(data["record_type"]),
            nameserver=data.get("nameserver"),
            timestamp=datetime.fromisoformat(data["timestamp"]),
            status=data["status"],
            query_time_ms=data.get("query_time_ms"),
        )

    def to_dict(self) -> dict:
        """Convert HistoryEntry to dictionary.

        Returns:
            dict: Dictionary representation of the entry.
        """
        return {
            "domain": self.domain,
            "record_type": self.record_type.value,
            "nameserver": self.nameserver,
            "timestamp": self.timestamp.isoformat(),
            "status": self.status,
            "query_time_ms": self.query_time_ms,
        }


class QueryHistory:
    """Manages query history storage and retrieval."""

    def __init__(self, max_entries: int = 100):
        """Initialize query history manager.

        Args:
            max_entries (int): Maximum number of entries to keep.
        """
        self.max_entries = max_entries
        self._entries: List[HistoryEntry] = []
        self._history_file = self._get_history_file_path()
        self._load_history()

    def _get_history_file_path(self) -> Path:
        """Get the path to the history file.

        Returns:
            Path: Path to history file.
        """
        # Use XDG data directory or fallback to ~/.local/share
        data_dir = os.environ.get("XDG_DATA_HOME")
        if not data_dir:
            data_dir = os.path.expanduser("~/.local/share")

        app_dir = Path(data_dir) / "digger"
        app_dir.mkdir(parents=True, exist_ok=True)

        return app_dir / "history.json"

    def _load_history(self):
        """Load history from disk."""
        try:
            if self._history_file.exists():
                with open(self._history_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self._entries = [
                        HistoryEntry.from_dict(entry) for entry in data.get("entries", [])
                    ]
                    # Sort by timestamp (newest first)
                    self._entries.sort(key=lambda x: x.timestamp, reverse=True)
        except (json.JSONDecodeError, KeyError, ValueError) as e:
            # If history file is corrupted, start fresh
            print(f"Warning: Could not load history: {e}")
            self._entries = []

    def _save_history(self):
        """Save history to disk."""
        try:
            data = {"entries": [entry.to_dict() for entry in self._entries]}
            with open(self._history_file, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Warning: Could not save history: {e}")

    def add_entry(
        self,
        domain: str,
        record_type: RecordType,
        nameserver: Optional[str],
        status: str,
        query_time_ms: Optional[int] = None,
    ):
        """Add a new query to the history.

        Args:
            domain (str): Domain that was queried.
            record_type (RecordType): DNS record type.
            nameserver (Optional[str]): DNS server used.
            status (str): Query status (NOERROR, NXDOMAIN, etc.).
            query_time_ms (Optional[int]): Query time in milliseconds.
        """
        # Check if this exact query (domain + record_type + nameserver) exists recently
        # If found within the last 5 minutes, update it instead of creating duplicate
        now = datetime.now()
        recent_threshold = timedelta(minutes=5)
        
        for i, existing_entry in enumerate(self._entries):
            if (
                existing_entry.domain.lower() == domain.lower()
                and existing_entry.record_type == record_type
                and existing_entry.nameserver == nameserver
                and (now - existing_entry.timestamp) < recent_threshold
            ):
                # Update the existing entry with new timestamp and status
                updated_entry = HistoryEntry(
                    domain=domain,
                    record_type=record_type,
                    nameserver=nameserver,
                    timestamp=now,
                    status=status,
                    query_time_ms=query_time_ms,
                )
                # Remove old entry and add updated one at the beginning
                self._entries.pop(i)
                self._entries.insert(0, updated_entry)
                self._save_history()
                return

        # No recent duplicate found, add new entry
        entry = HistoryEntry(
            domain=domain,
            record_type=record_type,
            nameserver=nameserver,
            timestamp=now,
            status=status,
            query_time_ms=query_time_ms,
        )

        # Add to beginning of list
        self._entries.insert(0, entry)

        # Trim to max entries
        if len(self._entries) > self.max_entries:
            self._entries = self._entries[: self.max_entries]

        # Save to disk
        self._save_history()

    def get_entries(self, limit: Optional[int] = None) -> List[HistoryEntry]:
        """Get history entries.

        Args:
            limit (Optional[int]): Maximum number of entries to return.

        Returns:
            List[HistoryEntry]: List of history entries.
        """
        if limit is None:
            return self._entries.copy()
        return self._entries[:limit].copy()

    def get_recent_domains(self, limit: int = 10) -> List[str]:
        """Get list of recently queried domains.

        Args:
            limit (int): Maximum number of domains to return.

        Returns:
            List[str]: List of recent domain names.
        """
        seen_domains = set()
        recent_domains = []

        for entry in self._entries:
            if entry.domain not in seen_domains:
                seen_domains.add(entry.domain)
                recent_domains.append(entry.domain)
                if len(recent_domains) >= limit:
                    break

        return recent_domains

    def clear_history(self):
        """Clear all history entries."""
        self._entries.clear()
        self._save_history()

    def remove_entry(self, index: int) -> bool:
        """Remove a specific history entry.

        Args:
            index (int): Index of entry to remove.

        Returns:
            bool: True if entry was removed, False if index was invalid.
        """
        if 0 <= index < len(self._entries):
            del self._entries[index]
            self._save_history()
            return True
        return False

    def search_history(self, query: str) -> List[HistoryEntry]:
        """Search history for entries matching query.

        Args:
            query (str): Search query (matches domain names).

        Returns:
            List[HistoryEntry]: Matching history entries.
        """
        query_lower = query.lower()
        return [
            entry
            for entry in self._entries
            if query_lower in entry.domain.lower()
        ]

    def get_stats(self) -> dict:
        """Get statistics about query history.

        Returns:
            dict: Statistics about the history.
        """
        if not self._entries:
            return {
                "total_queries": 0,
                "unique_domains": 0,
                "most_common_type": None,
                "success_rate": 0.0,
            }

        # Count record types
        type_counts = {}
        successful_queries = 0
        unique_domains = set()

        for entry in self._entries:
            # Count record types
            type_name = entry.record_type.value
            type_counts[type_name] = type_counts.get(type_name, 0) + 1

            # Count successful queries
            if entry.status == "NOERROR":
                successful_queries += 1

            # Track unique domains
            unique_domains.add(entry.domain)

        # Find most common record type
        most_common_type = max(type_counts, key=type_counts.get) if type_counts else None

        return {
            "total_queries": len(self._entries),
            "unique_domains": len(unique_domains),
            "most_common_type": most_common_type,
            "success_rate": successful_queries / len(self._entries) * 100,
            "type_distribution": type_counts,
        }

    def cleanup_old_entries(self, days_to_keep: int):
        """Remove entries older than specified days.

        Args:
            days_to_keep (int): Number of days to keep entries for.
        """
        if days_to_keep <= 0:
            return

        cutoff_date = datetime.now() - timedelta(days=days_to_keep)
        original_count = len(self._entries)
        
        # Keep only entries newer than cutoff date
        self._entries = [
            entry for entry in self._entries 
            if entry.timestamp > cutoff_date
        ]
        
        # Save if any entries were removed
        if len(self._entries) < original_count:
            self._save_history()

    def enforce_limit(self, max_limit: int):
        """Enforce maximum number of history entries.

        Args:
            max_limit (int): Maximum number of entries to keep (0 = unlimited).
        """
        if max_limit <= 0:
            return

        if len(self._entries) > max_limit:
            self._entries = self._entries[:max_limit]
            self._save_history()

    def set_max_entries(self, max_entries: int):
        """Update the maximum entries limit.

        Args:
            max_entries (int): New maximum entries limit.
        """
        self.max_entries = max_entries
        if max_entries > 0:
            self.enforce_limit(max_entries)