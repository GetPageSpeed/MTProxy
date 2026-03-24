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

    Copyright 2010-2012 Vkontakte Ltd
              2010-2012 Nikolai Durov
              2010-2012 Andrey Lopatin
    Copyright 2014-2016 Telegram Messenger Inc
              2015-2016 Vitaly Valtman
    Copyright 2025 GetPageSpeed Inc
*/

#include "net/net-http-parse.h"

#include <assert.h>
#include <stddef.h>
#include <string.h>
#include <strings.h>

int http_parse_data (struct hts_data *D, const char *data, int len) {
  const char *ptr = data;
  const char *ptr_e = data + len;
  long long tt;

  while (ptr < ptr_e && D->parse_state != htqp_done) {
    switch (D->parse_state) {
      case htqp_start:
        memset (D, 0, offsetof (struct hts_data, query_seqno));
        D->query_seqno++;
        D->query_type = htqt_none;
        D->data_size = -1;
        D->parse_state = htqp_readtospace;
        /* fallthrough */

      case htqp_readtospace:
        while (ptr < ptr_e && ((unsigned char) *ptr > ' ')) {
          if (D->wlen < 15) {
            D->word[D->wlen] = *ptr;
          }
          D->wlen++;
          ptr++;
        }
        if (D->wlen > 4096) {
          D->parse_state = htqp_fatal;
          break;
        }
        if (ptr == ptr_e) {
          break;
        }
        D->parse_state = htqp_skipspc;
        D->query_words++;
        if (D->query_words == 1) {
          D->query_type = htqt_error;
          if (D->wlen == 3 && !memcmp (D->word, "GET", 3)) {
            D->query_type = htqt_get;
          } else if (D->wlen == 4) {
            if (!memcmp (D->word, "HEAD", 4)) {
              D->query_type = htqt_head;
            } else if (!memcmp (D->word, "POST", 4)) {
              D->query_type = htqt_post;
            }
          } else if (D->wlen == 7 && !memcmp (D->word, "OPTIONS", 7)) {
            D->query_type = htqt_options;
          }
          if (D->query_type == htqt_error) {
            D->parse_state = htqp_skiptoeoln;
            D->query_flags |= QF_ERROR;
          }
        } else if (D->query_words == 2) {
          D->uri_offset = D->header_size;
          D->uri_size = D->wlen;
          if (!D->wlen) {
            D->parse_state = htqp_skiptoeoln;
            D->query_flags |= QF_ERROR;
          }
        } else if (D->query_words == 3) {
          D->parse_state = htqp_skipspctoeoln;
          if (D->wlen != 0) {
            /* HTTP/x.y */
            if (D->wlen != 8) {
              D->parse_state = htqp_skiptoeoln;
              D->query_flags |= QF_ERROR;
            } else {
              if (!memcmp (D->word, "HTTP/1.0", 8)) {
                D->http_ver = HTTP_V10;
              } else if (!memcmp (D->word, "HTTP/1.1", 8)) {
                D->http_ver = HTTP_V11;
              } else {
                D->parse_state = htqp_skiptoeoln;
                D->query_flags |= QF_ERROR;
              }
            }
          } else {
            D->http_ver = HTTP_V09;
          }
        } else {
          assert (D->query_flags & (QF_HOST | QF_CONNECTION));
          if (D->wlen) {
            if (D->query_flags & QF_HOST) {
              D->host_offset = D->header_size;
              D->host_size = D->wlen;
            } else if (D->wlen == 10 && !strncasecmp (D->word, "keep-alive", 10)) {
              D->query_flags |= QF_KEEPALIVE;
            }
          }
          D->query_flags &= ~(QF_HOST | QF_CONNECTION);
          D->parse_state = htqp_skipspctoeoln;
        }
        D->header_size += D->wlen;
        break;

      case htqp_skipspc:
      case htqp_skipspctoeoln:
        while (D->header_size < MAX_HTTP_HEADER_SIZE && ptr < ptr_e && (*ptr == ' ' || (*ptr == '\t' && D->query_words >= 8))) {
          D->header_size++;
          ptr++;
        }
        if (D->header_size >= MAX_HTTP_HEADER_SIZE) {
          D->parse_state = htqp_fatal;
          break;
        }
        if (ptr == ptr_e) {
          break;
        }
        if (D->parse_state == htqp_skipspctoeoln) {
          D->parse_state = htqp_eoln;
          break;
        }
        if (D->query_words < 3) {
          D->wlen = 0;
          D->parse_state = htqp_readtospace;
        } else {
          assert (D->query_words >= 4);
          if (D->query_flags & QF_DATASIZE) {
            if (D->data_size != -1) {
              D->parse_state = htqp_skiptoeoln;
              D->query_flags |= QF_ERROR;
            } else {
              D->parse_state = htqp_readint;
              D->data_size = 0;
            }
          } else if (D->query_flags & (QF_HOST | QF_CONNECTION)) {
            D->wlen = 0;
            D->parse_state = htqp_readtospace;
          } else {
            D->parse_state = htqp_skiptoeoln;
          }
        }
        break;

      case htqp_readtocolon:
        while (ptr < ptr_e && *ptr != ':' && *ptr > ' ') {
          if (D->wlen < 15) {
            D->word[D->wlen] = *ptr;
          }
          D->wlen++;
          ptr++;
        }
        if (D->wlen > 4096) {
          D->parse_state = htqp_fatal;
          break;
        }
        if (ptr == ptr_e) {
          break;
        }

        if (*ptr != ':') {
          D->header_size += D->wlen;
          D->parse_state = htqp_skiptoeoln;
          D->query_flags |= QF_ERROR;
          break;
        }

        ptr++;

        if (D->wlen == 4 && !strncasecmp (D->word, "host", 4)) {
          D->query_flags |= QF_HOST;
        } else if (D->wlen == 10 && !strncasecmp (D->word, "connection", 10)) {
          D->query_flags |= QF_CONNECTION;
        } else if (D->wlen == 14 && !strncasecmp (D->word, "content-length", 14)) {
          D->query_flags |= QF_DATASIZE;
        } else {
          D->query_flags &= ~(QF_HOST | QF_DATASIZE | QF_CONNECTION);
        }

        D->header_size += D->wlen + 1;
        D->parse_state = htqp_skipspc;
        break;

      case htqp_readint:
        tt = D->data_size;
        while (ptr < ptr_e && *ptr >= '0' && *ptr <= '9') {
          if (tt >= 0x7fffffffL / 10) {
            D->query_flags |= QF_ERROR;
            D->parse_state = htqp_skiptoeoln;
            break;
          }
          tt = tt * 10 + (*ptr - '0');
          ptr++;
          D->header_size++;
          D->query_flags &= ~QF_DATASIZE;
        }

        D->data_size = tt;
        if (ptr == ptr_e) {
          break;
        }

        if (D->query_flags & QF_DATASIZE) {
          D->query_flags |= QF_ERROR;
          D->parse_state = htqp_skiptoeoln;
        } else {
          D->parse_state = htqp_skipspctoeoln;
        }
        break;

      case htqp_skiptoeoln:
        while (D->header_size < MAX_HTTP_HEADER_SIZE && ptr < ptr_e && (*ptr != '\r' && *ptr != '\n')) {
          D->header_size++;
          ptr++;
        }
        if (D->header_size >= MAX_HTTP_HEADER_SIZE) {
          D->parse_state = htqp_fatal;
          break;
        }
        if (ptr == ptr_e) {
          break;
        }

        D->parse_state = htqp_eoln;
        /* fallthrough */

      case htqp_eoln:
        if (ptr == ptr_e) {
          break;
        }
        if (*ptr == '\r') {
          ptr++;
          D->header_size++;
        }
        D->parse_state = htqp_wantlf;
        /* fallthrough */

      case htqp_wantlf:
        if (ptr == ptr_e) {
          break;
        }
        if (++D->query_words < 8) {
          D->query_words = 8;
          if (D->query_flags & QF_ERROR) {
            D->parse_state = htqp_fatal;
            break;
          }
        }

        if (D->http_ver <= HTTP_V09) {
          D->parse_state = htqp_wantlastlf;
          break;
        }

        if (*ptr != '\n') {
          D->query_flags |= QF_ERROR;
          D->parse_state = htqp_skiptoeoln;
          break;
        }

        ptr++;
        D->header_size++;

        D->parse_state = htqp_linestart;
        /* fallthrough */

      case htqp_linestart:
        if (ptr == ptr_e) {
          break;
        }

        if (!D->first_line_size) {
          D->first_line_size = D->header_size;
        }

        if (*ptr == '\r') {
          ptr++;
          D->header_size++;
          D->parse_state = htqp_wantlastlf;
          break;
        }
        if (*ptr == '\n') {
          D->parse_state = htqp_wantlastlf;
          break;
        }

        if (D->query_flags & QF_ERROR) {
          D->parse_state = htqp_skiptoeoln;
        } else {
          D->wlen = 0;
          D->parse_state = htqp_readtocolon;
        }
        break;

      case htqp_wantlastlf:
        if (ptr == ptr_e) {
          break;
        }
        if (*ptr != '\n') {
          D->parse_state = htqp_fatal;
          break;
        }
        ptr++;
        D->header_size++;

        if (!D->first_line_size) {
          D->first_line_size = D->header_size;
        }

        D->parse_state = htqp_done;
        /* fallthrough */

      case htqp_done:
        break;

      case htqp_fatal:
        D->query_flags |= QF_ERROR;
        D->parse_state = htqp_done;
        break;

      default:
        assert (0);
    }
  }

  return (int)(ptr - data);
}
