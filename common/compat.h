/*
    Compatibility shim for building with musl libc (Alpine Linux).

    musl does not provide the reentrant drand48_r family (glibc extension).
    This implements the same 48-bit linear congruential generator so that each
    job thread keeps its own PRNG state without data races.
    Coefficients: a = 0x5DEECE66D, c = 0xB, m = 2^48 (same as POSIX drand48).
*/

#pragma once

#ifndef __GLIBC__

#include <stdint.h>

struct drand48_data {
  uint16_t x[3];
};

static inline void __compat_drand48_step (struct drand48_data *buf) {
  uint64_t X = ((uint64_t)buf->x[2] << 32) |
               ((uint64_t)buf->x[1] << 16) |
                (uint64_t)buf->x[0];
  X = (0x5DEECE66DULL * X + 0xBULL) & 0xFFFFFFFFFFFFULL;
  buf->x[0] = (uint16_t)(X);
  buf->x[1] = (uint16_t)(X >> 16);
  buf->x[2] = (uint16_t)(X >> 32);
}

static inline int srand48_r (long seedval, struct drand48_data *buf) {
  buf->x[2] = (uint16_t)((unsigned long)seedval >> 16);
  buf->x[1] = (uint16_t)((unsigned long)seedval & 0xFFFF);
  buf->x[0] = 0x330E;
  return 0;
}

static inline int lrand48_r (struct drand48_data *buf, long *result) {
  __compat_drand48_step (buf);
  *result = ((long)buf->x[2] << 15) | ((long)buf->x[1] >> 1);
  return 0;
}

static inline int mrand48_r (struct drand48_data *buf, long *result) {
  __compat_drand48_step (buf);
  *result = ((long)buf->x[2] << 16) | (long)buf->x[1];
  return 0;
}

static inline int drand48_r (struct drand48_data *buf, double *result) {
  __compat_drand48_step (buf);
  *result = (double)buf->x[2] / (1 << 16) +
            (double)buf->x[1] / (1ULL << 32) +
            (double)buf->x[0] / (1ULL << 48);
  return 0;
}

#endif /* __GLIBC__ */
