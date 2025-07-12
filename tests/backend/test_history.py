"""Tests for query history functionality."""

import json
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import patch

import pytest

from digger.backend.history import HistoryEntry, QueryHistory
from digger.backend.models import RecordType


class TestHistoryEntry:
    """Test cases for HistoryEntry class."""

    def test_create_entry(self):
        """Test creating a history entry."""
        timestamp = datetime.now()
        entry = HistoryEntry(
            domain="example.com",
            record_type=RecordType.A,
            nameserver="8.8.8.8",
            timestamp=timestamp,
            status="NOERROR",
            query_time_ms=45,
        )

        assert entry.domain == "example.com"
        assert entry.record_type == RecordType.A
        assert entry.nameserver == "8.8.8.8"
        assert entry.timestamp == timestamp
        assert entry.status == "NOERROR"
        assert entry.query_time_ms == 45

    def test_to_dict(self):
        """Test converting entry to dictionary."""
        timestamp = datetime(2023, 1, 1, 12, 0, 0)
        entry = HistoryEntry(
            domain="test.com",
            record_type=RecordType.MX,
            nameserver=None,
            timestamp=timestamp,
            status="NOERROR",
            query_time_ms=123,
        )

        expected = {
            "domain": "test.com",
            "record_type": "MX",
            "nameserver": None,
            "timestamp": "2023-01-01T12:00:00",
            "status": "NOERROR",
            "query_time_ms": 123,
        }

        assert entry.to_dict() == expected

    def test_from_dict(self):
        """Test creating entry from dictionary."""
        data = {
            "domain": "test.com",
            "record_type": "AAAA",
            "nameserver": "1.1.1.1",
            "timestamp": "2023-01-01T12:00:00",
            "status": "NOERROR",
            "query_time_ms": 87,
        }

        entry = HistoryEntry.from_dict(data)

        assert entry.domain == "test.com"
        assert entry.record_type == RecordType.AAAA
        assert entry.nameserver == "1.1.1.1"
        assert entry.timestamp == datetime(2023, 1, 1, 12, 0, 0)
        assert entry.status == "NOERROR"
        assert entry.query_time_ms == 87

    def test_from_dict_none_values(self):
        """Test creating entry from dictionary with None values."""
        data = {
            "domain": "test.com",
            "record_type": "A",
            "nameserver": None,
            "timestamp": "2023-01-01T12:00:00",
            "status": "NXDOMAIN",
            "query_time_ms": None,
        }

        entry = HistoryEntry.from_dict(data)

        assert entry.domain == "test.com"
        assert entry.record_type == RecordType.A
        assert entry.nameserver is None
        assert entry.timestamp == datetime(2023, 1, 1, 12, 0, 0)
        assert entry.status == "NXDOMAIN"
        assert entry.query_time_ms is None


class TestQueryHistory:
    """Test cases for QueryHistory class."""

    def setup_method(self):
        """Set up test environment."""
        # Create temporary directory for history file
        self.temp_dir = tempfile.mkdtemp()
        self.history_file = Path(self.temp_dir) / "history.json"

        # Patch the history file path
        with patch.object(QueryHistory, "_get_history_file_path") as mock_path:
            mock_path.return_value = self.history_file
            self.history = QueryHistory(max_entries=5)

    def test_empty_history(self):
        """Test empty history state."""
        assert len(self.history.get_entries()) == 0
        assert len(self.history.get_recent_domains()) == 0

    def test_add_entry(self):
        """Test adding a history entry."""
        self.history.add_entry(
            domain="example.com",
            record_type=RecordType.A,
            nameserver="8.8.8.8",
            status="NOERROR",
            query_time_ms=50,
        )

        entries = self.history.get_entries()
        assert len(entries) == 1
        assert entries[0].domain == "example.com"
        assert entries[0].record_type == RecordType.A
        assert entries[0].nameserver == "8.8.8.8"
        assert entries[0].status == "NOERROR"
        assert entries[0].query_time_ms == 50

    def test_multiple_entries_order(self):
        """Test that entries are ordered by timestamp (newest first)."""
        # Add entries with delays to ensure different timestamps
        self.history.add_entry("first.com", RecordType.A, None, "NOERROR")
        self.history.add_entry("second.com", RecordType.MX, None, "NOERROR")
        self.history.add_entry("third.com", RecordType.AAAA, None, "NOERROR")

        entries = self.history.get_entries()
        assert len(entries) == 3
        assert entries[0].domain == "third.com"  # Most recent
        assert entries[1].domain == "second.com"
        assert entries[2].domain == "first.com"  # Oldest

    def test_max_entries_limit(self):
        """Test that history respects max entries limit."""
        # Add more entries than the limit (5)
        for i in range(10):
            self.history.add_entry(f"test{i}.com", RecordType.A, None, "NOERROR")

        entries = self.history.get_entries()
        assert len(entries) == 5  # Should be limited to max_entries

        # Check that we kept the most recent entries
        for i, entry in enumerate(entries):
            expected_domain = f"test{9-i}.com"  # Reverse order (newest first)
            assert entry.domain == expected_domain

    def test_get_entries_with_limit(self):
        """Test getting entries with a limit."""
        for i in range(5):
            self.history.add_entry(f"test{i}.com", RecordType.A, None, "NOERROR")

        # Get limited entries
        entries = self.history.get_entries(limit=3)
        assert len(entries) == 3

        # Should be the most recent 3
        assert entries[0].domain == "test4.com"
        assert entries[1].domain == "test3.com"
        assert entries[2].domain == "test2.com"

    def test_get_recent_domains(self):
        """Test getting recent unique domains."""
        # Add some duplicate domains
        self.history.add_entry("example.com", RecordType.A, None, "NOERROR")
        self.history.add_entry("test.com", RecordType.MX, None, "NOERROR")
        self.history.add_entry("example.com", RecordType.AAAA, None, "NOERROR")  # Duplicate
        self.history.add_entry("another.com", RecordType.TXT, None, "NOERROR")

        recent_domains = self.history.get_recent_domains(limit=10)
        assert len(recent_domains) == 3  # Should be unique
        assert recent_domains == ["another.com", "example.com", "test.com"]

    def test_get_recent_domains_with_limit(self):
        """Test getting recent domains with limit."""
        for i in range(5):
            self.history.add_entry(f"test{i}.com", RecordType.A, None, "NOERROR")

        recent_domains = self.history.get_recent_domains(limit=3)
        assert len(recent_domains) == 3
        assert recent_domains == ["test4.com", "test3.com", "test2.com"]

    def test_clear_history(self):
        """Test clearing all history."""
        # Add some entries
        for i in range(3):
            self.history.add_entry(f"test{i}.com", RecordType.A, None, "NOERROR")

        assert len(self.history.get_entries()) == 3

        # Clear history
        self.history.clear_history()
        assert len(self.history.get_entries()) == 0

    def test_remove_entry(self):
        """Test removing a specific entry."""
        # Add entries
        self.history.add_entry("first.com", RecordType.A, None, "NOERROR")
        self.history.add_entry("second.com", RecordType.MX, None, "NOERROR")
        self.history.add_entry("third.com", RecordType.AAAA, None, "NOERROR")

        # Remove middle entry (index 1)
        result = self.history.remove_entry(1)
        assert result is True

        entries = self.history.get_entries()
        assert len(entries) == 2
        assert entries[0].domain == "third.com"
        assert entries[1].domain == "first.com"  # second.com should be gone

    def test_remove_entry_invalid_index(self):
        """Test removing entry with invalid index."""
        self.history.add_entry("test.com", RecordType.A, None, "NOERROR")

        # Try to remove invalid indices
        assert self.history.remove_entry(-1) is False
        assert self.history.remove_entry(10) is False

        # Entry should still be there
        assert len(self.history.get_entries()) == 1

    def test_search_history(self):
        """Test searching history entries."""
        self.history.add_entry("example.com", RecordType.A, None, "NOERROR")
        self.history.add_entry("test.example.org", RecordType.MX, None, "NOERROR")
        self.history.add_entry("different.com", RecordType.AAAA, None, "NOERROR")
        self.history.add_entry("EXAMPLE.NET", RecordType.TXT, None, "NOERROR")

        # Search for "example" (case insensitive)
        results = self.history.search_history("example")
        assert len(results) == 3
        domains = [entry.domain for entry in results]
        assert "example.com" in domains
        assert "test.example.org" in domains
        assert "EXAMPLE.NET" in domains
        assert "different.com" not in domains

    def test_search_history_no_results(self):
        """Test searching with no matching results."""
        self.history.add_entry("example.com", RecordType.A, None, "NOERROR")

        results = self.history.search_history("notfound")
        assert len(results) == 0

    def test_get_stats_empty(self):
        """Test getting statistics for empty history."""
        stats = self.history.get_stats()
        expected = {
            "total_queries": 0,
            "unique_domains": 0,
            "most_common_type": None,
            "success_rate": 0.0,
        }
        assert stats == expected

    def test_get_stats_with_data(self):
        """Test getting statistics with actual data."""
        # Add various entries
        self.history.add_entry("example.com", RecordType.A, None, "NOERROR")
        self.history.add_entry("test.com", RecordType.A, None, "NOERROR")
        self.history.add_entry("example.com", RecordType.MX, None, "NXDOMAIN")  # Failed
        self.history.add_entry("other.com", RecordType.A, None, "NOERROR")
        self.history.add_entry("test.com", RecordType.AAAA, None, "NOERROR")

        stats = self.history.get_stats()

        assert stats["total_queries"] == 5
        assert stats["unique_domains"] == 3  # example.com, test.com, other.com
        assert stats["most_common_type"] == "A"  # 3 A records vs 1 MX, 1 AAAA
        assert stats["success_rate"] == 80.0  # 4 NOERROR out of 5 total
        assert stats["type_distribution"] == {"A": 3, "MX": 1, "AAAA": 1}

    def test_persistence_save_and_load(self):
        """Test that history is saved and loaded from disk."""
        # Add some entries
        self.history.add_entry("example.com", RecordType.A, "8.8.8.8", "NOERROR", 50)
        self.history.add_entry("test.com", RecordType.MX, None, "NXDOMAIN", None)

        # Verify file was created
        assert self.history_file.exists()

        # Create new history instance (should load from file)
        with patch.object(QueryHistory, "_get_history_file_path") as mock_path:
            mock_path.return_value = self.history_file
            new_history = QueryHistory()

        # Check that entries were loaded
        entries = new_history.get_entries()
        assert len(entries) == 2
        assert entries[0].domain == "test.com"  # Most recent first
        assert entries[1].domain == "example.com"

    def test_persistence_corrupted_file(self):
        """Test handling of corrupted history file."""
        # Create corrupted JSON file
        with open(self.history_file, "w") as f:
            f.write("invalid json content")

        # Should handle corruption gracefully and start fresh
        with patch.object(QueryHistory, "_get_history_file_path") as mock_path:
            mock_path.return_value = self.history_file
            history = QueryHistory()

        assert len(history.get_entries()) == 0

    def test_persistence_missing_file(self):
        """Test handling of missing history file."""
        # Delete the file if it exists
        if self.history_file.exists():
            self.history_file.unlink()

        # Should handle missing file gracefully
        with patch.object(QueryHistory, "_get_history_file_path") as mock_path:
            mock_path.return_value = self.history_file
            history = QueryHistory()

        assert len(history.get_entries()) == 0