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

    Copyright 2026 Danila Vershinin
*/

#pragma once

/* Set file paths for blocklist/allowlist (called during CLI parsing). */
void ip_acl_set_blocklist_file (const char *path);
void ip_acl_set_allowlist_file (const char *path);

/* Load or reload ACL files. Returns 0 on success, -1 on error.
   On reload failure, keeps the existing ACL and logs a warning. */
int ip_acl_reload (void);

/* Check whether an IPv4 address (host byte order) is allowed.
   Returns 1 if allowed, 0 if rejected. */
int ip_acl_check_v4 (unsigned ip);

/* Check whether an IPv6 address is allowed.
   Returns 1 if allowed, 0 if rejected. */
int ip_acl_check_v6 (const unsigned char ipv6[16]);

/* Return count of loaded rules (for stats/debugging). */
int ip_acl_blocklist_count (void);
int ip_acl_allowlist_count (void);
