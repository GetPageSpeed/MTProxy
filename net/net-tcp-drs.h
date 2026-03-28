/*
    Dynamic Record Sizing (DRS) and inter-record delays for TLS transport.

    Mimics real HTTPS server behavior: small records during TCP slow-start,
    ramping to max TLS payload, with Weibull-distributed inter-record delays.

    Copyright 2026 GetPageSpeed Inc
*/

#pragma once

#include "net/net-connections.h"
#include "net/net-tcp-rpc-common.h"

/* Per-connection DRS state.  Lives in custom_data after tcp_rpc_data. */
struct drs_state {
  int record_index;         /* records sent since last reset (for sizing) */
  int total_records;        /* records sent total (for delay decisions, 30s reset) */
  double last_record_time;  /* precise_now when last record was sent */
  int delay_pending;        /* 1 = timer set, waiting before next record */
};

#define DRS_STATE(c) ((struct drs_state *)(CONN_INFO(c)->custom_data + sizeof (struct tcp_rpc_data)))

int drs_record_size (int record_index);
int cpu_tcp_aes_crypto_ctr128_encrypt_output_drs (connection_job_t C);

/* Inter-record delay parameters (Weibull distribution).
   Delays are automatically enabled when DRS is active (TLS mode). */
extern int drs_delays_enabled;
extern long long drs_delays_applied;
extern long long drs_delays_skipped;

double drs_delay_get_k (void);
double drs_delay_get_lambda (void);
