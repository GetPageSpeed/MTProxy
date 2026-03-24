/*
    This file is part of Mtproto-proxy Library.

    Mtproto-proxy Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    Mtproto-proxy Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Mtproto-proxy Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2025 GetPageSpeed Inc
*/

#pragma once

#define MAX_ENCRYPTED_RECORDS 8

/* Read a 2-byte big-endian length from data at *pos, advancing *pos by 2. */
int tls_read_length (const unsigned char *data, int *pos);

/* Validate an upstream TLS ServerHello response.
   Returns 1 on success, 0 on failure.
   On success, fills is_reversed_extension_order, encrypted_record_sizes
   (up to MAX_ENCRYPTED_RECORDS entries), and encrypted_record_count. */
int tls_check_server_hello (const unsigned char *response, int len,
                            const unsigned char *request_session_id,
                            int *is_reversed_extension_order,
                            int *encrypted_record_sizes,
                            int *encrypted_record_count);

/* Parse the SNI extension from a TLS ClientHello.
   Extracts the domain name into out_domain (NUL-terminated, up to max_domain_len-1 chars).
   Returns the domain length on success, -1 on failure. */
int tls_parse_sni (const unsigned char *client_hello, int len,
                   char *out_domain, int max_domain_len);

/* Parse cipher suites from a TLS ClientHello, skipping GREASE values.
   client_hello: full ClientHello buffer; len: buffer length.
   On success, writes the chosen cipher suite ID to *cipher_suite_id and returns 0.
   Returns -1 on failure. */
int tls_parse_client_hello_ciphers (const unsigned char *client_hello, int len,
                                    unsigned char *cipher_suite_id);
