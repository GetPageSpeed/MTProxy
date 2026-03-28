/*
    This file is part of MTProto-Server

    MTProto-Server is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    MTProto-Server is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with MTProto-Server.  If not, see <http://www.gnu.org/licenses/>.

    This program is released under the GPL with the additional exemption
    that compiling, linking, and/or using OpenSSL is allowed.
    You are free to remove this exemption from derived works.
*/
#pragma once

#include <netinet/in.h>

struct dc_address {
  int dc_id;
  in_addr_t ipv4;             /* network byte order */
  unsigned char ipv6[16];     /* network byte order, all-zero if unavailable */
  int port;
};

/* Look up a Telegram DC by its identifier.
   Handles negative dc_id (media DCs) and dc_id >= 10000 (test DCs).
   Returns NULL if the DC is unknown. */
const struct dc_address *direct_dc_lookup (int dc_id);
