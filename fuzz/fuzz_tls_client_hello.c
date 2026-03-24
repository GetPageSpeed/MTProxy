/* Fuzz harness for tls_parse_sni() and tls_parse_client_hello_ciphers().
   Tests: SNI extraction, extension iteration, cipher suite GREASE skipping. */

#include <stddef.h>
#include <stdint.h>

#include "net/net-tls-parse.h"

int LLVMFuzzerTestOneInput (const uint8_t *data, size_t size) {
  if (size > 65536) {
    return 0;
  }

  char domain[256];
  tls_parse_sni (data, (int)size, domain, sizeof (domain));

  unsigned char cipher_suite_id;
  tls_parse_client_hello_ciphers (data, (int)size, &cipher_suite_id);

  return 0;
}
