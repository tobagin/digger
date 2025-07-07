"""Pydantic models for DNS record data."""

from datetime import datetime
from enum import Enum
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator


class RecordType(str, Enum):
    """Supported DNS record types."""

    A = "A"
    AAAA = "AAAA"
    CNAME = "CNAME"
    MX = "MX"
    NS = "NS"
    SOA = "SOA"
    TXT = "TXT"


class DNSRecord(BaseModel):
    """Base model for DNS records."""

    name: str
    ttl: int
    record_class: str = Field(default="IN")
    record_type: RecordType
    value: str

    @field_validator("name", "value")
    @classmethod
    def strip_trailing_dot(cls, v: str) -> str:
        """Remove trailing dots from domain names.

        Args:
            v (str): Domain name string that may have trailing dots.

        Returns:
            str: Domain name with trailing dots removed.
        """
        return v.rstrip(".")

    @field_validator("ttl")
    @classmethod
    def validate_ttl(cls, v: int) -> int:
        """Validate TTL is non-negative.

        Args:
            v (int): TTL value to validate.

        Returns:
            int: Validated TTL value.

        Raises:
            ValueError: If TTL is negative.
        """
        if v < 0:
            raise ValueError("TTL must be non-negative")
        return v


class MXRecord(DNSRecord):
    """MX record with priority and mail server."""

    record_type: Literal[RecordType.MX] = RecordType.MX
    priority: int
    mail_server: str

    @field_validator("priority")
    @classmethod
    def validate_priority(cls, v: int) -> int:
        """Validate MX priority is non-negative.

        Args:
            v (int): Priority value to validate.

        Returns:
            int: Validated priority value.

        Raises:
            ValueError: If priority is negative.
        """
        if v < 0:
            raise ValueError("MX priority must be non-negative")
        return v

    @field_validator("mail_server")
    @classmethod
    def strip_mail_server_dot(cls, v: str) -> str:
        """Remove trailing dots from mail server domain.

        Args:
            v (str): Mail server domain that may have trailing dots.

        Returns:
            str: Mail server domain with trailing dots removed.
        """
        return v.rstrip(".")


class DigResponse(BaseModel):
    """Complete dig command response with all sections."""

    query_domain: str
    query_type: RecordType
    query_time: datetime
    server: Optional[str] = None
    query_time_ms: Optional[int] = None
    status: str = "NOERROR"  # NOERROR, NXDOMAIN, SERVFAIL, etc.
    answer_section: list[DNSRecord] = Field(default_factory=list)
    authority_section: list[DNSRecord] = Field(default_factory=list)
    additional_section: list[DNSRecord] = Field(default_factory=list)

    @field_validator("query_domain")
    @classmethod
    def strip_query_domain_dot(cls, v: str) -> str:
        """Remove trailing dots from query domain.

        Args:
            v (str): Query domain that may have trailing dots.

        Returns:
            str: Query domain with trailing dots removed.
        """
        return v.rstrip(".")

    @field_validator("query_time_ms")
    @classmethod
    def validate_query_time_ms(cls, v: Optional[int]) -> Optional[int]:
        """Validate query time is non-negative if provided.

        Args:
            v (Optional[int]): Query time in milliseconds.

        Returns:
            Optional[int]: Validated query time.

        Raises:
            ValueError: If query time is negative.
        """
        if v is not None and v < 0:
            raise ValueError("Query time must be non-negative")
        return v

    @field_validator("server")
    @classmethod
    def strip_server_info(cls, v: Optional[str]) -> Optional[str]:
        """Clean up server information by removing extra whitespace.

        Args:
            v (Optional[str]): Server information string.

        Returns:
            Optional[str]: Cleaned server information.
        """
        if v is not None:
            return v.strip()
        return v

    @property
    def total_records(self) -> int:
        """Get total number of records in all sections.

        Returns:
            int: Total number of records.
        """
        return (
            len(self.answer_section)
            + len(self.authority_section)
            + len(self.additional_section)
        )

    @property
    def has_answer(self) -> bool:
        """Check if response has any answer records.

        Returns:
            bool: True if there are answer records.
        """
        return len(self.answer_section) > 0

    @property
    def is_successful(self) -> bool:
        """Check if the DNS query was successful.

        Returns:
            bool: True if status is NOERROR.
        """
        return self.status == "NOERROR"
