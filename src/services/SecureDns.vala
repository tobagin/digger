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
                // RFC 8484 requires unpadded base64url for the ?dns= parameter.
                var b64_query = Base64.encode (dns_query_bytes)
                    .replace ("+", "-").replace ("/", "_").replace ("=", "");

                var uri = doh_endpoint + "?dns=" + b64_query;
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

            // RFC 8484 §4.1: use ID 0 with GET so responses stay cache-friendly.
            query.append ({ 0x00, 0x00 });
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

            // We always send ID 0 (RFC 8484 GET); a mismatched ID means the
            // response doesn't belong to our query.
            if (data[0] != 0 || data[1] != 0) {
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

            // Re-check bounds: skip_name advanced the offset, so the fixed
            // 10-byte record header (type+class+ttl+rdlength) must still fit.
            if (offset + 10 > data.length) {
                return null;
            }

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

        /**
         * Decodes a (possibly compressed) DNS name starting at `start`.
         * Follows 0xC0 compression pointers with a hop cap to defeat pointer
         * loops. `end` receives the offset just past the name in the linear
         * region (before the first pointer jump), for continued parsing.
         */
        private string read_name (uint8[] data, int start, out int end) {
            var parts = new StringBuilder ();
            int offset = start;
            bool jumped = false;
            int hops = 0;
            end = start;

            while (offset >= 0 && offset < data.length && hops < 128) {
                uint8 len = data[offset];
                if (len == 0) {
                    if (!jumped) end = offset + 1;
                    break;
                }
                if ((len & 0xC0) == 0xC0) {
                    if (offset + 1 >= data.length) break;
                    int pointer = ((len & 0x3F) << 8) | data[offset + 1];
                    if (!jumped) end = offset + 2;
                    jumped = true;
                    offset = pointer;
                    hops++;
                    continue;
                }
                if (offset + 1 + len > data.length) break;
                if (parts.len > 0) parts.append (".");
                for (int i = 0; i < len; i++) {
                    parts.append_c ((char) data[offset + 1 + i]);
                }
                offset += len + 1;
                if (!jumped) end = offset;
                hops++;
            }

            return parts.str;
        }

        private string read_txt (uint8[] data, int offset, uint16 length) {
            var sb = new StringBuilder ();
            int p = offset;
            int limit = int.min (offset + length, data.length);
            while (p < limit) {
                uint8 slen = data[p];
                p++;
                for (int i = 0; i < slen && p < limit; i++) {
                    sb.append_c ((char) data[p]);
                    p++;
                }
            }
            return sb.str;
        }

        private uint32 read_u32 (uint8[] data, int o) {
            return ((uint32)data[o] << 24) | ((uint32)data[o+1] << 16) |
                   ((uint32)data[o+2] << 8) | data[o+3];
        }

        private string parse_rdata (uint8[] data, int offset, uint16 length, uint16 rtype) {
            int end;
            switch (rtype) {
                case 1: // A
                    if (length == 4) {
                        return @"$(data[offset]).$(data[offset+1]).$(data[offset+2]).$(data[offset+3])";
                    }
                    break;
                case 28: // AAAA
                    if (length == 16) {
                        var parts = new string[8];
                        for (int i = 0; i < 8; i++) {
                            parts[i] = "%04x".printf (((uint16)data[offset + i*2] << 8) | data[offset + i*2 + 1]);
                        }
                        return string.joinv (":", parts);
                    }
                    break;
                case 5:  // CNAME
                case 2:  // NS
                case 12: // PTR
                    return read_name (data, offset, out end);
                case 15: // MX
                    if (length >= 3) {
                        uint16 pref = ((uint16)data[offset] << 8) | data[offset + 1];
                        string exch = read_name (data, offset + 2, out end);
                        return @"$pref $exch";
                    }
                    break;
                case 16: // TXT
                    return read_txt (data, offset, length);
                case 6:  // SOA
                    if (length >= 22) {
                        int p = offset;
                        string mname = read_name (data, p, out end); p = end;
                        string rname = read_name (data, p, out end); p = end;
                        if (p + 20 <= data.length) {
                            uint32 serial = read_u32 (data, p);
                            uint32 refresh = read_u32 (data, p + 4);
                            uint32 retry = read_u32 (data, p + 8);
                            uint32 expire = read_u32 (data, p + 12);
                            uint32 minimum = read_u32 (data, p + 16);
                            return @"$mname $rname $serial $refresh $retry $expire $minimum";
                        }
                    }
                    break;
                case 33: // SRV
                    if (length >= 7) {
                        uint16 prio = ((uint16)data[offset] << 8) | data[offset + 1];
                        uint16 weight = ((uint16)data[offset + 2] << 8) | data[offset + 3];
                        uint16 port = ((uint16)data[offset + 4] << 8) | data[offset + 5];
                        string target = read_name (data, offset + 6, out end);
                        return @"$prio $weight $port $target";
                    }
                    break;
            }

            // Fallback for binary types (DNSKEY, DS, RRSIG, NSEC, HTTPS, …).
            var hex = new StringBuilder ();
            for (int i = 0; i < length && i < Constants.MAX_RECORD_DATA_DISPLAY_LENGTH; i++) {
                hex.append_printf ("%02x", data[offset + i]);
            }
            return hex.str;
        }
    }
}
