/* Fuzz harness for http_parse_data().
   Tests: state machine transitions, header limits, Content-Length overflow. */

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "net/net-http-parse.h"

int LLVMFuzzerTestOneInput (const uint8_t *data, size_t size) {
  if (size > 65536) {
    return 0;
  }

  struct hts_data D;
  memset (&D, 0, sizeof (D));
  D.parse_state = htqp_start;

  http_parse_data (&D, (const char *)data, (int)size);
  return 0;
}
