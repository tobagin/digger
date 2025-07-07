"""Unit tests for dig parser."""


from digger.backend.dig_parser import DigParser
from digger.backend.models import MXRecord, RecordType


class TestDigParser:
    """Test dig parser class."""

    def test_init(self):
        """Test parser initialization."""
        parser = DigParser()

        assert hasattr(parser, "record_pattern")
        assert hasattr(parser, "status_pattern")
        assert hasattr(parser, "query_time_pattern")
        assert hasattr(parser, "server_pattern")

    def test_parse_empty_output(self):
        """Test parsing empty output."""
        parser = DigParser()

        response = parser.parse("", "example.com", "A")

        assert response.query_domain == "example.com"
        assert response.query_type == RecordType.A
        assert response.status == "NODATA"
        assert len(response.answer_section) == 0
        assert len(response.authority_section) == 0
        assert len(response.additional_section) == 0

    def test_parse_a_record_response(self):
        """Test parsing standard A record response."""
        output = """;; ANSWER SECTION:
example.com.    300    IN    A    93.184.216.34

;; Query time: 45 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)
;; WHEN: Mon Jan 01 12:00:00 UTC 2024
;; MSG SIZE  rcvd: 56"""

        parser = DigParser()
        response = parser.parse(output, "example.com", "A")

        assert response.status == "NOERROR"
        assert response.query_time_ms == 45
        assert response.server == "8.8.8.8"
        assert len(response.answer_section) == 1
        assert response.answer_section[0].name == "example.com"
        assert response.answer_section[0].ttl == 300
        assert response.answer_section[0].record_type == RecordType.A
        assert response.answer_section[0].value == "93.184.216.34"

    def test_parse_multiple_a_records(self):
        """Test parsing multiple A records."""
        output = """;; ANSWER SECTION:
example.com.    300    IN    A    93.184.216.34
example.com.    300    IN    A    93.184.216.35"""

        parser = DigParser()
        response = parser.parse(output, "example.com", "A")

        assert len(response.answer_section) == 2
        assert response.answer_section[0].value == "93.184.216.34"
        assert response.answer_section[1].value == "93.184.216.35"

    def test_parse_mx_records(self):
        """Test parsing MX records with priority."""
        output = """;; ANSWER SECTION:
example.com.    300    IN    MX    10 mail.example.com.
example.com.    300    IN    MX    20 mail2.example.com."""

        parser = DigParser()
        response = parser.parse(output, "example.com", "MX")

        assert len(response.answer_section) == 2

        # First MX record
        mx1 = response.answer_section[0]
        assert isinstance(mx1, MXRecord)
        assert mx1.priority == 10
        assert mx1.mail_server == "mail.example.com"
        assert mx1.record_type == RecordType.MX

        # Second MX record
        mx2 = response.answer_section[1]
        assert isinstance(mx2, MXRecord)
        assert mx2.priority == 20
        assert mx2.mail_server == "mail2.example.com"

    def test_parse_cname_record(self):
        """Test parsing CNAME record."""
        output = """;; ANSWER SECTION:
www.example.com.    300    IN    CNAME    example.com."""

        parser = DigParser()
        response = parser.parse(output, "www.example.com", "CNAME")

        assert len(response.answer_section) == 1
        record = response.answer_section[0]
        assert record.name == "www.example.com"
        assert record.record_type == RecordType.CNAME
        assert record.value == "example.com"

    def test_parse_aaaa_record(self):
        """Test parsing AAAA record."""
        output = """;; ANSWER SECTION:
example.com.    300    IN    AAAA    2001:db8::1"""

        parser = DigParser()
        response = parser.parse(output, "example.com", "AAAA")

        assert len(response.answer_section) == 1
        record = response.answer_section[0]
        assert record.record_type == RecordType.AAAA
        assert record.value == "2001:db8::1"

    def test_parse_txt_record(self):
        """Test parsing TXT record."""
        output = """;; ANSWER SECTION:
example.com.    300    IN    TXT    "v=spf1 include:_spf.example.com ~all" """

        parser = DigParser()
        response = parser.parse(output, "example.com", "TXT")

        assert len(response.answer_section) == 1
        record = response.answer_section[0]
        assert record.record_type == RecordType.TXT
        assert "spf1" in record.value

    def test_parse_ns_records(self):
        """Test parsing NS records."""
        output = """;; ANSWER SECTION:
example.com.    300    IN    NS    ns1.example.com.
example.com.    300    IN    NS    ns2.example.com."""

        parser = DigParser()
        response = parser.parse(output, "example.com", "NS")

        assert len(response.answer_section) == 2
        assert response.answer_section[0].record_type == RecordType.NS
        assert response.answer_section[0].value == "ns1.example.com"
        assert response.answer_section[1].value == "ns2.example.com"

    def test_parse_soa_record(self):
        """Test parsing SOA record."""
        output = """;; ANSWER SECTION:
example.com.    300    IN    SOA    ns1.example.com. admin.example.com. 2024010101 3600 1800 604800 86400"""

        parser = DigParser()
        response = parser.parse(output, "example.com", "SOA")

        assert len(response.answer_section) == 1
        record = response.answer_section[0]
        assert record.record_type == RecordType.SOA
        assert "ns1.example.com" in record.value
        assert "admin.example.com" in record.value

    def test_parse_nxdomain_response(self):
        """Test parsing NXDOMAIN response."""
        output = """;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 12345
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1"""

        parser = DigParser()
        response = parser.parse(output, "nonexistent.com", "A")

        assert response.status == "NXDOMAIN"
        assert len(response.answer_section) == 0

    def test_parse_servfail_response(self):
        """Test parsing SERVFAIL response."""
        output = """;; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 12345
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 1"""

        parser = DigParser()
        response = parser.parse(output, "example.com", "A")

        assert response.status == "SERVFAIL"
        assert len(response.answer_section) == 0

    def test_parse_multiple_sections(self):
        """Test parsing response with multiple sections."""
        output = """;; ANSWER SECTION:
example.com.    300    IN    A    93.184.216.34

;; AUTHORITY SECTION:
example.com.    3600    IN    NS    ns1.example.com.
example.com.    3600    IN    NS    ns2.example.com.

;; ADDITIONAL SECTION:
ns1.example.com.    3600    IN    A    192.0.2.1
ns2.example.com.    3600    IN    A    192.0.2.2"""

        parser = DigParser()
        response = parser.parse(output, "example.com", "A")

        assert len(response.answer_section) == 1
        assert len(response.authority_section) == 2
        assert len(response.additional_section) == 2

        # Check answer section
        assert response.answer_section[0].record_type == RecordType.A
        assert response.answer_section[0].value == "93.184.216.34"

        # Check authority section
        assert response.authority_section[0].record_type == RecordType.NS
        assert response.authority_section[0].value == "ns1.example.com"

        # Check additional section
        assert response.additional_section[0].record_type == RecordType.A
        assert response.additional_section[0].value == "192.0.2.1"

    def test_parse_record_line_valid(self):
        """Test parsing a valid record line."""
        parser = DigParser()

        record = parser._parse_record_line("example.com. 300 IN A 93.184.216.34")

        assert record is not None
        assert record.name == "example.com"
        assert record.ttl == 300
        assert record.record_class == "IN"
        assert record.record_type == RecordType.A
        assert record.value == "93.184.216.34"

    def test_parse_record_line_invalid(self):
        """Test parsing an invalid record line."""
        parser = DigParser()

        # Invalid format
        record = parser._parse_record_line("invalid line format")
        assert record is None

        # Comment line
        record = parser._parse_record_line(";; This is a comment")
        assert record is None

        # Empty line
        record = parser._parse_record_line("")
        assert record is None

    def test_parse_mx_record_line(self):
        """Test parsing MX record line."""
        parser = DigParser()

        record = parser._parse_record_line(
            "example.com. 300 IN MX 10 mail.example.com."
        )

        assert isinstance(record, MXRecord)
        assert record.priority == 10
        assert record.mail_server == "mail.example.com"
        assert record.value == "10 mail.example.com"

    def test_parse_mx_record_invalid_priority(self):
        """Test parsing MX record with invalid priority."""
        parser = DigParser()

        # Non-numeric priority
        record = parser._parse_record_line(
            "example.com. 300 IN MX abc mail.example.com."
        )
        assert record is None

        # Missing priority
        record = parser._parse_record_line("example.com. 300 IN MX mail.example.com.")
        assert record is None

    def test_extract_status_noerror(self):
        """Test extracting NOERROR status."""
        parser = DigParser()

        output = ";; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12345"
        status = parser._extract_status(output)

        assert status == "NOERROR"

    def test_extract_status_nxdomain(self):
        """Test extracting NXDOMAIN status."""
        parser = DigParser()

        output = ";; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 12345"
        status = parser._extract_status(output)

        assert status == "NXDOMAIN"

    def test_extract_status_default(self):
        """Test extracting status when not found."""
        parser = DigParser()

        output = "No status information"
        status = parser._extract_status(output)

        assert status == "NOERROR"

    def test_extract_query_time(self):
        """Test extracting query time."""
        parser = DigParser()

        output = ";; Query time: 45 msec"
        query_time = parser._extract_query_time(output)

        assert query_time == 45

    def test_extract_query_time_not_found(self):
        """Test extracting query time when not found."""
        parser = DigParser()

        output = "No query time information"
        query_time = parser._extract_query_time(output)

        assert query_time is None

    def test_extract_query_time_invalid(self):
        """Test extracting invalid query time."""
        parser = DigParser()

        output = ";; Query time: abc msec"
        query_time = parser._extract_query_time(output)

        assert query_time is None

    def test_extract_server(self):
        """Test extracting server information."""
        parser = DigParser()

        output = ";; SERVER: 8.8.8.8#53(8.8.8.8)"
        server = parser._extract_server(output)

        assert server == "8.8.8.8"

    def test_extract_server_with_port(self):
        """Test extracting server information with port."""
        parser = DigParser()

        output = ";; SERVER: 192.168.1.1#5353(192.168.1.1)"
        server = parser._extract_server(output)

        assert server == "192.168.1.1"

    def test_extract_server_not_found(self):
        """Test extracting server when not found."""
        parser = DigParser()

        output = "No server information"
        server = parser._extract_server(output)

        assert server is None

    def test_parse_record_type_valid(self):
        """Test parsing valid record types."""
        parser = DigParser()

        assert parser._parse_record_type("A") == RecordType.A
        assert parser._parse_record_type("a") == RecordType.A
        assert parser._parse_record_type("MX") == RecordType.MX
        assert parser._parse_record_type("mx") == RecordType.MX

    def test_parse_record_type_invalid(self):
        """Test parsing invalid record type."""
        parser = DigParser()

        # Unknown record type defaults to A
        assert parser._parse_record_type("UNKNOWN") == RecordType.A
        assert parser._parse_record_type("") == RecordType.A

    def test_validate_domain_valid(self):
        """Test domain validation with valid domains."""
        parser = DigParser()

        assert parser.validate_domain("example.com") is True
        assert parser.validate_domain("sub.example.com") is True
        assert parser.validate_domain("example-site.com") is True
        assert parser.validate_domain("123.example.com") is True
        assert parser.validate_domain("a.b.c.d.example.com") is True

    def test_validate_domain_invalid(self):
        """Test domain validation with invalid domains."""
        parser = DigParser()

        assert parser.validate_domain("") is False
        assert parser.validate_domain("   ") is False
        assert parser.validate_domain(".example.com") is False
        assert parser.validate_domain("example.com.") is False
        assert parser.validate_domain("-example.com") is False
        assert parser.validate_domain("example.com-") is False
        assert parser.validate_domain("example..com") is False
        assert parser.validate_domain("example$.com") is False
        assert parser.validate_domain("a" * 254) is False  # Too long

    def test_get_supported_record_types(self):
        """Test getting supported record types."""
        parser = DigParser()

        types = parser.get_supported_record_types()

        assert isinstance(types, list)
        assert "A" in types
        assert "AAAA" in types
        assert "MX" in types
        assert "NS" in types
        assert "CNAME" in types
        assert "SOA" in types
        assert "TXT" in types

    def test_parse_unknown_record_type(self):
        """Test parsing unknown record type."""
        parser = DigParser()

        # Unknown record type should be ignored
        record = parser._parse_record_line("example.com. 300 IN UNKNOWN some-value")
        assert record is None

    def test_parse_with_comments_and_empty_lines(self):
        """Test parsing output with comments and empty lines."""
        output = """;; This is a comment

;; ANSWER SECTION:
example.com.    300    IN    A    93.184.216.34

;; Another comment

;; AUTHORITY SECTION:
example.com.    3600    IN    NS    ns1.example.com.

;; Final comment"""

        parser = DigParser()
        response = parser.parse(output, "example.com", "A")

        assert len(response.answer_section) == 1
        assert len(response.authority_section) == 1
        assert response.answer_section[0].value == "93.184.216.34"
        assert response.authority_section[0].value == "ns1.example.com"

    def test_parse_real_dig_output(self):
        """Test parsing realistic dig output."""
        output = """; <<>> DiG 9.16.1-Ubuntu <<>> example.com A
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12345
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 512

;; QUESTION SECTION:
;example.com.                   IN      A

;; ANSWER SECTION:
example.com.            300     IN      A       93.184.216.34

;; Query time: 45 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)
;; WHEN: Mon Jan 01 12:00:00 UTC 2024
;; MSG SIZE  rcvd: 56"""

        parser = DigParser()
        response = parser.parse(output, "example.com", "A")

        assert response.status == "NOERROR"
        assert response.query_time_ms == 45
        assert response.server == "8.8.8.8"
        assert len(response.answer_section) == 1
        assert response.answer_section[0].value == "93.184.216.34"
