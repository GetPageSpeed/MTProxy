/* Fuzz harness for tls_check_server_hello().
   Tests: extension parsing, length validation, record counting. */

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "net/net-tls-parse.h"

int LLVMFuzzerTestOneInput (const uint8_t *data, size_t size) {
  if (size > 65536) {
    return 0;
  }

  int is_reversed = 0;
  int encrypted_sizes[MAX_ENCRYPTED_RECORDS];
  int encrypted_count = 0;
  unsigned char session_id[32];
  memset (session_id, 0x42, sizeof (session_id));

  tls_check_server_hello (data, (int)size, session_id,
                          &is_reversed, encrypted_sizes, &encrypted_count);
  return 0;
}
