CC ?= clang
FUZZ_SANITIZERS = -fsanitize=fuzzer,address,undefined
FUZZ_CFLAGS = $(FUZZ_SANITIZERS) -g -O1 -fno-omit-frame-pointer -std=gnu11 -Wall -D_GNU_SOURCE=1 -DFUZZ_TARGET
FUZZ_CINCLUDE = -iquote ../common -iquote ..
FUZZ_DURATION ?= 60

TARGETS = fuzz_tls_server_hello fuzz_tls_client_hello fuzz_http_request
PARSE_OBJS = net-tls-parse.o net-http-parse.o stubs.o

.PHONY: all clean run

all: $(TARGETS)

net-tls-parse.o: ../net/net-tls-parse.c ../net/net-tls-parse.h
	$(CC) $(FUZZ_CFLAGS) $(FUZZ_CINCLUDE) -c -o $@ $<

net-http-parse.o: ../net/net-http-parse.c ../net/net-http-parse.h ../net/net-http-server.h
	$(CC) $(FUZZ_CFLAGS) $(FUZZ_CINCLUDE) -c -o $@ $<

stubs.o: stubs.c
	$(CC) $(FUZZ_CFLAGS) $(FUZZ_CINCLUDE) -c -o $@ $<

fuzz_tls_server_hello: fuzz_tls_server_hello.c net-tls-parse.o stubs.o
	$(CC) $(FUZZ_CFLAGS) $(FUZZ_CINCLUDE) -o $@ $^

fuzz_tls_client_hello: fuzz_tls_client_hello.c net-tls-parse.o stubs.o
	$(CC) $(FUZZ_CFLAGS) $(FUZZ_CINCLUDE) -o $@ $^

fuzz_http_request: fuzz_http_request.c net-http-parse.o stubs.o
	$(CC) $(FUZZ_CFLAGS) $(FUZZ_CINCLUDE) -o $@ $^

run: $(TARGETS)
	@failed=0; \
	for target in $(TARGETS); do \
		echo "=== Running $$target for $(FUZZ_DURATION)s ==="; \
		corpus_dir=corpus/$$(echo $$target | sed 's/^fuzz_//'); \
		./$$target $$corpus_dir -max_total_time=$(FUZZ_DURATION) -print_final_stats=1 || failed=1; \
	done; \
	if [ $$failed -ne 0 ]; then echo "FAIL: some fuzz targets crashed"; exit 1; fi

clean:
	rm -f $(TARGETS) $(PARSE_OBJS)
