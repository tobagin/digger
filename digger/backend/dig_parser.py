"""Parse dig command output into structured data."""

import re
from datetime import datetime
from typing import Optional

from .models import DigResponse, DNSRecord, MXRecord, RecordType


class DigParser:
    """Parse dig command output into structured data models."""

    def __init__(self) -> None:
        """Initialize the dig parser with regex patterns."""
        # Pattern for DNS records: name ttl class type value
        self.record_pattern = re.compile(r"^(\S+)\s+(\d+)\s+(IN|CH|HS)\s+(\w+)\s+(.+)$")

        # Pattern for extracting status from header
        self.status_pattern = re.compile(r"status:\s*(\w+)")

        # Pattern for extracting query time
        self.query_time_pattern = re.compile(r"Query time:\s*(\d+)\s*msec")

        # Pattern for extracting server information
        self.server_pattern = re.compile(r"SERVER:\s*([^#\s]+)")

        # Pattern for extracting command line
        self.command_pattern = re.compile(r"^\s*;;\s*WHEN:\s*(.+)$")

        # Section header patterns
        self.answer_section_pattern = re.compile(r"^\s*;;\s*ANSWER SECTION:\s*$")
        self.authority_section_pattern = re.compile(r"^\s*;;\s*AUTHORITY SECTION:\s*$")
        self.additional_section_pattern = re.compile(
            r"^\s*;;\s*ADDITIONAL SECTION:\s*$"
        )

    def parse(self, output: str, domain: str, record_type: str) -> DigResponse:
        """Parse complete dig output into structured response.

        Args:
            output (str): Raw dig command output.
            domain (str): Domain name that was queried.
            record_type (str): Record type that was queried.

        Returns:
            DigResponse: Structured response containing all parsed data.
        """
        if not output or not output.strip():
            return DigResponse(
                query_domain=domain,
                query_type=self._parse_record_type(record_type),
                query_time=datetime.now(),
                status="NODATA",
            )

        lines = output.strip().split("\n")

        # Extract metadata from the output
        status = self._extract_status(output)
        query_time_ms = self._extract_query_time(output)
        server = self._extract_server(output)

        # Parse sections
        answer_section = []
        authority_section = []
        additional_section = []
        current_section = None

        for line in lines:
            line = line.strip()

            # Skip empty lines
            if not line:
                continue

            # Skip comments that are not section headers
            if line.startswith(";") and "SECTION:" not in line:
                continue

            # Detect section headers
            if self.answer_section_pattern.match(line):
                current_section = "answer"
                continue
            elif self.authority_section_pattern.match(line):
                current_section = "authority"
                continue
            elif self.additional_section_pattern.match(line):
                current_section = "additional"
                continue

            # Parse record line if we're in a section
            if current_section:
                record = self._parse_record_line(line)
                if record:
                    if current_section == "answer":
                        answer_section.append(record)
                    elif current_section == "authority":
                        authority_section.append(record)
                    elif current_section == "additional":
                        additional_section.append(record)

        return DigResponse(
            query_domain=domain,
            query_type=self._parse_record_type(record_type),
            query_time=datetime.now(),
            server=server,
            query_time_ms=query_time_ms,
            status=status,
            answer_section=answer_section,
            authority_section=authority_section,
            additional_section=additional_section,
        )

    def _parse_record_line(self, line: str) -> Optional[DNSRecord]:
        """Parse a single DNS record line.

        Args:
            line (str): Single line from dig output containing a DNS record.

        Returns:
            Optional[DNSRecord]: Parsed DNS record or None if parsing fails.
        """
        match = self.record_pattern.match(line)
        if not match:
            return None

        name, ttl, record_class, record_type, value = match.groups()

        try:
            # Handle MX records specially
            if record_type == "MX":
                return self._parse_mx_record(name, ttl, record_class, value)

            # Handle generic records
            return DNSRecord(
                name=name,
                ttl=int(ttl),
                record_class=record_class,
                record_type=RecordType(record_type),
                value=value,
            )
        except (ValueError, KeyError):
            # Unknown record type or invalid data
            return None

    def _parse_mx_record(
        self, name: str, ttl: str, record_class: str, value: str
    ) -> Optional[MXRecord]:
        """Parse MX record with priority and mail server.

        Args:
            name (str): Record name.
            ttl (str): TTL value as string.
            record_class (str): Record class (usually IN).
            value (str): MX record value containing priority and server.

        Returns:
            Optional[MXRecord]: Parsed MX record or None if parsing fails.
        """
        parts = value.split(None, 1)
        if len(parts) != 2:
            return None

        try:
            priority_str, mail_server = parts
            priority = int(priority_str)

            return MXRecord(
                name=name,
                ttl=int(ttl),
                record_class=record_class,
                priority=priority,
                mail_server=mail_server,
                value=value,
            )
        except ValueError:
            return None

    def _extract_status(self, output: str) -> str:
        """Extract status from dig output.

        Args:
            output (str): Raw dig output.

        Returns:
            str: Status code (NOERROR, NXDOMAIN, SERVFAIL, etc.).
        """
        match = self.status_pattern.search(output)
        if match:
            return match.group(1)

        # Default status if not found
        return "NOERROR"

    def _extract_query_time(self, output: str) -> Optional[int]:
        """Extract query time from dig output.

        Args:
            output (str): Raw dig output.

        Returns:
            Optional[int]: Query time in milliseconds or None if not found.
        """
        match = self.query_time_pattern.search(output)
        if match:
            try:
                return int(match.group(1))
            except ValueError:
                return None
        return None

    def _extract_server(self, output: str) -> Optional[str]:
        """Extract server information from dig output.

        Args:
            output (str): Raw dig output.

        Returns:
            Optional[str]: Server address or None if not found.
        """
        match = self.server_pattern.search(output)
        if match:
            server = match.group(1)
            # Remove port information if present
            if "#" in server:
                server = server.split("#")[0]
            return server.strip()
        return None

    def _parse_record_type(self, record_type: str) -> RecordType:
        """Parse record type string into enum.

        Args:
            record_type (str): Record type string.

        Returns:
            RecordType: Parsed record type enum.
        """
        try:
            return RecordType(record_type.upper())
        except ValueError:
            # Default to A record if unknown type
            return RecordType.A

    def validate_domain(self, domain: str) -> bool:
        """Validate if domain name is reasonably formatted.

        Args:
            domain (str): Domain name to validate.

        Returns:
            bool: True if domain appears valid.
        """
        if not domain or not domain.strip():
            return False

        domain = domain.strip()

        # Basic domain validation
        if len(domain) > 253:  # RFC 1035 limit
            return False

        # Check for invalid characters
        if not re.match(r"^[a-zA-Z0-9.-]+$", domain):
            return False

        # Check for consecutive dots
        if ".." in domain:
            return False

        # Check for leading/trailing dots or hyphens
        if (
            domain.startswith(".")
            or domain.endswith(".")
            or domain.startswith("-")
            or domain.endswith("-")
        ):
            return False

        return True

    def get_supported_record_types(self) -> list[str]:
        """Get list of supported DNS record types.

        Returns:
            List[str]: List of supported record type strings.
        """
        return [rt.value for rt in RecordType]
