"""Unit tests for dig executor."""

import subprocess
from unittest.mock import Mock, patch

import pytest

from digger.backend.dig_executor import DigExecutor


class TestDigExecutor:
    """Test dig executor class."""

    def test_init(self):
        """Test executor initialization."""
        executor = DigExecutor()

        # Should initialize with proper flatpak detection
        assert hasattr(executor, "is_flatpak")
        assert isinstance(executor.is_flatpak, bool)
        assert hasattr(executor, "_dig_available")
        assert executor._dig_available is None

    @patch("subprocess.run")
    def test_check_dig_available_success(self, mock_run):
        """Test dig availability check when dig is available."""
        # Mock successful subprocess call
        mock_run.return_value = Mock(returncode=0)

        executor = DigExecutor()
        result = executor.check_dig_available()

        assert result is True
        assert executor._dig_available is True

        # Should call 'which dig' command
        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        assert "which" in args
        assert "dig" in args

    @patch("subprocess.run")
    def test_check_dig_available_failure(self, mock_run):
        """Test dig availability check when dig is not available."""
        # Mock failed subprocess call
        mock_run.side_effect = subprocess.CalledProcessError(1, "which")

        executor = DigExecutor()
        result = executor.check_dig_available()

        assert result is False
        assert executor._dig_available is False

    @patch("subprocess.run")
    def test_check_dig_available_timeout(self, mock_run):
        """Test dig availability check with timeout."""
        # Mock timeout
        mock_run.side_effect = subprocess.TimeoutExpired("which", 5)

        executor = DigExecutor()
        result = executor.check_dig_available()

        assert result is False
        assert executor._dig_available is False

    @patch("pathlib.Path.exists")
    @patch("subprocess.run")
    def test_check_dig_available_flatpak(self, mock_run, mock_exists):
        """Test dig availability check in flatpak environment."""
        # Mock flatpak environment
        mock_exists.return_value = True
        mock_run.return_value = Mock(returncode=0)

        executor = DigExecutor()
        result = executor.check_dig_available()

        assert result is True
        assert executor.is_flatpak is True

        # Should call flatpak-spawn command
        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        assert "flatpak-spawn" in args
        assert "--host" in args
        assert "which" in args
        assert "dig" in args

    def test_execute_dig_without_callback(self):
        """Test that execute_dig requires callback."""
        executor = DigExecutor()

        with pytest.raises(ValueError) as exc_info:
            executor.execute_dig("example.com")

        assert "Callback function is required" in str(exc_info.value)

    def test_execute_dig_empty_domain(self):
        """Test execute_dig with empty domain."""
        executor = DigExecutor()
        callback = Mock()

        executor.execute_dig("", callback=callback)

        # Should call callback with error
        callback.assert_called_once()
        args = callback.call_args[0]
        assert args[0] == ""  # Empty output
        assert isinstance(args[1], ValueError)
        assert "Domain name cannot be empty" in str(args[1])

    def test_execute_dig_whitespace_domain(self):
        """Test execute_dig with whitespace-only domain."""
        executor = DigExecutor()
        callback = Mock()

        executor.execute_dig("   ", callback=callback)

        # Should call callback with error
        callback.assert_called_once()
        args = callback.call_args[0]
        assert args[0] == ""  # Empty output
        assert isinstance(args[1], ValueError)
        assert "Domain name cannot be empty" in str(args[1])

    @patch("threading.Thread")
    def test_execute_dig_creates_thread(self, mock_thread):
        """Test that execute_dig creates a background thread."""
        executor = DigExecutor()
        callback = Mock()

        executor.execute_dig("example.com", callback=callback)

        # Should create a thread
        mock_thread.assert_called_once()

        # Check thread arguments
        args, kwargs = mock_thread.call_args
        assert kwargs['target'] == executor._execute_in_thread
        assert kwargs["daemon"] is True

        # Check that thread.start() was called
        mock_thread.return_value.start.assert_called_once()

    def test_build_command_basic(self):
        """Test building basic dig command."""
        executor = DigExecutor()

        cmd = executor._build_command("example.com", "A", None)

        expected = [
            "dig",
            "example.com",
            "A",
            "+noall",
            "+answer",
            "+authority",
            "+additional",
            "+stats",
            "+comments",
            "+cmd",
        ]
        assert cmd == expected

    def test_build_command_with_nameserver(self):
        """Test building dig command with nameserver."""
        executor = DigExecutor()

        cmd = executor._build_command("example.com", "A", "8.8.8.8")

        expected = [
            "dig",
            "@8.8.8.8",
            "example.com",
            "A",
            "+noall",
            "+answer",
            "+authority",
            "+additional",
            "+stats",
            "+comments",
            "+cmd",
        ]
        assert cmd == expected

    def test_build_command_with_nameserver_whitespace(self):
        """Test building dig command with nameserver containing whitespace."""
        executor = DigExecutor()

        cmd = executor._build_command("example.com", "A", "  8.8.8.8  ")

        expected = [
            "dig",
            "@8.8.8.8",
            "example.com",
            "A",
            "+noall",
            "+answer",
            "+authority",
            "+additional",
            "+stats",
            "+comments",
            "+cmd",
        ]
        assert cmd == expected

    @patch("pathlib.Path.exists")
    def test_build_command_flatpak(self, mock_exists):
        """Test building dig command in flatpak environment."""
        # Mock flatpak environment
        mock_exists.return_value = True

        executor = DigExecutor()
        cmd = executor._build_command("example.com", "A", None)

        expected = [
            "flatpak-spawn",
            "--host",
            "dig",
            "example.com",
            "A",
            "+noall",
            "+answer",
            "+authority",
            "+additional",
            "+stats",
            "+comments",
            "+cmd",
        ]
        assert cmd == expected

    @patch("subprocess.run")
    def test_execute_dig_sync_success(self, mock_run):
        """Test synchronous dig execution success."""
        # Mock successful subprocess call
        mock_run.return_value = Mock(returncode=0, stdout="dig output", stderr="")

        executor = DigExecutor()
        executor._dig_available = True  # Mock dig as available

        output, error = executor.execute_dig_sync("example.com", "A")

        assert output == "dig output"
        assert error is None

        # Check subprocess call
        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        assert "dig" in args
        assert "example.com" in args
        assert "A" in args

    @patch("subprocess.run")
    def test_execute_dig_sync_failure(self, mock_run):
        """Test synchronous dig execution failure."""
        # Mock failed subprocess call
        mock_run.return_value = Mock(returncode=1, stdout="", stderr="dig error")

        executor = DigExecutor()
        executor._dig_available = True  # Mock dig as available

        output, error = executor.execute_dig_sync("example.com", "A")

        assert output == ""
        assert error is not None
        assert "dig command failed" in str(error)
        assert "dig error" in str(error)

    @patch("subprocess.run")
    def test_execute_dig_sync_timeout(self, mock_run):
        """Test synchronous dig execution timeout."""
        # Mock timeout
        mock_run.side_effect = subprocess.TimeoutExpired("dig", 30)

        executor = DigExecutor()
        executor._dig_available = True  # Mock dig as available

        output, error = executor.execute_dig_sync("example.com", "A")

        assert output == ""
        assert error is not None
        assert isinstance(error, TimeoutError)
        assert "timed out" in str(error)

    @patch("subprocess.run")
    def test_execute_dig_sync_dig_not_available(self, mock_run):
        """Test synchronous dig execution when dig is not available."""
        executor = DigExecutor()
        executor._dig_available = False  # Mock dig as not available

        output, error = executor.execute_dig_sync("example.com", "A")

        assert output == ""
        assert error is not None
        assert "not available" in str(error)

        # Should not call subprocess
        mock_run.assert_not_called()

    @patch("subprocess.run")
    def test_execute_dig_sync_with_parameters(self, mock_run):
        """Test synchronous dig execution with various parameters."""
        # Mock successful subprocess call
        mock_run.return_value = Mock(returncode=0, stdout="dig output", stderr="")

        executor = DigExecutor()
        executor._dig_available = True  # Mock dig as available

        output, error = executor.execute_dig_sync(
            "example.com", "MX", "8.8.8.8", timeout=60
        )

        assert output == "dig output"
        assert error is None

        # Check subprocess call arguments
        mock_run.assert_called_once()
        args, kwargs = mock_run.call_args

        # Check command
        cmd = args[0]
        assert "dig" in cmd
        assert "@8.8.8.8" in cmd
        assert "example.com" in cmd
        assert "MX" in cmd

        # Check timeout
        assert kwargs["timeout"] == 60

    def test_get_system_info(self):
        """Test getting system information."""
        executor = DigExecutor()

        info = executor.get_system_info()

        assert isinstance(info, dict)
        assert "is_flatpak" in info
        assert "dig_available" in info
        assert "flatpak_info_exists" in info
        assert isinstance(info["is_flatpak"], bool)
        assert isinstance(info["dig_available"], bool)
        assert isinstance(info["flatpak_info_exists"], bool)

    @patch("subprocess.run")
    def test_execute_in_thread_success(self, mock_run):
        """Test background thread execution success."""
        # Mock successful subprocess call
        mock_run.return_value = Mock(returncode=0, stdout="dig output", stderr="")

        executor = DigExecutor()
        executor._dig_available = True  # Mock dig as available
        callback = Mock()

        # Execute in thread
        executor._execute_in_thread("example.com", "A", None, callback)

        # Should call callback with success
        callback.assert_called_once()
        args = callback.call_args[0]
        assert args[0] == "dig output"
        assert args[1] is None

    @patch("subprocess.run")
    def test_execute_in_thread_failure(self, mock_run):
        """Test background thread execution failure."""
        # Mock failed subprocess call
        mock_run.side_effect = RuntimeError("Test error")

        executor = DigExecutor()
        executor._dig_available = True  # Mock dig as available
        callback = Mock()

        # Execute in thread
        executor._execute_in_thread("example.com", "A", None, callback)

        # Should call callback with error
        callback.assert_called_once()
        args = callback.call_args[0]
        assert args[0] == ""
        assert isinstance(args[1], RuntimeError)
        assert "Test error" in str(args[1])

    @patch("subprocess.run")
    def test_execute_in_thread_dig_not_available(self, mock_run):
        """Test background thread execution when dig is not available."""
        executor = DigExecutor()
        executor._dig_available = False  # Mock dig as not available
        callback = Mock()

        # Execute in thread
        executor._execute_in_thread("example.com", "A", None, callback)

        # Should call callback with error
        callback.assert_called_once()
        args = callback.call_args[0]
        assert args[0] == ""
        assert isinstance(args[1], RuntimeError)
        assert "not available" in str(args[1])

        # Should not call subprocess
        mock_run.assert_not_called()

    @patch("subprocess.run")
    def test_execute_in_thread_with_stderr_output(self, mock_run):
        """Test background thread execution with stderr but successful stdout."""
        # Mock subprocess call with both stdout and stderr
        mock_run.return_value = Mock(
            returncode=0,
            stdout="dig output with warnings",
            stderr="warning: some warning",
        )

        executor = DigExecutor()
        executor._dig_available = True  # Mock dig as available
        callback = Mock()

        # Execute in thread
        executor._execute_in_thread("example.com", "A", None, callback)

        # Should call callback with success (stdout is not empty)
        callback.assert_called_once()
        args = callback.call_args[0]
        assert args[0] == "dig output with warnings"
        assert args[1] is None
