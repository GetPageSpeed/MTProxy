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

#pragma once

#include "net/net-http-server.h"

enum http_query_parse_state {
  htqp_start,
  htqp_readtospace,
  htqp_readtocolon,
  htqp_readint,
  htqp_skipspc,
  htqp_skiptoeoln,
  htqp_skipspctoeoln,
  htqp_eoln,
  htqp_wantlf,
  htqp_wantlastlf,
  htqp_linestart,
  htqp_fatal,
  htqp_done
};

/* Parse HTTP request data from a flat buffer.
   The state machine operates on struct hts_data which must be initialized
   with parse_state = htqp_start before the first call.
   Returns the number of bytes consumed. */
int http_parse_data (struct hts_data *D, const char *data, int len);
