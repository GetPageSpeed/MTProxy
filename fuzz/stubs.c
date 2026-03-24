/* Stubs for fuzz targets — replace engine dependencies with no-ops. */

#include <stdarg.h>

int kprintf (const char *format, ...) {
  (void)format;
  return 0;
}

void kprintf_multiline (const char *format, ...) {
  (void)format;
}

int verbosity;
