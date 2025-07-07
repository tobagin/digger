"""Execute dig commands with proper error handling and threading."""

import subprocess
import threading
from pathlib import Path
from typing import Callable, Optional


class DigExecutor:
    """Execute dig commands with proper error handling and thread management."""

    def __init__(self) -> None:
        """Initialize the dig executor."""
        self.is_flatpak = Path("/.flatpak-info").exists()
        self._dig_available: Optional[bool] = None

    def check_dig_available(self) -> bool:
        """Check if dig command is available on the system.

        Returns:
            bool: True if dig is available, False otherwise.
        """
        if self._dig_available is not None:
            return self._dig_available

        # Try to execute dig with --version to check availability
        # This is more reliable than 'which' in Flatpak environments
        try:
            result = subprocess.run(
                ["dig", "-v"], 
                capture_output=True, 
                timeout=5,
                check=False
            )
            # dig -v returns non-zero exit code but still works if available
            print(f"DEBUG: dig -v result: returncode={result.returncode}, stdout={result.stdout}, stderr={result.stderr}")
            self._dig_available = True
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError) as e:
            print(f"DEBUG: dig check failed with exception: {e}")
            self._dig_available = False

        return self._dig_available

    def execute_dig(
        self,
        domain: str,
        record_type: str = "A",
        nameserver: Optional[str] = None,
        callback: Optional[Callable[[str, Optional[Exception]], None]] = None,
    ) -> None:
        """Execute dig command in background thread.

        Args:
            domain (str): Domain name to query.
            record_type (str): DNS record type to query (A, AAAA, MX, etc.).
            nameserver (Optional[str]): DNS server to use for the query.
            callback (Optional[Callable]): Callback function to handle results.
        """
        if not callback:
            raise ValueError("Callback function is required")

        # Validate inputs
        if not domain or not domain.strip():
            callback("", ValueError("Domain name cannot be empty"))
            return

        domain = domain.strip()
        record_type = record_type.strip().upper()

        # Start background thread
        thread = threading.Thread(
            target=self._execute_in_thread,
            args=(domain, record_type, nameserver, callback),
            daemon=True,
        )
        thread.start()

    def _execute_in_thread(
        self,
        domain: str,
        record_type: str,
        nameserver: Optional[str],
        callback: Callable[[str, Optional[Exception]], None],
    ) -> None:
        """Thread worker for dig execution.

        Args:
            domain (str): Domain name to query.
            record_type (str): DNS record type to query.
            nameserver (Optional[str]): DNS server to use.
            callback (Callable): Callback function to handle results.
        """
        try:
            # Check if dig is available
            if not self.check_dig_available():
                callback("", RuntimeError("dig command is not available"))
                return

            # Build and execute command
            cmd = self._build_command(domain, record_type, nameserver)
            print(f"DEBUG: Executing command: {cmd}")
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30,  # 30 second timeout
                check=False,  # Don't raise exception on non-zero exit code
            )

            print(f"DEBUG: Command result: returncode={result.returncode}, stdout_len={len(result.stdout)}, stderr_len={len(result.stderr)}")
            if result.stderr:
                print(f"DEBUG: stderr content: {result.stderr}")

            # Handle the result
            if result.returncode == 0:
                callback(result.stdout, None)
            else:
                # Even with non-zero exit code, dig might have useful output
                # For example, NXDOMAIN responses still contain useful information
                if result.stdout.strip():
                    callback(result.stdout, None)
                else:
                    error_msg = (
                        result.stderr.strip() if result.stderr else "dig command failed"
                    )
                    # Add more specific error handling for network issues
                    if "network unreachable" in error_msg.lower() or "connection timed out" in error_msg.lower():
                        callback("", RuntimeError("Network connection failed. Please check your internet connection."))
                    else:
                        callback("", RuntimeError(f"dig command failed: {error_msg}"))

        except subprocess.TimeoutExpired:
            callback("", TimeoutError("DNS query timed out. Please check your network connection."))
        except Exception as e:
            callback("", e)

    def _build_command(
        self, domain: str, record_type: str, nameserver: Optional[str]
    ) -> list[str]:
        """Build dig command with appropriate options.

        Args:
            domain (str): Domain name to query.
            record_type (str): DNS record type to query.
            nameserver (Optional[str]): DNS server to use.

        Returns:
            List[str]: Complete command as list of strings.
        """
        base_cmd = ["dig"]

        # Add nameserver if specified
        if nameserver and nameserver.strip():
            base_cmd.append(f"@{nameserver.strip()}")

        # Add domain and record type
        base_cmd.extend([domain, record_type])

        # Add options for structured output
        base_cmd.extend(
            [
                "+noall",  # Turn off all sections
                "+answer",  # Show answer section
                "+authority",  # Show authority section
                "+additional",  # Show additional section
                "+stats",  # Show query statistics
                "+comments",  # Show section comments
                "+cmd",  # Show command line used
            ]
        )

        # Return the command directly (dig is bundled in Flatpak)
        return base_cmd

    def execute_dig_sync(
        self,
        domain: str,
        record_type: str = "A",
        nameserver: Optional[str] = None,
        timeout: int = 30,
    ) -> tuple[str, Optional[Exception]]:
        """Execute dig command synchronously (for testing).

        Args:
            domain (str): Domain name to query.
            record_type (str): DNS record type to query.
            nameserver (Optional[str]): DNS server to use.
            timeout (int): Timeout in seconds.

        Returns:
            tuple[str, Optional[Exception]]: Output and any exception.
        """
        try:
            if not self.check_dig_available():
                return "", RuntimeError("dig command is not available")

            cmd = self._build_command(domain, record_type, nameserver)
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=timeout, check=False
            )

            if result.returncode == 0 or result.stdout.strip():
                return result.stdout, None
            else:
                error_msg = (
                    result.stderr.strip() if result.stderr else "dig command failed"
                )
                return "", RuntimeError(f"dig command failed: {error_msg}")

        except subprocess.TimeoutExpired:
            return "", TimeoutError("DNS query timed out")
        except Exception as e:
            return "", e

    def get_system_info(self) -> dict[str, bool]:
        """Get system information for debugging.

        Returns:
            dict: System information including Flatpak status and dig availability.
        """
        return {
            "is_flatpak": self.is_flatpak,
            "dig_available": self.check_dig_available(),
            "flatpak_info_exists": Path("/.flatpak-info").exists(),
        }
