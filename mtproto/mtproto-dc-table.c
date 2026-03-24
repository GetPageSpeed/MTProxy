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

#include <arpa/inet.h>
#include "mtproto/mtproto-dc-table.h"

/*
 * Well-known Telegram production DC addresses.
 * Media DCs (negative dc_id) share the same IPs as their positive counterparts.
 * Test DCs use dc_id + 10000 and have their own addresses.
 */

static const struct dc_address production_dcs[] = {
  { 1, 0, 443 },  /* 149.154.175.50  */
  { 2, 0, 443 },  /* 149.154.167.51  */
  { 3, 0, 443 },  /* 149.154.175.100 */
  { 4, 0, 443 },  /* 149.154.167.91  */
  { 5, 0, 443 },  /* 91.108.56.100   */
};

static const struct dc_address test_dcs[] = {
  { 1, 0, 443 },  /* 149.154.175.10  */
  { 2, 0, 443 },  /* 149.154.167.40  */
  { 3, 0, 443 },  /* 149.154.175.117 */
};

static int dc_table_initialized;

static struct dc_address prod_table[5];
static struct dc_address test_table[3];

static void dc_table_init (void) {
  if (dc_table_initialized) {
    return;
  }
  dc_table_initialized = 1;

  /* Production DCs */
  prod_table[0] = production_dcs[0];
  prod_table[0].ipv4 = inet_addr ("149.154.175.50");

  prod_table[1] = production_dcs[1];
  prod_table[1].ipv4 = inet_addr ("149.154.167.51");

  prod_table[2] = production_dcs[2];
  prod_table[2].ipv4 = inet_addr ("149.154.175.100");

  prod_table[3] = production_dcs[3];
  prod_table[3].ipv4 = inet_addr ("149.154.167.91");

  prod_table[4] = production_dcs[4];
  prod_table[4].ipv4 = inet_addr ("91.108.56.100");

  /* Test DCs */
  test_table[0] = test_dcs[0];
  test_table[0].ipv4 = inet_addr ("149.154.175.10");

  test_table[1] = test_dcs[1];
  test_table[1].ipv4 = inet_addr ("149.154.167.40");

  test_table[2] = test_dcs[2];
  test_table[2].ipv4 = inet_addr ("149.154.175.117");
}

const struct dc_address *direct_dc_lookup (int dc_id) {
  dc_table_init ();

  int is_test = 0;

  /* Negative dc_id = media DC (same IP as positive counterpart) */
  if (dc_id < 0) {
    dc_id = -dc_id;
  }

  /* dc_id >= 10000 = test DC */
  if (dc_id >= 10000) {
    dc_id -= 10000;
    is_test = 1;
  }

  if (is_test) {
    for (int i = 0; i < 3; i++) {
      if (test_table[i].dc_id == dc_id) {
        return &test_table[i];
      }
    }
    return 0;
  }

  for (int i = 0; i < 5; i++) {
    if (prod_table[i].dc_id == dc_id) {
      return &prod_table[i];
    }
  }
  return 0;
}
