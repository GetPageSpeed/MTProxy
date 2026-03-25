/*
    Dynamic Record Sizing (DRS) for TLS transport.

    Real HTTPS servers (Cloudflare, Go stdlib, Caddy) use graduated TLS
    record sizes that mimic TCP slow-start:
      - First ~40 records:  MTU-sized  (~1450 bytes)
      - Next  ~20 records:  ramped     (~4096 bytes)
      - Remaining records:  maximum    (~16144 bytes)

    The counter resets after 1 second of inactivity, matching the pattern
    observed in production web servers.

    Reference: mtg proxy (9seconds/mtg), mtglib/internal/doppel/.

    Copyright 2026 GetPageSpeed Inc
*/

#include <assert.h>

#include "net/net-tcp-drs.h"
#include "net/net-crypto-aes.h"
#include "net/net-msg.h"
#include "common/precise-time.h"
#include "common/kprintf.h"
#include "jobs/jobs.h"

/* DRS thresholds (record indices) */
#define DRS_PHASE1_END   40   /* slow-start: MTU-sized records */
#define DRS_PHASE2_END   60   /* ramp: intermediate records */

/* DRS base record sizes (bytes) */
#define DRS_SIZE_START   1450   /* fits in one TCP segment */
#define DRS_SIZE_ACCEL   4096   /* intermediate ramp */
#define DRS_SIZE_MAX    16144   /* 16384 - TLS record overhead */

/* Inactivity timeout before resetting DRS counter (seconds) */
#define DRS_RESET_AFTER  1.0

/* Noise range: +-100 bytes */
#define DRS_NOISE_RANGE  201
#define DRS_NOISE_OFFSET 100

int drs_record_size (int record_index) /* {{{ */ {
  int base;
  if (record_index < DRS_PHASE1_END) {
    base = DRS_SIZE_START;
  } else if (record_index < DRS_PHASE2_END) {
    base = DRS_SIZE_ACCEL;
  } else {
    base = DRS_SIZE_MAX;
  }
  int noise = (int)(lrand48_j () % DRS_NOISE_RANGE) - DRS_NOISE_OFFSET;
  int size = base + noise;
  if (size < 64) {
    size = 64;
  }
  return size;
}
/* }}} */

int cpu_tcp_aes_crypto_ctr128_encrypt_output_drs (connection_job_t C) /* {{{ */ {
  assert_net_cpu_thread ();
  struct connection_info *c = CONN_INFO (C);

  struct aes_crypto *T = c->crypto;
  assert (c->crypto);

  struct drs_state *drs = DRS_STATE (C);

  while (c->out.total_bytes) {
    int len = c->out.total_bytes;
    if (c->flags & C_IS_TLS) {
      assert (c->left_tls_packet_length >= 0);

      /* Reset record counter after inactivity */
      if (precise_now - drs->last_record_time > DRS_RESET_AFTER) {
        drs->record_index = 0;
      }

      int max_len = drs_record_size (drs->record_index);
      if (max_len < len) {
        len = max_len;
      }

      unsigned char header[5] = {0x17, 0x03, 0x03, len >> 8, len & 255};
      rwm_push_data (&c->out_p, header, 5);
      vkprintf (2, "Send TLS-packet of length %d (DRS phase %s, record #%d)\n",
                len,
                drs->record_index < DRS_PHASE1_END ? "start" :
                drs->record_index < DRS_PHASE2_END ? "accel" : "max",
                drs->record_index);

      drs->record_index++;
      drs->last_record_time = precise_now;
    }

    assert (rwm_encrypt_decrypt_to (&c->out, &c->out_p, len, T->write_aeskey, 1) == len);
  }

  return 0;
}
/* }}} */
