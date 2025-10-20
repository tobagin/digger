/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024 tobagin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger {
    public enum SecureDnsProtocol {
        NONE,
        DOH,
        DOT;

        public string to_string () {
            switch (this) {
                case NONE: return "Standard DNS";
                case DOH: return "DNS-over-HTTPS";
                case DOT: return "DNS-over-TLS";
                default: return "Unknown";
            }
        }
    }

    public class SecureDnsProvider : Object {
        public string name { get; set; }
        public string description { get; set; }
        public SecureDnsProtocol protocol { get; set; }
        public string endpoint { get; set; }

        public SecureDnsProvider (string name, SecureDnsProtocol protocol, string endpoint) {
            this.name = name;
            this.protocol = protocol;
            this.endpoint = endpoint;
            this.description = "";
        }

        public static Gee.ArrayList<SecureDnsProvider> get_default_providers () {
            var providers = new Gee.ArrayList<SecureDnsProvider> ();

            var cloudflare = new SecureDnsProvider (
                "Cloudflare DNS",
                SecureDnsProtocol.DOH,
                "https://cloudflare-dns.com/dns-query"
            );
            cloudflare.description = "Fast and privacy-focused DNS";
            providers.add (cloudflare);

            var google = new SecureDnsProvider (
                "Google DNS",
                SecureDnsProtocol.DOH,
                "https://dns.google/dns-query"
            );
            google.description = "Reliable DNS by Google";
            providers.add (google);

            return providers;
        }
    }

    public class SecureDnsQuery : Object {
        private Soup.Session session;

        public SecureDnsQuery () {
            session = new Soup.Session ();
            session.timeout = Constants.DOH_QUERY_TIMEOUT_SECONDS;
            session.user_agent = "Digger/" + Config.VERSION;
        }

        public async QueryResult? perform_doh_query (string domain, RecordType record_type, string doh_endpoint) {
            var result = new QueryResult ();
            result.domain = domain;
            result.query_type = record_type;
            result.dns_server = doh_endpoint;

            // SEC-006: Enforce HTTPS-only for DoH endpoints
            if (!ValidationUtils.is_https_url (doh_endpoint)) {
                result.status = QueryStatus.NETWORK_ERROR;
                critical ("DoH endpoint must use HTTPS: %s", doh_endpoint);
                return result;
            }

            var timer = new Timer ();
            timer.start ();

            try {
                var dns_query_bytes = build_dns_query (domain, record_type);
                var b64_query = Base64.encode (dns_query_bytes);

                var uri = doh_endpoint + "?dns=" + Uri.escape_string (b64_query);
                var message = new Soup.Message ("GET", uri);
                message.request_headers.append ("Accept", "application/dns-message");

                var response = yield session.send_and_read_async (message, Priority.DEFAULT, null);

                timer.stop ();
                result.query_time_ms = timer.elapsed () * 1000;

                if (message.status_code != 200) {
                    result.status = QueryStatus.NETWORK_ERROR;
                    return result;
                }

                parse_dns_response (response.get_data (), result);
                return result;

            } catch (Error e) {
                timer.stop ();
                result.query_time_ms = timer.elapsed () * 1000;
                result.status = QueryStatus.NETWORK_ERROR;
                warning ("DoH query failed: %s", e.message);
                return result;
            }
        }

        private uint8[] build_dns_query (string domain, RecordType record_type) {
            var query = new ByteArray ();

            uint16 txid = (uint16) Random.int_range (0, 65536);
            query.append ({ (uint8)(txid >> 8), (uint8)(txid & 0xFF) });
            query.append ({ 0x01, 0x00 });
            query.append ({ 0x00, 0x01 });
            query.append ({ 0x00, 0x00 });
            query.append ({ 0x00, 0x00 });
            query.append ({ 0x00, 0x00 });

            var labels = domain.split (".");
            foreach (var label in labels) {
                query.append ({ (uint8)label.length });
                query.append (label.data);
            }
            query.append ({ 0x00 });

            uint16 qtype = (uint16) record_type.to_wire_type ();
            query.append ({ (uint8)(qtype >> 8), (uint8)(qtype & 0xFF) });
            query.append ({ 0x00, 0x01 });

            return query.data;
        }

        private void parse_dns_response (uint8[] data, QueryResult result) {
            if (data.length < Constants.MIN_DNS_PACKET_SIZE) {
                result.status = QueryStatus.NETWORK_ERROR;
                return;
            }

            uint8 rcode = data[3] & 0x0F;
            switch (rcode) {
                case 0:
                    result.status = QueryStatus.SUCCESS;
                    break;
                case 3:
                    result.status = QueryStatus.NXDOMAIN;
                    return;
                case 2:
                case 1:
                    result.status = QueryStatus.SERVFAIL;
                    return;
                case 5:
                    result.status = QueryStatus.REFUSED;
                    return;
                default:
                    result.status = QueryStatus.NETWORK_ERROR;
                    return;
            }

            uint16 ancount = ((uint16)data[6] << 8) | data[7];
            if (ancount == 0) {
                return;
            }

            int offset = 12;
            offset = skip_question (data, offset);

            for (int i = 0; i < ancount && offset < data.length; i++) {
                var record = parse_record (data, ref offset, result.domain);
                if (record != null) {
                    result.answer_section.add (record);
                }
            }
        }

        private int skip_question (uint8[] data, int offset) {
            while (offset < data.length) {
                uint8 len = data[offset];
                if (len == 0) {
                    return offset + 5;
                }
                if ((len & 0xC0) == 0xC0) {
                    return offset + 6;
                }
                offset += len + 1;
            }
            return offset;
        }

        private DnsRecord? parse_record (uint8[] data, ref int offset, string default_name) {
            if (offset + 10 > data.length) {
                return null;
            }

            offset = skip_name (data, offset);

            uint16 rtype = ((uint16)data[offset] << 8) | data[offset + 1];
            offset += 4;

            uint32 ttl = ((uint32)data[offset] << 24) | ((uint32)data[offset + 1] << 16) |
                        ((uint32)data[offset + 2] << 8) | data[offset + 3];
            offset += 4;

            uint16 rdlength = ((uint16)data[offset] << 8) | data[offset + 1];
            offset += 2;

            if (offset + rdlength > data.length) {
                return null;
            }

            string value = parse_rdata (data, offset, rdlength, rtype);
            offset += rdlength;

            var record_type = RecordType.from_wire_type ((int)rtype);
            return new DnsRecord (default_name, record_type, (int)ttl, value);
        }

        private int skip_name (uint8[] data, int offset) {
            while (offset < data.length) {
                uint8 len = data[offset];
                if (len == 0) {
                    return offset + 1;
                }
                if ((len & 0xC0) == 0xC0) {
                    return offset + 2;
                }
                offset += len + 1;
            }
            return offset;
        }

        private string parse_rdata (uint8[] data, int offset, uint16 length, uint16 rtype) {
            if (rtype == 1 && length == 4) {
                return @"$(data[offset]).$(data[offset+1]).$(data[offset+2]).$(data[offset+3])";
            } else if (rtype == 28 && length == 16) {
                var parts = new string[8];
                for (int i = 0; i < 8; i++) {
                    parts[i] = "%04x".printf(((uint16)data[offset + i*2] << 8) | data[offset + i*2 + 1]);
                }
                return string.joinv (":", parts);
            }

            var hex = new StringBuilder ();
            for (int i = 0; i < length && i < Constants.MAX_RECORD_DATA_DISPLAY_LENGTH; i++) {
                hex.append_printf ("%02x", data[offset + i]);
            }
            return hex.str;
        }
    }
}
