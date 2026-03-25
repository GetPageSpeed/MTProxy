/*
    Dynamic Record Sizing (DRS) for TLS transport.

    Mimics real HTTPS server behavior: small records during TCP slow-start,
    ramping to max TLS payload.  This makes proxy traffic statistically
    indistinguishable from real HTTPS at the packet level.

    Copyright 2026 GetPageSpeed Inc
*/

#pragma once

#include "net/net-connections.h"
#include "net/net-tcp-rpc-common.h"

/* Per-connection DRS state.  Lives in custom_data after tcp_rpc_data. */
struct drs_state {
  int record_index;         /* records sent since last reset */
  double last_record_time;  /* precise_now when last record was sent */
};

#define DRS_STATE(c) ((struct drs_state *)(CONN_INFO(c)->custom_data + sizeof (struct tcp_rpc_data)))

int drs_record_size (int record_index);
int cpu_tcp_aes_crypto_ctr128_encrypt_output_drs (connection_job_t C);
