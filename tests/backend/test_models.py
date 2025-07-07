"""Unit tests for DNS record models."""

from datetime import datetime

import pytest
from pydantic import ValidationError

from digger.backend.models import DigResponse, DNSRecord, MXRecord, RecordType


class TestRecordType:
    """Test DNS record type enum."""

    def test_record_type_values(self):
        """Test that all expected record types are available."""
        expected_types = ["A", "AAAA", "CNAME", "MX", "NS", "SOA", "TXT"]
        actual_types = [rt.value for rt in RecordType]

        assert set(actual_types) == set(expected_types)

    def test_record_type_string_conversion(self):
        """Test record type string conversion."""
        assert RecordType.A == "A"
        assert RecordType.MX == "MX"
        assert RecordType.AAAA.value == "AAAA"


class TestDNSRecord:
    """Test DNS record model."""

    def test_valid_dns_record(self):
        """Test creating a valid DNS record."""
        record = DNSRecord(
            name="example.com", ttl=300, record_type=RecordType.A, value="192.0.2.1"
        )

        assert record.name == "example.com"
        assert record.ttl == 300
        assert record.record_class == "IN"
        assert record.record_type == RecordType.A
        assert record.value == "192.0.2.1"

    def test_dns_record_with_custom_class(self):
        """Test DNS record with custom class."""
        record = DNSRecord(
            name="example.com",
            ttl=300,
            record_class="CH",
            record_type=RecordType.A,
            value="192.0.2.1",
        )

        assert record.record_class == "CH"

    def test_strip_trailing_dots(self):
        """Test that trailing dots are stripped from domain names."""
        record = DNSRecord(
            name="example.com.", ttl=300, record_type=RecordType.A, value="192.0.2.1."
        )

        assert record.name == "example.com"
        assert record.value == "192.0.2.1"

    def test_negative_ttl_validation(self):
        """Test that negative TTL values are rejected."""
        with pytest.raises(ValidationError) as exc_info:
            DNSRecord(
                name="example.com", ttl=-1, record_type=RecordType.A, value="192.0.2.1"
            )

        assert "TTL must be non-negative" in str(exc_info.value)

    def test_zero_ttl_allowed(self):
        """Test that zero TTL is allowed."""
        record = DNSRecord(
            name="example.com", ttl=0, record_type=RecordType.A, value="192.0.2.1"
        )

        assert record.ttl == 0

    def test_dns_record_with_different_types(self):
        """Test DNS records with different record types."""
        # A record
        a_record = DNSRecord(
            name="example.com", ttl=300, record_type=RecordType.A, value="192.0.2.1"
        )
        assert a_record.record_type == RecordType.A

        # AAAA record
        aaaa_record = DNSRecord(
            name="example.com",
            ttl=300,
            record_type=RecordType.AAAA,
            value="2001:db8::1",
        )
        assert aaaa_record.record_type == RecordType.AAAA

        # CNAME record
        cname_record = DNSRecord(
            name="www.example.com",
            ttl=300,
            record_type=RecordType.CNAME,
            value="example.com",
        )
        assert cname_record.record_type == RecordType.CNAME


class TestMXRecord:
    """Test MX record model."""

    def test_valid_mx_record(self):
        """Test creating a valid MX record."""
        mx_record = MXRecord(
            name="example.com",
            ttl=300,
            priority=10,
            mail_server="mail.example.com",
            value="10 mail.example.com",
        )

        assert mx_record.name == "example.com"
        assert mx_record.ttl == 300
        assert mx_record.record_type == RecordType.MX
        assert mx_record.priority == 10
        assert mx_record.mail_server == "mail.example.com"
        assert mx_record.value == "10 mail.example.com"

    def test_mx_record_strips_trailing_dots(self):
        """Test that MX record strips trailing dots from mail server."""
        mx_record = MXRecord(
            name="example.com.",
            ttl=300,
            priority=10,
            mail_server="mail.example.com.",
            value="10 mail.example.com.",
        )

        assert mx_record.name == "example.com"
        assert mx_record.mail_server == "mail.example.com"
        assert mx_record.value == "10 mail.example.com"

    def test_negative_priority_validation(self):
        """Test that negative priority values are rejected."""
        with pytest.raises(ValidationError) as exc_info:
            MXRecord(
                name="example.com",
                ttl=300,
                priority=-1,
                mail_server="mail.example.com",
                value="10 mail.example.com",
            )

        assert "MX priority must be non-negative" in str(exc_info.value)

    def test_zero_priority_allowed(self):
        """Test that zero priority is allowed."""
        mx_record = MXRecord(
            name="example.com",
            ttl=300,
            priority=0,
            mail_server="mail.example.com",
            value="0 mail.example.com",
        )

        assert mx_record.priority == 0

    def test_mx_record_type_is_fixed(self):
        """Test that MX record type is automatically set to MX."""
        mx_record = MXRecord(
            name="example.com",
            ttl=300,
            priority=10,
            mail_server="mail.example.com",
            value="10 mail.example.com",
        )

        assert mx_record.record_type == RecordType.MX


class TestDigResponse:
    """Test dig response model."""

    def test_valid_dig_response(self):
        """Test creating a valid dig response."""
        response = DigResponse(
            query_domain="example.com",
            query_type=RecordType.A,
            query_time=datetime.now(),
        )

        assert response.query_domain == "example.com"
        assert response.query_type == RecordType.A
        assert response.status == "NOERROR"
        assert response.answer_section == []
        assert response.authority_section == []
        assert response.additional_section == []

    def test_dig_response_with_records(self):
        """Test dig response with DNS records."""
        answer_record = DNSRecord(
            name="example.com", ttl=300, record_type=RecordType.A, value="192.0.2.1"
        )

        response = DigResponse(
            query_domain="example.com",
            query_type=RecordType.A,
            query_time=datetime.now(),
            answer_section=[answer_record],
        )

        assert len(response.answer_section) == 1
        assert response.answer_section[0].value == "192.0.2.1"

    def test_dig_response_strips_query_domain_dots(self):
        """Test that query domain dots are stripped."""
        response = DigResponse(
            query_domain="example.com.",
            query_type=RecordType.A,
            query_time=datetime.now(),
        )

        assert response.query_domain == "example.com"

    def test_dig_response_with_server_info(self):
        """Test dig response with server information."""
        response = DigResponse(
            query_domain="example.com",
            query_type=RecordType.A,
            query_time=datetime.now(),
            server="8.8.8.8",
            query_time_ms=45,
        )

        assert response.server == "8.8.8.8"
        assert response.query_time_ms == 45

    def test_negative_query_time_validation(self):
        """Test that negative query time is rejected."""
        with pytest.raises(ValidationError) as exc_info:
            DigResponse(
                query_domain="example.com",
                query_type=RecordType.A,
                query_time=datetime.now(),
                query_time_ms=-1,
            )

        assert "Query time must be non-negative" in str(exc_info.value)

    def test_server_info_whitespace_stripping(self):
        """Test that server info whitespace is stripped."""
        response = DigResponse(
            query_domain="example.com",
            query_type=RecordType.A,
            query_time=datetime.now(),
            server="  8.8.8.8  ",
        )

        assert response.server == "8.8.8.8"

    def test_dig_response_properties(self):
        """Test dig response computed properties."""
        # Response with no records
        empty_response = DigResponse(
            query_domain="example.com",
            query_type=RecordType.A,
            query_time=datetime.now(),
        )

        assert empty_response.total_records == 0
        assert empty_response.has_answer is False
        assert empty_response.is_successful is True

        # Response with records
        answer_record = DNSRecord(
            name="example.com", ttl=300, record_type=RecordType.A, value="192.0.2.1"
        )

        response_with_records = DigResponse(
            query_domain="example.com",
            query_type=RecordType.A,
            query_time=datetime.now(),
            answer_section=[answer_record],
        )

        assert response_with_records.total_records == 1
        assert response_with_records.has_answer is True
        assert response_with_records.is_successful is True

        # Response with error status
        error_response = DigResponse(
            query_domain="nonexistent.com",
            query_type=RecordType.A,
            query_time=datetime.now(),
            status="NXDOMAIN",
        )

        assert error_response.is_successful is False

    def test_dig_response_with_multiple_sections(self):
        """Test dig response with records in multiple sections."""
        answer_record = DNSRecord(
            name="example.com", ttl=300, record_type=RecordType.A, value="192.0.2.1"
        )

        authority_record = DNSRecord(
            name="example.com",
            ttl=3600,
            record_type=RecordType.NS,
            value="ns1.example.com",
        )

        additional_record = DNSRecord(
            name="ns1.example.com",
            ttl=3600,
            record_type=RecordType.A,
            value="192.0.2.10",
        )

        response = DigResponse(
            query_domain="example.com",
            query_type=RecordType.A,
            query_time=datetime.now(),
            answer_section=[answer_record],
            authority_section=[authority_record],
            additional_section=[additional_record],
        )

        assert len(response.answer_section) == 1
        assert len(response.authority_section) == 1
        assert len(response.additional_section) == 1
        assert response.total_records == 3
        assert response.has_answer is True
